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
  import RetroHexChatWeb.Components.UI.LanguageMenu
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]

  attr :id, :string, default: "help-menubar"
  attr :current_path, :string, default: "/chat/help"
  attr :class, :any, default: nil
  attr :rest, :global

  @spec help_menu_bar(map()) :: Phoenix.LiveView.Rendered.t()
  def help_menu_bar(assigns) do
    ~H"""
    <.menu_bar
      id={@id}
      testid="help-menu-bar"
      class={classes(["app-menu-bar", @class])}
      {@rest}
    >
      <%!-- Same rail every other shell shows on a phone: one icon per menu,
            opening the shared drawer already on that section. --%>
      <.mobile_menu_drawer menu_id={@id} sections={mobile_sections()} active_section="navigate">
        <:section id="navigate">
          <.navigate_menu_items />
        </:section>
        <:section id="view">
          <.view_menu_items />
        </:section>
        <:section id="language">
          <.language_menu_items mode={:public} current_path={@current_path} />
        </:section>
        <:section id="help">
          <.about_menu_items />
        </:section>
      </.mobile_menu_drawer>

      <.mobile_menu_rail sections={mobile_sections()} />

      <.menu class="app-menu-bar__desktop-menu" label={dgettext("help", "Navigate")}>
        <:icon><Icons.icon_btn_next class="h-4 w-4" /></:icon>
        <.navigate_menu_items />
      </.menu>

      <.menu class="app-menu-bar__desktop-menu" label={dgettext("help", "View")}>
        <:icon><Icons.icon_channels class="h-4 w-4" /></:icon>
        <.view_menu_items />
      </.menu>

      <.language_menu
        mode={:public}
        current_path={@current_path}
        class="app-menu-bar__desktop-menu"
      />

      <.menu class="app-menu-bar__desktop-menu" label={dgettext("help", "Help")}>
        <:icon><Icons.icon_btn_help_topics class="h-4 w-4" /></:icon>
        <.about_menu_items />
      </.menu>
    </.menu_bar>
    """
  end

  defp mobile_sections do
    [
      %{id: "navigate", label: dgettext("help", "Navigate"), icon_fn: :icon_btn_next},
      %{id: "view", label: dgettext("help", "View"), icon_fn: :icon_channels},
      %{id: "language", label: dgettext("ui", "Language"), icon_fn: :icon_globe},
      %{id: "help", label: dgettext("help", "Help"), icon_fn: :icon_btn_help_topics}
    ]
  end

  defp navigate_menu_items(assigns) do
    ~H"""
    <.context_menu_item data-testid="help-menu-home">
      <:icon><Icons.icon_hex_stone class="h-[14px] w-[14px]" /></:icon>
      <.link navigate="/chat/help" class="block flex-1">{dgettext("help", "Home")}</.link>
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
    """
  end

  defp view_menu_items(assigns) do
    ~H"""
    <.context_menu_item
      on_click="help_nav_tab"
      phx-value-tab="contents"
      data-testid="help-menu-contents"
    >
      <:icon><Icons.icon_notepad class="h-[14px] w-[14px]" /></:icon>
      {dgettext("help", "Contents")}
    </.context_menu_item>
    <.context_menu_item on_click="help_nav_tab" phx-value-tab="index" data-testid="help-menu-index">
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
    """
  end

  defp about_menu_items(assigns) do
    ~H"""
    <.context_menu_item on_click={show_modal("about-dialog")} data-testid="help-menu-about">
      <:icon><Icons.icon_dialog_about class="h-[14px] w-[14px]" /></:icon>
      {dgettext("help", "About RetroHexChat")}
    </.context_menu_item>
    """
  end
end
