defmodule RetroHexChatWeb.Components.UI.Games.ArcadeMenuBar do
  @moduledoc """
  macOS-style menu bar for the solo arcade desktop.

  The arcade counterpart to `MenuBarApp`/`LobbyMenuBar`: same `MenuBar`/`ContextMenu`
  primitives and the same `MenuBarHook` DOM contract, with arcade menus — Session,
  Window and Help. Items route through the two interaction styles: server events
  (`close_session`, handled by `SoloSessionLive`) and client-side `data-window-open`
  (read by the `WindowManagerHook`, which is why the menu bar must render inside the
  desktop element).
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Icons

  import RetroHexChatWeb.Components.UI.MenuBar
  import RetroHexChatWeb.Components.UI.ContextMenu
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]

  attr :id, :string, default: "arcade-menubar"
  attr :class, :any, default: nil
  attr :rest, :global

  @spec arcade_menu_bar(map()) :: Phoenix.LiveView.Rendered.t()
  def arcade_menu_bar(assigns) do
    ~H"""
    <.menu_bar id={@id} testid="arcade-menu-bar" class={@class} {@rest}>
      <%!-- Session menu --%>
      <.menu label={dgettext("games", "Session")}>
        <.context_menu_item on_click="close_session" data-testid="arcade-menu-leave">
          <:icon><Icons.icon_close class="h-[14px] w-[14px]" /></:icon>
          {dgettext("games", "Leave")}
        </.context_menu_item>
      </.menu>

      <%!-- Window menu (open/focus windows) --%>
      <.menu label={dgettext("games", "Window")}>
        <.context_menu_item data-window-open="arcade" data-testid="arcade-menu-window">
          <:icon><Icons.icon_joystick class="h-[14px] w-[14px]" /></:icon>
          {dgettext("games", "Arcade")}
        </.context_menu_item>
      </.menu>

      <%!-- Help menu --%>
      <.menu label={dgettext("games", "Help")}>
        <.context_menu_item data-testid="arcade-menu-help-topics">
          <:icon><Icons.icon_btn_help_topics class="h-[14px] w-[14px]" /></:icon>
          <a href="/chat/help" target="_blank" rel="noopener" class="block flex-1">
            {dgettext("games", "Help Topics")}
          </a>
        </.context_menu_item>
        <.context_menu_separator />
        <.context_menu_item on_click={show_modal("about-dialog")} data-testid="arcade-menu-about">
          <:icon><Icons.icon_dialog_about class="h-[14px] w-[14px]" /></:icon>
          {dgettext("games", "About RetroHexChat")}
        </.context_menu_item>
      </.menu>
    </.menu_bar>
    """
  end
end
