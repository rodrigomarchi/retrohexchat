defmodule RetroHexChatWeb.P2PLive.SessionEvents do
  @moduledoc """
  What the session process says, as this page hears it on the session's
  PubSub topic: the peer arriving, readying, leaving and coming back, the
  session starting, connecting, restarting and ending, a game proposed and
  decided — each turned into the `p2p_session` assign and what the page shows.
  """

  import Phoenix.LiveView, only: [push_event: 3]

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias Phoenix.LiveView.Socket
  alias RetroHexChat.Accounts.NickLocales
  alias RetroHexChat.Games.Activity
  alias RetroHexChat.Lobby
  alias RetroHexChat.Lobby.Schema.Session, as: LobbySession
  alias RetroHexChatWeb.Live.Surface
  alias RetroHexChatWeb.MediaDevices
  alias RetroHexChatWeb.P2PLive.Components.P2PGameIsland
  alias RetroHexChatWeb.P2PLive.Components.P2PMediaIsland
  alias RetroHexChatWeb.P2PLive.{Console, SessionLink, SessionStatus, WebRTCStart}
  alias RetroHexChatWeb.Params

  defp peer_restart_reason("lobby_manual_retry"), do: "peer_manual_retry"

  defp peer_restart_reason("lobby_media_restart"), do: "peer_media_restart"

  @doc "Applies one message from the session's topic to this page; the caller has checked it is this session's."
  @spec handle(map(), Socket.t(), map()) :: {:halt, Socket.t()}
  def handle(
        %{event: "lobby_status_changed", payload: %{status: status} = payload},
        socket,
        p2p
      ) do
    cond do
      status == "connected" ->
        {:halt, enter_connected(socket, p2p)}

      LobbySession.terminal?(status) ->
        {:halt, SessionLink.finish_session(socket, payload[:reason] || status)}

      true ->
        {:halt, socket}
    end
  end

  # Both hooks have reported ready, which is the room saying so rather than a
  # silent go. The answerer prepares itself the moment it is told — its
  # `lobby_start_answer` only builds the peer connection and waits — because the
  # first offer is dropped if it is not listening yet. What waits is the
  # *offer*, and it waits for the host.
  def handle(
        %{event: "lobby_start_signaling", payload: payload},
        socket,
        p2p
      ) do
    p2p = %{p2p | peer_ready: true}
    socket = SessionStatus.put_p2p(socket, p2p)

    cond do
      # This page is the rebuild the restart is announcing, not a target of it:
      # its connection was built moments ago by its own start, and tearing that
      # down restarts the round that is already in flight — the peer then holds
      # an offer whose answer belongs to a connection that no longer exists.
      # A page that has not started yet is not that page: it still needs the
      # start the branch below gives it.
      Params.truthy?(Params.value(payload, :restart)) and p2p.webrtc_started and
          p2p.webrtc_connection_reset ->
        {:halt, socket}

      Params.truthy?(Params.value(payload, :restart)) ->
        {:halt, WebRTCStart.restart_from_signaling(socket, p2p, Params.value(payload, :reason))}

      p2p.session_started ->
        # A side that rejoined mid-call re-arms the gate; the host says again
        # that the session is running, so the returning room does not sit there
        # waiting for a `[Start]` that was already pressed.
        if p2p.role == :creator, do: Lobby.broadcast(p2p.token, "lobby_session_start", %{})
        {:halt, WebRTCStart.start(socket, p2p)}

      # The answerer builds its peer connection now and waits — it is still in
      # the room, and "connecting" would be a lie about a negotiation nobody
      # has released yet.
      p2p.role == :peer ->
        {:halt, WebRTCStart.start(socket, p2p, :joining)}

      true ->
        {:halt, socket}
    end
  end

  # The host pressed `[Start]`, or is saying again that they already did.
  # Everyone leaves the room together, which is what makes the wait legible
  # from the other side — and what stops a page that reloaded mid-negotiation
  # from being asked to press Ready for a session that is already running.
  def handle(%{event: "lobby_session_start"}, socket, p2p) do
    started = %{p2p | session_started: true, room_ready: true, state: :connecting}

    {:halt,
     socket
     |> SessionStatus.put_p2p(started)
     |> WebRTCStart.start(started)
     |> Console.open("call")}
  end

  # The other side asked to restart the connection (by hand, or because its
  # media failed); our own request comes back to us too and changes nothing.
  def handle(%{event: event, payload: %{from: from} = payload}, socket, p2p)
      when event in ["lobby_manual_retry", "lobby_media_restart"] do
    if from == p2p.user_id do
      {:halt, socket}
    else
      reason = payload[:reason] || peer_restart_reason(event)

      {:halt,
       socket
       |> SessionStatus.mark_p2p_reconnecting(nil, reason, %{trigger: "peer"})
       |> Console.open("call")
       |> push_event("lobby_restart", WebRTCStart.payload(p2p))}
    end
  end

  # The creator holds :invite_sent WITHOUT having joined — a pending invite is
  # just a card, not a connection. The peer joining is the cue to join from
  # here.
  def handle(%{event: "lobby_peer_joined", payload: %{user_id: uid}}, socket, p2p) do
    cond do
      uid == p2p.user_id -> {:halt, socket}
      p2p.state == :invite_sent -> {:halt, seat_taken(socket, p2p)}
      true -> {:halt, peer_rejoined(socket, p2p)}
    end
  end

  def handle(
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
        {:halt, SessionStatus.put_p2p(socket, %{p2p | peer_online: false})}

      true ->
        {:halt,
         socket
         |> SessionStatus.put_p2p(%{p2p | peer_online: false})
         |> Surface.system(
           dgettext("chat", "%{peer} lost the P2P connection — waiting for them to return...",
             peer: p2p.peer_nick
           )
         )}
    end
  end

  def handle(
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

  def handle(
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

  def handle(
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

  def handle(
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

  def handle(
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
  def handle(
        %{event: "lobby_game_request", payload: %{game_id: game_id} = request},
        socket,
        %{match_game_id: game_id} = p2p
      )
      when is_binary(game_id) do
    if request.proposer_id == p2p.user_id do
      {:halt, Console.open(socket, "games")}
    else
      _ = Lobby.respond_game(p2p.token, p2p.user_id, true)
      {:halt, Console.open(socket, "games")}
    end
  end

  def handle(%{event: "lobby_game_request", payload: request}, socket, p2p) do
    outgoing = request.proposer_id == p2p.user_id

    Phoenix.LiveView.send_update(P2PGameIsland,
      id: P2PGameIsland.id(),
      action: {:request, request, outgoing}
    )

    {:halt, Console.open(socket, "games")}
  end

  def handle(
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

  def handle(
        %{event: "lobby_game_response", payload: %{accepted: true}},
        socket,
        _p2p
      ) do
    {:halt, socket}
  end

  def handle(
        %{event: "lobby_game_status_changed", payload: %{status: "playing"} = payload},
        socket,
        p2p
      ) do
    is_host = payload.host_id == p2p.user_id
    :ok = Activity.playing(socket.assigns.nickname, payload.game_id, p2p.token)

    Phoenix.LiveView.send_update(P2PGameIsland,
      id: P2PGameIsland.id(),
      action: {:playing, payload.game_id, is_host}
    )

    SessionLink.send_watchers(p2p.token)

    {:halt, Console.open(socket, "games")}
  end

  def handle(
        %{event: "lobby_game_status_changed", payload: %{status: "idle"}},
        socket,
        _p2p
      ) do
    :ok = Activity.stopped(socket.assigns.nickname)
    Phoenix.LiveView.send_update(P2PGameIsland, id: P2PGameIsland.id(), action: :idle)

    {:halt, socket}
  end

  def handle(
        %{event: "lobby_game_status_changed", payload: %{status: "finished"} = payload},
        socket,
        _p2p
      ) do
    :ok = Activity.stopped(socket.assigns.nickname)

    Phoenix.LiveView.send_update(P2PGameIsland,
      id: P2PGameIsland.id(),
      action: {:result, payload.result}
    )

    {:halt, Console.open(socket, "games")}
  end

  def handle(
        %{event: "lobby_client_info", payload: %{from: from, info: info}},
        socket,
        p2p
      ) do
    if from == p2p.user_id do
      {:halt, socket}
    else
      {:halt, SessionStatus.put_p2p(socket, %{p2p | peer_info: info, peer_online: true})}
    end
  end

  def handle(
        %{event: "lobby_session_closed", payload: %{reason: reason}},
        socket,
        _p2p
      ) do
    {:halt, SessionLink.finish_session(socket, reason)}
  end

  def handle(%{event: "lobby_inactivity_warning"}, socket, _p2p) do
    {:halt,
     Surface.system(
       socket,
       dgettext("chat", "The P2P session will expire soon due to inactivity.")
     )}
  end

  # Session-topic events the in-chat host doesn't render directly. Feature
  # windows consume their own relays through their islands/hooks.
  def handle(_msg, socket, _p2p), do: {:halt, socket}

  # The other side has arrived, so this page takes its own seat. A match link
  # had nobody to name when it mounted, so the peer's nickname is read now
  # rather than remembered: for an open lobby this arrival *is* the moment
  # there is one.
  defp seat_taken(socket, p2p) do
    case Lobby.join_session(p2p.token, p2p.user_id) do
      :ok ->
        p2p =
          put_peer_nick(p2p, p2p.peer_nick || SessionStatus.peer_nick_for(p2p.token, p2p.user_id))

        socket
        |> SessionStatus.put_p2p(%{p2p | state: :joining, peer_online: true})
        |> SessionLink.share_client_info(p2p)
        |> Surface.system(
          dgettext("chat", "%{peer} accepted the P2P request - connecting...",
            peer: p2p.peer_nick || dgettext("chat", "The other user")
          )
        )

      {:error, :already_joined} ->
        SessionLink.detach_session(socket, p2p)

      {:error, message} ->
        socket |> SessionLink.detach_session(p2p) |> Surface.system(message)
    end
  end

  # Somebody joined a session this page is already in. Re-share our whois so a
  # peer that joined after us still receives it, and — if this session is
  # already running — say so, because the page that just arrived cannot know it
  # and would otherwise sit in the starting room waiting for a `[Start]` that
  # was pressed minutes ago.
  defp peer_rejoined(socket, p2p) do
    if p2p.session_started, do: Lobby.broadcast(p2p.token, "lobby_session_start", %{})

    socket =
      socket
      |> SessionStatus.put_p2p(%{p2p | peer_online: true})
      |> SessionLink.share_client_info(p2p)

    # A worry that turned out fine has to be taken back, or it stays on screen
    # for the rest of the session saying the opposite of the truth.
    if p2p.state == :connected and not p2p.peer_online do
      Surface.system(socket, dgettext("chat", "%{peer} is back.", peer: p2p.peer_nick))
    else
      socket
    end
  end

  # The language travels with the name: a peer named only now (an open lobby's
  # arrival) is looked up once, here.
  defp put_peer_nick(%{peer_nick: nick} = p2p, nick), do: p2p

  defp put_peer_nick(p2p, nick),
    do: Map.merge(p2p, %{peer_nick: nick, peer_locale: NickLocales.for_nick(nick)})

  defp maybe_persist_connected(socket, %{role: :creator, state: state} = p2p)
       when state != :connected do
    SessionLink.persist_p2p_system(
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
  @spec enter_connected(Socket.t(), map()) :: Socket.t()
  def enter_connected(socket, %{state: :connected} = p2p) do
    SessionStatus.emit_p2p_connected(p2p)

    SessionStatus.put_p2p(socket, %{
      p2p
      | webrtc_started: true,
        webrtc_connection_reset: false,
        recovery: SessionStatus.empty_p2p_recovery()
    })
  end

  def enter_connected(socket, p2p) do
    SessionStatus.emit_p2p_connected(p2p)

    socket
    |> maybe_persist_connected(p2p)
    # The status bar said "connecting" from the moment the peer accepted;
    # now that the link is up it says so, rather than lingering on the wait.
    |> Surface.system(
      dgettext("chat", "P2P session connected - call, files, games and stats are available.")
    )
    |> SessionStatus.put_p2p(%{
      p2p
      | state: :connected,
        webrtc_started: true,
        webrtc_connection_reset: false,
        recovery: SessionStatus.empty_p2p_recovery()
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
    socket |> Console.open("games") |> propose_match_game()
  end

  defp burst_windows(socket) do
    Console.open(socket, "call")
  end

  defp propose_match_game(
         %{assigns: %{p2p_session: %{role: :creator, match_proposed: false} = p2p}} = socket
       ) do
    _ = Lobby.propose_game(p2p.token, p2p.user_id, p2p.match_game_id)
    SessionStatus.put_p2p(socket, %{p2p | match_proposed: true})
  end

  defp propose_match_game(socket), do: socket
end
