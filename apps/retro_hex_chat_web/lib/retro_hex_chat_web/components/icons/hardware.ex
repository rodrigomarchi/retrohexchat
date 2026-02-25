defmodule RetroHexChatWeb.Icons.Hardware do
  @moduledoc """
  Icons depicting hardware, infrastructure, and technology platforms.
  """
  use Phoenix.Component

  attr :class, :string, default: nil

  @spec icon_laptop(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_laptop(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Laptop Shadow -->
      <path
        d="M6 4 h 20 v 14 h 4 l -2 4 h -24 l -2 -4 h 4 z"
        fill="#000"
        transform="translate(1,1)"
        stroke-linejoin="round"
      />
      
    <!-- Monitor Lid -->
      <rect x="6" y="4" width="20" height="14" rx="1" fill="#000080" stroke="#000" stroke-width="1.5" />
      <!-- Screen -->
      <rect x="8" y="6" width="16" height="10" fill="#008080" stroke="#000" stroke-width="1" />
      <path
        d="M8 7 L 24 7 M 8 16"
        stroke="#fff"
        stroke-width="1.5"
        opacity="0.6"
        stroke-linecap="round"
      />
      <polygon points="18,6 24,6 24,14 18,14" fill="#fff" opacity="0.1" />
      
    <!-- Base Deck -->
      <path
        d="M6 18 h 20 l 2 4 h -24 z"
        fill="#C0C0C0"
        stroke="#000"
        stroke-width="1.5"
        stroke-linejoin="round"
      />
      <!-- Base Deck Bevel -->
      <path d="M6 18 h 20" stroke="#fff" stroke-width="1.5" />
      <path d="M4.5 21 L 27.5 21" stroke="#fff" stroke-width="1" />
      
    <!-- Keypad Impression -->
      <path d="M9 19 L 23 19 L 24 20 L 8 20 z" fill="#808080" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_server(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_server(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Shadow of both racks -->
      <rect x="4" y="4" width="24" height="10" rx="2" fill="#000" transform="translate(1,1)" />
      <rect x="4" y="18" width="24" height="10" rx="2" fill="#000" transform="translate(1,1)" />
      
    <!-- Rack 1 -->
      <rect x="4" y="4" width="24" height="10" rx="2" fill="#000080" stroke="#000" stroke-width="1.5" />
      <path d="M5 5 h 22" stroke="#fff" stroke-width="1.5" opacity="0.6" stroke-linecap="round" />
      <circle cx="24" cy="9" r="2" fill="#00FF00" />
      <circle cx="20" cy="9" r="2" fill="#FFD700" />
      <rect x="8" y="7" width="8" height="2" fill="#C0C0C0" stroke="#000" stroke-width="1" />
      <rect x="8" y="11" width="8" height="1" fill="#C0C0C0" />
      
    <!-- Rack 2 -->
      <rect
        x="4"
        y="18"
        width="24"
        height="10"
        rx="2"
        fill="#000080"
        stroke="#000"
        stroke-width="1.5"
      />
      <path d="M5 19 h 22" stroke="#fff" stroke-width="1.5" opacity="0.6" stroke-linecap="round" />
      <circle cx="24" cy="23" r="2" fill="#00FF00" />
      <circle cx="20" cy="23" r="1.5" fill="#808080" />
      <rect x="8" y="21" width="8" height="2" fill="#C0C0C0" stroke="#000" stroke-width="1" />
      <rect x="8" y="25" width="8" height="1" fill="#C0C0C0" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_database(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_database(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Shadow Base -->
      <ellipse cx="17" cy="25" rx="10" ry="5" fill="#000" />
      <rect x="7" y="9" width="20" height="16" fill="#000" />
      <ellipse cx="17" cy="9" rx="10" ry="5" fill="#000" />
      
    <!-- Base Cylinder Color -->
      <rect x="6" y="8" width="20" height="16" fill="#000080" stroke="#000" stroke-width="1.5" />
      <ellipse cx="16" cy="24" rx="10" ry="5" fill="#000080" stroke="#000" stroke-width="1.5" />
      
    <!-- Top Disc Base Color -->
      <ellipse cx="16" cy="8" rx="10" ry="5" fill="#000080" stroke="#000" stroke-width="1.5" />
      <ellipse cx="16" cy="8" rx="10" ry="5" fill="#0000A0" />
      
    <!-- Middle Disk Outlines to simulate stack -->
      <path d="M6 13 A 10 5 0 0 0 26 13" fill="none" stroke="#000" stroke-width="1.5" />
      <path d="M6 18 A 10 5 0 0 0 26 18" fill="none" stroke="#000" stroke-width="1.5" />
      
    <!-- Bevel Highlights -->
      <line x1="7" y1="8" x2="7" y2="24" stroke="#fff" stroke-width="1" opacity="0.5" />
      <path d="M7 8 A 9 4 0 0 0 25 8" fill="none" stroke="#fff" stroke-width="1" opacity="0.5" />
      <path d="M7 13 A 9 4 0 0 0 16 17" fill="none" stroke="#fff" stroke-width="1" opacity="0.3" />
      <path d="M7 18 A 9 4 0 0 0 16 22" fill="none" stroke="#fff" stroke-width="1" opacity="0.3" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_elixir(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_elixir(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Shadow -->
      <path
        d="M16 2 C12 8 8 14 8 20 C8 26 12 30 16 30 C20 30 24 26 24 20 C24 14 20 8 16 2 Z"
        fill="#000"
        transform="translate(1,1)"
        stroke-linejoin="round"
      />
      
    <!-- Base Drop (Purple/Navy) -->
      <path
        d="M16 2 C12 8 8 14 8 20 C8 26 12 30 16 30 C20 30 24 26 24 20 C24 14 20 8 16 2 Z"
        fill="#4B0082"
        stroke="#000"
        stroke-width="1.5"
        stroke-linejoin="round"
      />
      
    <!-- Inner Glow (Teal) -->
      <path
        d="M16 6 C13 11 11 15 11 20 C11 24 13 27 16 27 C19 27 21 24 21 20 C21 15 19 11 16 6 Z"
        fill="#008080"
      />
      
    <!-- Left Highlight -->
      <path
        d="M15 4 C11 10 9.5 15 9.5 20 C9.5 24 11 27 14 28"
        fill="none"
        stroke="#fff"
        stroke-width="2"
        opacity="0.6"
        stroke-linecap="round"
      />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_postgres(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_postgres(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Shadow Base -->
      <ellipse cx="17" cy="25" rx="10" ry="5" fill="#000" />
      <rect x="7" y="9" width="20" height="16" fill="#000" />
      <ellipse cx="17" cy="9" rx="10" ry="5" fill="#000" />
      
    <!-- Base Cylinder Color -->
      <rect x="6" y="8" width="20" height="16" fill="#008080" stroke="#000" stroke-width="1.5" />
      <ellipse cx="16" cy="24" rx="10" ry="5" fill="#008080" stroke="#000" stroke-width="1.5" />
      
    <!-- Top Disc Base Color -->
      <ellipse cx="16" cy="8" rx="10" ry="5" fill="#008080" stroke="#000" stroke-width="1.5" />
      <ellipse cx="16" cy="8" rx="10" ry="5" fill="#00A0A0" />
      
    <!-- Middle Disk Outlines to simulate stack -->
      <path d="M6 13 A 10 5 0 0 0 26 13" fill="none" stroke="#000" stroke-width="1.5" />
      <path d="M6 18 A 10 5 0 0 0 26 18" fill="none" stroke="#000" stroke-width="1.5" />
      
    <!-- Bevel Highlights -->
      <line x1="7" y1="8" x2="7" y2="24" stroke="#fff" stroke-width="1" opacity="0.5" />
      <path d="M7 8 A 9 4 0 0 0 25 8" fill="none" stroke="#fff" stroke-width="1" opacity="0.5" />
      <path d="M7 13 A 9 4 0 0 0 16 17" fill="none" stroke="#fff" stroke-width="1" opacity="0.3" />
      <path d="M7 18 A 9 4 0 0 0 16 22" fill="none" stroke="#fff" stroke-width="1" opacity="0.3" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_tab_display(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_tab_display(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Monitor Frame -->
      <rect x="2" y="3" width="12" height="9" fill="#000080" />
      <!-- Screen -->
      <rect x="3" y="4" width="10" height="7" fill="#008080" />
      <!-- Highlight/Glare -->
      <rect x="4" y="5" width="2" height="1" fill="#00FFFF" />
      <!-- Stand -->
      <rect x="6" y="12" width="4" height="1" fill="#000080" />
      <rect x="5" y="13" width="6" height="1" fill="#000080" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_dialog_channel_list(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_dialog_channel_list(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <text x="2" y="11" font-size="10" font-weight="bold" font-family="sans-serif" fill="#FFD700">
        #
      </text>
      <!-- List lines (White) -->
      <rect x="8" y="3" width="6" height="2" fill="#fff" />
      <rect x="8" y="7" width="6" height="2" fill="#fff" />
      <rect x="8" y="11" width="6" height="2" fill="#fff" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_dialog_channel_central(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_dialog_channel_central(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Shadow -->
      <rect x="5" y="9" width="8" height="6" fill="#000" />
      <!-- House base -->
      <rect x="4" y="8" width="8" height="6" fill="#fff" stroke="#000" stroke-width="1" />
      <!-- Door -->
      <rect x="7" y="11" width="2" height="3" fill="#000" />
      <!-- Red Roof -->
      <polygon points="8,2 2,8 14,8" fill="#FF0000" stroke="#000" stroke-width="1" />
    </svg>
    """
  end

  # -- Toolbar: Bell --

  attr :class, :string, default: nil

  @spec icon_btn_bell(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_bell(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <path
        d="M8 1a1 1 0 0 1 1 1v1a4 4 0 0 1 3 3.87V10l2 2H2l2-2V6.87A4 4 0 0 1 7 3V2a1 1 0 0 1 1-1z"
        fill="#FFD700"
        stroke="#000"
        stroke-width="0.5"
      />
      <path d="M6.5 13a1.5 1.5 0 0 0 3 0h-3z" fill="#FFD700" stroke="#000" stroke-width="0.5" />
    </svg>
    """
  end
end
