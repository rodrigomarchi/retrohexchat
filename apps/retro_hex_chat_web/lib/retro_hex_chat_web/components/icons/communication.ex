defmodule RetroHexChatWeb.Icons.Communication do
  @moduledoc """
  Icons depicting messaging, networking, and communication concepts.
  """
  use Phoenix.Component
  use Gettext, backend: RetroHexChatWeb.Gettext

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

  @spec icon_p2p_route(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_p2p_route(assigns) do
    ~H"""
    <svg
      viewBox="0 0 240 28"
      preserveAspectRatio="none"
      shape-rendering="crispEdges"
      class={@class}
      aria-hidden="true"
    >
      <line x1="8" y1="14" x2="232" y2="14" class="p2p-diagram-strip__track" />
      <rect
        x="38"
        y="11"
        width="8"
        height="6"
        class="p2p-diagram-strip__packet p2p-diagram-strip__packet--one"
      />
      <rect
        x="116"
        y="11"
        width="8"
        height="6"
        class="p2p-diagram-strip__packet p2p-diagram-strip__packet--two"
      />
      <rect
        x="194"
        y="11"
        width="8"
        height="6"
        class="p2p-diagram-strip__packet p2p-diagram-strip__packet--three"
      />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_protocol_p2p(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_protocol_p2p(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 96 64" shape-rendering="crispEdges" aria-hidden="true">
      <rect x=".5" y=".5" width="95" height="63" fill="#dfdfdf" stroke="#000000" stroke-width="1" />
      <path d="M1.5 1.5 H94.5 M1.5 1.5 V62.5" stroke="#ffffff" stroke-width="1" />
      <path d="M1.5 62.5 H94.5 M94.5 1.5 V62.5" stroke="#808080" stroke-width="1" />

      <g fill="none" stroke-linecap="square">
        <path d="M31 24 H61" stroke="#000000" stroke-width="6" />
        <path d="M65 41 H35" stroke="#000000" stroke-width="6" />
        <path d="M31 24 H61" stroke="#008000" stroke-width="4" />
        <path d="M65 41 H35" stroke="#806000" stroke-width="4" />
        <path d="M31 23 H61" stroke="#00ff00" stroke-width="1" />
        <path d="M65 40 H35" stroke="#ffd700" stroke-width="1" />
      </g>

      <path d="M58 18 L69 24 L58 30 Z" fill="#00a000" stroke="#000000" stroke-width="1.5" />
      <path d="M38 35 L27 41 L38 47 Z" fill="#ffd700" stroke="#000000" stroke-width="1.5" />
      <g stroke="#000000" stroke-width="1">
        <rect x="41" y="20" width="6" height="6" fill="#ffd700" />
        <rect x="51" y="20" width="6" height="6" fill="#ffd700" />
        <rect x="49" y="37" width="6" height="6" fill="#ffffff" />
        <rect x="39" y="37" width="6" height="6" fill="#ffffff" />
      </g>

      <g>
        <rect x="6" y="18" width="24" height="30" fill="#000000" transform="translate(1 1)" />
        <rect x="66" y="18" width="24" height="30" fill="#000000" transform="translate(1 1)" />
        <rect x="6" y="18" width="24" height="30" fill="#c0c0c0" stroke="#000000" stroke-width="1.5" />
        <rect x="66" y="18" width="24" height="30" fill="#c0c0c0" stroke="#000000" stroke-width="1.5" />
        <rect x="8" y="20" width="20" height="5" fill="#000080" />
        <rect x="68" y="20" width="20" height="5" fill="#000080" />
        <rect x="9" y="21" width="2" height="2" fill="#ff0000" />
        <rect x="12" y="21" width="2" height="2" fill="#ffd700" />
        <rect x="15" y="21" width="2" height="2" fill="#00ff00" />
        <rect x="69" y="21" width="2" height="2" fill="#ff0000" />
        <rect x="72" y="21" width="2" height="2" fill="#ffd700" />
        <rect x="75" y="21" width="2" height="2" fill="#00ff00" />
        <rect x="8" y="27" width="20" height="17" fill="#008080" stroke="#000000" stroke-width="1" />
        <rect x="68" y="27" width="20" height="17" fill="#008080" stroke="#000000" stroke-width="1" />
        <path d="M10 30 H23 M10 35 H25 M10 40 H20" stroke="#ffffff" stroke-width="1.5" />
        <path d="M70 30 H83 M70 35 H85 M70 40 H80" stroke="#ffffff" stroke-width="1.5" />
      </g>
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_protocol_conference(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_protocol_conference(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 96 64" shape-rendering="crispEdges" aria-hidden="true">
      <rect x=".5" y=".5" width="95" height="63" fill="#dfdfdf" stroke="#000000" stroke-width="1" />
      <path d="M1.5 1.5 H94.5 M1.5 1.5 V62.5" stroke="#ffffff" stroke-width="1" />
      <path d="M1.5 62.5 H94.5 M94.5 1.5 V62.5" stroke="#808080" stroke-width="1" />

      <g fill="none" stroke-linecap="square">
        <path d="M31 25 H42" stroke="#000000" stroke-width="6" />
        <path d="M42 41 H31" stroke="#000000" stroke-width="6" />
        <path d="M66 18 L55 26" stroke="#000000" stroke-width="6" />
        <path d="M56 33 L67 25" stroke="#000000" stroke-width="6" />
        <path d="M66 46 L55 38" stroke="#000000" stroke-width="6" />
        <path d="M56 31 L67 39" stroke="#000000" stroke-width="6" />
        <path d="M31 25 H42" stroke="#008000" stroke-width="4" />
        <path d="M42 41 H31" stroke="#806000" stroke-width="4" />
        <path d="M66 18 L55 26" stroke="#008000" stroke-width="4" />
        <path d="M56 33 L67 25" stroke="#806000" stroke-width="4" />
        <path d="M66 46 L55 38" stroke="#008000" stroke-width="4" />
        <path d="M56 31 L67 39" stroke="#806000" stroke-width="4" />
      </g>

      <path d="M39 19 L48 25 L39 31 Z" fill="#00a000" stroke="#000000" stroke-width="1.5" />
      <path d="M34 35 L25 41 L34 47 Z" fill="#ffd700" stroke="#000000" stroke-width="1.5" />
      <path d="M58 23 L48 30 L47 19 Z" fill="#00a000" stroke="#000000" stroke-width="1.5" />
      <path d="M65 29 L75 22 L76 33 Z" fill="#ffd700" stroke="#000000" stroke-width="1.5" />
      <path d="M58 41 L48 34 L47 45 Z" fill="#00a000" stroke="#000000" stroke-width="1.5" />
      <path d="M65 35 L75 42 L76 31 Z" fill="#ffd700" stroke="#000000" stroke-width="1.5" />

      <g stroke="#000000" stroke-width="1">
        <rect x="35" y="22" width="6" height="6" fill="#ffd700" />
        <rect x="35" y="38" width="6" height="6" fill="#ffffff" />
        <rect x="58" y="20" width="6" height="6" fill="#ffd700" />
        <rect x="59" y="36" width="6" height="6" fill="#ffffff" />
      </g>

      <g>
        <rect x="6" y="18" width="24" height="30" fill="#000000" transform="translate(1 1)" />
        <rect x="6" y="18" width="24" height="30" fill="#c0c0c0" stroke="#000000" stroke-width="1.5" />
        <rect x="8" y="20" width="20" height="5" fill="#000080" />
        <rect x="9" y="21" width="2" height="2" fill="#ff0000" />
        <rect x="12" y="21" width="2" height="2" fill="#ffd700" />
        <rect x="15" y="21" width="2" height="2" fill="#00ff00" />
        <rect x="8" y="27" width="20" height="17" fill="#008080" stroke="#000000" stroke-width="1" />
        <path d="M10 30 H23 M10 35 H25 M10 40 H20" stroke="#ffffff" stroke-width="1.5" />
      </g>

      <g>
        <rect x="42" y="18" width="14" height="30" fill="#000000" transform="translate(1 1)" />
        <rect x="42" y="18" width="14" height="30" fill="#c0c0c0" stroke="#000000" stroke-width="1.5" />
        <path d="M43 19 H55 M43 19 V47" stroke="#ffffff" stroke-width="1" />
        <rect x="45" y="24" width="8" height="4" fill="#008000" stroke="#000000" stroke-width="1" />
        <rect x="45" y="33" width="8" height="4" fill="#ffd700" stroke="#000000" stroke-width="1" />
        <rect x="45" y="42" width="8" height="2" fill="#808080" stroke="#000000" stroke-width="1" />
      </g>

      <g>
        <rect x="66" y="7" width="24" height="24" fill="#000000" transform="translate(1 1)" />
        <rect x="66" y="35" width="24" height="24" fill="#000000" transform="translate(1 1)" />
        <rect x="66" y="7" width="24" height="24" fill="#c0c0c0" stroke="#000000" stroke-width="1.5" />
        <rect x="66" y="35" width="24" height="24" fill="#c0c0c0" stroke="#000000" stroke-width="1.5" />
        <rect x="68" y="9" width="20" height="5" fill="#000080" />
        <rect x="68" y="37" width="20" height="5" fill="#000080" />
        <rect x="69" y="10" width="2" height="2" fill="#ff0000" />
        <rect x="72" y="10" width="2" height="2" fill="#ffd700" />
        <rect x="69" y="38" width="2" height="2" fill="#ff0000" />
        <rect x="72" y="38" width="2" height="2" fill="#ffd700" />
        <rect x="68" y="16" width="20" height="11" fill="#008080" stroke="#000000" stroke-width="1" />
        <rect x="68" y="44" width="20" height="11" fill="#008080" stroke="#000000" stroke-width="1" />
        <path d="M70 19 H83 M70 23 H80" stroke="#ffffff" stroke-width="1.5" />
        <path d="M70 47 H83 M70 51 H80" stroke="#ffffff" stroke-width="1.5" />
      </g>
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_protocol_p2p_compact(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_protocol_p2p_compact(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 48 48" shape-rendering="crispEdges" aria-hidden="true">
      <rect x=".5" y=".5" width="47" height="47" fill="#dfdfdf" stroke="#000000" stroke-width="1" />
      <path d="M1.5 1.5 H46.5 M1.5 1.5 V46.5" stroke="#ffffff" stroke-width="1" />
      <path d="M1.5 46.5 H46.5 M46.5 1.5 V46.5" stroke="#808080" stroke-width="1" />

      <path d="M15 18 H33" stroke="#000000" stroke-width="5" />
      <path d="M33 31 H15" stroke="#000000" stroke-width="5" />
      <path d="M15 18 H33" stroke="#008000" stroke-width="3" />
      <path d="M33 31 H15" stroke="#806000" stroke-width="3" />
      <path d="M30 13 L39 18 L30 23 Z" fill="#00a000" stroke="#000000" stroke-width="1.5" />
      <path d="M18 26 L9 31 L18 36 Z" fill="#ffd700" stroke="#000000" stroke-width="1.5" />

      <rect x="20" y="15" width="5" height="5" fill="#ffd700" stroke="#000000" stroke-width="1" />
      <rect x="23" y="28" width="5" height="5" fill="#ffffff" stroke="#000000" stroke-width="1" />
      <rect x="3" y="14" width="13" height="21" fill="#000000" transform="translate(1 1)" />
      <rect x="32" y="14" width="13" height="21" fill="#000000" transform="translate(1 1)" />
      <rect x="3" y="14" width="13" height="21" fill="#c0c0c0" stroke="#000000" stroke-width="1.5" />
      <rect x="32" y="14" width="13" height="21" fill="#c0c0c0" stroke="#000000" stroke-width="1.5" />
      <rect x="5" y="16" width="9" height="3" fill="#000080" />
      <rect x="34" y="16" width="9" height="3" fill="#000080" />
      <rect x="5" y="21" width="9" height="10" fill="#008080" stroke="#000000" stroke-width="1" />
      <rect x="34" y="21" width="9" height="10" fill="#008080" stroke="#000000" stroke-width="1" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_protocol_conference_compact(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_protocol_conference_compact(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 48 48" shape-rendering="crispEdges" aria-hidden="true">
      <rect x=".5" y=".5" width="47" height="47" fill="#dfdfdf" stroke="#000000" stroke-width="1" />
      <path d="M1.5 1.5 H46.5 M1.5 1.5 V46.5" stroke="#ffffff" stroke-width="1" />
      <path d="M1.5 46.5 H46.5 M46.5 1.5 V46.5" stroke="#808080" stroke-width="1" />

      <g stroke="#000000" stroke-width="5" stroke-linecap="square">
        <path d="M15 19 H21" />
        <path d="M21 31 H15" />
        <path d="M34 13 L27 20" />
        <path d="M28 27 L35 20" />
        <path d="M34 36 L27 29" />
        <path d="M28 24 L35 31" />
      </g>
      <g stroke="#008000" stroke-width="3" stroke-linecap="square">
        <path d="M15 19 H21" />
        <path d="M34 13 L27 20" />
        <path d="M34 36 L27 29" />
      </g>
      <g stroke="#806000" stroke-width="3" stroke-linecap="square">
        <path d="M21 31 H15" />
        <path d="M28 27 L35 20" />
        <path d="M28 24 L35 31" />
      </g>

      <path d="M19 15 L25 19 L19 23 Z" fill="#00a000" stroke="#000000" stroke-width="1" />
      <path d="M17 27 L11 31 L17 35 Z" fill="#ffd700" stroke="#000000" stroke-width="1" />
      <rect x="3" y="15" width="13" height="20" fill="#000000" transform="translate(1 1)" />
      <rect x="3" y="15" width="13" height="20" fill="#c0c0c0" stroke="#000000" stroke-width="1.5" />
      <rect x="5" y="17" width="9" height="3" fill="#000080" />
      <rect x="5" y="22" width="9" height="9" fill="#008080" stroke="#000000" stroke-width="1" />

      <rect x="20" y="17" width="9" height="18" fill="#000000" transform="translate(1 1)" />
      <rect x="20" y="17" width="9" height="18" fill="#c0c0c0" stroke="#000000" stroke-width="1.5" />
      <path d="M21 18 H28 M21 18 V34" stroke="#ffffff" stroke-width="1" />
      <rect x="22" y="21" width="5" height="3" fill="#008000" stroke="#000000" stroke-width="1" />
      <rect x="22" y="28" width="5" height="3" fill="#ffd700" stroke="#000000" stroke-width="1" />

      <rect x="33" y="5" width="12" height="16" fill="#000000" transform="translate(1 1)" />
      <rect x="33" y="28" width="12" height="16" fill="#000000" transform="translate(1 1)" />
      <rect x="33" y="5" width="12" height="16" fill="#c0c0c0" stroke="#000000" stroke-width="1.5" />
      <rect x="33" y="28" width="12" height="16" fill="#c0c0c0" stroke="#000000" stroke-width="1.5" />
      <rect x="35" y="7" width="8" height="3" fill="#000080" />
      <rect x="35" y="30" width="8" height="3" fill="#000080" />
      <rect x="35" y="12" width="8" height="5" fill="#008080" stroke="#000000" stroke-width="1" />
      <rect x="35" y="35" width="8" height="5" fill="#008080" stroke="#000000" stroke-width="1" />
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

  @spec icon_globe(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_globe(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Shadow -->
      <circle cx="16" cy="16" r="11" fill="#000" transform="translate(1,1)" />
      
    <!-- Globe base + ocean -->
      <circle cx="16" cy="16" r="11" fill="#C0E0FF" stroke="#000080" stroke-width="1.5" />
      
    <!-- Grid: meridian ellipse, equator, prime meridian -->
      <ellipse cx="16" cy="16" rx="5" ry="11" fill="none" stroke="#000080" stroke-width="1.5" />
      <line x1="16" y1="5" x2="16" y2="27" stroke="#000080" stroke-width="1.5" />
      <line x1="5" y1="16" x2="27" y2="16" stroke="#000080" stroke-width="1.5" />
      
    <!-- Latitude lines -->
      <line x1="7.5" y1="11" x2="24.5" y2="11" stroke="#000080" stroke-width="1" />
      <line x1="7.5" y1="21" x2="24.5" y2="21" stroke="#000080" stroke-width="1" />
      
    <!-- Highlight -->
      <circle cx="12" cy="11.5" r="1.5" fill="#fff" opacity="0.7" />
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
