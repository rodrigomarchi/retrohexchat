defmodule RetroHexChatWeb.Icons.Security do
  @moduledoc """
  Icons depicting security, privacy, and access control concepts.
  """
  use Phoenix.Component

  attr :class, :string, default: nil

  @spec icon_lock(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_lock(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Shadow -->
      <path
        d="M10 14V10C10 6.7 12.7 4 16 4C19.3 4 22 6.7 22 10V14"
        fill="none"
        stroke="#000"
        stroke-width="4"
        transform="translate(1,1)"
      />
      <rect x="8" y="14" width="16" height="14" rx="2" fill="#000" transform="translate(1,1)" />
      
    <!-- Lock Shackle Base -->
      <path
        d="M10 14V10C10 6.7 12.7 4 16 4C19.3 4 22 6.7 22 10V14"
        fill="none"
        stroke="#C0C0C0"
        stroke-width="4"
      />
      <path
        d="M10 14V10C10 6.7 12.7 4 16 4C19.3 4 22 6.7 22 10V14"
        fill="none"
        stroke="#000"
        stroke-width="2"
      />
      
    <!-- Highlight -->
      <path d="M11 12 V 10 C 11 7 13 5 16 5" fill="none" stroke="#fff" stroke-width="1" />
      
    <!-- Lock Body -->
      <rect
        x="8"
        y="14"
        width="16"
        height="14"
        rx="2"
        fill="#FFD700"
        stroke="#000"
        stroke-width="1.5"
      />
      
    <!-- Highlight / Shadow inside Lock Body -->
      <path d="M9 15 h 14" stroke="#fff" stroke-width="1.5" opacity="0.6" stroke-linecap="round" />
      <path d="M9 16 v 10" stroke="#fff" stroke-width="1.5" opacity="0.6" stroke-linecap="round" />

      <circle cx="16" cy="20" r="2" fill="#000" />
      <path d="M15 21 h 2 l 1 4 h -4 z" fill="#000" stroke-linejoin="round" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_shield(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_shield(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Shield Shadow -->
      <path
        d="M16 2 L 4 8 v 8 c 0 7 6 12 12 14 c 6 -2 12 -7 12 -14 V 8 z"
        fill="#000"
        transform="translate(1,1)"
        stroke-linejoin="round"
      />
      
    <!-- Shield Body -->
      <path
        d="M16 2 L 4 8 v 8 c 0 7 6 12 12 14 c 6 -2 12 -7 12 -14 V 8 z"
        fill="#000080"
        stroke="#000"
        stroke-width="1.5"
        stroke-linejoin="round"
      />
      
    <!-- Inner Shield (White) -->
      <path
        d="M16 5 L 7 10 v 5 c 0 5 4 9 9 11 c 5 -2 9 -6 9 -11 V 10 z"
        fill="#fff"
        stroke="#000080"
        stroke-width="1.5"
        stroke-linejoin="round"
      />
      
    <!-- Checkmark -->
      <path
        d="M12 15 l 3 4 L 22 12"
        fill="none"
        stroke="#008000"
        stroke-width="3"
        stroke-linecap="round"
        stroke-linejoin="round"
      />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_security(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_security(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Shield Base -->
      <path
        d="M16 2 L 4 8 v 8 c 0 7 6 12 12 14 c 6 -2 12 -7 12 -14 V 8 z"
        fill="#000"
        transform="translate(1,1)"
        stroke-linejoin="round"
      />
      <path
        d="M16 2 L 4 8 v 8 c 0 7 6 12 12 14 c 6 -2 12 -7 12 -14 V 8 z"
        fill="#000080"
        stroke="#000"
        stroke-width="1.5"
        stroke-linejoin="round"
      />
      
    <!-- Inner Shield (White) -->
      <path
        d="M16 5 L 7 10 v 5 c 0 5 4 9 9 11 c 5 -2 9 -6 9 -11 V 10 z"
        fill="#fff"
        stroke="#000080"
        stroke-width="1.5"
        stroke-linejoin="round"
      />
      
    <!-- Center Lock Shackle Base -->
      <path
        d="M13 13 V 10 C 13 8 15 6 16 6 C 17 6 19 8 19 10 V 13"
        fill="none"
        stroke="#C0C0C0"
        stroke-width="3"
      />
      <path
        d="M13 13 V 10 C 13 8 15 6 16 6 C 17 6 19 8 19 10 V 13"
        fill="none"
        stroke="#555"
        stroke-width="1.5"
      />
      
    <!-- Center Lock Body -->
      <rect x="12" y="13" width="8" height="7" rx="1" fill="#FFD700" stroke="#000" stroke-width="1.5" />
      <path d="M13 14 h 6" stroke="#fff" stroke-width="1" opacity="0.6" stroke-linecap="round" />
      
    <!-- Keyhole -->
      <circle cx="16" cy="16" r="1.5" fill="#000" />
      <path d="M15.5 17 h 1 l 0.5 2 h -2 z" fill="#000" stroke-linejoin="round" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_ban(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_ban(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Shadow -->
      <circle cx="17" cy="17" r="13" fill="none" stroke="#000" stroke-width="4" />
      <line x1="8" y1="8" x2="26" y2="26" stroke="#000" stroke-width="4" />
      
    <!-- Red Ban Sign -->
      <circle cx="16" cy="16" r="13" fill="none" stroke="#FF0000" stroke-width="5" />
      <line x1="7" y1="7" x2="25" y2="25" stroke="#FF0000" stroke-width="5" />
      
    <!-- Inner Bevel (pink) -->
      <circle cx="16" cy="16" r="11" fill="none" stroke="#FF8080" stroke-width="1" />
      <line x1="8" y1="7" x2="25" y2="24" stroke="#FF8080" stroke-width="1" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_globe_blocked(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_globe_blocked(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Shadow Globe -->
      <circle cx="16" cy="16" r="11" fill="#000" transform="translate(1,1)" />
      
    <!-- Globe Base -->
      <circle cx="16" cy="16" r="11" fill="#fff" stroke="#000080" stroke-width="1.5" />
      
    <!-- Globe Ellipses/Grid -->
      <ellipse cx="16" cy="16" rx="5" ry="11" fill="none" stroke="#000080" stroke-width="1.5" />
      <line x1="5" y1="16" x2="27" y2="16" stroke="#000080" stroke-width="1.5" />
      
    <!-- Block Shadow -->
      <line
        x1="5"
        y1="5"
        x2="27"
        y2="27"
        stroke="#000"
        stroke-width="4"
        stroke-linecap="round"
        transform="translate(1,1)"
      />
      
    <!-- Block Line -->
      <line x1="5" y1="5" x2="27" y2="27" stroke="#FF0000" stroke-width="4" stroke-linecap="round" />
      <line x1="6" y1="6" x2="25" y2="25" stroke="#FF8080" stroke-width="1" stroke-linecap="round" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_rules(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_rules(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Shadow of paper -->
      <rect x="6" y="2" width="20" height="28" rx="2" fill="#000" transform="translate(1,1)" />
      
    <!-- Paper Base -->
      <rect x="6" y="2" width="20" height="28" rx="2" fill="#fff" stroke="#000" stroke-width="1.5" />
      <path d="M7 3 h 18" stroke="#C0C0C0" stroke-width="1" opacity="0.6" stroke-linecap="round" />
      <path d="M7 3 v 26" stroke="#C0C0C0" stroke-width="1" opacity="0.6" stroke-linecap="round" />
      
    <!-- Checkbox 1 -->
      <rect x="10" y="6" width="4" height="4" fill="#C0C0C0" stroke="#000080" stroke-width="1" />
      <path
        d="M11 8 l 1 1 l 2 -3"
        fill="none"
        stroke="#000"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      />
      <!-- Line 1 -->
      <line x1="16" y1="8" x2="22" y2="8" stroke="#000080" stroke-width="2" stroke-linecap="round" />
      
    <!-- Checkbox 2 -->
      <rect x="10" y="14" width="4" height="4" fill="#C0C0C0" stroke="#000080" stroke-width="1" />
      <path
        d="M11 16 l 1 1 l 2 -3"
        fill="none"
        stroke="#000"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      />
      <!-- Line 2 -->
      <line x1="16" y1="16" x2="22" y2="16" stroke="#000080" stroke-width="2" stroke-linecap="round" />
      
    <!-- Checkbox 3 -->
      <rect x="10" y="22" width="4" height="4" fill="#fff" stroke="#000080" stroke-width="1" />
      <!-- Line 3 -->
      <line x1="16" y1="24" x2="22" y2="24" stroke="#000080" stroke-width="2" stroke-linecap="round" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_dialog_ignore(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_dialog_ignore(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Shadow -->
      <rect x="5" y="4" width="6" height="5" fill="#000" />
      <polygon points="2,15 14,15 14,11 11,9 5,9 2,11" fill="#000" />
      <rect x="10" y="8" width="6" height="6" fill="#000" />
      
    <!-- Person (White) -->
      <rect x="4" y="3" width="6" height="5" fill="#fff" stroke="#000" stroke-width="1" />
      <polygon points="1,14 13,14 13,10 10,8 4,8 1,10" fill="#fff" stroke="#000" stroke-width="1" />
      
    <!-- Ban sign (Red Octagon) -->
      <polygon
        points="11,7 13,7 15,9 15,11 13,13 11,13 9,11 9,9"
        fill="#808080"
        stroke="#000"
        stroke-width="1"
      />
      <polygon
        points="10,8 14,8 14,12 12,12 10,12 10,8"
        fill="none"
        stroke="#FF0000"
        stroke-width="1"
      />
      <polygon points="13,8 14,9 11,12 10,11" fill="#FF0000" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_tab_modes(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_tab_modes(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Lock Shackle -->
      <polygon points="6,6 6,3 10,3 10,6" fill="none" stroke="#000080" stroke-width="1" />
      <!-- Lock Body -->
      <rect x="5" y="7" width="6" height="7" fill="#000080" />
      <!-- Keyhole -->
      <rect x="7" y="10" width="2" height="2" fill="#fff" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_tab_bans(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_tab_bans(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Ban sign (Red Octagon) -->
      <polygon
        points="5,2 11,2 14,5 14,11 11,14 5,14 2,11 2,5"
        fill="none"
        stroke="#FF0000"
        stroke-width="1"
      />
      <polygon points="4,3 12,11 11,12 3,4" fill="#FF0000" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_tab_exceptions(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_tab_exceptions(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Shield Base -->
      <polygon points="3,3 13,3 13,8 8,14 3,8" fill="#000080" />
      <!-- Checkmark -->
      <polygon points="6,8 8,10 11,6 10,5 8,8 7,7" fill="#fff" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_privacy(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_privacy(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Shield Base -->
      <path
        d="M16 2 L 4 8 v 8 c 0 7 6 12 12 14 c 6 -2 12 -7 12 -14 V 8 z"
        fill="#000"
        transform="translate(1,1)"
        stroke-linejoin="round"
      />
      <path
        d="M16 2 L 4 8 v 8 c 0 7 6 12 12 14 c 6 -2 12 -7 12 -14 V 8 z"
        fill="#000080"
        stroke="#000"
        stroke-width="1.5"
        stroke-linejoin="round"
      />
      
    <!-- Inner Shield (White) -->
      <path
        d="M16 5 L 7 10 v 5 c 0 5 4 9 9 11 c 5 -2 9 -6 9 -11 V 10 z"
        fill="#fff"
        stroke="#000080"
        stroke-width="1.5"
        stroke-linejoin="round"
      />
      
    <!-- Center Lock Shackle Base -->
      <path
        d="M13 13 V 10 C 13 8 15 6 16 6 C 17 6 19 8 19 10 V 13"
        fill="none"
        stroke="#C0C0C0"
        stroke-width="3"
      />
      <path
        d="M13 13 V 10 C 13 8 15 6 16 6 C 17 6 19 8 19 10 V 13"
        fill="none"
        stroke="#555"
        stroke-width="1.5"
      />
      
    <!-- Center Lock Body -->
      <rect x="12" y="13" width="8" height="7" rx="1" fill="#FFD700" stroke="#000" stroke-width="1.5" />
      <path d="M13 14 h 6" stroke="#fff" stroke-width="1" opacity="0.6" stroke-linecap="round" />
      
    <!-- Keyhole -->
      <circle cx="16" cy="16" r="1.5" fill="#000" />
      <path d="M15.5 17 h 1 l 0.5 2 h -2 z" fill="#000" stroke-linejoin="round" />
    </svg>
    """
  end

  # -- Toolbar: Ignore List --

  attr :class, :string, default: nil

  @spec icon_btn_ignore_list(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_ignore_list(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="6" y="3" width="4" height="3" fill="#555" />
      <path d="M4 7h8v5H4z" fill="#555" />
      <!-- Red Ban -->
      <path d="M4 2h8v2H4z M4 12h8v2H4z M2 4h2v8H2z M12 4h2v8h-2z" fill="#FF0000" />
      <path d="M4 4h2v2h2v2h2v2h2v2h-2v-2h-2v-2H6V6H4V4z" fill="#FF0000" />
    </svg>
    """
  end

  # -- Toolbar: Flood Protection --

  attr :class, :string, default: nil

  @spec icon_btn_flood_protection(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_flood_protection(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <path
        d="M8 1h1v1h2v1h2v1h1v7h-1v2h-1v1h-2v1h-1v1H7v-1H5v-1H4v-1H3v-2H2V4h1V3h2V2h2V1h1z"
        fill="#000080"
      />
      <path d="M8 3h1v1h1v1h1v4h-1v1h-1v1h-1v1H7v-1H6V9H5V5h1V4h1V3h1z" fill="#fff" />
      <rect x="7" y="6" width="2" height="3" fill="#000080" />
      <rect x="7" y="10" width="2" height="2" fill="#000080" />
    </svg>
    """
  end
end
