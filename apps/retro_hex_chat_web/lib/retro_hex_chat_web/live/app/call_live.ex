defmodule RetroHexChatWeb.App.CallLive do
  @moduledoc """
  A channel conference, as a surface of its own.

  One module, two mounts: this is the page at `/call/:token` and it is also
  what the chat's Group Call window renders. Nothing about a conference is
  written twice — the difference between the two is where the process hangs,
  not what it does. Everything that genuinely differs goes through
  `RetroHexChatWeb.Live.SurfaceHost`.

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
  alias RetroHexChatWeb.Live.SurfaceHost, as: Host
  alias RetroHexChatWeb.ShareLinkRef

  @impl true
  @spec mount(map(), map(), Socket.t()) :: {:ok, Socket.t()}
  def mount(params, session, socket) do
    socket =
      assign(socket,
        embedded?: session["embedded"] == true,
        surface_tag: :call,
        nickname: session["nickname"] || socket.assigns[:surface_nickname],
        # The device preference is the person's, not the screen's: the same
        # terminal that remembered a camera for the chat's pre-join has to hand
        # it to the surface that replaced it.
        trusted_device_id: session["trusted_device_id"] || socket.assigns[:trusted_device_id],
        channel_name: nil,
        group_call: nil,
        group_call_prejoin: nil,
        group_call_pending: nil,
        group_call_prejoin_preferences: nil,
        prejoin_roster: [],
        host_snapshot: nil,
        notice: nil,
        share_url: nil,
        denied: nil
      )

    socket = OpenSurfaces.attach(socket, socket.assigns.nickname)

    case resolve_room(socket, params, session) do
      {:ok, channel_name, user_id} ->
        {:ok,
         socket
         |> assign(channel_name: channel_name)
         |> subscribe_to_room(channel_name)
         |> Events.mount_call(channel_name, user_id)
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
      <.call_body {assigns} />
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <%!-- The same shell every other desktop screen uses: the workspace only
          has a height because something above it does. --%>
    <div class="bg-background text-text font-system flex h-screen flex-col">
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

  # The chat renders this same LiveView inside its own Group Call window, so
  # the body is shared and the chrome is not.
  defp call_body(assigns) do
    ~H"""
    <div class="flex h-full min-h-0 flex-col">
      <.call_denied :if={@denied} message={@denied} />

      <.group_call_pre_join_panel
        :if={@group_call_prejoin}
        id="group-call-prejoin"
        class="min-h-0 flex-1"
        prejoin={@group_call_prejoin}
        participants={@prejoin_roster}
        on_cancel="group_call_prejoin_cancel"
      />

      <div :if={@group_call} class="flex h-full min-h-0 flex-col gap-1">
        <%!-- Minting is a deliberate act, not a side effect of opening a call:
              a link per window opened would fill the table with addresses
              nobody ever sent. --%>
        <.share_bar
          url={@share_url}
          available={sharable?(@nickname)}
          on_share="share_call"
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
      {:noreply, assign(socket, share_url: ShareLinkRef.url(link.slug))}
    else
      _unavailable -> {:noreply, socket}
    end
  end

  def handle_event("share_call", _params, socket), do: {:noreply, socket}

  def handle_event(event, params, socket) do
    {_halted, socket} = Events.handle_event(event, params, socket)
    {:noreply, publish(socket)}
  end

  @impl true
  @spec handle_info(term(), Socket.t()) :: {:noreply, Socket.t()}
  # The chat forwards the shortcuts and the window chrome it still owns: the
  # keystroke lands on the chat's window, the call is what it means.
  def handle_info({:call_surface_command, {:event, event}}, socket) do
    {_halted, socket} = Events.handle_event(event, %{}, socket)
    {:noreply, publish(socket)}
  end

  # Not a window being closed: the channel the call stood on is gone, or the
  # host is swapping it for another one's.
  def handle_info({:call_surface_command, {:leave, reason}}, socket) do
    {:noreply, socket |> Events.leave(reason) |> publish()}
  end

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

  def handle_info({:group_call_moderation, _payload}, socket) do
    {:noreply, socket}
  end

  defp publish(socket), do: Host.publish(socket, host_snapshot(socket))

  @doc """
  What the host is told about the call — public so its shape is testable.

  Nicknames and track ids, not participants and tracks: the chat's title bar,
  taskbar button and status zone count them and name the channel, and nothing
  in the chat reads a media state it is not carrying.
  """
  @spec host_snapshot(Socket.t()) :: map() | nil
  def host_snapshot(%{assigns: %{group_call: %{} = call}}) do
    %{
      channel_name: call.channel_name,
      status: call.status,
      participants: Enum.map(call.participants || [], &%{nickname: Map.get(&1, :nickname)}),
      tracks: Enum.map(call.tracks || [], &%{id: Map.get(&1, :id)})
    }
  end

  def host_snapshot(%{assigns: %{group_call_prejoin: %{channel_name: channel_name}}}) do
    %{channel_name: channel_name, status: :prejoin, participants: [], tracks: []}
  end

  def host_snapshot(_socket), do: nil

  defp apply_room_broadcast(socket, payload) do
    socket
    |> Events.refresh_roster()
    |> Events.apply_summary(Map.get(payload, :channel), Map.get(payload, :summary))
    |> publish()
  end

  defp subscribe_to_room(socket, channel_name) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.channel_calls(channel_name))
    end

    socket
  end

  # Embedded, the chat already decided which channel and already applied the
  # gates it owns; the surface is handed the answer. Standalone, the token in
  # the address is all there is, so every gate runs here — and the refusal is
  # the policy's own sentence, because that is the part the reader can act on.
  defp resolve_room(%{assigns: %{embedded?: true}}, _params, session) do
    case {session["channel_name"], session["user_id"]} do
      {channel_name, user_id} when is_binary(channel_name) and is_integer(user_id) ->
        {:ok, channel_name, user_id}

      _incomplete ->
        {:error, dgettext("group_call", "This conference is no longer available.")}
    end
  end

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
