defmodule RetroHexChatWeb.Components.Diagrams.GameP2pFlow do
  @moduledoc "SVG diagram for P2P multiplayer games flow."
  use Phoenix.Component
  use Gettext, backend: RetroHexChatWeb.Gettext

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
      aria-label={
        dgettext(
          "diagrams",
          "P2P multiplayer games flow: type /game command, join lobby, select game, play via WebRTC DataChannel between two players"
        )
      }
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
        {dgettext("diagrams", "Chat")}
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
        {dgettext("diagrams", "/game bob")}
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
        {dgettext("diagrams", "Send")}
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
        {dgettext("diagrams", "P2P Lobby")}
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
        {dgettext("diagrams", "Alice (you)")}
      </text>
      <circle cx="212" cy="57" r="3" fill="#00ff00" stroke="#000" stroke-width="1" />
      <text
        x="218"
        y="60"
        fill="#000"
        font-size="8"
        font-family="Tahoma,sans-serif"
      >
        {dgettext("diagrams", "Bob (joined)")}
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
        {dgettext("diagrams", "Choose Game")}
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
        {dgettext("diagrams", "Hex Pong")}
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
        {dgettext("diagrams", "Star Duel")}
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
        {dgettext("diagrams", "Pixel Tanks")}
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
        {dgettext("diagrams", "Light Trails")}
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
        {dgettext("diagrams", "Hex Pong — Alice vs Bob")}
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
        {dgettext("diagrams", "Alice")}
      </text>
      <text x="130" y="264" text-anchor="middle" fill="#000" font-size="18">
        {dgettext("diagrams", "&#x1F468;")}
      </text>

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
        {dgettext("diagrams", "Bob")}
      </text>
      <text x="390" y="264" text-anchor="middle" fill="#000" font-size="18">
        {dgettext("diagrams", "&#x1F469;")}
      </text>

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
        {dgettext("diagrams", "WebRTC DataChannel")}
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
        {dgettext("diagrams", "28 games · Real-time sync · No server")}
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
end
