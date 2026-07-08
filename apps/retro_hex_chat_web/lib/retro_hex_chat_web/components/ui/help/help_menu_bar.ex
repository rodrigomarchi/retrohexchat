defmodule RetroHexChatWeb.Components.UI.Help.HelpMenuBar do
  @moduledoc """
  macOS-style menu bar for the help desktop.

  The help counterpart to `MenuBarApp`: same `MenuBar`/`ContextMenu`
  primitives and the same `MenuBarHook` DOM contract, with help menus — Navigate,
  View and Help. Items route through three interaction styles: LiveView `navigate`
  links (Home / go to a topic), client-side `data-help-nav` (Back/Forward, read by
  `HelpNavHook`), and server events (`help_nav_tab`, handled by `HelpLive.Index`).
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Icons

  import RetroHexChatWeb.Components.UI.MenuBar
  import RetroHexChatWeb.Components.UI.ContextMenu
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]

  attr :id, :string, default: "help-menubar"
  attr :class, :any, default: nil
  attr :rest, :global

  @spec help_menu_bar(map()) :: Phoenix.LiveView.Rendered.t()
  def help_menu_bar(assigns) do
    ~H"""
    <.menu_bar id={@id} testid="help-menu-bar" class={@class} {@rest}>
      <%!-- Navigate menu --%>
      <.menu label={dgettext("help", "Navigate")}>
        <.context_menu_item data-testid="help-menu-home">
          <:icon><Icons.icon_hex_stone class="h-[14px] w-[14px]" /></:icon>
          <.link navigate="/chat/help" class="block flex-1">
            {dgettext("help", "Home")}
          </.link>
        </.context_menu_item>
        <.context_menu_separator />
        <.context_menu_item data-help-nav="back" data-testid="help-menu-back">
          <:icon><Icons.icon_btn_prev class="h-[14px] w-[14px]" /></:icon>
          {dgettext("help", "Back")}
        </.context_menu_item>
        <.context_menu_item data-help-nav="forward" data-testid="help-menu-forward">
          <:icon><Icons.icon_btn_next class="h-[14px] w-[14px]" /></:icon>
          {dgettext("help", "Forward")}
        </.context_menu_item>
      </.menu>

      <%!-- View menu (navigator tabs) --%>
      <.menu label={dgettext("help", "View")}>
        <.context_menu_item
          on_click="help_nav_tab"
          phx-value-tab="contents"
          data-testid="help-menu-contents"
        >
          <:icon><Icons.icon_notepad class="h-[14px] w-[14px]" /></:icon>
          {dgettext("help", "Contents")}
        </.context_menu_item>
        <.context_menu_item
          on_click="help_nav_tab"
          phx-value-tab="index"
          data-testid="help-menu-index"
        >
          <:icon><Icons.icon_btn_channel_list class="h-[14px] w-[14px]" /></:icon>
          {dgettext("help", "Index")}
        </.context_menu_item>
        <.context_menu_item
          on_click="help_nav_tab"
          phx-value-tab="search"
          data-testid="help-menu-search"
        >
          <:icon><Icons.icon_btn_search class="h-[14px] w-[14px]" /></:icon>
          {dgettext("help", "Search")}
        </.context_menu_item>
      </.menu>

      <%!-- Help menu --%>
      <.menu label={dgettext("help", "Help")}>
        <.context_menu_item on_click={show_modal("about-dialog")} data-testid="help-menu-about">
          <:icon><Icons.icon_dialog_about class="h-[14px] w-[14px]" /></:icon>
          {dgettext("help", "About RetroHexChat")}
        </.context_menu_item>
      </.menu>
    </.menu_bar>
    """
  end
end
