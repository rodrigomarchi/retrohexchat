defmodule RetroHexChatWeb.Components.Diagrams.Voice do
  @moduledoc """
  Voice/video call SVG diagrams and mockups.
  """
  use Phoenix.Component
  use Gettext, backend: RetroHexChatWeb.Gettext

  # ──────────────────────────────────────────────────
  # Voice Call Mockup Diagram (features page — feat-p2p)
  # ──────────────────────────────────────────────────

  attr :class, :string, default: nil

  @spec diagram_voice_call_mockup(map()) :: Phoenix.LiveView.Rendered.t()
  def diagram_voice_call_mockup(assigns) do
    ~H"""
    <svg
      class={@class}
      viewBox="0 0 340 150"
      shape-rendering="crispEdges"
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-label={
        gettext(
          "Retro-style voice call window showing timer, mute, camera, screen share, and end call buttons"
        )
      }
    >
      <!-- Shadow -->
      <rect x="14" y="14" width="320" height="130" fill="#000" />
      <!-- Window Background -->
      <rect x="10" y="10" width="320" height="130" fill="#c0c0c0" stroke="#000" stroke-width="1" />
      <polyline points="11,139 11,11 329,11" fill="none" stroke="#fff" stroke-width="1" />
      <polyline points="329,12 329,139 11,139" fill="none" stroke="#808080" stroke-width="1" />
      
    <!-- Title bar -->
      <rect x="13" y="13" width="314" height="20" fill="#000080" />
      <text
        x="22"
        y="27"
        fill="#fff"
        font-size="11"
        font-family="'Segoe UI',Tahoma,sans-serif"
        font-weight="bold"
      >
        {gettext("Voice Call with Bob")}
      </text>
      
    <!-- Title bar buttons (fake) -->
      <!-- Minimize -->
      <rect x="274" y="15" width="16" height="16" fill="#c0c0c0" stroke="#000" stroke-width="1" />
      <polyline points="275,30 275,16 289,16" fill="none" stroke="#fff" stroke-width="1" />
      <polyline points="289,17 289,30 275,30" fill="none" stroke="#808080" stroke-width="1" />
      <rect x="277" y="27" width="6" height="2" fill="#000" />
      
    <!-- Maximize -->
      <rect x="292" y="15" width="16" height="16" fill="#c0c0c0" stroke="#000" stroke-width="1" />
      <polyline points="293,30 293,16 307,16" fill="none" stroke="#fff" stroke-width="1" />
      <polyline points="307,17 307,30 293,30" fill="none" stroke="#808080" stroke-width="1" />
      <rect x="295" y="18" width="10" height="9" fill="none" stroke="#000" stroke-width="1" />
      <rect x="295" y="18" width="10" height="2" fill="#000" />
      
    <!-- Close -->
      <rect x="309" y="15" width="16" height="16" fill="#c0c0c0" stroke="#000" stroke-width="1" />
      <polyline points="310,30 310,16 324,16" fill="none" stroke="#fff" stroke-width="1" />
      <polyline points="324,17 324,30 310,30" fill="none" stroke="#808080" stroke-width="1" />
      <line x1="313" y1="19" x2="321" y2="27" stroke="#000" stroke-width="1" />
      <line x1="314" y1="19" x2="322" y2="27" stroke="#000" stroke-width="1" />
      <line x1="321" y1="19" x2="313" y2="27" stroke="#000" stroke-width="1" />
      <line x1="322" y1="19" x2="314" y2="27" stroke="#000" stroke-width="1" />
      
    <!-- Inner Content Panel (Sunken) -->
      <rect x="18" y="42" width="304" height="88" fill="#dfdfdf" stroke="#000" stroke-width="1" />
      <polyline points="19,129 19,43 321,43" fill="none" stroke="#808080" stroke-width="1" />
      <polyline points="321,44 321,129 19,129" fill="none" stroke="#fff" stroke-width="1" />
      
    <!-- Display Area (Call avatar / timer) -->
      <rect x="24" y="48" width="292" height="40" fill="#000" stroke="#008080" stroke-width="1" />
      <polyline points="25,87 25,49 315,49" fill="none" stroke="#555" stroke-width="1" />
      <polyline points="315,50 315,87 25,87" fill="none" stroke="#333" stroke-width="1" />
      
    <!-- Small avatar icon square -->
      <rect x="30" y="52" width="32" height="32" fill="#008080" stroke="#fff" stroke-width="1" />
      <text x="46" y="74" text-anchor="middle" fill="#fff" font-size="20">
        {gettext("&#x1F469;")}
      </text>
      
    <!-- Timer elements -->
      <circle cx="95" cy="68" r="5" fill="#00ff00" />
      <!-- Animated inner dot using values representing blinking -->
      <circle cx="95" cy="68" r="3" fill="#fff">
        <animate attributeName="opacity" values="1;0;1" dur="1.5s" repeatCount="indefinite" />
      </circle>

      <text
        x="110"
        y="73"
        fill="#00ff00"
        font-size="18"
        font-family="'Courier New',Courier,monospace"
        font-weight="bold"
      >
        00:03:42
      </text>
      
    <!-- Call buttons (Outset) -->
      <!-- Mute -->
      <rect x="24" y="96" width="65" height="26" fill="#c0c0c0" stroke="#000" stroke-width="1" />
      <polyline points="25,121 25,97 88,97" fill="none" stroke="#fff" stroke-width="1" />
      <polyline points="88,98 88,121 25,121" fill="none" stroke="#808080" stroke-width="1" />
      <text
        x="56"
        y="113"
        text-anchor="middle"
        fill="#000"
        font-size="11"
        font-family="'Segoe UI',Tahoma,sans-serif"
      >
        {gettext("Mute")}
      </text>
      
    <!-- Camera -->
      <rect x="99" y="96" width="65" height="26" fill="#c0c0c0" stroke="#000" stroke-width="1" />
      <polyline points="100,121 100,97 163,97" fill="none" stroke="#fff" stroke-width="1" />
      <polyline points="163,98 163,121 100,121" fill="none" stroke="#808080" stroke-width="1" />
      <text
        x="131"
        y="113"
        text-anchor="middle"
        fill="#000"
        font-size="11"
        font-family="'Segoe UI',Tahoma,sans-serif"
      >
        {gettext("Camera")}
      </text>
      
    <!-- Screen -->
      <rect x="174" y="96" width="65" height="26" fill="#c0c0c0" stroke="#000" stroke-width="1" />
      <polyline points="175,121 175,97 238,97" fill="none" stroke="#fff" stroke-width="1" />
      <polyline points="238,98 238,121 175,121" fill="none" stroke="#808080" stroke-width="1" />
      <text
        x="206"
        y="113"
        text-anchor="middle"
        fill="#000"
        font-size="11"
        font-family="'Segoe UI',Tahoma,sans-serif"
      >
        {gettext("Screen")}
      </text>
      
    <!-- End Call (Disabled/Red style) -->
      <rect x="249" y="96" width="67" height="26" fill="#c0c0c0" stroke="#000" stroke-width="1" />
      <polyline points="250,121 250,97 315,97" fill="none" stroke="#fff" stroke-width="1" />
      <polyline points="315,98 315,121 250,121" fill="none" stroke="#808080" stroke-width="1" />
      
    <!-- Inside inset text with a bit of color -->
      <rect x="252" y="99" width="61" height="20" fill="#cc0000" />
      <polyline points="253,118 253,100 312,100" fill="none" stroke="#800000" stroke-width="1" />
      <polyline points="312,101 312,118 253,118" fill="none" stroke="#ff8080" stroke-width="1" />
      <text
        x="282"
        y="113"
        text-anchor="middle"
        fill="#fff"
        font-size="11"
        font-family="'Segoe UI',Tahoma,sans-serif"
        font-weight="bold"
      >
        {gettext("End")}
      </text>
    </svg>
    """
  end
end
