defmodule RetroHexChatWeb.ShowcaseLive.Primitives.DropdownMenuPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.DropdownMenu
  import RetroHexChatWeb.Components.UI.ToolButton
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
        <.dropdown_menu
          label={dgettext("showcase", "Open Menu")}
          placement="below-start"
          trigger_class={tool_button_class(size: "sm", captioned: true)}
          open
        >
          <:trigger>
            <Icons.icon_btn_menu class="h-4 w-4" />
            <span class="tool-button__caption">{dgettext("showcase", "Open Menu")}</span>
          </:trigger>
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
          <.dropdown_menu_item tone="danger">
            <:icon><Icons.icon_btn_disconnect class="w-4 h-4" /></:icon>
            {dgettext("showcase", "Log Out")}
          </.dropdown_menu_item>
        </.dropdown_menu>
        <.code_example>
          &lt;.dropdown_menu label="Open Menu"&gt;
          &lt;:trigger&gt;&lt;Icons.icon_btn_menu /&gt;&lt;/:trigger&gt;
          &lt;.dropdown_menu_item phx-click="profile"&gt;
          &lt;:icon&gt;&lt;Icons.icon_status_user /&gt;&lt;/:icon&gt;
          Profile
          &lt;/.dropdown_menu_item&gt;
          &lt;/.dropdown_menu&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "With Shortcuts")}
        description="Menu items with keyboard shortcut hints."
      >
        <.dropdown_menu
          label={dgettext("showcase", "Edit")}
          placement="below-start"
          trigger_class={tool_button_class(size: "sm", captioned: true)}
        >
          <:trigger>
            <Icons.icon_btn_edit class="h-4 w-4" />
            <span class="tool-button__caption">{dgettext("showcase", "Edit")}</span>
          </:trigger>
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
        </.dropdown_menu>
      </.showcase_card>
    </.showcase_layout>
    """
  end

  # A showcase page renders the component and nothing behind it, so the
  # controls it draws have nowhere to go. Answering them is what keeps a
  # click from taking the page down with an unmatched event.
  @impl true
  def handle_event(_event, _params, socket), do: {:noreply, socket}
end
