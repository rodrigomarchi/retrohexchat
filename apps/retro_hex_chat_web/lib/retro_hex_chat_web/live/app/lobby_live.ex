defmodule RetroHexChatWeb.App.LobbyLive do
  @moduledoc """
  Universal P2P lobby.

  A single, persistent WebRTC connection between two peers that hosts every
  feature concurrently: ephemeral chat, self-controlled audio/video, file
  transfer and games — all at the same time. Unlike `P2PSessionLive`, ending a
  feature never closes the session; only an explicit leave or inactivity does.
  """
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  require Logger

  import RetroHexChatWeb.Components.UI.Lobby.UniversalLobby

  alias RetroHexChat.Chat.Schemas.UserPreference
  alias RetroHexChat.Games.Catalog
  alias RetroHexChat.Lobby
  alias RetroHexChat.Lobby.Schema.Session
  alias RetroHexChat.P2P
  alias RetroHexChat.P2P.SignalingRateLimit
  alias RetroHexChatWeb.App.SessionHelpers

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
      mount_lobby(socket, token, nickname, user_id, db_session)
    else
      {:expired, reason} ->
        {:ok,
         assign(socket,
           expired: true,
           session_closed: false,
           ended_reason: expired_reason_label(reason)
         )}

      {:redirect, redirect_socket} when is_struct(redirect_socket) ->
        {:ok, redirect_socket}

      {:redirect, _} ->
        {:ok, push_navigate(socket, to: ~p"/chat")}
    end
  end

  # --- PubSub handlers (topic "lobby:#{token}") ---

  @impl true
  def handle_info(%{event: "lobby_status_changed", payload: %{status: "lobby"}}, socket) do
    {:noreply, assign(socket, session_status: "lobby")}
  end

  # The SessionServer fires this once BOTH peers' hooks are ready and the session
  # is in "lobby" — only now is it safe to exchange the offer/answer.
  def handle_info(%{event: "lobby_start_signaling"}, socket) do
    {:noreply, maybe_start_webrtc(socket)}
  end

  def handle_info(%{event: "lobby_status_changed", payload: %{status: "connected"}}, socket) do
    {:noreply,
     assign(socket,
       session_status: "connected",
       connection_label: connected_label(),
       ever_connected: true
     )}
  end

  def handle_info(%{event: "lobby_status_changed", payload: %{status: status}}, socket) do
    if Session.terminal?(status) do
      {:noreply, assign(socket, session_closed: true, ended_reason: expired_reason_label(status))}
    else
      {:noreply, assign(socket, session_status: status)}
    end
  end

  def handle_info(%{event: "lobby_peer_joined", payload: %{user_id: uid}}, socket) do
    if uid == socket.assigns.user_id do
      {:noreply, socket}
    else
      # Re-share our whois so a peer that joined after us still receives it.
      broadcast("lobby_client_info", socket.assigns.token, %{
        from: socket.assigns.user_id,
        info: socket.assigns.local_info
      })

      {:noreply, assign(socket, peer_online: true)}
    end
  end

  def handle_info(%{event: "lobby_client_info", payload: %{from: from_id, info: info}}, socket) do
    if from_id == socket.assigns.user_id do
      {:noreply, socket}
    else
      {:noreply, assign(socket, peer_info: info, peer_online: true)}
    end
  end

  def handle_info(%{event: "lobby_peer_mute", payload: %{muted: muted, from: from_id}}, socket) do
    if from_id == socket.assigns.user_id do
      {:noreply, socket}
    else
      {:noreply,
       socket
       |> assign(peer_muted: muted)
       |> push_event("lobby_media_peer_muted", %{muted: muted})}
    end
  end

  def handle_info(%{event: "lobby_peer_camera", payload: %{off: off, from: from_id}}, socket) do
    if from_id == socket.assigns.user_id do
      {:noreply, socket}
    else
      {:noreply,
       socket
       |> assign(peer_camera_off: off)
       |> push_event("lobby_media_peer_camera", %{off: off})}
    end
  end

  def handle_info(%{event: "lobby_message", payload: msg}, socket) do
    {:noreply, assign(socket, messages: socket.assigns.messages ++ [msg])}
  end

  def handle_info(%{event: "lobby_media_changed", payload: payload}, socket) do
    if payload.user_id == socket.assigns.user_id do
      {:noreply, socket}
    else
      socket
      |> assign(peer_media: %{audio: payload.audio, video: payload.video})
      |> surface_peer_media(payload.audio or payload.video)
    end
  end

  def handle_info(%{event: "lobby_game_request", payload: request}, socket) do
    outgoing = request.proposer_id == socket.assigns.user_id

    {:noreply,
     socket
     |> assign(game_request: request, game_outgoing: outgoing)
     |> push_event("window_command", %{action: "open", id: "game"})}
  end

  def handle_info(%{event: "lobby_game_response", payload: %{accepted: false}}, socket) do
    msg = system_message(dgettext("lobby", "Game request declined."))

    {:noreply,
     socket
     |> assign(game_request: nil, game_outgoing: false)
     |> assign(messages: socket.assigns.messages ++ [msg])}
  end

  def handle_info(%{event: "lobby_game_response", payload: %{accepted: true}}, socket) do
    {:noreply, socket}
  end

  def handle_info(
        %{event: "lobby_game_status_changed", payload: %{status: "playing"} = p},
        socket
      ) do
    is_host = p.host_id == socket.assigns.user_id

    {:noreply,
     socket
     |> assign(
       game: %{status: "playing", game_id: p.game_id, is_host: is_host},
       game_request: nil,
       game_outgoing: false
     )
     |> push_event("lobby_game_start", %{game_id: p.game_id, is_host: is_host})
     |> push_event("window_command", %{action: "open", id: "game"})}
  end

  def handle_info(%{event: "lobby_game_status_changed", payload: %{status: "idle"}}, socket) do
    {:noreply,
     socket
     |> assign(game: %{status: "idle", game_id: nil, is_host: false})
     |> push_event("lobby_game_end", %{})
     |> push_event("window_command", %{action: "close", id: "game"})}
  end

  def handle_info(%{event: "lobby_inactivity_warning"}, socket) do
    {:noreply, assign(socket, inactivity_warning: true)}
  end

  def handle_info(%{event: "lobby_session_closed", payload: %{reason: reason}}, socket) do
    if socket.assigns.session_closed do
      {:noreply, socket}
    else
      {:noreply, assign(socket, session_closed: true, ended_reason: expired_reason_label(reason))}
    end
  end

  def handle_info(%{event: "lobby_signal", payload: %{from: from_id} = payload}, socket) do
    if from_id == socket.assigns.user_id do
      {:noreply, socket}
    else
      {:noreply, push_event(socket, "lobby_signal", payload)}
    end
  end

  def handle_info(%{event: "lobby_renegotiate", payload: %{from: from_id} = payload}, socket) do
    # Only the initiator acts on it; the answerer (the sender) ignores its own echo.
    if from_id == socket.assigns.user_id do
      {:noreply, socket}
    else
      {:noreply,
       push_event(socket, "lobby_renegotiate", %{
         kinds: payload[:kinds] || [],
         recover: payload[:recover] || false
       })}
    end
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  # --- WebRTC lifecycle ---

  @impl true
  def handle_event("lobby_webrtc_ready", _params, socket) do
    # Report readiness to the SessionServer; it starts signaling only once BOTH
    # peers' hooks are ready, so the first offer can never be dropped by a hook
    # that hasn't registered its handlers yet.
    Lobby.mark_webrtc_ready(socket.assigns.token, socket.assigns.user_id)
    {:noreply, assign(socket, webrtc_ready: true)}
  end

  def handle_event("lobby_signal", params, socket) do
    rate_limiter = SignalingRateLimit.configured_module()

    with :ok <- rate_limiter.check_signal_rate(socket.assigns.token, socket.assigns.user_id),
         {:ok, validated} <- P2P.validate_signal(params) do
      payload = Map.put(validated, :from, socket.assigns.user_id)
      broadcast("lobby_signal", socket.assigns.token, payload)
      {:noreply, socket}
    else
      {:error, _reason} -> {:noreply, socket}
    end
  end

  def handle_event("lobby_connected", _params, socket) do
    socket = assign(socket, connection_label: connected_label(), ever_connected: true)
    _ = Lobby.transition_status(socket.assigns.token, :connected)
    {:noreply, socket}
  end

  # The answerer asks the initiator to re-offer after it added local media tracks
  # (single-offerer model — only the initiator emits offers).
  def handle_event("lobby_renegotiate", params, socket) do
    broadcast("lobby_renegotiate", socket.assigns.token, %{
      from: socket.assigns.user_id,
      kinds: Map.get(params, "kinds", []),
      recover: Map.get(params, "recover", false)
    })

    {:noreply, socket}
  end

  def handle_event("lobby_state_change", %{"state" => state}, socket) do
    label = SessionHelpers.webrtc_state_label(state, nil) || socket.assigns.connection_label
    {:noreply, assign(socket, connection_label: label)}
  end

  def handle_event("lobby_failed", _params, socket) do
    msg = system_message(dgettext("lobby", "The connection failed."))

    {:noreply,
     socket
     |> assign(connection_label: dgettext("lobby", "Connection failed"))
     |> assign(messages: socket.assigns.messages ++ [msg])}
  end

  def handle_event("lobby_retry", _params, socket) do
    {:noreply, assign(socket, connection_label: dgettext("lobby", "Reconnecting..."))}
  end

  # --- Chat ---

  def handle_event("send_message", %{"content" => content}, socket) do
    case Lobby.send_lobby_message(socket.assigns.token, socket.assigns.user_id, content) do
      :ok ->
        {:noreply, push_event(socket, "p2p_lobby_message_sent", %{form_id: "lobby-chat-form"})}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  # --- Media (self-controlled) ---

  def handle_event("lobby_media_hook_ready", _params, socket) do
    {:noreply, assign(socket, media_ready: true)}
  end

  def handle_event("start_call", %{"type" => "video"}, socket) do
    Lobby.set_media(socket.assigns.token, socket.assigns.user_id, true, true)

    {:noreply,
     socket
     |> push_event("lobby_media_start_video", %{})
     |> push_event("window_command", %{action: "open", id: "call"})}
  end

  def handle_event("start_call", %{"type" => "audio"}, socket) do
    Lobby.set_media(socket.assigns.token, socket.assigns.user_id, true, false)

    {:noreply,
     socket
     |> push_event("lobby_media_start_audio", %{})
     |> push_event("window_command", %{action: "open", id: "call"})}
  end

  # The media hook reports its self-controlled send state here for every change:
  # starting a call, or an auto-joined receiver later enabling mic/camera. The
  # `audio_on`/`video_on` flags describe what THIS peer is sending now.
  def handle_event("lobby_media_call_started", params, socket) do
    type = params["type"] || "audio"
    audio_on = Map.get(params, "audio_on", true)
    video_on = Map.get(params, "video_on", type == "video")
    Lobby.set_media(socket.assigns.token, socket.assigns.user_id, audio_on, video_on)

    call =
      Map.merge(socket.assigns.call || %{}, %{
        type: type,
        audio_on: audio_on,
        video_on: video_on,
        duration: socket.assigns.call[:duration] || "00:00:00",
        muted: socket.assigns.local_muted,
        camera_off: socket.assigns.local_camera_off
      })

    {:noreply, assign(socket, call: call)}
  end

  # The user ended the call from the window's close (X) button. Tell the media hook
  # to tear the call down AND echo back (`notify: true`) so `lobby_media_call_ended`
  # clears our state and closes the window — without the echo the call would stop
  # locally but the window state would linger.
  def handle_event("end_call", _params, socket) do
    {:noreply, push_event(socket, "lobby_media_end_call", %{notify: true})}
  end

  def handle_event("lobby_media_call_ended", _params, socket) do
    Lobby.set_media(socket.assigns.token, socket.assigns.user_id, false, false)

    {:noreply,
     socket
     |> assign(
       call: nil,
       stats: empty_stats(),
       call_layout: "focus",
       local_muted: false,
       local_camera_off: false,
       peer_muted: false,
       peer_camera_off: false
     )
     |> push_event("window_command", %{action: "close", id: "call"})}
  end

  def handle_event("lobby_media_mute_changed", %{"muted" => muted}, socket) do
    broadcast("lobby_peer_mute", socket.assigns.token, %{
      muted: muted,
      from: socket.assigns.user_id
    })

    {:noreply,
     assign(socket,
       local_muted: muted,
       call: Map.merge(socket.assigns.call || %{}, %{muted: muted})
     )}
  end

  def handle_event("lobby_media_camera_changed", %{"off" => off}, socket) do
    broadcast("lobby_peer_camera", socket.assigns.token, %{off: off, from: socket.assigns.user_id})

    {:noreply,
     assign(socket,
       local_camera_off: off,
       call: Map.merge(socket.assigns.call || %{}, %{camera_off: off})
     )}
  end

  def handle_event("lobby_media_duration_tick", %{"formatted" => formatted}, socket) do
    {:noreply,
     assign(socket, call: Map.merge(socket.assigns.call || %{}, %{duration: formatted}))}
  end

  def handle_event("lobby_media_quality_update", %{"label" => label} = p, socket) do
    call =
      Map.merge(socket.assigns.call || %{}, %{quality_level: p["level"], quality_label: label})

    {:noreply, assign(socket, call: call)}
  end

  def handle_event("lobby_stats", payload, socket) do
    {:noreply, assign(socket, stats: normalize_stats(payload))}
  end

  def handle_event("media_select_preset", %{"preset" => preset}, socket) do
    {:noreply, push_event(socket, "lobby_media_set_preset", %{preset: preset})}
  end

  def handle_event("set_call_layout", %{"layout" => layout}, socket)
      when layout in ~w(focus side_by_side maximized) do
    {:noreply, assign(socket, call_layout: layout)}
  end

  def handle_event("set_call_layout", _params, socket), do: {:noreply, socket}

  def handle_event("toggle_network_info", _params, socket) do
    {:noreply, assign(socket, network_info_open: !socket.assigns.network_info_open)}
  end

  def handle_event("lobby_media_devices_listed", payload, socket) do
    {:noreply, assign(socket, devices: payload)}
  end

  def handle_event("lobby_media_device_fallback", %{"message" => message}, socket) do
    {:noreply, assign(socket, messages: socket.assigns.messages ++ [system_message(message)])}
  end

  def handle_event("lobby_media_error", _params, socket) do
    msg = system_message(dgettext("lobby", "Could not access your microphone or camera."))
    {:noreply, assign(socket, call: nil, messages: socket.assigns.messages ++ [msg])}
  end

  def handle_event("toggle_privacy_mode", _params, socket) do
    new_value = !socket.assigns.turn_only
    save_turn_only_preference(socket.assigns.nickname, new_value)
    {:noreply, assign(socket, turn_only: new_value)}
  end

  # --- File transfer (reuses FileTransferHook) ---

  def handle_event("file_transfer_ready", _params, socket) do
    {:noreply,
     socket
     |> assign(file_transfer_ready: true)
     |> ensure_file_transfer()
     |> maybe_push_ft_config()}
  end

  def handle_event("ft_offer_sent", params, socket) do
    {:noreply,
     assign(socket, file_transfer: ft_meta(params, "offering", socket.assigns.nickname))}
  end

  def handle_event("ft_offer_received", params, socket) do
    {:noreply,
     socket
     |> assign(file_transfer: ft_meta(params, "offer_received", socket.assigns.peer_nick))
     |> push_event("window_command", %{action: "open", id: "file"})}
  end

  def handle_event("ft_respond", %{"accepted" => "true"}, socket) do
    {:noreply, push_event(socket, "ft_accept", %{})}
  end

  def handle_event("ft_respond", _params, socket) do
    {:noreply, push_event(socket, "ft_reject", %{})}
  end

  def handle_event("ft_accepted", _params, socket) do
    ft = Map.merge(socket.assigns.file_transfer || %{}, %{status: "transferring", percent: 0})
    {:noreply, assign(socket, file_transfer: ft)}
  end

  def handle_event("ft_progress", params, socket) do
    ft =
      Map.merge(socket.assigns.file_transfer || %{}, %{
        status: "transferring",
        percent: params["percent"],
        speed: params["speed"],
        eta: params["eta"]
      })

    {:noreply, assign(socket, file_transfer: ft)}
  end

  # A finished transfer returns to "ready" — the lobby connection stays alive.
  def handle_event("ft_completed", params, socket) do
    Logger.info("Lobby file completed: #{params["file_name"]}, token=#{socket.assigns.token}")

    msg =
      system_message(
        dgettext("lobby", "File transfer completed: %{name}", name: params["file_name"])
      )

    {:noreply,
     socket
     |> assign(file_transfer: %{status: "ready"}, messages: socket.assigns.messages ++ [msg])
     |> maybe_push_ft_config()}
  end

  def handle_event("ft_failed", params, socket) do
    ft =
      Map.merge(socket.assigns.file_transfer || %{}, %{status: "failed", reason: params["reason"]})

    {:noreply, assign(socket, file_transfer: ft)}
  end

  def handle_event("ft_cancelled", _params, socket) do
    {:noreply,
     socket
     |> assign(file_transfer: %{status: "ready"})
     |> maybe_push_ft_config()
     |> push_event("window_command", %{action: "close", id: "file"})}
  end

  def handle_event("ft_reset", _params, socket) do
    {:noreply, socket |> assign(file_transfer: %{status: "ready"}) |> maybe_push_ft_config()}
  end

  def handle_event("ft_validation_error", params, socket) do
    {:noreply,
     assign(socket,
       file_transfer: %{status: "validation_error", validation_error: params["error"]}
     )}
  end

  def handle_event("ft_accept_offer", _params, socket) do
    {:noreply, push_event(socket, "ft_accept", %{})}
  end

  # The X on the Files window cancels an in-flight transfer (the hook tears it down)
  # and closes the window in every state, including an idle picker.
  def handle_event("ft_cancel", _params, socket) do
    {:noreply,
     socket
     |> push_event("ft_cancel", %{nickname: socket.assigns.nickname})
     |> push_event("window_command", %{action: "close", id: "file"})}
  end

  def handle_event("ft_retry", _params, socket) do
    {:noreply, push_event(socket, "ft_retry", %{})}
  end

  def handle_event("ft_paused", _params, socket) do
    {:noreply,
     assign(socket,
       file_transfer: Map.merge(socket.assigns.file_transfer || %{}, %{status: "paused"})
     )}
  end

  def handle_event("ft_resumed", _params, socket) do
    {:noreply,
     assign(socket,
       file_transfer: Map.merge(socket.assigns.file_transfer || %{}, %{status: "transferring"})
     )}
  end

  def handle_event(event, params, socket) when event in ~w(ft_queued ft_rejected) do
    _ = params
    {:noreply, socket}
  end

  # --- Games ---

  def handle_event("lobby_game_canvas_ready", _params, socket) do
    game = socket.assigns.game

    if game.status == "playing" do
      {:noreply,
       push_event(socket, "lobby_game_start", %{game_id: game.game_id, is_host: game.is_host})}
    else
      {:noreply, socket}
    end
  end

  def handle_event("propose_game", %{"game_id" => game_id}, socket) do
    case Lobby.propose_game(socket.assigns.token, socket.assigns.user_id, game_id) do
      :ok -> {:noreply, socket}
      {:error, _reason} -> {:noreply, socket}
    end
  end

  def handle_event("respond_game", %{"accepted" => accepted}, socket) do
    accepted? = accepted == "true"
    Lobby.respond_game(socket.assigns.token, socket.assigns.user_id, accepted?)
    {:noreply, socket}
  end

  # The X on the Game window quits/cancels whatever is there and closes it — a
  # playing game ends for both peers; an open picker or pending proposal just closes.
  def handle_event("end_game", _params, socket) do
    Lobby.end_game(socket.assigns.token, socket.assigns.user_id)

    {:noreply,
     socket
     |> assign(game_request: nil, game_outgoing: false)
     |> push_event("window_command", %{action: "close", id: "game"})}
  end

  def handle_event("lobby_game_result", _result, socket) do
    {:noreply, socket}
  end

  # --- Session lifecycle ---

  def handle_event("leave_lobby", _params, socket) do
    Lobby.close_session(socket.assigns.token, socket.assigns.user_id, "user_closed")
    {:noreply, assign(socket, session_closed: true)}
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  @impl true
  def terminate(_reason, socket) do
    if (connected?(socket) and is_binary(socket.assigns[:token]) and
          socket.assigns[:user_id]) && !socket.assigns[:session_closed] do
      Lobby.leave(socket.assigns.token, socket.assigns.user_id)
    end

    :ok
  end

  # --- Private helpers ---

  defp mount_lobby(socket, token, nickname, user_id, db_session) do
    role = if user_id == db_session.creator_id, do: :creator, else: :peer
    Logger.info("Lobby LiveView mounted: token=#{token}, user=#{nickname}, role=#{role}")

    local_info = SessionHelpers.parse_client_info(get_connect_params(socket))

    if connected?(socket) do
      Phoenix.PubSub.subscribe(@pubsub, "lobby:#{token}")
      Lobby.join_session(token, user_id)
      broadcast("lobby_client_info", token, %{from: user_id, info: local_info})
    end

    {:ok,
     assign(socket,
       token: token,
       nickname: nickname,
       user_id: user_id,
       role: role,
       peer_nick: SessionHelpers.resolve_peer_nick(user_id, db_session),
       peer_online: false,
       session_status: db_session.status,
       ever_connected: false,
       connection_label: dgettext("lobby", "Waiting for peer..."),
       inactivity_warning: false,
       webrtc_ready: false,
       webrtc_started: false,
       media_ready: false,
       messages: [],
       call: nil,
       call_layout: "focus",
       local_muted: false,
       local_camera_off: false,
       peer_muted: false,
       peer_camera_off: false,
       peer_media: %{audio: false, video: false},
       stats: empty_stats(),
       network_info_open: false,
       devices: nil,
       local_info: local_info,
       peer_info: %{},
       turn_only: load_turn_only_preference(nickname),
       turn_configured: P2P.turn_configured?(),
       file_transfer: nil,
       file_transfer_ready: false,
       game: %{status: "idle", game_id: nil, is_host: false},
       game_request: nil,
       game_outgoing: false,
       games: Catalog.list_games(),
       expired: false,
       session_closed: false,
       ended_reason: nil
     )}
  end

  defp fetch_session(token) do
    case Lobby.get_session(token) do
      {:ok, session} -> {:ok, session}
      {:error, :not_found} -> {:redirect, nil}
    end
  end

  defp verify_not_terminal(session) do
    if Session.terminal?(session.status),
      do: {:expired, session.closed_reason || session.status},
      else: :ok
  end

  defp maybe_start_webrtc(%{assigns: %{webrtc_started: false}} = socket) do
    ice_servers = P2P.ice_servers(to_string(socket.assigns.user_id))
    turn_only = socket.assigns.turn_only && socket.assigns.turn_configured

    event =
      case socket.assigns.role do
        :creator -> "lobby_start_offer"
        :peer -> "lobby_start_answer"
      end

    socket
    |> assign(webrtc_started: true, connection_label: dgettext("lobby", "Connecting..."))
    |> push_event(event, %{
      ice_servers: ice_servers,
      role: to_string(socket.assigns.role),
      turn_only: turn_only
    })
  end

  defp maybe_start_webrtc(socket), do: socket

  defp ensure_file_transfer(%{assigns: %{file_transfer: nil}} = socket) do
    socket |> assign(file_transfer: %{status: "ready"}) |> maybe_push_ft_config()
  end

  defp ensure_file_transfer(socket), do: socket

  defp maybe_push_ft_config(%{assigns: %{file_transfer_ready: true}} = socket) do
    config = %{
      max_size_mb: Application.get_env(:retro_hex_chat, :file_transfer_max_size_mb, 500),
      blocked_extensions:
        Application.get_env(
          :retro_hex_chat,
          :file_transfer_blocked_extensions,
          ~w(.exe .bat .cmd .com .msi .scr .pif .vbs .vbe .js .jse .wsf .wsh .ps1 .reg)
        )
    }

    push_event(socket, "ft_config", config)
  end

  defp maybe_push_ft_config(socket), do: socket

  defp ft_meta(params, status, sender_nick) do
    %{
      status: status,
      file_name: params["file_name"],
      formatted_size: params["formatted_size"],
      sender_nick: sender_nick
    }
  end

  defp broadcast(event, token, payload) do
    Phoenix.PubSub.broadcast(@pubsub, "lobby:#{token}", %{event: event, payload: payload})
  end

  # The peer's media turned on. If we are not in the call yet, auto-join as a pure
  # receiver: become a participant (window opens, surface renders) with our own mic
  # and camera off — the user then chooses to enable them, no permission prompt. If
  # we are already in, just keep the window surfaced.
  defp surface_peer_media(socket, true) do
    if is_nil(socket.assigns.call) do
      # We are sending nothing yet, so mic/camera are simply "not on" — NOT muted
      # or camera-off. Keeping these false means that when the user later enables a
      # device the toggle reflects its real state instead of starting inverted.
      call = %{
        type: "receiving",
        audio_on: false,
        video_on: false,
        duration: "00:00:00",
        muted: false,
        camera_off: false
      }

      {:noreply,
       socket
       |> assign(call: call, local_muted: false, local_camera_off: false)
       |> push_event("lobby_media_join", %{})
       |> push_event("window_command", %{action: "open", id: "call"})}
    else
      {:noreply, push_event(socket, "window_command", %{action: "open", id: "call"})}
    end
  end

  # The peer turned everything off. If we were only receiving (sending nothing),
  # there is no media left for us, so leave the call; otherwise stay as we are.
  defp surface_peer_media(socket, false) do
    call = socket.assigns.call
    sending? = call != nil and (call[:audio_on] or call[:video_on])

    if call != nil and not sending? do
      {:noreply, push_event(socket, "lobby_media_end_call", %{notify: true})}
    else
      {:noreply, socket}
    end
  end

  defp system_message(content) do
    %{
      id: System.unique_integer([:positive]),
      sender_nick: dgettext("lobby", "System"),
      content: content,
      type: "system",
      timestamp: DateTime.utc_now()
    }
  end

  defp connected_label, do: dgettext("lobby", "Connected")

  # The statistics window is ALWAYS complete: every section and metric is present
  # even with no activity (idle features simply read zero). This normalizes the
  # per-feature payload from LobbyWebRTCHook into a fully-populated struct so the
  # panel never has to guard against missing keys.
  @spec normalize_stats(map()) :: map()
  defp normalize_stats(payload) do
    conn = Map.get(payload, "connection", %{})
    audio = Map.get(payload, "audio", %{})
    video = Map.get(payload, "video", %{})
    game = Map.get(payload, "game", %{})
    file = Map.get(payload, "file", %{})

    %{
      connection: %{
        level: Map.get(conn, "level", "excellent"),
        label: Map.get(conn, "label", ""),
        mos: Map.get(conn, "mos", 0),
        rtt_ms: Map.get(conn, "rtt_ms", 0),
        jitter_ms: Map.get(conn, "jitter_ms", 0),
        loss_pct: Map.get(conn, "loss_pct", 0),
        available_kbps: Map.get(conn, "available_kbps", 0)
      },
      audio: %{
        active: Map.get(audio, "active", false),
        in_kbps: Map.get(audio, "in_kbps", 0),
        out_kbps: Map.get(audio, "out_kbps", 0),
        loss_pct: Map.get(audio, "loss_pct", 0),
        jitter_ms: Map.get(audio, "jitter_ms", 0)
      },
      video: %{
        active: Map.get(video, "active", false),
        in_kbps: Map.get(video, "in_kbps", 0),
        out_kbps: Map.get(video, "out_kbps", 0),
        loss_pct: Map.get(video, "loss_pct", 0),
        jitter_ms: Map.get(video, "jitter_ms", 0),
        fps: Map.get(video, "fps", 0),
        width: Map.get(video, "width", 0),
        height: Map.get(video, "height", 0),
        freeze_count: Map.get(video, "freeze_count", 0),
        limitation: Map.get(video, "limitation", "none")
      },
      game: normalize_channel_stats(game),
      file: normalize_channel_stats(file)
    }
  end

  @spec normalize_channel_stats(map()) :: map()
  defp normalize_channel_stats(channel) do
    %{
      active: Map.get(channel, "active", false),
      state: Map.get(channel, "state", "closed"),
      sent_kbps: Map.get(channel, "sent_kbps", 0),
      recv_kbps: Map.get(channel, "recv_kbps", 0),
      messages: Map.get(channel, "messages", 0)
    }
  end

  # A zeroed statistics struct so the window renders complete before the first
  # sample (and whenever there is no connection yet).
  @spec empty_stats() :: map()
  defp empty_stats do
    %{
      connection: %{
        level: "excellent",
        label: "",
        mos: 0,
        rtt_ms: 0,
        jitter_ms: 0,
        loss_pct: 0,
        available_kbps: 0
      },
      audio: %{active: false, in_kbps: 0, out_kbps: 0, loss_pct: 0, jitter_ms: 0},
      video: %{
        active: false,
        in_kbps: 0,
        out_kbps: 0,
        loss_pct: 0,
        jitter_ms: 0,
        fps: 0,
        width: 0,
        height: 0,
        freeze_count: 0,
        limitation: "none"
      },
      game: %{active: false, state: "closed", sent_kbps: 0, recv_kbps: 0, messages: 0},
      file: %{active: false, state: "closed", sent_kbps: 0, recv_kbps: 0, messages: 0}
    }
  end

  defp load_turn_only_preference(nickname) do
    case RetroHexChat.Repo.get(UserPreference, nickname) do
      nil -> false
      pref -> get_in(pref.display_settings, ["p2p_settings", "turn_only"]) == true
    end
  end

  defp save_turn_only_preference(nickname, turn_only) do
    case RetroHexChat.Repo.get(UserPreference, nickname) do
      nil ->
        %UserPreference{}
        |> UserPreference.changeset(%{
          owner_nickname: nickname,
          display_settings: %{"p2p_settings" => %{"turn_only" => turn_only}}
        })
        |> RetroHexChat.Repo.insert()

      pref ->
        current = pref.display_settings || %{}
        p2p = Map.get(current, "p2p_settings", %{})
        updated = Map.put(current, "p2p_settings", Map.put(p2p, "turn_only", turn_only))

        pref
        |> UserPreference.changeset(%{display_settings: updated})
        |> RetroHexChat.Repo.update()
    end
  end

  defp expired_reason_label("user_closed"), do: dgettext("lobby", "Lobby closed by a user.")
  defp expired_reason_label("peer_left"), do: dgettext("lobby", "The other user left the lobby.")
  defp expired_reason_label("expired"), do: dgettext("lobby", "Lobby expired due to inactivity.")

  defp expired_reason_label("failed"),
    do: dgettext("lobby", "Lobby closed due to a connection failure.")

  defp expired_reason_label("user_blocked"),
    do: dgettext("lobby", "Lobby closed because a user was ignored.")

  defp expired_reason_label(_reason), do: dgettext("lobby", "The lobby ended.")
end
