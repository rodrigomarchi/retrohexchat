defmodule RetroHexChatWeb.App.P2PLive do
  @moduledoc """
  A one-to-one P2P session, as a surface of its own.

  One module, two mounts: this is the page at `/p2p/:token` and it is also what
  the chat's P2P window renders. Nothing about a session is written twice — the
  difference between the two is where the process hangs, not what it does.
  Everything that genuinely differs goes through
  `RetroHexChatWeb.Live.SurfaceHost`.

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

  import RetroHexChatWeb.Components.UI.Desktop
  import RetroHexChatWeb.Components.UI.P2P.StartingRoom
  import RetroHexChatWeb.Components.UI.ShareBar
  import RetroHexChatWeb.Components.UI.Window

  alias Phoenix.LiveView.Socket
  alias RetroHexChat.Lobby
  alias RetroHexChat.Lobby.Schema.Session, as: LobbySession
  alias RetroHexChat.ShareLinks
  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.App.SessionHelpers
  alias RetroHexChatWeb.ChatLive.Components.P2PSessionConsole
  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.Live.P2PConfirmDialog
  alias RetroHexChatWeb.Live.SurfaceHost, as: Host
  alias RetroHexChatWeb.P2PLive.Events
  alias RetroHexChatWeb.ShareLinkRef

  @impl true
  @spec mount(map(), map(), Socket.t()) :: {:ok, Socket.t()}
  def mount(params, session, socket) do
    socket =
      assign(socket,
        embedded?: session["embedded"] == true,
        surface_tag: :p2p,
        nickname: session["nickname"] || socket.assigns[:surface_nickname],
        # The device preference is the person's, not the screen's: the same
        # terminal that remembered a camera for the chat's setup dialog has to
        # hand it to the room that replaced it.
        trusted_device_id: session["trusted_device_id"] || socket.assigns[:trusted_device_id],
        client_info: session["client_info"] || %{},
        p2p_session: nil,
        setup: nil,
        host_snapshot: nil,
        notice: nil,
        share_url: nil,
        denied: nil
      )

    case resolve_session(socket, params, session) do
      {:ok, db_session, user_id, role} ->
        {:ok,
         socket
         |> assign(setup: Events.initial_setup(socket))
         |> enter(db_session, user_id, role)
         |> publish()}

      {:error, message} ->
        {:ok, assign(socket, denied: message)}
    end
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(%{embedded?: true} = assigns) do
    ~H"""
    <div class="h-full min-h-0">
      <.p2p_body {assigns} />
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <%!-- The same shell every other desktop screen uses: the workspace only
          has a height because something above it does. --%>
    <div class="bg-background text-text font-system flex h-screen flex-col">
      <.desktop id="p2p-desktop" persist_key="p2p" class="flex-1" data-testid="p2p-desktop">
        <.desktop_window
          id="p2p-call"
          title={window_title(@p2p_session)}
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
              <.link navigate={~p"/chat"} data-testid="p2p-back-to-chat">
                ← {dgettext("chat", "Chat")}
              </.link>
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

  # The chat renders this same LiveView inside its own P2P window, so the body
  # is shared and the chrome is not.
  defp p2p_body(assigns) do
    ~H"""
    <div class="flex h-full min-h-0 flex-col">
      <.p2p_denied :if={@denied} message={@denied} />

      <.p2p_displaced :if={displaced?(@p2p_session)} />

      <.p2p_starting_room
        :if={in_room?(@p2p_session)}
        id="p2p-starting-room"
        setup={@setup}
        room={Events.room(assigns)}
      >
        <:footer>
          <%!-- Minting is a deliberate act, not a side effect of opening a
                session: a link per invite sent would fill the table with
                addresses nobody ever followed. --%>
          <.share_bar
            url={@share_url}
            available={sharable?(@nickname)}
            on_share="share_p2p"
            class="min-w-0 flex-1 justify-start"
          />
          <%!-- A plain anchor, so the middle click and "open in new tab" the
                browser already offers work; `noopener` because without it the
                new tab shares this one's event loop. --%>
          <a
            :if={@embedded?}
            href={Paths.p2p_path(@p2p_session.token)}
            target="_blank"
            rel="noopener"
            class="shadow-retro-raised bg-surface flex h-[26px] shrink-0 items-center justify-center gap-1 px-3 text-sm focus:outline-none focus-visible:ring-1 focus-visible:ring-foreground"
            data-testid="p2p-open-in-tab"
          >
            <Icons.icon_btn_link class="h-3.5 w-3.5" />
            <span>{dgettext("chat", "Open in a tab")}</span>
          </a>
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
             kind: "p2p",
             target: %{"session_token" => token},
             creator_id: user_id,
             creator_nick: nickname
           }) do
      {:noreply, assign(socket, share_url: ShareLinkRef.url(link.slug))}
    else
      _unavailable -> {:noreply, socket}
    end
  end

  def handle_event("share_p2p", _params, socket), do: {:noreply, socket}

  def handle_event(event, params, socket) do
    {_halted, socket} = Events.handle_event(event, params, socket)
    {:noreply, publish(socket)}
  end

  @impl true
  @spec handle_info(term(), Socket.t()) :: {:noreply, Socket.t()}
  # The chat forwards the window chrome it still owns: the X lands on the
  # chat's window, this session is what it means.
  def handle_info({:p2p_surface_command, {:event, event}}, socket) do
    {_halted, socket} = Events.handle_event(event, %{}, socket)
    {:noreply, publish(socket)}
  end

  def handle_info({:p2p_surface_command, {:event, event, params}}, socket) do
    {_halted, socket} = Events.handle_event(event, params, socket)
    {:noreply, publish(socket)}
  end

  def handle_info(message, socket) do
    {_halted, socket} = Events.handle_info(message, socket)
    {:noreply, publish(socket)}
  end

  defp publish(socket), do: Host.publish(socket, host_snapshot(socket))

  @doc """
  What the host is told about the session — public so its shape is testable.

  The nickname, the state, the transport policy, and the three summaries the
  chat's status zone turns into facets. Nothing else: the chat draws a taskbar
  button and a status zone, and reads no media state it is not carrying.
  """
  @spec host_snapshot(Socket.t()) :: map() | nil
  def host_snapshot(%{assigns: %{p2p_session: %{} = p2p}}) do
    %{
      token: p2p.token,
      user_id: p2p.user_id,
      peer_nick: p2p.peer_nick,
      role: p2p.role,
      state: p2p.state,
      turn_configured: p2p.turn_configured,
      turn_only: p2p.turn_only,
      recovery: p2p.recovery,
      call_summary: p2p.call_summary,
      file_summary: p2p.file_summary,
      game_summary: p2p.game_summary
    }
  end

  def host_snapshot(_socket), do: nil

  # The creator of a pending invite is subscribed but has not taken a seat: a
  # pending invite is a card, not a connection, and joining before the peer
  # accepts would start the rejoin grace on a session nobody is in yet.
  defp enter(socket, %LobbySession{status: "pending"} = db_session, user_id, :creator) do
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "lobby:#{db_session.token}")

    socket
    |> assign(p2p_session: Events.new_invite_sent(socket, db_session.token, user_id))
    |> resume_started(db_session)
  end

  defp enter(socket, db_session, user_id, role) do
    socket
    |> Events.attach_session(db_session.token, user_id, role)
    |> resume_started(db_session)
  end

  # A session that is already connected does not send you back to the starting
  # room: the reload of a page mid-call is the one moment where being asked to
  # press `[Ready]` again would be the surface losing the call it is showing.
  defp resume_started(socket, %LobbySession{status: "connected"}) do
    case socket.assigns.p2p_session do
      %{} = p2p ->
        assign(socket,
          p2p_session: %{p2p | room_ready: true, peer_ready: true, session_started: true}
        )

      nil ->
        socket
    end
  end

  defp resume_started(socket, _db_session), do: socket

  # Embedded, the chat already decided which session and already applied the
  # gates it owns; the surface is handed the token. Standalone, the token in
  # the address is all there is, so every gate runs here — and the refusal is
  # the policy's own sentence, because that is the part the reader can act on.
  defp resolve_session(socket, params, session) do
    # A nested `live_render` never went through the router, so its params are
    # the atom `:not_mounted_at_router` rather than a map — the token comes
    # from the host's session there, and from the address here.
    token = if is_map(params), do: params["token"], else: session["token"]

    with {:ok, token} <- require_token(token),
         {:ok, db_session} <- fetch_session(token),
         {:ok, user_id} <- require_registered(socket.assigns.nickname),
         :ok <- Lobby.Policy.can_join?(user_id, db_session) do
      {:ok, db_session, user_id, role_of(db_session, user_id)}
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

  # Only a registered nickname can mint a link: the record carries who made it,
  # and a link nobody is accountable for is one nobody can be asked about.
  defp sharable?(nickname) when is_binary(nickname) and nickname != "" do
    match?({:ok, _id}, SessionHelpers.resolve_user_id(nickname))
  end

  defp sharable?(_nickname), do: false

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

  defp window_title(%{peer_nick: peer}) when is_binary(peer) and peer != "",
    do: dgettext("chat", "P2P · %{peer}", peer: peer)

  defp window_title(_p2p), do: dgettext("chat", "P2P Session")
end
