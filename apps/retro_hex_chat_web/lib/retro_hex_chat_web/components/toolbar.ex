defmodule RetroHexChatWeb.Components.Toolbar do
  @moduledoc """
  Toolbar with Connect/Disconnect, Channel List, Settings buttons.
  Each button has a 16x16 inline SVG icon alongside the text label.
  """
  use Phoenix.Component

  attr :connected, :boolean, default: false

  @spec toolbar(map()) :: Phoenix.LiveView.Rendered.t()
  def toolbar(assigns) do
    ~H"""
    <div class="toolbar" role="toolbar">
      <button
        :if={@connected}
        type="button"
        class="toolbar-btn"
        data-testid="toolbar-disconnect"
        phx-click="disconnect"
      >
        <svg viewBox="0 0 16 16" fill="currentColor">
          <path d="M11 3l2.5 2.5-3 3L13 11l-2.5 2.5L8 11l-3 3L2.5 11.5 5.5 8.5l-3-3L5 3l3 3 3-3z" />
        </svg>
        Disconnect
      </button>
      <button
        :if={!@connected}
        type="button"
        class="toolbar-btn"
        data-testid="toolbar-connect"
        phx-click="connect"
      >
        <svg viewBox="0 0 16 16" fill="currentColor">
          <path d="M10 2l4 4-3 3 1 1 2-2 1 1-4 4-1-1 2-2-1-1-3 3-4-4 3-3-1-1-2 2-1-1 4-4 1 1-2 2 1 1z" />
        </svg>
        Connect
      </button>
      <button
        type="button"
        class="toolbar-btn"
        data-testid="toolbar-channel-list"
        phx-click="channel_list"
      >
        <svg viewBox="0 0 16 16" fill="currentColor">
          <path d="M2 3h12v2H2V3zm0 4h12v2H2V7zm0 4h8v2H2v-2z" />
          <text x="11" y="14" font-size="7" font-weight="bold" font-family="sans-serif">#</text>
        </svg>
        Channel List
      </button>
      <button type="button" class="toolbar-btn" data-testid="toolbar-settings" phx-click="settings">
        <svg viewBox="0 0 16 16" fill="currentColor">
          <path d="M6.5 1h3l.5 2.1a5.5 5.5 0 0 1 1.3.7L13.3 3l1.5 2.6-1.5 1.5c.1.3.1.6.1.9s0 .6-.1.9l1.5 1.5L13.3 13l-2-.8a5.5 5.5 0 0 1-1.3.7L9.5 15h-3l-.5-2.1a5.5 5.5 0 0 1-1.3-.7L2.7 13 1.2 10.4l1.5-1.5A5.3 5.3 0 0 1 2.6 8c0-.3 0-.6.1-.9L1.2 5.6 2.7 3l2 .8a5.5 5.5 0 0 1 1.3-.7L6.5 1zM8 5.5a2.5 2.5 0 1 0 0 5 2.5 2.5 0 0 0 0-5z" />
        </svg>
        Settings
      </button>
      <button
        type="button"
        class="toolbar-btn"
        data-testid="toolbar-address-book"
        phx-click="toggle_address_book"
      >
        <svg viewBox="0 0 16 16" fill="currentColor">
          <path d="M3 1h10a1 1 0 0 1 1 1v12a1 1 0 0 1-1 1H3a1 1 0 0 1-1-1V2a1 1 0 0 1 1-1zm1 2v10h8V3H4zm2 2h4v1H6V5zm0 2h4v1H6V7zm0 2h3v1H6V9z" />
          <rect x="1" y="4" width="2" height="2" rx="0.5" />
          <rect x="1" y="8" width="2" height="2" rx="0.5" />
        </svg>
        Address Book
      </button>
    </div>
    """
  end
end
