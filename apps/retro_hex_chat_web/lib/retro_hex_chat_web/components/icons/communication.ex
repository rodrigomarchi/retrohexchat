defmodule RetroHexChatWeb.Icons.Communication do
  @moduledoc """
  Icons depicting messaging, networking, and communication concepts.
  """
  use Phoenix.Component

  attr :class, :string, default: nil

  @spec icon_p2p(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_p2p(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <circle cx="4" cy="8" r="2.5" fill="#000080" />
      <circle cx="12" cy="8" r="2.5" fill="#000080" />
      <line x1="6.5" y1="7" x2="9.5" y2="7" stroke="#008000" stroke-width="1.5" />
      <line x1="6.5" y1="9" x2="9.5" y2="9" stroke="#008000" stroke-width="1.5" />
      <polygon points="10,5.5 12,7 10,8.5" fill="#008000" />
      <polygon points="6,7.5 4,9 6,10.5" fill="#008000" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_chat(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_chat(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <path d="M2 2h12v9H6l-3 3v-3H2z" fill="#000080" />
      <path d="M3 3h10v7H6l-2 2v-2H3z" fill="#fff" />
      <line x1="5" y1="5.5" x2="11" y2="5.5" stroke="#000080" stroke-width="1" />
      <line x1="5" y1="7.5" x2="9" y2="7.5" stroke="#000080" stroke-width="1" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_channels(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_channels(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <rect x="1" y="2" width="6" height="5" rx="0.5" fill="#000080" />
      <rect x="9" y="2" width="6" height="5" rx="0.5" fill="#008080" />
      <rect x="1" y="9" width="6" height="5" rx="0.5" fill="#008080" />
      <rect x="9" y="9" width="6" height="5" rx="0.5" fill="#000080" />
      <text x="4" y="6" text-anchor="middle" font-size="4" font-family="sans-serif" fill="#fff">
        #
      </text>
      <text x="12" y="6" text-anchor="middle" font-size="4" font-family="sans-serif" fill="#fff">
        #
      </text>
      <text x="4" y="13" text-anchor="middle" font-size="4" font-family="sans-serif" fill="#fff">
        #
      </text>
      <text x="12" y="13" text-anchor="middle" font-size="4" font-family="sans-serif" fill="#fff">
        #
      </text>
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_websocket(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_websocket(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <path d="M2 8c2-4 4-4 6 0s4 4 6 0" fill="none" stroke="#008000" stroke-width="2" />
      <circle cx="2" cy="8" r="1.5" fill="#000080" />
      <circle cx="14" cy="8" r="1.5" fill="#000080" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_webrtc(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_webrtc(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <polygon points="2,4 7,4 7,12 2,12" fill="#000080" />
      <polygon points="7,6 11,4 11,12 7,10" fill="#008080" />
      <circle cx="13" cy="5" r="1.5" fill="#FF0000" />
      <circle cx="13" cy="11" r="0.8" fill="#FF0000" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_megaphone(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_megaphone(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <polygon points="3,6 3,10 6,10 11,13 11,3 6,6" fill="#000080" />
      <rect x="11" y="6" width="3" height="1" fill="#FFD700" stroke="#B8860B" stroke-width="0.3" />
      <rect x="11" y="9" width="3" height="1" fill="#FFD700" stroke="#B8860B" stroke-width="0.3" />
      <rect x="12" y="7" width="2" height="2" fill="#FFD700" stroke="#B8860B" stroke-width="0.3" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_send(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_send(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <polygon points="2,2 14,8 2,14 4,8" fill="#000080" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_dialog_invite(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_dialog_invite(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <path d="M1 4l7 4 7-4v9H1z" fill="#fff" stroke="#555" stroke-width="1" />
      <line x1="1" y1="4" x2="8" y2="9" stroke="#555" stroke-width="1" />
      <line x1="15" y1="4" x2="8" y2="9" stroke="#555" stroke-width="1" />
      <polygon
        points="12,1 12.8,3 15,3 13.2,4.2 13.8,6.5 12,5.2 10.2,6.5 10.8,4.2 9,3 11.2,3"
        fill="#FFD700"
        stroke="#000"
        stroke-width="0.3"
      />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_dialog_url(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_dialog_url(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <circle cx="8" cy="8" r="6.5" fill="none" stroke="#000080" stroke-width="1" />
      <ellipse cx="8" cy="8" rx="3" ry="6.5" fill="none" stroke="#000080" stroke-width="0.8" />
      <line x1="1.5" y1="8" x2="14.5" y2="8" stroke="#000080" stroke-width="0.8" />
      <line x1="3" y1="4.5" x2="13" y2="4.5" stroke="#000080" stroke-width="0.6" />
      <line x1="3" y1="11.5" x2="13" y2="11.5" stroke="#000080" stroke-width="0.6" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_tab_pm(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_tab_pm(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <rect x="1" y="4" width="14" height="9" rx="1" fill="none" stroke="#000080" stroke-width="1.2" />
      <polyline points="1,4 8,9.5 15,4" fill="none" stroke="#000080" stroke-width="1.2" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_tab_conversations(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_tab_conversations(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <path d="M2 2h12v8H6l-3 3v-3H2z" fill="#000080" />
      <line x1="5" y1="5" x2="11" y2="5" stroke="#fff" stroke-width="1" />
      <line x1="5" y1="7.5" x2="9" y2="7.5" stroke="#fff" stroke-width="1" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_tab_autojoin(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_tab_autojoin(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <text
        x="8"
        y="12"
        text-anchor="middle"
        font-size="12"
        font-weight="bold"
        font-family="sans-serif"
        fill="#000080"
      >
        #
      </text>
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_link(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_link(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <path
        d="M6.5 9.5l3-3"
        fill="none"
        stroke="#000080"
        stroke-width="1.5"
        stroke-linecap="round"
      />
      <path
        d="M7 10l-1.5 1.5a2 2 0 0 1-2.8-2.8L4.2 7.2"
        fill="none"
        stroke="#000080"
        stroke-width="1.5"
        stroke-linecap="round"
      />
      <path
        d="M9 6l1.5-1.5a2 2 0 0 1 2.8 2.8L11.8 8.8"
        fill="none"
        stroke="#000080"
        stroke-width="1.5"
        stroke-linecap="round"
      />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_tab_channel(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_tab_channel(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <rect x="1" y="2" width="14" height="10" rx="1" fill="#000080" />
      <rect x="2" y="3" width="12" height="8" rx="0.5" fill="#fff" />
      <line x1="4" y1="5.5" x2="10" y2="5.5" stroke="#000080" stroke-width="1" />
      <line x1="4" y1="8" x2="8" y2="8" stroke="#000080" stroke-width="1" />
      <polygon points="5,12 8,15 11,12" fill="#000080" />
    </svg>
    """
  end
end
