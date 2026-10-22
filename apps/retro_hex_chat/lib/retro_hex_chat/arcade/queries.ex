defmodule RetroHexChat.Arcade.Queries do
  @moduledoc """
  Database queries for solo arcade sessions.
  """

  import Ecto.Query

  alias RetroHexChat.Arcade.Schema.SoloSession
  alias RetroHexChat.Repo
  alias RetroHexChat.Services.RegisteredNick
  alias RetroHexChat.StaleRecords

  @terminal_statuses ~w(finished closed expired)
  @stale StaleRecords.new(SoloSession, @terminal_statuses)

  @spec insert_session(map()) :: {:ok, SoloSession.t()} | {:error, Ecto.Changeset.t()}
  def insert_session(attrs) do
    %SoloSession{}
    |> SoloSession.changeset(attrs)
    |> Repo.insert()
  end

  @spec get_session_by_token(String.t()) :: SoloSession.t() | nil
  def get_session_by_token(token) do
    Repo.get_by(SoloSession, token: token)
  end

  @spec get_session(integer()) :: SoloSession.t() | nil
  def get_session(id) do
    Repo.get(SoloSession, id)
  end

  @spec update_status(SoloSession.t(), String.t(), map()) ::
          {:ok, SoloSession.t()} | {:error, Ecto.Changeset.t()}
  def update_status(session, new_status, extra_attrs \\ %{}) do
    attrs = Map.merge(extra_attrs, %{status: new_status})

    session
    |> SoloSession.status_changeset(attrs)
    |> Repo.update()
  end

  @spec active_session_exists?(integer()) :: boolean()
  def active_session_exists?(user_id) do
    SoloSession
    |> where([s], s.creator_id == ^user_id)
    |> where([s], s.status not in ^@terminal_statuses)
    |> Repo.exists?()
  end

  @spec get_active_session(integer()) :: SoloSession.t() | nil
  def get_active_session(user_id) do
    SoloSession
    |> where([s], s.creator_id == ^user_id)
    |> where([s], s.status not in ^@terminal_statuses)
    |> order_by([s], desc: s.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  # ── Plays: a session in which a game was started ──────────────

  @type play :: %{
          id: integer(),
          game_id: String.t(),
          nickname: String.t(),
          started_at: DateTime.t(),
          channel_message_id: integer() | nil,
          feed_message_id: integer() | nil
        }

  @spec attach_message(SoloSession.t(), map()) ::
          {:ok, SoloSession.t()} | {:error, Ecto.Changeset.t()}
  def attach_message(session, attrs) do
    session
    |> SoloSession.message_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Whether a line — in the game's channel or in `#arcade` — already said that
  `session`'s player started the same game at or after `since`.
  """
  @spec announced_since?(SoloSession.t(), DateTime.t()) :: boolean()
  def announced_since?(%SoloSession{} = session, since) do
    SoloSession
    |> where([s], s.creator_id == ^session.creator_id and s.game_id == ^session.game_id)
    |> where([s], s.id != ^session.id)
    |> where([s], not is_nil(s.channel_message_id) or not is_nil(s.feed_message_id))
    |> where([s], s.game_started_at >= ^since)
    |> Repo.exists?()
  end

  @doc "The plays announced by these lines, in a game's channel or in `#arcade`."
  @spec plays_by_message_ids([integer()]) :: [play()]
  def plays_by_message_ids([]), do: []

  def plays_by_message_ids(ids) do
    plays()
    |> where([s], s.channel_message_id in ^ids or s.feed_message_id in ^ids)
    |> Repo.all()
  end

  @doc "The latest plays of a game, newest first, by players whose account still exists."
  @spec recent_plays(String.t(), pos_integer()) :: [play()]
  def recent_plays(game_id, limit) do
    plays()
    |> where([s], s.game_id == ^game_id)
    |> order_by([s], desc: s.game_started_at, desc: s.id)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc "Who started a game most often since `since`, most first; ties by the latest play."
  @spec most_played(String.t(), DateTime.t(), pos_integer()) :: [
          %{nickname: String.t(), plays: pos_integer(), last_at: DateTime.t()}
        ]
  def most_played(game_id, since, limit) do
    SoloSession
    |> started()
    |> where([s], s.game_id == ^game_id and s.game_started_at >= ^since)
    |> join(:inner, [s], n in RegisteredNick, on: n.id == s.creator_id)
    |> group_by([s, n], [s.creator_id, n.nickname])
    |> order_by([s, n], desc: count(s.id), desc: max(s.game_started_at), asc: n.nickname)
    |> limit(^limit)
    |> select([s, n], %{nickname: n.nickname, plays: count(s.id), last_at: max(s.game_started_at)})
    |> Repo.all()
  end

  @doc "How many times a game was started since `since`."
  @spec play_count(String.t(), DateTime.t()) :: non_neg_integer()
  def play_count(game_id, since) do
    SoloSession
    |> started()
    |> where([s], s.game_id == ^game_id and s.game_started_at >= ^since)
    |> Repo.aggregate(:count)
  end

  @doc """
  How many times each game was started between `since` and `until`, and by
  how many people, keyed by game.
  """
  @spec play_counts(DateTime.t(), DateTime.t()) :: %{
          String.t() => %{plays: pos_integer(), people: pos_integer()}
        }
  def play_counts(since, until) do
    SoloSession
    |> started()
    |> where([s], s.game_started_at >= ^since and s.game_started_at < ^until)
    |> group_by([s], s.game_id)
    |> select([s], {s.game_id, %{plays: count(s.id), people: count(s.creator_id, :distinct)}})
    |> Repo.all()
    |> Map.new()
  end

  @doc "How often one player started a game, and when they first and last did."
  @spec player_plays(String.t(), integer()) :: %{
          plays: non_neg_integer(),
          first_at: DateTime.t() | nil,
          last_at: DateTime.t() | nil
        }
  def player_plays(game_id, player_id) do
    SoloSession
    |> started()
    |> where([s], s.game_id == ^game_id and s.creator_id == ^player_id)
    |> select([s], %{
      plays: count(s.id),
      first_at: min(s.game_started_at),
      last_at: max(s.game_started_at)
    })
    |> Repo.one()
  end

  defp started(query), do: where(query, [s], not is_nil(s.game_started_at))

  defp plays do
    SoloSession
    |> started()
    |> join(:inner, [s], n in RegisteredNick, on: n.id == s.creator_id)
    |> select([s, n], %{
      id: s.id,
      game_id: s.game_id,
      nickname: n.nickname,
      started_at: s.game_started_at,
      channel_message_id: s.channel_message_id,
      feed_message_id: s.feed_message_id
    })
  end

  @spec list_stale_sessions(DateTime.t(), keyword()) :: [SoloSession.t()]
  def list_stale_sessions(before_datetime, opts \\ []),
    do: StaleRecords.list(@stale, before_datetime, opts)

  @spec stale_session_count(DateTime.t()) :: non_neg_integer()
  def stale_session_count(before_datetime), do: StaleRecords.count(@stale, before_datetime)

  @spec expire_stale_session(SoloSession.t(), DateTime.t()) ::
          {:ok, :expired | :skipped} | {:error, term()}
  def expire_stale_session(%SoloSession{id: id}, before_datetime),
    do: StaleRecords.expire(@stale, id, before_datetime)
end
