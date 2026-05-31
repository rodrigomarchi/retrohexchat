defmodule RetroHexChatWeb.Components.Diagrams.P2pArchitecture do
  @moduledoc "SVG diagram for P2P architecture."
  use Phoenix.Component
  use Gettext, backend: RetroHexChatWeb.Gettext

  attr :class, :string, default: nil

  @spec diagram_p2p_architecture(map()) :: Phoenix.LiveView.Rendered.t()
  def diagram_p2p_architecture(assigns) do
    ~H"""
    <svg
      class={@class}
      viewBox="0 0 520 260"
      shape-rendering="crispEdges"
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-label={
        gettext(
          "Peer-to-peer connection diagram showing Alice and Bob connected directly via WebRTC, with the server only used for signaling"
        )
      }
    >
      <!-- Alice window -->
      <!-- Shadow -->
      <rect x="24" y="24" width="140" height="80" fill="#000" />
      <!-- Base -->
      <rect x="20" y="20" width="140" height="80" fill="#c0c0c0" stroke="#000" stroke-width="1" />
      <polyline points="21,99 21,21 159,21" fill="none" stroke="#fff" stroke-width="1" />
      <polyline points="159,22 159,99 21,99" fill="none" stroke="#808080" stroke-width="1" />
      
    <!-- Title bar -->
      <rect x="23" y="23" width="134" height="20" fill="#000080" />
      <text
        x="90"
        y="37"
        text-anchor="middle"
        fill="#fff"
        font-size="12"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        {gettext("Alice")}
      </text>
      <!-- Content Area Inset -->
      <rect x="26" y="48" width="128" height="46" fill="#dfdfdf" stroke="#000" stroke-width="1" />
      <polyline points="27,93 27,49 153,49" fill="none" stroke="#808080" stroke-width="1" />
      <polyline points="153,50 153,93 27,93" fill="none" stroke="#fff" stroke-width="1" />

      <text x="90" y="80" text-anchor="middle" fill="#000" font-size="28">
        {gettext("&#x1F468;")}
      </text>
      
    <!-- Bob window -->
      <!-- Shadow -->
      <rect x="364" y="24" width="140" height="80" fill="#000" />
      <!-- Base -->
      <rect x="360" y="20" width="140" height="80" fill="#c0c0c0" stroke="#000" stroke-width="1" />
      <polyline points="361,99 361,21 499,21" fill="none" stroke="#fff" stroke-width="1" />
      <polyline points="499,22 499,99 361,99" fill="none" stroke="#808080" stroke-width="1" />
      
    <!-- Title bar -->
      <rect x="363" y="23" width="134" height="20" fill="#000080" />
      <text
        x="430"
        y="37"
        text-anchor="middle"
        fill="#fff"
        font-size="12"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        {gettext("Bob")}
      </text>
      <!-- Content Area Inset -->
      <rect x="366" y="48" width="128" height="46" fill="#dfdfdf" stroke="#000" stroke-width="1" />
      <polyline points="367,93 367,49 493,49" fill="none" stroke="#808080" stroke-width="1" />
      <polyline points="493,50 493,93 367,93" fill="none" stroke="#fff" stroke-width="1" />

      <text x="430" y="80" text-anchor="middle" fill="#000" font-size="28">
        {gettext("&#x1F469;")}
      </text>
      
    <!-- P2P arrow (bidirectional thick line) -->
      <rect x="160" y="52" width="200" height="12" fill="#000" />
      <rect x="168" y="52" width="184" height="10" fill="#008080" />
      <!-- Left head -->
      <path d="M168 46 L154 57 L168 68 Z" fill="#000" />
      <path d="M168 49 L158 57 L168 65 Z" fill="#008080" />
      <!-- Right head -->
      <path d="M352 46 L366 57 L352 68 Z" fill="#000" />
      <path d="M352 49 L362 57 L352 65 Z" fill="#008080" />

      <rect x="210" y="35" width="100" height="36" fill="#dfdfdf" stroke="#000" stroke-width="1" />
      <polyline points="211,70 211,36 309,36" fill="none" stroke="#fff" stroke-width="1" />
      <polyline points="309,37 309,70 211,70" fill="none" stroke="#808080" stroke-width="1" />
      <text
        x="260"
        y="48"
        text-anchor="middle"
        fill="#000080"
        font-size="10"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        {gettext("WebRTC P2P")}
      </text>
      <text
        x="260"
        y="62"
        text-anchor="middle"
        fill="#000"
        font-size="9"
        font-family="Tahoma,sans-serif"
      >
        {gettext("voice / video / files")}
      </text>
      
    <!-- Dashed lines to server -->
      <line
        x1="90"
        y1="110"
        x2="90"
        y2="170"
        stroke="#808080"
        stroke-width="2"
        stroke-dasharray="6,4"
      />
      <line
        x1="430"
        y1="110"
        x2="430"
        y2="170"
        stroke="#808080"
        stroke-width="2"
        stroke-dasharray="6,4"
      />
      <line
        x1="90"
        y1="170"
        x2="430"
        y2="170"
        stroke="#808080"
        stroke-width="2"
        stroke-dasharray="6,4"
      />
      <line
        x1="260"
        y1="170"
        x2="260"
        y2="190"
        stroke="#808080"
        stroke-width="2"
        stroke-dasharray="6,4"
      />
      
    <!-- Server window -->
      <!-- Shadow -->
      <rect x="199" y="196" width="122" height="60" fill="#000" />
      <!-- Base -->
      <rect x="195" y="192" width="122" height="60" fill="#c0c0c0" stroke="#000" stroke-width="1" />
      <polyline points="196,251 196,193 316,193" fill="none" stroke="#fff" stroke-width="1" />
      <polyline points="316,194 316,251 196,251" fill="none" stroke="#808080" stroke-width="1" />
      
    <!-- Title bar (disabled style for server since it's just bg signaling) -->
      <rect x="198" y="195" width="116" height="18" fill="#808080" />
      <text
        x="256"
        y="208"
        text-anchor="middle"
        fill="#c0c0c0"
        font-size="10"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        {gettext("Server (signaling)")}
      </text>

      <text
        x="256"
        y="230"
        text-anchor="middle"
        fill="#444"
        font-size="10"
        font-family="Tahoma,sans-serif"
      >
        {gettext("· only connects them")}
      </text>
      <text
        x="256"
        y="244"
        text-anchor="middle"
        fill="#444"
        font-size="10"
        font-family="Tahoma,sans-serif"
      >
        {gettext("· never sees data")}
      </text>
    </svg>
    """
  end
end
