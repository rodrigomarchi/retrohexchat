defmodule RetroHexChatWeb.Components.Diagrams.P2pFlow do
  @moduledoc "SVG diagram for P2P connection flow."
  use Phoenix.Component

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
end
