defmodule RetroHexChatWeb.Components.Diagrams.Games do
  @moduledoc """
  Game-related SVG diagrams: P2P multiplayer flow and solo arcade flow.
  """
  use Phoenix.Component

  # ──────────────────────────────────────────────────
  # P2P Multiplayer Games Flow (landing page)
  # ──────────────────────────────────────────────────

  attr :class, :string, default: nil

  @spec diagram_p2p_games(map()) :: Phoenix.LiveView.Rendered.t()
  def diagram_p2p_games(assigns) do
    ~H"""
    <svg
      class={@class}
      viewBox="0 0 520 360"
      shape-rendering="crispEdges"
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-label="P2P multiplayer games flow: type /game command, join lobby, select game, play via WebRTC DataChannel between two players"
    >
      <%!-- ── Step 1: /game bob command ── --%>
      <%!-- Shadow --%>
      <rect x="14" y="14" width="160" height="60" fill="#000" />
      <%!-- Window --%>
      <rect x="10" y="10" width="160" height="60" fill="#c0c0c0" stroke="#000" stroke-width="1" />
      <polyline points="11,69 11,11 169,11" fill="none" stroke="#fff" stroke-width="1" />
      <polyline points="169,12 169,69 11,69" fill="none" stroke="#808080" stroke-width="1" />
      <%!-- Title bar --%>
      <rect x="13" y="13" width="154" height="16" fill="#000080" />
      <%!-- Number block --%>
      <rect x="15" y="15" width="14" height="12" fill="#000080" stroke="#000" stroke-width="1" />
      <text
        x="22"
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
        x="98"
        y="25"
        text-anchor="middle"
        fill="#fff"
        font-size="9"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        Chat
      </text>
      <%!-- Content: input field with /game bob --%>
      <rect x="16" y="34" width="148" height="30" fill="#dfdfdf" stroke="#000" stroke-width="1" />
      <polyline points="17,63 17,35 163,35" fill="none" stroke="#808080" stroke-width="1" />
      <polyline points="163,36 163,63 17,63" fill="none" stroke="#fff" stroke-width="1" />
      <%!-- Input sunken field --%>
      <rect x="20" y="40" width="106" height="16" fill="#fff" stroke="#808080" stroke-width="1" />
      <text
        x="24"
        y="52"
        fill="#000"
        font-size="9"
        font-family="'Courier New',monospace"
      >
        /game bob
      </text>
      <%!-- Send button --%>
      <rect x="130" y="40" width="30" height="16" fill="#c0c0c0" stroke="#000" stroke-width="1" />
      <polyline points="131,55 131,41 159,41" fill="none" stroke="#fff" stroke-width="1" />
      <polyline points="159,42 159,55 131,55" fill="none" stroke="#808080" stroke-width="1" />
      <text
        x="145"
        y="52"
        text-anchor="middle"
        fill="#000"
        font-size="8"
        font-family="Tahoma,sans-serif"
      >
        Send
      </text>

      <%!-- Arrow 1 → 2 --%>
      <rect x="172" y="36" width="18" height="4" fill="#000" />
      <path d="M186 30 l8 8 l-8 8 z" fill="#000" />
      <rect x="172" y="36" width="16" height="2" fill="#808080" />

      <%!-- ── Step 2: P2P Lobby ── --%>
      <%!-- Shadow --%>
      <rect x="200" y="14" width="120" height="60" fill="#000" />
      <%!-- Window --%>
      <rect x="196" y="10" width="120" height="60" fill="#c0c0c0" stroke="#000" stroke-width="1" />
      <polyline points="197,69 197,11 315,11" fill="none" stroke="#fff" stroke-width="1" />
      <polyline points="315,12 315,69 197,69" fill="none" stroke="#808080" stroke-width="1" />
      <%!-- Title bar --%>
      <rect x="199" y="13" width="114" height="16" fill="#000080" />
      <rect x="201" y="15" width="14" height="12" fill="#000080" stroke="#000" stroke-width="1" />
      <text
        x="208"
        y="24"
        text-anchor="middle"
        fill="#fff"
        font-size="10"
        font-family="'Courier New',monospace"
        font-weight="bold"
      >
        2
      </text>
      <text
        x="274"
        y="25"
        text-anchor="middle"
        fill="#fff"
        font-size="9"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        P2P Lobby
      </text>
      <%!-- Content --%>
      <rect x="202" y="34" width="108" height="30" fill="#dfdfdf" stroke="#000" stroke-width="1" />
      <polyline points="203,63 203,35 309,35" fill="none" stroke="#808080" stroke-width="1" />
      <polyline points="309,36 309,63 203,63" fill="none" stroke="#fff" stroke-width="1" />
      <%!-- Green dot + text --%>
      <circle cx="212" cy="45" r="3" fill="#00ff00" stroke="#000" stroke-width="1" />
      <text
        x="218"
        y="48"
        fill="#000"
        font-size="8"
        font-family="Tahoma,sans-serif"
      >
        Alice (you)
      </text>
      <circle cx="212" cy="57" r="3" fill="#00ff00" stroke="#000" stroke-width="1" />
      <text
        x="218"
        y="60"
        fill="#000"
        font-size="8"
        font-family="Tahoma,sans-serif"
      >
        Bob (joined)
      </text>

      <%!-- Arrow 2 → 3 --%>
      <rect x="318" y="36" width="18" height="4" fill="#000" />
      <path d="M332 30 l8 8 l-8 8 z" fill="#000" />
      <rect x="318" y="36" width="16" height="2" fill="#808080" />

      <%!-- ── Step 3: Game Selection ── --%>
      <%!-- Shadow --%>
      <rect x="346" y="14" width="160" height="60" fill="#000" />
      <%!-- Window --%>
      <rect x="342" y="10" width="160" height="60" fill="#c0c0c0" stroke="#000" stroke-width="1" />
      <polyline points="343,69 343,11 501,11" fill="none" stroke="#fff" stroke-width="1" />
      <polyline points="501,12 501,69 343,69" fill="none" stroke="#808080" stroke-width="1" />
      <%!-- Title bar --%>
      <rect x="345" y="13" width="154" height="16" fill="#000080" />
      <rect x="347" y="15" width="14" height="12" fill="#000080" stroke="#000" stroke-width="1" />
      <text
        x="354"
        y="24"
        text-anchor="middle"
        fill="#fff"
        font-size="10"
        font-family="'Courier New',monospace"
        font-weight="bold"
      >
        3
      </text>
      <text
        x="432"
        y="25"
        text-anchor="middle"
        fill="#fff"
        font-size="9"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        Choose Game
      </text>
      <%!-- Content: 2x2 game grid --%>
      <rect x="348" y="34" width="148" height="30" fill="#dfdfdf" stroke="#000" stroke-width="1" />
      <polyline points="349,63 349,35 495,35" fill="none" stroke="#808080" stroke-width="1" />
      <polyline points="495,36 495,63 349,63" fill="none" stroke="#fff" stroke-width="1" />
      <%!-- Game tiles --%>
      <rect x="352" y="37" width="66" height="11" fill="#fff" stroke="#808080" stroke-width="1" />
      <%!-- Selected highlight --%>
      <rect x="352" y="37" width="66" height="11" fill="#000080" stroke="#000080" stroke-width="1" />
      <text
        x="385"
        y="46"
        text-anchor="middle"
        fill="#fff"
        font-size="7"
        font-family="Tahoma,sans-serif"
      >
        Hex Pong
      </text>
      <rect x="422" y="37" width="66" height="11" fill="#fff" stroke="#808080" stroke-width="1" />
      <text
        x="455"
        y="46"
        text-anchor="middle"
        fill="#000"
        font-size="7"
        font-family="Tahoma,sans-serif"
      >
        Star Duel
      </text>
      <rect x="352" y="51" width="66" height="11" fill="#fff" stroke="#808080" stroke-width="1" />
      <text
        x="385"
        y="60"
        text-anchor="middle"
        fill="#000"
        font-size="7"
        font-family="Tahoma,sans-serif"
      >
        Pixel Tanks
      </text>
      <rect x="422" y="51" width="66" height="11" fill="#fff" stroke="#808080" stroke-width="1" />
      <text
        x="455"
        y="60"
        text-anchor="middle"
        fill="#000"
        font-size="7"
        font-family="Tahoma,sans-serif"
      >
        Light Trails
      </text>

      <%!-- Arrow 3 → 4 (down, green accent) --%>
      <rect x="420" y="72" width="4" height="20" fill="#000" />
      <path d="M414 88 h12 l-6 8 z" fill="#000" />
      <rect x="420" y="72" width="2" height="18" fill="#00ff00" />
      <path d="M416 88 h8 l-4 5 z" fill="#00ff00" />

      <%!-- ── Step 4: Game Running ── --%>
      <%!-- Shadow --%>
      <rect x="184" y="104" width="320" height="120" fill="#000" />
      <%!-- Window --%>
      <rect x="180" y="100" width="320" height="120" fill="#c0c0c0" stroke="#000" stroke-width="1" />
      <%!-- Green accent border --%>
      <rect x="181" y="101" width="318" height="118" fill="none" stroke="#00ff00" stroke-width="1" />
      <polyline points="181,219 181,101 499,101" fill="none" stroke="#fff" stroke-width="1" />
      <polyline points="499,102 499,219 181,219" fill="none" stroke="#808080" stroke-width="1" />
      <%!-- Title bar --%>
      <rect x="183" y="103" width="314" height="18" fill="#000080" />
      <%!-- Number block (green for success) --%>
      <rect x="185" y="105" width="16" height="14" fill="#008000" stroke="#000" stroke-width="1" />
      <polyline points="186,118 186,106 200,106" fill="none" stroke="#005500" stroke-width="1" />
      <polyline points="200,107 200,118 186,118" fill="none" stroke="#00ff00" stroke-width="1" />
      <text
        x="193"
        y="116"
        text-anchor="middle"
        fill="#fff"
        font-size="10"
        font-family="'Courier New',monospace"
        font-weight="bold"
      >
        4
      </text>
      <text
        x="340"
        y="116"
        text-anchor="middle"
        fill="#fff"
        font-size="10"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        Hex Pong — Alice vs Bob
      </text>
      <%!-- Game canvas area (black) --%>
      <rect x="190" y="126" width="300" height="84" fill="#000" stroke="#808080" stroke-width="1" />
      <polyline points="191,209 191,127 489,127" fill="none" stroke="#555" stroke-width="1" />
      <polyline points="489,128 489,209 191,209" fill="none" stroke="#333" stroke-width="1" />
      <%!-- Score display --%>
      <text
        x="340"
        y="142"
        text-anchor="middle"
        fill="#00ff00"
        font-size="12"
        font-family="'Courier New',monospace"
        font-weight="bold"
      >
        3 : 2
      </text>
      <%!-- Center dashed line --%>
      <line x1="340" y1="146" x2="340" y2="206" stroke="#333" stroke-width="1" stroke-dasharray="4,4" />
      <%!-- Left paddle --%>
      <rect x="204" y="160" width="6" height="30" fill="#00ff00" />
      <%!-- Right paddle --%>
      <rect x="470" y="170" width="6" height="30" fill="#00ff00" />
      <%!-- Ball --%>
      <rect x="336" y="172" width="6" height="6" fill="#fff" />

      <%!-- ── Bottom: Alice & Bob with DataChannel ── --%>
      <%!-- Alice node --%>
      <rect x="94" y="244" width="80" height="30" fill="#000" />
      <rect x="90" y="240" width="80" height="30" fill="#dfdfdf" stroke="#000" stroke-width="1" />
      <polyline points="91,269 91,241 169,241" fill="none" stroke="#fff" stroke-width="1" />
      <polyline points="169,242 169,269 91,269" fill="none" stroke="#808080" stroke-width="1" />
      <rect x="93" y="243" width="74" height="12" fill="#000080" />
      <text
        x="130"
        y="252"
        text-anchor="middle"
        fill="#fff"
        font-size="9"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        Alice
      </text>
      <text x="130" y="264" text-anchor="middle" fill="#000" font-size="18">&#x1F468;</text>

      <%!-- Bob node --%>
      <rect x="354" y="244" width="80" height="30" fill="#000" />
      <rect x="350" y="240" width="80" height="30" fill="#dfdfdf" stroke="#000" stroke-width="1" />
      <polyline points="351,269 351,241 429,241" fill="none" stroke="#fff" stroke-width="1" />
      <polyline points="429,242 429,269 351,269" fill="none" stroke="#808080" stroke-width="1" />
      <rect x="353" y="243" width="74" height="12" fill="#000080" />
      <text
        x="390"
        y="252"
        text-anchor="middle"
        fill="#fff"
        font-size="9"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        Bob
      </text>
      <text x="390" y="264" text-anchor="middle" fill="#000" font-size="18">&#x1F469;</text>

      <%!-- Bidirectional green arrow --%>
      <rect x="170" y="252" width="180" height="6" fill="#000" />
      <rect x="176" y="252" width="168" height="4" fill="#00ff00" />
      <%!-- Left arrowhead --%>
      <path d="M176 248 l-8 6 l8 6 z" fill="#000" />
      <path d="M176 250 l-6 4 l6 4 z" fill="#00ff00" />
      <%!-- Right arrowhead --%>
      <path d="M344 248 l8 6 l-8 6 z" fill="#000" />
      <path d="M344 250 l6 4 l-6 4 z" fill="#00ff00" />

      <%!-- DataChannel label --%>
      <rect x="200" y="238" width="120" height="14" fill="#dfdfdf" stroke="#000" stroke-width="1" />
      <polyline points="201,251 201,239 319,239" fill="none" stroke="#fff" stroke-width="1" />
      <polyline points="319,240 319,251 201,251" fill="none" stroke="#808080" stroke-width="1" />
      <text
        x="260"
        y="249"
        text-anchor="middle"
        fill="#000080"
        font-size="8"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        WebRTC DataChannel
      </text>

      <%!-- Tooltip --%>
      <rect x="150" y="285" width="220" height="16" fill="#ffffcc" stroke="#000" stroke-width="1" />
      <polyline points="150,300 150,286 369,286" fill="none" stroke="#fff" stroke-width="1" />
      <polyline points="369,287 369,300 151,300" fill="none" stroke="#808080" stroke-width="1" />
      <text
        x="260"
        y="297"
        text-anchor="middle"
        fill="#000"
        font-size="9"
        font-family="Tahoma,sans-serif"
      >
        28 games · Real-time sync · No server
      </text>

      <%!-- Dashed lines from nodes to game window --%>
      <line
        x1="130"
        y1="240"
        x2="130"
        y2="226"
        stroke="#808080"
        stroke-width="1"
        stroke-dasharray="4,3"
      />
      <line
        x1="130"
        y1="226"
        x2="180"
        y2="226"
        stroke="#808080"
        stroke-width="1"
        stroke-dasharray="4,3"
      />
      <line
        x1="390"
        y1="240"
        x2="390"
        y2="226"
        stroke="#808080"
        stroke-width="1"
        stroke-dasharray="4,3"
      />
      <line
        x1="390"
        y1="226"
        x2="500"
        y2="226"
        stroke="#808080"
        stroke-width="1"
        stroke-dasharray="4,3"
      />
    </svg>
    """
  end

  # ──────────────────────────────────────────────────
  # Solo Arcade Flow Diagram (landing page)
  # ──────────────────────────────────────────────────

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
      aria-label="Solo arcade flow: type /singleplayer command, pick a game from catalog, new window opens, WASM game runs in browser"
    >
      <%!-- ── Step 1: /singleplayer command ── --%>
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
        Chat
      </text>
      <%!-- Input field with /singleplayer --%>
      <rect x="70" y="34" width="178" height="14" fill="#fff" stroke="#808080" stroke-width="1" />
      <text
        x="74"
        y="45"
        fill="#000"
        font-size="9"
        font-family="'Courier New',monospace"
      >
        /singleplayer
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
