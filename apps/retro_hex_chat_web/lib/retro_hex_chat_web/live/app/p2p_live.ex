defmodule RetroHexChatWeb.App.P2PLive do
  @moduledoc """
  A one-to-one P2P session, at an address of its own.

  The page at `/p2p/:token`, and the only place a session is rendered. The chat
  has no window for one: the card in the private message is the door, and
  following it gives the session the whole window.

  Two states, and you always arrive at the first: the **starting room**, where
  you see who is here, pick your devices and press `[Ready]`, and **inside**.
  Unlike a call or a space, this antechamber has a host and a `[Start]`: a P2P
  session is an event rather than a place, and the creator is the only side
  that may offer.

  What stayed in the chat is the **invite**. It is a real private message, it
  is persisted, it has a card in the conversation, and creating the session
  *is* sending it — so it is conversation, and conversation is the chat's.

  The anchor keeps the id `lobby-webrtc` exactly: the media, game and
  file-transfer hooks locate the shared `RTCPeerConnection` through it. It
  changed page, not name.

  Both states are decided in `mount/3`. Initial data delivered after the first
  render is invisible to ExUnit and only ever caught in a browser.
  """
  use RetroHexChatWeb, :live_view

  import RetroHexChatWeb.Components.UI.ActivityIndicator
  import RetroHexChatWeb.Components.UI.Desktop
  import RetroHexChatWeb.Components.UI.P2P.StartingRoom
  import RetroHexChatWeb.Components.UI.SurfaceTabLink
  import RetroHexChatWeb.Components.UI.Window

  alias Phoenix.LiveView.Socket
  alias RetroHexChat.Games.Catalog
  alias RetroHexChat.Lobby
  alias RetroHexChat.Lobby.Schema.Session, as: LobbySession
  alias RetroHexChat.Services.NickServ
  alias RetroHexChat.ShareLinks
  alias RetroHexChat.Topics
  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.App.SessionHelpers
  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.Live.OpenSurfaces
  alias RetroHexChatWeb.Live.P2PConfirmDialog
  alias RetroHexChatWeb.Live.ShareControl
  alias RetroHexChatWeb.P2PLive.Components.P2PSessionConsole
  alias RetroHexChatWeb.P2PLive.Events
  alias RetroHexChatWeb.ShareLinkRef

  @impl true
  @spec mount(map(), map(), Socket.t()) :: {:ok, Socket.t()}
  def mount(params, session, socket) do
    socket =
      assign(socket,
        nickname: socket.assigns.surface_nickname,
        page_title: window_title(nil, nil),
        # The device preference is the person's, not the screen's: the same
        # terminal that remembered a camera for the chat's setup dialog has to
        # hand it to the room that replaced it.
        trusted_device_id: session["trusted_device_id"] || socket.assigns[:trusted_device_id],
        # What the browser said about itself when the socket joined; it is
        # shared with the peer, so a page with no socket yet has nothing to say.
        client_info: client_info(socket),
        p2p_session: nil,
        setup: nil,
        notice: nil,
        share_url: nil,
        share_slug: nil,
        match_game: nil,
        denied: nil,
        surface_left: false
      )

    socket = OpenSurfaces.attach(socket, socket.assigns.nickname)

    case resolve_session(socket, params) do
      {:ok, db_session, user_id, role} ->
        match_game = match_game(db_session)

        {:ok,
         socket
         |> assign(
           setup: Events.initial_setup(socket),
           match_game: match_game,
           page_title: window_title(nil, match_game)
         )
         |> enter(db_session, user_id, role)}

      {:error, message} ->
        {:ok, assign(socket, denied: message)}
    end
  end

  # What the session was made for, drawn rather than named: somebody who
  # followed a link posted in a channel has seen nothing of this match except
  # its address, and "what did I just walk into" is the only question the
  # starting room of a game has to answer.
  defp match_game(db_session) do
    with game_id when is_binary(game_id) <- Lobby.match_game_id(db_session),
         {:ok, game} <- Catalog.get_game(game_id) do
      game
    else
      _not_a_match -> nil
    end
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <%!-- The same shell every other desktop screen uses: the workspace only
          has a height because something above it does. --%>
    <div class="bg-background text-text font-system flex h-screen flex-col">
      <%!-- This tab answers when the chat asks for it by address. --%>
      <div id="surface-presence" phx-hook="SurfacePresenceHook" class="hidden"></div>
      <%!-- Where "Copied!" lands: a page of its own has no chat to borrow a
            toast container from. --%>
      <RetroHexChatWeb.Components.Toast.toast_container />
      <.desktop id="p2p-desktop" persist_key="p2p" class="flex-1" data-testid="p2p-desktop">
        <.desktop_window
          id="p2p-call"
          title={window_title(@p2p_session, @match_game)}
          pinned
          default_maximized
          body_class="h-full min-h-0 overflow-hidden p-1"
          data-testid="p2p-call-window"
        >
          <:icon><Icons.icon_protocol_p2p_compact class="h-4 w-4" /></:icon>
          <%!-- The title's meta says how the connection is doing, which is a
                thing there is nothing to say about until there is one. --%>
          <:meta>
            <P2PSessionConsole.p2p_title_meta
              :if={inside?(@p2p_session)}
              p2p_session={@p2p_session}
            />
          </:meta>
          <%!-- The way back is always on screen, in both states. Someone who
                arrived from a shared link has no chat tab behind this one, so
                it is a link and not a focus request — deciding between the two
                needs to know what else the person has open, which is a later
                wave. --%>
          <:status>
            <.window_status_bar_field grow>
              <.back_to_chat
                open?={OpenSurfaces.open?(@open_surface_paths, Paths.chat_path())}
                testid="p2p-back-to-chat"
              />
            </.window_status_bar_field>
            <.window_status_bar_field :if={@notice}>
              <span data-testid="p2p-notice">{@notice.message}</span>
            </.window_status_bar_field>
          </:status>
          <.p2p_body {assigns} />
        </.desktop_window>
      </.desktop>
    </div>
    """
  end

  # Split from the chrome around it so the states — refused, arriving, starting
  # room, inside, finished — read as one thing, and the window that frames
  # them as another.
  defp p2p_body(assigns) do
    ~H"""
    <div class="flex h-full min-h-0 flex-col">
      <.p2p_denied :if={@denied} message={@denied} />
      <.p2p_left :if={@surface_left} />

      <%!-- The first render of a match whose seat is still empty: the seat is
            taken by the mount that can hold it, so until the socket joins there
            is nothing here to draw yet. Same shape the chat's own dead render
            uses — paint what is true, not what is about to be. --%>
      <.p2p_arriving :if={arriving?(assigns)} />

      <.p2p_displaced :if={displaced?(@p2p_session)} />

      <.p2p_starting_room
        :if={in_room?(@p2p_session)}
        id="p2p-starting-room"
        setup={@setup}
        game={@match_game}
        room={Events.room(assigns)}
      >
        <:footer>
          <%!-- Minting is a deliberate act, not a side effect of opening a
                session: a link per invite sent would fill the table with
                addresses nobody ever followed. --%>
          <.live_component
            module={ShareControl}
            id="share-p2p"
            url={@share_url}
            available={sharable?(@nickname)}
            on_share="share_p2p"
            on_revoke="revoke_p2p"
            class="justify-start"
          />
        </:footer>
      </.p2p_starting_room>

      <div :if={inside?(@p2p_session)} class="min-h-0 flex-1">
        <.live_component
          module={P2PSessionConsole}
          id="p2p-session-console"
          p2p_session={@p2p_session}
          section={Map.get(@p2p_session, :console_section, "call")}
          nickname={@nickname}
          client_info={@client_info}
          session_status={panel_status(@p2p_session)}
          connection_label={nil}
        />
      </div>

      <.live_component module={P2PConfirmDialog} id={P2PConfirmDialog.id()} scope={:window} />

      <%!-- P2P WebRTC anchor: the wrapper is keyed by session token so
            switching sessions replaces it wholesale — the hook remounts with a
            fresh RTCPeerConnection. The inner id MUST stay "lobby-webrtc": the
            media, game and file-transfer hooks locate the shared PC through it.
            NOT mounted before `[Ready]` — a hook here would report readiness
            for devices the person has not chosen yet, and readiness is half of
            what makes the first offer safe to send. --%>
      <div :if={armed?(@p2p_session)} id={"p2p-session-#{@p2p_session.token}"} class="hidden">
        <div
          id="lobby-webrtc"
          phx-hook="LobbyWebRTCHook"
          phx-update="ignore"
          data-testid="p2p-webrtc"
          data-session-token={@p2p_session.token}
          data-join-token={Events.signaling_join_token(@p2p_session, @nickname)}
        >
        </div>
      </div>
    </div>
    """
  end

  attr :message, :string, required: true

  # A refusal says what the policy said. A generic "not allowed" would make the
  # one thing the reader can act on the one thing the screen withholds.
  defp p2p_denied(assigns) do
    ~H"""
    <div
      class="m-auto flex h-fit w-full max-w-[520px] items-start gap-2 border border-border bg-canvas p-2 text-xs shadow-retro-sunken"
      data-testid="p2p-denied"
    >
      <span class="flex h-8 w-8 shrink-0 items-center justify-center bg-surface shadow-retro-sunken">
        <Icons.icon_protocol_p2p_compact class="h-4 w-4" />
      </span>
      <p class="min-w-0">{@message}</p>
    </div>
    """
  end

  # The session is over and this page said so on its status bar. No second way
  # back: `← Chat` is along the bottom of the window in every state, and it is
  # the one that knows how to reach a chat tab that is already open.
  defp p2p_left(assigns) do
    ~H"""
    <div
      class="m-auto flex h-fit w-full max-w-[520px] items-start gap-2 border border-border bg-canvas p-2 text-xs shadow-retro-sunken"
      data-testid="p2p-left"
    >
      <span class="flex h-8 w-8 shrink-0 items-center justify-center bg-surface shadow-retro-sunken">
        <Icons.icon_protocol_p2p_compact class="h-4 w-4" />
      </span>
      <p class="min-w-0">{dgettext("chat", "Session ended.")}</p>
    </div>
    """
  end

  defp p2p_arriving(assigns) do
    ~H"""
    <div class="m-auto" data-testid="p2p-arriving">
      <.boot_activity_panel
        title={dgettext("p2p", "P2P Session")}
        text={dgettext("p2p", "Taking your seat...")}
        icon={:protocol_p2p}
      />
    </div>
    """
  end

  # A page that lost its seat is not an error and not a dead end: the way to
  # get it back is on the screen that lost it.
  defp p2p_displaced(assigns) do
    ~H"""
    <div
      class="m-auto flex h-fit w-full max-w-[520px] items-start gap-2 border border-border bg-canvas p-2 text-xs shadow-retro-sunken"
      data-testid="p2p-displaced"
    >
      <span class="flex h-8 w-8 shrink-0 items-center justify-center bg-surface shadow-retro-sunken">
        <Icons.icon_protocol_p2p_compact class="h-4 w-4" />
      </span>
      <div class="min-w-0">
        <p>{dgettext("p2p", "This session is open in another window of yours.")}</p>
        <button
          type="button"
          phx-click="p2p_room_reclaim"
          class="shadow-retro-raised bg-surface mt-2 h-[26px] px-3"
          data-testid="p2p-reclaim"
        >
          {dgettext("p2p", "Bring it back here")}
        </button>
      </div>
    </div>
    """
  end

  @impl true
  @spec handle_event(String.t(), map(), Socket.t()) :: {:noreply, Socket.t()}
  def handle_event("share_p2p", _params, %{assigns: %{p2p_session: %{token: token}}} = socket)
      when is_binary(token) do
    nickname = socket.assigns.nickname

    with {:ok, user_id} <- SessionHelpers.resolve_user_id(nickname || ""),
         {:ok, link} <-
           ShareLinks.create(%{
             kind: share_kind(socket.assigns.match_game),
             target: share_target(token, socket.assigns.match_game),
             creator_id: user_id,
             creator_nick: nickname
           }) do
      {:noreply, assign(socket, share_url: ShareLinkRef.url(link.slug), share_slug: link.slug)}
    else
      _unavailable -> {:noreply, socket}
    end
  end

  def handle_event("share_p2p", _params, socket), do: {:noreply, socket}

  # Closing the address without closing the room. `ShareLinks` asks its own
  # policy who may — the creator, or an operator of the channel the link leads
  # into — so a screen that offers the button is not the thing deciding.
  def handle_event("revoke_p2p", _params, %{assigns: %{share_slug: slug}} = socket)
      when is_binary(slug) do
    case ShareLinks.revoke(slug, socket.assigns.nickname || "") do
      {:ok, _link} -> {:noreply, assign(socket, share_url: nil, share_slug: nil)}
      _refused -> {:noreply, socket}
    end
  end

  def handle_event("revoke_p2p", _params, socket), do: {:noreply, socket}

  def handle_event(event, params, socket) do
    {_halted, socket} = Events.handle_event(event, params, socket)
    {:noreply, socket}
  end

  @impl true
  @spec handle_info(term(), Socket.t()) :: {:noreply, Socket.t()}
  def handle_info(message, socket) do
    {_halted, socket} = Events.handle_info(message, socket)
    {:noreply, socket}
  end

  # The creator of a pending invite is subscribed but has not taken a seat: a
  # pending invite is a card, not a connection, and joining before the peer
  # accepts would start the rejoin grace on a session nobody is in yet.
  # An open lobby's creator is in the same place: the seat opposite is empty,
  # nobody has joined, and taking one here would start the rejoin grace on a
  # match nobody has walked into yet.
  defp enter(socket, %LobbySession{status: status} = db_session, user_id, :creator)
       when status in ["pending", "open"] do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.lobby(db_session.token))
    end

    socket
    |> assign(
      p2p_session:
        Events.new_invite_sent(socket, db_session.token, user_id, match_opts(db_session))
    )
    |> resume_started(db_session)
  end

  # Taking the seat is the sharper half of what a first render must not do.
  # `attach_session/5` joins with `takeover: true` — the contract that moves a
  # session into the window that just opened it — so on a bare fetch it handed
  # the seat to the request process, which is already gone when the browser
  # answers. Somebody's running call would be displaced by a prefetch, and the
  # dead process's `:DOWN` would open the rejoin grace against nobody.
  defp enter(socket, db_session, user_id, role) do
    if connected?(socket) do
      socket
      |> Events.attach_session(db_session.token, user_id, role, match_opts(db_session))
      |> resume_started(db_session)
    else
      socket
    end
  end

  defp match_opts(db_session), do: [match_game_id: Lobby.match_game_id(db_session)]

  # A session that is already connected does not send you back to the starting
  # room: the reload of a page mid-call is the one moment where being asked to
  # press `[Ready]` again would be the surface losing the call it is showing.
  defp resume_started(socket, %LobbySession{status: "connected"}) do
    # `:connected` is the domain's own answer, not an optimism: a page that
    # arrives into a running session has to say so, because the media hook
    # only auto-starts the call once the session reads as connected — and a
    # page that never starts its own media is a page the other side sees as
    # a black tile.
    resume_into(socket, :connected)
  end

  # Reloading while the first offer is still being applied comes back to a
  # session that is running every bit as much as a connected one: the
  # negotiation has been released and the peer is holding a connection against
  # this seat. The status is `lobby` for the whole of that window, so it cannot
  # be the test — sending the page to the starting room would ask it to press
  # `[Ready]` again for something that already started, and the peer would wait
  # for a readiness report that nobody is going to send.
  defp resume_started(socket, %LobbySession{token: token}) do
    if Lobby.signaling_released?(token) do
      resume_into(socket, :connecting)
    else
      socket
    end
  end

  defp resume_into(socket, state) do
    case socket.assigns.p2p_session do
      %{} = p2p ->
        assign(socket,
          p2p_session: %{
            p2p
            | room_ready: true,
              peer_ready: true,
              session_started: true,
              webrtc_connection_reset: true,
              state: state
          }
        )

      nil ->
        socket
    end
  end

  # The token in the address is all there is, so every gate runs here — and the
  # refusal is the policy's own sentence, because that is the part the reader
  # can act on.
  defp resolve_session(socket, params) do
    token = params["token"]
    seating? = connected?(socket)

    with {:ok, token} <- require_token(token),
         {:ok, db_session} <- fetch_session(token),
         {:ok, user_id} <- require_registered(socket.assigns.nickname),
         :ok <- require_identified(socket.assigns.nickname),
         {:ok, db_session} <- take_seat(db_session, user_id, seating?),
         :ok <- allowed_in?(db_session, user_id, seating?) do
      {:ok, db_session, user_id, role_of(db_session, user_id)}
    end
  end

  # A match link has an empty seat, and following it is how you take it. This
  # is the only door in the plan where arriving *changes* what the link points
  # at, and it is why the claim happens here rather than on the public card:
  # the card runs before any of the three questions above, so a seat taken
  # there could be burned by somebody the surface then refuses.
  #
  # `seating?` is what keeps that from being true of the first render as well.
  # A page is fetched before it is connected, so an unguarded claim here belongs
  # to anything that merely *retrieves* the address — a speculative prefetch, an
  # extension, a scanner behind an authenticated proxy — and a claim cannot be
  # undone: `open` is the only status the link is followable in, and the session
  # it becomes runs forward and never back.
  defp take_seat(%LobbySession{creator_id: user_id} = db_session, user_id, _seating?),
    do: {:ok, db_session}

  defp take_seat(%LobbySession{peer_id: user_id} = db_session, user_id, _seating?),
    do: {:ok, db_session}

  defp take_seat(db_session, user_id, seating?) do
    cond do
      Lobby.open_session?(db_session) and seating? ->
        claim_seat(db_session, user_id)

      Lobby.open_session?(db_session) ->
        {:ok, db_session}

      # A stranger at a match link is late, not lost: "you are not a
      # participant" would be true and useless, because being one was the
      # thing this link was offering.
      is_binary(Lobby.match_game_id(db_session)) ->
        {:error, full_message()}

      true ->
        {:ok, db_session}
    end
  end

  # The policy is asked about a seat that exists. On the first render of a match
  # whose seat is still empty there is nothing to ask about yet, and asking
  # anyway would refuse the one person the address was written for. Every other
  # refusal still reaches the first paint, because a page that only says "you
  # may not" once the socket joins is a page that shows the room first.
  defp allowed_in?(db_session, user_id, true),
    do: Lobby.Policy.can_join?(user_id, db_session)

  defp allowed_in?(db_session, user_id, false) do
    if Lobby.open_session?(db_session),
      do: :ok,
      else: Lobby.Policy.can_join?(user_id, db_session)
  end

  defp claim_seat(db_session, user_id) do
    case Lobby.claim_open_session(db_session.token, user_id) do
      {:ok, claimed} -> {:ok, claimed}
      {:error, :already_claimed} -> {:error, full_message()}
      {:error, message} -> {:error, message}
    end
  end

  defp require_token(token) when is_binary(token) and token != "", do: {:ok, token}
  defp require_token(_token), do: {:error, gone_message()}

  defp fetch_session(token) do
    case Lobby.get_session(token) do
      {:ok, %LobbySession{} = db_session} ->
        if LobbySession.terminal?(db_session.status),
          do: {:error, gone_message()},
          else: {:ok, db_session}

      {:error, :not_found} ->
        {:error, gone_message()}
    end
  end

  # Asked after registration, because "you are not registered" is the concrete
  # answer for a nickname that is not in the table, and this one is the answer
  # for a nickname that is. Registration alone is not enough at this door:
  # being a participant is recorded as a `registered_nicks` id, so whoever is
  # merely holding the nickname would otherwise walk into a session that
  # belongs to the person who owns it. Identification is not the chat's private
  # fact — NickServ keeps the set, and this asks the same authority the
  # conference does.
  defp require_identified(nickname) when is_binary(nickname) do
    if NickServ.identified?(nickname) do
      :ok
    else
      {:error, dgettext("p2p", "You must be identified with NickServ to use P2P sessions.")}
    end
  end

  defp require_identified(_nickname),
    do: {:error, dgettext("p2p", "You must be identified with NickServ to use P2P sessions.")}

  defp require_registered(nickname) when is_binary(nickname) do
    case SessionHelpers.resolve_user_id(nickname) do
      {:ok, user_id} ->
        {:ok, user_id}

      _unregistered ->
        {:error, dgettext("p2p", "You must be registered with NickServ to use P2P sessions.")}
    end
  end

  defp require_registered(_nickname),
    do: {:error, dgettext("p2p", "You must be registered with NickServ to use P2P sessions.")}

  defp role_of(%LobbySession{creator_id: user_id}, user_id), do: :creator
  defp role_of(_db_session, _user_id), do: :peer

  defp gone_message, do: dgettext("p2p", "This P2P session is no longer available.")

  # Said as a fact about the match and never about who filled it: naming the
  # other player would turn a link anybody may hold into a way of learning who
  # answered it.
  defp full_message, do: dgettext("p2p", "This match is already full.")

  # A match is shared as a game, because that is what the person receiving it
  # is being offered — and the card then draws the game rather than "a P2P
  # session with ana". Same session, same surface; the kind is what the link
  # is *about*.
  defp share_kind(%{id: _game_id}), do: "play"
  defp share_kind(_no_game), do: "p2p"

  defp share_target(token, %{id: game_id}),
    do: %{"game_id" => game_id, "session_token" => token}

  defp share_target(token, _no_game), do: %{"session_token" => token}

  # Only a registered nickname can mint a link: the record carries who made it,
  # and a link nobody is accountable for is one nobody can be asked about.
  defp sharable?(nickname) when is_binary(nickname) and nickname != "" do
    match?({:ok, _id}, SessionHelpers.resolve_user_id(nickname))
  end

  defp sharable?(_nickname), do: false

  # Nothing refused, nothing finished and nothing to draw: the seat is still
  # being taken.
  defp arriving?(%{denied: nil, surface_left: false, p2p_session: nil}), do: true
  defp arriving?(_assigns), do: false

  defp client_info(socket) do
    if connected?(socket),
      do: SessionHelpers.parse_client_info(get_connect_params(socket)),
      else: %{}
  end

  defp displaced?(%{displaced: true}), do: true
  defp displaced?(_p2p), do: false

  defp in_room?(%{displaced: true}), do: false
  defp in_room?(%{session_started: false}), do: true
  defp in_room?(_p2p), do: false

  defp inside?(%{displaced: true}), do: false
  defp inside?(%{session_started: true}), do: true
  defp inside?(_p2p), do: false

  # Armed from `[Ready]` onwards and never before: the hook reporting ready is
  # the second half of what the button promises.
  defp armed?(%{displaced: true}), do: false
  defp armed?(%{room_ready: true}), do: true
  defp armed?(_p2p), do: false

  # The shared Statistics panel speaks the domain status vocabulary; this state
  # machine maps onto it (a pending invite reads as "pending", both joining
  # phases as "lobby").
  defp panel_status(%{state: :connected}), do: "connected"
  defp panel_status(%{state: :invite_sent}), do: "pending"
  defp panel_status(_p2p), do: "lobby"

  # A match says which game it is, because that is what somebody who followed
  # the link came for; a plain session says who is on the other end.
  defp window_title(%{peer_nick: peer}, %{name: game})
       when is_binary(peer) and peer != "",
       do: dgettext("chat", "%{game} · %{peer}", game: game, peer: peer)

  defp window_title(_p2p, %{name: game}),
    do: dgettext("chat", "%{game} · match", game: game)

  defp window_title(%{peer_nick: peer}, _game) when is_binary(peer) and peer != "",
    do: dgettext("chat", "P2P · %{peer}", peer: peer)

  defp window_title(_p2p, _game), do: dgettext("chat", "P2P Session")
end
