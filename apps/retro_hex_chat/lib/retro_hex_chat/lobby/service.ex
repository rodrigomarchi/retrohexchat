defmodule RetroHexChat.Lobby.Service do
  @moduledoc """
  Orchestrates universal lobby operations: policy check → persist → process → notify.
  """
  use Gettext, backend: RetroHexChat.Gettext

  require Logger

  alias RetroHexChat.Lobby.{Policy, Queries, SessionServer, Supervisor}
  alias RetroHexChat.Lobby.Schema.Session
  alias RetroHexChat.P2P.RateLimiter

  @pubsub RetroHexChat.PubSub

  @spec create_session(integer(), integer()) ::
          {:ok, %{session: Session.t(), token: String.t()}} | {:error, String.t()}
  def create_session(creator_id, peer_id) do
    with :ok <- check_rate_limit(creator_id),
         :ok <- Policy.can_create?(creator_id, peer_id),
         {:ok, session} <- insert_session(creator_id, peer_id),
         {:ok, _pid} <- Supervisor.start_child(session.token) do
      Logger.info(
        "Lobby session created: token=#{session.token}, creator=#{creator_id}, peer=#{peer_id}"
      )

      notify_peer(peer_id, session.token, creator_id)
      {:ok, %{session: session, token: session.token}}
    else
      {:error, reason} = error ->
        Logger.info("Lobby session denied: reason=#{inspect(reason)}, creator=#{creator_id}")
        error
    end
  end

  @spec join_session(String.t(), integer()) :: :ok | {:error, String.t()}
  def join_session(token, user_id) do
    with {:ok, session} <- fetch_session(token),
         :ok <- Policy.can_join?(user_id, session) do
      SessionServer.join(token, user_id)
    end
  end

  @spec close_session(String.t(), integer(), String.t()) :: :ok | {:error, String.t()}
  def close_session(token, user_id, reason) do
    with {:ok, session} <- fetch_session(token),
         :ok <- Policy.can_close?(user_id, session) do
      close_session_server(session, token, user_id, reason)
    end
  end

  @spec close_sessions_between(integer(), integer()) :: :ok
  def close_sessions_between(user_a_id, user_b_id) do
    for session <- Queries.active_sessions_between(user_a_id, user_b_id) do
      close_session_server(session, session.token, user_a_id, "user_blocked")
    end

    :ok
  end

  @spec send_lobby_message(String.t(), integer(), String.t()) :: :ok | {:error, atom()}
  def send_lobby_message(token, user_id, content) do
    nick = get_nickname(user_id)
    SessionServer.send_message(token, user_id, nick || "unknown", content)
  end

  @spec propose_game(String.t(), integer(), String.t()) :: :ok | {:error, atom()}
  def propose_game(token, user_id, game_id) do
    nick = get_nickname(user_id)
    SessionServer.propose_game(token, user_id, nick || "unknown", game_id)
  end

  @spec respond_game(String.t(), integer(), boolean()) :: :ok | {:error, atom()}
  def respond_game(token, user_id, accepted?) do
    nick = get_nickname(user_id)
    SessionServer.respond_game(token, user_id, nick || "unknown", accepted?)
  end

  @spec start_signaling(integer(), integer()) :: %{creator_payload: map(), peer_payload: map()}
  def start_signaling(creator_id, peer_id) do
    creator_ice = RetroHexChat.P2P.ice_servers(to_string(creator_id))
    peer_ice = RetroHexChat.P2P.ice_servers(to_string(peer_id))

    %{
      creator_payload: %{ice_servers: creator_ice, role: "initiator"},
      peer_payload: %{ice_servers: peer_ice}
    }
  end

  # --- Private helpers ---

  defp close_session_server(session, token, user_id, reason) do
    case SessionServer.close(token, user_id, reason) do
      :ok -> :ok
      {:error, message} -> handle_close_error(session, reason, message)
    end
  end

  defp handle_close_error(session, reason, message) do
    if session_process_not_running?(message) do
      mark_session_closed(session, reason)
      :ok
    else
      {:error, message}
    end
  end

  defp mark_session_closed(session, reason) do
    Queries.update_status(session, "closed", %{
      closed_at: DateTime.utc_now(),
      closed_reason: reason
    })
  end

  defp session_process_not_running?(message) do
    message in ["Session process not running", dgettext("lobby", "Session process not running")]
  end

  defp insert_session(creator_id, peer_id) do
    db_token = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)

    case Queries.insert_session(%{
           token: db_token,
           creator_id: creator_id,
           peer_id: peer_id,
           status: "pending"
         }) do
      {:ok, _session} = ok ->
        ok

      {:error, changeset} ->
        Logger.warning("Failed to insert lobby session: #{inspect(changeset.errors)}")
        {:error, dgettext("lobby", "Failed to create lobby")}
    end
  end

  defp fetch_session(token) do
    case Queries.get_session_by_token(token) do
      nil -> {:error, dgettext("lobby", "Lobby not found")}
      session -> {:ok, session}
    end
  end

  defp notify_peer(peer_id, token, creator_id) do
    peer_nick = get_nickname(peer_id)
    creator_nick = get_nickname(creator_id)

    if peer_nick do
      Phoenix.PubSub.broadcast(@pubsub, "user:#{peer_nick}", %{
        event: "lobby_invite",
        payload: %{token: token, from: creator_nick}
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
        {:error,
         dgettext("lobby", "Too many lobbies created. Try again in %{minutes} minutes",
           minutes: remaining_seconds
         )}
    end
  end
end
