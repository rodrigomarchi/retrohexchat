defmodule RetroHexChat.P2P.Service do
  @moduledoc """
  Orchestrates P2P session operations: policy check → persist → process → notify.
  """
  use Gettext, backend: RetroHexChat.Gettext

  require Logger

  alias RetroHexChat.P2P.{Policy, Queries, RateLimiter, SessionServer, SessionToken, Supervisor}
  alias RetroHexChat.P2P.Schema.Session

  @pubsub RetroHexChat.PubSub

  @spec create_session(integer(), integer(), keyword()) ::
          {:ok, %{session: Session.t(), token: String.t()}} | {:error, String.t()}
  def create_session(creator_id, peer_id, opts \\ []) do
    session_type = Keyword.get(opts, :session_type, "generic")

    with :ok <- check_rate_limit(creator_id),
         :ok <- Policy.can_create?(creator_id, peer_id),
         token = SessionToken.sign(creator_id, peer_id, 0),
         {:ok, session} <- insert_session(token, creator_id, peer_id, session_type),
         {:ok, _pid} <- Supervisor.start_child(session.token) do
      Logger.info(
        "P2P session created: token=#{session.token}, creator=#{creator_id}, peer=#{peer_id}, type=#{session_type}"
      )

      notify_peer(peer_id, session.token, creator_id, session_type)
      {:ok, %{session: session, token: session.token}}
    else
      {:error, reason} = error ->
        Logger.info("P2P session denied: reason=#{inspect(reason)}, creator=#{creator_id}")
        error
    end
  end

  @spec join_session(String.t(), integer()) :: :ok | {:error, String.t()}
  def join_session(token, user_id) do
    with {:ok, _data} <- verify_token(token),
         {:ok, session} <- fetch_session(token),
         :ok <- Policy.can_join?(user_id, session) do
      SessionServer.join(token, user_id)
    end
  end

  @spec close_session(String.t(), integer(), String.t()) :: :ok | {:error, String.t()}
  def close_session(token, user_id, reason) do
    with {:ok, _data} <- verify_token(token),
         {:ok, session} <- fetch_session(token),
         :ok <- Policy.can_close?(user_id, session) do
      case SessionServer.close(token, user_id, reason) do
        :ok ->
          :ok

        {:error, message} ->
          if session_process_not_running?(message) do
            # GenServer not running — update DB directly
            now = DateTime.utc_now()

            Queries.update_status(session, "closed", %{
              closed_at: now,
              closed_reason: reason
            })

            :ok
          else
            {:error, message}
          end

        error ->
          error
      end
    end
  end

  @spec close_sessions_between(integer(), integer()) :: :ok
  def close_sessions_between(user_a_id, user_b_id) do
    sessions = Queries.active_sessions_between(user_a_id, user_b_id)

    for session <- sessions do
      case SessionServer.close(session.token, user_a_id, "user_blocked") do
        :ok ->
          :ok

        {:error, message} ->
          if session_process_not_running?(message) do
            now = DateTime.utc_now()

            Queries.update_status(session, "closed", %{
              closed_at: now,
              closed_reason: "user_blocked"
            })
          end

        _error ->
          :ok
      end
    end

    :ok
  end

  defp session_process_not_running?(message) do
    message in ["Session process not running", gettext("Session process not running")]
  end

  @valid_action_types ~w(audio_call video_call file_transfer)

  @spec send_lobby_message(String.t(), integer(), String.t()) :: :ok | {:error, atom()}
  def send_lobby_message(token, user_id, content) do
    nick = get_nickname(user_id)
    SessionServer.send_message(token, user_id, nick || "unknown", content)
  end

  @spec request_action(String.t(), integer(), String.t()) :: :ok | {:error, atom()}
  def request_action(token, user_id, action_type) do
    if action_type in @valid_action_types do
      nick = get_nickname(user_id)
      SessionServer.request_action(token, user_id, nick || "unknown", action_type)
    else
      {:error, :invalid_action_type}
    end
  end

  @spec respond_action(String.t(), integer(), boolean()) :: :ok | {:error, atom()}
  def respond_action(token, user_id, accepted?) do
    nick = get_nickname(user_id)
    SessionServer.respond_action(token, user_id, nick || "unknown", accepted?)
  end

  @spec start_signaling(String.t(), integer(), integer()) :: %{
          creator_payload: map(),
          peer_payload: map()
        }
  def start_signaling(_token, creator_id, peer_id) do
    creator_ice = RetroHexChat.P2P.ice_servers(to_string(creator_id))
    peer_ice = RetroHexChat.P2P.ice_servers(to_string(peer_id))

    %{
      creator_payload: %{ice_servers: creator_ice, role: "initiator"},
      peer_payload: %{ice_servers: peer_ice}
    }
  end

  # --- Private Helpers ---

  defp insert_session(_signed_token, creator_id, peer_id, session_type) do
    # Use a truncated token for the DB (Phoenix.Token can be long)
    db_token = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)

    case Queries.insert_session(%{
           token: db_token,
           creator_id: creator_id,
           peer_id: peer_id,
           session_type: session_type,
           status: "pending"
         }) do
      {:ok, _session} = ok ->
        ok

      {:error, changeset} ->
        Logger.warning("Failed to insert P2P session: #{inspect(changeset.errors)}")
        {:error, gettext("Failed to create session")}
    end
  end

  defp verify_token(_token_string) do
    # First try to find the session by token (DB token)
    # SessionToken.verify is for signed invite tokens, not DB lookup tokens
    # For join/close, we look up by the DB token directly
    {:ok, %{}}
  end

  defp fetch_session(token) do
    case Queries.get_session_by_token(token) do
      nil -> {:error, gettext("Session not found")}
      session -> {:ok, session}
    end
  end

  defp notify_peer(peer_id, token, creator_id, session_type) do
    peer_nick = get_nickname(peer_id)
    creator_nick = get_nickname(creator_id)

    if peer_nick do
      Phoenix.PubSub.broadcast(@pubsub, "user:#{peer_nick}", %{
        event: "p2p_invite",
        payload: %{
          token: token,
          from: creator_nick,
          session_type: session_type
        }
      })
    end
  end

  defp get_nickname(user_id) do
    import Ecto.Query

    from(r in "registered_nicks", where: r.id == ^user_id, select: r.nickname)
    |> RetroHexChat.Repo.one()
  end

  defp check_rate_limit(user_id) do
    case RateLimiter.check_session_rate(user_id) do
      :ok ->
        :ok

      {:error, {:rate_limited, remaining_seconds}} ->
        {:error, "Too many sessions created. Try again in #{remaining_seconds} minutes"}
    end
  end
end
