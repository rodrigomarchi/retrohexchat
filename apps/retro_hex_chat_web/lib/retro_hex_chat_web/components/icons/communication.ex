defmodule RetroHexChatWeb.Icons.Communication do
  @moduledoc """
  Icons depicting messaging, networking, and communication concepts.
  """
  use Phoenix.Component

  attr :class, :string, default: nil

  @spec icon_p2p(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_p2p(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Shadow of connection -->
      <path d="M12 16 L20 16" stroke="#000" stroke-width="4" transform="translate(1,1)" />
      
    <!-- Nodes Shadow -->
      <circle cx="8" cy="16" r="6" fill="#000" transform="translate(1,1)" />
      <circle cx="24" cy="16" r="6" fill="#000" transform="translate(1,1)" />
      
    <!-- Connection lines -->
      <path d="M12 16 L20 16" stroke="#008000" stroke-width="3.5" stroke-linecap="round" />
      <path d="M12 15.5 L20 15.5" stroke="#00FF00" stroke-width="1.5" stroke-linecap="round" />
      <polygon points="17,11 22,16 17,21" fill="#008000" />
      <polygon points="15,11 10,16 15,21" fill="#008000" />
      
    <!-- Nodes Base -->
      <circle cx="8" cy="16" r="6" fill="#000080" stroke="#000" stroke-width="1.5" />
      <circle cx="24" cy="16" r="6" fill="#000080" stroke="#000" stroke-width="1.5" />
      
    <!-- Nodes Highlight -->
      <circle cx="6" cy="14" r="2" fill="#fff" opacity="0.6" />
      <circle cx="22" cy="14" r="2" fill="#fff" opacity="0.6" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_chat(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_chat(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Shadow Back Bubble -->
      <path
        d="M4 4 h 18 v 12 h -8 l -6 6 v -6 h -4 z"
        fill="#000"
        transform="translate(1,1)"
        stroke-linejoin="round"
      />
      <!-- Back Bubble (Navy) -->
      <path
        d="M4 4 h 18 v 12 h -8 l -6 6 v -6 h -4 z"
        fill="#000080"
        stroke="#000"
        stroke-width="1.5"
        stroke-linejoin="round"
      />
      <path d="M5 5 h 16" stroke="#fff" stroke-width="1.5" opacity="0.4" stroke-linecap="round" />
      <path d="M5 5 v 10" stroke="#fff" stroke-width="1.5" opacity="0.4" stroke-linecap="round" />
      
    <!-- Shadow Front Bubble -->
      <path
        d="M8 12 h 18 v 12 h -8 l -4 6 c -1 -1 -1 -3 -1 -6 h -5 z"
        fill="#000"
        transform="translate(1,1)"
        stroke-linejoin="round"
      />
      <!-- Front Bubble (White) -->
      <path
        d="M8 12 h 18 v 12 h -8 l -4 6 c -1 -1 -1 -3 -1 -6 h -5 z"
        fill="#fff"
        stroke="#000"
        stroke-width="1.5"
        stroke-linejoin="round"
      />
      
    <!-- Text Lines -->
      <line x1="12" y1="16" x2="22" y2="16" stroke="#000080" stroke-width="2" stroke-linecap="round" />
      <line x1="12" y1="20" x2="19" y2="20" stroke="#000080" stroke-width="2" stroke-linecap="round" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_channels(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_channels(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Matrix of channels -->
      
      <!-- Top Left -->
      <rect x="3" y="2" width="12" height="12" rx="2" fill="#000" transform="translate(1,1)" />
      <rect x="3" y="2" width="12" height="12" rx="2" fill="#000080" stroke="#000" stroke-width="1.5" />
      <path d="M4 3 h 10" stroke="#fff" stroke-width="1.5" opacity="0.6" stroke-linecap="round" />
      <text
        x="9"
        y="11"
        text-anchor="middle"
        font-size="10"
        font-family="sans-serif"
        font-weight="bold"
        fill="#fff"
      >
        #
      </text>
      
    <!-- Top Right -->
      <rect x="17" y="2" width="12" height="12" rx="2" fill="#000" transform="translate(1,1)" />
      <rect
        x="17"
        y="2"
        width="12"
        height="12"
        rx="2"
        fill="#008080"
        stroke="#000"
        stroke-width="1.5"
      />
      <path d="M18 3 h 10" stroke="#fff" stroke-width="1.5" opacity="0.6" stroke-linecap="round" />
      <text
        x="23"
        y="11"
        text-anchor="middle"
        font-size="10"
        font-family="sans-serif"
        font-weight="bold"
        fill="#fff"
      >
        #
      </text>
      
    <!-- Bottom Left -->
      <rect x="3" y="16" width="12" height="12" rx="2" fill="#000" transform="translate(1,1)" />
      <rect
        x="3"
        y="16"
        width="12"
        height="12"
        rx="2"
        fill="#008080"
        stroke="#000"
        stroke-width="1.5"
      />
      <path d="M4 17 h 10" stroke="#fff" stroke-width="1.5" opacity="0.6" stroke-linecap="round" />
      <text
        x="9"
        y="25"
        text-anchor="middle"
        font-size="10"
        font-family="sans-serif"
        font-weight="bold"
        fill="#fff"
      >
        #
      </text>
      
    <!-- Bottom Right -->
      <rect x="17" y="16" width="12" height="12" rx="2" fill="#000" transform="translate(1,1)" />
      <rect
        x="17"
        y="16"
        width="12"
        height="12"
        rx="2"
        fill="#000080"
        stroke="#000"
        stroke-width="1.5"
      />
      <path d="M18 17 h 10" stroke="#fff" stroke-width="1.5" opacity="0.6" stroke-linecap="round" />
      <text
        x="23"
        y="25"
        text-anchor="middle"
        font-size="10"
        font-family="sans-serif"
        font-weight="bold"
        fill="#fff"
      >
        #
      </text>
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_websocket(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_websocket(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Shadow Wave -->
      <path
        d="M4 16 C 8 8, 12 8, 16 16 C 20 24, 24 24, 28 16"
        fill="none"
        stroke="#000"
        stroke-width="4.5"
        transform="translate(1,1)"
        stroke-linecap="round"
      />
      
    <!-- Connecting Wave -->
      <path
        d="M4 16 C 8 8, 12 8, 16 16 C 20 24, 24 24, 28 16"
        fill="none"
        stroke="#008000"
        stroke-width="3.5"
        stroke-linecap="round"
      />
      <path
        d="M4 15.5 C 8 7.5, 12 7.5, 16 15.5 C 20 23.5, 24 23.5, 28 15.5"
        fill="none"
        stroke="#00FF00"
        stroke-width="1.5"
        stroke-linecap="round"
      />
      
    <!-- Nodes Shadow -->
      <circle cx="4" cy="16" r="4" fill="#000" transform="translate(1,1)" />
      <circle cx="28" cy="16" r="4" fill="#000" transform="translate(1,1)" />
      
    <!-- Nodes Base -->
      <circle cx="4" cy="16" r="4" fill="#000080" stroke="#000" stroke-width="1.5" />
      <circle cx="28" cy="16" r="4" fill="#000080" stroke="#000" stroke-width="1.5" />
      
    <!-- Nodes Bevel -->
      <circle cx="3" cy="15" r="1.5" fill="#fff" opacity="0.6" />
      <circle cx="27" cy="15" r="1.5" fill="#fff" opacity="0.6" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_webrtc(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_webrtc(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Shadow Polygon -->
      <polygon
        points="4,8 14,8 14,24 4,24"
        fill="#000"
        transform="translate(1,1)"
        stroke-linejoin="round"
      />
      <polygon
        points="14,12 22,8 22,24 14,20"
        fill="#000"
        transform="translate(1,1)"
        stroke-linejoin="round"
      />
      
    <!-- Polygon Right (Teal) -->
      <polygon
        points="14,12 22,8 22,24 14,20"
        fill="#008080"
        stroke="#000"
        stroke-width="1.5"
        stroke-linejoin="round"
      />
      <path
        d="M15 13 L 21 10 L 21 22"
        fill="none"
        stroke="#fff"
        stroke-width="1"
        opacity="0.6"
        stroke-linecap="round"
      />
      
    <!-- Polygon Left (Navy) -->
      <polygon
        points="4,8 14,8 14,24 4,24"
        fill="#000080"
        stroke="#000"
        stroke-width="1.5"
        stroke-linejoin="round"
      />
      <path
        d="M5 9 L 13 9 L 13 22"
        fill="none"
        stroke="#fff"
        stroke-width="1"
        opacity="0.6"
        stroke-linecap="round"
      />
      
    <!-- Recording Light -->
      <circle cx="26" cy="10" r="3" fill="#FF0000" stroke="#000" stroke-width="1.5" />
      <circle cx="26" cy="22" r="1.5" fill="#FF0000" stroke="#000" stroke-width="1" />
      <circle cx="25" cy="9" r="1" fill="#fff" opacity="0.7" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_megaphone(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_megaphone(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Megaphone Shadow -->
      <polygon
        points="6,12 6,20 12,20 22,26 22,6 12,12"
        fill="#000"
        transform="translate(1,1)"
        stroke-linejoin="round"
      />
      
    <!-- Megaphone Body -->
      <polygon
        points="6,12 6,20 12,20 22,26 22,6 12,12"
        fill="#000080"
        stroke="#000"
        stroke-width="1.5"
        stroke-linejoin="round"
      />
      <path
        d="M7 13 L 12 13 L 21 8 L 21 24 M7 13 L 7 19"
        fill="none"
        stroke="#fff"
        stroke-width="1.5"
        opacity="0.6"
        stroke-linejoin="round"
      />
      
    <!-- Sound Waves Shadow -->
      <path
        d="M26 12 A 5 5 0 0 1 26 20"
        fill="none"
        stroke="#000"
        stroke-width="3"
        stroke-linecap="round"
        transform="translate(1,1)"
      />
      <path
        d="M25 8 A 9 9 0 0 1 25 24"
        fill="none"
        stroke="#000"
        stroke-width="3"
        stroke-linecap="round"
        transform="translate(1,1)"
      />
      
    <!-- Sound Waves -->
      <path
        d="M26 12 A 5 5 0 0 1 26 20"
        fill="none"
        stroke="#FFD700"
        stroke-width="2"
        stroke-linecap="round"
      />
      <path
        d="M25 8 A 9 9 0 0 1 25 24"
        fill="none"
        stroke="#FFD700"
        stroke-width="2"
        stroke-linecap="round"
      />
      
    <!-- Speaker details -->
      <rect x="23" y="14" width="4" height="4" fill="#FFD700" stroke="#B8860B" stroke-width="1" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_send(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_send(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Shadow -->
      <polygon
        points="4,4 28,16 4,28 8,16"
        fill="#000"
        transform="translate(1,1)"
        stroke-linejoin="round"
      />
      <!-- Paper plane base -->
      <polygon
        points="4,4 28,16 4,28 8,16"
        fill="#000080"
        stroke="#000"
        stroke-width="1.5"
        stroke-linejoin="round"
      />
      <!-- Top fold -->
      <polygon points="4,4 28,16 8,16" fill="#008080" />
      <!-- Highlight -->
      <path d="M4 4 L 28 16" stroke="#fff" stroke-width="1.5" opacity="0.6" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_dialog_invite(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_dialog_invite(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="3" y="4" width="12" height="8" fill="#000" />
      <!-- Envelope base -->
      <rect x="2" y="3" width="12" height="8" fill="#fff" stroke="#000" stroke-width="1" />
      <!-- Envelope folds -->
      <polyline points="2,3 8,8 14,3" fill="none" stroke="#000" stroke-width="1" />
      <polyline points="2,11 6,8" fill="none" stroke="#000" stroke-width="1" />
      <polyline points="14,11 10,8" fill="none" stroke="#000" stroke-width="1" />
      <!-- Star / Seal (Gold) -->
      <rect x="7" y="6" width="2" height="2" fill="#FFD700" />
      <rect x="12" y="1" width="2" height="2" fill="#FFD700" />
      <rect x="14" y="0" width="1" height="1" fill="#FFD700" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_dialog_url(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_dialog_url(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Pixel art globe (White wireframe to stand out over dark) -->
      <polygon
        points="6,1 10,1 13,4 13,12 10,15 6,15 3,12 3,4"
        fill="none"
        stroke="#fff"
        stroke-width="1"
      />
      <!-- Grids -->
      <line x1="2" y1="8" x2="14" y2="8" stroke="#fff" stroke-width="1" />
      <line x1="8" y1="2" x2="8" y2="14" stroke="#fff" stroke-width="1" />
      <rect x="5" y="2" width="6" height="12" fill="none" stroke="#fff" stroke-width="1" />
      <!-- Star highlight -->
      <rect x="12" y="2" width="2" height="2" fill="#FFD700" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_tab_pm(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_tab_pm(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="1" y="4" width="14" height="9" fill="none" stroke="#000080" stroke-width="1" />
      <polygon points="1,4 8,9 15,4" fill="none" stroke="#000080" stroke-width="1" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_tab_conversations(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_tab_conversations(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Speech bubble -->
      <polygon points="2,2 14,2 14,10 7,10 4,13 4,10 2,10" fill="#000080" />
      <!-- Text lines -->
      <rect x="5" y="4" width="6" height="1" fill="#fff" />
      <rect x="5" y="7" width="4" height="1" fill="#fff" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_tab_autojoin(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_tab_autojoin(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Hash symbol -->
      <rect x="5" y="3" width="2" height="10" fill="#000080" />
      <rect x="9" y="3" width="2" height="10" fill="#000080" />
      <rect x="3" y="6" width="10" height="2" fill="#000080" />
      <rect x="3" y="9" width="10" height="2" fill="#000080" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_link(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_link(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Shadows -->
      <path
        d="M12 20 C 18 14 18 14 20 12"
        fill="none"
        stroke="#000"
        stroke-width="4"
        stroke-linecap="round"
        transform="translate(1,1)"
      />
      <path
        d="M14 20 C 8 26 2 20 8 14"
        fill="none"
        stroke="#000"
        stroke-width="3"
        stroke-linecap="round"
        transform="translate(1,1)"
      />
      <path
        d="M20 12 C 26 6 32 12 26 18"
        fill="none"
        stroke="#000"
        stroke-width="3"
        stroke-linecap="round"
        transform="translate(1,1)"
      />
      
    <!-- Right Chain -->
      <path
        d="M20 12 C 26 6 32 12 26 18"
        fill="none"
        stroke="#C0C0C0"
        stroke-width="3"
        stroke-linecap="round"
      />
      <path
        d="M20 12 C 26 6 32 12 26 18"
        fill="none"
        stroke="#000"
        stroke-width="1"
        stroke-linecap="round"
      />
      
    <!-- Connect Line -->
      <path d="M12 20 L 20 12" fill="none" stroke="#000080" stroke-width="3" stroke-linecap="round" />
      <path d="M12 20 L 20 12" fill="none" stroke="#fff" stroke-width="1" stroke-linecap="round" />
      
    <!-- Left Chain -->
      <path
        d="M14 20 C 8 26 2 20 8 14"
        fill="none"
        stroke="#C0C0C0"
        stroke-width="3"
        stroke-linecap="round"
      />
      <path
        d="M14 20 C 8 26 2 20 8 14"
        fill="none"
        stroke="#000"
        stroke-width="1"
        stroke-linecap="round"
      />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_tab_channel(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_tab_channel(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Frame -->
      <polygon points="1,2 15,2 15,12 10,12 8,14 6,12 1,12" fill="#000080" />
      <!-- Screen -->
      <rect x="2" y="3" width="12" height="8" fill="#fff" />
      <!-- Text lines -->
      <rect x="4" y="5" width="6" height="1" fill="#000080" />
      <rect x="4" y="8" width="4" height="1" fill="#000080" />
    </svg>
    """
  end

  # -- Disconnect --

  attr :class, :string, default: nil

  @spec icon_btn_disconnect(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_disconnect(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="1" y="6" width="3" height="3" fill="#000080" />
      <rect x="12" y="6" width="3" height="3" fill="#000080" />
      <rect x="5" y="7" width="6" height="1" fill="#555" />

      <path
        d="M4 4h2v1h1v2h2v-2h1v-1h2v2h-1v1h-2v2h2v1h1v2h-2v-1h-1v-2h-2v2h-1v1H4v-2h1v-1h2v-2H5V7H4V4z"
        fill="#FF5555"
      />
    </svg>
    """
  end

  # -- Connect Lightning --

  attr :class, :string, default: nil

  @spec icon_btn_connect_lightning(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_connect_lightning(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="2" y="6" width="3" height="3" fill="#000080" />
      <rect x="11" y="6" width="3" height="3" fill="#000080" />
      <path d="M8 2h3v4h2v1H9v6H7V8H5V7h3V2z" fill="#FFD700" />
    </svg>
    """
  end

  # -- Connect Disabled --

  attr :class, :string, default: nil

  @spec icon_btn_connect_disabled(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_connect_disabled(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="2" y="6" width="3" height="3" fill="#999" />
      <rect x="11" y="6" width="3" height="3" fill="#999" />
      <path d="M8 2h3v4h2v1H9v6H7V8H5V7h3V2z" fill="#ccc" />
    </svg>
    """
  end

  # -- Channel List --

  attr :class, :string, default: nil

  @spec icon_btn_channel_list(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_channel_list(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="2" y="3" width="12" height="2" fill="#000080" />
      <rect x="2" y="7" width="12" height="2" fill="#000080" />
      <rect x="2" y="11" width="5" height="2" fill="#000080" />

      <rect x="10" y="10" width="1" height="5" fill="#000080" />
      <rect x="12" y="10" width="1" height="5" fill="#000080" />
      <rect x="9" y="11" width="5" height="1" fill="#000080" />
      <rect x="9" y="13" width="5" height="1" fill="#000080" />
    </svg>
    """
  end

  # -- Toggle Conversations --

  attr :class, :string, default: nil

  @spec icon_btn_toggle_conversations(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_toggle_conversations(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="1" y="1" width="14" height="14" fill="#fff" />
      <path d="M0 0h16v1H1v14h15v1H0z M15 1v14h1V1z M0 1v14h1V1z" fill="#000" />
      <rect x="2" y="2" width="5" height="12" fill="#000080" />
      <rect x="3" y="4" width="3" height="1" fill="#fff" />
      <rect x="3" y="6" width="3" height="1" fill="#fff" />
      <rect x="3" y="8" width="3" height="1" fill="#fff" />
    </svg>
    """
  end

  # -- Toggle Nicklist --

  attr :class, :string, default: nil

  @spec icon_btn_toggle_nicklist(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_toggle_nicklist(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="1" y="1" width="14" height="14" fill="#fff" />
      <path d="M0 0h16v1H1v14h15v1H0z M15 1v14h1V1z M0 1v14h1V1z" fill="#000" />
      <rect x="9" y="2" width="5" height="12" fill="#008000" />
      <rect x="10" y="4" width="3" height="2" fill="#fff" />
      <rect x="10" y="8" width="3" height="2" fill="#fff" />
    </svg>
    """
  end

  # -- Auto Respond --

  attr :class, :string, default: nil

  @spec icon_btn_auto_respond(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_auto_respond(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Background bubble -->
      <rect x="2" y="3" width="10" height="7" fill="#000080" />
      <rect x="4" y="10" width="2" height="2" fill="#000080" />
      
    <!-- Foreground bubble -->
      <rect x="3" y="4" width="8" height="5" fill="#87CEEB" />
      <rect x="5" y="9" width="1" height="1" fill="#87CEEB" />
      
    <!-- Arrow -->
      <path d="M7 6h3V5h1V4h1v2h1v2h-1v2h-1V9h-1V8H7V6z" fill="#FFD700" />
    </svg>
    """
  end

  # -- URL Catcher --

  attr :class, :string, default: nil

  @spec icon_btn_url_catcher(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_url_catcher(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Globe outline -->
      <path d="M5 2h6v1H5V2z M3 4h2V3h6v1h2v2h1v6h-1v2h-2v1H5v-1H3v-2H2V6h1V4z" fill="#000080" />
      <!-- Inner lines -->
      <rect x="7" y="3" width="2" height="10" fill="#000080" />
      <rect x="3" y="7" width="10" height="2" fill="#000080" />
      <rect x="7" y="7" width="2" height="2" fill="#00ff00" />
    </svg>
    """
  end

  # -- CTCP --

  attr :class, :string, default: nil

  @spec icon_btn_ctcp(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_ctcp(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <path d="M2 5h6V4h1v1h1v1h1v1h-1v1H9v1H8V8H2V5z" fill="#008000" />
      <path d="M14 10H8v1H7v-1H6v-1H5v-1h1V7h1v1h1v1h6v2z" fill="#000080" />
    </svg>
    """
  end

  # -- Channel Central --

  attr :class, :string, default: nil

  @spec icon_btn_channel_central(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_channel_central(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- House Base -->
      <path d="M3 6h10v8H3V6z" fill="#555" />
      <rect x="5" y="8" width="2" height="2" fill="#87CEEB" />
      <rect x="9" y="8" width="2" height="2" fill="#87CEEB" />
      <rect x="7" y="11" width="2" height="3" fill="#8B4513" />
      <!-- Roof -->
      <path d="M7 2h2v1h2v1h2v1h2v1H1v-1h2V5h2V4h2V3h2V2z" fill="#FF5555" />
      <!-- Chimney -->
      <rect x="11" y="2" width="2" height="3" fill="#FF5555" />
    </svg>
    """
  end

  # -- Button: Link (chain link, 16×16) --

  attr :class, :string, default: nil

  @spec icon_btn_link(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_link(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Left link -->
      <path d="M2 5h3v1h2v1H5v2h2v1H4v1H2V5z" fill="#000080" />
      <rect x="3" y="6" width="2" height="3" fill="#C0C0C0" />
      <!-- Right link -->
      <path d="M9 5h3v1h2v5h-2v-1H9V9h2V7H9V5z" fill="#000080" />
      <rect x="10" y="6" width="2" height="3" fill="#C0C0C0" />
      <!-- Center overlap -->
      <rect x="6" y="7" width="3" height="1" fill="#808080" />
    </svg>
    """
  end
end
