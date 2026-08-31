defmodule RetroHexChat.Lobby.Queries do
  @moduledoc """
  Database queries for P2P lobby sessions.
  """

  import Ecto.Query

  alias RetroHexChat.Lobby.Schema.Session
  alias RetroHexChat.Repo
  alias RetroHexChat.StaleRecords

  @terminal_statuses ~w(closed expired failed)
  @stale StaleRecords.new(Session, @terminal_statuses)

  @spec insert_session(map()) :: {:ok, Session.t()} | {:error, Ecto.Changeset.t()}
  def insert_session(attrs) do
    %Session{}
    |> Session.changeset(attrs)
    |> Repo.insert()
  end

  @spec get_session_by_token(String.t()) :: Session.t() | nil
  def get_session_by_token(token) do
    Repo.get_by(Session, token: token)
  end

  @spec update_status(Session.t(), String.t(), map()) ::
          {:ok, Session.t()} | {:error, Ecto.Changeset.t()}
  def update_status(session, new_status, extra_attrs \\ %{}) do
    attrs = Map.merge(extra_attrs, %{status: new_status})

    session
    |> Session.status_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Takes the empty seat of an open lobby, if it is still empty.

  This is one conditional `UPDATE`, and the condition is the whole point: two
  people following the same match link at the same moment both reach here, and
  the database is what decides between them. A read that checks and a write
  that trusts the check would hand the same seat to both — the same reasoning
  that made the duplicate-session check a query rather than a Registry lookup.

  Zero rows affected means somebody arrived first, the lobby expired, or it was
  never open; all three are `:already_claimed`, because from the claimer's side
  they are the same fact: the seat is not available.
  """
  @spec claim_open_session(String.t(), integer(), DateTime.t()) ::
          {:ok, Session.t()} | {:error, :already_claimed}
  def claim_open_session(token, claimer_id, now \\ DateTime.utc_now()) do
    {count, sessions} =
      token
      |> claim_query(claimer_id, now)
      |> Repo.update_all(
        set: [
          peer_id: claimer_id,
          status: "pending",
          accepted_at: now,
          expires_at: nil,
          updated_at: now
        ]
      )

    case {count, sessions} do
      {1, [session]} -> {:ok, session}
      _none -> {:error, :already_claimed}
    end
  end

  @doc """
  The rows `claim_open_session/3` is allowed to write — public so a test can
  read the condition instead of trusting that it is there.
  """
  @spec claim_query(String.t(), integer(), DateTime.t()) :: Ecto.Query.t()
  def claim_query(token, _claimer_id, now) do
    Session
    |> where([s], s.token == ^token)
    |> where([s], is_nil(s.peer_id) and s.status == "open")
    |> where([s], is_nil(s.expires_at) or s.expires_at > ^now)
    |> select([s], s)
  end

  @doc "Open lobbies whose window has closed, oldest first."
  @spec list_expired_open_sessions(DateTime.t(), keyword()) :: [Session.t()]
  def list_expired_open_sessions(now, opts \\ []) do
    Session
    |> open_and_expired(now)
    |> order_by([s], asc: s.expires_at, asc: s.id)
    |> maybe_limit(Keyword.get(opts, :limit))
    |> Repo.all()
  end

  @doc "How many open lobbies the sweep would have to close, ignoring any limit."
  @spec expired_open_session_count(DateTime.t()) :: non_neg_integer()
  def expired_open_session_count(now) do
    Session
    |> open_and_expired(now)
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Closes one open lobby as expired, but only while it is still open and past
  its window.

  `:skipped` is not a failure: between listing a row and writing to it somebody
  may have claimed it, and a sweep that closed a lobby two people had just
  walked into would be worse than one that ran late.
  """
  @spec expire_open_session(Session.t(), DateTime.t()) ::
          {:ok, :expired | :skipped} | {:error, term()}
  def expire_open_session(%Session{id: id}, now) do
    {count, _sessions} =
      Session
      |> where([s], s.id == ^id)
      |> open_and_expired(now)
      |> Repo.update_all(
        set: [
          status: "expired",
          closed_at: now,
          closed_reason: "open_lobby_unclaimed",
          updated_at: now
        ]
      )

    case count do
      1 -> {:ok, :expired}
      0 -> {:ok, :skipped}
    end
  rescue
    error -> {:error, error}
  end

  @spec active_session_exists?(integer(), integer()) :: boolean()
  def active_session_exists?(user_a_id, user_b_id) do
    Session
    |> where(
      [s],
      (s.creator_id == ^user_a_id and s.peer_id == ^user_b_id) or
        (s.creator_id == ^user_b_id and s.peer_id == ^user_a_id)
    )
    |> where([s], s.status not in ^@terminal_statuses)
    |> Repo.exists?()
  end

  @spec active_sessions_between(integer(), integer()) :: [Session.t()]
  def active_sessions_between(user_a_id, user_b_id) do
    Session
    |> where(
      [s],
      (s.creator_id == ^user_a_id and s.peer_id == ^user_b_id) or
        (s.creator_id == ^user_b_id and s.peer_id == ^user_a_id)
    )
    |> where([s], s.status not in ^@terminal_statuses)
    |> Repo.all()
  end

  @doc """
  The sessions `user_id` is *in*, most recently updated first.

  An unclaimed match link is not one of them, and that is the whole reason this
  says `status != "open"`. Such a row is non-terminal and has the creator's id
  on it, so it matches every other condition here — and it is newer than the
  call they are already on, because minting it is the last thing they did. The
  caller asking this question is the chat, rebuilding what to draw after a
  reload; answering with a link nobody has followed makes it stop drawing the
  session that is actually running.
  """
  @spec active_sessions_for_user(integer()) :: [Session.t()]
  def active_sessions_for_user(user_id) do
    Session
    |> where([s], s.creator_id == ^user_id or s.peer_id == ^user_id)
    |> where([s], s.status not in ^@terminal_statuses)
    |> where([s], s.status != "open")
    |> order_by([s], desc: s.updated_at)
    |> Repo.all()
  end

  @spec list_stale_sessions(DateTime.t(), keyword()) :: [Session.t()]
  def list_stale_sessions(before_datetime, opts \\ []),
    do: StaleRecords.list(@stale, before_datetime, opts)

  @spec stale_session_count(DateTime.t()) :: non_neg_integer()
  def stale_session_count(before_datetime), do: StaleRecords.count(@stale, before_datetime)

  @spec expire_session(Session.t()) :: {:ok, Session.t()} | {:error, Ecto.Changeset.t()}
  def expire_session(session) do
    update_status(session, "expired", %{
      closed_at: DateTime.utc_now(),
      closed_reason: "stale_cleanup"
    })
  end

  @spec expire_stale_session(Session.t(), DateTime.t()) ::
          {:ok, :expired | :skipped} | {:error, term()}
  def expire_stale_session(%Session{id: id}, before_datetime),
    do: StaleRecords.expire(@stale, id, before_datetime)

  defp open_and_expired(queryable, now) do
    queryable
    |> where([s], is_nil(s.peer_id) and s.status == "open")
    |> where([s], not is_nil(s.expires_at) and s.expires_at <= ^now)
  end

  defp maybe_limit(query, max_rows) when is_integer(max_rows) and max_rows > 0,
    do: limit(query, ^max_rows)

  defp maybe_limit(query, _max_rows), do: query
end
