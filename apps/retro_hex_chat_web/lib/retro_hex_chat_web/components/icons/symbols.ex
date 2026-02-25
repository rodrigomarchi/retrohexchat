defmodule RetroHexChatWeb.Icons.Symbols do
  @moduledoc """
  Icons depicting abstract symbols, currency, and miscellaneous concepts.
  """
  use Phoenix.Component

  attr :class, :string, default: nil

  @spec icon_dollar(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_dollar(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Shadow -->
      <circle cx="17" cy="17" r="13" fill="#000" />
      <!-- Base Circle (Gold) -->
      <circle cx="16" cy="16" r="13" fill="#FFD700" stroke="#000" stroke-width="1.5" />
      
      <!-- Bevel -->
      <path d="M16 4 A 12 12 0 0 0 4 16" fill="none" stroke="#fff" stroke-width="2" opacity="0.6" stroke-linecap="round" />
      
      <text
        x="16"
        y="23"
        text-anchor="middle"
        font-size="20"
        font-weight="bold"
        font-family="sans-serif"
        fill="#000"
      >
        $
      </text>
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_star(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_star(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Shadow -->
      <polygon
        points="16,4 20,12 29,13 22,19 24,28 16,23 8,28 10,19 3,13 12,12"
        fill="#000"
        transform="translate(1,1)"
        stroke-linejoin="round"
      />
      
      <!-- Base Star (Gold) -->
      <polygon
        points="16,4 20,12 29,13 22,19 24,28 16,23 8,28 10,19 3,13 12,12"
        fill="#FFD700"
        stroke="#000"
        stroke-width="1.5"
        stroke-linejoin="round"
      />
      <!-- Inner Bevel Highlights -->
      <path d="M16 4 L 12 12 L 3 13 L 10 19 L 8 28 L 16 23" fill="none" stroke="#fff" stroke-width="1.5" opacity="0.6" stroke-linejoin="round" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_bug(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_bug(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Legs Shadow -->
      <path d="M10 17 l -6 -2 M22 17 l 6 -2 M10 24 l -6 2 M22 24 l 6 2 M12 10 l -4 -4 M20 10 l 4 -4" fill="none" stroke="#000" stroke-width="2" stroke-linecap="round" transform="translate(1,1)" />
      <!-- Legs -->
      <path d="M10 17 l -6 -2 M22 17 l 6 -2 M10 24 l -6 2 M22 24 l 6 2 M12 10 l -4 -4 M20 10 l 4 -4" fill="none" stroke="#555" stroke-width="2" stroke-linecap="round" />
      
      <!-- Body Shadow -->
      <ellipse cx="17" cy="19" rx="7" ry="9" fill="#000" />
      <circle cx="17" cy="11" r="4" fill="#000" />
      
      <!-- Body -->
      <ellipse cx="16" cy="18" rx="7" ry="9" fill="#008000" stroke="#000" stroke-width="1.5" />
      <!-- Head -->
      <circle cx="16" cy="10" r="4" fill="#008000" stroke="#000" stroke-width="1.5" />
      
      <!-- Details -->
      <line x1="16" y1="13" x2="16" y2="25" stroke="#000" stroke-width="1.5" />
      <!-- Bevel Highlight -->
      <path d="M13 13 C 10 15 10 20 13 22" fill="none" stroke="#fff" stroke-width="1.5" opacity="0.6" stroke-linecap="round" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_heart(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_heart(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Shadow -->
      <path
        d="M16 28s-10-7-10-14c0-4 3-7 6-7 2 0 3.4 1 4 2.6c0.6-1.6 2-2.6 4-2.6 3 0 6 3 6 7 0 7-10 14-10 14z"
        fill="#000"
        transform="translate(1,1)"
      />
      <!-- Base Heart (Red) -->
      <path
        d="M16 28s-10-7-10-14c0-4 3-7 6-7 2 0 3.4 1 4 2.6c0.6-1.6 2-2.6 4-2.6 3 0 6 3 6 7 0 7-10 14-10 14z"
        fill="#FF0000"
        stroke="#000"
        stroke-width="1.5"
        stroke-linejoin="round"
      />
      <!-- Reflection -->
      <path d="M9 13 C9 9 12 8 14 9" fill="none" stroke="#fff" stroke-width="2" opacity="0.6" stroke-linecap="round" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_legal(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_legal(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Shadow -->
      <path d="M14 4 h 4 v 20 h -4 z M6 10 h 20 M6 14 c 0 4 6 4 6 4 M20 14 c 0 4 6 4 6 4 M10 24 h 12 v 4 h -12 z" fill="none" stroke="#000" stroke-width="4" stroke-linecap="round" stroke-linejoin="round" transform="translate(1,1)" />
      
      <!-- Central Pole -->
      <rect x="14" y="4" width="4" height="20" fill="#C0C0C0" stroke="#000" stroke-width="1.5" />
      <path d="M15 5 v 18" stroke="#fff" stroke-width="1" opacity="0.6" />
      
      <!-- Top Beam -->
      <line x1="6" y1="10" x2="26" y2="10" stroke="#000" stroke-width="3" stroke-linecap="round" />
      <line x1="6" y1="10" x2="26" y2="10" stroke="#808080" stroke-width="1" stroke-linecap="round" />
      
      <!-- Left Pan -->
      <path d="M6 14 c 0 6 6 6 6 6" fill="none" stroke="#FFD700" stroke-width="2" stroke-linecap="round" />
      <path d="M5 19 c 0 4 8 4 8 0 z" fill="#FFD700" stroke="#000" stroke-width="1.5" stroke-linejoin="round" />
      
      <!-- Right Pan -->
      <path d="M20 14 c 0 6 6 6 6 6" fill="none" stroke="#FFD700" stroke-width="2" stroke-linecap="round" />
      <path d="M19 19 c 0 4 8 4 8 0 z" fill="#FFD700" stroke="#000" stroke-width="1.5" stroke-linejoin="round" />
      
      <!-- Base -->
      <rect x="10" y="24" width="12" height="4" rx="1" fill="#C0C0C0" stroke="#000" stroke-width="1.5" />
      <path d="M11 25 h 10" stroke="#fff" stroke-width="1" opacity="0.6" stroke-linecap="round" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_clock(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_clock(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Shadow -->
      <circle cx="17" cy="17" r="13" fill="#000" />
      
      <!-- Base Circle (White) -->
      <circle cx="16" cy="16" r="13" fill="#fff" stroke="#000" stroke-width="1.5" />
      <circle cx="16" cy="16" r="13" fill="none" stroke="#000080" stroke-width="2" />
      
      <!-- Bevel Highlights -->
      <path d="M16 4 A 12 12 0 0 0 4 16" fill="none" stroke="#fff" stroke-width="2" opacity="0.8" stroke-linecap="round" />
      <path d="M16 28 A 12 12 0 0 0 28 16" fill="none" stroke="#000" stroke-width="2" opacity="0.2" stroke-linecap="round" />
      
      <!-- Clock Hands -->
      <line x1="16" y1="8" x2="16" y2="16" stroke="#000" stroke-width="2" stroke-linecap="round" />
      <line x1="16" y1="16" x2="22" y2="20" stroke="#000" stroke-width="2" stroke-linecap="round" />
      
      <!-- Center Pin -->
      <circle cx="16" cy="16" r="1.5" fill="#FFD700" stroke="#000" stroke-width="1" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_status_signal(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_status_signal(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="3" y="10" width="3" height="4" fill="#000080" />
      <rect x="7" y="6" width="3" height="8" fill="#000080" />
      <rect x="11" y="2" width="3" height="12" fill="#000080" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_btn_ignore(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_ignore(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Shadow -->
      <polygon points="5,3 11,3 14,6 14,12 11,15 5,15 2,12 2,6" fill="#000" />
      
      <!-- Outer Octagon Shape (Ignore symbol background) -->
      <polygon points="5,2 11,2 14,5 14,11 11,14 5,14 2,11 2,5" fill="#808080" stroke="#000" stroke-width="1" />
      <polyline points="5,3 11,3" stroke="#fff" stroke-width="1" />
      
      <!-- Inner Shape and diagonal block -->
      <polygon points="6,4 10,4 12,6 12,10 10,12 6,12 4,10 4,6" fill="none" stroke="#fff" stroke-width="1" />
      <!-- Diagonal Stripe in Pixels -->
      <polygon points="11,5 12,6 6,12 5,11" fill="#fff" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_dialog_kick(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_dialog_kick(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Shadow -->
      <polygon points="6,3 12,3 15,6 15,12 12,15 6,15 3,12 3,6" fill="#000" />
      
      <!-- Red Octagon -->
      <polygon points="5,2 11,2 14,5 14,11 11,14 5,14 2,11 2,5" fill="#FF0000" stroke="#000" stroke-width="1" />
      <!-- Red Highlight -->
      <polygon points="5,3 11,3 13,5 5,5" fill="#FF6B6B" />
      
      <!-- ! marker (White) -->
      <rect x="7" y="4" width="2" height="5" fill="#fff" />
      <rect x="7" y="11" width="2" height="2" fill="#fff" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_tag(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_tag(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Shadow -->
      <path d="M4 2 h 13 L 28 13 L 17 24 L 6 13 z" fill="#000" transform="translate(1,1)" stroke-linejoin="round" />
      
      <!-- Base Tag (Gold) -->
      <path d="M4 2 h 13 L 28 13 L 17 24 L 4 11 z" fill="#FFD700" stroke="#000" stroke-width="1.5" stroke-linejoin="round" />
      
      <!-- Highlight -->
      <path d="M5 3 h 11 L 27 13 L 17 23 L 5 11 z" fill="none" stroke="#fff" stroke-width="1.5" opacity="0.6" stroke-linejoin="round" />
      
      <!-- String -->
      <path d="M10 9 C 15 4 24 6 28 2" fill="none" stroke="#C0C0C0" stroke-width="2" stroke-linecap="round" />
      <path d="M9.5 8.5 C 14.5 3.5 23.5 5.5 28.5 2" fill="none" stroke="#555" stroke-width="1" />
      
      <!-- Hole -->
      <circle cx="9" cy="8" r="3" fill="#000080" stroke="#000" stroke-width="1" />
      <circle cx="9" cy="8" r="1.5" fill="#fff" stroke="#000" stroke-width="1.5" />
    </svg>
    """
  end
end
