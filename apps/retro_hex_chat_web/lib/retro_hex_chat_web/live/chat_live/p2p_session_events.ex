defmodule RetroHexChatWeb.ChatLive.P2PSessionEvents do
  @moduledoc """
  Host-side state machine and event adapters for the in-chat P2P session.

  The chat holds at most ONE P2P session, in the `@p2p_session` assign:

      nil → :invite_sent → :joining → :connecting → :connected → nil

  Every P2P surface (status-bar area, invite-card buttons, confirm dialogs,
  the WebRTC hook anchor) derives from this single assign. WebRTC wiring:
  hooks push events to this root LiveView, the
  domain relays signals through `"lobby:\#{token}"`, and signaling only starts
  after BOTH hooks report ready (never re-order this — the first offer is
  dropped if the answerer's hook isn't listening yet).

  Switching sessions (accepting an invite while one is active) validates the
  NEW session is still joinable before ending the current one, then tears
  down and joins — the hook anchor is keyed by token, so the swap remounts
  the WebRTC hook with a fresh RTCPeerConnection.
  """

  import Phoenix.Component, only: [assign: 2, update: 3]
  import Phoenix.LiveView, only: [push_event: 3]

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias Phoenix.LiveView.Socket
  alias RetroHexChat.Chat.Schemas.UserPreference
  alias RetroHexChat.Chat.Service, as: ChatService
  alias RetroHexChat.Lobby
  alias RetroHexChat.Lobby.Schema.Session, as: LobbySession
  alias RetroHexChat.P2P
  alias RetroHexChat.P2P.SignalingRateLimit
  alias RetroHexChatWeb.App.P2PStats
  alias RetroHexChatWeb.App.SessionHelpers
  alias RetroHexChatWeb.ChatLive.Components.P2PConfirmDialog
  alias RetroHexChatWeb.ChatLive.Components.P2PFileIsland
  alias RetroHexChatWeb.ChatLive.Components.P2PGameIsland
  alias RetroHexChatWeb.ChatLive.Components.P2PMediaIsland
  alias RetroHexChatWeb.ChatLive.Helpers.LobbyInvite
  alias RetroHexChatWeb.ChatLive.Helpers.Messages
  alias RetroHexChatWeb.ChatLive.Helpers.PM, as: PMHelper
  alias RetroHexChatWeb.ChatLive.Windows

  @pubsub RetroHexChat.PubSub
  @p2p_console_width 760
  @p2p_console_height 520
  @p2p_console_x 360
  @p2p_console_y 48

  # ── Client events (WebRTC hooks + P2P UI) ─────────────────────

  @spec handle_event(String.t(), map(), Socket.t()) :: {:cont | :halt, Socket.t()}
  def handle_event("lobby_webrtc_ready", _params, %{assigns: %{p2p_session: %{}}} = socket) do
    p2p = socket.assigns.p2p_session
    Lobby.mark_webrtc_ready(p2p.token, p2p.user_id)
    {:halt, socket}
  end

  def handle_event("lobby_signal", params, %{assigns: %{p2p_session: %{}}} = socket) do
    p2p = socket.assigns.p2p_session
    rate_limiter = SignalingRateLimit.configured_module()

    with :ok <- rate_limiter.check_signal_rate(p2p.token, p2p.user_id),
         {:ok, validated} <- P2P.validate_signal(params) do
      broadcast(p2p.token, "lobby_signal", Map.put(validated, :from, p2p.user_id))
    end

    {:halt, socket}
  end

  def handle_event("lobby_connected", _params, %{assigns: %{p2p_session: %{}}} = socket) do
    p2p = socket.assigns.p2p_session
    _ = Lobby.transition_status(p2p.token, :connected)
    {:halt, enter_connected(socket, p2p)}
  end

  # The answerer asks the initiator to re-offer after adding local media
  # tracks (single-offerer model — only the initiator emits offers).
  def handle_event("lobby_renegotiate", params, %{assigns: %{p2p_session: %{}}} = socket) do
    p2p = socket.assigns.p2p_session

    broadcast(p2p.token, "lobby_renegotiate", %{
      from: p2p.user_id,
      kinds: Map.get(params, "kinds", []),
      recover: Map.get(params, "recover", false)
    })

    {:halt, socket}
  end

  def handle_event(
        "lobby_state_change",
        %{"state" => "disconnected"},
        %{assigns: %{p2p_session: %{}}} = socket
      ) do
    {:halt, mark_p2p_reconnecting(socket, nil, "disconnected")}
  end

  def handle_event("lobby_state_change", _params, %{assigns: %{p2p_session: %{}}} = socket) do
    {:halt, socket}
  end

  def handle_event("lobby_failed", params, %{assigns: %{p2p_session: %{}}} = socket) do
    reason = params["reason"] || params[:reason] || "failed"

    {:halt,
     socket
     |> mark_p2p_failed(reason)
     |> open_p2p_console("call")
     |> Messages.system_event(dgettext("chat", "P2P connection failed."))}
  end

  def handle_event("lobby_retry", params, %{assigns: %{p2p_session: %{}}} = socket) do
    attempt = integer_param(params, "attempt")
    {:halt, mark_p2p_reconnecting(socket, attempt, "auto_retry")}
  end

  def handle_event("p2p_retry_connection", _params, %{assigns: %{p2p_session: %{}}} = socket) do
    p2p = socket.assigns.p2p_session

    broadcast(p2p.token, "lobby_manual_retry", %{from: p2p.user_id})

    {:halt,
     socket
     |> mark_p2p_reconnecting(nil, "manual_retry")
     |> push_event("lobby_restart", %{})}
  end

  def handle_event("lobby_media_restart", params, %{assigns: %{p2p_session: %{}}} = socket) do
    p2p = socket.assigns.p2p_session
    reason = params["reason"] || params[:reason] || "media_restart"

    broadcast(p2p.token, "lobby_media_restart", %{from: p2p.user_id, reason: reason})

    {:halt,
     socket
     |> mark_p2p_reconnecting(nil, reason)
     |> push_event("lobby_restart", %{})}
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
        %{assigns: %{p2p_session: %{state: state}}} = socket
      )
      when state != :invite_sent do
    {:halt, open_p2p_console(socket, section)}
  end

  def handle_event("p2p_console_select", _params, socket), do: {:halt, socket}

  # Privacy mode: force every P2P connection through the TURN relay (hides
  # the direct peer IP). Persisted per user; applies from the next
  # (re)signaling round.
  def handle_event("p2p_toggle_privacy", _params, %{assigns: %{p2p_session: %{}}} = socket) do
    p2p = socket.assigns.p2p_session
    new_value = not p2p.turn_only
    save_turn_only(socket.assigns.session.nickname, new_value)

    label =
      if new_value,
        do: dgettext("chat", "Privacy mode enabled — the P2P connection will use the relay."),
        else: dgettext("chat", "Privacy mode disabled.")

    {:halt,
     socket
     |> put_p2p(%{p2p | turn_only: new_value})
     |> Messages.system_event(label)}
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
     Messages.system_event(
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

  def handle_event("p2p_accept_invite", %{"token" => token}, socket) do
    {:halt, request_accept(socket, token)}
  end

  def handle_event("p2p_setup_accept", %{"p2p_setup" => params}, socket) do
    {:halt, accept_setup(socket, params)}
  end

  def handle_event("p2p_setup_cancel", _params, socket) do
    {:halt, assign(socket, p2p_setup: nil)}
  end

  def handle_event("p2p_setup_devices_listed", payload, %{assigns: %{p2p_setup: %{}}} = socket) do
    {:halt,
     update(socket, :p2p_setup, fn setup ->
       Map.put(setup, :devices, normalize_devices(payload))
     end)}
  end

  def handle_event("p2p_setup_devices_listed", _payload, socket), do: {:halt, socket}

  def handle_event(
        "p2p_setup_preferences_loaded",
        payload,
        %{assigns: %{p2p_setup: %{}}} = socket
      ) do
    preferences = normalize_p2p_setup_preferences(payload)

    {:halt,
     update(socket, :p2p_setup, fn setup ->
       setup
       |> Map.put(:media, preferences.media)
       |> Map.put(:media_mode, media_mode_from_preferences(preferences))
       |> Map.put(:device_preferences, preferences.device_preferences)
     end)}
  end

  def handle_event("p2p_setup_preferences_loaded", _payload, socket), do: {:halt, socket}

  def handle_event("p2p_decline_invite", %{"token" => token}, socket) do
    {:halt, decline_invite(socket, token)}
  end

  # The P2P menu without a session: teach the entry points and drop the
  # inline help card for the full walkthrough.
  def handle_event("p2p_how_to_start", _params, socket) do
    socket =
      socket
      |> Messages.system_event(
        dgettext(
          "chat",
          "Start a P2P session with /p2p <nick>, or right-click a user in the nicklist."
        )
      )
      |> Messages.inline_help_event(
        "feature-p2p-in-chat",
        dgettext("chat", "P2P Sessions in Chat")
      )

    {:halt, socket}
  end

  def handle_event("p2p_statusbar_click", _params, socket) do
    case socket.assigns.p2p_session do
      nil ->
        {:halt, socket}

      _p2p ->
        {:halt, open_p2p_console(socket, "call")}
    end
  end

  def handle_event("p2p_statusbar_stop", _params, socket) do
    request_stop(socket)
  end

  def handle_event("p2p_toggle_call_mini", _params, %{assigns: %{p2p_session: %{}}} = socket) do
    p2p = socket.assigns.p2p_session
    mini = not Map.get(p2p, :call_mini, false)

    {:halt,
     socket
     |> put_p2p(Map.put(p2p, :call_mini, mini))
     |> Windows.open("p2p-call")
     |> push_p2p_call_geometry(mini)}
  end

  def handle_event("p2p_toggle_call_mini", _params, socket), do: {:halt, socket}

  # The X on ANY session window means disconnecting the whole session, never
  # a silent hide — users were closing the camera and not realizing the
  # connection stayed up. Every close path (X, taskbar menu, Escape) routes
  # here via on_close; the window only goes away if the disconnect is
  # confirmed. Minimize remains the "keep it running" gesture.
  def handle_event("p2p_window_close", _params, socket) do
    case socket.assigns.p2p_session do
      %{} = p2p ->
        Phoenix.LiveView.send_update(P2PConfirmDialog,
          id: P2PConfirmDialog.id(),
          action: {:open_close, p2p.peer_nick}
        )

        {:halt, socket}

      nil ->
        {:halt, socket}
    end
  end

  def handle_event("p2p_confirm_end", _params, socket) do
    close_dialog()

    case socket.assigns.p2p_session do
      %{} = p2p ->
        persist_p2p_system(
          socket,
          p2p.peer_nick,
          dgettext("chat", "%{nick} ended the P2P session.",
            nick: socket.assigns.session.nickname
          )
        )

        _ = Lobby.close_session(p2p.token, p2p.user_id, "user_closed")
        {:halt, socket}

      nil ->
        {:halt, socket}
    end
  end

  def handle_event("p2p_confirm_switch", _params, socket) do
    close_dialog()
    {:halt, confirm_switch(socket)}
  end

  def handle_event("p2p_confirm_cancel", _params, socket) do
    close_dialog()

    # Backing out clears the staged switch. New outgoing sessions are only
    # created after setup submit; the token branch is defensive for callers
    # that may stage an already-created invite.
    case socket.assigns.p2p_pending do
      %{kind: :outgoing, payload: %{token: token, creator_id: creator_id}} ->
        _ = Lobby.cancel_invite(token, creator_id)
        :ok

      _ ->
        :ok
    end

    {:halt, assign(socket, p2p_pending: nil)}
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}

  # ── PubSub events (topic "lobby:#{token}") ────────────────────

  # Session-topic envelopes carry the token: events from a session that is no
  # longer the current one (a switch already unsubscribed, but its last
  # messages were enqueued first) are dropped instead of tearing down the
  # NEW session — the exact stale-close race of the A→B switch protocol.
  @spec handle_info(term(), Socket.t()) :: {:cont | :halt, Socket.t()}
  def handle_info(%{event: "lobby_" <> _rest, token: token} = msg, socket) do
    case socket.assigns.p2p_session do
      %{token: ^token} = p2p -> handle_session_event(msg, socket, p2p)
      _ -> {:halt, socket}
    end
  end

  # User-topic lobby events without a token envelope (lobby_session_ended);
  # PubsubHandlers consumed lobby_invite before this hook.
  def handle_info(%{event: "lobby_" <> _rest}, socket), do: {:halt, socket}

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
        if Keyword.get(opts, :writer, false), do: persist_p2p_system(socket, p2p.peer_nick, text)
        {:halt, socket}

      {:local, _p2p} ->
        {:halt, Messages.system_event(socket, text)}
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

      status == "lobby" ->
        # Both joined: the pending invite card loses its accept CTA.
        {:halt, PMHelper.refresh_p2p_invite_card(socket, p2p.peer_nick, p2p.token)}

      true ->
        {:halt, socket}
    end
  end

  defp handle_session_event(%{event: "lobby_start_signaling"}, socket, p2p) do
    {:halt, start_webrtc(socket, p2p)}
  end

  defp handle_session_event(
         %{event: "lobby_signal", payload: %{from: from} = payload},
         socket,
         p2p
       ) do
    if from == p2p.user_id do
      {:halt, socket}
    else
      {:halt, push_event(socket, "lobby_signal", payload)}
    end
  end

  defp handle_session_event(
         %{event: "lobby_renegotiate", payload: %{from: from} = payload},
         socket,
         p2p
       ) do
    if from == p2p.user_id do
      {:halt, socket}
    else
      {:halt,
       push_event(socket, "lobby_renegotiate", %{
         kinds: payload[:kinds] || [],
         recover: payload[:recover] || false
       })}
    end
  end

  defp handle_session_event(
         %{event: "lobby_manual_retry", payload: %{from: from}},
         socket,
         p2p
       ) do
    if from == p2p.user_id do
      {:halt, socket}
    else
      {:halt,
       socket
       |> mark_p2p_reconnecting(nil, "peer_manual_retry")
       |> open_p2p_console("call")
       |> push_event("lobby_restart", %{})}
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
       |> mark_p2p_reconnecting(nil, payload[:reason] || "peer_media_restart")
       |> open_p2p_console("call")
       |> push_event("lobby_restart", %{})}
    end
  end

  # The creator holds :invite_sent WITHOUT having joined — a pending invite
  # is just a card, not a connection. The peer joining is the cue to join
  # from here; :already_joined means another process of this user (an old
  # LiveView finishing a takeover) still holds the slot — detach silently
  # and let it drive.
  defp handle_session_event(%{event: "lobby_peer_joined", payload: %{user_id: uid}}, socket, p2p) do
    cond do
      uid == p2p.user_id ->
        {:halt, socket}

      p2p.state == :invite_sent ->
        case Lobby.join_session(p2p.token, p2p.user_id) do
          :ok ->
            {:halt,
             socket
             |> put_p2p(%{p2p | state: :joining, peer_online: true})
             |> share_client_info(p2p)
             |> Messages.system_event(
               dgettext(
                 "chat",
                 "%{peer} accepted the invite - connecting... the P2P session will open shortly.",
                 peer: p2p.peer_nick || dgettext("chat", "The other user")
               )
             )}

          {:error, :already_joined} ->
            {:halt, detach_session(socket, p2p)}

          {:error, message} ->
            {:halt, socket |> detach_session(p2p) |> Messages.system_event(message)}
        end

      true ->
        # Re-share our whois so a peer that joined after us still receives it.
        {:halt, socket |> put_p2p(%{p2p | peer_online: true}) |> share_client_info(p2p)}
    end
  end

  defp handle_session_event(
         %{event: "lobby_peer_disconnected", payload: %{user_id: uid}},
         socket,
         p2p
       ) do
    if uid == p2p.user_id do
      {:halt, socket}
    else
      {:halt,
       socket
       |> put_p2p(%{p2p | peer_online: false})
       |> Messages.system_event(
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
        device_preferences: Map.get(p2p, :device_preferences, default_device_preferences()),
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

    {:halt, Messages.system_event(socket, dgettext("chat", "Game request declined."))}
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
     Messages.system_event(
       socket,
       dgettext("chat", "The P2P session will expire soon due to inactivity.")
     )}
  end

  # Session-topic events the in-chat host doesn't render directly. Feature
  # windows consume their own relays through their islands/hooks.
  defp handle_session_event(_msg, socket, _p2p), do: {:halt, socket}

  # ── Session lifecycle (called from mount / invite helper) ─────

  @doc """
  Re-attaches the user's live P2P session after a mount without a token
  (reconnect, chat takeover). Peers who never accepted a pending invite are
  NOT joined — for them the invite is still just a card; a pending invite's
  creator re-attaches in the subscribe-only :invite_sent mode.
  """
  @spec rehydrate(Socket.t()) :: Socket.t()
  def rehydrate(socket) do
    nickname = socket.assigns.session.nickname

    with user_id when is_integer(user_id) <- resolve_user_id(nickname),
         %LobbySession{} = db_session <- Lobby.active_session_for_user(user_id) do
      role = if db_session.creator_id == user_id, do: :creator, else: :peer

      case {db_session.status, role} do
        {"pending", :peer} -> socket
        {"pending", :creator} -> subscribe_invite_sent(socket, db_session.token, user_id)
        _ -> attach_session(socket, db_session.token, user_id, role)
      end
    else
      _ -> socket
    end
  end

  @doc """
  Tracks the freshly created invite as its creator — subscribe-only, no
  join: a pending invite is just a card, so the creator only joins once the
  peer does (see lobby_peer_joined).
  """
  @spec start_as_creator(Socket.t(), String.t(), integer()) :: Socket.t()
  def start_as_creator(socket, token, creator_id) do
    subscribe_invite_sent(socket, token, creator_id)
  end

  @doc """
  Opens the same P2P setup used by incoming invites before an outgoing invite is
  delivered. The lobby row and invite PM are created only after setup submit.
  """
  @spec open_outgoing_setup(Socket.t(), map()) :: Socket.t()
  def open_outgoing_setup(socket, payload) do
    assign(socket,
      p2p_setup:
        socket
        |> setup_base(payload.target)
        |> Map.merge(%{
          kind: :outgoing,
          payload: payload
        })
    )
  end

  defp subscribe_invite_sent(socket, token, user_id) do
    Phoenix.PubSub.subscribe(@pubsub, "lobby:#{token}")
    put_p2p(socket, new_session(socket, token, user_id, :creator, :invite_sent))
  end

  defp new_session(socket, token, user_id, role, state) do
    %{
      token: token,
      user_id: user_id,
      role: role,
      peer_nick: peer_nick_for(token, user_id),
      state: state,
      webrtc_started: false,
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
      media_mode: "video",
      call_mini: false,
      device_preferences: default_device_preferences(),
      turn_only: load_turn_only(socket.assigns.session.nickname),
      turn_configured: P2P.turn_configured?()
    }
  end

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
          dgettext("chat", "%{nick} cancelled the P2P invite.",
            nick: socket.assigns.session.nickname
          )
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

  @doc """
  Accepts an invite from a PM card. With a session already active this stashes
  the target and opens the switch confirm instead (E1 in the plan).
  """
  @spec request_accept(Socket.t(), String.t()) :: Socket.t()
  def request_accept(socket, token) do
    case socket.assigns.p2p_session do
      nil ->
        open_setup(socket, token)

      p2p ->
        case joinable_summary(token) do
          {:ok, summary} ->
            Phoenix.LiveView.send_update(P2PConfirmDialog,
              id: P2PConfirmDialog.id(),
              action: {:open_switch, p2p.peer_nick, summary.created_by}
            )

            assign(socket, p2p_pending: %{kind: :incoming, token: token})

          {:error, message} ->
            Messages.system_event(socket, message)
        end
    end
  end

  # ── Private ───────────────────────────────────────────────────

  # E1/E2 switch protocol: validate the NEW session is still joinable BEFORE
  # ending the current one, so a stale confirm can't cost the user both.
  defp confirm_switch(socket) do
    pending = socket.assigns.p2p_pending
    socket = assign(socket, p2p_pending: nil)

    case pending do
      %{kind: :incoming, token: token} ->
        case joinable_summary(token) do
          {:ok, _summary} ->
            socket
            |> end_current_session()
            |> open_setup(token)

          {:error, message} ->
            Messages.system_event(socket, message)
        end

      %{kind: :outgoing, payload: payload} ->
        socket
        |> end_current_session()
        |> open_outgoing_setup(payload)

      _ ->
        socket
    end
  end

  defp end_current_session(socket) do
    case socket.assigns.p2p_session do
      nil ->
        socket

      p2p ->
        persist_p2p_system(
          socket,
          p2p.peer_nick,
          dgettext("chat", "%{nick} ended the P2P session.",
            nick: socket.assigns.session.nickname
          )
        )

        _ = Lobby.close_session(p2p.token, p2p.user_id, "user_closed")
        detach_session(socket, p2p)
    end
  end

  defp open_setup(socket, token) do
    case joinable_summary(token) do
      {:ok, summary} ->
        assign(socket,
          p2p_setup:
            socket
            |> setup_base(summary.created_by)
            |> Map.merge(%{
              kind: :incoming,
              token: token,
              created_by: summary.created_by
            })
        )

      {:error, message} ->
        Messages.system_event(socket, message)
    end
  end

  defp accept_setup(socket, params) do
    case socket.assigns[:p2p_setup] do
      %{kind: :outgoing, payload: payload, turn_configured: turn_configured?} ->
        setup_opts = setup_options_from_params(socket, params, turn_configured?)

        socket
        |> assign(p2p_setup: nil)
        |> deliver_outgoing_setup(payload, setup_opts)

      %{token: token, turn_configured: turn_configured?} ->
        setup_opts = setup_options_from_params(socket, params, turn_configured?)

        socket
        |> assign(p2p_setup: nil)
        |> do_accept(token, setup_opts)

      _ ->
        assign(socket, p2p_setup: nil)
    end
  end

  defp setup_base(socket, peer_nick) do
    %{
      peer_nick: peer_nick,
      media_mode: "video",
      media: %{audio: true, video: true},
      user_id: resolve_user_id(socket.assigns.session.nickname),
      devices: default_devices(),
      device_preferences: default_device_preferences(),
      turn_only: load_turn_only(socket.assigns.session.nickname),
      turn_configured: P2P.turn_configured?()
    }
  end

  defp setup_options_from_params(socket, params, turn_configured?) do
    preferences = normalize_p2p_setup_preferences(params)

    media_mode =
      normalize_media_mode(params["media_mode"] || media_mode_from_preferences(preferences))

    turn_only = turn_configured? and truthy?(params["turn_only"])

    if turn_configured? do
      save_turn_only(socket.assigns.session.nickname, turn_only)
    end

    %{
      media_mode: media_mode,
      turn_only: turn_only,
      device_preferences: preferences.device_preferences
    }
  end

  defp deliver_outgoing_setup(socket, payload, setup_opts) do
    socket
    |> LobbyInvite.deliver_invite(socket.assigns.session, payload)
    |> apply_setup_options(setup_opts)
  end

  defp do_accept(socket, token, setup_opts) do
    nickname = socket.assigns.session.nickname

    with user_id when is_integer(user_id) <- resolve_user_id(nickname),
         {:ok, _summary} <- joinable_summary(token) do
      socket
      |> attach_session(token, user_id, :peer)
      |> apply_setup_options(setup_opts)
      |> notify_invite_accepted()
    else
      {:error, message} -> Messages.system_event(socket, message)
      _ -> socket
    end
  end

  defp apply_setup_options(%{assigns: %{p2p_session: p2p}} = socket, setup_opts)
       when not is_nil(p2p) do
    update(socket, :p2p_session, fn p2p ->
      %{
        p2p
        | media_mode: setup_opts[:media_mode] || "video",
          device_preferences: setup_opts[:device_preferences] || default_device_preferences(),
          turn_only: setup_opts[:turn_only] == true
      }
    end)
  end

  defp apply_setup_options(socket, _setup_opts), do: socket

  defp notify_invite_accepted(%{assigns: %{p2p_session: p2p}} = socket) when not is_nil(p2p) do
    Messages.system_event(
      socket,
      dgettext(
        "chat",
        "Invite accepted - connecting... the P2P session will open shortly."
      )
    )
  end

  defp notify_invite_accepted(socket), do: socket

  defp decline_invite(socket, token) do
    nickname = socket.assigns.session.nickname
    creator = creator_nick(token)

    case resolve_user_id(nickname) do
      user_id when is_integer(user_id) ->
        case Lobby.decline_session(token, user_id) do
          :ok ->
            persist_p2p_system(
              socket,
              creator,
              dgettext("chat", "%{nick} declined the P2P invite.", nick: nickname)
            )

            PMHelper.refresh_p2p_invite_card(socket, creator, token)

          {:error, message} ->
            Messages.system_event(socket, message)
        end

      _ ->
        socket
    end
  end

  defp creator_nick(token) do
    case Lobby.session_summary(token) do
      {:ok, %{created_by: created_by}} -> created_by
      _ -> nil
    end
  end

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
  defp enter_connected(socket, %{state: :connected} = p2p) do
    put_p2p(socket, %{p2p | recovery: empty_p2p_recovery()})
  end

  defp enter_connected(socket, p2p) do
    socket
    |> maybe_persist_connected(p2p)
    |> put_p2p(%{p2p | state: :connected, recovery: empty_p2p_recovery()})
    |> burst_windows()
  end

  # The session presents itself the moment the link comes up, on both sides:
  # the unified P2P console opens in front. Call, Files, Games and Statistics
  # live inside that surface so mobile and desktop share one mental model.
  defp burst_windows(socket) do
    open_p2p_console(socket, "call")
  end

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
        |> Windows.open("p2p-call")
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

  defp push_p2p_call_geometry(socket, true) do
    push_event(socket, "window_command", %{
      action: "set_geometry",
      id: "p2p-call",
      width: 300,
      height: 236,
      anchor: "bottom_right",
      margin: 16
    })
  end

  defp push_p2p_call_geometry(socket, false) do
    push_event(socket, "window_command", %{
      action: "set_geometry",
      id: "p2p-call",
      width: @p2p_console_width,
      height: @p2p_console_height,
      x: @p2p_console_x,
      y: @p2p_console_y
    })
  end

  defp attach_session(socket, token, user_id, role) do
    case Lobby.join_session(token, user_id) do
      :ok ->
        Phoenix.PubSub.subscribe(@pubsub, "lobby:#{token}")
        p2p = new_session(socket, token, user_id, role, :joining)

        socket
        |> put_p2p(p2p)
        |> share_client_info(p2p)

      {:error, :already_joined} ->
        Messages.system_event(
          socket,
          dgettext("chat", "This P2P session is already active in another window.")
        )

      {:error, message} ->
        Messages.system_event(socket, message)
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
      socket |> detach_session(p2p) |> PMHelper.refresh_p2p_invite_card(p2p.peer_nick, p2p.token)

    if reason in @persisted_by_actor do
      socket
    else
      Messages.system_event(socket, ended_message(p2p.peer_nick, reason))
    end
  end

  # ICE config + the role-specific start event, exactly once per
  # (re)signaling round.
  defp start_webrtc(socket, %{webrtc_started: true} = _p2p), do: socket

  defp start_webrtc(socket, p2p) do
    ice_servers = P2P.ice_servers(to_string(p2p.user_id))

    event =
      case p2p.role do
        :creator -> "lobby_start_offer"
        :peer -> "lobby_start_answer"
      end

    socket
    |> put_p2p(%{p2p | state: :connecting, webrtc_started: true})
    |> push_event(event, %{
      ice_servers: ice_servers,
      role: to_string(p2p.role),
      turn_only: p2p.turn_only && p2p.turn_configured
    })
  end

  defp put_p2p(socket, p2p), do: assign(socket, p2p_session: p2p)

  defp mark_p2p_reconnecting(socket, attempt, reason) do
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
              manual_retry: false
            },
            stats: P2PStats.empty()
        }
    end)
  end

  defp mark_p2p_failed(socket, reason) do
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
              manual_retry: true
            },
            stats: P2PStats.empty()
        }
    end)
  end

  defp empty_p2p_recovery do
    %{state: :idle, attempt: nil, reason: nil, manual_retry: false}
  end

  defp joinable_summary(token) do
    case Lobby.session_summary(token) do
      {:ok, %{terminal?: false} = summary} ->
        {:ok, summary}

      {:ok, %{terminal?: true}} ->
        {:error, dgettext("chat", "This P2P invite is no longer active.")}

      {:error, :not_found} ->
        {:error, dgettext("chat", "This P2P invite is no longer active.")}
    end
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

  defp resolve_user_id(nickname) do
    case SessionHelpers.resolve_user_id(nickname) do
      {:ok, user_id} -> user_id
      _ -> nil
    end
  end

  defp start_call_payload(p2p, type) do
    %{
      "type" => type,
      "device_preferences" => Map.get(p2p, :device_preferences, default_device_preferences())
    }
  end

  defp normalize_media_mode(mode) when mode in ~w(video audio receive), do: mode
  defp normalize_media_mode(_mode), do: "video"

  defp normalize_p2p_setup_preferences(preferences) when is_map(preferences) do
    audio = truthy?(value(preferences, :audio))
    video = truthy?(value(preferences, :video))

    %{
      media: %{audio: audio, video: video},
      device_preferences: %{
        audio_input_id: clean_device_id(value(preferences, :audio_input_id)),
        video_input_id: clean_device_id(value(preferences, :video_input_id)),
        audio_output_id: clean_device_id(value(preferences, :audio_output_id))
      }
    }
  end

  defp normalize_p2p_setup_preferences(_preferences) do
    %{media: %{audio: true, video: true}, device_preferences: default_device_preferences()}
  end

  defp media_mode_from_preferences(%{media: %{audio: true, video: true}}), do: "video"
  defp media_mode_from_preferences(%{media: %{audio: true, video: false}}), do: "audio"
  defp media_mode_from_preferences(_preferences), do: "receive"

  defp default_device_preferences do
    %{audio_input_id: nil, video_input_id: nil, audio_output_id: nil}
  end

  defp default_devices do
    %{"audioinput" => [], "videoinput" => [], "audiooutput" => []}
  end

  defp normalize_devices(devices) when is_map(devices) do
    %{
      "audioinput" => normalize_device_list(value(devices, :audioinput)),
      "videoinput" => normalize_device_list(value(devices, :videoinput)),
      "audiooutput" => normalize_device_list(value(devices, :audiooutput))
    }
  end

  defp normalize_devices(_devices), do: default_devices()

  defp normalize_device_list(devices) when is_list(devices) do
    Enum.map(devices, fn device ->
      %{
        "id" => to_string(value(device, :id) || value(device, :deviceId) || ""),
        "label" => to_string(value(device, :label) || dgettext("chat", "Default device"))
      }
    end)
  end

  defp normalize_device_list(_devices), do: []

  defp clean_device_id(nil), do: nil
  defp clean_device_id(""), do: nil
  defp clean_device_id(device_id) when is_binary(device_id), do: device_id
  defp clean_device_id(device_id), do: to_string(device_id)

  defp value(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, to_string(key))
  end

  defp value(_map, _key), do: nil

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

  defp load_turn_only(nickname) do
    case RetroHexChat.Repo.get(UserPreference, nickname) do
      nil -> false
      pref -> get_in(pref.display_settings, ["p2p_settings", "turn_only"]) == true
    end
  end

  defp save_turn_only(nickname, turn_only) do
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
        socket.assigns.session.nickname,
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
