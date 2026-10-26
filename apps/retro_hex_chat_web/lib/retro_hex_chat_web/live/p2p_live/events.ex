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

  This module routes the browser's events; the rest sits beside it under
  `RetroHexChatWeb.P2PLive`: `SessionEvents` (what the session process says),
  `SessionLink` (the seat, subscriptions and persisted lines), `SessionStatus`
  (reconnecting, failed, and the sentences about it), `WebRTCStart`,
  `Console` (the console window) and `SetupPreferences`.
  """

  import Phoenix.Component, only: [assign: 2, update: 3]
  import Phoenix.LiveView, only: [push_event: 3]

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias Phoenix.LiveView.Socket
  alias RetroHexChat.Games.Telemetry, as: GameTelemetry
  alias RetroHexChat.Lobby
  alias RetroHexChat.Lobby.JoinToken
  alias RetroHexChat.Topics
  alias RetroHexChatWeb.App.P2PStats
  alias RetroHexChatWeb.Live.P2PConfirmDialog
  alias RetroHexChatWeb.Live.Surface
  alias RetroHexChatWeb.MediaDevices
  alias RetroHexChatWeb.P2PLive.Components.P2PFileIsland
  alias RetroHexChatWeb.P2PLive.Components.P2PGameIsland
  alias RetroHexChatWeb.P2PLive.Components.P2PMediaIsland

  alias RetroHexChatWeb.P2PLive.{
    Console,
    SessionEvents,
    SessionLink,
    SessionStatus,
    SetupPreferences,
    WebRTCStart
  }

  alias RetroHexChatWeb.Params

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
     |> SessionStatus.put_p2p(%{p2p | hook_ready: true})
     |> WebRTCStart.resend_start(p2p)}
  end

  def handle_event("lobby_connected", _params, %{assigns: %{p2p_session: %{}}} = socket) do
    p2p = socket.assigns.p2p_session
    _ = Lobby.transition_status(p2p.token, :connected)
    {:halt, SessionEvents.enter_connected(socket, p2p)}
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
     |> SessionStatus.mark_p2p_failed("signaling_" <> reason)
     |> Console.open("call")
     |> Surface.system(dgettext("chat", "The P2P signaling channel refused this session."))}
  end

  def handle_event(
        "lobby_state_change",
        %{"state" => "disconnected"},
        %{assigns: %{p2p_session: %{}}} = socket
      ) do
    {:halt,
     SessionStatus.mark_p2p_reconnecting(socket, nil, "disconnected", %{
       trigger: "connection_state"
     })}
  end

  def handle_event("lobby_state_change", _params, %{assigns: %{p2p_session: %{}}} = socket) do
    {:halt, socket}
  end

  def handle_event("lobby_failed", params, %{assigns: %{p2p_session: %{}}} = socket) do
    reason = params["reason"] || params[:reason] || "failed"
    duplicate? = SessionStatus.p2p_failed?(socket.assigns.p2p_session, reason)

    socket =
      socket
      |> SessionStatus.mark_p2p_failed(reason)
      |> Console.open("call")

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
    {:halt, SessionStatus.mark_p2p_reconnecting(socket, attempt, reason, %{trigger: "auto"})}
  end

  def handle_event("lobby_recovery_pending", params, %{assigns: %{p2p_session: %{}}} = socket) do
    reason = short_string_param(params, "reason", 80) || "disconnected"
    {:halt, SessionStatus.mark_p2p_reconnecting(socket, nil, reason, %{trigger: "disconnected"})}
  end

  def handle_event("p2p_retry_connection", _params, %{assigns: %{p2p_session: %{}}} = socket) do
    p2p = socket.assigns.p2p_session
    Lobby.broadcast(p2p.token, "lobby_manual_retry", %{from: p2p.user_id})

    {:halt,
     socket
     |> SessionStatus.mark_p2p_reconnecting(nil, "manual_retry", %{trigger: "manual"})
     |> push_event("lobby_restart", WebRTCStart.payload(p2p))}
  end

  def handle_event("lobby_media_restart", params, %{assigns: %{p2p_session: %{}}} = socket) do
    p2p = socket.assigns.p2p_session
    reason = params["reason"] || params[:reason] || "media_restart"

    Lobby.broadcast(p2p.token, "lobby_media_restart", %{from: p2p.user_id, reason: reason})

    {:halt,
     socket
     |> SessionStatus.mark_p2p_reconnecting(nil, reason, %{trigger: "media_restart"})
     |> push_event("lobby_restart", WebRTCStart.payload(p2p))}
  end

  def handle_event("lobby_stats", payload, %{assigns: %{p2p_session: %{}}} = socket) do
    p2p = socket.assigns.p2p_session
    {:halt, SessionStatus.put_p2p(socket, %{p2p | stats: P2PStats.normalize(payload)})}
  end

  def handle_event("toggle_network_info", _params, %{assigns: %{p2p_session: %{}}} = socket) do
    p2p = socket.assigns.p2p_session
    {:halt, SessionStatus.put_p2p(socket, %{p2p | info_open: not p2p.info_open})}
  end

  def handle_event(
        "p2p_console_select",
        %{"section" => section},
        %{assigns: %{p2p_session: %{}}} = socket
      ) do
    {:halt, Console.open(socket, section)}
  end

  def handle_event("p2p_console_select", _params, socket), do: {:halt, socket}

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
    {:halt, SessionStatus.put_p2p(socket, %{p2p | stats: P2PStats.empty()})}
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

      {:halt, SessionStatus.put_p2p(socket, %{p2p | auto_call_started: true})}
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

  # Both engines may report an end; the session takes the host's as the
  # result, writes the match down, and relays "finished" (with the score read
  # by `Games.Result`) to both peers.
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
      SetupPreferences.from_params(socket, params, socket.assigns.p2p_session.turn_configured)

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
    if SessionLink.room_can_start?(p2p) do
      _ = Lobby.mark_started(p2p.token, p2p.user_id)
      Lobby.broadcast(p2p.token, "lobby_session_start", %{})

      {:halt,
       socket
       |> SessionStatus.put_p2p(%{p2p | session_started: true})
       |> WebRTCStart.start(%{p2p | session_started: true})
       |> Console.open(started_section(p2p))}
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
    {:halt, SessionLink.attach_session(socket, p2p.token, p2p.user_id, p2p.role)}
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
    preferences = SetupPreferences.normalize(payload)

    {:halt,
     update(socket, :setup, fn setup ->
       setup
       |> Map.put(:media, preferences.media)
       |> Map.put(:media_mode, SetupPreferences.media_mode(preferences))
       |> Map.put(:device_preferences, preferences.device_preferences)
     end)}
  end

  def handle_event("p2p_setup_preferences_loaded", _payload, socket), do: {:halt, socket}

  def handle_event("p2p_toggle_call_mini", _params, %{assigns: %{p2p_session: %{}}} = socket) do
    p2p = socket.assigns.p2p_session
    mini = not Map.get(p2p, :call_mini, false)

    {:halt,
     socket
     |> SessionStatus.put_p2p(Map.put(p2p, :call_mini, mini))
     |> Console.push_call_geometry(mini)}
  end

  def handle_event("p2p_toggle_call_mini", _params, socket), do: {:halt, socket}

  def handle_event("p2p_confirm_end", _params, socket) do
    close_dialog()

    case socket.assigns.p2p_session do
      %{} = p2p ->
        SessionLink.persist_p2p_system(
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

  # ── PubSub events (`Topics.lobby/1`) ──────────────────────────

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
      %{token: ^token} = p2p -> SessionEvents.handle(msg, socket, p2p)
      _other_session -> {:halt, socket}
    end
  end

  # User-topic lobby events without a token envelope (lobby_session_ended).
  def handle_info(%{event: "lobby_" <> _rest}, socket), do: {:halt, socket}

  # Somebody started or stopped watching this session's match: the players are
  # told how many are there.
  def handle_info(%{event: "presence_diff", topic: "lobby:" <> _rest = topic}, socket) do
    case socket.assigns.p2p_session do
      %{token: token} when is_binary(token) ->
        if topic == Topics.lobby_watchers(token), do: SessionLink.send_watchers(token)
        {:halt, socket}

      _no_session ->
        {:halt, socket}
    end
  end

  # Another page of this same person asked for this seat and got it. The anchor
  # stops being rendered, so the hook is destroyed and this browser's peer
  # connection goes down with it — which is the honest outcome: one person is
  # one participant, and the media belongs to the page they are looking at.
  def handle_info({:lobby_slot_taken, token}, socket) do
    case socket.assigns.p2p_session do
      %{token: ^token} = p2p ->
        # The page that took the seat is the one listening now. Reclaiming
        # subscribes again, so leaving this subscription in place would make a
        # page that lost and retook its seat hear every event twice.
        SessionLink.unsubscribe_session(token)

        {:halt,
         socket
         |> SessionStatus.put_p2p(%{
           p2p
           | displaced: true,
             webrtc_started: false,
             hook_ready: false
         })
         |> Surface.system(dgettext("chat", "This P2P session moved to another window of yours."))}

      _other_session ->
        {:halt, socket}
    end
  end

  def handle_info({:p2p_console_section, section}, socket) do
    {:halt, Console.open(socket, section)}
  end

  # C2 read-model bubbles from the feature islands (taskbar badges + the
  # Statistics strip read them from the host state).
  def handle_info({:feature_summary, feature, summary}, socket)
      when feature in [:file, :call, :game] do
    case socket.assigns.p2p_session do
      nil ->
        {:halt, socket}

      p2p ->
        {:halt, SessionStatus.put_p2p(socket, Map.put(p2p, summary_key(feature), summary))}
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
          do:
            SessionLink.persist_p2p_system(
              socket,
              p2p.peer_nick,
              SessionStatus.p2p_notice_text(text)
            )

        {:halt, socket}

      {:local, _p2p} ->
        {:halt, SessionStatus.p2p_system_event(socket, text)}
    end
  end

  # A notice that stopped being true leaves the status bar — only that one, so
  # a newer line said since is left alone.
  def handle_info({:p2p_clear_notice, text}, socket) do
    case socket.assigns[:notice] do
      %{message: ^text} -> {:halt, assign(socket, notice: nil)}
      _other -> {:halt, socket}
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

  # A match leaves its room straight into its game; a plain session leaves it
  # into the call, which is what it is.
  defp started_section(%{match_game_id: game_id}) when is_binary(game_id), do: "games"
  defp started_section(_p2p), do: "call"

  # Cancel a pending invite outright; anything past that needs the confirm.
  defp request_stop(socket) do
    case socket.assigns.p2p_session do
      %{state: :invite_sent} = p2p ->
        SessionLink.persist_p2p_system(
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

  defp start_call_payload(p2p, type) do
    %{
      "type" => type,
      "device_preferences" => Map.get(p2p, :device_preferences, MediaDevices.no_preference())
    }
  end

  defp normalize_devices(devices), do: MediaDevices.normalize(devices, unnamed_device())

  defp unnamed_device, do: dgettext("chat", "Default device")

  defp short_string_param(map, key, max_bytes) do
    case Params.value(map, key) do
      value when is_binary(value) -> String.slice(value, 0, max_bytes)
      _ -> nil
    end
  end

  defp integer_param(map, key), do: Params.integer(Params.value(map, key))

  defp close_dialog do
    Phoenix.LiveView.send_update(P2PConfirmDialog,
      id: P2PConfirmDialog.id(),
      action: :close
    )
  end
end
