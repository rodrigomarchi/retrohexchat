defmodule RetroHexChat.VirtualSpace.Queries do
  @moduledoc """
  Database queries for virtual space sessions.
  """

  import Ecto.Query

  alias RetroHexChat.Repo
  alias RetroHexChat.VirtualSpace.Schema.Session

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

  @spec list_expired_sessions(DateTime.t()) :: [Session.t()]
  def list_expired_sessions(now) do
    Session
    |> where([s], s.status not in ^@terminal_statuses)
    |> where([s], not is_nil(s.expires_at) and s.expires_at < ^now)
    |> Repo.all()
  end

  @spec expire_session(Session.t()) :: {:ok, Session.t()} | {:error, Ecto.Changeset.t()}
  def expire_session(session) do
    update_status(session, "expired", %{
      closed_at: DateTime.utc_now(),
      closed_reason: "expired"
    })
  end
end
