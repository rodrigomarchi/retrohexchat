defmodule RetroHexChatWeb.Components.Diagrams do
  @moduledoc """
  SVG diagrams and illustrations for landing pages and informational displays.
  Unlike Icons (small reusable icons), these are larger, complex SVG illustrations.
  """
  use Phoenix.Component

  # ──────────────────────────────────────────────────
  # P2P Flow Diagram (how_it_works — tab-p2p)
  # ──────────────────────────────────────────────────

  attr :class, :string, default: nil

  @spec diagram_p2p_flow(map()) :: Phoenix.LiveView.Rendered.t()
  def diagram_p2p_flow(assigns) do
    ~H"""
    <svg
      class={@class}
      viewBox="0 0 420 340"
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-label="Vertical flowchart showing 4 steps: Alice calls Bob, server exchanges signaling, P2P connection established, then direct data flow with server out of the loop"
    >
      <!-- Step 1 -->
      <rect
        x="60"
        y="10"
        width="300"
        height="36"
        rx="0"
        fill="#c0c0c0"
        stroke="#808080"
        stroke-width="2"
      />
      <rect x="62" y="12" width="20" height="14" rx="0" fill="#008080" />
      <text
        x="72"
        y="23"
        text-anchor="middle"
        fill="#fff"
        font-size="10"
        font-family="'Segoe UI',Tahoma,sans-serif"
        font-weight="bold"
      >
        1
      </text>
      <text
        x="210"
        y="33"
        text-anchor="middle"
        fill="#000"
        font-size="12"
        font-family="'Segoe UI',Tahoma,sans-serif"
      >
        Alice wants to call Bob
      </text>
      
    <!-- Arrow 1→2 -->
      <line x1="210" y1="46" x2="210" y2="72" stroke="#808080" stroke-width="2" />
      <polygon points="210,72 205,64 215,64" fill="#808080" />
      
    <!-- Step 2 -->
      <rect
        x="60"
        y="74"
        width="300"
        height="36"
        rx="0"
        fill="#c0c0c0"
        stroke="#808080"
        stroke-width="2"
      />
      <rect x="62" y="76" width="20" height="14" rx="0" fill="#008080" />
      <text
        x="72"
        y="87"
        text-anchor="middle"
        fill="#fff"
        font-size="10"
        font-family="'Segoe UI',Tahoma,sans-serif"
        font-weight="bold"
      >
        2
      </text>
      <text
        x="210"
        y="97"
        text-anchor="middle"
        fill="#000"
        font-size="12"
        font-family="'Segoe UI',Tahoma,sans-serif"
      >
        Server exchanges signaling (SDP/ICE)
      </text>
      
    <!-- Arrow 2→3 -->
      <line x1="210" y1="110" x2="210" y2="136" stroke="#808080" stroke-width="2" />
      <polygon points="210,136 205,128 215,128" fill="#808080" />
      
    <!-- Step 3 -->
      <rect
        x="60"
        y="138"
        width="300"
        height="36"
        rx="0"
        fill="#c0c0c0"
        stroke="#808080"
        stroke-width="2"
      />
      <rect x="62" y="140" width="20" height="14" rx="0" fill="#008080" />
      <text
        x="72"
        y="151"
        text-anchor="middle"
        fill="#fff"
        font-size="10"
        font-family="'Segoe UI',Tahoma,sans-serif"
        font-weight="bold"
      >
        3
      </text>
      <text
        x="210"
        y="161"
        text-anchor="middle"
        fill="#000"
        font-size="12"
        font-family="'Segoe UI',Tahoma,sans-serif"
      >
        Direct P2P connection established
      </text>
      
    <!-- Arrow 3→4 -->
      <line x1="210" y1="174" x2="210" y2="200" stroke="#008080" stroke-width="2" />
      <polygon points="210,200 205,192 215,192" fill="#008080" />
      
    <!-- Step 4 (highlighted) -->
      <rect
        x="60"
        y="202"
        width="300"
        height="36"
        rx="0"
        fill="#c0c0c0"
        stroke="#008080"
        stroke-width="2"
      />
      <rect x="62" y="204" width="20" height="14" rx="0" fill="#008080" />
      <text
        x="72"
        y="215"
        text-anchor="middle"
        fill="#fff"
        font-size="10"
        font-family="'Segoe UI',Tahoma,sans-serif"
        font-weight="bold"
      >
        4
      </text>
      <text
        x="210"
        y="225"
        text-anchor="middle"
        fill="#000"
        font-size="12"
        font-family="'Segoe UI',Tahoma,sans-serif"
      >
        Voice, video, and files flow directly
      </text>
      
    <!-- Alice ↔ Bob arrow -->
      <rect
        x="80"
        y="258"
        width="70"
        height="32"
        rx="0"
        fill="#c0c0c0"
        stroke="#808080"
        stroke-width="1.5"
      />
      <text
        x="115"
        y="278"
        text-anchor="middle"
        fill="#000"
        font-size="11"
        font-family="'Segoe UI',Tahoma,sans-serif"
        font-weight="bold"
      >
        Alice
      </text>
      <rect
        x="270"
        y="258"
        width="70"
        height="32"
        rx="0"
        fill="#c0c0c0"
        stroke="#808080"
        stroke-width="1.5"
      />
      <text
        x="305"
        y="278"
        text-anchor="middle"
        fill="#000"
        font-size="11"
        font-family="'Segoe UI',Tahoma,sans-serif"
        font-weight="bold"
      >
        Bob
      </text>
      <line x1="155" y1="274" x2="265" y2="274" stroke="#008080" stroke-width="3" />
      <polygon points="265,274 257,269 257,279" fill="#008080" />
      <polygon points="155,274 163,269 163,279" fill="#008080" />
      
    <!-- "server is out of the loop" -->
      <text
        x="210"
        y="316"
        text-anchor="middle"
        fill="#808080"
        font-size="10"
        font-family="'Segoe UI',Tahoma,sans-serif"
        font-style="italic"
      >
        (server is out of the loop)
      </text>
    </svg>
    """
  end

  # ──────────────────────────────────────────────────
  # Security Layers Diagram (how_it_works — tab-security)
  # ──────────────────────────────────────────────────

  attr :class, :string, default: nil

  @spec diagram_security_layers(map()) :: Phoenix.LiveView.Rendered.t()
  def diagram_security_layers(assigns) do
    ~H"""
    <svg
      class={@class}
      viewBox="0 0 520 290"
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-label="Two security layers: browser to server via HTTPS/WSS with TLS, and browser to browser via DTLS-SRTP for P2P calls"
    >
      <!-- Layer 1 label -->
      <text
        x="260"
        y="18"
        text-anchor="middle"
        fill="#005c5c"
        font-size="11"
        font-family="'Segoe UI',Tahoma,sans-serif"
        font-weight="bold"
      >
        LAYER 1 — Server Connection
      </text>
      
    <!-- Browser box (left) -->
      <rect
        x="30"
        y="30"
        width="120"
        height="50"
        rx="0"
        fill="#c0c0c0"
        stroke="#808080"
        stroke-width="2"
      />
      <rect x="32" y="32" width="116" height="16" fill="#000080" />
      <text
        x="90"
        y="44"
        text-anchor="middle"
        fill="#fff"
        font-size="10"
        font-family="'Segoe UI',Tahoma,sans-serif"
        font-weight="bold"
      >
        Browser
      </text>
      <!-- Lock icon -->
      <rect
        x="74"
        y="56"
        width="12"
        height="10"
        rx="1"
        fill="#008080"
        stroke="#005c5c"
        stroke-width="1"
      />
      <path
        d="M77,56 V52 a3,3 0 0 1 6,0 V56"
        fill="none"
        stroke="#005c5c"
        stroke-width="1.5"
      />
      <text
        x="90"
        y="72"
        text-anchor="middle"
        fill="#000"
        font-size="9"
        font-family="'Segoe UI',Tahoma,sans-serif"
      >
        TLS 1.3
      </text>
      
    <!-- Server box (right) -->
      <rect
        x="370"
        y="30"
        width="120"
        height="50"
        rx="0"
        fill="#c0c0c0"
        stroke="#808080"
        stroke-width="2"
      />
      <rect x="372" y="32" width="116" height="16" fill="#000080" />
      <text
        x="430"
        y="44"
        text-anchor="middle"
        fill="#fff"
        font-size="10"
        font-family="'Segoe UI',Tahoma,sans-serif"
        font-weight="bold"
      >
        Server
      </text>
      <!-- Shield icon -->
      <path
        d="M425,54 L430,51 L435,54 L435,62 C435,66 430,69 430,69 C430,69 425,66 425,62 Z"
        fill="#008080"
        stroke="#005c5c"
        stroke-width="1"
      />
      <text
        x="430"
        y="72"
        text-anchor="middle"
        fill="#000"
        font-size="9"
        font-family="'Segoe UI',Tahoma,sans-serif"
      >
        Protected
      </text>
      
    <!-- HTTPS/WSS connection line -->
      <line x1="155" y1="55" x2="365" y2="55" stroke="#008080" stroke-width="2" />
      <polygon points="365,55 357,50 357,60" fill="#008080" />
      <polygon points="155,55 163,50 163,60" fill="#008080" />
      <rect x="200" y="43" width="120" height="16" rx="2" fill="#008080" />
      <text
        x="260"
        y="55"
        text-anchor="middle"
        fill="#fff"
        font-size="10"
        font-family="'Segoe UI',Tahoma,sans-serif"
        font-weight="bold"
      >
        HTTPS / WSS
      </text>
      
    <!-- Server features -->
      <text
        x="430"
        y="100"
        text-anchor="middle"
        fill="#444"
        font-size="9"
        font-family="'Segoe UI',Tahoma,sans-serif"
      >
        bcrypt hashing
      </text>
      <text
        x="430"
        y="112"
        text-anchor="middle"
        fill="#444"
        font-size="9"
        font-family="'Segoe UI',Tahoma,sans-serif"
      >
        rate limiting
      </text>
      <text
        x="430"
        y="124"
        text-anchor="middle"
        fill="#444"
        font-size="9"
        font-family="'Segoe UI',Tahoma,sans-serif"
      >
        CSRF protection
      </text>
      
    <!-- Separator line -->
      <line
        x1="30"
        y1="145"
        x2="490"
        y2="145"
        stroke="#c0c0c0"
        stroke-width="1"
        stroke-dasharray="4,3"
      />
      
    <!-- Layer 2 label -->
      <text
        x="260"
        y="168"
        text-anchor="middle"
        fill="#005c5c"
        font-size="11"
        font-family="'Segoe UI',Tahoma,sans-serif"
        font-weight="bold"
      >
        LAYER 2 — P2P Calls (end-to-end)
      </text>
      
    <!-- Browser box (left) -->
      <rect
        x="30"
        y="180"
        width="120"
        height="50"
        rx="0"
        fill="#c0c0c0"
        stroke="#808080"
        stroke-width="2"
      />
      <rect x="32" y="182" width="116" height="16" fill="#000080" />
      <text
        x="90"
        y="194"
        text-anchor="middle"
        fill="#fff"
        font-size="10"
        font-family="'Segoe UI',Tahoma,sans-serif"
        font-weight="bold"
      >
        Browser
      </text>
      <rect
        x="74"
        y="206"
        width="12"
        height="10"
        rx="1"
        fill="#008080"
        stroke="#005c5c"
        stroke-width="1"
      />
      <path
        d="M77,206 V202 a3,3 0 0 1 6,0 V206"
        fill="none"
        stroke="#005c5c"
        stroke-width="1.5"
      />
      <text
        x="90"
        y="222"
        text-anchor="middle"
        fill="#000"
        font-size="9"
        font-family="'Segoe UI',Tahoma,sans-serif"
      >
        E2E encrypted
      </text>
      
    <!-- Browser box (right) -->
      <rect
        x="370"
        y="180"
        width="120"
        height="50"
        rx="0"
        fill="#c0c0c0"
        stroke="#808080"
        stroke-width="2"
      />
      <rect x="372" y="182" width="116" height="16" fill="#000080" />
      <text
        x="430"
        y="194"
        text-anchor="middle"
        fill="#fff"
        font-size="10"
        font-family="'Segoe UI',Tahoma,sans-serif"
        font-weight="bold"
      >
        Browser
      </text>
      <rect
        x="414"
        y="206"
        width="12"
        height="10"
        rx="1"
        fill="#008080"
        stroke="#005c5c"
        stroke-width="1"
      />
      <path
        d="M417,206 V202 a3,3 0 0 1 6,0 V206"
        fill="none"
        stroke="#005c5c"
        stroke-width="1.5"
      />
      <text
        x="430"
        y="222"
        text-anchor="middle"
        fill="#000"
        font-size="9"
        font-family="'Segoe UI',Tahoma,sans-serif"
      >
        E2E encrypted
      </text>
      
    <!-- DTLS-SRTP connection line -->
      <line x1="155" y1="205" x2="365" y2="205" stroke="#008080" stroke-width="2" />
      <polygon points="365,205 357,200 357,210" fill="#008080" />
      <polygon points="155,205 163,200 163,210" fill="#008080" />
      <rect x="200" y="193" width="120" height="16" rx="2" fill="#008080" />
      <text
        x="260"
        y="205"
        text-anchor="middle"
        fill="#fff"
        font-size="10"
        font-family="'Segoe UI',Tahoma,sans-serif"
        font-weight="bold"
      >
        DTLS-SRTP
      </text>
      
    <!-- P2P description -->
      <text
        x="260"
        y="260"
        text-anchor="middle"
        fill="#444"
        font-size="9"
        font-family="'Segoe UI',Tahoma,sans-serif"
      >
        P2P calls encrypted end-to-end via WebRTC
      </text>
      <text
        x="260"
        y="275"
        text-anchor="middle"
        fill="#808080"
        font-size="9"
        font-family="'Segoe UI',Tahoma,sans-serif"
        font-style="italic"
      >
        Server never sees voice/video data
      </text>
    </svg>
    """
  end

  # ──────────────────────────────────────────────────
  # P2P Architecture Diagram (about page)
  # ──────────────────────────────────────────────────

  attr :class, :string, default: nil

  @spec diagram_p2p_architecture(map()) :: Phoenix.LiveView.Rendered.t()
  def diagram_p2p_architecture(assigns) do
    ~H"""
    <svg
      class={@class}
      viewBox="0 0 520 260"
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-label="Peer-to-peer connection diagram showing Alice and Bob connected directly via WebRTC, with the server only used for signaling"
    >
      <!-- Alice window -->
      <rect
        x="20"
        y="20"
        width="140"
        height="80"
        rx="0"
        fill="#c0c0c0"
        stroke="#808080"
        stroke-width="2"
      />
      <rect x="22" y="22" width="136" height="20" fill="#000080" />
      <text
        x="90"
        y="36"
        text-anchor="middle"
        fill="#fff"
        font-size="12"
        font-family="'Segoe UI',Tahoma,sans-serif"
        font-weight="bold"
      >
        Alice
      </text>
      <text x="90" y="72" text-anchor="middle" fill="#000" font-size="28">&#x1F468;</text>
      
    <!-- Bob window -->
      <rect
        x="360"
        y="20"
        width="140"
        height="80"
        rx="0"
        fill="#c0c0c0"
        stroke="#808080"
        stroke-width="2"
      />
      <rect x="362" y="22" width="136" height="20" fill="#000080" />
      <text
        x="430"
        y="36"
        text-anchor="middle"
        fill="#fff"
        font-size="12"
        font-family="'Segoe UI',Tahoma,sans-serif"
        font-weight="bold"
      >
        Bob
      </text>
      <text x="430" y="72" text-anchor="middle" fill="#000" font-size="28">&#x1F469;</text>
      
    <!-- P2P arrow (bidirectional) -->
      <line x1="165" y1="55" x2="355" y2="55" stroke="#008080" stroke-width="3" />
      <polygon points="355,55 345,49 345,61" fill="#008080" />
      <polygon points="165,55 175,49 175,61" fill="#008080" />
      <rect x="195" y="40" width="130" height="16" rx="2" fill="#008080" />
      <text
        x="260"
        y="52"
        text-anchor="middle"
        fill="#fff"
        font-size="10"
        font-family="'Segoe UI',Tahoma,sans-serif"
        font-weight="bold"
      >
        WebRTC P2P
      </text>
      <text
        x="260"
        y="78"
        text-anchor="middle"
        fill="#005c5c"
        font-size="11"
        font-family="'Segoe UI',Tahoma,sans-serif"
      >
        voice / video / files
      </text>
      
    <!-- Dashed lines to server -->
      <line
        x1="90"
        y1="105"
        x2="90"
        y2="170"
        stroke="#808080"
        stroke-width="1.5"
        stroke-dasharray="5,4"
      />
      <line
        x1="430"
        y1="105"
        x2="430"
        y2="170"
        stroke="#808080"
        stroke-width="1.5"
        stroke-dasharray="5,4"
      />
      <line
        x1="90"
        y1="170"
        x2="430"
        y2="170"
        stroke="#808080"
        stroke-width="1.5"
        stroke-dasharray="5,4"
      />
      <line
        x1="260"
        y1="170"
        x2="260"
        y2="190"
        stroke="#808080"
        stroke-width="1.5"
        stroke-dasharray="5,4"
      />
      
    <!-- Server box (smaller, secondary) -->
      <rect
        x="195"
        y="190"
        width="130"
        height="50"
        rx="0"
        fill="#dfdfdf"
        stroke="#808080"
        stroke-width="1.5"
      />
      <rect x="197" y="192" width="126" height="16" fill="#808080" />
      <text
        x="260"
        y="204"
        text-anchor="middle"
        fill="#fff"
        font-size="10"
        font-family="'Segoe UI',Tahoma,sans-serif"
      >
        Server (signaling)
      </text>
      <text
        x="260"
        y="226"
        text-anchor="middle"
        fill="#666"
        font-size="9"
        font-family="'Segoe UI',Tahoma,sans-serif"
      >
        only connects them
      </text>
      <text
        x="260"
        y="236"
        text-anchor="middle"
        fill="#666"
        font-size="9"
        font-family="'Segoe UI',Tahoma,sans-serif"
      >
        never sees the data
      </text>
    </svg>
    """
  end

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
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-label="Retro-style voice call window showing timer, mute, camera, screen share, and end call buttons"
    >
      <!-- Window frame -->
      <rect
        x="10"
        y="10"
        width="320"
        height="130"
        rx="0"
        fill="#c0c0c0"
        stroke="#808080"
        stroke-width="2"
      />
      <!-- Title bar -->
      <rect x="12" y="12" width="316" height="20" fill="#000080" />
      <text
        x="22"
        y="26"
        fill="#fff"
        font-size="11"
        font-family="'Segoe UI',Tahoma,sans-serif"
        font-weight="bold"
      >
        Voice Call with Bob
      </text>
      <!-- Title bar buttons -->
      <rect
        x="290"
        y="15"
        width="14"
        height="14"
        rx="0"
        fill="#c0c0c0"
        stroke="#808080"
        stroke-width="1"
      />
      <line x1="293" y1="18" x2="301" y2="26" stroke="#000" stroke-width="1.5" />
      <line x1="301" y1="18" x2="293" y2="26" stroke="#000" stroke-width="1.5" />
      <rect
        x="272"
        y="15"
        width="14"
        height="14"
        rx="0"
        fill="#c0c0c0"
        stroke="#808080"
        stroke-width="1"
      />
      
    <!-- Timer area -->
      <circle cx="80" cy="62" r="5" fill="#cc0000" />
      <text
        x="95"
        y="66"
        fill="#000"
        font-size="18"
        font-family="'Source Code Pro','Courier New',monospace"
        font-weight="bold"
      >
        00:03:42
      </text>
      
    <!-- Call buttons -->
      <!-- Mute -->
      <rect x="30" y="90" width="60" height="28" rx="0" fill="#c0c0c0" />
      <line x1="30" y1="90" x2="90" y2="90" stroke="#fff" stroke-width="1" />
      <line x1="30" y1="90" x2="30" y2="118" stroke="#fff" stroke-width="1" />
      <line x1="90" y1="90" x2="90" y2="118" stroke="#808080" stroke-width="1" />
      <line x1="30" y1="118" x2="90" y2="118" stroke="#808080" stroke-width="1" />
      <text
        x="60"
        y="108"
        text-anchor="middle"
        fill="#000"
        font-size="11"
        font-family="'Segoe UI',Tahoma,sans-serif"
      >
        Mute
      </text>
      
    <!-- Camera -->
      <rect x="100" y="90" width="60" height="28" rx="0" fill="#c0c0c0" />
      <line x1="100" y1="90" x2="160" y2="90" stroke="#fff" stroke-width="1" />
      <line x1="100" y1="90" x2="100" y2="118" stroke="#fff" stroke-width="1" />
      <line x1="160" y1="90" x2="160" y2="118" stroke="#808080" stroke-width="1" />
      <line x1="100" y1="118" x2="160" y2="118" stroke="#808080" stroke-width="1" />
      <text
        x="130"
        y="108"
        text-anchor="middle"
        fill="#000"
        font-size="11"
        font-family="'Segoe UI',Tahoma,sans-serif"
      >
        Camera
      </text>
      
    <!-- Screen -->
      <rect x="170" y="90" width="60" height="28" rx="0" fill="#c0c0c0" />
      <line x1="170" y1="90" x2="230" y2="90" stroke="#fff" stroke-width="1" />
      <line x1="170" y1="90" x2="170" y2="118" stroke="#fff" stroke-width="1" />
      <line x1="230" y1="90" x2="230" y2="118" stroke="#808080" stroke-width="1" />
      <line x1="170" y1="118" x2="230" y2="118" stroke="#808080" stroke-width="1" />
      <text
        x="200"
        y="108"
        text-anchor="middle"
        fill="#000"
        font-size="11"
        font-family="'Segoe UI',Tahoma,sans-serif"
      >
        Screen
      </text>
      
    <!-- End (reddish) -->
      <rect x="240" y="90" width="60" height="28" rx="0" fill="#d4a0a0" />
      <line x1="240" y1="90" x2="300" y2="90" stroke="#e8c0c0" stroke-width="1" />
      <line x1="240" y1="90" x2="240" y2="118" stroke="#e8c0c0" stroke-width="1" />
      <line x1="300" y1="90" x2="300" y2="118" stroke="#993333" stroke-width="1" />
      <line x1="240" y1="118" x2="300" y2="118" stroke="#993333" stroke-width="1" />
      <text
        x="270"
        y="108"
        text-anchor="middle"
        fill="#660000"
        font-size="11"
        font-family="'Segoe UI',Tahoma,sans-serif"
        font-weight="bold"
      >
        End
      </text>
    </svg>
    """
  end
end
