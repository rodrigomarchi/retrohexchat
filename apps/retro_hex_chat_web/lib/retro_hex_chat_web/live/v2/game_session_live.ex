defmodule RetroHexChatWeb.V2.GameSessionLive do
  @moduledoc """
  v2 multiplayer game session — uses new UI components.
  Provides game selection, bilateral consent, WebRTC signaling for DataChannel,
  and the game canvas container.
  """
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  require Logger

  import RetroHexChatWeb.Components.UI.AppHeader
  import RetroHexChatWeb.Components.UI.MenuBarApp
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]
  import RetroHexChatWeb.Components.UI.AboutDialog
  import RetroHexChatWeb.Components.UI.GameLobby
  import RetroHexChatWeb.Components.UI.GameCanvas
  import RetroHexChatWeb.Components.UI.GameSessionEnded

  alias RetroHexChat.Games
  alias RetroHexChat.Games.Schema.GameSession
  alias RetroHexChat.P2P.SignalingRateLimit
  alias RetroHexChatWeb.V2.SessionHelpers

  @pubsub RetroHexChat.PubSub

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(%{"token" => token}, session, socket) do
    nickname = session["chat_nickname"]

    with {:ok, socket} <- SessionHelpers.verify_nickname(socket, nickname),
         {:ok, user_id} <- SessionHelpers.resolve_user_id(nickname),
         {:ok, db_session} <- fetch_session(token),
         :ok <- SessionHelpers.verify_participant(user_id, db_session),
         :ok <- verify_not_terminal(db_session) do
      mount_game_lobby(socket, token, nickname, user_id, db_session)
    else
      {:expired, reason, metadata} ->
        {:ok,
         assign(socket,
           expired: true,
           expired_reason: expired_reason_label(reason),
           game_result: metadata["result"]
         )}

      {:redirect, redirect_socket} when is_struct(redirect_socket) ->
        {:ok, redirect_socket}

      {:redirect, _} ->
        {:ok, push_navigate(socket, to: ~p"/chat")}
    end
  end

  # --- PubSub Handlers ---

  @impl true
  def handle_info(%{event: "game_peer_joined", payload: %{user_id: uid}}, socket) do
    if uid != socket.assigns.user_id do
      Phoenix.PubSub.broadcast(
        @pubsub,
        "game:#{socket.assigns.token}",
        %{
          event: "game_client_info",
          payload: %{from: socket.assigns.user_id, info: socket.assigns.local_info}
        }
      )

      {:noreply, assign(socket, peer_online: true)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(
        %{event: "game_client_info", payload: %{from: from_id, info: info}},
        socket
      ) do
    if from_id != socket.assigns.user_id do
      {:noreply, assign(socket, peer_info: info)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(%{event: "game_status_changed", payload: %{status: "lobby"}}, socket) do
    {:noreply, assign(socket, session_status: "lobby")}
  end

  def handle_info(
        %{event: "game_status_changed", payload: %{status: "playing", game_id: game_id}},
        socket
      ) do
    game_name =
      case Games.get_game(game_id) do
        {:ok, game} -> game.name
        _ -> game_id
      end

    socket =
      socket
      |> assign(
        session_status: "playing",
        game_id: game_id,
        game_name: game_name
      )
      |> start_webrtc()

    {:noreply, socket}
  end

  def handle_info(%{event: "game_status_changed", payload: %{status: status}}, socket) do
    if GameSession.terminal?(status) do
      notify_session_ended(socket, status)

      if socket.assigns.session_closed do
        # We initiated the close — close tab
        {:noreply,
         socket
         |> push_event("game_end", %{})
         |> push_event("game_close_tab", %{})}
      else
        # Other peer ended — show session ended screen
        {duration, game_result} = fetch_session_result(socket)

        {:noreply,
         socket
         |> push_event("game_end", %{})
         |> assign(
           session_ended_reason: session_ended_label(status),
           session_duration: duration,
           game_result: game_result,
           session_closed: true
         )}
      end
    else
      {:noreply, assign(socket, session_status: status)}
    end
  end

  def handle_info(%{event: "game_select_request", payload: request}, socket) do
    game_name =
      case Games.get_game(request.game_id) do
        {:ok, game} -> game.name
        _ -> request.game_id
      end

    {:noreply, assign(socket, game_request: Map.put(request, :game_name, game_name))}
  end

  def handle_info(%{event: "game_select_response", payload: _response}, socket) do
    {:noreply, assign(socket, game_request: nil)}
  end

  def handle_info(%{event: "game_select_expired"}, socket) do
    {:noreply, assign(socket, game_request: nil)}
  end

  def handle_info(%{event: "game_session_closed", payload: %{reason: reason}}, socket) do
    if socket.assigns.session_closed do
      # We initiated the close — close tab
      {:noreply, push_event(socket, "game_close_tab", %{})}
    else
      # Other peer closed — show session ended screen
      notify_session_ended(socket, reason)
      {duration, game_result} = fetch_session_result(socket)

      {:noreply,
       assign(socket,
         session_ended_reason: session_ended_label(reason),
         session_duration: duration,
         game_result: game_result,
         session_closed: true
       )}
    end
  end

  def handle_info(
        %{event: "game_inactivity_warning", payload: %{expires_in_seconds: _secs}},
        socket
      ) do
    {:noreply, assign(socket, inactivity_warning: true)}
  end

  def handle_info(
        %{event: "game_signal", payload: %{from: from_id} = payload},
        socket
      ) do
    if from_id != socket.assigns.user_id do
      {:noreply, push_event(socket, "game_signal", payload)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  # --- Client Event Handlers ---

  @impl true
  def handle_event("select_game", %{"game_id" => game_id}, socket) do
    Games.select_game(socket.assigns.token, socket.assigns.user_id, game_id)
    {:noreply, socket}
  end

  def handle_event("respond_game", %{"accepted" => accepted}, socket) do
    accepted_bool = accepted == "true" or accepted == true
    Games.respond_game(socket.assigns.token, socket.assigns.user_id, accepted_bool)
    {:noreply, socket}
  end

  def handle_event("close_session", _params, socket) do
    Games.close_session(socket.assigns.token, socket.assigns.user_id, "user_closed")

    {:noreply,
     socket
     |> assign(session_closed: true)
     |> push_event("game_close_tab", %{})}
  end

  def handle_event("end_game", _params, socket) do
    Games.close_session(socket.assigns.token, socket.assigns.user_id, "game_ended")

    {:noreply,
     socket
     |> assign(session_closed: true)
     |> push_event("game_close_tab", %{})}
  end

  def handle_event("game_signal", params, socket) do
    rate_limiter = SignalingRateLimit.configured_module()

    with :ok <- rate_limiter.check_signal_rate(socket.assigns.token, socket.assigns.user_id),
         {:ok, validated} <- RetroHexChat.P2P.validate_signal(params) do
      payload = Map.put(validated, :from, socket.assigns.user_id)

      Phoenix.PubSub.broadcast(
        @pubsub,
        "game:#{socket.assigns.token}",
        %{event: "game_signal", payload: payload}
      )

      {:noreply, socket}
    else
      {:error, :rate_limited} -> {:noreply, socket}
      {:error, :invalid_signal} -> {:noreply, socket}
    end
  end

  def handle_event("game_result", %{"score" => score, "winner" => winner}, socket) do
    result = %{"score" => score, "winner" => winner}
    Games.finish_game(socket.assigns.token, socket.assigns.user_id, result)
    {:noreply, socket}
  end

  def handle_event("game_connected", _params, socket) do
    Logger.info("Game WebRTC connected: token=#{socket.assigns.token}")

    socket =
      socket
      |> assign(webrtc_state: "Connected")
      |> push_event("game_start", %{
        game_id: socket.assigns.game_id,
        is_host: socket.assigns.role == :creator
      })

    {:noreply, socket}
  end

  def handle_event("game_failed", %{"reason" => reason}, socket) do
    Logger.warning("Game WebRTC failed: #{reason}, token=#{socket.assigns.token}")
    {:noreply, assign(socket, webrtc_state: "failed")}
  end

  def handle_event("game_rtc_state", %{"state" => state}, socket) do
    {:noreply, assign(socket, webrtc_state: SessionHelpers.webrtc_state_label(state, nil))}
  end

  def handle_event("game_leave", _params, socket) do
    unless socket.assigns[:session_closed] do
      Games.close_session(socket.assigns.token, socket.assigns.user_id, "tab_closed")
    end

    {:noreply, assign(socket, session_closed: true)}
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  @impl true
  def terminate(_reason, socket) do
    if connected?(socket) and is_binary(socket.assigns[:token]) and
         !socket.assigns[:session_closed] do
      token = socket.assigns.token
      user_id = socket.assigns[:user_id]

      notify_session_ended(socket, "disconnected")

      if user_id do
        try do
          Games.close_session(token, user_id, "disconnected")
        rescue
          _ -> :ok
        end
      end
    end

    :ok
  end

  # --- Private Helpers ---

  defp mount_game_lobby(socket, token, nickname, user_id, db_session) do
    role = if user_id == db_session.creator_id, do: :creator, else: :peer

    local_info = SessionHelpers.parse_client_info(get_connect_params(socket))

    if connected?(socket) do
      Phoenix.PubSub.subscribe(@pubsub, "game:#{token}")
      Games.join_session(token, user_id)

      Phoenix.PubSub.broadcast(
        @pubsub,
        "game:#{token}",
        %{event: "game_client_info", payload: %{from: user_id, info: local_info}}
      )
    end

    peer_nick = SessionHelpers.resolve_peer_nick(user_id, db_session)
    peer_online = fetch_peer_online(token, role)

    games = Games.list_games()

    {game_id, game_name} = resolve_game_info(db_session)

    socket =
      assign(socket,
        token: token,
        nickname: nickname,
        user_id: user_id,
        peer_nick: peer_nick,
        peer_online: peer_online,
        role: role,
        local_info: local_info,
        peer_info: %{},
        games: games,
        game_request: nil,
        session_status: db_session.status,
        inactivity_warning: false,
        webrtc_state: nil,
        game_id: game_id,
        game_name: game_name,
        session_closed: false,
        session_ended_reason: nil,
        session_duration: nil
      )

    {:ok, socket}
  end

  defp fetch_session(token) do
    case Games.get_session(token) do
      {:ok, session} -> {:ok, session}
      {:error, :not_found} -> {:redirect, nil}
    end
  end

  defp verify_not_terminal(session) do
    if GameSession.terminal?(session.status) do
      {:expired, session.closed_reason || session.status, session.metadata || %{}}
    else
      :ok
    end
  end

  defp fetch_peer_online(token, role) do
    case Games.session_info(token) do
      {:ok, state} ->
        if role == :creator, do: state.peer_joined, else: state.creator_joined

      _ ->
        false
    end
  end

  defp resolve_game_info(%{status: "playing", game_id: game_id}) when is_binary(game_id) do
    game_name =
      case Games.get_game(game_id) do
        {:ok, game} -> game.name
        _ -> game_id
      end

    {game_id, game_name}
  end

  defp resolve_game_info(_session), do: {nil, nil}

  defp start_webrtc(socket) do
    user_id = socket.assigns.user_id
    role = socket.assigns.role
    ice_servers = Games.ice_servers(to_string(user_id))

    case role do
      :creator ->
        push_event(socket, "game_start_offer", %{
          ice_servers: ice_servers,
          role: "initiator",
          turn_only: false
        })

      :peer ->
        push_event(socket, "game_start_answer", %{
          ice_servers: ice_servers,
          turn_only: false
        })
    end
  end

  defp expired_reason_label("user_closed"), do: dgettext("games", "Session closed by user.")
  defp expired_reason_label("game_ended"), do: dgettext("games", "Game ended.")
  defp expired_reason_label("rejected"), do: dgettext("games", "Game invite was rejected.")
  defp expired_reason_label("tab_closed"), do: dgettext("games", "Session closed (disconnected).")

  defp expired_reason_label("disconnected"),
    do: dgettext("games", "Session closed (disconnected).")

  defp expired_reason_label("expired"),
    do: dgettext("games", "Session expired due to inactivity.")

  defp expired_reason_label("pending_timeout"),
    do: dgettext("games", "Session expired — peer did not join.")

  defp expired_reason_label("lobby_inactivity"),
    do: dgettext("games", "Session expired due to inactivity.")

  defp expired_reason_label(_reason), do: dgettext("games", "Game session ended.")

  defp fetch_session_result(socket) do
    case socket.assigns[:token] && Games.get_session(socket.assigns.token) do
      {:ok, s} -> {s.duration_seconds, s.metadata["result"]}
      _ -> {nil, nil}
    end
  end

  defp session_ended_label("game_over"), do: dgettext("games", "Game over.")
  defp session_ended_label("finished"), do: dgettext("games", "Game finished.")
  defp session_ended_label("user_closed"), do: dgettext("games", "Session closed by user.")
  defp session_ended_label("disconnected"), do: dgettext("games", "Peer disconnected.")

  defp session_ended_label("inactivity"),
    do: dgettext("games", "Session closed due to inactivity.")

  defp session_ended_label("lobby_inactivity"),
    do: dgettext("games", "Session closed due to inactivity.")

  defp session_ended_label(reason), do: expired_reason_label(reason)

  defp notify_session_ended(socket, reason) do
    nickname = socket.assigns[:nickname]
    peer_nick = socket.assigns[:peer_nick]
    game_name = socket.assigns[:game_name]
    token = socket.assigns[:token]

    if nickname do
      {duration_secs, game_result} =
        case token && RetroHexChat.Games.get_session(token) do
          {:ok, s} -> {s.duration_seconds, s.metadata["result"]}
          _ -> {nil, nil}
        end

      Phoenix.PubSub.broadcast(
        @pubsub,
        "user:#{nickname}",
        %{
          event: "game_session_ended",
          payload: %{
            peer_nick: peer_nick || "unknown",
            game_name: game_name,
            reason: reason,
            duration_seconds: duration_secs,
            game_result: game_result
          }
        }
      )
    end
  rescue
    _ -> :ok
  end
end
