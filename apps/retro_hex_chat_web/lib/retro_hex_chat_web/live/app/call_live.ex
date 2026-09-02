defmodule RetroHexChatWeb.App.CallLive do
  @moduledoc """
  A channel conference, as a surface of its own.

  One mount and one door: this is the page at `/call/:token`, and the only way
  to it is the card the chat wrote into the conversation when the room was
  opened. The chat draws a badge and a status zone about a call it does not
  host and cannot reach — everything else about a conference is here.

  Two states, and you always arrive at the first: the **antechamber**, where
  you see who is already in the room and choose how you walk in, and **inside**.
  There is no host and no `[Start]` — a channel call has no owner, any member
  opens one and anyone joins whenever they like, and a gate here would be a
  regression dressed as a feature.

  Both states are decided in `mount/3`. Initial data delivered after the first
  render is invisible to ExUnit and only ever caught in a browser.
  """
  use RetroHexChatWeb, :live_view

  import RetroHexChatWeb.Components.UI.Desktop
  import RetroHexChatWeb.Components.UI.GroupCall.Panel
  import RetroHexChatWeb.Components.UI.GroupCall.PreJoin
  import RetroHexChatWeb.Components.UI.ShareBar
  import RetroHexChatWeb.Components.UI.SurfaceTabLink
  import RetroHexChatWeb.Components.UI.Window

  alias Phoenix.LiveView.Socket
  alias RetroHexChat.Channels.Membership
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Chat.KeyBindings
  alias RetroHexChat.GroupCall
  alias RetroHexChat.Services.NickServ
  alias RetroHexChat.ShareLinks
  alias RetroHexChat.Topics
  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.App.SessionHelpers
  alias RetroHexChatWeb.CallLive.Events
  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.Live.GroupCallConfirmDialog
  alias RetroHexChatWeb.Live.OpenSurfaces
  alias RetroHexChatWeb.ShareLinkRef

  # The shortcuts this page answers. Everything else the binding table knows is
  # the chat's, and reaches nothing here.
  @call_actions [
    :group_call_toggle_audio,
    :group_call_toggle_video,
    :group_call_leave,
    :group_call_layout_next,
    :group_call_focus_next
  ]

  @impl true
  @spec mount(map(), map(), Socket.t()) :: {:ok, Socket.t()}
  def mount(params, session, socket) do
    socket =
      assign(socket,
        nickname: session["nickname"] || socket.assigns[:surface_nickname],
        # The device preference is the person's, not the screen's: the same
        # terminal that remembered a camera for the chat's pre-join has to hand
        # it to the surface that replaced it.
        trusted_device_id: session["trusted_device_id"] || socket.assigns[:trusted_device_id],
        channel_name: nil,
        group_call: nil,
        group_call_prejoin: nil,
        group_call_pending: nil,
        group_call_prejoin_preferences:
          Events.restored_prejoin_preferences(session["prejoin_preferences"]),
        prejoin_roster: [],
        notice: nil,
        share_url: nil,
        share_slug: nil,
        denied: nil,
        surface_left: false
      )

    socket = OpenSurfaces.attach(socket, socket.assigns.nickname)

    case resolve_room(socket, params, session) do
      {:ok, channel_name, user_id} ->
        {:ok,
         socket
         |> push_event("update_bindings", %{
           bindings: KeyBindings.to_persistable(KeyBindings.defaults())
         })
         |> assign(channel_name: channel_name)
         |> subscribe_to_room(channel_name)
         |> Events.mount_call(channel_name, user_id)}

      {:error, message} ->
        {:ok, assign(socket, denied: message)}
    end
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <%!-- The same shell every other desktop screen uses: the workspace only
          has a height because something above it does. The conference
          shortcuts are bound here because this is where the keystroke lands
          now that the call has a page instead of a window in the chat. --%>
    <div class="bg-background text-text font-system flex h-screen flex-col">
      <%!-- The same dispatcher the chat mounts, for the same reason: it reads
            the real keyboard event and pushes the action, which is the only way
            a Ctrl+Shift binding can be matched at all. --%>
      <div id="shortcut-dispatcher-hook" phx-hook="ShortcutDispatcherHook" class="hidden"></div>
      <%!-- This tab answers when another tab of this person's asks for it by
            address, which is what lets a second click go to the call they
            already have open instead of opening a second one. --%>
      <div id="surface-presence" phx-hook="SurfacePresenceHook" class="hidden"></div>
      <.desktop id="call-desktop" persist_key="call" class="flex-1" data-testid="call-desktop">
        <.desktop_window
          id="group-call"
          title={@channel_name || dgettext("group_call", "Group Call")}
          pinned
          default_maximized
          body_class="h-full min-h-0 overflow-hidden p-1"
          data-testid="group-call-window"
        >
          <:icon><Icons.icon_protocol_conference_compact class="h-4 w-4" /></:icon>
          <:meta><.conference_title_meta call={@group_call} /></:meta>
          <%!-- The way back is always on screen, in both states. Someone who
                arrived from a shared link has no chat tab behind this one, so
                it is a link and not a focus request — deciding between the two
                needs to know what else the person has open, which is a later
                wave. --%>
          <:status>
            <.window_status_bar_field grow>
              <.back_to_chat
                open?={OpenSurfaces.open?(@open_surface_paths, Paths.chat_path())}
                testid="call-back-to-chat"
              />
            </.window_status_bar_field>
            <.window_status_bar_field :if={@notice}>
              <span data-testid="call-notice">{@notice.message}</span>
            </.window_status_bar_field>
          </:status>
          <.call_body {assigns} />
        </.desktop_window>
      </.desktop>
    </div>
    """
  end

  # Split from the chrome around it so the two states — antechamber and inside —
  # read as one thing, and the window that frames them as another.
  defp call_body(assigns) do
    ~H"""
    <div class="flex h-full min-h-0 flex-col">
      <.call_denied :if={@denied} message={@denied} />
      <.call_left :if={@surface_left} channel={@channel_name} />

      <.group_call_pre_join_panel
        :if={@group_call_prejoin && !@surface_left}
        id="group-call-prejoin"
        class="min-h-0 flex-1"
        prejoin={@group_call_prejoin}
        participants={@prejoin_roster}
        on_cancel="group_call_prejoin_cancel"
      />

      <div :if={@group_call && !@surface_left} class="flex h-full min-h-0 flex-col gap-1">
        <%!-- Minting is a deliberate act, not a side effect of opening a call:
              a link per window opened would fill the table with addresses
              nobody ever sent. --%>
        <.share_bar
          url={@share_url}
          available={sharable?(@nickname)}
          on_share="share_call"
          on_revoke="revoke_call"
          class="shrink-0 justify-end border border-border bg-surface p-1 shadow-retro-raised"
        />
        <div class="min-h-0 flex-1">
          <.group_call_panel id="group-call-panel-surface" call={@group_call} />
        </div>
      </div>

      <.live_component
        module={GroupCallConfirmDialog}
        id={GroupCallConfirmDialog.id()}
        scope={:window}
      />
    </div>
    """
  end

  attr :channel, :string, default: nil

  # Leaving a conference leaves its page and stops there. Navigating to the chat
  # from here would mount a second chat session, and a second chat session ends
  # the first — so somebody who backed out of the antechamber lost the chat they
  # had open in another tab and never asked to leave.
  defp call_left(assigns) do
    ~H"""
    <div
      class="m-2 flex items-start gap-2 border border-border bg-canvas p-2 text-xs shadow-retro-sunken"
      data-testid="call-left"
    >
      <span class="flex h-8 w-8 shrink-0 items-center justify-center bg-surface shadow-retro-sunken">
        <Icons.icon_protocol_conference_compact class="h-4 w-4" />
      </span>
      <div class="min-w-0 space-y-1">
        <p>
          {if @channel,
            do: dgettext("group_call", "You left the conference in %{channel}.", channel: @channel),
            else: dgettext("group_call", "You left the conference.")}
        </p>
        <%!-- No second way back: `← Chat` is already along the bottom of this
              window, in both states, and it is the one that knows how to reach
              a chat tab that is already open instead of opening another. --%>
        <p class="text-muted-foreground">
          {dgettext("group_call", "This tab is finished. The room is still at this address.")}
        </p>
      </div>
    </div>
    """
  end

  attr :message, :string, required: true

  # A refusal says what the policy said. A generic "not allowed" would make the
  # one thing the reader can act on the one thing the screen withholds.
  defp call_denied(assigns) do
    ~H"""
    <div
      class="m-2 flex items-start gap-2 border border-border bg-canvas p-2 text-xs shadow-retro-sunken"
      data-testid="call-denied"
    >
      <span class="flex h-8 w-8 shrink-0 items-center justify-center bg-surface shadow-retro-sunken">
        <Icons.icon_protocol_conference_compact class="h-4 w-4" />
      </span>
      <p class="min-w-0">{@message}</p>
    </div>
    """
  end

  @impl true
  @spec handle_event(String.t(), map(), Socket.t()) :: {:noreply, Socket.t()}
  def handle_event("share_call", _params, %{assigns: %{group_call: %{token: token}}} = socket)
      when is_binary(token) do
    nickname = socket.assigns.nickname

    with {:ok, user_id} <- SessionHelpers.resolve_user_id(nickname || ""),
         {:ok, link} <-
           ShareLinks.create(%{
             kind: "call",
             target: %{"room_token" => token},
             creator_id: user_id,
             creator_nick: nickname
           }) do
      {:noreply, assign(socket, share_url: ShareLinkRef.url(link.slug), share_slug: link.slug)}
    else
      _unavailable -> {:noreply, socket}
    end
  end

  def handle_event("share_call", _params, socket), do: {:noreply, socket}

  # Closing the address without closing the room. `ShareLinks` asks its own
  # policy who may — the creator, or an operator of the channel the link leads
  # into — so a screen that offers the button is not the thing deciding.
  def handle_event("revoke_call", _params, %{assigns: %{share_slug: slug}} = socket)
      when is_binary(slug) do
    case ShareLinks.revoke(slug, socket.assigns.nickname || "") do
      {:ok, _link} -> {:noreply, assign(socket, share_url: nil, share_slug: nil)}
      _refused -> {:noreply, socket}
    end
  end

  def handle_event("revoke_call", _params, socket), do: {:noreply, socket}

  # The conference shortcuts were bound on the chat's window while the call was
  # rendered inside it, and the chat forwarded them here. The call has its own
  # page now, so the keystroke lands here — through the same dispatcher the chat
  # uses, and for the reason that dispatcher exists at all: LiveView's own
  # `phx-window-keydown` payload carries the key and **not the modifiers**, so a
  # binding table keyed on Ctrl+Shift can never match it. Measured in the
  # browser: `%{"key" => "ArrowUp"}` arrived, and nothing else.
  def handle_event("shortcut_action", %{"action" => action}, socket) do
    case safe_action(action) do
      nil -> {:noreply, socket}
      resolved -> apply_shortcut(socket, resolved)
    end
  end

  def handle_event(event, params, socket) do
    {_halted, socket} = Events.handle_event(event, params, socket)
    {:noreply, socket}
  end

  # Only the conference's own shortcuts act here. Everything else the binding
  # table knows belongs to the chat and reaches nothing on this page.
  defp apply_shortcut(socket, action) when action in @call_actions do
    {_halted, socket} = Events.handle_event(Atom.to_string(action), %{}, socket)
    {:noreply, socket}
  end

  defp apply_shortcut(socket, _action), do: {:noreply, socket}

  defp safe_action(action) when is_binary(action) do
    String.to_existing_atom(action)
  rescue
    ArgumentError -> nil
  end

  defp safe_action(_action), do: nil

  @impl true
  @spec handle_info(term(), Socket.t()) :: {:noreply, Socket.t()}
  # The room's own topic, and only it: the antechamber's roster is the reason
  # this surface subscribes to anything at all.
  def handle_info({:group_call_started, payload}, socket) do
    {:noreply, apply_room_broadcast(socket, payload)}
  end

  def handle_info({:group_call_updated, payload}, socket) do
    {:noreply, apply_room_broadcast(socket, payload)}
  end

  def handle_info({:group_call_ended, _payload}, socket) do
    {:noreply, Events.refresh_roster(socket)}
  end

  # Being removed from a conference has to end the page you are removed from,
  # and the room's broadcast is the only thing that says so. Without this the
  # person sits in a conference they are no longer in, and nothing anywhere
  # says otherwise.
  def handle_info(
        {:group_call_moderation, %{action: :participant_kicked, target: target}},
        %{assigns: %{nickname: nickname}} = socket
      )
      when is_binary(target) and is_binary(nickname) do
    if String.downcase(target) == String.downcase(nickname) do
      {:noreply, Events.leave(socket, "kicked")}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:group_call_moderation, _payload}, socket) do
    {:noreply, socket}
  end

  # The membership the call stands on is gone — a `/part`, a kick, a ban. The
  # room may still hold a seat and the chat has already given it up; what is
  # left is this screen, which cannot stay in a conference for a channel this
  # person is no longer in.
  def handle_info(
        {:channel_membership_lost, %{nickname: target, reason: reason}},
        %{assigns: %{nickname: nickname}} = socket
      )
      when is_binary(target) and is_binary(nickname) do
    if String.downcase(target) == String.downcase(nickname) do
      {:noreply, Events.leave(socket, reason)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:channel_membership_lost, _payload}, socket), do: {:noreply, socket}

  defp apply_room_broadcast(socket, payload) do
    socket
    |> Events.refresh_roster()
    |> Events.apply_summary(Map.get(payload, :channel), Map.get(payload, :summary))
  end

  defp subscribe_to_room(socket, channel_name) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.channel_calls(channel_name))
    end

    socket
  end

  # The token in the address is all there is, so every gate runs here — and the
  # refusal is the policy's own sentence, because that is the part the reader
  # can act on.
  defp resolve_room(socket, %{"token" => token}, _session) when is_binary(token) do
    nickname = socket.assigns.nickname

    with {:ok, room} <- fetch_room(token),
         :ok <- require_identified(nickname),
         {:ok, user_id} <- require_registered(nickname),
         membership <- channel_membership(room.channel_name),
         :ok <- GroupCall.Policy.can_join?(user_id, nickname, room, membership) do
      {:ok, room.channel_name, user_id}
    end
  end

  defp resolve_room(_socket, _params, _session) do
    {:error, dgettext("group_call", "This conference is no longer available.")}
  end

  defp fetch_room(token) do
    case GroupCall.get_room(token) do
      {:ok, room} -> {:ok, room}
      {:error, :not_found} -> {:error, dgettext("group_call", "This conference has ended.")}
    end
  end

  # Identification is not the chat's private fact: NickServ keeps the set, and
  # the chat's `session.identified` is a mirror of it. A surface with no chat
  # behind it asks the same question of the same authority.
  defp require_identified(nickname) when is_binary(nickname) do
    if NickServ.identified?(nickname) do
      :ok
    else
      {:error, dgettext("group_call", "You must be identified with NickServ to use group calls.")}
    end
  end

  defp require_identified(_nickname),
    do:
      {:error, dgettext("group_call", "You must be identified with NickServ to use group calls.")}

  defp require_registered(nickname) do
    case SessionHelpers.resolve_user_id(nickname) do
      {:ok, user_id} ->
        {:ok, user_id}

      _unregistered ->
        {:error,
         dgettext("group_call", "You must be registered with NickServ to use group calls.")}
    end
  end

  # Only a registered nickname can mint a link: the record carries who made it,
  # and a link nobody is accountable for is one nobody can be asked about.
  defp sharable?(nickname) when is_binary(nickname) and nickname != "" do
    match?({:ok, _id}, SessionHelpers.resolve_user_id(nickname))
  end

  defp sharable?(_nickname), do: false

  defp channel_membership(channel_name) do
    case Server.get_state(channel_name) do
      {:ok, %{members: members}} ->
        Enum.reduce(members, Membership.new(), fn {nickname, role}, membership ->
          Membership.add(membership, nickname, role)
        end)

      _absent ->
        Membership.new()
    end
  end
end
