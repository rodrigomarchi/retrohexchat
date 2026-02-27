defmodule RetroHexChatWeb.Components.Toolbar do
  @moduledoc """
  Simplified toolbar with 3 icons: Disconnect, Options (merged dropdown),
  and Help (direct link to Help Topics).
  """
  use Phoenix.Component

  alias RetroHexChatWeb.Icons

  attr :connected, :boolean, default: false
  attr :is_admin, :boolean, default: false
  @spec toolbar(map()) :: Phoenix.LiveView.Rendered.t()
  def toolbar(assigns) do
    ~H"""
    <div class="toolbar" role="toolbar" id="toolbar" phx-hook="ToolbarGroupHook">
      {connection_group(assigns)}
      {options_group(assigns)}
      {help_button(assigns)}
    </div>
    """
  end

  defp connection_group(assigns) do
    ~H"""
    <button
      :if={@connected}
      type="button"
      class="toolbar-btn"
      title="Disconnect"
      data-testid="toolbar-disconnect"
      phx-click="disconnect"
    >
      <Icons.icon_btn_disconnect />
    </button>
    <button
      :if={!@connected}
      type="button"
      class="toolbar-btn"
      title="Connect"
      data-testid="toolbar-connect"
      phx-click="connect"
    >
      <Icons.icon_btn_connect_lightning />
    </button>
    """
  end

  defp options_group(assigns) do
    ~H"""
    <div class="toolbar-group">
      <button
        type="button"
        class="toolbar-btn toolbar-group-toggle"
        data-toolbar-group="options"
        title="Options"
        data-testid="toolbar-group-options"
      >
        <Icons.icon_group_tools class="toolbar-group-icon" />
      </button>
      <div class="toolbar-group-dropdown u-hidden">
        {options_view_items(assigns)}
        <hr class="toolbar-dropdown-separator" />
        {options_tool_items(assigns)}
      </div>
    </div>
    """
  end

  defp options_view_items(assigns) do
    ~H"""
    <button
      type="button"
      class="toolbar-btn"
      title="Channel List"
      data-testid="toolbar-channel-list"
      phx-click="channel_list"
    >
      <Icons.icon_btn_channel_list />
      <span class="toolbar-group-label">Channel List</span>
    </button>
    <button
      type="button"
      class="toolbar-btn"
      title="Toggle Conversations"
      data-testid="toolbar-toggle-conversations"
      phx-click="toggle_conversations"
    >
      <Icons.icon_btn_toggle_conversations />
      <span class="toolbar-group-label">Toggle Conversations</span>
    </button>
    <button
      type="button"
      class="toolbar-btn"
      title="Toggle Nicklist"
      data-testid="toolbar-toggle-nicklist"
      phx-click="toggle_nicklist"
    >
      <Icons.icon_btn_toggle_nicklist />
      <span class="toolbar-group-label">Toggle Nicklist</span>
    </button>
    <button
      type="button"
      class="toolbar-btn"
      title="Find (Ctrl+Shift+F)"
      data-testid="toolbar-find"
      phx-click="open_search"
    >
      <Icons.icon_btn_find />
      <span class="toolbar-group-label">Find</span>
    </button>
    """
  end

  defp options_tool_items(assigns) do
    ~H"""
    <button
      type="button"
      class="toolbar-btn"
      title="Address Book (Ctrl+Shift+A)"
      data-testid="toolbar-address-book"
      phx-click="toggle_address_book"
    >
      <Icons.icon_btn_address_book />
      <span class="toolbar-group-label">Address Book</span>
    </button>
    <button
      type="button"
      class="toolbar-btn"
      title="Highlight Words (Ctrl+Shift+H)"
      data-testid="toolbar-highlight"
      phx-click="open_highlight_dialog"
    >
      <Icons.icon_btn_highlight_words />
      <span class="toolbar-group-label">Highlight Words</span>
    </button>
    <button
      type="button"
      class="toolbar-btn"
      title="Ignore List (Ctrl+Shift+G)"
      data-testid="toolbar-ignore-list"
      phx-click="open_ignore_dialog"
    >
      <Icons.icon_btn_ignore_list />
      <span class="toolbar-group-label">Ignore List</span>
    </button>
    <button
      type="button"
      class="toolbar-btn"
      title="URL Catcher (Ctrl+Shift+S)"
      data-testid="toolbar-url-catcher"
      phx-click="toggle_url_catcher"
    >
      <Icons.icon_btn_url_catcher />
      <span class="toolbar-group-label">URL Catcher</span>
    </button>
    <button
      type="button"
      class="toolbar-btn"
      title="Channel Central"
      data-testid="toolbar-channel-central"
      phx-click="open_channel_central"
    >
      <Icons.icon_btn_channel_central />
      <span class="toolbar-group-label">Channel Central</span>
    </button>
    <button
      type="button"
      class="toolbar-btn"
      title="Perform (Ctrl+Shift+E)"
      data-testid="toolbar-perform"
      phx-click="open_perform_dialog"
    >
      <Icons.icon_btn_perform />
      <span class="toolbar-group-label">Perform</span>
    </button>
    <button
      type="button"
      class="toolbar-btn"
      title="Sounds"
      data-testid="toolbar-sounds"
      phx-click="open_sound_settings_dialog"
    >
      <Icons.icon_btn_sounds />
      <span class="toolbar-group-label">Sounds</span>
    </button>
    <button
      type="button"
      class="toolbar-btn"
      title="CTCP Settings"
      data-testid="toolbar-ctcp-settings"
      phx-click="open_ctcp_settings_dialog"
    >
      <Icons.icon_btn_ctcp />
      <span class="toolbar-group-label">CTCP Settings</span>
    </button>
    <button
      type="button"
      class="toolbar-btn"
      title="Flood Protection"
      data-testid="toolbar-flood-protection"
      phx-click="open_flood_protection_dialog"
    >
      <Icons.icon_btn_flood_protection />
      <span class="toolbar-group-label">Flood Protection</span>
    </button>
    <button
      type="button"
      class="toolbar-btn"
      title="Alias Editor"
      data-testid="toolbar-alias-editor"
      phx-click="open_alias_dialog"
    >
      <Icons.icon_btn_alias_editor />
      <span class="toolbar-group-label">Alias Editor</span>
    </button>
    <button
      type="button"
      class="toolbar-btn"
      title="Custom Menus"
      data-testid="toolbar-custom-menus"
      phx-click="open_custom_menus_dialog"
    >
      <Icons.icon_btn_custom_menus />
      <span class="toolbar-group-label">Custom Menus</span>
    </button>
    <button
      type="button"
      class="toolbar-btn"
      title="Auto-Respond"
      data-testid="toolbar-autorespond"
      phx-click="open_autorespond_dialog"
    >
      <Icons.icon_btn_auto_respond />
      <span class="toolbar-group-label">Auto-Respond</span>
    </button>
    <button
      type="button"
      class="toolbar-btn"
      title="Settings (Ctrl+Shift+O)"
      data-testid="toolbar-settings"
      phx-click="settings"
    >
      <Icons.icon_btn_settings />
      <span class="toolbar-group-label">Settings</span>
    </button>
    <button
      type="button"
      class="toolbar-btn"
      title="Bot Management"
      data-testid="toolbar-bot-management"
      phx-click="open_bot_dialog"
    >
      <Icons.icon_btn_bot_management />
      <span class="toolbar-group-label">Bot Management</span>
    </button>
    <button
      :if={@is_admin}
      type="button"
      class="toolbar-btn"
      title="Admin Console"
      data-testid="toolbar-admin-console"
      phx-click="open_admin_console"
    >
      <Icons.icon_dialog_admin_console />
      <span class="toolbar-group-label">Admin Console</span>
    </button>
    """
  end

  defp help_button(assigns) do
    ~H"""
    <a
      class="toolbar-btn"
      title="Help Topics (Ctrl+Shift+W)"
      data-testid="toolbar-help"
      href="/chat/help"
      target="_blank"
    >
      <Icons.icon_group_help />
    </a>
    """
  end
end
