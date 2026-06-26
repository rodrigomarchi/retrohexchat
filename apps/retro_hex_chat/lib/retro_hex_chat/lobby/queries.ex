defmodule RetroHexChat.Lobby.Queries do
  @moduledoc """
  Database queries for universal lobby sessions.
  """

  import Ecto.Query

  alias RetroHexChat.Lobby.Schema.Session
  alias RetroHexChat.Repo

  @terminal_statuses ~w(closed expired failed)

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

  @spec list_stale_sessions(DateTime.t()) :: [Session.t()]
  def list_stale_sessions(before_datetime) do
    Session
    |> where([s], s.status not in ^@terminal_statuses)
    |> where([s], s.updated_at < ^before_datetime)
    |> Repo.all()
  end

  @spec expire_session(Session.t()) :: {:ok, Session.t()} | {:error, Ecto.Changeset.t()}
  def expire_session(session) do
    update_status(session, "expired", %{
      closed_at: DateTime.utc_now(),
      closed_reason: "stale_cleanup"
    })
  end
end
