defmodule RetroHexChat.Lobby do
  @moduledoc """
  Public API for the universal lobby bounded context.

  A lobby is a single *persistent* P2P connection between two registered users
  that hosts audio, video, file transfer and games **concurrently**. All
  external callers use this module; WebRTC signal validation and ICE server
  configuration are reused from `RetroHexChat.P2P`.
  """

  alias RetroHexChat.Lobby.{Queries, Service, SessionServer}
  alias RetroHexChat.Lobby.Schema.Session

  @spec create_session(integer(), integer()) ::
          {:ok, %{session: Session.t(), token: String.t()}} | {:error, String.t()}
  defdelegate create_session(creator_id, peer_id), to: Service

  @spec join_session(String.t(), integer()) :: :ok | {:error, String.t()}
  defdelegate join_session(token, user_id), to: Service

  @spec close_session(String.t(), integer(), String.t()) :: :ok | {:error, String.t()}
  defdelegate close_session(token, user_id, reason), to: Service

  @spec close_sessions_between(integer(), integer()) :: :ok
  defdelegate close_sessions_between(user_a_id, user_b_id), to: Service

  @spec send_lobby_message(String.t(), integer(), String.t()) :: :ok | {:error, atom()}
  defdelegate send_lobby_message(token, user_id, content), to: Service

  @spec propose_game(String.t(), integer(), String.t()) :: :ok | {:error, atom()}
  defdelegate propose_game(token, user_id, game_id), to: Service

  @spec respond_game(String.t(), integer(), boolean()) :: :ok | {:error, atom()}
  defdelegate respond_game(token, user_id, accepted?), to: Service

  @spec start_signaling(integer(), integer()) :: %{creator_payload: map(), peer_payload: map()}
  defdelegate start_signaling(creator_id, peer_id), to: Service

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

  @spec leave(String.t(), integer()) :: :ok
  defdelegate leave(token, user_id), to: SessionServer

  @spec mark_webrtc_ready(String.t(), integer()) :: :ok | {:error, atom()}
  defdelegate mark_webrtc_ready(token, user_id), to: SessionServer

  @spec set_media(String.t(), integer(), boolean(), boolean()) :: :ok | {:error, atom()}
  defdelegate set_media(token, user_id, audio?, video?), to: SessionServer

  @spec end_game(String.t(), integer()) :: :ok | {:error, atom()}
  defdelegate end_game(token, user_id), to: SessionServer
end
