defmodule RetroHexChatWeb.App.SpaceLive do
  @moduledoc """
  Shell LiveView for a virtual space.

  Validates the HTTP session, the space token and the join policy, then
  renders the canvas shell with a signed `join_token`. The world runtime
  never flows through this process: the `SpaceCanvasHook` opens its own
  Phoenix Channel (`space:<token>`) authorized by the signed token.

  Invalid, terminal, full and access-denied sessions render retro terminal
  states instead of the canvas.
  """
  use RetroHexChatWeb, :live_view

  import RetroHexChatWeb.Components.UI.AppHeader
  import RetroHexChatWeb.Components.UI.ContextMenu
  import RetroHexChatWeb.Components.UI.Desktop
  import RetroHexChatWeb.Components.UI.MenuBar
  import RetroHexChatWeb.Components.UI.Window

  alias RetroHexChat.Services.NickServ
  alias RetroHexChat.VirtualSpace
  alias RetroHexChat.VirtualSpace.JoinToken
  alias RetroHexChatWeb.App.SessionHelpers
  alias RetroHexChatWeb.Icons

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(%{"token" => token}, session, socket) do
    nickname = session["chat_nickname"]

    with {:ok, socket} <- SessionHelpers.verify_nickname(socket, nickname),
         {:ok, user_id} <- SessionHelpers.resolve_user_id(nickname),
         {:ok, db_session} <- fetch_session(token),
         actor = build_actor(user_id, nickname),
         :ok <- VirtualSpace.can_join?(actor, db_session),
         :ok <- VirtualSpace.check_capacity(db_session, user_id) do
      {:ok, assign_shell(socket, token, db_session, user_id, nickname)}
    else
      {:redirect, redirect_socket} when is_struct(redirect_socket) ->
        {:ok, redirect_socket}

      {:redirect, _} ->
        {:ok, assign_state(socket, :denied, token, nil)}

      {:error, :not_found} ->
        {:ok, assign_state(socket, :invalid, token, nil)}

      {:error, :terminal_session} ->
        {:ok, assign_terminal(socket, token)}

      {:error, :space_full} ->
        {:ok, assign_state(socket, :full, token, nil)}

      {:error, _denied} ->
        {:ok, assign_state(socket, :denied, token, nil)}
    end
  end

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("leave_space", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/chat")}
  end

  def handle_event("space_help", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/chat/help/feature-virtual-spaces")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col fixed inset-0 overflow-hidden bg-background" id="space-app">
      <.desktop id="space-desktop" persist_key="space" persist={false} data-testid="space-root">
        <:header>
          <.app_header>
            <:panels>
              <.menu_bar id="space-menubar" phx-hook="MenuBarHook">
                <.menu label={dgettext("space", "Space")}>
                  <.context_menu_item :if={@state == :ready} data-window-open="space-world">
                    <:icon><Icons.icon_community class="h-[14px] w-[14px]" /></:icon>
                    {dgettext("space", "Space")}
                  </.context_menu_item>
                  <.context_menu_item :if={@state == :ready} data-window-open="space-people">
                    <:icon><Icons.icon_status_user class="h-[14px] w-[14px]" /></:icon>
                    {dgettext("space", "Who's here")}
                  </.context_menu_item>
                  <.context_menu_item
                    :if={@state == :ready and @is_creator}
                    data-window-open="space-host"
                  >
                    <:icon><Icons.icon_shield class="h-[14px] w-[14px]" /></:icon>
                    {dgettext("space", "Host controls")}
                  </.context_menu_item>
                  <.context_menu_separator />
                  <.context_menu_item on_click="leave_space" action="leave_space">
                    <:icon><Icons.icon_channels class="h-[14px] w-[14px]" /></:icon>
                    {dgettext("space", "Back to chat")}
                  </.context_menu_item>
                </.menu>
                <.menu label={dgettext("ui", "Help")}>
                  <.context_menu_item on_click="space_help" action="space_help">
                    <:icon><Icons.icon_group_help class="h-[14px] w-[14px]" /></:icon>
                    {dgettext("space", "Virtual spaces help")}
                  </.context_menu_item>
                </.menu>
              </.menu_bar>

              <.window_status_bar class="ml-auto p-[2px]">
                <.window_status_bar_field class="font-bold">
                  {@space_title || dgettext("space", "Virtual space")}
                </.window_status_bar_field>
                <.window_status_bar_field :if={@state == :ready} class="text-muted-foreground">
                  {@channel_name}
                </.window_status_bar_field>
                <button
                  :if={@state == :ready}
                  type="button"
                  data-window-open="space-people"
                  title={dgettext("space", "Who's here")}
                  class="shadow-retro-status px-[3px] py-[2px] text-sm truncate hover:text-primary"
                >
                  <span data-space-hud-count>1</span>
                  <span>{dgettext("space", "here")}</span>
                </button>
              </.window_status_bar>
            </:panels>
          </.app_header>
        </:header>

        <%= if @state == :ready do %>
          <.space_world_window
            space_title={@space_title}
            space_token={@space_token}
            join_token={@join_token}
            nickname={@nickname}
          />

          <.desktop_window
            :if={@is_creator}
            id="space-host"
            title={dgettext("space", "Host controls")}
            width={320}
            height={300}
            default_x={24}
            default_y={24}
          >
            <:icon><Icons.icon_shield class="h-4 w-4" /></:icon>
            <div
              id="space-admin-list"
              data-space-admin-list
              phx-update="ignore"
              class="flex flex-col divide-y divide-border"
            >
            </div>
          </.desktop_window>

          <.desktop_window
            id="space-people"
            title={dgettext("space", "Who's here")}
            open={false}
            width={240}
            height={300}
            default_x={360}
            default_y={24}
          >
            <:icon><Icons.icon_status_user class="h-4 w-4" /></:icon>
            <div
              id="space-people-list"
              data-space-people-list
              phx-update="ignore"
              class="flex flex-col divide-y divide-border"
            >
            </div>
          </.desktop_window>

          <%!-- Real icons kept in Elixir; the canvas hook clones these into the
               JS-built participant rows so buttons carry proper glyphs. --%>
          <div class="hidden" aria-hidden="true">
            <template data-space-tpl="ban"><Icons.icon_ban class="h-[12px] w-[12px]" /></template>
            <template data-space-tpl="mute"><Icons.icon_mute class="h-[12px] w-[12px]" /></template>
          </div>
        <% else %>
          <.space_terminal_window state={@state} session_status={@session_status} />
        <% end %>

        <:taskbar>
          <.taskbar id="space-taskbar">
            <:start>
              <div class="relative">
                <.start_button label={dgettext("space", "Space")}>
                  <:icon><Icons.icon_hex_stone class="h-4 w-4" /></:icon>
                </.start_button>
                <.start_menu id="space-start-menu">
                  <.start_menu_item
                    :if={@state == :ready}
                    data-window-open="space-world"
                    label={dgettext("space", "Space")}
                  >
                    <:icon><Icons.icon_community class="h-4 w-4" /></:icon>
                  </.start_menu_item>
                  <.start_menu_item
                    :if={@state == :ready}
                    data-window-open="space-people"
                    label={dgettext("space", "Who's here")}
                  >
                    <:icon><Icons.icon_status_user class="h-4 w-4" /></:icon>
                  </.start_menu_item>
                  <.start_menu_item
                    :if={@state == :ready and @is_creator}
                    data-window-open="space-host"
                    label={dgettext("space", "Host controls")}
                  >
                    <:icon><Icons.icon_shield class="h-4 w-4" /></:icon>
                  </.start_menu_item>
                  <.start_menu_separator />
                  <.start_menu_item phx-click="leave_space" label={dgettext("space", "Back to chat")}>
                    <:icon><Icons.icon_channels class="h-4 w-4" /></:icon>
                  </.start_menu_item>
                </.start_menu>
              </div>
            </:start>

            <.taskbar_button :if={@state == :ready} window="space-world" label={@space_title}>
              <:icon><Icons.icon_community class="h-4 w-4" /></:icon>
            </.taskbar_button>
            <.taskbar_button
              :if={@state == :ready}
              window="space-people"
              label={dgettext("space", "Who's here")}
            >
              <:icon><Icons.icon_status_user class="h-4 w-4" /></:icon>
            </.taskbar_button>
            <.taskbar_button
              :if={@state == :ready and @is_creator}
              window="space-host"
              label={dgettext("space", "Host controls")}
            >
              <:icon><Icons.icon_shield class="h-4 w-4" /></:icon>
            </.taskbar_button>

            <:tray>
              <.desktop_tray>
                <span id="space-tray-clock" phx-hook="ClockHook" class="font-mono tabular-nums">
                </span>
              </.desktop_tray>
            </:tray>
          </.taskbar>
        </:taskbar>
      </.desktop>
    </div>
    """
  end

  attr :space_title, :string, required: true
  attr :space_token, :string, required: true
  attr :join_token, :string, required: true
  attr :nickname, :string, required: true

  # The world lives in one pinned, maximized window. Its body is the hook root:
  # the canvas plus the JS-driven overlays (chat, board modal, kicked/closed).
  # Maximizing the window enlarges the canvas, which reveals more of the map.
  defp space_world_window(assigns) do
    ~H"""
    <.desktop_window
      id="space-world"
      title={@space_title}
      pinned
      default_maximized
      width={760}
      height={540}
      min_width={360}
      min_height={280}
      body_class="p-0 min-h-0 overflow-hidden flex flex-col"
    >
      <:icon><Icons.icon_community class="h-4 w-4" /></:icon>
      <div
        id="space-canvas-root"
        phx-hook="SpaceCanvasHook"
        phx-update="ignore"
        data-testid="space-shell"
        data-space-token={@space_token}
        data-join-token={@join_token}
        data-nickname={@nickname}
        class="relative flex-1 min-h-0 w-full bg-canvas"
      >
        <canvas id="space-canvas" class="absolute inset-0 block h-full w-full"></canvas>
        <p class="absolute top-1 left-2 right-2 text-xs text-muted-foreground pointer-events-none">
          {dgettext("space", "Arrows/WASD to move · E to use · F to sit")}
        </p>
        <div
          data-space-modal
          hidden
          class="absolute inset-0 m-auto h-fit w-fit bg-canvas shadow-retro-field p-3 text-center"
        >
        </div>
        <input
          type="text"
          data-space-chat-input
          maxlength="160"
          autocomplete="off"
          placeholder={dgettext("space", "Say something… (Enter to send)")}
          class="absolute bottom-2 left-2 right-2 bg-canvas shadow-retro-field px-2 py-1 text-sm"
        />
        <div
          data-space-kicked
          hidden
          class="absolute inset-0 flex items-center justify-center bg-canvas font-mono text-center p-6"
        >
          <div>
            <div class="font-bold mb-2">{dgettext("space", "REMOVED FROM SPACE")}</div>
            <p class="text-sm">{dgettext("space", "The host removed you from this space.")}</p>
            <.link navigate={~p"/chat"} class="mt-4 inline-block underline text-sm">
              {dgettext("space", "Back to chat")}
            </.link>
          </div>
        </div>
        <div
          data-space-closed
          hidden
          class="absolute inset-0 flex items-center justify-center bg-canvas font-mono text-center p-6"
        >
          <div>
            <div class="font-bold mb-2">{dgettext("space", "SPACE CLOSED")}</div>
            <p class="text-sm">{dgettext("space", "This virtual space has ended.")}</p>
            <.link navigate={~p"/chat"} class="mt-4 inline-block underline text-sm">
              {dgettext("space", "Back to chat")}
            </.link>
          </div>
        </div>
      </div>
    </.desktop_window>
    """
  end

  attr :state, :atom, required: true
  attr :session_status, :string, default: nil

  # Invalid / ended / full / denied render as a single pinned, centered window
  # on the same desktop so every space screen shares the window-manager chrome.
  defp space_terminal_window(assigns) do
    assigns = assign(assigns, :copy, terminal_copy(assigns.state, assigns.session_status))

    ~H"""
    <.desktop_window
      id="space-terminal"
      title={@copy.title}
      pinned
      default_centered
      width={420}
      height={200}
      resizable={false}
      data-testid={@copy.testid}
    >
      <:icon><Icons.icon_shield class="h-4 w-4" /></:icon>
      <div class="text-center font-mono p-4">
        <p class="text-sm">{@copy.body}</p>
        <.link navigate={~p"/chat"} class="mt-4 inline-block underline text-sm">
          {dgettext("space", "Back to chat")}
        </.link>
      </div>
    </.desktop_window>
    """
  end

  defp terminal_copy(:invalid, _status) do
    %{
      testid: "space-invalid",
      title: dgettext("space", "SPACE NOT FOUND"),
      body: dgettext("space", "This virtual space link is invalid or was removed.")
    }
  end

  defp terminal_copy(:terminal, status) do
    %{
      testid: "space-terminal",
      title: dgettext("space", "SPACE ENDED — %{status}", status: status),
      body: dgettext("space", "This virtual space is no longer active.")
    }
  end

  defp terminal_copy(:full, _status) do
    %{
      testid: "space-full",
      title: dgettext("space", "SPACE FULL"),
      body: dgettext("space", "This virtual space is at capacity. Try again later.")
    }
  end

  defp terminal_copy(_denied, _status) do
    %{
      testid: "space-denied",
      title: dgettext("space", "ACCESS DENIED"),
      body:
        dgettext(
          "space",
          "You do not have access to this virtual space. You must be registered, identified and allowed into its channel."
        )
    }
  end

  defp fetch_session(token) do
    VirtualSpace.get_session(token)
  end

  defp build_actor(user_id, nickname) do
    %{
      user_id: user_id,
      nickname: nickname,
      identified: NickServ.identified?(nickname),
      is_admin: false,
      is_server_operator: false
    }
  end

  defp assign_shell(socket, token, db_session, user_id, nickname) do
    socket
    |> assign(
      state: :ready,
      space_token: token,
      join_token: JoinToken.sign(token, user_id, nickname),
      space_title: db_session.title || dgettext("space", "Virtual space"),
      channel_name: db_session.channel_name,
      nickname: nickname,
      user_id: user_id,
      is_creator: db_session.creator_id == user_id,
      page_title: db_session.title || dgettext("space", "Virtual space")
    )
  end

  defp assign_terminal(socket, token) do
    status =
      case VirtualSpace.get_session(token) do
        {:ok, session} -> session.status
        _ -> "closed"
      end

    socket
    |> assign_state(:terminal, token, status)
  end

  defp assign_state(socket, state, token, session_status) do
    assign(socket,
      state: state,
      space_token: token,
      session_status: session_status,
      space_title: dgettext("space", "Virtual space"),
      channel_name: nil,
      is_creator: false,
      page_title: dgettext("space", "Virtual space")
    )
  end
end
