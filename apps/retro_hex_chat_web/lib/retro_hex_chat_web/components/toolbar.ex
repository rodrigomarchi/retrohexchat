defmodule RetroHexChatWeb.Components.Toolbar do
  @moduledoc """
  Collapsible toolbar with grouped icon buttons. Each group shows a single
  representative icon; clicking it reveals a dropdown with all group buttons
  and text labels (classic menu style). Single-button groups stay standalone.
  """
  use Phoenix.Component

  alias RetroHexChatWeb.Icons

  attr :connected, :boolean, default: false
  attr :dnd_enabled, :boolean, default: false
  attr :notification_count, :integer, default: 0
  attr :is_admin, :boolean, default: false
  @spec toolbar(map()) :: Phoenix.LiveView.Rendered.t()
  def toolbar(assigns) do
    ~H"""
    <div class="toolbar" role="toolbar" id="toolbar" phx-hook="ToolbarGroupHook">
      {connection_group(assigns)}
      {view_group(assigns)}
      {tools_group(assigns)}
      {notifications_group(assigns)}
      {help_group(assigns)}
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

  defp view_group(assigns) do
    ~H"""
    <div class="toolbar-group">
      <button
        type="button"
        class="toolbar-btn toolbar-group-toggle"
        data-toolbar-group="view"
        title="View"
        data-testid="toolbar-group-view"
      >
        <Icons.icon_group_view class="toolbar-group-icon" />
      </button>
      <div class="toolbar-group-dropdown u-hidden">
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
      </div>
    </div>
    """
  end

  defp tools_group(assigns) do
    ~H"""
    <div class="toolbar-group">
      <button
        type="button"
        class="toolbar-btn toolbar-group-toggle"
        data-toolbar-group="tools"
        title="Tools"
        data-testid="toolbar-group-tools"
      >
        <Icons.icon_group_tools class="toolbar-group-icon" />
      </button>
      <div class="toolbar-group-dropdown u-hidden">
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
      </div>
    </div>
    """
  end

  defp notifications_group(assigns) do
    ~H"""
    <div class="toolbar-group">
      <button
        type="button"
        class="toolbar-btn toolbar-group-toggle"
        data-toolbar-group="notifications"
        title="Notifications"
        data-testid="toolbar-group-notifications"
      >
        <Icons.icon_group_notifications class="toolbar-group-icon" />
      </button>
      <div class="toolbar-group-dropdown u-hidden">
        <button
          type="button"
          class={"toolbar-btn#{if @dnd_enabled, do: " toolbar-btn--active", else: ""}"}
          title={if @dnd_enabled, do: "Disable Do Not Disturb", else: "Do Not Disturb"}
          data-testid="toolbar-dnd"
          phx-click="toggle_dnd"
        >
          <Icons.icon_btn_dnd :if={!@dnd_enabled} />
          <Icons.icon_btn_dnd_active :if={@dnd_enabled} />
          <span class="toolbar-group-label">Do Not Disturb</span>
        </button>
        <button
          type="button"
          class="toolbar-btn toolbar-btn--bell"
          title="Notification Center"
          data-testid="toolbar-bell"
          phx-click="toggle_notification_center"
        >
          <Icons.icon_btn_bell />
          <span class="toolbar-group-label">Notification Center</span>
          <span
            :if={@notification_count > 0}
            class="toolbar-badge"
            data-testid="notification-badge"
          >
            {if @notification_count > 99, do: "99+", else: @notification_count}
          </span>
        </button>
      </div>
    </div>
    """
  end

  defp help_group(assigns) do
    ~H"""
    <div class="toolbar-group">
      <button
        type="button"
        class="toolbar-btn toolbar-group-toggle"
        data-toolbar-group="help"
        title="Help"
        data-testid="toolbar-group-help"
      >
        <Icons.icon_group_help class="toolbar-group-icon" />
      </button>
      <div class="toolbar-group-dropdown u-hidden">
        <button
          type="button"
          class="toolbar-btn"
          title="Keyboard Shortcuts (Ctrl+Shift+/)"
          data-testid="toolbar-cheatsheet"
          phx-click="toggle_cheatsheet"
        >
          <Icons.icon_btn_keyboard />
          <span class="toolbar-group-label">Keyboard Shortcuts</span>
        </button>
        <a
          class="toolbar-btn"
          title="Help Topics (Ctrl+Shift+W)"
          data-testid="toolbar-help"
          href="/chat/help"
          target="_blank"
        >
          <Icons.icon_btn_help_topics />
          <span class="toolbar-group-label">Help Topics</span>
        </a>
      </div>
    </div>
    """
  end
end
