defmodule RetroHexChatWeb.ShowcaseLive.DropdownMenuPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.DropdownMenu
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Dropdown Menu", active_page: "dropdown-menu")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Dropdown Menu</h2>

      <.showcase_card
        title="Basic Dropdown"
        description="A dropdown menu triggered by a button click."
      >
        <.dropdown_menu>
          <.dropdown_menu_trigger>
            <.button variant="outline">Open Menu</.button>
          </.dropdown_menu_trigger>
          <.dropdown_menu_content class="shadow-retro-window bg-surface p-[3px] min-w-[160px]">
            <div class="shadow-retro-field bg-white p-[2px]">
              <div class="px-3 py-1 text-sm hover:bg-primary hover:text-white cursor-pointer">
                Profile
              </div>
              <div class="px-3 py-1 text-sm hover:bg-primary hover:text-white cursor-pointer">
                Settings
              </div>
              <div class="px-3 py-1 text-sm hover:bg-primary hover:text-white cursor-pointer">
                Keyboard Shortcuts
              </div>
              <div class="border-t border-separator my-[2px]" />
              <div class="px-3 py-1 text-sm hover:bg-primary hover:text-white cursor-pointer">
                Log Out
              </div>
            </div>
          </.dropdown_menu_content>
        </.dropdown_menu>
        <.code_example>
          &lt;.dropdown_menu&gt;
          &lt;.dropdown_menu_trigger&gt;
          &lt;.button variant="outline"&gt;Open Menu&lt;/.button&gt;
          &lt;/.dropdown_menu_trigger&gt;
          &lt;.dropdown_menu_content&gt;
          ...items...
          &lt;/.dropdown_menu_content&gt;
          &lt;/.dropdown_menu&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card title="With Shortcuts" description="Menu items with keyboard shortcut hints.">
        <.dropdown_menu>
          <.dropdown_menu_trigger>
            <.button variant="outline">Edit</.button>
          </.dropdown_menu_trigger>
          <.dropdown_menu_content class="shadow-retro-window bg-surface p-[3px] min-w-[200px]">
            <div class="shadow-retro-field bg-white p-[2px]">
              <div class="flex justify-between px-3 py-1 text-sm hover:bg-primary hover:text-white cursor-pointer">
                <span>Undo</span>
                <.dropdown_menu_shortcut>Ctrl+Z</.dropdown_menu_shortcut>
              </div>
              <div class="flex justify-between px-3 py-1 text-sm hover:bg-primary hover:text-white cursor-pointer">
                <span>Redo</span>
                <.dropdown_menu_shortcut>Ctrl+Y</.dropdown_menu_shortcut>
              </div>
              <div class="border-t border-separator my-[2px]" />
              <div class="flex justify-between px-3 py-1 text-sm hover:bg-primary hover:text-white cursor-pointer">
                <span>Cut</span>
                <.dropdown_menu_shortcut>Ctrl+X</.dropdown_menu_shortcut>
              </div>
              <div class="flex justify-between px-3 py-1 text-sm hover:bg-primary hover:text-white cursor-pointer">
                <span>Copy</span>
                <.dropdown_menu_shortcut>Ctrl+C</.dropdown_menu_shortcut>
              </div>
              <div class="flex justify-between px-3 py-1 text-sm hover:bg-primary hover:text-white cursor-pointer">
                <span>Paste</span>
                <.dropdown_menu_shortcut>Ctrl+V</.dropdown_menu_shortcut>
              </div>
            </div>
          </.dropdown_menu_content>
        </.dropdown_menu>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
