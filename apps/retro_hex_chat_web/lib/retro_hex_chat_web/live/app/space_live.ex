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
  """
  use RetroHexChatWeb, :live_view

  import RetroHexChatWeb.Components.UI.ActivityIndicator
  import RetroHexChatWeb.Components.UI.Desktop
  import RetroHexChatWeb.Components.UI.ShareBar
  import RetroHexChatWeb.Components.UI.SpaceCharacterSelect
  import RetroHexChatWeb.Components.UI.SpaceFullscreenToggle
  import RetroHexChatWeb.Components.UI.SpaceVirtualPad
  import RetroHexChatWeb.Components.UI.SurfaceTabLink
  import RetroHexChatWeb.Components.UI.Window

  alias Phoenix.LiveView.Socket
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Channels.Visibility
  alias RetroHexChat.ShareLinks
  alias RetroHexChat.Topics
  alias RetroHexChat.VirtualSpace
  alias RetroHexChat.VirtualSpace.ChannelJoinToken
  alias RetroHexChat.VirtualSpace.DirectMessageSpace
  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.App.SessionHelpers
  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.Live.OpenSurfaces
  alias RetroHexChatWeb.ShareLinkRef
  alias RetroHexChatWeb.SpaceAssets
  alias RetroHexChatWeb.SpaceRef

  @impl true
  @spec mount(map(), map(), Socket.t()) :: {:ok, Socket.t()}
  def mount(params, session, socket) do
    socket =
      assign(socket,
        nickname: session["nickname"] || socket.assigns[:surface_nickname],
        avatars: VirtualSpace.avatars(),
        avatar: nil,
        # The character you picked last time, until the browser that picked it
        # says otherwise. This LiveView is mounted fresh for every visit, so the
        # memory cannot live in here — it lives where the person does.
        last_avatar: hd(VirtualSpace.avatars()),
        join_token: nil,
        roster: [],
        share_url: nil,
        share_slug: nil,
        space: nil,
        denied: nil
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
         |> assign(roster: VirtualSpace.roster(space.id))}

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
    <div class="bg-background text-text font-system flex h-screen flex-col">
      <%!-- This tab answers when the chat asks for it by address. --%>
      <div id="surface-presence" phx-hook="SurfacePresenceHook" class="hidden"></div>
      <.desktop id="space-desktop" persist_key="space" class="flex-1" data-testid="space-desktop">
        <.desktop_window
          id="virtual-space"
          title={window_title(@space)}
          pinned
          default_maximized
          body_class="h-full min-h-0 overflow-hidden p-1"
          data-testid="virtual-space-window"
        >
          <:icon><Icons.icon_community class="h-4 w-4" /></:icon>
          <%!-- The way back is always on screen, in both states. --%>
          <:status>
            <.window_status_bar_field grow>
              <.back_to_chat
                open?={OpenSurfaces.open?(@open_surface_paths, Paths.chat_path())}
                testid="space-back-to-chat"
              />
            </.window_status_bar_field>
            <.window_status_bar_field>
              <span data-testid="space-status-count">
                {dngettext(
                  "chat",
                  "%{count} in the space",
                  "%{count} in the space",
                  length(@roster)
                )}
              </span>
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
        <.share_bar
          url={@share_url}
          available={sharable?(@user_id)}
          on_share="share_space"
          on_revoke="revoke_space"
          class="min-w-0 flex-1 justify-start"
        />
      </:footer>
    </.space_character_select>

    <div
      :if={@space && @avatar}
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
      <canvas id={"#{@space.dom_id}-canvas"} class="absolute inset-0 block h-full w-full"></canvas>
      <.space_virtual_pad />
      <%!-- A maximized window is still a window inside browser chrome. This is
            the only control that gets the tab bar and the address bar off an
            isometric map, so it stays on the one screen a space now has. --%>
      <.space_fullscreen_toggle />
      <div
        data-space-loading
        class="absolute inset-0 z-20 flex items-center justify-center bg-background/95"
        data-testid="space-loading"
      >
        <.boot_activity_panel
          title={loading_title(@space)}
          text={loading_text(@space)}
          icon={if @space.mode == "direct_message", do: :p2p, else: :channels}
          class="w-full max-w-sm"
          data-space-loading-panel
          text_attrs={%{"data-space-loading-text" => ""}}
        />
      </div>
      <div
        data-space-modal
        hidden
        class="absolute inset-0 m-auto h-fit w-fit bg-canvas shadow-retro-field p-3 text-center"
      >
      </div>
    </div>
    """
  end

  attr :message, :string, required: true

  # A refusal says what the policy said. A generic "not allowed" would make the
  # one thing the reader can act on the one thing the screen withholds.
  defp space_denied(assigns) do
    ~H"""
    <div
      class="m-2 flex h-fit items-start gap-2 border border-border bg-canvas p-2 text-xs shadow-retro-sunken"
      data-testid="space-denied"
    >
      <span class="flex h-8 w-8 shrink-0 items-center justify-center bg-surface shadow-retro-sunken">
        <Icons.icon_community class="h-4 w-4" />
      </span>
      <p class="min-w-0">{@message}</p>
    </div>
    """
  end

  @impl true
  @spec handle_event(String.t(), map(), Socket.t()) :: {:noreply, Socket.t()}
  # Choosing is entering: the token is minted here rather than at mount, so a
  # picker somebody left open for an hour does not hand the canvas an expired
  # one.
  def handle_event("space_select_avatar", %{"avatar" => avatar}, socket) do
    if avatar in socket.assigns.avatars and socket.assigns.space do
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
  # is chosen. Only a character this build still has: a saved name that has
  # since been removed would highlight nothing and select nothing.
  def handle_event("space_remember_avatar", %{"avatar" => avatar}, socket) do
    if avatar in socket.assigns.avatars and is_nil(socket.assigns.avatar) do
      {:noreply, assign(socket, last_avatar: avatar)}
    else
      {:noreply, socket}
    end
  end

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
  def handle_info({:space_roster, %{participants: participants}}, socket) do
    {:noreply, assign(socket, roster: participants)}
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

  defp join_token(%{assigns: %{space: space}} = socket, _avatar) do
    ChannelJoinToken.sign(space.id, socket.assigns.user_id, socket.assigns.nickname)
  end

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
          {:ok, participants} -> {:ok, space(space_id, "direct_message", participants)}
          :error -> {:error, dgettext("chat", "That address does not name a space.")}
        end
    end
  end

  # The same two doors the space's own channel checks at join, asked one screen
  # earlier so the refusal is a sentence rather than a canvas that never boots.
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
    target = String.downcase(nickname)

    case Server.get_state(channel_name) do
      {:ok, %{members: members}} ->
        Enum.any?(members, fn {member, _role} -> String.downcase(member) == target end)

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

  defp window_title(%{mode: "direct_message", participants: participants})
       when is_list(participants),
       do: dgettext("chat", "Space · %{name}", name: Enum.join(participants, " + "))

  defp window_title(%{id: space_id}), do: dgettext("chat", "Space · %{name}", name: space_id)

  defp window_title(_absent), do: dgettext("chat", "Space")

  defp loading_title(%{mode: "direct_message"}), do: dgettext("chat", "Private Space")
  defp loading_title(_space), do: dgettext("chat", "Channel Space")

  defp loading_text(%{mode: "direct_message"}), do: dgettext("chat", "Opening private room...")
  defp loading_text(_space), do: dgettext("chat", "Entering channel space...")

  # Only a registered nickname can mint a link: the record carries who made it,
  # and a link nobody is accountable for is one nobody can be asked about.
  defp sharable?(user_id), do: is_integer(user_id)
end
