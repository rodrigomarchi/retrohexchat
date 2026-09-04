defmodule RetroHexChat.Arcade.Queries do
  @moduledoc """
  Database queries for solo arcade sessions.
  """

  import Ecto.Query

  alias RetroHexChat.Arcade.Schema.SoloSession
  alias RetroHexChat.Repo
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
