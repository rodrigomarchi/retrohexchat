defmodule RetroHexChatWeb.App.SpaceLive do
  @moduledoc """
  A virtual space, at an address of its own.

  The page at `/space/:slug`, and the only place a space is rendered. The chat
  used to draw this same module into the conversation's own region behind a tab;
  it does not any more, and the isometric renderer — the largest chunk in the
  app, running a continuous render loop — no longer shares a main thread with
  the chat's message stream.

  Two states, and you always arrive at the first: the **antechamber**, which is
  the character picker, and **inside**. There is no `[Start]`, because a space
  does not begin or end — it is a place, and the address of a place stays good.
  What begins and ends is the gathering in it, which the conversation hears
  about as a card.

  Both states are decided in `mount/3`. Initial data delivered after the first
  render is invisible to ExUnit and only ever caught in a browser.

  A space's gate leads to its Construct, at an address of its own, and the
  Construct's gate leads back. Walking through either one carries the character
  in the address (`?avatar=`), so the door is not a second antechamber: the
  same `mount/3` that would draw the picker goes straight inside instead.
  """

  alias RetroHexChat.Nickname
  use RetroHexChatWeb, :live_view

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.SpaceBuildPalette
  import RetroHexChatWeb.Components.UI.Desktop
  import RetroHexChatWeb.Components.UI.NickPortrait
  import RetroHexChatWeb.Components.UI.SpaceCharacterSelect
  import RetroHexChatWeb.Components.UI.SpaceConstructPanel
  import RetroHexChatWeb.Components.UI.SpaceFullscreenToggle
  import RetroHexChatWeb.Components.UI.Space.PixelIcon
  import RetroHexChatWeb.Components.UI.SpaceSayBar
  import RetroHexChatWeb.Components.UI.SpaceVirtualPad
  import RetroHexChatWeb.Components.UI.SurfaceTabLink
  import RetroHexChatWeb.Components.UI.Window

  alias Phoenix.LiveView.Socket
  alias RetroHexChat.Accounts.Avatars
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Channels.Visibility
  alias RetroHexChat.ShareLinks
  alias RetroHexChat.Topics
  alias RetroHexChat.VirtualSpace
  alias RetroHexChat.VirtualSpace.ChannelJoinToken
  alias RetroHexChat.VirtualSpace.DirectMessageSpace
  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.App.SessionHelpers
  alias RetroHexChatWeb.Live.OpenSurfaces
  alias RetroHexChatWeb.Live.ShareControl
  alias RetroHexChatWeb.ShareLinkRef
  alias RetroHexChatWeb.SpaceAssets
  alias RetroHexChatWeb.SpaceRef

  @impl true
  @spec mount(map(), map(), Socket.t()) :: {:ok, Socket.t()}
  def mount(params, session, socket) do
    nickname = socket.assigns.surface_nickname
    saved_avatar = saved_avatar(nickname)

    socket =
      assign(socket,
        nickname: nickname,
        page_title: loading_title(nil),
        avatars: VirtualSpace.avatars(),
        avatar: nil,
        # The character a registered nickname chose is its identity — the one
        # the chat draws beside it — and the picker starts on it in any
        # browser. Without one, the browser that picked last time says which,
        # because nothing else outlives a visit.
        saved_avatar: saved_avatar,
        last_avatar: saved_avatar || hd(VirtualSpace.avatars()),
        join_token: nil,
        roster: [],
        share_url: nil,
        share_slug: nil,
        space: nil,
        denied: nil,
        say_draft: "",
        say_error: nil,
        changing_avatar: false
      )

    # Resolved once, at the door: the join token carries it into the space's
    # own channel, which is what decides whether the gathering it opens has
    # somebody accountable enough to be announced in the conversation.
    socket = assign(socket, user_id: user_id(socket.assigns.nickname))
    socket = OpenSurfaces.attach(socket, socket.assigns.nickname)

    case resolve_space(socket, params, session) do
      {:ok, space} ->
        {:ok,
         socket
         |> assign(space: space)
         |> subscribe_to_roster(space)
         |> assign(roster: VirtualSpace.roster(space.id))
         |> walk_through(params["avatar"])}

      {:error, message} ->
        {:ok, assign(socket, denied: message)}
    end
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <%!-- The same shell every other desktop screen uses: the workspace only
          has a height because something above it does. --%>
    <%!-- `space-ui` puts the whole page in the space's pixel-art kit
          (features/space-ui.css): the window, the overlays, the say bar. --%>
    <%!-- The visible viewport, not 100vh: on a phone 100vh is the viewport with
          the address bar hidden, and the page would scroll by the bar's height.
          The chat's own root and hook, so both follow the keyboard the same way. --%>
    <div class="space-ui chat-app-root fixed inset-0 flex flex-col overflow-hidden bg-background text-text">
      <div id="viewport-detect" phx-hook="ViewportDetectHook" class="hidden"></div>
      <%!-- This tab answers when the chat asks for it by address. --%>
      <div id="surface-presence" phx-hook="SurfacePresenceHook" class="hidden"></div>
      <%!-- Where "Copied!" lands: a page of its own has no chat to borrow a
            toast container from. --%>
      <RetroHexChatWeb.Components.Toast.toast_container tips={false} />
      <.desktop id="space-desktop" persist_key="space" class="flex-1" data-testid="space-desktop">
        <.desktop_window
          id="virtual-space"
          title={window_title(@space)}
          skin="pixel"
          pinned
          default_maximized
          body_class="h-full min-h-0 overflow-hidden p-1"
          data-testid="virtual-space-window"
        >
          <:icon><.pixel_icon name={:space} /></:icon>
          <%!-- The way back is always there. On the map it is on the say bar,
                the one line under the map; before the map (the picker, a
                refusal) it is the window's own status line. --%>
          <:status :if={!(@space && @avatar)}>
            <.window_status_bar_field skin="pixel" grow>
              <.back_to_chat
                open?={OpenSurfaces.open?(@open_surface_paths, Paths.chat_path())}
                testid="space-back-to-chat"
              />
            </.window_status_bar_field>
            <.window_status_bar_field skin="pixel">
              <.space_count roster={@roster} />
            </.window_status_bar_field>
          </:status>
          <div class="relative flex h-full min-h-0 w-full">
            <.space_body {assigns} />
          </div>
        </.desktop_window>
      </.desktop>
    </div>
    """
  end

  defp space_body(assigns) do
    ~H"""
    <.space_denied :if={@denied} message={@denied} />

    <%!-- The picker remembers the character across visits by asking the browser,
          because nothing on the server outlives a visit any more: the LiveView
          is mounted per visit and the chat that used to hold this no longer has
          the space in it at all. --%>
    <.space_character_select
      :if={@space && is_nil(@avatar)}
      avatars={@avatars}
      selected={@last_avatar}
      roster={@roster}
      remember_key={@space && "space:last-avatar"}
    >
      <:footer>
        <%!-- The invitation is made at the door: a bar over the map would take
              pixels from the thing the person came for, and the picker is the
              one screen every visit goes through. --%>
        <%!-- A Construct is shared through its space: its gate is right there. --%>
        <.live_component
          :if={@space.mode != "construct"}
          module={ShareControl}
          id="share-space"
          url={@share_url}
          available={sharable?(@user_id)}
          on_share="share_space"
          on_revoke="revoke_space"
          variant="pixel"
          class="justify-start"
        />
      </:footer>
    </.space_character_select>

    <%!-- The stage is what fullscreen presents: the map and the line you type
          in go together, or a fullscreen map would leave you mute. --%>
    <div
      :if={@space && @avatar}
      data-space-stage
      data-testid="space-stage"
      class="relative flex min-h-0 w-full flex-1 flex-col"
    >
      <%!-- The same picker as at the door, over the running map: the map keeps
            running underneath, so changing who you are is not leaving. --%>
      <.space_character_select
        :if={@changing_avatar}
        avatars={@avatars}
        selected={@avatar}
        roster={@roster}
        remember_key="space:last-avatar"
      >
        <:footer>
          <.button
            type="button"
            size="sm"
            variant="pixel-secondary"
            phx-click="space_change_cancel"
            data-testid="space-change-cancel"
          >
            <:icon><.pixel_icon name={:cancel} /></:icon>
            {dgettext("chat", "Cancel")}
          </.button>
        </:footer>
      </.space_character_select>
      <div
        id={@space.dom_id}
        phx-hook="SpaceCanvasHook"
        phx-update="ignore"
        data-testid="channel-space-shell"
        data-space-channel={@space.id}
        data-join-token={@join_token}
        data-nickname={@nickname}
        data-space-mode={@space.mode}
        data-avatar={@avatar}
        data-sprite-sheets={SpaceAssets.sheet_urls_json()}
        class="relative flex-1 min-h-0 w-full bg-canvas"
      >
        <%!-- Focusable so Esc in the line below can hand the keyboard back to
            the map. --%>
        <canvas
          id={"#{@space.dom_id}-canvas"}
          tabindex="-1"
          class={
            [
              "absolute inset-0 block h-full w-full outline-none",
              # Dragging a piece is a touch on the canvas, not a page scroll.
              @space.mode == "construct" && "touch-none"
            ]
          }
        >
        </canvas>
        <.space_virtual_pad />
        <.space_build_palette :if={@space.mode == "construct"} conversation={@space.parent.mode} />
        <%!-- A maximized window is still a window inside browser chrome. This is
            the only control that gets the tab bar and the address bar off an
            isometric map, so it stays on the one screen a space now has. --%>
        <.space_fullscreen_toggle />
        <div
          data-space-loading
          class="space-ui-veil absolute inset-0 z-20 flex items-center justify-center p-2"
          data-testid="space-loading"
        >
          <div
            class="space-ui-panel flex w-full max-w-sm flex-col items-center gap-2 text-center"
            role="status"
            aria-live="polite"
            aria-label={"#{loading_title(@space)}: #{loading_text(@space)}"}
            data-space-loading-panel
          >
            <.pixel_icon name={:loading} class="space-ui-hourglass" />
            <p class="space-ui-heading">{loading_title(@space)}</p>
            <p data-space-loading-text>{loading_text(@space)}</p>
          </div>
        </div>
        <%!-- What the bubbles say, in words, for whoever cannot see the canvas. --%>
        <div
          data-space-said
          data-ko-text={dgettext("chat", "%{name} is knocked out!", name: "%{name}")}
          data-getup-text={dgettext("chat", "%{name} is back on their feet.", name: "%{name}")}
          aria-live="polite"
          class="sr-only"
          data-testid="space-said"
        >
        </div>
        <%!-- A gate asks before it takes anyone anywhere; the question is
              carried here, translated, and drawn by the canvas when the
              server answers a use of the gate with a confirm modal. --%>
        <div
          data-space-modal
          hidden
          data-testid="space-modal"
          data-confirm-enter_construct={dgettext("chat", "Go into the Construct?")}
          data-confirm-exit_construct={dgettext("chat", "Go back to the End of Time?")}
          class="space-ui-panel absolute inset-0 z-30 m-auto h-fit w-fit max-w-[calc(100%-1rem)] text-center"
        >
        </div>
        <template data-space-confirm-template>
          <p data-space-modal-question class="space-ui-modal__title"></p>
          <div class="flex justify-center gap-2">
            <.button
              type="button"
              size="sm"
              variant="pixel"
              data-space-modal-yes
              data-testid="space-modal-yes"
            >
              <:icon><.pixel_icon name={:ok} /></:icon>
              {dgettext("chat", "Yes")}
            </.button>
            <.button
              type="button"
              size="sm"
              variant="pixel-secondary"
              data-space-modal-no
              data-testid="space-modal-no"
            >
              <:icon><.pixel_icon name={:cancel} /></:icon>
              {dgettext("chat", "No")}
            </.button>
          </div>
        </template>
        <.space_construct_panel :if={@space.mode == "construct"} />
      </div>
      <.space_say_bar
        id="space-say-input"
        canvas_id={"#{@space.dom_id}-canvas"}
        value={@say_draft}
        error={@say_error}
        placeholder={say_placeholder(@space, @nickname)}
      >
        <%!-- The way back comes along into fullscreen. On a phone it steps
              aside while the field is typed in (space-ui.css). --%>
        <:lead>
          <div class="space-ui-chip">
            <.back_to_chat
              open?={OpenSurfaces.open?(@open_surface_paths, Paths.chat_path())}
              testid="space-back-to-chat"
            />
          </div>
        </:lead>
        <:trail>
          <%!-- On a phone the face alone is the key; its name stays its label. --%>
          <button
            :if={@avatar}
            type="button"
            phx-click="space_change_character"
            class="space-ui-chip hover:underline"
            aria-label={dgettext("chat", "Change character")}
            title={dgettext("chat", "Change character")}
            data-testid="space-change-character"
          >
            <.nick_portrait avatar={@avatar} />
            <span class="space-say-bar__label">{dgettext("chat", "Change character")}</span>
          </button>
          <%!-- On a phone the count is the space's tower and a number; the
                sentence stays, for a screen reader. --%>
          <span class="space-ui-chip" data-testid="space-status-count">
            <.pixel_icon name={:space} class="space-say-bar__glyph" />
            <span class="space-say-bar__label">{count_text(@roster)}</span>
            <span class="space-say-bar__glyph" aria-hidden="true">{length(@roster)}</span>
          </span>
        </:trail>
      </.space_say_bar>
    </div>
    """
  end

  attr :roster, :list, required: true

  defp space_count(assigns) do
    ~H"""
    <span data-testid="space-status-count">{count_text(@roster)}</span>
    """
  end

  defp count_text(roster),
    do: dngettext("chat", "%{count} in the space", "%{count} in the space", length(roster))

  attr :message, :string, required: true

  # A refusal says what the policy said. A generic "not allowed" would make the
  # one thing the reader can act on the one thing the screen withholds.
  defp space_denied(assigns) do
    ~H"""
    <div class="space-ui-note m-2 flex h-fit items-start gap-2" data-testid="space-denied">
      <.pixel_icon name={:space} />
      <p class="min-w-0">{@message}</p>
    </div>
    """
  end

  @impl true
  @spec handle_event(String.t(), map(), Socket.t()) :: {:noreply, Socket.t()}
  # Inside, choosing again changes clothes rather than rooms: the canvas stays,
  # and the choice travels over the space's own channel, which swaps the
  # character for everyone standing there and remembers it for the nickname.
  def handle_event(
        "space_select_avatar",
        %{"avatar" => avatar},
        %{assigns: %{avatar: current}} = socket
      )
      when is_binary(current) do
    if avatar in socket.assigns.avatars do
      {:noreply,
       socket
       |> assign(avatar: avatar, last_avatar: avatar, changing_avatar: false)
       |> push_event("space_change_avatar", %{avatar: avatar})}
    else
      {:noreply, socket}
    end
  end

  # Choosing is entering: the token is minted here rather than at mount, so a
  # picker somebody left open for an hour does not hand the canvas an expired
  # one.
  def handle_event("space_select_avatar", %{"avatar" => avatar}, socket) do
    if avatar in socket.assigns.avatars and socket.assigns.space do
      # The choice outlives the visit now: the chat draws the same figure beside
      # this nickname, and a character that vanished when you walked out was a
      # costume rather than an identity.
      Avatars.remember(socket.assigns.nickname, avatar)

      {:noreply,
       assign(socket,
         avatar: avatar,
         last_avatar: avatar,
         join_token: join_token(socket, avatar)
       )}
    else
      {:noreply, socket}
    end
  end

  # What the browser remembered from a previous visit, offered before anything
  # is chosen — unless the nickname has a character of its own, which wins over
  # whatever this particular browser last clicked. Only a character this build
  # still has: a saved name that has since been removed would highlight nothing
  # and select nothing.
  def handle_event("space_remember_avatar", %{"avatar" => avatar}, socket) do
    if avatar in socket.assigns.avatars and is_nil(socket.assigns.avatar) and
         is_nil(socket.assigns.saved_avatar) do
      {:noreply, assign(socket, last_avatar: avatar)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("space_change_character", _params, %{assigns: %{avatar: avatar}} = socket)
      when is_binary(avatar) do
    {:noreply, assign(socket, changing_avatar: true)}
  end

  def handle_event("space_change_character", _params, socket), do: {:noreply, socket}

  def handle_event("space_change_cancel", _params, socket),
    do: {:noreply, assign(socket, changing_avatar: false)}

  # The viewport hook says the screen's size to whichever page mounts it. The
  # space lays nothing out on the server: the hook's CSS variables size the
  # page, so the report is acknowledged and nothing else.
  def handle_event("viewport_info", _params, socket), do: {:noreply, socket}

  # The draft is held here so a refused line stays in the field to be fixed,
  # and a sent one leaves it empty.
  def handle_event("space_say_change", %{"text" => text}, socket) do
    {:noreply, assign(socket, say_draft: text, say_error: nil)}
  end

  def handle_event("space_say", %{"text" => text}, %{assigns: %{space: %{} = space}} = socket) do
    case VirtualSpace.say(conversation(space), socket.assigns.nickname || "", text) do
      :ok -> {:noreply, assign(socket, say_draft: "", say_error: nil)}
      {:error, reason} -> {:noreply, assign(socket, say_draft: text, say_error: reason)}
    end
  end

  def handle_event("space_say", _params, socket), do: {:noreply, socket}

  # Minting is a deliberate act, not a side effect of opening a space: a link
  # per visit would fill the table with addresses nobody ever sent.
  def handle_event("share_space", _params, %{assigns: %{space: %{} = space}} = socket) do
    nickname = socket.assigns.nickname

    with user_id when is_integer(user_id) <- socket.assigns.user_id,
         {:ok, link} <-
           ShareLinks.create(%{
             kind: "space",
             target: %{"space_id" => space.id, "mode" => space.mode},
             creator_id: user_id,
             creator_nick: nickname
           }) do
      {:noreply, assign(socket, share_url: ShareLinkRef.url(link.slug), share_slug: link.slug)}
    else
      _unavailable -> {:noreply, socket}
    end
  end

  def handle_event("share_space", _params, socket), do: {:noreply, socket}

  # Closing the address without closing the room. `ShareLinks` asks its own
  # policy who may — the creator, or an operator of the channel the link leads
  # into — so a screen that offers the button is not the thing deciding.
  def handle_event("revoke_space", _params, %{assigns: %{share_slug: slug}} = socket)
      when is_binary(slug) do
    case ShareLinks.revoke(slug, socket.assigns.nickname || "") do
      {:ok, _link} -> {:noreply, assign(socket, share_url: nil, share_slug: nil)}
      _refused -> {:noreply, socket}
    end
  end

  def handle_event("revoke_space", _params, socket), do: {:noreply, socket}

  # Through a gate: the destination is this space's Construct, or from a
  # Construct the space it belongs to — read off the space this screen already
  # resolved, never off anything the client said.
  def handle_event(
        "space_portal",
        _params,
        %{assigns: %{space: %{} = space, avatar: avatar}} = socket
      )
      when is_binary(avatar) do
    destination =
      case space do
        %{mode: "construct", parent: parent} -> parent.id
        %{id: space_id} -> VirtualSpace.construct_id(space_id)
      end

    path = Paths.space_path(destination) <> "?" <> URI.encode_query(%{avatar: avatar})
    {:noreply, push_navigate(socket, to: path)}
  end

  def handle_event("space_portal", _params, socket), do: {:noreply, socket}

  # The canvas reports a hovered or right-clicked character to the LiveView that
  # owns its element, which is this one. What it means is a hover card and a
  # nick menu, and both of those read a chat session and draw over a
  # conversation — neither of which is here. Named rather than left to a
  # catch-all, so the day the canvas grows a fourth report it is a crash and not
  # a silence.
  def handle_event(event, _params, socket)
      when event in ~w(nick_hover nick_hover_dismiss nick_right_click) do
    {:noreply, socket}
  end

  @impl true
  @spec handle_info(term(), Socket.t()) :: {:noreply, Socket.t()}
  # The roster topic and only it: who is inside is the reason this surface
  # subscribes to anything at all.
  # The space's own list, or its Construct's saying it changed: a space counts
  # whoever is in its Construct too, so the list is read again rather than taken
  # from a message that only knows one of the two rooms.
  def handle_info({:space_roster, %{participants: participants}}, socket)
      when socket.assigns.space.mode == "construct" do
    {:noreply, assign(socket, roster: participants)}
  end

  def handle_info({:space_roster, _changed}, %{assigns: %{space: %{} = space}} = socket) do
    {:noreply, assign(socket, roster: VirtualSpace.roster(space.id))}
  end

  defp subscribe_to_roster(socket, space) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.space_roster(space.id))
    end

    socket
  end

  # The token binds this nickname to this space, and the channel verifies it
  # before touching the runtime. Which process signs it moved here; the token
  # itself did not change, and `SpaceChannel` did not either.
  defp join_token(%{assigns: %{space: %{mode: "direct_message"} = space}} = socket, _avatar) do
    ChannelJoinToken.sign_direct_message(
      space.id,
      socket.assigns.user_id,
      socket.assigns.nickname,
      space.participants
    )
  end

  defp join_token(%{assigns: %{space: %{mode: "construct"} = space}} = socket, _avatar) do
    ChannelJoinToken.sign_construct(
      space.id,
      socket.assigns.user_id,
      socket.assigns.nickname,
      space.participants
    )
  end

  defp join_token(%{assigns: %{space: space}} = socket, _avatar) do
    ChannelJoinToken.sign(space.id, socket.assigns.user_id, socket.assigns.nickname)
  end

  # Arriving through a gate, the character is already chosen: the address
  # names it, and an id this build does not have leaves the picker up.
  defp walk_through(socket, avatar) when is_binary(avatar) do
    if avatar in socket.assigns.avatars do
      assign(socket, avatar: avatar, last_avatar: avatar, join_token: join_token(socket, avatar))
    else
      socket
    end
  end

  defp walk_through(socket, _avatar), do: socket

  defp saved_avatar(nickname) when is_binary(nickname) and nickname != "" do
    avatar = Avatars.for_nick(nickname)
    if avatar in VirtualSpace.avatars(), do: avatar
  end

  defp saved_avatar(_nickname), do: nil

  defp user_id(nickname) when is_binary(nickname) and nickname != "" do
    case SessionHelpers.resolve_user_id(nickname) do
      {:ok, user_id} -> user_id
      _unregistered -> nil
    end
  end

  defp user_id(_nickname), do: nil

  # The address is all there is, so every gate runs here — and the refusal says
  # which door was shut.
  defp resolve_space(socket, %{"slug" => slug}, _session) do
    with {:ok, space_id} <- decode_slug(slug),
         {:ok, space} <- build_space(space_id),
         :ok <- allowed?(space, socket.assigns.nickname) do
      {:ok, space}
    end
  end

  defp resolve_space(_socket, _params, _session),
    do: {:error, dgettext("chat", "This space is no longer available.")}

  defp decode_slug(slug) do
    case SpaceRef.space_id(slug) do
      {:ok, space_id} -> {:ok, space_id}
      :error -> {:error, dgettext("chat", "That address does not name a space.")}
    end
  end

  defp build_space(space_id) do
    case VirtualSpace.space_kind(space_id) do
      :channel ->
        {:ok, space(space_id, "channel", nil)}

      :direct_message ->
        case SpaceRef.participants(space_id) do
          {:ok, participants} ->
            {:ok, space(space_id, "direct_message", DirectMessageSpace.as_shown(participants))}

          :error ->
            {:error, dgettext("chat", "That address does not name a space.")}
        end

      # A Construct is everything its space is — who may enter, where a line
      # said inside goes — at an address of its own.
      :construct ->
        with {:ok, parent_id} <- construct_parent(space_id),
             {:ok, parent} <- build_space(parent_id) do
          {:ok,
           space_id
           |> space("construct", parent.participants)
           |> Map.put(:parent, parent)}
        end
    end
  end

  defp construct_parent(space_id) do
    case VirtualSpace.construct_parent(space_id) do
      {:ok, parent_id} -> {:ok, parent_id}
      :error -> {:error, dgettext("chat", "That address does not name a space.")}
    end
  end

  # The same two doors the space's own channel checks at join, asked one screen
  # earlier so the refusal is a sentence rather than a canvas that never boots.
  defp allowed?(%{mode: "construct", parent: parent}, nickname), do: allowed?(parent, nickname)

  defp allowed?(%{mode: "direct_message", participants: participants}, nickname) do
    if DirectMessageSpace.member?(participants, nickname || "") do
      :ok
    else
      {:error, dgettext("chat", "This private space belongs to two other people.")}
    end
  end

  # The refusal names the channel only when a stranger could have listed it
  # anyway. The address already carries the id, but that is an encoding nobody
  # reads by accident — a sentence on screen is the product saying it out loud,
  # and a secret channel's name is the one thing this refusal must not be the
  # place somebody learns. Same rule the shared card applies, same function.
  defp allowed?(%{mode: "channel", id: channel_name}, nickname) do
    cond do
      channel_member?(channel_name, nickname) ->
        :ok

      Visibility.nameable?(channel_name) ->
        {:error,
         dgettext("chat", "You have to be in %{channel} to enter its space.",
           channel: channel_name
         )}

      true ->
        {:error, dgettext("chat", "This space belongs to a channel you are not in.")}
    end
  end

  # The members of a channel are a list of `{nickname, role}`, and the space
  # keys its participants by the downcased nickname — so the comparison is the
  # one the space itself will make when the canvas joins.
  defp channel_member?(channel_name, nickname) when is_binary(nickname) do
    target = Nickname.key(nickname)

    case Server.get_state(channel_name) do
      {:ok, %{members: members}} ->
        Enum.any?(members, fn {member, _role} -> Nickname.key(member) == target end)

      _absent ->
        false
    end
  end

  defp channel_member?(_channel_name, _nickname), do: false

  defp space(space_id, mode, participants) do
    %{
      id: space_id,
      mode: mode,
      participants: normalize_participants(participants),
      dom_id: SpaceRef.dom_id(space_id)
    }
  end

  defp normalize_participants(participants) when is_list(participants) do
    case DirectMessageSpace.normalize_participants(participants) do
      {:ok, participants} -> participants
      {:error, :invalid_participants} -> nil
    end
  end

  defp normalize_participants(_participants), do: nil

  # The Construct's name is the glossary's label, joined to the space's name
  # the way the tab title joins it, rather than a sentence for the engine.
  defp window_title(%{mode: "construct", parent: parent}),
    do: dgettext("chat", "Construct") <> " · " <> space_name(parent)

  defp window_title(%{mode: "direct_message", participants: participants})
       when is_list(participants),
       do: dgettext("chat", "Space · %{name}", name: Enum.join(participants, " + "))

  defp window_title(%{id: space_id}), do: dgettext("chat", "Space · %{name}", name: space_id)

  defp window_title(_absent), do: dgettext("chat", "Space")

  defp space_name(%{mode: "direct_message", participants: participants})
       when is_list(participants),
       do: Enum.join(participants, " + ")

  defp space_name(%{id: space_id}), do: space_id

  defp conversation(%{mode: "construct", parent: parent}), do: conversation(parent)

  defp conversation(%{mode: "direct_message", participants: participants}),
    do: {:direct_message, participants || []}

  defp conversation(%{id: channel_name}), do: {:channel, channel_name}

  # Who will read the line: the channel, or the one other person in a private
  # space.
  defp say_placeholder(%{mode: "construct", parent: parent}, nickname),
    do: say_placeholder(parent, nickname)

  defp say_placeholder(%{mode: "direct_message", participants: participants}, nickname)
       when is_list(participants) do
    me = Nickname.key(nickname || "")

    case Enum.reject(participants, &(Nickname.key(&1) == me)) do
      [peer] -> dgettext("chat", "Say something to %{name}...", name: peer)
      _absent -> dgettext("chat", "Say something...")
    end
  end

  defp say_placeholder(%{id: channel_name}, _nickname),
    do: dgettext("chat", "Say something to %{name}...", name: channel_name)

  defp loading_title(%{mode: "construct"}), do: dgettext("chat", "Construct")
  defp loading_title(%{mode: "direct_message"}), do: dgettext("chat", "Private Space")
  defp loading_title(_space), do: dgettext("chat", "Channel Space")

  defp loading_text(%{mode: "construct"}), do: dgettext("chat", "Loading the Construct...")
  defp loading_text(%{mode: "direct_message"}), do: dgettext("chat", "Opening private room...")
  defp loading_text(_space), do: dgettext("chat", "Entering channel space...")

  # Only a registered nickname can mint a link: the record carries who made it,
  # and a link nobody is accountable for is one nobody can be asked about.
  defp sharable?(user_id), do: is_integer(user_id)
end
