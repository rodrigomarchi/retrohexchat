defmodule RetroHexChat.Lobby do
  @moduledoc """
  Public API for the P2P lobby bounded context.

  A lobby is a single *persistent* P2P connection between two registered users
  that hosts audio, video, file transfer and games **concurrently**. All
  external callers use this module; WebRTC signal validation and ICE server
  configuration are reused from `RetroHexChat.P2P`.
  """

  alias RetroHexChat.Lobby.{Queries, Service, SessionServer}
  alias RetroHexChat.Lobby.Schema.Session
  alias RetroHexChat.Services.Queries, as: ServiceQueries

  @typedoc """
  Resolved, presentation-ready summary of a lobby session for a chat invite
  card. Nicks are resolved from `creator_id`/`peer_id`; timestamps are raw so
  the renderer can localize them to the viewer's timezone.
  """
  @type summary :: %{
          kind: :lobby,
          token: String.t(),
          status: String.t(),
          terminal?: boolean(),
          created_by: String.t() | nil,
          peer: String.t() | nil,
          created_at: DateTime.t() | nil,
          accepted_at: DateTime.t() | nil,
          connected_at: DateTime.t() | nil,
          closed_at: DateTime.t() | nil,
          closed_reason: String.t() | nil,
          duration_seconds: integer() | nil
        }

  @spec create_session(integer(), integer()) ::
          {:ok, %{session: Session.t(), token: String.t()}} | {:error, String.t()}
  defdelegate create_session(creator_id, peer_id), to: Service

  @spec can_create_session?(integer(), integer()) :: :ok | {:error, String.t()}
  defdelegate can_create_session?(creator_id, peer_id), to: Service

  @spec join_session(String.t(), integer()) :: :ok | {:error, String.t() | :already_joined}
  defdelegate join_session(token, user_id), to: Service

  @spec close_session(String.t(), integer(), String.t()) :: :ok | {:error, String.t()}
  defdelegate close_session(token, user_id, reason), to: Service

  @spec decline_session(String.t(), integer()) :: :ok | {:error, String.t()}
  defdelegate decline_session(token, user_id), to: Service

  @spec cancel_invite(String.t(), integer()) :: :ok | {:error, String.t()}
  defdelegate cancel_invite(token, user_id), to: Service

  @spec close_sessions_between(integer(), integer()) :: :ok
  defdelegate close_sessions_between(user_a_id, user_b_id), to: Service

  @spec propose_game(String.t(), integer(), String.t()) :: :ok | {:error, atom()}
  defdelegate propose_game(token, user_id, game_id), to: Service

  @spec respond_game(String.t(), integer(), boolean()) :: :ok | {:error, atom()}
  defdelegate respond_game(token, user_id, accepted?), to: Service

  @spec get_session(String.t()) :: {:ok, Session.t()} | {:error, :not_found}
  def get_session(token) do
    case Queries.get_session_by_token(token) do
      nil -> {:error, :not_found}
      session -> {:ok, session}
    end
  end

  @doc """
  Resolves a lobby session into a `t:summary/0` for rendering a rich invite card
  (creator/peer nicks, lifecycle timestamps, duration and close reason).
  """
  @spec session_summary(String.t()) :: {:ok, summary()} | {:error, :not_found}
  def session_summary(token) do
    case Queries.get_session_by_token(token) do
      nil ->
        {:error, :not_found}

      session ->
        {:ok,
         %{
           kind: :lobby,
           token: session.token,
           status: session.status,
           terminal?: Session.terminal?(session.status),
           created_by: ServiceQueries.get_nickname_by_id(session.creator_id),
           peer: ServiceQueries.get_nickname_by_id(session.peer_id),
           created_at: session.inserted_at,
           accepted_at: session.accepted_at,
           connected_at: session.connected_at,
           closed_at: session.closed_at,
           closed_reason: session.closed_reason,
           duration_seconds: session.duration_seconds
         }}
    end
  end

  @spec transition_status(String.t(), atom()) :: :ok | {:error, String.t()}
  defdelegate transition_status(token, new_status), to: SessionServer, as: :transition

  @spec session_info(String.t()) :: {:ok, map()} | {:error, :not_found}
  defdelegate session_info(token), to: SessionServer, as: :get_state

  @spec leave(String.t(), integer()) :: :ok
  defdelegate leave(token, user_id), to: SessionServer

  @spec record_activity(String.t()) :: :ok
  defdelegate record_activity(token), to: SessionServer

  @doc """
  The user's most recently updated non-terminal session, if any — the entry
  point for re-hydrating a P2P session after a LiveView reconnect, where the
  client no longer carries the token.
  """
  @spec active_session_for_user(integer()) :: Session.t() | nil
  def active_session_for_user(user_id) do
    user_id |> Queries.active_sessions_for_user() |> List.first()
  end

  @spec mark_webrtc_ready(String.t(), integer()) :: :ok | {:error, atom()}
  defdelegate mark_webrtc_ready(token, user_id), to: SessionServer

  @spec set_media(String.t(), integer(), boolean(), boolean()) :: :ok | {:error, atom()}
  defdelegate set_media(token, user_id, audio?, video?), to: SessionServer

  @spec end_game(String.t(), integer()) :: :ok | {:error, atom()}
  defdelegate end_game(token, user_id), to: SessionServer

  @spec finish_game(String.t(), integer(), map()) :: :ok | {:error, atom()}
  defdelegate finish_game(token, user_id, result), to: SessionServer
end
