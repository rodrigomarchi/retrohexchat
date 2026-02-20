defmodule RetroHexChatWeb.Components.Toolbar do
  @moduledoc """
  All-in-one toolbar with 24 retro-styled colorful SVG icon buttons.
  Replaces the former menu bar + toolbar with a single toolbar row.
  """
  use Phoenix.Component

  attr :connected, :boolean, default: false
  attr :dnd_enabled, :boolean, default: false
  attr :notification_count, :integer, default: 0
  @spec toolbar(map()) :: Phoenix.LiveView.Rendered.t()
  def toolbar(assigns) do
    ~H"""
    <div class="toolbar" role="toolbar">
      {connection_group(assigns)}
      <span class="toolbar-separator"></span>
      {view_group(assigns)}
      <span class="toolbar-separator"></span>
      {tools_group(assigns)}
      <span class="toolbar-separator"></span>
      {notifications_group(assigns)}
      <span class="toolbar-separator"></span>
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
      <svg viewBox="0 0 16 16">
        <circle cx="4" cy="8" r="2.5" fill="#000080" />
        <circle cx="12" cy="8" r="2.5" fill="#000080" />
        <line x1="6" y1="8" x2="10" y2="8" stroke="#C0C0C0" stroke-width="1.5" />
        <line x1="5" y1="5" x2="11" y2="11" stroke="#FF0000" stroke-width="2" />
        <line x1="11" y1="5" x2="5" y2="11" stroke="#FF0000" stroke-width="2" />
      </svg>
    </button>
    <button
      :if={!@connected}
      type="button"
      class="toolbar-btn"
      title="Connect"
      data-testid="toolbar-connect"
      phx-click="connect"
    >
      <svg viewBox="0 0 16 16">
        <circle cx="4" cy="8" r="2.5" fill="#000080" />
        <circle cx="12" cy="8" r="2.5" fill="#000080" />
        <path d="M7 6l2-2 2 2-1 1-1-1v6l1-1 1 1-2 2-2-2 1-1 1 1V6L7 7z" fill="#FFD700" />
      </svg>
    </button>
    """
  end

  defp view_group(assigns) do
    ~H"""
    <button
      type="button"
      class="toolbar-btn"
      title="Channel List"
      data-testid="toolbar-channel-list"
      phx-click="channel_list"
    >
      <svg viewBox="0 0 16 16">
        <rect x="2" y="3" width="10" height="1.5" fill="#000080" />
        <rect x="2" y="7" width="10" height="1.5" fill="#000080" />
        <rect x="2" y="11" width="7" height="1.5" fill="#000080" />
        <text x="11" y="14" font-size="7" font-weight="bold" font-family="sans-serif" fill="#000080">
          #
        </text>
      </svg>
    </button>
    <button
      type="button"
      class="toolbar-btn"
      title="Toggle Treebar"
      data-testid="toolbar-toggle-treebar"
      phx-click="toggle_treebar"
    >
      <svg viewBox="0 0 16 16">
        <rect
          x="1"
          y="1"
          width="14"
          height="14"
          rx="1"
          fill="#C0C0C0"
          stroke="#808080"
          stroke-width="1"
        />
        <rect x="2" y="2" width="5" height="12" fill="#000080" />
        <line x1="3" y1="5" x2="6" y2="5" stroke="#fff" stroke-width="1" />
        <line x1="3" y1="7" x2="6" y2="7" stroke="#fff" stroke-width="1" />
        <line x1="3" y1="9" x2="6" y2="9" stroke="#fff" stroke-width="1" />
      </svg>
    </button>
    <button
      type="button"
      class="toolbar-btn"
      title="Toggle Nicklist"
      data-testid="toolbar-toggle-nicklist"
      phx-click="toggle_nicklist"
    >
      <svg viewBox="0 0 16 16">
        <rect
          x="1"
          y="1"
          width="14"
          height="14"
          rx="1"
          fill="#C0C0C0"
          stroke="#808080"
          stroke-width="1"
        />
        <rect x="9" y="2" width="5" height="12" fill="#008000" />
        <circle cx="11.5" cy="5" r="1.5" fill="#fff" />
        <path d="M10 8.5c0-1 1-1.5 1.5-1.5s1.5.5 1.5 1.5v1.5h-3z" fill="#fff" />
        <circle cx="11.5" cy="11" r="1.5" fill="#fff" />
      </svg>
    </button>
    <button
      type="button"
      class="toolbar-btn"
      title="Find"
      data-testid="toolbar-find"
      phx-click="open_search"
    >
      <svg viewBox="0 0 16 16">
        <circle cx="7" cy="7" r="4" fill="none" stroke="#000080" stroke-width="2" />
        <line
          x1="10"
          y1="10"
          x2="14"
          y2="14"
          stroke="#FFD700"
          stroke-width="2.5"
          stroke-linecap="round"
        />
      </svg>
    </button>
    """
  end

  defp tools_group(assigns) do
    ~H"""
    <button
      type="button"
      class="toolbar-btn"
      title="Address Book"
      data-testid="toolbar-address-book"
      phx-click="toggle_address_book"
    >
      <svg viewBox="0 0 16 16">
        <rect x="3" y="1" width="10" height="14" rx="1" fill="#000080" />
        <rect x="4" y="2" width="8" height="12" fill="#FFD700" />
        <line x1="5" y1="5" x2="11" y2="5" stroke="#000080" stroke-width="1" />
        <line x1="5" y1="7" x2="11" y2="7" stroke="#000080" stroke-width="1" />
        <line x1="5" y1="9" x2="9" y2="9" stroke="#000080" stroke-width="1" />
        <rect x="1" y="4" width="2" height="2" rx="0.5" fill="#FF0000" />
        <rect x="1" y="8" width="2" height="2" rx="0.5" fill="#FF0000" />
      </svg>
    </button>
    <button
      type="button"
      class="toolbar-btn"
      title="Highlight Words"
      data-testid="toolbar-highlight"
      phx-click="open_highlight_dialog"
    >
      <svg viewBox="0 0 16 16">
        <rect x="2" y="10" width="12" height="3" rx="0.5" fill="#FFD700" opacity="0.7" />
        <path d="M10 2l2 8H8L6 2z" fill="#000080" />
        <rect x="7" y="9" width="6" height="2" fill="#FFD700" />
      </svg>
    </button>
    <button
      type="button"
      class="toolbar-btn"
      title="Ignore List"
      data-testid="toolbar-ignore-list"
      phx-click="open_ignore_dialog"
    >
      <svg viewBox="0 0 16 16">
        <circle cx="8" cy="5" r="3" fill="#808080" />
        <path d="M4 12c0-2.5 2-4 4-4s4 1.5 4 4z" fill="#808080" />
        <circle cx="8" cy="8" r="5.5" fill="none" stroke="#FF0000" stroke-width="1.5" />
        <line x1="4.5" y1="4.5" x2="11.5" y2="11.5" stroke="#FF0000" stroke-width="1.5" />
      </svg>
    </button>
    <button
      type="button"
      class="toolbar-btn"
      title="URL Catcher"
      data-testid="toolbar-url-catcher"
      phx-click="toggle_url_catcher"
    >
      <svg viewBox="0 0 16 16">
        <circle cx="8" cy="8" r="6" fill="none" stroke="#000080" stroke-width="1.5" />
        <ellipse cx="8" cy="8" rx="3" ry="6" fill="none" stroke="#000080" stroke-width="1" />
        <line x1="2" y1="8" x2="14" y2="8" stroke="#000080" stroke-width="1" />
        <line x1="8" y1="2" x2="8" y2="14" stroke="#000080" stroke-width="1" />
        <circle cx="8" cy="8" r="1.5" fill="#008000" />
      </svg>
    </button>
    <button
      type="button"
      class="toolbar-btn"
      title="Channel Central"
      data-testid="toolbar-channel-central"
      phx-click="open_channel_central"
    >
      <svg viewBox="0 0 16 16">
        <rect x="3" y="6" width="10" height="9" fill="#808080" />
        <rect x="4" y="7" width="3" height="3" fill="#87CEEB" />
        <rect x="9" y="7" width="3" height="3" fill="#87CEEB" />
        <rect x="7" y="11" width="2" height="4" fill="#8B4513" />
        <polygon points="2,6 8,1 14,6" fill="#FF0000" />
        <line x1="8" y1="1" x2="8" y2="-1" stroke="#808080" stroke-width="1.5" />
        <circle cx="8" cy="-1" r="1" fill="#FF0000" />
      </svg>
    </button>
    <button
      type="button"
      class="toolbar-btn"
      title="Log Viewer"
      data-testid="toolbar-log-viewer"
      phx-click="open_log_viewer"
    >
      <svg viewBox="0 0 16 16">
        <rect x="2" y="1" width="12" height="14" rx="1" fill="#fff" stroke="#808080" stroke-width="1" />
        <line x1="4" y1="4" x2="12" y2="4" stroke="#000080" stroke-width="1" />
        <line x1="4" y1="6" x2="12" y2="6" stroke="#000080" stroke-width="1" />
        <line x1="4" y1="8" x2="12" y2="8" stroke="#000080" stroke-width="1" />
        <line x1="4" y1="10" x2="9" y2="10" stroke="#000080" stroke-width="1" />
      </svg>
    </button>
    <button
      type="button"
      class="toolbar-btn"
      title="Perform"
      data-testid="toolbar-perform"
      phx-click="open_perform_dialog"
    >
      <svg viewBox="0 0 16 16">
        <polygon points="3,2 13,8 3,14" fill="#008000" />
        <circle cx="12" cy="4" r="3" fill="none" stroke="#808080" stroke-width="1.5" />
        <circle cx="12" cy="4" r="1" fill="#808080" />
      </svg>
    </button>
    <button
      type="button"
      class="toolbar-btn"
      title="Sounds"
      data-testid="toolbar-sounds"
      phx-click="open_sound_settings_dialog"
    >
      <svg viewBox="0 0 16 16">
        <path d="M2 6h3l4-4v12l-4-4H2z" fill="#000080" />
        <path d="M11 5.5c1 1 1 4 0 5" fill="none" stroke="#FFD700" stroke-width="1.5" />
        <path d="M13 3.5c2 2 2 7 0 9" fill="none" stroke="#FFD700" stroke-width="1.5" />
      </svg>
    </button>
    <button
      type="button"
      class="toolbar-btn"
      title="CTCP Settings"
      data-testid="toolbar-ctcp-settings"
      phx-click="open_ctcp_settings_dialog"
    >
      <svg viewBox="0 0 16 16">
        <path d="M2 8h5" stroke="#008000" stroke-width="2" />
        <polygon points="7,6 10,8 7,10" fill="#008000" />
        <path d="M14 8h-5" stroke="#000080" stroke-width="2" />
        <polygon points="9,6 6,8 9,10" fill="#000080" />
      </svg>
    </button>
    <button
      type="button"
      class="toolbar-btn"
      title="Flood Protection"
      data-testid="toolbar-flood-protection"
      phx-click="open_flood_protection_dialog"
    >
      <svg viewBox="0 0 16 16">
        <path d="M8 1L2 6v5c0 3 3 4.5 6 4.5s6-1.5 6-4.5V6z" fill="#000080" />
        <path d="M8 3L4 6.5v4c0 2 2 3 4 3s4-1 4-3v-4z" fill="#fff" />
        <path d="M7 7h2v3H7z" fill="#000080" />
        <circle cx="8" cy="11" r="1" fill="#000080" />
      </svg>
    </button>
    <button
      type="button"
      class="toolbar-btn"
      title="Alias Editor"
      data-testid="toolbar-alias-editor"
      phx-click="open_alias_dialog"
    >
      <svg viewBox="0 0 16 16">
        <text x="1" y="11" font-size="10" font-weight="bold" font-family="sans-serif" fill="#000080">
          A=
        </text>
        <line x1="10" y1="3" x2="14" y2="13" stroke="#FFD700" stroke-width="2" stroke-linecap="round" />
        <polygon points="14,13 12,14 13,11" fill="#FFD700" />
      </svg>
    </button>
    <button
      type="button"
      class="toolbar-btn"
      title="Custom Menus"
      data-testid="toolbar-custom-menus"
      phx-click="open_custom_menus_dialog"
    >
      <svg viewBox="0 0 16 16">
        <rect x="2" y="2" width="10" height="2" fill="#808080" />
        <rect x="2" y="5" width="10" height="2" fill="#808080" />
        <rect x="2" y="8" width="10" height="2" fill="#808080" />
        <polygon points="11,11 14,13.5 11,16" fill="#FFD700" stroke="#FF8C00" stroke-width="0.5" />
      </svg>
    </button>
    <button
      type="button"
      class="toolbar-btn"
      title="Auto-Respond"
      data-testid="toolbar-autorespond"
      phx-click="open_autorespond_dialog"
    >
      <svg viewBox="0 0 16 16">
        <path d="M2 3h10v7H6l-2 2v-2H2z" fill="#000080" />
        <path d="M3 4h8v5H6l-1 1v-1H3z" fill="#87CEEB" />
        <path d="M7 6l1.5-2 1.5 2h-1v2H8V6z" fill="#FFD700" />
      </svg>
    </button>
    <button
      type="button"
      class="toolbar-btn"
      title="Settings"
      data-testid="toolbar-settings"
      phx-click="settings"
    >
      <svg viewBox="0 0 16 16">
        <path
          d="M6.5 1h3l.5 2.1a5.5 5.5 0 0 1 1.3.7L13.3 3l1.5 2.6-1.5 1.5c.1.3.1.6.1.9s0 .6-.1.9l1.5 1.5L13.3 13l-2-.8a5.5 5.5 0 0 1-1.3.7L9.5 15h-3l-.5-2.1a5.5 5.5 0 0 1-1.3-.7L2.7 13 1.2 10.4l1.5-1.5A5.3 5.3 0 0 1 2.6 8c0-.3 0-.6.1-.9L1.2 5.6 2.7 3l2 .8a5.5 5.5 0 0 1 1.3-.7L6.5 1z"
          fill="#808080"
        />
        <circle cx="8" cy="8" r="2" fill="#000080" />
      </svg>
    </button>
    """
  end

  defp notifications_group(assigns) do
    ~H"""
    <button
      type="button"
      class={"toolbar-btn#{if @dnd_enabled, do: " toolbar-btn--active", else: ""}"}
      title={if @dnd_enabled, do: "Disable Do Not Disturb", else: "Do Not Disturb"}
      data-testid="toolbar-dnd"
      phx-click="toggle_dnd"
    >
      <svg viewBox="0 0 16 16">
        <path
          d="M12 2a5 5 0 0 1 0 10c-1.3 0-2.5-.5-3.4-1.3A6.9 6.9 0 0 0 10 6a6.9 6.9 0 0 0-1.4-4.7A5 5 0 0 1 12 2z"
          fill="#000080"
        />
        <path :if={@dnd_enabled} d="M1 14L14 1" stroke="#FF0000" stroke-width="2" />
      </svg>
    </button>
    <button
      type="button"
      class="toolbar-btn toolbar-btn--bell"
      title="Notification Center"
      data-testid="toolbar-bell"
      phx-click="toggle_notification_center"
    >
      <svg viewBox="0 0 16 16">
        <path
          d="M8 1a1 1 0 0 1 1 1v1a4 4 0 0 1 3 3.87V10l2 2H2l2-2V6.87A4 4 0 0 1 7 3V2a1 1 0 0 1 1-1z"
          fill="#FFD700"
        />
        <path d="M6.5 13a1.5 1.5 0 0 0 3 0h-3z" fill="#FFD700" />
      </svg>
      <span
        :if={@notification_count > 0}
        class="toolbar-badge"
        data-testid="notification-badge"
      >
        {if @notification_count > 99, do: "99+", else: @notification_count}
      </span>
    </button>
    """
  end

  defp help_group(assigns) do
    ~H"""
    <a
      class="toolbar-btn"
      title="Help Topics"
      data-testid="toolbar-help"
      href="/chat/help"
      target="_blank"
    >
      <svg viewBox="0 0 16 16">
        <circle cx="8" cy="8" r="7" fill="#000080" />
        <text
          x="8"
          y="12"
          text-anchor="middle"
          font-size="11"
          font-weight="bold"
          font-family="sans-serif"
          fill="#fff"
        >
          ?
        </text>
      </svg>
    </a>
    """
  end
end
