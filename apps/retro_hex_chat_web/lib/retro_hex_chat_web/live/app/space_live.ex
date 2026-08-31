defmodule RetroHexChatWeb.App.SpaceLive do
  @moduledoc """
  A virtual space, as a surface of its own.

  One module, two mounts: this is the page at `/space/:slug` and it is also the
  Space view of a conversation in the chat. Nothing about a space is written
  twice — the difference between the two is where the process hangs, not what
  it does.

  The space is the one feature here that was never a window: inside the chat it
  takes the conversation's own region, behind a tab beside it, and that does not
  change. What changes is which process owns the canvas: the isometric renderer
  is the largest chunk in the app and runs a continuous render loop, and in a
  tab of its own it stops sharing a main thread with the chat's message stream.

  Two states, and you always arrive at the first: the **antechamber**, which is
  the character picker that was always there, and **inside**. There is no host
  and no `[Start]`, because a space does not begin or end — it is a place, and
  the address of a place stays good.

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
        embedded?: session["embedded"] == true,
        nickname: session["nickname"] || socket.assigns[:surface_nickname],
        avatars: VirtualSpace.avatars(),
        avatar: nil,
        # The character you picked last time. In the chat the host holds it,
        # because this LiveView is mounted fresh every time the tab is opened
        # and a memory kept in here would not survive its own screen.
        last_avatar: last_avatar(session),
        join_token: nil,
        roster: [],
        share_url: nil,
        space: nil,
        denied: nil
      )

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
  def render(%{embedded?: true} = assigns) do
    ~H"""
    <div class="relative flex min-h-0 w-full flex-1">
      <.space_body {assigns} />
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <%!-- The same shell every other desktop screen uses: the workspace only
          has a height because something above it does. --%>
    <div class="bg-background text-text font-system flex h-screen flex-col">
      <%!-- This tab answers when the chat asks for it by address. Only in the
            standalone render: embedded, the address is the chat's own and the
            chat already answers for it. --%>
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
          <%!-- The way back is always on screen, in both states. Someone who
                arrived from a shared link has no chat tab behind this one, so
                it is a link and not a focus request — deciding between the two
                needs to know what else the person has open, which is a later
                wave. --%>
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

  # The chat renders this same LiveView into its conversation region, so the
  # body is shared and the chrome is not.
  defp space_body(assigns) do
    ~H"""
    <.space_denied :if={@denied} message={@denied} />

    <.space_character_select
      :if={@space && is_nil(@avatar)}
      avatars={@avatars}
      selected={@last_avatar}
      roster={@roster}
    >
      <:footer>
        <%!-- The invitation is made at the door: a bar over the map would
              take pixels from the thing the person came for, and the picker is
              the one screen both hosts show every single time. --%>
        <.share_bar
          url={@share_url}
          available={sharable?(@nickname)}
          on_share="share_space"
          class="min-w-0 flex-1 justify-start"
        />
        <.surface_tab_link
          :if={@embedded?}
          path={Paths.space_path(@space.id)}
          open?={OpenSurfaces.open?(@open_surface_paths, Paths.space_path(@space.id))}
          testid="space-open-in-tab"
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
      <%!-- In a tab of its own the page is already the space, so a second way
            to fill the screen is one control too many. --%>
      <.space_fullscreen_toggle :if={@embedded?} />
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
       socket
       |> assign(avatar: avatar, last_avatar: avatar, join_token: join_token(socket, avatar))
       |> remember_avatar(avatar)}
    else
      {:noreply, socket}
    end
  end

  # Minting is a deliberate act, not a side effect of opening a space: a link
  # per visit would fill the table with addresses nobody ever sent.
  def handle_event("share_space", _params, %{assigns: %{space: %{} = space}} = socket) do
    nickname = socket.assigns.nickname

    with {:ok, user_id} <- SessionHelpers.resolve_user_id(nickname || ""),
         {:ok, link} <-
           ShareLinks.create(%{
             kind: "space",
             target: %{"space_id" => space.id, "mode" => space.mode},
             creator_id: user_id,
             creator_nick: nickname
           }) do
      {:noreply, assign(socket, share_url: ShareLinkRef.url(link.slug))}
    else
      _unavailable -> {:noreply, socket}
    end
  end

  def handle_event("share_space", _params, socket), do: {:noreply, socket}

  # The canvas reports a hovered or right-clicked character to whichever
  # LiveView owns its element, which is this one in both mounts. What it means
  # is a hover card and a nick menu, and both are the chat's: they read a chat
  # session and they draw over the conversation. Embedded, the chat is the
  # parent and gets them; standalone there is no conversation to draw them in,
  # and the person is one click from the chat that has them.
  def handle_event(event, params, socket)
      when event in ~w(nick_hover nick_hover_dismiss nick_right_click) do
    if socket.assigns.embedded? do
      send(socket.parent_pid, {:space_surface_event, event, params})
    end

    {:noreply, socket}
  end

  @impl true
  @spec handle_info(term(), Socket.t()) :: {:noreply, Socket.t()}
  # The roster topic and only it: who is inside is the reason this surface
  # subscribes to anything at all.
  def handle_info({:space_roster, %{participants: participants}}, socket) do
    {:noreply, assign(socket, roster: participants)}
  end

  defp remember_avatar(%{assigns: %{embedded?: true}} = socket, avatar) do
    send(socket.parent_pid, {:space_surface_avatar, avatar})
    socket
  end

  defp remember_avatar(socket, _avatar), do: socket

  defp subscribe_to_roster(socket, space) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.space_roster(space.id))
    end

    socket
  end

  defp last_avatar(session) do
    case session["last_avatar"] do
      avatar when is_binary(avatar) -> avatar
      _absent -> hd(VirtualSpace.avatars())
    end
  end

  # The token binds this nickname to this space, and the channel verifies it
  # before touching the runtime. Which process signs it moved here; the token
  # itself did not change, and `SpaceChannel` did not either.
  defp join_token(%{assigns: %{space: %{mode: "direct_message"} = space}} = socket, _avatar) do
    ChannelJoinToken.sign_direct_message(
      space.id,
      nil,
      socket.assigns.nickname,
      space.participants
    )
  end

  defp join_token(%{assigns: %{space: space}} = socket, _avatar) do
    ChannelJoinToken.sign(space.id, nil, socket.assigns.nickname)
  end

  # Embedded, the chat already decided which conversation is in focus and the
  # surface is handed the answer. Standalone, the address is all there is, so
  # every gate runs here — and the refusal says which door was shut.
  defp resolve_space(%{assigns: %{embedded?: true}}, _params, session) do
    case {session["space_id"], session["mode"]} do
      {space_id, mode} when is_binary(space_id) and mode in ["channel", "direct_message"] ->
        {:ok, space(space_id, mode, session["participants"])}

      _incomplete ->
        {:error, dgettext("chat", "This space is no longer available.")}
    end
  end

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
  defp sharable?(nickname) when is_binary(nickname) and nickname != "" do
    match?({:ok, _id}, SessionHelpers.resolve_user_id(nickname))
  end

  defp sharable?(_nickname), do: false
end
