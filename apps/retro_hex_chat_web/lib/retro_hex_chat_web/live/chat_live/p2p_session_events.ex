defmodule RetroHexChatWeb.ChatLive.P2PSessionEvents do
  @moduledoc """
  Host-side state machine and event adapters for the in-chat P2P session.

  The chat holds at most ONE P2P session, in the `@p2p_session` assign:

      nil → :invite_sent → :joining → :connecting → :connected → nil

  Every P2P surface (status-bar area, invite-card buttons, confirm dialogs,
  the WebRTC hook anchor) derives from this single assign. The WebRTC wiring
  mirrors the standalone lobby: hooks push events to this root LiveView, the
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
  alias RetroHexChatWeb.App.LobbyLive.Components.FileIsland
  alias RetroHexChatWeb.App.LobbyLive.Components.GameIsland
  alias RetroHexChatWeb.App.LobbyLive.Components.MediaIsland
  alias RetroHexChatWeb.App.P2PStats
  alias RetroHexChatWeb.App.SessionHelpers
  alias RetroHexChatWeb.ChatLive.Components.P2PConfirmDialog
  alias RetroHexChatWeb.ChatLive.Helpers.LobbyInvite
  alias RetroHexChatWeb.ChatLive.Helpers.Messages
  alias RetroHexChatWeb.ChatLive.Helpers.PM, as: PMHelper
  alias RetroHexChatWeb.ChatLive.Windows

  @pubsub RetroHexChat.PubSub

  # The P2P desktop windows, in status-bar focus order.
  @p2p_windows ~w(p2p-stats p2p-files p2p-call p2p-games)

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

    {:halt,
     socket
     |> maybe_persist_connected(p2p)
     |> put_p2p(%{p2p | state: :connected})}
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

  def handle_event("lobby_state_change", _params, %{assigns: %{p2p_session: %{}}} = socket) do
    {:halt, socket}
  end

  def handle_event("lobby_failed", _params, %{assigns: %{p2p_session: %{}}} = socket) do
    {:halt, Messages.system_event(socket, dgettext("chat", "P2P connection failed."))}
  end

  def handle_event("lobby_retry", _params, %{assigns: %{p2p_session: %{}}} = socket) do
    {:halt, socket}
  end

  def handle_event("lobby_stats", payload, %{assigns: %{p2p_session: %{}}} = socket) do
    p2p = socket.assigns.p2p_session
    {:halt, put_p2p(socket, %{p2p | stats: P2PStats.normalize(payload)})}
  end

  def handle_event("toggle_network_info", _params, %{assigns: %{p2p_session: %{}}} = socket) do
    p2p = socket.assigns.p2p_session
    {:halt, put_p2p(socket, %{p2p | info_open: not p2p.info_open})}
  end

  def handle_event("p2p_open_stats", _params, %{assigns: %{p2p_session: %{}}} = socket) do
    {:halt, Windows.open(socket, "p2p-stats")}
  end

  def handle_event("p2p_open_files", _params, %{assigns: %{p2p_session: %{}}} = socket) do
    {:halt, Windows.open(socket, "p2p-files")}
  end

  def handle_event("p2p_open_games", _params, %{assigns: %{p2p_session: %{}}} = socket) do
    {:halt, Windows.open(socket, "p2p-games")}
  end

  def handle_event("p2p_start_audio", _params, %{assigns: %{p2p_session: %{}}} = socket) do
    forward_media(socket, "start_call", %{"type" => "audio"})
  end

  def handle_event("p2p_start_video", _params, %{assigns: %{p2p_session: %{}}} = socket) do
    forward_media(socket, "start_call", %{"type" => "video"})
  end

  # Media is self-controlled: the LobbyMediaHook and the Call window's controls
  # push to this root LV; the whole family forwards to the MediaIsland, which
  # owns the call state and drives its window. Ending a call clears the
  # host-held telemetry, mirroring the standalone lobby.
  def handle_event(
        "lobby_media_call_ended" = event,
        params,
        %{assigns: %{p2p_session: %{}}} = socket
      ) do
    {:halt, socket} = forward_media(socket, event, params)
    p2p = socket.assigns.p2p_session
    {:halt, put_p2p(socket, %{p2p | stats: P2PStats.empty()})}
  end

  def handle_event("lobby_media_" <> _ = event, params, %{assigns: %{p2p_session: %{}}} = socket) do
    forward_media(socket, event, params)
  end

  def handle_event(event, params, %{assigns: %{p2p_session: %{}}} = socket)
      when event in ~w(start_call end_call set_call_layout media_select_preset) do
    forward_media(socket, event, params)
  end

  def handle_event("lobby_game_canvas_ready", _params, %{assigns: %{p2p_session: %{}}} = socket) do
    Phoenix.LiveView.send_update(GameIsland, id: GameIsland.id(), action: :canvas_ready)
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

  # The X on the Games window quits/cancels whatever is there — a playing game
  # ends for both peers; an open picker or pending proposal just closes.
  def handle_event("end_game", _params, %{assigns: %{p2p_session: %{}}} = socket) do
    p2p = socket.assigns.p2p_session
    _ = Lobby.end_game(p2p.token, p2p.user_id)

    if "p2p-games" in socket.assigns.open_windows do
      Phoenix.LiveView.send_update(GameIsland, id: GameIsland.id(), action: :end_game)
    end

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
    Phoenix.LiveView.send_update(GameIsland, id: GameIsland.id(), action: :dismiss_result)
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
  # forwarded verbatim to the island, exactly like the standalone lobby.
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

  def handle_event("p2p_decline_invite", %{"token" => token}, socket) do
    {:halt, decline_invite(socket, token)}
  end

  def handle_event("p2p_statusbar_click", _params, socket) do
    case socket.assigns.p2p_session do
      nil ->
        {:halt, socket}

      _p2p ->
        case Enum.filter(@p2p_windows, &(&1 in socket.assigns.open_windows)) do
          [] ->
            {:halt, Windows.open(socket, "p2p-stats")}

          open_ids ->
            {:halt,
             Enum.reduce(open_ids, socket, fn id, acc ->
               push_event(acc, "window_command", %{action: "focus", id: id})
             end)}
        end
    end
  end

  def handle_event("p2p_statusbar_stop", _params, socket) do
    request_stop(socket)
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

    # Backing out of an OUTGOING switch cancels the pending session the /p2p
    # command already created — otherwise it would dangle for 5 minutes.
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
    Phoenix.LiveView.send_update(FileIsland,
      id: FileIsland.id(),
      action: {:ft_event, event, params}
    )

    {:halt, socket}
  end

  defp forward_media(socket, event, params) do
    Phoenix.LiveView.send_update(MediaIsland,
      id: MediaIsland.id(),
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
        {:halt,
         socket
         |> maybe_persist_connected(p2p)
         |> put_p2p(%{p2p | state: :connected})}

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

  # The creator holds :invite_sent WITHOUT having joined (so the standalone
  # page stays free to claim the session while it exists). The peer joining is
  # the cue to join from here; :already_joined means the creator's own
  # standalone tab claimed it — the chat detaches silently and lets that
  # surface drive.
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
             |> share_client_info(p2p)}

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
      Phoenix.LiveView.send_update(MediaIsland,
        id: MediaIsland.id(),
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
      Phoenix.LiveView.send_update(MediaIsland,
        id: MediaIsland.id(),
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
      Phoenix.LiveView.send_update(MediaIsland,
        id: MediaIsland.id(),
        action: {:peer_camera, off}
      )
    end

    {:halt, socket}
  end

  defp handle_session_event(%{event: "lobby_game_request", payload: request}, socket, p2p) do
    outgoing = request.proposer_id == p2p.user_id

    # open_with defers the send_update one message hop: a same-cycle
    # send_update into the freshly mounted managed island never patches.
    {:halt,
     Windows.open_with(socket, "p2p-games", GameIsland,
       id: GameIsland.id(),
       action: {:request, request, outgoing}
     )}
  end

  defp handle_session_event(
         %{event: "lobby_game_response", payload: %{accepted: false}},
         socket,
         _p2p
       ) do
    if "p2p-games" in socket.assigns.open_windows do
      Phoenix.LiveView.send_update(GameIsland, id: GameIsland.id(), action: :request_declined)
    end

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

    {:halt,
     Windows.open_with(socket, "p2p-games", GameIsland,
       id: GameIsland.id(),
       action: {:playing, payload.game_id, is_host}
     )}
  end

  defp handle_session_event(
         %{event: "lobby_game_status_changed", payload: %{status: "idle"}},
         socket,
         _p2p
       ) do
    if "p2p-games" in socket.assigns.open_windows do
      Phoenix.LiveView.send_update(GameIsland, id: GameIsland.id(), action: :idle)
    end

    {:halt, socket}
  end

  defp handle_session_event(
         %{event: "lobby_game_status_changed", payload: %{status: "finished"} = payload},
         socket,
         _p2p
       ) do
    if "p2p-games" in socket.assigns.open_windows do
      Phoenix.LiveView.send_update(GameIsland,
        id: GameIsland.id(),
        action: {:result, payload.result}
      )
    end

    {:halt, socket}
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

  # Session-topic events the in-chat host doesn't render (ephemeral lobby
  # chat, client info, media/game relays until their windows land in F3).
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
  Tracks the freshly created invite as its creator — subscribe-only, no join:
  while the standalone page exists it must stay free to claim the session,
  so the creator only joins once the peer does (see lobby_peer_joined).
  """
  @spec start_as_creator(Socket.t(), String.t(), integer()) :: Socket.t()
  def start_as_creator(socket, token, creator_id) do
    subscribe_invite_sent(socket, token, creator_id)
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
        do_accept(socket, token)

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
            |> do_accept(token)

          {:error, message} ->
            Messages.system_event(socket, message)
        end

      %{kind: :outgoing, payload: payload} ->
        case joinable_summary(payload.token) do
          {:ok, _summary} ->
            socket
            |> end_current_session()
            |> LobbyInvite.deliver_invite(socket.assigns.session, payload)

          {:error, message} ->
            Messages.system_event(socket, message)
        end

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

  defp do_accept(socket, token) do
    nickname = socket.assigns.session.nickname

    with user_id when is_integer(user_id) <- resolve_user_id(nickname),
         {:ok, _summary} <- joinable_summary(token) do
      attach_session(socket, token, user_id, :peer)
    else
      {:error, message} -> Messages.system_event(socket, message)
      _ -> socket
    end
  end

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
      dgettext("chat", "P2P session connected — calls, files and games are available.")
    )

    socket
  end

  defp maybe_persist_connected(socket, _p2p), do: socket

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

    socket
    |> put_p2p(nil)
    |> update(:open_windows, fn open ->
      Enum.reduce(@p2p_windows, open, &MapSet.delete(&2, &1))
    end)
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

  # Mirrors the standalone lobby's maybe_start_webrtc: ICE config + the
  # role-specific start event, exactly once per (re)signaling round.
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

  defp load_turn_only(nickname) do
    case RetroHexChat.Repo.get(UserPreference, nickname) do
      nil -> false
      pref -> get_in(pref.display_settings, ["p2p_settings", "turn_only"]) == true
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
