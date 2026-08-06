defmodule RetroHexChat.Arcade.Queries do
  @moduledoc """
  Database queries for solo arcade sessions.
  """

  import Ecto.Query

  alias RetroHexChat.Arcade.Schema.SoloSession
  alias RetroHexChat.Repo

  @terminal_statuses ~w(finished closed expired)

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

  @spec list_stale_sessions(DateTime.t(), keyword()) :: [SoloSession.t()]
  def list_stale_sessions(before_datetime, opts \\ []) do
    SoloSession
    |> stale_sessions_query(before_datetime)
    |> order_by([s], asc: s.updated_at, asc: s.id)
    |> maybe_limit(Keyword.get(opts, :limit))
    |> Repo.all()
  end

  @spec stale_session_count(DateTime.t()) :: non_neg_integer()
  def stale_session_count(before_datetime) do
    SoloSession
    |> stale_sessions_query(before_datetime)
    |> Repo.aggregate(:count, :id)
  end

  @spec expire_session(SoloSession.t()) :: {:ok, SoloSession.t()} | {:error, Ecto.Changeset.t()}
  def expire_session(session) do
    update_status(session, "expired", %{
      closed_at: DateTime.utc_now(),
      closed_reason: "stale_cleanup"
    })
  end

  @spec expire_stale_session(SoloSession.t(), DateTime.t()) ::
          {:ok, :expired | :skipped} | {:error, term()}
  def expire_stale_session(%SoloSession{id: id}, before_datetime) do
    now = DateTime.utc_now()

    {count, _records} =
      SoloSession
      |> where([s], s.id == ^id)
      |> stale_sessions_query(before_datetime)
      |> Repo.update_all(
        set: [
          status: "expired",
          closed_at: now,
          closed_reason: "stale_cleanup",
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

  defp stale_sessions_query(queryable, before_datetime) do
    queryable
    |> where([s], s.status not in ^@terminal_statuses)
    |> where([s], s.updated_at < ^before_datetime)
  end

  defp maybe_limit(query, max_rows) when is_integer(max_rows) and max_rows > 0,
    do: limit(query, ^max_rows)

  defp maybe_limit(query, _max_rows), do: query
end
