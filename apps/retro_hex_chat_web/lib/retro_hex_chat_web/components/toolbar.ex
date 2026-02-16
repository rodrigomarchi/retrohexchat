defmodule RetroHexChatWeb.Components.Toolbar do
  @moduledoc """
  Toolbar with Connect/Disconnect, Channel List, Settings buttons.
  Icon-only buttons with tooltips (mIRC style).
  """
  use Phoenix.Component

  attr :connected, :boolean, default: false
  attr :dnd_enabled, :boolean, default: false
  attr :notification_count, :integer, default: 0

  @spec toolbar(map()) :: Phoenix.LiveView.Rendered.t()
  def toolbar(assigns) do
    ~H"""
    <div class="toolbar" role="toolbar">
      <button
        :if={@connected}
        type="button"
        class="toolbar-btn"
        title="Disconnect"
        data-testid="toolbar-disconnect"
        phx-click="disconnect"
      >
        <svg viewBox="0 0 16 16" fill="currentColor">
          <path d="M11 3l2.5 2.5-3 3L13 11l-2.5 2.5L8 11l-3 3L2.5 11.5 5.5 8.5l-3-3L5 3l3 3 3-3z" />
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
        <svg viewBox="0 0 16 16" fill="currentColor">
          <path d="M10 2l4 4-3 3 1 1 2-2 1 1-4 4-1-1 2-2-1-1-3 3-4-4 3-3-1-1-2 2-1-1 4-4 1 1-2 2 1 1z" />
        </svg>
      </button>
      <button
        type="button"
        class="toolbar-btn"
        title="Channel List"
        data-testid="toolbar-channel-list"
        phx-click="channel_list"
      >
        <svg viewBox="0 0 16 16" fill="currentColor">
          <path d="M2 3h12v2H2V3zm0 4h12v2H2V7zm0 4h8v2H2v-2z" />
          <text x="11" y="14" font-size="7" font-weight="bold" font-family="sans-serif">#</text>
        </svg>
      </button>
      <button
        type="button"
        class="toolbar-btn"
        title="Settings"
        data-testid="toolbar-settings"
        phx-click="settings"
      >
        <svg viewBox="0 0 16 16" fill="currentColor">
          <path d="M6.5 1h3l.5 2.1a5.5 5.5 0 0 1 1.3.7L13.3 3l1.5 2.6-1.5 1.5c.1.3.1.6.1.9s0 .6-.1.9l1.5 1.5L13.3 13l-2-.8a5.5 5.5 0 0 1-1.3.7L9.5 15h-3l-.5-2.1a5.5 5.5 0 0 1-1.3-.7L2.7 13 1.2 10.4l1.5-1.5A5.3 5.3 0 0 1 2.6 8c0-.3 0-.6.1-.9L1.2 5.6 2.7 3l2 .8a5.5 5.5 0 0 1 1.3-.7L6.5 1zM8 5.5a2.5 2.5 0 1 0 0 5 2.5 2.5 0 0 0 0-5z" />
        </svg>
      </button>
      <button
        type="button"
        class="toolbar-btn"
        title="Address Book"
        data-testid="toolbar-address-book"
        phx-click="toggle_address_book"
      >
        <svg viewBox="0 0 16 16" fill="currentColor">
          <path d="M3 1h10a1 1 0 0 1 1 1v12a1 1 0 0 1-1 1H3a1 1 0 0 1-1-1V2a1 1 0 0 1 1-1zm1 2v10h8V3H4zm2 2h4v1H6V5zm0 2h4v1H6V7zm0 2h3v1H6V9z" />
          <rect x="1" y="4" width="2" height="2" rx="0.5" />
          <rect x="1" y="8" width="2" height="2" rx="0.5" />
        </svg>
      </button>
      <button
        type="button"
        class="toolbar-btn"
        title="Log Viewer"
        data-testid="toolbar-log-viewer"
        phx-click="open_log_viewer"
      >
        <svg viewBox="0 0 16 16" fill="currentColor">
          <path d="M2 2h12v12H2V2zm1 1v10h10V3H3zm1 1h8v1H4V4zm0 2h8v1H4V6zm0 2h8v1H4V8zm0 2h5v1H4v-1z" />
        </svg>
      </button>
      <span class="toolbar-separator"></span>
      <button
        type="button"
        class={"toolbar-btn#{if @dnd_enabled, do: " toolbar-btn--active", else: ""}"}
        title={if @dnd_enabled, do: "Disable Do Not Disturb", else: "Do Not Disturb"}
        data-testid="toolbar-dnd"
        phx-click="toggle_dnd"
      >
        <svg viewBox="0 0 16 16" fill="currentColor">
          <path d="M12 2a5 5 0 0 1 0 10c-1.3 0-2.5-.5-3.4-1.3A6.9 6.9 0 0 0 10 6a6.9 6.9 0 0 0-1.4-4.7A5 5 0 0 1 12 2z" />
          <path :if={@dnd_enabled} d="M1 14L14 1" stroke="currentColor" stroke-width="2" />
        </svg>
      </button>
      <button
        type="button"
        class="toolbar-btn toolbar-btn--bell"
        title="Notification Center"
        data-testid="toolbar-bell"
        phx-click="toggle_notification_center"
      >
        <svg viewBox="0 0 16 16" fill="currentColor">
          <path d="M8 1a1 1 0 0 1 1 1v1a4 4 0 0 1 3 3.87V10l2 2H2l2-2V6.87A4 4 0 0 1 7 3V2a1 1 0 0 1 1-1zM6.5 13a1.5 1.5 0 0 0 3 0h-3z" />
        </svg>
        <span
          :if={@notification_count > 0}
          class="toolbar-badge"
          data-testid="notification-badge"
        >
          {if @notification_count > 99, do: "99+", else: @notification_count}
        </span>
      </button>
    </div>
    """
  end
end
