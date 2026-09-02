defmodule RetroHexChatWeb.P2PLive.Events do
  @moduledoc """
  Being inside a P2P session.

  Every event here presumes the session exists and you are in it, or about to
  walk into it: the media you are sending, the files and the game riding the
  same peer connection, the statistics, and the recovery a dropped connection
  goes through. The state machine is one assign:

      nil → :invite_sent → :joining → :connecting → :connected → nil

  and every P2P surface derives from it.

  Knowing that a session *exists* is not here — that is
  `RetroHexChatWeb.ChatLive.P2PReadModel`, and the chat reads it without any of
  this. The rule that split the two: if the datum only exists while you are in
  the session, it is in this module. The invite is the clearest case of the
  other side — it is a real private message, persisted, and creating the
  session *is* sending it, so it stayed in the conversation.

  **The signalling wire is not here either.** Offers, answers, candidates, the
  answerer's renegotiation request and the replay that fills a reconnect's gap
  travel on `RetroHexChatWeb.P2PChannel`, a raw Phoenix Channel the browser
  joins with `Lobby.JoinToken`. What is here is what the host does *about*
  signalling: telling its own client to start it, to answer, or to restart —
  commands whose payload carries `ice_servers`, `role` and `turn_only`, which
  is transport policy this process owns and persists.

  Signalling still only starts after BOTH hooks report ready, and now the
  starting room says so out loud: `[Ready]` is a hook that has mounted, and the
  creator's `[Start]` is what releases the first offer. Never re-order this —
  the first offer is dropped if the answerer's hook is not listening yet.

  A refusal is a sentence on this page's own status bar, and leaving is this
  page saying it is finished — both through `RetroHexChatWeb.Live.Surface`,
  which is what a screen with an address does to itself. There is no host to
  tell any more.
  """

  import Phoenix.Component, only: [assign: 2, update: 3]
  import Phoenix.LiveView, only: [push_event: 3]

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias Phoenix.LiveView.Socket
  alias RetroHexChat.Accounts.TrustedDevices
  alias RetroHexChat.Calls.Events, as: CallEvents
  alias RetroHexChat.Chat.Service, as: ChatService
  alias RetroHexChat.Games.Telemetry, as: GameTelemetry
  alias RetroHexChat.Lobby
  alias RetroHexChat.Lobby.JoinToken
  alias RetroHexChat.Lobby.Schema.Session, as: LobbySession
  alias RetroHexChat.P2P
  alias RetroHexChatWeb.App.P2PStats
  alias RetroHexChatWeb.Live.P2PConfirmDialog
  alias RetroHexChatWeb.Live.Surface
  alias RetroHexChatWeb.MediaDevices
  alias RetroHexChatWeb.P2PLive.Components.P2PFileIsland
  alias RetroHexChatWeb.P2PLive.Components.P2PGameIsland
  alias RetroHexChatWeb.P2PLive.Components.P2PMediaIsland

  @pubsub RetroHexChat.PubSub
  @call_window_id "p2p-call"
  @p2p_console_width 640
  @p2p_console_height 430
  @p2p_console_x 448
  @p2p_console_y 72
  @p2p_setup_preference_namespace "p2p_setup"

  # ── Client events (WebRTC hooks + P2P UI) ─────────────────────

  @doc """
  The token the browser joins `p2p:<session_token>` with.

  Minted here because this is where the session and the person are both known,
  and rendered onto the WebRTC anchor, which is keyed by session token — so a
  session switch replaces the element and the token with it.
  """
  @spec signaling_join_token(map() | nil, String.t() | nil) :: String.t() | nil
  def signaling_join_token(%{token: token, user_id: user_id}, nickname)
      when is_binary(token) and is_integer(user_id) do
    JoinToken.sign(token, user_id, nickname || "")
  end

  def signaling_join_token(_p2p, _nickname), do: nil

  @spec handle_event(String.t(), map(), Socket.t()) :: {:cont | :halt, Socket.t()}
  # The hook is mounted and listening, which is the second half of what
  # `[Ready]` means — the first half is the devices, chosen a moment earlier in
  # the starting room. Only now may the domain's gate fire.
  def handle_event("lobby_webrtc_ready", _params, %{assigns: %{p2p_session: %{}}} = socket) do
    p2p = socket.assigns.p2p_session
    _ = Lobby.mark_webrtc_ready(p2p.token, p2p.user_id)

    {:halt,
     socket
     |> put_p2p(%{p2p | hook_ready: true})
     |> resend_webrtc_start(p2p)}
  end

  def handle_event("lobby_connected", _params, %{assigns: %{p2p_session: %{}}} = socket) do
    p2p = socket.assigns.p2p_session
    _ = Lobby.transition_status(p2p.token, :connected)
    {:halt, enter_connected(socket, p2p)}
  end

  # The signaling wire refused the browser. Nothing about the connection can
  # proceed without it, and a silent wait would look exactly like a peer who
  # never answered — so it is said out loud, with the door the channel named.
  def handle_event(
        "lobby_signaling_unavailable",
        params,
        %{assigns: %{p2p_session: %{}}} = socket
      ) do
    reason = short_string_param(params, "reason", 40) || "signaling_unavailable"

    {:halt,
     socket
     |> mark_p2p_failed("signaling_" <> reason)
     |> open_p2p_console("call")
     |> Surface.system(dgettext("chat", "The P2P signaling channel refused this session."))}
  end

  def handle_event(
        "lobby_state_change",
        %{"state" => "disconnected"},
        %{assigns: %{p2p_session: %{}}} = socket
      ) do
    {:halt, mark_p2p_reconnecting(socket, nil, "disconnected", %{trigger: "connection_state"})}
  end

  def handle_event("lobby_state_change", _params, %{assigns: %{p2p_session: %{}}} = socket) do
    {:halt, socket}
  end

  def handle_event("lobby_failed", params, %{assigns: %{p2p_session: %{}}} = socket) do
    reason = params["reason"] || params[:reason] || "failed"
    duplicate? = p2p_failed?(socket.assigns.p2p_session, reason)

    socket =
      socket
      |> mark_p2p_failed(reason)
      |> open_p2p_console("call")

    socket =
      if duplicate? do
        socket
      else
        Surface.system(socket, dgettext("chat", "P2P connection failed."))
      end

    {:halt, socket}
  end

  def handle_event("lobby_retry", params, %{assigns: %{p2p_session: %{}}} = socket) do
    attempt = integer_param(params, "attempt")
    reason = short_string_param(params, "reason", 80) || "auto_retry"
    {:halt, mark_p2p_reconnecting(socket, attempt, reason, %{trigger: "auto"})}
  end

  def handle_event("lobby_recovery_pending", params, %{assigns: %{p2p_session: %{}}} = socket) do
    reason = short_string_param(params, "reason", 80) || "disconnected"
    {:halt, mark_p2p_reconnecting(socket, nil, reason, %{trigger: "disconnected"})}
  end

  def handle_event("p2p_retry_connection", _params, %{assigns: %{p2p_session: %{}}} = socket) do
    p2p = socket.assigns.p2p_session
    broadcast(p2p.token, "lobby_manual_retry", %{from: p2p.user_id})

    {:halt,
     socket
     |> mark_p2p_reconnecting(nil, "manual_retry", %{trigger: "manual"})
     |> push_event("lobby_restart", webrtc_payload(p2p))}
  end

  def handle_event("lobby_media_restart", params, %{assigns: %{p2p_session: %{}}} = socket) do
    p2p = socket.assigns.p2p_session
    reason = params["reason"] || params[:reason] || "media_restart"

    broadcast(p2p.token, "lobby_media_restart", %{from: p2p.user_id, reason: reason})

    {:halt,
     socket
     |> mark_p2p_reconnecting(nil, reason, %{trigger: "media_restart"})
     |> push_event("lobby_restart", webrtc_payload(p2p))}
  end

  def handle_event("lobby_stats", payload, %{assigns: %{p2p_session: %{}}} = socket) do
    p2p = socket.assigns.p2p_session
    {:halt, put_p2p(socket, %{p2p | stats: P2PStats.normalize(payload)})}
  end

  def handle_event("toggle_network_info", _params, %{assigns: %{p2p_session: %{}}} = socket) do
    p2p = socket.assigns.p2p_session
    {:halt, put_p2p(socket, %{p2p | info_open: not p2p.info_open})}
  end

  def handle_event(
        "p2p_console_select",
        %{"section" => section},
        %{assigns: %{p2p_session: %{}}} = socket
      ) do
    {:halt, open_p2p_console(socket, section)}
  end

  def handle_event("p2p_console_select", _params, socket), do: {:halt, socket}

  # Privacy mode: force every P2P connection through the TURN relay (hides
  # the direct peer IP). Persisted per trusted terminal; if WebRTC is already
  # active, the connection is restarted immediately so the transport policy is
  # real now.
  def handle_event("p2p_toggle_privacy", _params, %{assigns: %{p2p_session: %{}}} = socket) do
    p2p = socket.assigns.p2p_session
    new_value = not p2p.turn_only

    save_p2p_setup_preferences(socket, %{
      media: media_from_media_mode(p2p.media_mode),
      device_preferences: Map.get(p2p, :device_preferences, MediaDevices.no_preference()),
      turn_only: new_value
    })

    p2p = %{p2p | turn_only: new_value}

    label =
      if new_value,
        do: dgettext("chat", "Privacy mode enabled — the P2P connection will use the relay."),
        else: dgettext("chat", "Privacy mode disabled.")

    socket =
      socket
      |> put_p2p(p2p)
      |> Surface.system(label)

    if p2p_webrtc_active?(p2p) do
      broadcast(p2p.token, "lobby_manual_retry", %{from: p2p.user_id, reason: "privacy_changed"})

      {:halt,
       socket
       |> mark_p2p_reconnecting(nil, "privacy_changed", %{trigger: "privacy"})
       |> push_event("lobby_restart", webrtc_payload(p2p))}
    else
      {:halt, socket}
    end
  end

  def handle_event("p2p_start_audio", _params, %{assigns: %{p2p_session: %{}}} = socket) do
    forward_media(socket, "start_call", %{"type" => "audio"})
  end

  def handle_event("p2p_start_video", _params, %{assigns: %{p2p_session: %{}}} = socket) do
    forward_media(socket, "start_call", %{"type" => "video"})
  end

  # Media is self-controlled: the LobbyMediaHook and the Call window's controls
  # push to this root LV; the whole family forwards to the P2PMediaIsland, which
  # owns the call state and drives its window. Ending a call clears the
  # host-held telemetry.
  def handle_event(
        "lobby_media_call_ended" = event,
        params,
        %{assigns: %{p2p_session: %{}}} = socket
      ) do
    {:halt, socket} = forward_media(socket, event, params)
    p2p = socket.assigns.p2p_session
    {:halt, put_p2p(socket, %{p2p | stats: P2PStats.empty()})}
  end

  # The media hook finished its lazy load and is listening. This is the
  # race-free moment to auto-start the call: both sides open mic+camera on
  # connect (the single-offerer model absorbs the simultaneous start). Once
  # per session; the unified P2P console is now surfaced on mobile too.
  def handle_event(
        "lobby_media_hook_ready",
        _params,
        %{assigns: %{p2p_session: %{}}} = socket
      ) do
    p2p = socket.assigns.p2p_session

    if p2p.state == :connected and not p2p.auto_call_started do
      socket =
        case p2p[:media_mode] || "video" do
          "video" ->
            {:halt, socket} =
              forward_media(socket, "start_call", start_call_payload(p2p, "video"))

            socket

          "audio" ->
            {:halt, socket} = forward_media(socket, "join_call", %{})

            socket

          _receive_only ->
            socket
        end

      {:halt, put_p2p(socket, %{p2p | auto_call_started: true})}
    else
      {:halt, socket}
    end
  end

  def handle_event("lobby_media_" <> _ = event, params, %{assigns: %{p2p_session: %{}}} = socket) do
    forward_media(socket, event, params)
  end

  def handle_event(event, params, %{assigns: %{p2p_session: %{}}} = socket)
      when event in ~w(start_call end_call set_call_layout cycle_call_self_view media_select_preset send_call_reaction) do
    forward_media(socket, event, params)
  end

  def handle_event("cycle_call_layout", params, %{assigns: %{p2p_session: %{}}} = socket) do
    forward_media(socket, "cycle_call_layout", params)
  end

  def handle_event("lobby_game_canvas_ready", _params, %{assigns: %{p2p_session: %{}}} = socket) do
    Phoenix.LiveView.send_update(P2PGameIsland, id: P2PGameIsland.id(), action: :canvas_ready)
    {:halt, socket}
  end

  def handle_event(
        "propose_game",
        %{"game_id" => game_id},
        %{assigns: %{p2p_session: %{}}} = socket
      ) do
    p2p = socket.assigns.p2p_session
    _ = Lobby.propose_game(p2p.token, p2p.user_id, game_id)
    {:halt, socket}
  end

  def handle_event(
        "respond_game",
        %{"accepted" => accepted},
        %{assigns: %{p2p_session: %{}}} = socket
      ) do
    p2p = socket.assigns.p2p_session
    _ = Lobby.respond_game(p2p.token, p2p.user_id, accepted == "true")
    {:halt, socket}
  end

  # A game close/cancel action quits whatever is there: a playing game ends for
  # both peers; an open picker or pending proposal returns to the session.
  def handle_event("end_game", _params, %{assigns: %{p2p_session: %{}}} = socket) do
    p2p = socket.assigns.p2p_session
    _ = Lobby.end_game(p2p.token, p2p.user_id)

    Phoenix.LiveView.send_update(P2PGameIsland, id: P2PGameIsland.id(), action: :end_game)

    {:halt, socket}
  end

  # Only the host's game engine fires onGameEnd; it reports the authoritative
  # result and the server relays "finished" (with the score) to both peers.
  def handle_event("lobby_game_result", result, %{assigns: %{p2p_session: %{}}} = socket) do
    p2p = socket.assigns.p2p_session
    _ = Lobby.finish_game(p2p.token, p2p.user_id, result)
    {:halt, socket}
  end

  # Both peers report their own view of the match every few seconds. Game state
  # never reaches the server, so these samples are the only evidence a match was
  # smooth on one side and stuttering on the other. The RTT is grafted on here
  # because the connection stats already know it and the game engine does not.
  def handle_event("lobby_game_telemetry", payload, %{assigns: %{p2p_session: %{}}} = socket) do
    p2p = socket.assigns.p2p_session
    rtt_ms = get_in(p2p.stats, [:connection, :rtt_ms]) || 0

    _ = GameTelemetry.report(payload, %{rtt_ms: rtt_ms})

    {:halt, socket}
  end

  def handle_event("dismiss_game_result", _params, %{assigns: %{p2p_session: %{}}} = socket) do
    Phoenix.LiveView.send_update(P2PGameIsland, id: P2PGameIsland.id(), action: :dismiss_result)
    {:halt, socket}
  end

  # The game canvas failed to load its engine bundle: end the game for both
  # peers (it cannot be played one-sided) and tell the user why.
  def handle_event("lobby_game_error", _params, %{assigns: %{p2p_session: %{}}} = socket) do
    p2p = socket.assigns.p2p_session
    _ = Lobby.end_game(p2p.token, p2p.user_id)

    {:halt,
     Surface.system(
       socket,
       dgettext("chat", "Could not load the game. Please try again.")
     )}
  end

  # File-transfer control rides the data channel; the hook's ft_* events are
  # forwarded verbatim to the island.
  # `file_transfer_ready` does not share the ft_ prefix.
  def handle_event("file_transfer_ready", _params, %{assigns: %{p2p_session: %{}}} = socket) do
    forward_ft(socket, "file_transfer_ready", %{})
  end

  def handle_event("ft_" <> _ = event, params, %{assigns: %{p2p_session: %{}}} = socket) do
    forward_ft(socket, event, params)
  end

  def handle_event("p2p_end_session", _params, socket) do
    request_stop(socket)
  end

  # `[Ready]`: the devices are chosen, so the anchor may be rendered and the
  # hook may mount. The second half of readiness — the hook actually
  # listening — reports back as `lobby_webrtc_ready`, and only then does the
  # domain hear about it. Splitting it any other way is how the first offer
  # reaches a client that is not listening.
  def handle_event(
        "p2p_room_ready",
        %{"p2p_setup" => params},
        %{assigns: %{p2p_session: %{}}} = socket
      ) do
    setup_opts =
      setup_options_from_params(socket, params, socket.assigns.p2p_session.turn_configured)

    {:halt,
     socket
     |> apply_setup_options(setup_opts)
     |> update(
       :setup,
       &Map.merge(&1, Map.take(setup_opts, [:media, :turn_only, :device_preferences]))
     )
     |> update(:p2p_session, &%{&1 | room_ready: true})}
  end

  def handle_event("p2p_room_ready", _params, socket), do: {:halt, socket}

  # `[Start]`: the creator is always the offerer, so this is the only button
  # that can release a first offer, and only the creator has it.
  def handle_event(
        "p2p_room_start",
        _params,
        %{assigns: %{p2p_session: %{role: :creator} = p2p}} = socket
      ) do
    if room_can_start?(p2p) do
      broadcast(p2p.token, "lobby_session_start", %{})

      {:halt,
       socket
       |> put_p2p(%{p2p | session_started: true})
       |> start_webrtc(%{p2p | session_started: true})
       |> open_p2p_console(started_section(p2p))}
    else
      {:halt, socket}
    end
  end

  def handle_event("p2p_room_start", _params, socket), do: {:halt, socket}

  # The host stops waiting: the room closes and the address dies with it,
  # rather than standing until the deadline sweeps it.
  def handle_event(
        "p2p_room_cancel",
        _params,
        %{assigns: %{p2p_session: %{role: :creator}}} = socket
      ) do
    request_stop(socket)
  end

  def handle_event("p2p_room_cancel", _params, socket), do: {:halt, socket}

  # Taking the session back into this page: the same seat grab a fresh mount
  # does, asked for by the window that lost it.
  def handle_event(
        "p2p_room_reclaim",
        _params,
        %{assigns: %{p2p_session: %{displaced: true} = p2p}} = socket
      ) do
    {:halt, attach_session(socket, p2p.token, p2p.user_id, p2p.role)}
  end

  def handle_event("p2p_room_reclaim", _params, socket), do: {:halt, socket}

  def handle_event("p2p_setup_devices_listed", payload, %{assigns: %{setup: %{}}} = socket) do
    {:halt,
     update(socket, :setup, fn setup ->
       Map.put(setup, :devices, normalize_devices(payload))
     end)}
  end

  def handle_event("p2p_setup_devices_listed", _payload, socket), do: {:halt, socket}

  def handle_event(
        "p2p_setup_preferences_loaded",
        payload,
        %{assigns: %{setup: %{}}} = socket
      ) do
    preferences = normalize_p2p_setup_preferences(payload)

    {:halt,
     update(socket, :setup, fn setup ->
       setup
       |> Map.put(:media, preferences.media)
       |> Map.put(:media_mode, media_mode_from_preferences(preferences))
       |> Map.put(:device_preferences, preferences.device_preferences)
     end)}
  end

  def handle_event("p2p_setup_preferences_loaded", _payload, socket), do: {:halt, socket}

  def handle_event("p2p_toggle_call_mini", _params, %{assigns: %{p2p_session: %{}}} = socket) do
    p2p = socket.assigns.p2p_session
    mini = not Map.get(p2p, :call_mini, false)

    {:halt,
     socket
     |> put_p2p(Map.put(p2p, :call_mini, mini))
     |> push_p2p_call_geometry(mini)}
  end

  def handle_event("p2p_toggle_call_mini", _params, socket), do: {:halt, socket}

  def handle_event("p2p_confirm_end", _params, socket) do
    close_dialog()

    case socket.assigns.p2p_session do
      %{} = p2p ->
        persist_p2p_system(
          socket,
          p2p.peer_nick,
          dgettext("chat", "%{nick} ended the P2P session.", nick: socket.assigns.nickname)
        )

        _ = Lobby.close_session(p2p.token, p2p.user_id, "user_closed")
        {:halt, socket}

      nil ->
        {:halt, socket}
    end
  end

  def handle_event("p2p_confirm_cancel", _params, socket) do
    close_dialog()
    {:halt, socket}
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}

  # ── PubSub events (topic "lobby:#{token}") ────────────────────

  # Session-topic envelopes carry the token: events from a session that is no
  # longer the current one (a switch already unsubscribed, but its last
  # messages were enqueued first) are dropped instead of tearing down the
  # NEW session — the exact stale-close race of the A→B switch protocol.
  @spec handle_info(term(), Socket.t()) :: {:cont | :halt, Socket.t()}
  # A page that has lost its seat is no longer the connection; it draws the way
  # back and nothing else, so the events of a session it no longer holds are
  # not its business either.
  def handle_info(%{event: "lobby_" <> _rest, token: token} = msg, socket) do
    case socket.assigns.p2p_session do
      %{token: ^token, displaced: true} -> {:halt, socket}
      %{token: ^token} = p2p -> handle_session_event(msg, socket, p2p)
      _other_session -> {:halt, socket}
    end
  end

  # User-topic lobby events without a token envelope (lobby_session_ended).
  def handle_info(%{event: "lobby_" <> _rest}, socket), do: {:halt, socket}

  # Another page of this same person asked for this seat and got it. The anchor
  # stops being rendered, so the hook is destroyed and this browser's peer
  # connection goes down with it — which is the honest outcome: one person is
  # one participant, and the media belongs to the page they are looking at.
  def handle_info({:lobby_slot_taken, token}, socket) do
    case socket.assigns.p2p_session do
      %{token: ^token} = p2p ->
        {:halt,
         socket
         |> put_p2p(%{p2p | displaced: true, webrtc_started: false, hook_ready: false})
         |> Surface.system(dgettext("chat", "This P2P session moved to another window of yours."))}

      _other_session ->
        {:halt, socket}
    end
  end

  def handle_info({:p2p_console_section, section}, socket) do
    {:halt, open_p2p_console(socket, section)}
  end

  # C2 read-model bubbles from the feature islands (taskbar badges + the
  # Statistics strip read them from the host state).
  def handle_info({:feature_summary, feature, summary}, socket)
      when feature in [:file, :call, :game] do
    case socket.assigns.p2p_session do
      nil ->
        {:halt, socket}

      p2p ->
        {:halt, put_p2p(socket, Map.put(p2p, summary_key(feature), summary))}
    end
  end

  def handle_info({:p2p_call_reaction_timeout, reaction_id}, socket) do
    Phoenix.LiveView.send_update(P2PMediaIsland,
      id: P2PMediaIsland.id(),
      action: {:clear_reaction, reaction_id}
    )

    {:halt, socket}
  end

  # C1 sink with the single-writer rule (plan §4.3): shared notices are
  # persisted into the PM as "p2p_system" by exactly ONE side (the writer);
  # the other side drops its copy and renders the arriving PM instead.
  # Local-only notices (device errors) stay ephemeral.
  def handle_info({:p2p_feature_notice, _feature, text, opts}, socket) do
    case {Keyword.get(opts, :scope, :local), socket.assigns.p2p_session} do
      {_scope, nil} ->
        {:halt, socket}

      {:shared, p2p} ->
        if Keyword.get(opts, :writer, false),
          do: persist_p2p_system(socket, p2p.peer_nick, p2p_notice_text(text))

        {:halt, socket}

      {:local, _p2p} ->
        {:halt, p2p_system_event(socket, text)}
    end
  end

  def handle_info(_msg, socket), do: {:cont, socket}

  defp summary_key(:file), do: :file_summary
  defp summary_key(:call), do: :call_summary
  defp summary_key(:game), do: :game_summary

  defp forward_ft(socket, event, params) do
    Phoenix.LiveView.send_update(P2PFileIsland,
      id: P2PFileIsland.id(),
      action: {:ft_event, event, params}
    )

    {:halt, socket}
  end

  defp forward_media(socket, event, params) do
    Phoenix.LiveView.send_update(P2PMediaIsland,
      id: P2PMediaIsland.id(),
      action: {:media_event, event, params}
    )

    {:halt, socket}
  end

  defp handle_session_event(
         %{event: "lobby_status_changed", payload: %{status: status} = payload},
         socket,
         p2p
       ) do
    cond do
      status == "connected" ->
        {:halt, enter_connected(socket, p2p)}

      LobbySession.terminal?(status) ->
        {:halt, finish_session(socket, payload[:reason] || status)}

      true ->
        {:halt, socket}
    end
  end

  # Both hooks have reported ready. That used to mean "go", and going was
  # invisible; now it means the room can say so. The answerer still prepares
  # itself the moment it is told — its `lobby_start_answer` only builds the
  # peer connection and waits — because the first offer is dropped if it is
  # not listening yet. What waits is the *offer*, and it waits for the host.
  defp handle_session_event(
         %{event: "lobby_start_signaling", payload: payload},
         socket,
         p2p
       ) do
    p2p = %{p2p | peer_ready: true}
    socket = put_p2p(socket, p2p)

    cond do
      # This page is the rebuild the restart is announcing, not a target of it:
      # its connection was built moments ago by its own start, and tearing that
      # down restarts the round that is already in flight — the peer then holds
      # an offer whose answer belongs to a connection that no longer exists.
      # A page that has not started yet is not that page: it still needs the
      # start the branch below gives it.
      truthy?(value(payload, :restart)) and p2p.webrtc_started and
          p2p.webrtc_connection_reset ->
        {:halt, socket}

      truthy?(value(payload, :restart)) ->
        {:halt, restart_webrtc_from_signaling(socket, p2p, value(payload, :reason))}

      p2p.session_started ->
        # A side that rejoined mid-call re-arms the gate; the host says again
        # that the session is running, so the returning room does not sit there
        # waiting for a `[Start]` that was already pressed.
        if p2p.role == :creator, do: broadcast(p2p.token, "lobby_session_start", %{})
        {:halt, start_webrtc(socket, p2p)}

      # The answerer builds its peer connection now and waits — it is still in
      # the room, and "connecting" would be a lie about a negotiation nobody
      # has released yet.
      p2p.role == :peer ->
        {:halt, start_webrtc(socket, p2p, :joining)}

      true ->
        {:halt, socket}
    end
  end

  # The host pressed `[Start]`, or is saying again that they already did.
  # Everyone leaves the room together, which is what makes the wait legible
  # from the other side — and what stops a page that reloaded mid-negotiation
  # from being asked to press Ready for a session that is already running.
  defp handle_session_event(%{event: "lobby_session_start"}, socket, p2p) do
    started = %{p2p | session_started: true, room_ready: true, state: :connecting}

    {:halt,
     socket
     |> put_p2p(started)
     |> start_webrtc(started)
     |> open_p2p_console("call")}
  end

  defp handle_session_event(
         %{event: "lobby_manual_retry", payload: %{from: from} = payload},
         socket,
         p2p
       ) do
    if from == p2p.user_id do
      {:halt, socket}
    else
      {:halt,
       socket
       |> mark_p2p_reconnecting(nil, payload[:reason] || "peer_manual_retry", %{trigger: "peer"})
       |> open_p2p_console("call")
       |> push_event("lobby_restart", webrtc_payload(p2p))}
    end
  end

  defp handle_session_event(
         %{event: "lobby_media_restart", payload: %{from: from} = payload},
         socket,
         p2p
       ) do
    if from == p2p.user_id do
      {:halt, socket}
    else
      {:halt,
       socket
       |> mark_p2p_reconnecting(nil, payload[:reason] || "peer_media_restart", %{
         trigger: "peer"
       })
       |> open_p2p_console("call")
       |> push_event("lobby_restart", webrtc_payload(p2p))}
    end
  end

  # The creator holds :invite_sent WITHOUT having joined — a pending invite is
  # just a card, not a connection. The peer joining is the cue to join from
  # here.
  defp handle_session_event(%{event: "lobby_peer_joined", payload: %{user_id: uid}}, socket, p2p) do
    cond do
      uid == p2p.user_id -> {:halt, socket}
      p2p.state == :invite_sent -> {:halt, seat_taken(socket, p2p)}
      true -> {:halt, peer_rejoined(socket, p2p)}
    end
  end

  defp handle_session_event(
         %{event: "lobby_peer_disconnected", payload: %{user_id: uid}},
         socket,
         p2p
       ) do
    cond do
      uid == p2p.user_id ->
        {:halt, socket}

      # Nothing was connected yet, so nothing was lost. Someone arriving at a
      # match link goes through the resolver and then the surface, and the
      # page swap in between releases the seat for an instant: saying "lost the
      # P2P connection" there names a connection that never existed, and the
      # sentence then sits in the status bar through the whole session.
      p2p.state != :connected ->
        {:halt, put_p2p(socket, %{p2p | peer_online: false})}

      true ->
        {:halt,
         socket
         |> put_p2p(%{p2p | peer_online: false})
         |> Surface.system(
           dgettext("chat", "%{peer} lost the P2P connection — waiting for them to return...",
             peer: p2p.peer_nick
           )
         )}
    end
  end

  defp handle_session_event(
         %{event: "lobby_media_changed", payload: payload},
         socket,
         p2p
       ) do
    unless payload.user_id == p2p.user_id do
      Phoenix.LiveView.send_update(P2PMediaIsland,
        id: P2PMediaIsland.id(),
        device_preferences: Map.get(p2p, :device_preferences, MediaDevices.no_preference()),
        media_mode: Map.get(p2p, :media_mode, "video"),
        action: {:peer_media_changed, payload}
      )
    end

    {:halt, socket}
  end

  defp handle_session_event(
         %{event: "lobby_peer_mute", payload: %{muted: muted, from: from}},
         socket,
         p2p
       ) do
    unless from == p2p.user_id do
      Phoenix.LiveView.send_update(P2PMediaIsland,
        id: P2PMediaIsland.id(),
        action: {:peer_mute, muted}
      )
    end

    {:halt, socket}
  end

  defp handle_session_event(
         %{event: "lobby_peer_camera", payload: %{off: off, from: from}},
         socket,
         p2p
       ) do
    unless from == p2p.user_id do
      Phoenix.LiveView.send_update(P2PMediaIsland,
        id: P2PMediaIsland.id(),
        action: {:peer_camera, off}
      )
    end

    {:halt, socket}
  end

  defp handle_session_event(
         %{event: "lobby_peer_screen_share", payload: %{active: active, from: from}},
         socket,
         p2p
       ) do
    unless from == p2p.user_id do
      Phoenix.LiveView.send_update(P2PMediaIsland,
        id: P2PMediaIsland.id(),
        action: {:peer_screen_share, active}
      )
    end

    {:halt, socket}
  end

  defp handle_session_event(
         %{
           event: "lobby_peer_reaction",
           payload: %{reaction: reaction, reaction_id: id, from: from}
         },
         socket,
         p2p
       ) do
    unless from == p2p.user_id do
      Phoenix.LiveView.send_update(P2PMediaIsland,
        id: P2PMediaIsland.id(),
        action: {:peer_reaction, reaction, id}
      )
    end

    {:halt, socket}
  end

  # The game a match link named needs no second yes: following the link was the
  # consent, and an accept/decline dialog in front of it would be the product
  # asking whether you meant the address you just opened. Any *other* game
  # proposed inside the same session still asks, because that one nobody agreed
  # to yet.
  defp handle_session_event(
         %{event: "lobby_game_request", payload: %{game_id: game_id} = request},
         socket,
         %{match_game_id: game_id} = p2p
       )
       when is_binary(game_id) do
    if request.proposer_id == p2p.user_id do
      {:halt, open_p2p_console(socket, "games")}
    else
      _ = Lobby.respond_game(p2p.token, p2p.user_id, true)
      {:halt, open_p2p_console(socket, "games")}
    end
  end

  defp handle_session_event(%{event: "lobby_game_request", payload: request}, socket, p2p) do
    outgoing = request.proposer_id == p2p.user_id

    Phoenix.LiveView.send_update(P2PGameIsland,
      id: P2PGameIsland.id(),
      action: {:request, request, outgoing}
    )

    {:halt, open_p2p_console(socket, "games")}
  end

  defp handle_session_event(
         %{event: "lobby_game_response", payload: %{accepted: false}},
         socket,
         _p2p
       ) do
    Phoenix.LiveView.send_update(P2PGameIsland,
      id: P2PGameIsland.id(),
      action: :request_declined
    )

    {:halt, Surface.system(socket, dgettext("chat", "Game request declined."))}
  end

  defp handle_session_event(
         %{event: "lobby_game_response", payload: %{accepted: true}},
         socket,
         _p2p
       ) do
    {:halt, socket}
  end

  defp handle_session_event(
         %{event: "lobby_game_status_changed", payload: %{status: "playing"} = payload},
         socket,
         p2p
       ) do
    is_host = payload.host_id == p2p.user_id

    Phoenix.LiveView.send_update(P2PGameIsland,
      id: P2PGameIsland.id(),
      action: {:playing, payload.game_id, is_host}
    )

    {:halt, open_p2p_console(socket, "games")}
  end

  defp handle_session_event(
         %{event: "lobby_game_status_changed", payload: %{status: "idle"}},
         socket,
         _p2p
       ) do
    Phoenix.LiveView.send_update(P2PGameIsland, id: P2PGameIsland.id(), action: :idle)

    {:halt, socket}
  end

  defp handle_session_event(
         %{event: "lobby_game_status_changed", payload: %{status: "finished"} = payload},
         socket,
         _p2p
       ) do
    Phoenix.LiveView.send_update(P2PGameIsland,
      id: P2PGameIsland.id(),
      action: {:result, payload.result}
    )

    {:halt, open_p2p_console(socket, "games")}
  end

  defp handle_session_event(
         %{event: "lobby_client_info", payload: %{from: from, info: info}},
         socket,
         p2p
       ) do
    if from == p2p.user_id do
      {:halt, socket}
    else
      {:halt, put_p2p(socket, %{p2p | peer_info: info, peer_online: true})}
    end
  end

  defp handle_session_event(
         %{event: "lobby_session_closed", payload: %{reason: reason}},
         socket,
         _p2p
       ) do
    {:halt, finish_session(socket, reason)}
  end

  defp handle_session_event(%{event: "lobby_inactivity_warning"}, socket, _p2p) do
    {:halt,
     Surface.system(
       socket,
       dgettext("chat", "The P2P session will expire soon due to inactivity.")
     )}
  end

  # Session-topic events the in-chat host doesn't render directly. Feature
  # windows consume their own relays through their islands/hooks.
  defp handle_session_event(_msg, socket, _p2p), do: {:halt, socket}

  # The other side has arrived, so this page takes its own seat. A match link
  # had nobody to name when it mounted, so the peer's nickname is read now
  # rather than remembered: for an open lobby this arrival *is* the moment
  # there is one.
  defp seat_taken(socket, p2p) do
    case Lobby.join_session(p2p.token, p2p.user_id) do
      :ok ->
        p2p = %{p2p | peer_nick: p2p.peer_nick || peer_nick_for(p2p.token, p2p.user_id)}

        socket
        |> put_p2p(%{p2p | state: :joining, peer_online: true})
        |> share_client_info(p2p)
        |> Surface.system(
          dgettext("chat", "%{peer} accepted the P2P request - connecting...",
            peer: p2p.peer_nick || dgettext("chat", "The other user")
          )
        )

      {:error, :already_joined} ->
        detach_session(socket, p2p)

      {:error, message} ->
        socket |> detach_session(p2p) |> Surface.system(message)
    end
  end

  # Somebody joined a session this page is already in. Re-share our whois so a
  # peer that joined after us still receives it, and — if this session is
  # already running — say so, because the page that just arrived cannot know it
  # and would otherwise sit in the starting room waiting for a `[Start]` that
  # was pressed minutes ago.
  defp peer_rejoined(socket, p2p) do
    if p2p.session_started, do: broadcast(p2p.token, "lobby_session_start", %{})

    socket =
      socket
      |> put_p2p(%{p2p | peer_online: true})
      |> share_client_info(p2p)

    # A worry that turned out fine has to be taken back, or it stays on screen
    # for the rest of the session saying the opposite of the truth.
    if p2p.state == :connected and not p2p.peer_online do
      Surface.system(socket, dgettext("chat", "%{peer} is back.", peer: p2p.peer_nick))
    else
      socket
    end
  end

  defp new_session(socket, token, user_id, role, state, opts) do
    setup_preferences = load_p2p_setup_preferences(socket)

    %{
      token: token,
      user_id: user_id,
      role: role,
      # The game this session was created for, or nil for a plain session.
      # It is the difference between a room with devices in it and a room with
      # a game in it, and it is read from the session rather than the address.
      match_game_id: Keyword.get(opts, :match_game_id),
      match_proposed: false,
      peer_nick: peer_nick_for(token, user_id),
      state: state,
      webrtc_started: false,
      # Whether this page's start announces a rebuild. A page that opens into a
      # session already negotiating is one — whatever releases its start, the
      # peer has to be told the connection is new, or it reads this page's first
      # offer as stale for the rest of the session. It is also what makes the
      # resend to a hook that was still loading say the same thing twice.
      webrtc_connection_reset: false,
      # The starting room, in three facts. `room_ready` is the devices chosen,
      # `hook_ready` is the WebRTC hook mounted — `[Ready]` needs both, and the
      # domain's gate is what turns the pair on the other side into
      # `peer_ready`. `session_started` is the host having pressed `[Start]`,
      # which is the only thing that releases the first offer.
      room_ready: false,
      hook_ready: false,
      peer_ready: false,
      session_started: false,
      displaced: false,
      stats: P2PStats.empty(),
      info_open: false,
      peer_online: false,
      peer_info: %{},
      file_summary: nil,
      call_summary: nil,
      game_summary: nil,
      auto_call_started: false,
      recovery: empty_p2p_recovery(),
      console_section: "call",
      media_mode: media_mode_from_preferences(setup_preferences),
      call_mini: false,
      device_preferences: setup_preferences.device_preferences,
      turn_only: setup_preferences.turn_only,
      turn_configured: P2P.turn_configured?()
    }
  end

  @doc """
  The creator of an invite nobody has accepted yet.

  Subscribed and drawn, but not seated: a pending invite is a card, and taking
  a seat would start the rejoin grace on a session with nobody in it.
  """
  @spec new_invite_sent(Socket.t(), String.t(), integer(), keyword()) :: map()
  def new_invite_sent(socket, token, user_id, opts \\ []) do
    new_session(socket, token, user_id, :creator, :invite_sent, opts)
  end

  @doc """
  The device half of the starting room, before the browser has listed anything.

  The person's remembered preferences, not the screen's: the terminal that
  remembered a camera for the chat's setup dialog hands it to the room that
  replaced it.
  """
  @spec initial_setup(Socket.t()) :: map()
  def initial_setup(socket) do
    preferences = load_p2p_setup_preferences(socket)

    %{
      media: preferences.media,
      media_mode: media_mode_from_preferences(preferences),
      devices: default_devices(),
      device_preferences: preferences.device_preferences,
      turn_only: preferences.turn_only,
      turn_configured: P2P.turn_configured?()
    }
  end

  @doc """
  Who is in the starting room and what each of them is still waiting on.

  Two seats and never more: a P2P session is one person talking to one person,
  and the empty half is exactly the half the reader is waiting for.
  """
  @spec room(map()) :: map()
  def room(%{p2p_session: %{} = p2p, nickname: nickname}) do
    %{
      nickname: nickname,
      match?: is_binary(p2p.match_game_id),
      peer_nick: p2p.peer_nick,
      host?: p2p.role == :creator,
      host_nick: if(p2p.role == :creator, do: nickname, else: p2p.peer_nick),
      ready?: p2p.room_ready,
      started?: p2p.session_started,
      peer_present?: p2p.state != :invite_sent,
      peer_ready?: p2p.peer_ready,
      can_start?: room_can_start?(p2p)
    }
  end

  @doc """
  Whether the creator's `[Start]` may be pressed.

  Both sides ready is the domain's own gate, arriving as `lobby_start_signaling`
  and recorded as `peer_ready`; the button is that gate with a face.
  """
  @spec room_can_start?(map()) :: boolean()
  def room_can_start?(%{role: :creator} = p2p),
    do: p2p.room_ready and p2p.hook_ready and p2p.peer_ready and not p2p.session_started

  def room_can_start?(_p2p), do: false

  # A match leaves its room straight into its game; a plain session leaves it
  # into the call, which is what it is.
  defp started_section(%{match_game_id: game_id}) when is_binary(game_id), do: "games"
  defp started_section(_p2p), do: "call"

  defp share_client_info(socket, p2p) do
    broadcast(p2p.token, "lobby_client_info", %{
      from: p2p.user_id,
      info: socket.assigns[:client_info] || %{}
    })

    socket
  end

  # Cancel a pending invite outright; anything past that needs the confirm.
  defp request_stop(socket) do
    case socket.assigns.p2p_session do
      %{state: :invite_sent} = p2p ->
        persist_p2p_system(
          socket,
          p2p.peer_nick,
          dgettext("chat", "%{nick} cancelled the P2P invite.", nick: socket.assigns.nickname)
        )

        _ = Lobby.cancel_invite(p2p.token, p2p.user_id)
        {:halt, socket}

      %{} = p2p ->
        Phoenix.LiveView.send_update(P2PConfirmDialog,
          id: P2PConfirmDialog.id(),
          action: {:open_end, p2p.peer_nick}
        )

        {:halt, socket}

      nil ->
        {:halt, socket}
    end
  end

  defp setup_options_from_params(socket, params, turn_configured?) do
    preferences = normalize_p2p_setup_preferences(params)

    media_mode =
      normalize_media_mode(params["media_mode"] || media_mode_from_preferences(preferences))

    turn_only = turn_configured? and truthy?(params["turn_only"])

    setup_opts = %{
      media_mode: media_mode,
      media: preferences.media,
      turn_only: turn_only,
      device_preferences: preferences.device_preferences
    }

    save_p2p_setup_preferences(socket, setup_opts)
    setup_opts
  end

  defp apply_setup_options(%{assigns: %{p2p_session: p2p}} = socket, setup_opts)
       when not is_nil(p2p) do
    update(socket, :p2p_session, fn p2p ->
      %{
        p2p
        | media_mode: setup_opts[:media_mode] || "video",
          device_preferences: setup_opts[:device_preferences] || MediaDevices.no_preference(),
          turn_only: setup_opts[:turn_only] == true
      }
    end)
  end

  defp apply_setup_options(socket, _setup_opts), do: socket

  defp maybe_persist_connected(socket, %{role: :creator, state: state} = p2p)
       when state != :connected do
    persist_p2p_system(
      socket,
      p2p.peer_nick,
      dgettext("chat", "P2P session connected - call, files, games and stats are available.")
    )

    socket
  end

  defp maybe_persist_connected(socket, _p2p), do: socket

  # Already connected (duplicate hook event / PubSub echo): keep the console in
  # place, but clear any transient recovery banner from a completed retry.
  # Being connected retires the rebuild flag: from here on this page is the one
  # that stays, and the next restart is about it.
  defp enter_connected(socket, %{state: :connected} = p2p) do
    emit_p2p_connected(p2p)

    put_p2p(socket, %{
      p2p
      | webrtc_started: true,
        webrtc_connection_reset: false,
        recovery: empty_p2p_recovery()
    })
  end

  defp enter_connected(socket, p2p) do
    emit_p2p_connected(p2p)

    socket
    |> maybe_persist_connected(p2p)
    |> put_p2p(%{
      p2p
      | state: :connected,
        webrtc_started: true,
        webrtc_connection_reset: false,
        recovery: empty_p2p_recovery()
    })
    |> burst_windows()
  end

  # The session presents itself the moment the link comes up, on both sides:
  # the unified P2P console opens in front. Call, Files, Games and Statistics
  # live inside that surface so mobile and desktop share one mental model.
  #
  # A match opens on its game instead, and the host puts it on the table: the
  # link already named the game and both sides agreed to it by being here, so a
  # picker in front of a match would ask a question that was answered by the
  # address.
  defp burst_windows(%{assigns: %{p2p_session: %{match_game_id: game_id}}} = socket)
       when is_binary(game_id) do
    socket |> open_p2p_console("games") |> propose_match_game()
  end

  defp burst_windows(socket) do
    open_p2p_console(socket, "call")
  end

  defp propose_match_game(
         %{assigns: %{p2p_session: %{role: :creator, match_proposed: false} = p2p}} = socket
       ) do
    _ = Lobby.propose_game(p2p.token, p2p.user_id, p2p.match_game_id)
    put_p2p(socket, %{p2p | match_proposed: true})
  end

  defp propose_match_game(socket), do: socket

  defp open_p2p_console(socket, section) do
    section = normalize_console_section(section)

    case socket.assigns.p2p_session do
      nil ->
        socket

      p2p ->
        was_mini? = Map.get(p2p, :call_mini, false)

        p2p =
          if section == "call" do
            p2p
          else
            Map.put(p2p, :call_mini, false)
          end

        socket
        |> put_p2p(Map.put(p2p, :console_section, section))
        |> maybe_expand_p2p_console(section, was_mini?)
    end
  end

  defp normalize_console_section(section) when section in ~w(call files games stats), do: section

  defp normalize_console_section(section) when is_atom(section),
    do: normalize_console_section(Atom.to_string(section))

  defp normalize_console_section(_section), do: "call"

  defp maybe_expand_p2p_console(socket, "call", _was_mini?), do: socket
  defp maybe_expand_p2p_console(socket, _section, true), do: push_p2p_call_geometry(socket, false)
  defp maybe_expand_p2p_console(socket, _section, false), do: socket

  # The mini call is a size, and a size is the window manager's. This page has
  # one of its own — the session is a Win98 desktop with the call window on it —
  # so the command goes straight to it. It used to be handed to the chat, which
  # is how mini mode came to be a checkbox that changed nothing whenever the
  # session was at its own address.
  defp push_p2p_call_geometry(socket, true) do
    push_window_geometry(socket, %{
      width: 300,
      height: 236,
      anchor: "bottom_right",
      margin: 16
    })
  end

  defp push_p2p_call_geometry(socket, false) do
    push_window_geometry(socket, %{
      width: @p2p_console_width,
      height: @p2p_console_height,
      x: @p2p_console_x,
      y: @p2p_console_y
    })
  end

  defp push_window_geometry(socket, geometry) do
    Phoenix.LiveView.push_event(
      socket,
      "window_command",
      geometry |> Map.put(:action, "set_geometry") |> Map.put(:id, @call_window_id)
    )
  end

  # A page that is asked to be in this session takes the seat, and the page
  # that held it is told. Two windows on one session used to mean the second
  # spent five backoff attempts and then gave up with "close that window" — a
  # dead end reached by doing something reasonable, and unreachable to fix from
  # the window you were looking at. The most recently opened page is the one
  # the person is looking at, which is the same contract the chat's own
  # takeover has.
  @spec attach_session(Socket.t(), String.t(), integer(), :creator | :peer, keyword()) ::
          Socket.t()
  def attach_session(socket, token, user_id, role, opts \\ []) do
    case Lobby.join_session(token, user_id, takeover: true) do
      :ok ->
        Phoenix.PubSub.subscribe(@pubsub, "lobby:#{token}")
        p2p = new_session(socket, token, user_id, role, :joining, opts)

        socket
        |> put_p2p(p2p)
        |> share_client_info(p2p)

      {:error, message} ->
        p2p_system_event(socket, message)
    end
  end

  defp detach_session(socket, p2p) do
    Phoenix.PubSub.unsubscribe(@pubsub, "lobby:#{p2p.token}")

    put_p2p(socket, nil)
  end

  # Reasons with a single writer already persisted a p2p_system line into the
  # PM (end/decline/cancel actors) — an ephemeral copy here would duplicate
  # it. Domain-driven ends (timeout, peer_left, failure) have no writer, so
  # both sides render the ephemeral line.
  @persisted_by_actor ~w(user_closed declined invite_cancelled user_blocked)

  defp finish_session(socket, reason) do
    p2p = socket.assigns.p2p_session

    socket =
      if reason in @persisted_by_actor do
        detach_session(socket, p2p)
      else
        socket
        |> detach_session(p2p)
        |> Surface.system(ended_message(p2p.peer_nick, reason))
      end

    Surface.close(socket)
  end

  # ICE config + the role-specific start event, exactly once per
  # (re)signaling round.
  defp start_webrtc(socket, p2p, next_state \\ :connecting, opts \\ [])

  defp start_webrtc(socket, %{webrtc_started: true} = _p2p, _next_state, _opts), do: socket

  defp start_webrtc(socket, p2p, next_state, opts) do
    connection_reset = Keyword.get(opts, :connection_reset, p2p.webrtc_connection_reset)

    payload = Map.put(webrtc_payload(p2p), :connection_reset, connection_reset)

    socket
    |> put_p2p(%{
      p2p
      | state: next_state,
        webrtc_started: true,
        webrtc_connection_reset: connection_reset
    })
    |> push_event(start_webrtc_event(p2p), payload)
  end

  defp start_webrtc_event(%{role: :creator}), do: "lobby_start_offer"
  defp start_webrtc_event(%{role: :peer}), do: "lobby_start_answer"

  # The readiness protocol's second half (`AGENT-GUIDE` §15). The WebRTC hook is
  # lazy, so a page that resumes into a running session pushes its start while
  # the implementation is still being imported — at nobody. The hook says when
  # it is listening, and the start is said again then; `handleStartOffer` and
  # `handleStartAnswer` both return early once they hold a connection, so a page
  # that did hear the first one does nothing with the second.
  #
  # Without this the loss is silent and permanent: the surface has recorded the
  # start, so it never pushes it again, and the restart that follows arrives at
  # a connection with no role and no ICE servers to rebuild from.
  defp resend_webrtc_start(socket, %{webrtc_started: true} = p2p) do
    payload = Map.put(webrtc_payload(p2p), :connection_reset, p2p.webrtc_connection_reset)

    push_event(socket, start_webrtc_event(p2p), payload)
  end

  defp resend_webrtc_start(socket, _p2p), do: socket

  defp restart_webrtc_from_signaling(socket, p2p, reason) do
    reason = reason || "signaling_restart"

    emit_p2p_recovery_transition(p2p, :reconnecting, reason, %{
      manual_retry: false,
      trigger: "server"
    })

    p2p = %{
      p2p
      | recovery: %{
          state: :reconnecting,
          attempt: nil,
          reason: reason,
          trigger: "server",
          manual_retry: false
        },
        stats: P2PStats.empty()
    }

    socket =
      socket
      |> put_p2p(p2p)
      |> open_p2p_console("call")

    if p2p.webrtc_started do
      push_event(socket, "lobby_restart", Map.put(webrtc_payload(p2p), :reason, reason))
    else
      # A page that has no connection yet but is being told to restart is a page
      # that opened into a session already running — a second tab that took the
      # seat, or a reload mid-call. It has to start as a *rebuild*, because the
      # peer kept its own signalling epoch and would read a fresh page's first
      # offer as stale for the rest of the session.
      start_webrtc(socket, p2p, :connecting, connection_reset: true)
    end
  end

  defp webrtc_payload(p2p) do
    %{
      ice_servers: P2P.ice_servers(to_string(p2p.user_id)),
      role: to_string(p2p.role),
      turn_only: p2p.turn_only && p2p.turn_configured
    }
  end

  defp p2p_webrtc_active?(p2p) do
    Map.get(p2p, :webrtc_started, false) || p2p.state in [:connecting, :connected]
  end

  defp put_p2p(socket, p2p), do: assign(socket, p2p_session: p2p)

  defp mark_p2p_reconnecting(socket, attempt, reason, metadata) do
    emit_p2p_recovery_transition(socket.assigns[:p2p_session], :reconnecting, reason, %{
      attempt: attempt,
      manual_retry: false,
      trigger: metadata[:trigger]
    })

    update(socket, :p2p_session, fn
      nil ->
        nil

      p2p ->
        %{
          p2p
          | recovery: %{
              state: :reconnecting,
              attempt: attempt,
              reason: reason,
              trigger: metadata[:trigger],
              manual_retry: false
            },
            stats: P2PStats.empty()
        }
    end)
  end

  defp mark_p2p_failed(socket, reason) do
    p2p = socket.assigns[:p2p_session]

    emit_p2p_recovery_transition(p2p, :failed, reason, %{
      manual_retry: true,
      phase: "connection"
    })

    CallEvents.emit_client_error(:p2p, reason, %{phase: "connection"})

    update(socket, :p2p_session, fn
      nil ->
        nil

      p2p ->
        %{
          p2p
          | recovery: %{
              state: :failed,
              attempt: nil,
              reason: reason,
              trigger: "connection",
              manual_retry: true
            },
            stats: P2PStats.empty()
        }
    end)
  end

  defp p2p_failed?(%{recovery: %{state: :failed, reason: reason}}, reason), do: true
  defp p2p_failed?(_p2p, _reason), do: false

  defp empty_p2p_recovery do
    %{state: :idle, attempt: nil, reason: nil, trigger: nil, manual_retry: false}
  end

  @spec p2p_system_event(Socket.t(), term()) :: Socket.t()
  defp p2p_system_event(socket, message) do
    Surface.system(socket, p2p_notice_text(message))
  end

  @spec p2p_notice_text(term()) :: String.t()
  defp p2p_notice_text(message) when is_binary(message), do: message

  defp p2p_notice_text(:not_found) do
    dgettext("chat", "This P2P invite is no longer active.")
  end

  defp p2p_notice_text(:already_joined) do
    dgettext("chat", "This P2P session is already active in another window.")
  end

  defp p2p_notice_text(reason) when is_atom(reason) do
    reason = reason |> Atom.to_string() |> String.replace("_", " ")
    dgettext("chat", "P2P action failed: %{reason}", reason: reason)
  end

  defp p2p_notice_text(reason) do
    dgettext("chat", "P2P action failed: %{reason}", reason: inspect(reason))
  end

  defp peer_nick_for(token, user_id) do
    case Lobby.session_summary(token) do
      {:ok, summary} ->
        case Lobby.get_session(token) do
          {:ok, %{creator_id: ^user_id}} -> summary.peer
          _ -> summary.created_by
        end

      _ ->
        nil
    end
  end

  defp ended_message(peer_nick, reason) do
    peer = peer_nick || dgettext("chat", "the other user")

    case reason do
      "declined" ->
        dgettext("chat", "%{peer} declined the P2P invite.", peer: peer)

      "invite_cancelled" ->
        dgettext("chat", "The P2P invite was cancelled.")

      "user_closed" ->
        dgettext("chat", "P2P session with %{peer} ended.", peer: peer)

      "peer_left" ->
        dgettext("chat", "%{peer} left the P2P session.", peer: peer)

      reason when reason in ["expired", "pending_timeout", "lobby_inactivity"] ->
        dgettext("chat", "The P2P session expired.")

      _ ->
        dgettext("chat", "P2P session with %{peer} ended.", peer: peer)
    end
  end

  defp start_call_payload(p2p, type) do
    %{
      "type" => type,
      "device_preferences" => Map.get(p2p, :device_preferences, MediaDevices.no_preference())
    }
  end

  defp normalize_media_mode(mode) when mode in ~w(video audio receive), do: mode
  defp normalize_media_mode(_mode), do: "video"

  defp default_p2p_setup_preferences do
    %{
      media: %{audio: true, video: true},
      device_preferences: MediaDevices.no_preference(),
      turn_only: false
    }
  end

  defp normalize_p2p_setup_preferences(preferences) when is_map(preferences) do
    defaults = default_p2p_setup_preferences()
    media = value(preferences, :media)

    audio =
      boolean_preference(preference_value(value(preferences, :audio), value(media, :audio)), true)

    video =
      boolean_preference(preference_value(value(preferences, :video), value(media, :video)), true)

    %{
      media: %{audio: audio, video: video},
      device_preferences: MediaDevices.preferences(preferences),
      turn_only: boolean_preference(value(preferences, :turn_only), defaults.turn_only)
    }
  end

  defp normalize_p2p_setup_preferences(_preferences), do: default_p2p_setup_preferences()

  defp media_mode_from_preferences(%{media: %{audio: true, video: true}}), do: "video"
  defp media_mode_from_preferences(%{media: %{audio: true, video: false}}), do: "audio"
  defp media_mode_from_preferences(_preferences), do: "receive"

  defp load_p2p_setup_preferences(%{assigns: %{nickname: nickname}} = socket)
       when is_binary(nickname) do
    socket.assigns[:trusted_device_id]
    |> TrustedDevices.get_device_preference(nickname, @p2p_setup_preference_namespace)
    |> normalize_p2p_setup_preferences()
  end

  defp load_p2p_setup_preferences(_socket), do: default_p2p_setup_preferences()

  defp save_p2p_setup_preferences(%{assigns: %{nickname: nickname}} = socket, preferences)
       when is_binary(nickname) do
    _ =
      TrustedDevices.put_device_preference(
        socket.assigns[:trusted_device_id],
        nickname,
        @p2p_setup_preference_namespace,
        persistable_p2p_setup_preferences(preferences)
      )

    :ok
  end

  defp save_p2p_setup_preferences(_socket, _preferences), do: :ok

  defp persistable_p2p_setup_preferences(preferences) do
    preferences = normalize_p2p_setup_preferences(preferences)

    %{
      "media" => %{
        "audio" => preferences.media.audio,
        "video" => preferences.media.video
      },
      "turn_only" => preferences.turn_only == true,
      "device_preferences" => %{
        "audio_input_id" => preferences.device_preferences.audio_input_id,
        "video_input_id" => preferences.device_preferences.video_input_id,
        "audio_output_id" => preferences.device_preferences.audio_output_id
      }
    }
  end

  defp default_devices, do: MediaDevices.none()

  defp normalize_devices(devices), do: MediaDevices.normalize(devices, unnamed_device())

  defp unnamed_device, do: dgettext("chat", "Default device")

  defp emit_p2p_connected(p2p) do
    case p2p_recovery_state(p2p) do
      state when state in [:reconnecting, :failed] ->
        emit_p2p_recovery_transition(p2p, :connected, p2p_recovery_reason(p2p), %{
          manual_retry: false,
          trigger: "connected"
        })

      _state ->
        :ok
    end
  end

  defp emit_p2p_recovery_transition(nil, _state, _reason, _metadata), do: :ok

  defp emit_p2p_recovery_transition(p2p, state, reason, metadata) when is_map(p2p) do
    CallEvents.emit_recovery_transition(
      :p2p,
      state,
      reason,
      Map.put(metadata, :role, Map.get(p2p, :role))
    )
  end

  defp p2p_recovery_state(%{recovery: %{state: state}}), do: state
  defp p2p_recovery_state(_p2p), do: nil

  defp p2p_recovery_reason(%{recovery: %{reason: reason}}) when not is_nil(reason), do: reason
  defp p2p_recovery_reason(_p2p), do: "connected"

  defp preference_value(nil, fallback), do: fallback
  defp preference_value(value, _fallback), do: value

  defp boolean_preference(value, _default) when value in [true, "true", "on", "1", 1], do: true

  defp boolean_preference(value, _default) when value in [false, "false", "off", "0", 0],
    do: false

  defp boolean_preference(_value, default), do: default

  defp media_from_media_mode("audio"), do: %{audio: true, video: false}
  defp media_from_media_mode("receive"), do: %{audio: false, video: false}
  defp media_from_media_mode(_mode), do: %{audio: true, video: true}

  defp value(map, key) when is_map(map) do
    cond do
      Map.has_key?(map, key) -> Map.get(map, key)
      Map.has_key?(map, to_string(key)) -> Map.get(map, to_string(key))
      true -> nil
    end
  end

  defp value(_map, _key), do: nil

  defp short_string_param(map, key, max_bytes) do
    case value(map, key) do
      value when is_binary(value) -> String.slice(value, 0, max_bytes)
      _ -> nil
    end
  end

  defp integer_param(map, key) do
    case value(map, key) do
      value when is_integer(value) -> value
      value when is_binary(value) -> parse_integer(value)
      _ -> nil
    end
  end

  defp parse_integer(value) do
    case Integer.parse(value) do
      {integer, ""} -> integer
      _ -> nil
    end
  end

  defp truthy?(value), do: value in [true, "true", "1", 1, "on"]

  defp close_dialog do
    Phoenix.LiveView.send_update(P2PConfirmDialog,
      id: P2PConfirmDialog.id(),
      action: :close
    )
  end

  # Persists a session notice into the PM thread (D2: the PM is the
  # conversation). The PM broadcast delivers it to BOTH sides — hence the
  # single-writer rule everywhere this is called.
  defp persist_p2p_system(socket, peer_nick, text) when is_binary(peer_nick) do
    _ =
      ChatService.send_private_message(
        socket.assigns.nickname,
        peer_nick,
        text,
        "p2p_system"
      )

    :ok
  end

  defp persist_p2p_system(_socket, _peer_nick, _text), do: :ok

  defp broadcast(token, event, payload) do
    Phoenix.PubSub.broadcast(@pubsub, "lobby:#{token}", %{
      event: event,
      payload: payload,
      token: token
    })
  end
end
