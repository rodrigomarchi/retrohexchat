defmodule RetroHexChatWeb.Components.Diagrams.GameArcadeFlow do
  @moduledoc "SVG diagram for Solo Arcade games flow."
  use Phoenix.Component

  attr :class, :string, default: nil

  @spec diagram_arcade_flow(map()) :: Phoenix.LiveView.Rendered.t()
  def diagram_arcade_flow(assigns) do
    ~H"""
    <svg
      class={@class}
      viewBox="0 0 420 380"
      shape-rendering="crispEdges"
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-label="Solo arcade flow: type !play in #games channel, pick a game from catalog, new window opens, WASM game runs in browser"
    >
      <%!-- ── Step 1: !play command in #games ── --%>
      <%!-- Shadow --%>
      <rect x="64" y="14" width="300" height="44" fill="#000" />
      <%!-- Window --%>
      <rect x="60" y="10" width="300" height="44" fill="#c0c0c0" stroke="#000" stroke-width="1" />
      <polyline points="61,53 61,11 359,11" fill="none" stroke="#fff" stroke-width="1" />
      <polyline points="359,12 359,53 61,53" fill="none" stroke="#808080" stroke-width="1" />
      <%!-- Title bar --%>
      <rect x="63" y="13" width="294" height="16" fill="#000080" />
      <rect x="65" y="15" width="14" height="12" fill="#000080" stroke="#000" stroke-width="1" />
      <text
        x="72"
        y="24"
        text-anchor="middle"
        fill="#fff"
        font-size="10"
        font-family="'Courier New',monospace"
        font-weight="bold"
      >
        1
      </text>
      <text
        x="210"
        y="25"
        text-anchor="middle"
        fill="#fff"
        font-size="9"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        #games
      </text>
      <%!-- Input field with !play --%>
      <rect x="70" y="34" width="178" height="14" fill="#fff" stroke="#808080" stroke-width="1" />
      <text
        x="74"
        y="45"
        fill="#000"
        font-size="9"
        font-family="'Courier New',monospace"
      >
        !play
      </text>
      <%!-- Send button --%>
      <rect x="254" y="34" width="40" height="14" fill="#c0c0c0" stroke="#000" stroke-width="1" />
      <polyline points="255,47 255,35 293,35" fill="none" stroke="#fff" stroke-width="1" />
      <polyline points="293,36 293,47 255,47" fill="none" stroke="#808080" stroke-width="1" />
      <text
        x="274"
        y="45"
        text-anchor="middle"
        fill="#000"
        font-size="8"
        font-family="Tahoma,sans-serif"
      >
        Send
      </text>

      <%!-- Arrow 1 → 2 --%>
      <rect x="208" y="55" width="4" height="18" fill="#000" />
      <path d="M202 69 h16 l-8 8 z" fill="#000" />
      <rect x="208" y="55" width="2" height="16" fill="#808080" />
      <path d="M204 69 h10 l-5 5 z" fill="#808080" />

      <%!-- ── Step 2: Arcade Lobby / Catalog ── --%>
      <%!-- Shadow --%>
      <rect x="64" y="82" width="300" height="82" fill="#000" />
      <%!-- Window --%>
      <rect x="60" y="78" width="300" height="82" fill="#c0c0c0" stroke="#000" stroke-width="1" />
      <polyline points="61,159 61,79 359,79" fill="none" stroke="#fff" stroke-width="1" />
      <polyline points="359,80 359,159 61,159" fill="none" stroke="#808080" stroke-width="1" />
      <%!-- Title bar --%>
      <rect x="63" y="81" width="294" height="16" fill="#000080" />
      <rect x="65" y="83" width="14" height="12" fill="#000080" stroke="#000" stroke-width="1" />
      <text
        x="72"
        y="92"
        text-anchor="middle"
        fill="#fff"
        font-size="10"
        font-family="'Courier New',monospace"
        font-weight="bold"
      >
        2
      </text>
      <text
        x="210"
        y="93"
        text-anchor="middle"
        fill="#fff"
        font-size="9"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        Arcade — Select a Game
      </text>
      <%!-- Content inset --%>
      <rect x="66" y="100" width="288" height="52" fill="#dfdfdf" stroke="#000" stroke-width="1" />
      <polyline points="67,151 67,101 353,101" fill="none" stroke="#808080" stroke-width="1" />
      <polyline points="353,102 353,151 67,151" fill="none" stroke="#fff" stroke-width="1" />
      <%!-- Game tiles: 2 rows × 3 cols --%>
      <%!-- Row 1 --%>
      <%!-- Selected tile --%>
      <rect x="72" y="104" width="86" height="20" fill="#000080" stroke="#000080" stroke-width="1" />
      <text
        x="115"
        y="117"
        text-anchor="middle"
        fill="#fff"
        font-size="8"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        DOOM
      </text>
      <rect x="162" y="104" width="86" height="20" fill="#fff" stroke="#808080" stroke-width="1" />
      <text
        x="205"
        y="117"
        text-anchor="middle"
        fill="#000"
        font-size="8"
        font-family="Tahoma,sans-serif"
      >
        Quake
      </text>
      <rect x="252" y="104" width="86" height="20" fill="#fff" stroke="#808080" stroke-width="1" />
      <text
        x="295"
        y="117"
        text-anchor="middle"
        fill="#000"
        font-size="8"
        font-family="Tahoma,sans-serif"
      >
        Wolf3D
      </text>
      <%!-- Row 2 --%>
      <rect x="72" y="128" width="86" height="20" fill="#fff" stroke="#808080" stroke-width="1" />
      <text
        x="115"
        y="141"
        text-anchor="middle"
        fill="#000"
        font-size="8"
        font-family="Tahoma,sans-serif"
      >
        BASS
      </text>
      <rect x="162" y="128" width="86" height="20" fill="#fff" stroke="#808080" stroke-width="1" />
      <text
        x="205"
        y="141"
        text-anchor="middle"
        fill="#000"
        font-size="8"
        font-family="Tahoma,sans-serif"
      >
        Quake II
      </text>
      <rect x="252" y="128" width="86" height="20" fill="#fff" stroke="#808080" stroke-width="1" />
      <text
        x="295"
        y="141"
        text-anchor="middle"
        fill="#000"
        font-size="8"
        font-family="Tahoma,sans-serif"
      >
        HacX
      </text>

      <%!-- Arrow 2 → 3 --%>
      <rect x="208" y="162" width="4" height="18" fill="#000" />
      <path d="M202 176 h16 l-8 8 z" fill="#000" />
      <rect x="208" y="162" width="2" height="16" fill="#808080" />
      <path d="M204 176 h10 l-5 5 z" fill="#808080" />

      <%!-- ── Step 3: New Window Opens ── --%>
      <%!-- Back window (lobby, dimmed) --%>
      <rect x="84" y="192" width="200" height="40" fill="#c0c0c0" stroke="#808080" stroke-width="1" />
      <rect x="87" y="195" width="194" height="14" fill="#808080" />
      <text
        x="184"
        y="205"
        text-anchor="middle"
        fill="#c0c0c0"
        font-size="8"
        font-family="Tahoma,sans-serif"
      >
        Arcade — Select a Game
      </text>

      <%!-- Front window (game, opening) --%>
      <%!-- Shadow --%>
      <rect x="144" y="198" width="220" height="44" fill="#000" />
      <%!-- Window --%>
      <rect x="140" y="194" width="220" height="44" fill="#c0c0c0" stroke="#000" stroke-width="1" />
      <polyline points="141,237 141,195 359,195" fill="none" stroke="#fff" stroke-width="1" />
      <polyline points="359,196 359,237 141,237" fill="none" stroke="#808080" stroke-width="1" />
      <%!-- Title bar --%>
      <rect x="143" y="197" width="214" height="16" fill="#000080" />
      <rect x="145" y="199" width="14" height="12" fill="#000080" stroke="#000" stroke-width="1" />
      <text
        x="152"
        y="208"
        text-anchor="middle"
        fill="#fff"
        font-size="10"
        font-family="'Courier New',monospace"
        font-weight="bold"
      >
        3
      </text>
      <text
        x="270"
        y="209"
        text-anchor="middle"
        fill="#fff"
        font-size="9"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        New Window Opens
      </text>
      <%!-- Content --%>
      <rect x="148" y="218" width="204" height="14" fill="#dfdfdf" stroke="#000" stroke-width="1" />
      <polyline points="149,231 149,219 351,219" fill="none" stroke="#808080" stroke-width="1" />
      <polyline points="351,220 351,231 149,231" fill="none" stroke="#fff" stroke-width="1" />
      <text
        x="250"
        y="229"
        text-anchor="middle"
        fill="#000"
        font-size="8"
        font-family="Tahoma,sans-serif"
      >
        Loading DOOM: Knee-Deep in the Dead...
      </text>

      <%!-- Arrow 3 → 4 (green accent) --%>
      <rect x="208" y="242" width="4" height="18" fill="#000" />
      <path d="M202 256 h16 l-8 8 z" fill="#000" />
      <rect x="208" y="242" width="2" height="16" fill="#00ff00" />
      <path d="M204 256 h10 l-5 5 z" fill="#00ff00" />

      <%!-- ── Step 4: WASM Game Running ── --%>
      <%!-- Shadow --%>
      <rect x="64" y="270" width="300" height="80" fill="#000" />
      <%!-- Window --%>
      <rect x="60" y="266" width="300" height="80" fill="#c0c0c0" stroke="#000" stroke-width="1" />
      <%!-- Green accent border --%>
      <rect x="61" y="267" width="298" height="78" fill="none" stroke="#00ff00" stroke-width="1" />
      <polyline points="61,345 61,267 359,267" fill="none" stroke="#fff" stroke-width="1" />
      <polyline points="359,268 359,345 61,345" fill="none" stroke="#808080" stroke-width="1" />
      <%!-- Title bar --%>
      <rect x="63" y="269" width="294" height="16" fill="#000080" />
      <%!-- Number block (green) --%>
      <rect x="65" y="271" width="14" height="12" fill="#008000" stroke="#000" stroke-width="1" />
      <polyline points="66,282 66,272 78,272" fill="none" stroke="#005500" stroke-width="1" />
      <polyline points="78,273 78,282 66,282" fill="none" stroke="#00ff00" stroke-width="1" />
      <text
        x="72"
        y="280"
        text-anchor="middle"
        fill="#fff"
        font-size="10"
        font-family="'Courier New',monospace"
        font-weight="bold"
      >
        4
      </text>
      <text
        x="210"
        y="281"
        text-anchor="middle"
        fill="#fff"
        font-size="9"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        DOOM: Knee-Deep in the Dead
      </text>
      <%!-- Black game canvas --%>
      <rect x="68" y="290" width="284" height="46" fill="#000" stroke="#808080" stroke-width="1" />
      <polyline points="69,335 69,291 351,291" fill="none" stroke="#555" stroke-width="1" />
      <polyline points="351,292 351,335 69,335" fill="none" stroke="#333" stroke-width="1" />
      <%!-- WASM text --%>
      <text
        x="210"
        y="314"
        text-anchor="middle"
        fill="#00ff00"
        font-size="14"
        font-family="'Courier New',monospace"
        font-weight="bold"
      >
        WebAssembly
      </text>
      <text
        x="210"
        y="328"
        text-anchor="middle"
        fill="#808080"
        font-size="8"
        font-family="Tahoma,sans-serif"
      >
        Engine: Dwasm · Running in browser
      </text>

      <%!-- Tooltip --%>
      <rect x="85" y="356" width="250" height="16" fill="#ffffcc" stroke="#000" stroke-width="1" />
      <polyline points="85,371 85,357 334,357" fill="none" stroke="#fff" stroke-width="1" />
      <polyline points="334,358 334,371 86,371" fill="none" stroke="#808080" stroke-width="1" />
      <text
        x="210"
        y="368"
        text-anchor="middle"
        fill="#000"
        font-size="9"
        font-family="Tahoma,sans-serif"
      >
        18 classic games · Runs in your browser via WebAssembly
      </text>
    </svg>
    """
  end
end
