defmodule RetroHexChatWeb.App.LobbyLive do
  @moduledoc """
  P2P lobby.

  A single, persistent WebRTC connection between two peers that hosts every
  feature concurrently: ephemeral chat, self-controlled audio/video, file
  transfer and games — all at the same time. Ending a feature never closes the
  session; only an explicit leave or inactivity does.
  """
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  require Logger

  import RetroHexChatWeb.Components.UI.Lobby.UniversalLobby
  import RetroHexChatWeb.Components.UI.Lobby.LobbyTerminal

  alias RetroHexChat.Chat.Schemas.UserPreference
  alias RetroHexChat.Lobby
  alias RetroHexChat.Lobby.Schema.Session
  alias RetroHexChat.P2P
  alias RetroHexChat.P2P.SignalingRateLimit
  alias RetroHexChatWeb.App.ComposerEvents
  alias RetroHexChatWeb.App.LobbyLive.ChatDispatch
  alias RetroHexChatWeb.App.LobbyLive.Components.ChatIsland
  alias RetroHexChatWeb.App.LobbyLive.Components.FileIsland
  alias RetroHexChatWeb.App.LobbyLive.Components.GameIsland
  alias RetroHexChatWeb.App.LobbyLive.Components.MediaIsland
  alias RetroHexChatWeb.App.SessionHelpers
  alias RetroHexChatWeb.Timezone

  @pubsub RetroHexChat.PubSub

  # Server-managed desktop windows: their islands render only while listed in
  # @open_windows (see UniversalLobby). Every other window is static chrome.
  @managed_windows ~w(game)

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(%{"token" => token}, session, socket) do
    nickname = session["chat_nickname"]

    with {:ok, socket} <- SessionHelpers.verify_nickname(socket, nickname),
         {:ok, user_id} <- SessionHelpers.resolve_user_id(nickname),
         {:ok, db_session} <- fetch_session(token),
         :ok <- SessionHelpers.verify_participant(user_id, db_session),
         :ok <- verify_not_terminal(db_session) do
      mount_lobby(socket, token, nickname, user_id, db_session, resolve_timezone(session, socket))
    else
      {:expired, reason} ->
        {:ok, assign_terminal(socket, token, reason, resolve_timezone(session, socket))}

      {:redirect, redirect_socket} when is_struct(redirect_socket) ->
        {:ok, redirect_socket}

      {:redirect, _} ->
        {:ok, assign_invalid(socket)}
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
      {:noreply, mark_session_closed(socket, status)}
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
    unless from_id == socket.assigns.user_id do
      send_update(MediaIsland, id: MediaIsland.id(), action: {:peer_mute, muted})
    end

    {:noreply, socket}
  end

  def handle_info(%{event: "lobby_peer_camera", payload: %{off: off, from: from_id}}, socket) do
    unless from_id == socket.assigns.user_id do
      send_update(MediaIsland, id: MediaIsland.id(), action: {:peer_camera, off})
    end

    {:noreply, socket}
  end

  def handle_info(%{event: "lobby_message", payload: msg}, socket) do
    send_update(ChatIsland, id: ChatIsland.id(), append_message: msg)
    {:noreply, socket}
  end

  def handle_info(%{event: "lobby_media_changed", payload: payload}, socket) do
    unless payload.user_id == socket.assigns.user_id do
      send_update(MediaIsland, id: MediaIsland.id(), action: {:peer_media_changed, payload})
    end

    {:noreply, socket}
  end

  def handle_info(%{event: "lobby_game_request", payload: request}, socket) do
    outgoing = request.proposer_id == socket.assigns.user_id
    # Mount the island first — send_update is processed after this render, so
    # the freshly mounted island receives the request.
    socket = open_window(socket, "game")
    send_update(GameIsland, id: GameIsland.id(), action: {:request, request, outgoing})
    {:noreply, socket}
  end

  def handle_info(%{event: "lobby_game_response", payload: %{accepted: false}}, socket) do
    if window_open?(socket, "game") do
      send_update(GameIsland, id: GameIsland.id(), action: :request_declined)
    end

    send_update(ChatIsland,
      id: ChatIsland.id(),
      system_message: dgettext("lobby", "Game request declined.")
    )

    {:noreply, socket}
  end

  def handle_info(%{event: "lobby_game_response", payload: %{accepted: true}}, socket) do
    {:noreply, socket}
  end

  def handle_info(
        %{event: "lobby_game_status_changed", payload: %{status: "playing"} = p},
        socket
      ) do
    is_host = p.host_id == socket.assigns.user_id
    socket = open_window(socket, "game")
    send_update(GameIsland, id: GameIsland.id(), action: {:playing, p.game_id, is_host})
    {:noreply, socket}
  end

  def handle_info(%{event: "lobby_game_status_changed", payload: %{status: "idle"}}, socket) do
    if window_open?(socket, "game") do
      send_update(GameIsland, id: GameIsland.id(), action: :idle)
    end

    {:noreply, socket}
  end

  def handle_info(
        %{event: "lobby_game_status_changed", payload: %{status: "finished"} = p},
        socket
      ) do
    if window_open?(socket, "game") do
      send_update(GameIsland, id: GameIsland.id(), action: {:result, p.result})
    end

    {:noreply, socket}
  end

  def handle_info(%{event: "lobby_inactivity_warning"}, socket) do
    {:noreply, assign(socket, inactivity_warning: true)}
  end

  def handle_info(%{event: "lobby_session_closed", payload: %{reason: reason}}, socket) do
    if socket.assigns.session_closed do
      {:noreply, socket}
    else
      {:noreply, mark_session_closed(socket, reason)}
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

  # Read-model bubble from a feature island (C2). This is a tuple, not the
  # `%{event: ...}` PubSub shape, so it MUST be matched above the catch-all or it
  # is silently swallowed and the taskbar badge never updates.
  def handle_info({:feature_summary, :game, summary}, socket) do
    {:noreply, assign(socket, game_summary: summary)}
  end

  def handle_info({:feature_summary, :file, summary}, socket) do
    {:noreply, assign(socket, file_summary: summary)}
  end

  def handle_info({:feature_summary, :call, summary}, socket) do
    {:noreply, assign(socket, call_summary: summary)}
  end

  # Islands drive their own server-managed window lifecycle with these messages
  # (mirroring the {:feature_summary, ...} pattern): the host mounts/unmounts the
  # island by toggling @open_windows.
  def handle_info({:open_window, id}, socket) do
    {:noreply, open_window(socket, id)}
  end

  def handle_info({:close_window, id}, socket) do
    {:noreply, close_window(socket, id)}
  end

  # Bubbled from the shared Composer on submit. `reply_to` is always nil here
  # (the lobby capability set disables replies); ChatDispatch parses the text and
  # runs the lobby's plain-message / `/command` effects.
  def handle_info({:composer_dispatch, text, _reply_to}, socket) do
    {:noreply, ChatDispatch.dispatch(socket, text)}
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
    send_update(ChatIsland,
      id: ChatIsland.id(),
      system_message: dgettext("lobby", "The connection failed.")
    )

    {:noreply, assign(socket, connection_label: dgettext("lobby", "Connection failed"))}
  end

  def handle_event("lobby_retry", _params, socket) do
    {:noreply, assign(socket, connection_label: dgettext("lobby", "Reconnecting..."))}
  end

  # --- Chat ---
  #
  # The chat window hosts the shared `Composer` LiveComponent. On submit it
  # bubbles `{:composer_dispatch, text, reply_to}` here (handled in handle_info);
  # the formatting toolbar's strip toggle bubbles `toggle_strip_formatting`.

  def handle_event("toggle_strip_formatting", _params, socket) do
    {:noreply, assign(socket, strip_formatting: !socket.assigns.strip_formatting)}
  end

  # --- Media (self-controlled) ---
  #
  # The LobbyMediaHook and the call window's controls push to the root LV, so the
  # host forwards the whole media family to the MediaIsland, which owns the call
  # state and drives its window. `lobby_stats`/`toggle_network_info` feed the
  # host-owned Statistics window; ending a call also clears that telemetry here.

  def handle_event("lobby_media_call_ended" = event, params, socket) do
    send_update(MediaIsland, id: MediaIsland.id(), action: {:media_event, event, params})
    {:noreply, assign(socket, stats: empty_stats())}
  end

  def handle_event("lobby_stats", payload, socket) do
    {:noreply, assign(socket, stats: normalize_stats(payload))}
  end

  def handle_event("toggle_network_info", _params, socket) do
    {:noreply, assign(socket, network_info_open: !socket.assigns.network_info_open)}
  end

  def handle_event("lobby_media_" <> _ = event, params, socket) do
    send_update(MediaIsland, id: MediaIsland.id(), action: {:media_event, event, params})
    {:noreply, socket}
  end

  def handle_event(event, params, socket)
      when event in ~w(start_call end_call set_call_layout media_select_preset) do
    send_update(MediaIsland, id: MediaIsland.id(), action: {:media_event, event, params})
    {:noreply, socket}
  end

  def handle_event("toggle_privacy_mode", _params, socket) do
    new_value = !socket.assigns.turn_only
    save_turn_only_preference(socket.assigns.nickname, new_value)
    {:noreply, assign(socket, turn_only: new_value)}
  end

  # --- File transfer (reuses FileTransferHook) ---
  #
  # The hook pushes its `ft_*` events to the root LiveView, so the host forwards
  # the whole family to the FileIsland verbatim; the island owns the state and
  # drives its window. `file_transfer_ready` does not share the `ft_` prefix.

  def handle_event("file_transfer_ready", _params, socket) do
    send_update(FileIsland, id: FileIsland.id(), action: {:ft_event, "file_transfer_ready", %{}})
    {:noreply, socket}
  end

  def handle_event("ft_" <> _ = event, params, socket) do
    send_update(FileIsland, id: FileIsland.id(), action: {:ft_event, event, params})
    {:noreply, socket}
  end

  # --- Games ---

  def handle_event("lobby_game_canvas_ready", _params, socket) do
    send_update(GameIsland, id: GameIsland.id(), action: :canvas_ready)
    {:noreply, socket}
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

    if window_open?(socket, "game") do
      send_update(GameIsland, id: GameIsland.id(), action: :end_game)
    end

    {:noreply, socket}
  end

  # WindowManagerHook lifecycle for server-managed windows: something opened a
  # window whose island is not mounted (Start menu, shortcut, taskbar), or the
  # user closed one client-side. Unknown ids are ignored — only ids the desktop
  # declares as managed may toggle islands.
  def handle_event("window_open", %{"id" => id}, socket) when id in @managed_windows do
    {:noreply, open_window(socket, id)}
  end

  def handle_event("window_open", _params, socket), do: {:noreply, socket}

  def handle_event("window_closed", %{"id" => id}, socket) do
    {:noreply, close_window(socket, id)}
  end

  # Only the host's game engine fires onGameEnd; it reports the authoritative
  # result to the server, which relays "finished" (with the score) to both peers.
  def handle_event("lobby_game_result", result, socket) do
    Lobby.finish_game(socket.assigns.token, socket.assigns.user_id, result)
    {:noreply, socket}
  end

  # The "Back to games" button on the result card dismisses it locally (the lobby
  # is self-controlled — each peer leaves the result at its own pace).
  def handle_event("dismiss_game_result", _params, socket) do
    send_update(GameIsland, id: GameIsland.id(), action: :dismiss_result)
    {:noreply, socket}
  end

  # The game canvas failed to load its engine bundle: end the game for both peers
  # (it cannot be played one-sided) and tell the user why.
  def handle_event("lobby_game_error", _params, socket) do
    Lobby.end_game(socket.assigns.token, socket.assigns.user_id)

    send_update(ChatIsland,
      id: ChatIsland.id(),
      system_message: dgettext("lobby", "Could not load the game. Please try again.")
    )

    {:noreply, socket}
  end

  # --- Session lifecycle ---

  def handle_event("leave_lobby", _params, socket) do
    Lobby.close_session(socket.assigns.token, socket.assigns.user_id, "user_closed")
    {:noreply, mark_session_closed(socket, "user_closed")}
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

  defp mount_lobby(socket, token, nickname, user_id, db_session, timezone) do
    role = if user_id == db_session.creator_id, do: :creator, else: :peer
    Logger.info("Lobby LiveView mounted: token=#{token}, user=#{nickname}, role=#{role}")

    local_info = SessionHelpers.parse_client_info(get_connect_params(socket))

    join_result =
      if connected?(socket) do
        Phoenix.PubSub.subscribe(@pubsub, "lobby:#{token}")
        result = Lobby.join_session(token, user_id)
        broadcast("lobby_client_info", token, %{from: user_id, info: local_info})
        result
      else
        :ok
      end

    case join_result do
      {:error, :already_joined} ->
        {:ok, assign_already_joined(socket)}

      _ ->
        # The lobby drives the shared chat Composer, so it relays the composer's
        # keyboard events (autocomplete/history/tab/syntax) exactly like the chat.
        socket =
          attach_hook(socket, :composer_events, :handle_event, &ComposerEvents.handle_event/3)

        {:ok,
         assign(socket,
           token: token,
           nickname: nickname,
           user_id: user_id,
           live_ready: connected?(socket),
           role: role,
           timezone: timezone,
           strip_formatting: false,
           peer_nick: SessionHelpers.resolve_peer_nick(user_id, db_session),
           peer_online: false,
           session_status: db_session.status,
           ever_connected: false,
           connection_label: dgettext("lobby", "Waiting for peer..."),
           inactivity_warning: false,
           webrtc_ready: false,
           webrtc_started: false,
           call_summary: nil,
           stats: empty_stats(),
           network_info_open: false,
           local_info: local_info,
           peer_info: %{},
           turn_only: load_turn_only_preference(nickname),
           turn_configured: P2P.turn_configured?(),
           file_summary: nil,
           game_summary: %{active?: false},
           open_windows: MapSet.new(),
           expired: false,
           session_closed: false,
           invalid: false,
           ended_reason: nil,
           ended_summary: nil
         )}
    end
  end

  # --- Server-managed window lifecycle ---

  @spec open_window(Phoenix.LiveView.Socket.t(), String.t()) :: Phoenix.LiveView.Socket.t()
  defp open_window(socket, id) when id in @managed_windows do
    update(socket, :open_windows, &MapSet.put(&1, id))
  end

  defp open_window(socket, _id), do: socket

  @spec close_window(Phoenix.LiveView.Socket.t(), String.t()) :: Phoenix.LiveView.Socket.t()
  defp close_window(socket, id) do
    update(socket, :open_windows, &MapSet.delete(&1, id))
  end

  @spec window_open?(Phoenix.LiveView.Socket.t(), String.t()) :: boolean()
  defp window_open?(socket, id) do
    MapSet.member?(socket.assigns.open_windows, id)
  end

  @spec resolve_timezone(map(), Phoenix.LiveView.Socket.t()) :: String.t()
  defp resolve_timezone(http_session, socket) do
    session_tz = http_session["chat_timezone"]
    params_tz = Map.get(get_connect_params(socket) || %{}, "timezone")

    tz =
      cond do
        session_tz && session_tz != "" && session_tz != "Etc/UTC" -> session_tz
        params_tz && params_tz != "" -> params_tz
        true -> "Etc/UTC"
      end

    Timezone.validate(tz)
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

  defp broadcast(event, token, payload) do
    Phoenix.PubSub.broadcast(@pubsub, "lobby:#{token}", %{
      event: event,
      payload: payload,
      token: token
    })
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

  # --- Terminal-state assigns ---

  # An already-terminal session at mount: show the rich goodbye card.
  defp assign_terminal(socket, token, reason, timezone) do
    assign(socket,
      expired: true,
      session_closed: false,
      invalid: false,
      ended_reason: expired_reason_label(reason),
      ended_summary: summary_for(token),
      timezone: timezone
    )
  end

  # An unknown token, or a link the viewer was never part of: no session to show,
  # just a friendly explanation. `timezone` is only read by the rich card.
  defp assign_invalid(socket) do
    assign(socket,
      expired: false,
      session_closed: false,
      invalid: true,
      ended_reason:
        dgettext("lobby", "This lobby link is no longer valid, or the lobby never existed."),
      ended_summary: nil,
      timezone: "Etc/UTC"
    )
  end

  # The same user already holds a live connection to this session from another
  # process — one active tab per session.
  defp assign_already_joined(socket) do
    assign(socket,
      expired: false,
      session_closed: false,
      invalid: true,
      ended_reason: dgettext("lobby", "This lobby is already open in another tab or window."),
      ended_summary: nil,
      timezone: "Etc/UTC"
    )
  end

  # A live session that just closed: flip to the terminal screen and resolve the
  # final summary (timestamps/duration) for the goodbye card.
  defp mark_session_closed(socket, reason) do
    assign(socket,
      session_closed: true,
      ended_reason: expired_reason_label(reason),
      ended_summary: summary_for(socket.assigns.token)
    )
  end

  defp summary_for(token) do
    case Lobby.session_summary(token) do
      {:ok, summary} -> summary
      {:error, :not_found} -> nil
    end
  end

  defp expired_reason_label("user_closed"), do: dgettext("lobby", "Lobby closed by a user.")
  defp expired_reason_label("peer_left"), do: dgettext("lobby", "The other user left the lobby.")
  defp expired_reason_label("expired"), do: dgettext("lobby", "Lobby expired due to inactivity.")

  defp expired_reason_label("failed"),
    do: dgettext("lobby", "Lobby closed due to a connection failure.")

  defp expired_reason_label("user_blocked"),
    do: dgettext("lobby", "Lobby closed because a user was ignored.")

  defp expired_reason_label("declined"),
    do: dgettext("lobby", "The invite was declined.")

  defp expired_reason_label("invite_cancelled"),
    do: dgettext("lobby", "The invite was cancelled.")

  defp expired_reason_label(_reason), do: dgettext("lobby", "The lobby ended.")
end
