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
      shape-rendering="crispEdges"
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-label="Vertical flowchart showing 4 steps: Alice calls Bob, server exchanges signaling, P2P connection established, then direct data flow with server out of the loop"
    >
      <!-- Base Background/Grid or we can just leave it transparent -->

      <!-- Step 1: Alice wants to call Bob -->
      <!-- Shadow -->
      <rect x="64" y="14" width="300" height="36" fill="#000" />
      <!-- Window Base -->
      <rect x="60" y="10" width="300" height="36" fill="#c0c0c0" stroke="#000" stroke-width="1" />
      <!-- Outset borders -->
      <polyline points="61,45 61,11 359,11" fill="none" stroke="#fff" stroke-width="1" />
      <polyline points="359,12 359,45 61,45" fill="none" stroke="#808080" stroke-width="1" />
      
    <!-- Number block (Inset) -->
      <rect x="64" y="14" width="20" height="28" fill="#000080" stroke="#000" stroke-width="1" />
      <polyline points="65,41 65,15 83,15" fill="none" stroke="#555" stroke-width="1" />
      <polyline points="83,16 83,41 65,41" fill="none" stroke="#fff" stroke-width="1" />
      <text
        x="74"
        y="33"
        text-anchor="middle"
        fill="#fff"
        font-size="14"
        font-family="'Courier New',monospace"
        font-weight="bold"
      >
        1
      </text>
      
    <!-- Text -->
      <text
        x="210"
        y="32"
        text-anchor="middle"
        fill="#000"
        font-size="12"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        Alice wants to call Bob
      </text>
      
    <!-- Arrow 1->2 -->
      <rect x="208" y="47" width="4" height="25" fill="#000" />
      <path d="M202 68 h16 l-8 8 z" fill="#000" />
      <!-- Arrow Highlights -->
      <rect x="208" y="47" width="2" height="23" fill="#808080" />
      <path d="M204 68 h10 l-5 5 z" fill="#808080" />
      
    <!-- Step 2: Server signaling -->
      <rect x="64" y="78" width="300" height="36" fill="#000" />
      <rect x="60" y="74" width="300" height="36" fill="#c0c0c0" stroke="#000" stroke-width="1" />
      <polyline points="61,109 61,75 359,75" fill="none" stroke="#fff" stroke-width="1" />
      <polyline points="359,76 359,109 61,109" fill="none" stroke="#808080" stroke-width="1" />

      <rect x="64" y="78" width="20" height="28" fill="#000080" stroke="#000" stroke-width="1" />
      <polyline points="65,105 65,79 83,79" fill="none" stroke="#555" stroke-width="1" />
      <polyline points="83,80 83,105 65,105" fill="none" stroke="#fff" stroke-width="1" />
      <text
        x="74"
        y="97"
        text-anchor="middle"
        fill="#fff"
        font-size="14"
        font-family="'Courier New',monospace"
        font-weight="bold"
      >
        2
      </text>
      <text
        x="210"
        y="96"
        text-anchor="middle"
        fill="#000"
        font-size="12"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        Server exchanges signaling (SDP/ICE)
      </text>
      
    <!-- Arrow 2->3 -->
      <rect x="208" y="111" width="4" height="25" fill="#000" />
      <path d="M202 132 h16 l-8 8 z" fill="#000" />
      <rect x="208" y="111" width="2" height="23" fill="#808080" />
      <path d="M204 132 h10 l-5 5 z" fill="#808080" />
      
    <!-- Step 3: P2P Connection established -->
      <rect x="64" y="142" width="300" height="36" fill="#000" />
      <rect x="60" y="138" width="300" height="36" fill="#c0c0c0" stroke="#000" stroke-width="1" />
      <polyline points="61,173 61,139 359,139" fill="none" stroke="#fff" stroke-width="1" />
      <polyline points="359,140 359,173 61,173" fill="none" stroke="#808080" stroke-width="1" />

      <rect x="64" y="142" width="20" height="28" fill="#000080" stroke="#000" stroke-width="1" />
      <polyline points="65,169 65,143 83,143" fill="none" stroke="#555" stroke-width="1" />
      <polyline points="83,144 83,169 65,169" fill="none" stroke="#fff" stroke-width="1" />
      <text
        x="74"
        y="161"
        text-anchor="middle"
        fill="#fff"
        font-size="14"
        font-family="'Courier New',monospace"
        font-weight="bold"
      >
        3
      </text>
      <text
        x="210"
        y="160"
        text-anchor="middle"
        fill="#000"
        font-size="12"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        Direct P2P connection established
      </text>
      
    <!-- Arrow 3->4 (Accent color to show success) -->
      <rect x="208" y="175" width="4" height="25" fill="#000" />
      <path d="M202 196 h16 l-8 8 z" fill="#000" />
      <rect x="208" y="175" width="2" height="23" fill="#00ff00" />
      <path d="M204 196 h10 l-5 5 z" fill="#00ff00" />
      
    <!-- Step 4: Direct Data Flow -->
      <rect x="64" y="206" width="300" height="36" fill="#000" />
      <rect x="60" y="202" width="300" height="36" fill="#c0c0c0" stroke="#000" stroke-width="1" />
      <!-- Highlight box to make step 4 pop out more -->
      <rect x="61" y="203" width="298" height="34" fill="none" stroke="#00FF00" />
      <polyline points="61,237 61,203 359,203" fill="none" stroke="#fff" stroke-width="1" />
      <polyline points="359,204 359,237 61,237" fill="none" stroke="#808080" stroke-width="1" />

      <rect x="64" y="206" width="20" height="28" fill="#008000" stroke="#000" stroke-width="1" />
      <polyline points="65,233 65,207 83,207" fill="none" stroke="#005500" stroke-width="1" />
      <polyline points="83,208 83,233 65,233" fill="none" stroke="#00ff00" stroke-width="1" />
      <text
        x="74"
        y="225"
        text-anchor="middle"
        fill="#fff"
        font-size="14"
        font-family="'Courier New',monospace"
        font-weight="bold"
      >
        4
      </text>
      <text
        x="210"
        y="224"
        text-anchor="middle"
        fill="#000"
        font-size="12"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        Voice, video, and files flow directly
      </text>
      
    <!-- Alice & Bob nodes -->
      <!-- Alice Shadow -->
      <rect x="84" y="262" width="70" height="32" fill="#000" />
      <!-- Alice Box -->
      <rect x="80" y="258" width="70" height="32" fill="#dfdfdf" stroke="#000" stroke-width="1" />
      <polyline points="81,289 81,259 149,259" fill="none" stroke="#fff" stroke-width="1" />
      <polyline points="149,260 149,289 81,289" fill="none" stroke="#808080" stroke-width="1" />
      <rect x="83" y="261" width="64" height="12" fill="#000080" />
      <text
        x="115"
        y="270"
        text-anchor="middle"
        fill="#fff"
        font-size="10"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        Alice
      </text>
      <rect x="84" y="275" width="62" height="12" fill="#fff" stroke="#808080" stroke-width="1" />
      <text
        x="115"
        y="284"
        text-anchor="middle"
        fill="#000"
        font-size="9"
        font-family="Tahoma,sans-serif"
      >
        Connected
      </text>
      
    <!-- Bob Shadow -->
      <rect x="274" y="262" width="70" height="32" fill="#000" />
      <!-- Bob Box -->
      <rect x="270" y="258" width="70" height="32" fill="#dfdfdf" stroke="#000" stroke-width="1" />
      <polyline points="271,289 271,259 339,259" fill="none" stroke="#fff" stroke-width="1" />
      <polyline points="339,260 339,289 271,289" fill="none" stroke="#808080" stroke-width="1" />
      <rect x="273" y="261" width="64" height="12" fill="#000080" />
      <text
        x="305"
        y="270"
        text-anchor="middle"
        fill="#fff"
        font-size="10"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        Bob
      </text>
      <rect x="274" y="275" width="62" height="12" fill="#fff" stroke="#808080" stroke-width="1" />
      <text
        x="305"
        y="284"
        text-anchor="middle"
        fill="#000"
        font-size="9"
        font-family="Tahoma,sans-serif"
      >
        Connected
      </text>
      
    <!-- Bidirectional Data Flow Arrow -->
      <rect x="150" y="270" width="120" height="8" fill="#000" />
      <rect x="156" y="270" width="108" height="6" fill="#00ff00" />
      <!-- Left head -->
      <path d="M156 266 l-8 8 l8 8 z" fill="#000" />
      <path d="M156 268 l-6 6 l6 6 z" fill="#00ff00" />
      <!-- Right head -->
      <path d="M264 266 l8 8 l-8 8 z" fill="#000" />
      <path d="M264 268 l6 6 l-6 6 z" fill="#00ff00" />
      
    <!-- Description (Server out of the loop) -->
      <!-- Tooltip style bounding box -->
      <rect x="135" y="300" width="150" height="18" fill="#ffffcc" stroke="#000" stroke-width="1" />
      <polyline points="135,317 135,301 284,301" fill="none" stroke="#fff" stroke-width="1" />
      <polyline points="284,302 284,317 136,317" fill="none" stroke="#808080" stroke-width="1" />
      <text
        x="210"
        y="312"
        text-anchor="middle"
        fill="#000"
        font-size="10"
        font-family="Tahoma,sans-serif"
      >
        Server is out of the loop
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
      shape-rendering="crispEdges"
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-label="Two security layers: browser to server via HTTPS/WSS with TLS, and browser to browser via DTLS-SRTP for P2P calls"
    >
      <!-- Common Window styles -->

      <!-- Layer 1 label -->
      <text
        x="260"
        y="20"
        text-anchor="middle"
        fill="#000"
        font-size="12"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        LAYER 1 — Server Connection
      </text>
      
    <!-- Browser box (left) -->
      <!-- Shadow -->
      <rect x="34" y="34" width="120" height="50" fill="#000" />
      <!-- Window Background -->
      <rect x="30" y="30" width="120" height="50" fill="#c0c0c0" stroke="#000" stroke-width="1" />
      <polyline points="31,79 31,31 149,31" fill="none" stroke="#fff" stroke-width="1" />
      <polyline points="149,32 149,79 31,79" fill="none" stroke="#808080" stroke-width="1" />
      
    <!-- Title bar -->
      <rect x="33" y="33" width="114" height="18" fill="#000080" />
      <text
        x="90"
        y="46"
        text-anchor="middle"
        fill="#fff"
        font-size="11"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        Browser
      </text>
      
    <!-- Inside lock area -->
      <rect x="74" y="55" width="12" height="10" fill="#008080" stroke="#000" stroke-width="1" />
      <!-- Lock hoop -->
      <path d="M77 55 v-3 h6 v3" fill="none" stroke="#000" stroke-width="1.5" />
      <path d="M78 55 v-2 h4 v2" fill="none" stroke="#fff" stroke-width="1" />
      <text
        x="96"
        y="64"
        text-anchor="start"
        fill="#000"
        font-size="10"
        font-family="Tahoma,sans-serif"
      >
        TLS 1.3
      </text>
      
    <!-- Server box (right) -->
      <!-- Shadow -->
      <rect x="374" y="34" width="120" height="50" fill="#000" />
      <!-- Window Background -->
      <rect x="370" y="30" width="120" height="50" fill="#c0c0c0" stroke="#000" stroke-width="1" />
      <polyline points="371,79 371,31 489,31" fill="none" stroke="#fff" stroke-width="1" />
      <polyline points="489,32 489,79 371,79" fill="none" stroke="#808080" stroke-width="1" />
      
    <!-- Title bar -->
      <rect x="373" y="33" width="114" height="18" fill="#000080" />
      <text
        x="430"
        y="46"
        text-anchor="middle"
        fill="#fff"
        font-size="11"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        Server
      </text>
      
    <!-- Shield icon -->
      <path d="M422 55 h10 v6 l-5 5 l-5 -5 z" fill="#008080" stroke="#000" stroke-width="1" />
      <path d="M423 56 h8 v5 l-4 4 l-4 -4 z" fill="none" stroke="#fff" stroke-width="1" />
      <text
        x="438"
        y="64"
        text-anchor="start"
        fill="#000"
        font-size="10"
        font-family="Tahoma,sans-serif"
      >
        Protected
      </text>
      
    <!-- HTTPS/WSS connection line -->
      <rect x="156" y="54" width="208" height="4" fill="#000" />
      <path d="M152 56 l8 -6 v12 z" fill="#000" />
      <path d="M368 56 l-8 -6 v12 z" fill="#000" />
      
    <!-- Inner line accent -->
      <rect x="160" y="55" width="200" height="2" fill="#008080" />
      <path d="M154 56 l6 -4 v8 z" fill="#008080" />
      <path d="M366 56 l-6 -4 v8 z" fill="#008080" />
      
    <!-- Protocol label inset -->
      <rect x="220" y="45" width="80" height="18" fill="#008080" stroke="#000" stroke-width="1" />
      <polyline points="221,62 221,46 299,46" fill="none" stroke="#005500" stroke-width="1" />
      <polyline points="299,47 299,62 221,62" fill="none" stroke="#00ff00" stroke-width="1" />
      <text
        x="260"
        y="58"
        text-anchor="middle"
        fill="#fff"
        font-size="10"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        HTTPS / WSS
      </text>
      
    <!-- Server features (Tooltip style) -->
      <rect x="374" y="90" width="120" height="44" fill="#ffffcc" stroke="#000" stroke-width="1" />
      <polyline points="375,133 375,91 493,91" fill="none" stroke="#fff" stroke-width="1" />
      <polyline points="493,92 493,133 375,133" fill="none" stroke="#808080" stroke-width="1" />
      <text
        x="434"
        y="103"
        text-anchor="middle"
        fill="#000"
        font-size="10"
        font-family="Tahoma,sans-serif"
      >
        · bcrypt hashing
      </text>
      <text
        x="434"
        y="115"
        text-anchor="middle"
        fill="#000"
        font-size="10"
        font-family="Tahoma,sans-serif"
      >
        · rate limiting
      </text>
      <text
        x="434"
        y="127"
        text-anchor="middle"
        fill="#000"
        font-size="10"
        font-family="Tahoma,sans-serif"
      >
        · CSRF protection
      </text>
      
    <!-- Separator line (engraved style) -->
      <line
        x1="10"
        y1="145"
        x2="510"
        y2="145"
        stroke="#808080"
        stroke-width="1"
        stroke-dasharray="4,4"
      />
      <line x1="10" y1="146" x2="510" y2="146" stroke="#fff" stroke-width="1" stroke-dasharray="4,4" />
      
    <!-- Layer 2 label -->
      <text
        x="260"
        y="170"
        text-anchor="middle"
        fill="#000"
        font-size="12"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        LAYER 2 — P2P Calls (end-to-end)
      </text>
      
    <!-- Browser box (left, Bottom) -->
      <rect x="34" y="184" width="120" height="50" fill="#000" />
      <rect x="30" y="180" width="120" height="50" fill="#c0c0c0" stroke="#000" stroke-width="1" />
      <polyline points="31,229 31,181 149,181" fill="none" stroke="#fff" stroke-width="1" />
      <polyline points="149,182 149,229 31,229" fill="none" stroke="#808080" stroke-width="1" />

      <rect x="33" y="183" width="114" height="18" fill="#000080" />
      <text
        x="90"
        y="196"
        text-anchor="middle"
        fill="#fff"
        font-size="11"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        Browser
      </text>

      <rect x="54" y="205" width="12" height="10" fill="#008080" stroke="#000" stroke-width="1" />
      <path d="M57 205 v-3 h6 v3" fill="none" stroke="#000" stroke-width="1.5" />
      <path d="M58 205 v-2 h4 v2" fill="none" stroke="#fff" stroke-width="1" />
      <text
        x="74"
        y="214"
        text-anchor="start"
        fill="#000"
        font-size="10"
        font-family="Tahoma,sans-serif"
      >
        E2E enc
      </text>
      
    <!-- Browser box (right, Bottom) -->
      <rect x="374" y="184" width="120" height="50" fill="#000" />
      <rect x="370" y="180" width="120" height="50" fill="#c0c0c0" stroke="#000" stroke-width="1" />
      <polyline points="371,229 371,181 489,181" fill="none" stroke="#fff" stroke-width="1" />
      <polyline points="489,182 489,229 371,229" fill="none" stroke="#808080" stroke-width="1" />

      <rect x="373" y="183" width="114" height="18" fill="#000080" />
      <text
        x="430"
        y="196"
        text-anchor="middle"
        fill="#fff"
        font-size="11"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        Browser
      </text>

      <rect x="394" y="205" width="12" height="10" fill="#008080" stroke="#000" stroke-width="1" />
      <path d="M397 205 v-3 h6 v3" fill="none" stroke="#000" stroke-width="1.5" />
      <path d="M398 205 v-2 h4 v2" fill="none" stroke="#fff" stroke-width="1" />
      <text
        x="414"
        y="214"
        text-anchor="start"
        fill="#000"
        font-size="10"
        font-family="Tahoma,sans-serif"
      >
        E2E enc
      </text>
      
    <!-- DTLS-SRTP connection line -->
      <rect x="156" y="204" width="208" height="4" fill="#000" />
      <path d="M152 206 l8 -6 v12 z" fill="#000" />
      <path d="M368 206 l-8 -6 v12 z" fill="#000" />

      <rect x="160" y="205" width="200" height="2" fill="#008080" />
      <path d="M154 206 l6 -4 v8 z" fill="#008080" />
      <path d="M366 206 l-6 -4 v8 z" fill="#008080" />
      
    <!-- Protocol label inset -->
      <rect x="220" y="195" width="80" height="18" fill="#008080" stroke="#000" stroke-width="1" />
      <polyline points="221,212 221,196 299,196" fill="none" stroke="#005500" stroke-width="1" />
      <polyline points="299,197 299,212 221,212" fill="none" stroke="#00ff00" stroke-width="1" />
      <text
        x="260"
        y="208"
        text-anchor="middle"
        fill="#fff"
        font-size="10"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        DTLS / SRTP
      </text>
      
    <!-- P2P description -->
      <!-- Tooltip container -->
      <rect x="140" y="240" width="240" height="34" fill="#ffffcc" stroke="#000" stroke-width="1" />
      <polyline points="141,273 141,241 379,241" fill="none" stroke="#fff" stroke-width="1" />
      <polyline points="379,242 379,273 141,273" fill="none" stroke="#808080" stroke-width="1" />
      <text
        x="260"
        y="254"
        text-anchor="middle"
        fill="#000"
        font-size="10"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        P2P calls encrypted end-to-end via WebRTC
      </text>
      <text
        x="260"
        y="268"
        text-anchor="middle"
        fill="#444"
        font-size="10"
        font-family="Tahoma,sans-serif"
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
      shape-rendering="crispEdges"
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-label="Peer-to-peer connection diagram showing Alice and Bob connected directly via WebRTC, with the server only used for signaling"
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
        Alice
      </text>
      <!-- Content Area Inset -->
      <rect x="26" y="48" width="128" height="46" fill="#dfdfdf" stroke="#000" stroke-width="1" />
      <polyline points="27,93 27,49 153,49" fill="none" stroke="#808080" stroke-width="1" />
      <polyline points="153,50 153,93 27,93" fill="none" stroke="#fff" stroke-width="1" />

      <text x="90" y="80" text-anchor="middle" fill="#000" font-size="28">&#x1F468;</text>
      
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
        Bob
      </text>
      <!-- Content Area Inset -->
      <rect x="366" y="48" width="128" height="46" fill="#dfdfdf" stroke="#000" stroke-width="1" />
      <polyline points="367,93 367,49 493,49" fill="none" stroke="#808080" stroke-width="1" />
      <polyline points="493,50 493,93 367,93" fill="none" stroke="#fff" stroke-width="1" />

      <text x="430" y="80" text-anchor="middle" fill="#000" font-size="28">&#x1F469;</text>
      
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
        WebRTC P2P
      </text>
      <text
        x="260"
        y="62"
        text-anchor="middle"
        fill="#000"
        font-size="9"
        font-family="Tahoma,sans-serif"
      >
        voice / video / files
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
        Server (signaling)
      </text>

      <text
        x="256"
        y="230"
        text-anchor="middle"
        fill="#444"
        font-size="10"
        font-family="Tahoma,sans-serif"
      >
        · only connects them
      </text>
      <text
        x="256"
        y="244"
        text-anchor="middle"
        fill="#444"
        font-size="10"
        font-family="Tahoma,sans-serif"
      >
        · never sees data
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
      shape-rendering="crispEdges"
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-label="Retro-style voice call window showing timer, mute, camera, screen share, and end call buttons"
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
        Voice Call with Bob
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
      <text x="46" y="74" text-anchor="middle" fill="#fff" font-size="20">&#x1F469;</text>
      
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
        Mute
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
        Camera
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
        Screen
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
        End
      </text>
    </svg>
    """
  end
end
