defmodule RetroHexChatWeb.Components.UI.Lobby.LobbyMenuBar do
  @moduledoc """
  macOS-style menu bar for the lobby desktop.

  The lobby counterpart to `MenuBarApp`: same `MenuBar`/`ContextMenu` primitives
  and the same `MenuBarHook` DOM contract, but with lobby menus — Session, Call,
  Window and Help — mirroring the taskbar Start menu's actions.

  Items route through the two lobby interaction styles: server events
  (`start_call`, `toggle_privacy_mode`, `leave_lobby`, handled by `LobbyLive`)
  and client-side `data-window-open` (read by the `WindowManagerHook`, which is
  why the menu bar must render inside the desktop element).
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Icons

  import RetroHexChatWeb.Components.UI.MenuBar
  import RetroHexChatWeb.Components.UI.ContextMenu
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]

  attr :id, :string, default: "lobby-menubar"
  attr :connected, :boolean, default: false
  attr :call_active, :boolean, default: false
  attr :turn_configured, :boolean, default: false
  attr :turn_only, :boolean, default: false
  attr :class, :any, default: nil
  attr :rest, :global

  @spec lobby_menu_bar(map()) :: Phoenix.LiveView.Rendered.t()
  def lobby_menu_bar(assigns) do
    ~H"""
    <.menu_bar id={@id} testid="lobby-menu-bar" class={@class} {@rest}>
      <%!-- Session menu --%>
      <.menu label={dgettext("lobby", "Session")}>
        <.context_menu_item
          :if={@turn_configured}
          on_click="toggle_privacy_mode"
          data-testid="lobby-menu-privacy"
        >
          <:icon><Icons.icon_privacy class="h-[14px] w-[14px]" /></:icon>
          {if @turn_only,
            do: dgettext("lobby", "Privacy: ON"),
            else: dgettext("lobby", "Privacy: OFF")}
        </.context_menu_item>
        <.context_menu_separator :if={@turn_configured} />
        <.context_menu_item on_click="leave_lobby" data-testid="lobby-menu-leave">
          <:icon><Icons.icon_close class="h-[14px] w-[14px]" /></:icon>
          {dgettext("lobby", "Leave lobby")}
        </.context_menu_item>
      </.menu>

      <%!-- Call menu (start actions) --%>
      <.menu label={dgettext("lobby", "Call")}>
        <.context_menu_item
          on_click="start_call"
          phx-value-type="audio"
          disabled={not @connected or @call_active}
          data-testid="lobby-menu-audio"
        >
          <:icon><Icons.icon_microphone class="h-[14px] w-[14px]" /></:icon>
          {dgettext("lobby", "Start audio")}
        </.context_menu_item>
        <.context_menu_item
          on_click="start_call"
          phx-value-type="video"
          disabled={not @connected or @call_active}
          data-testid="lobby-menu-video"
        >
          <:icon><Icons.icon_camera class="h-[14px] w-[14px]" /></:icon>
          {dgettext("lobby", "Start video")}
        </.context_menu_item>
        <.context_menu_separator />
        <.context_menu_item
          data-window-open="file"
          disabled={not @connected}
          data-testid="lobby-menu-file"
        >
          <:icon><Icons.icon_file_send class="h-[14px] w-[14px]" /></:icon>
          {dgettext("lobby", "Send a file")}
        </.context_menu_item>
        <.context_menu_item
          data-window-open="game"
          disabled={not @connected}
          data-testid="lobby-menu-game"
        >
          <:icon><Icons.icon_joystick class="h-[14px] w-[14px]" /></:icon>
          {dgettext("lobby", "Play a game")}
        </.context_menu_item>
      </.menu>

      <%!-- Window menu (open/focus windows) --%>
      <.menu label={dgettext("lobby", "Window")}>
        <.context_menu_item data-window-open="chat">
          <:icon><Icons.icon_chat class="h-[14px] w-[14px]" /></:icon>
          {dgettext("lobby", "Chat")}
        </.context_menu_item>
        <.context_menu_item data-window-open="conn">
          <:icon><Icons.icon_status_signal class="h-[14px] w-[14px]" /></:icon>
          {dgettext("lobby", "Statistics")}
        </.context_menu_item>
        <.context_menu_item data-window-open="call">
          <:icon><Icons.icon_camera class="h-[14px] w-[14px]" /></:icon>
          {dgettext("lobby", "Call")}
        </.context_menu_item>
        <.context_menu_item data-window-open="file">
          <:icon><Icons.icon_file_send class="h-[14px] w-[14px]" /></:icon>
          {dgettext("lobby", "Files")}
        </.context_menu_item>
        <.context_menu_item data-window-open="game">
          <:icon><Icons.icon_joystick class="h-[14px] w-[14px]" /></:icon>
          {dgettext("lobby", "Games")}
        </.context_menu_item>
      </.menu>

      <%!-- Help menu --%>
      <.menu label={dgettext("lobby", "Help")}>
        <.context_menu_item data-testid="lobby-menu-help-topics">
          <:icon><Icons.icon_btn_help_topics class="h-[14px] w-[14px]" /></:icon>
          <a href="/chat/help" target="_blank" rel="noopener" class="block flex-1">
            {dgettext("lobby", "Help Topics")}
          </a>
        </.context_menu_item>
        <.context_menu_separator />
        <.context_menu_item on_click={show_modal("about-dialog")} data-testid="lobby-menu-about">
          <:icon><Icons.icon_dialog_about class="h-[14px] w-[14px]" /></:icon>
          {dgettext("lobby", "About RetroHexChat")}
        </.context_menu_item>
      </.menu>
    </.menu_bar>
    """
  end
end
