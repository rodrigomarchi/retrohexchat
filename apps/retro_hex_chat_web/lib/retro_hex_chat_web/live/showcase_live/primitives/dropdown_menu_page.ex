defmodule RetroHexChatWeb.ShowcaseLive.Primitives.DropdownMenuPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.DropdownMenu
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.ShowcaseHelpers
  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: dgettext("showcase", "Dropdown Menu"),
       active_page: "dropdown-menu"
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{dgettext("showcase", "Dropdown Menu")}</h2>

      <.showcase_card
        title={dgettext("showcase", "Basic Dropdown")}
        description="A dropdown menu triggered by a button click."
      >
        <.dropdown_menu>
          <.dropdown_menu_trigger>
            <.button variant="outline">
              <:icon><Icons.icon_btn_menu /></:icon>
              {dgettext("showcase", "Open Menu")}
            </.button>
          </.dropdown_menu_trigger>
          <.dropdown_menu_content class="shadow-retro-window bg-surface p-[3px] min-w-[160px]">
            <div class="shadow-retro-field bg-white p-[2px]">
              <.dropdown_menu_label>{dgettext("showcase", "Account")}</.dropdown_menu_label>
              <.dropdown_menu_separator />
              <.dropdown_menu_group>
                <.dropdown_menu_item>
                  <:icon><Icons.icon_status_user class="w-4 h-4" /></:icon>
                  {dgettext("showcase", "Profile")}
                </.dropdown_menu_item>
                <.dropdown_menu_item>
                  <:icon><Icons.icon_btn_settings class="w-4 h-4" /></:icon>
                  {dgettext("showcase", "Settings")}
                </.dropdown_menu_item>
                <.dropdown_menu_item>
                  <:icon><Icons.icon_btn_keyboard class="w-4 h-4" /></:icon>
                  {dgettext("showcase", "Keyboard Shortcuts")}
                </.dropdown_menu_item>
              </.dropdown_menu_group>
              <.dropdown_menu_separator />
              <.dropdown_menu_item>
                <:icon><Icons.icon_btn_disconnect class="w-4 h-4" /></:icon>
                {dgettext("showcase", "Log Out")}
              </.dropdown_menu_item>
            </div>
          </.dropdown_menu_content>
        </.dropdown_menu>
        <.code_example>
          &lt;.dropdown_menu&gt;
          &lt;.dropdown_menu_trigger&gt;
          &lt;.button variant="outline"&gt;
          &lt;:icon&gt;&lt;Icons.icon_btn_menu /&gt;&lt;/:icon&gt;
          Open Menu
          &lt;/.button&gt;
          &lt;/.dropdown_menu_trigger&gt;
          &lt;.dropdown_menu_content&gt;...&lt;/.dropdown_menu_content&gt;
          &lt;/.dropdown_menu&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "With Shortcuts")}
        description="Menu items with keyboard shortcut hints."
      >
        <.dropdown_menu>
          <.dropdown_menu_trigger>
            <.button variant="outline">
              <:icon><Icons.icon_btn_edit /></:icon>
              {dgettext("showcase", "Edit")}
            </.button>
          </.dropdown_menu_trigger>
          <.dropdown_menu_content class="shadow-retro-window bg-surface p-[3px] min-w-[200px]">
            <div class="shadow-retro-field bg-white p-[2px]">
              <.dropdown_menu_item>
                <:icon><Icons.icon_btn_reset class="w-4 h-4" /></:icon>
                {dgettext("showcase", "Undo")}
                <:shortcut>{dgettext("showcase", "Ctrl+Z")}</:shortcut>
              </.dropdown_menu_item>
              <.dropdown_menu_item>
                <:icon><Icons.icon_btn_refresh class="w-4 h-4" /></:icon>
                {dgettext("showcase", "Redo")}
                <:shortcut>{dgettext("showcase", "Ctrl+Y")}</:shortcut>
              </.dropdown_menu_item>
              <.dropdown_menu_separator />
              <.dropdown_menu_item>
                <:icon><Icons.icon_copy class="w-4 h-4" /></:icon>
                {dgettext("showcase", "Cut")}
                <:shortcut>{dgettext("showcase", "Ctrl+X")}</:shortcut>
              </.dropdown_menu_item>
              <.dropdown_menu_item>
                <:icon><Icons.icon_copy class="w-4 h-4" /></:icon>
                {dgettext("showcase", "Copy")}
                <:shortcut>{dgettext("showcase", "Ctrl+C")}</:shortcut>
              </.dropdown_menu_item>
              <.dropdown_menu_item>
                <:icon><Icons.icon_dialog_paste class="w-4 h-4" /></:icon>
                {dgettext("showcase", "Paste")}
                <:shortcut>{dgettext("showcase", "Ctrl+V")}</:shortcut>
              </.dropdown_menu_item>
            </div>
          </.dropdown_menu_content>
        </.dropdown_menu>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
