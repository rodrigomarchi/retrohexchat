defmodule RetroHexChat.P2P do
  @moduledoc """
  Public API for the P2P bounded context.
  All external callers use this module.
  """

  alias RetroHexChat.P2P.{Queries, Service, SessionServer}
  alias RetroHexChat.P2P.Schema.Session

  @spec create_session(integer(), integer(), keyword()) ::
          {:ok, %{session: Session.t(), token: String.t()}} | {:error, String.t()}
  defdelegate create_session(creator_id, peer_id, opts \\ []), to: Service

  @spec join_session(String.t(), integer()) :: :ok | {:error, String.t()}
  defdelegate join_session(token, user_id), to: Service

  @spec close_session(String.t(), integer(), String.t()) :: :ok | {:error, String.t()}
  defdelegate close_session(token, user_id, reason), to: Service

  @spec get_session(String.t()) :: {:ok, Session.t()} | {:error, :not_found}
  def get_session(token) do
    case Queries.get_session_by_token(token) do
      nil -> {:error, :not_found}
      session -> {:ok, session}
    end
  end

  @spec transition_status(String.t(), atom()) :: :ok | {:error, String.t()}
  defdelegate transition_status(token, new_status), to: SessionServer, as: :transition

  @spec session_info(String.t()) :: {:ok, map()} | {:error, :not_found}
  defdelegate session_info(token), to: SessionServer, as: :get_state
end
