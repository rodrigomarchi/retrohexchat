defmodule RetroHexChatWeb.Components.Diagrams.GameScreens do
  @moduledoc """
  SVG game screen diagrams for help topics.

  Each function renders a Win98-style window frame containing a simplified
  depiction of a game screen. Used in the help system to illustrate game
  mechanics visually.

  ## Naming Convention

  `diagram_game_<name>` where `<name>` matches the game family:
  pong, trails, tanks, space, breakout, warlords, raid, boxing,
  outlaw, hockey, tennis, enduro, invaders, frost, skiing.
  """
  use Phoenix.Component

  # ── Shared SVG helpers (private) ─────────────────────

  # Win98 window chrome: shadow, frame, bevels, title bar
  # x/y = top-left of shadow (window is at x-4, y-4)
  # w/h = window dimensions
  defp win98_chrome(title, step \\ nil) do
    assigns = %{title: title, step: step}

    ~H"""
    <%!-- Shadow --%>
    <rect x="4" y="4" width="512" height="352" fill="#000" />
    <%!-- Frame --%>
    <rect x="0" y="0" width="512" height="352" fill="#c0c0c0" stroke="#000" stroke-width="1" />
    <%!-- Outer bevels --%>
    <polyline points="1,351 1,1 511,1" fill="none" stroke="#fff" stroke-width="1" />
    <polyline points="511,2 511,351 1,351" fill="none" stroke="#808080" stroke-width="1" />
    <%!-- Title bar --%>
    <rect x="3" y="3" width="506" height="16" fill="#000080" />
    <%= if @step do %>
      <rect x="5" y="5" width="14" height="12" fill="#000080" stroke="#000" stroke-width="1" />
      <text
        x="12"
        y="14"
        text-anchor="middle"
        fill="#fff"
        font-size="10"
        font-family="'Courier New',monospace"
        font-weight="bold"
      >
        {@step}
      </text>
    <% end %>
    <text
      x="256"
      y="15"
      text-anchor="middle"
      fill="#fff"
      font-size="9"
      font-family="Tahoma,sans-serif"
      font-weight="bold"
    >
      {@title}
    </text>
    <%!-- Canvas area (inner) --%>
    <rect x="6" y="22" width="500" height="326" fill="#000" stroke="#808080" stroke-width="1" />
    <polyline points="7,347 7,23 505,23" fill="none" stroke="#404040" stroke-width="1" />
    """
  end

  # ────────────────────────────────────────────────────────
  # 1. Pong
  # ────────────────────────────────────────────────────────

  attr :class, :string, default: nil

  @spec diagram_game_pong(map()) :: Phoenix.LiveView.Rendered.t()
  def diagram_game_pong(assigns) do
    ~H"""
    <svg
      class={@class}
      viewBox="0 0 520 360"
      shape-rendering="crispEdges"
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-label="Hex Pong game screen: two paddles and a ball on a dark field with dashed center line"
    >
      {win98_chrome("Hex Pong")}
      <%!-- Center dashed line --%>
      <%= for y <- 0..15 do %>
        <rect x="254" y={26 + y * 20} width="4" height="10" fill="#00ff00" opacity="0.3" />
      <% end %>
      <%!-- Scores --%>
      <text
        x="200"
        y="52"
        text-anchor="middle"
        fill="#00ff00"
        font-size="28"
        font-family="'Courier New',monospace"
        font-weight="bold"
      >
        3
      </text>
      <text
        x="312"
        y="52"
        text-anchor="middle"
        fill="#00ff00"
        font-size="28"
        font-family="'Courier New',monospace"
        font-weight="bold"
      >
        7
      </text>
      <%!-- Left paddle (P1) --%>
      <rect x="36" y="140" width="8" height="60" fill="#00ff00" />
      <%!-- Right paddle (P2) --%>
      <rect x="468" y="200" width="8" height="60" fill="#00ff00" />
      <%!-- Ball --%>
      <rect x="280" y="180" width="8" height="8" fill="#fff" />
      <%!-- Ball trail --%>
      <rect x="272" y="184" width="6" height="6" fill="#00ff00" opacity="0.3" />
      <rect x="264" y="188" width="4" height="4" fill="#00ff00" opacity="0.15" />
      <%!-- CRT scanlines hint --%>
      <%= for y <- 0..7 do %>
        <rect x="6" y={24 + y * 40} width="500" height="1" fill="#000" opacity="0.08" />
      <% end %>
    </svg>
    """
  end

  # ────────────────────────────────────────────────────────
  # 2. Light Trails
  # ────────────────────────────────────────────────────────

  attr :class, :string, default: nil

  @spec diagram_game_trails(map()) :: Phoenix.LiveView.Rendered.t()
  def diagram_game_trails(assigns) do
    ~H"""
    <svg
      class={@class}
      viewBox="0 0 520 360"
      shape-rendering="crispEdges"
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-label="Light Trails game screen: two glowing trails on a dark grid, green and cyan"
    >
      {win98_chrome("Light Trails")}
      <%!-- Subtle grid --%>
      <%= for x <- 0..24 do %>
        <line
          x1={8 + x * 20}
          y1="24"
          x2={8 + x * 20}
          y2="346"
          stroke="#0a1628"
          stroke-width="1"
          opacity="0.3"
        />
      <% end %>
      <%= for y <- 0..15 do %>
        <line
          x1="8"
          y1={24 + y * 20}
          x2="504"
          y2={24 + y * 20}
          stroke="#0a1628"
          stroke-width="1"
          opacity="0.3"
        />
      <% end %>
      <%!-- P1 trail (green) --%>
      <rect x="48" y="164" width="8" height="8" fill="#00ff41" />
      <rect x="48" y="172" width="8" height="8" fill="#00ff41" opacity="0.9" />
      <rect x="48" y="180" width="8" height="8" fill="#00ff41" opacity="0.8" />
      <rect x="48" y="188" width="8" height="8" fill="#00ff41" opacity="0.7" />
      <rect x="56" y="188" width="8" height="8" fill="#00ff41" opacity="0.6" />
      <rect x="64" y="188" width="8" height="8" fill="#00ff41" opacity="0.5" />
      <rect x="72" y="188" width="8" height="8" fill="#00ff41" opacity="0.5" />
      <rect x="80" y="188" width="8" height="8" fill="#00ff41" opacity="0.5" />
      <rect x="88" y="188" width="8" height="8" fill="#00ff41" opacity="0.5" />
      <rect x="96" y="188" width="8" height="8" fill="#00ff41" opacity="0.5" />
      <rect x="104" y="188" width="8" height="8" fill="#00ff41" opacity="0.5" />
      <rect x="112" y="188" width="8" height="8" fill="#00ff41" opacity="0.5" />
      <rect x="120" y="188" width="8" height="8" fill="#00ff41" opacity="0.5" />
      <rect x="128" y="188" width="8" height="8" fill="#00ff41" opacity="0.5" />
      <rect x="136" y="188" width="8" height="8" fill="#00ff41" opacity="0.5" />
      <%!-- P1 head --%>
      <rect x="48" y="156" width="8" height="8" fill="#fff" />
      <%!-- P2 trail (cyan) --%>
      <rect x="440" y="164" width="8" height="8" fill="#00d4ff" />
      <rect x="440" y="172" width="8" height="8" fill="#00d4ff" opacity="0.9" />
      <rect x="440" y="180" width="8" height="8" fill="#00d4ff" opacity="0.8" />
      <rect x="432" y="180" width="8" height="8" fill="#00d4ff" opacity="0.7" />
      <rect x="424" y="180" width="8" height="8" fill="#00d4ff" opacity="0.6" />
      <rect x="416" y="180" width="8" height="8" fill="#00d4ff" opacity="0.5" />
      <rect x="408" y="180" width="8" height="8" fill="#00d4ff" opacity="0.5" />
      <rect x="400" y="180" width="8" height="8" fill="#00d4ff" opacity="0.5" />
      <rect x="392" y="180" width="8" height="8" fill="#00d4ff" opacity="0.5" />
      <rect x="384" y="180" width="8" height="8" fill="#00d4ff" opacity="0.5" />
      <%!-- P2 head --%>
      <rect x="440" y="156" width="8" height="8" fill="#fff" />
      <%!-- Scores --%>
      <text x="30" y="44" fill="#00ff41" font-size="14" font-family="'Courier New',monospace">
        P1: 2
      </text>
      <text x="440" y="44" fill="#00d4ff" font-size="14" font-family="'Courier New',monospace">
        P2: 1
      </text>
      <text x="230" y="44" fill="#ffaa00" font-size="12" font-family="'Courier New',monospace">
        ROUND 4
      </text>
    </svg>
    """
  end

  # ────────────────────────────────────────────────────────
  # 3. Pixel Tanks
  # ────────────────────────────────────────────────────────

  attr :class, :string, default: nil

  @spec diagram_game_tanks(map()) :: Phoenix.LiveView.Rendered.t()
  def diagram_game_tanks(assigns) do
    ~H"""
    <svg
      class={@class}
      viewBox="0 0 520 360"
      shape-rendering="crispEdges"
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-label="Pixel Tanks game screen: two tanks in a maze arena"
    >
      {win98_chrome("Pixel Tanks")}
      <%!-- Maze walls --%>
      <rect x="120" y="100" width="16" height="80" fill="#555" />
      <rect x="200" y="180" width="112" height="16" fill="#555" />
      <rect x="380" y="100" width="16" height="80" fill="#555" />
      <rect x="200" y="260" width="16" height="60" fill="#555" />
      <rect x="296" y="260" width="16" height="60" fill="#555" />
      <rect x="240" y="80" width="32" height="16" fill="#555" />
      <%!-- P1 tank (green) --%>
      <rect x="56" y="176" width="16" height="16" fill="#00ff41" />
      <rect x="72" y="180" width="8" height="8" fill="#00ff41" />
      <%!-- P2 tank (cyan) --%>
      <rect x="440" y="176" width="16" height="16" fill="#00d4ff" />
      <rect x="432" y="180" width="8" height="8" fill="#00d4ff" />
      <%!-- Missile (from P1) --%>
      <rect x="120" y="182" width="4" height="4" fill="#ff0" />
      <%!-- Scores --%>
      <text x="30" y="44" fill="#00ff41" font-size="12" font-family="'Courier New',monospace">
        P1: 3
      </text>
      <text x="440" y="44" fill="#00d4ff" font-size="12" font-family="'Courier New',monospace">
        P2: 1
      </text>
      <text x="210" y="44" fill="#ffaa00" font-size="12" font-family="'Courier New',monospace">
        ROUND 2  1:24
      </text>
    </svg>
    """
  end

  # ────────────────────────────────────────────────────────
  # 4. Star Duel
  # ────────────────────────────────────────────────────────

  attr :class, :string, default: nil

  @spec diagram_game_space(map()) :: Phoenix.LiveView.Rendered.t()
  def diagram_game_space(assigns) do
    ~H"""
    <svg
      class={@class}
      viewBox="0 0 520 360"
      shape-rendering="crispEdges"
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-label="Star Duel game screen: two ships in open space with missiles"
    >
      {win98_chrome("Star Duel")}
      <%!-- Stars background --%>
      <rect x="50" y="60" width="2" height="2" fill="#fff" opacity="0.5" />
      <rect x="150" y="120" width="2" height="2" fill="#fff" opacity="0.4" />
      <rect x="300" y="80" width="2" height="2" fill="#fff" opacity="0.6" />
      <rect x="420" y="140" width="2" height="2" fill="#fff" opacity="0.3" />
      <rect x="380" y="280" width="2" height="2" fill="#fff" opacity="0.5" />
      <rect x="100" y="300" width="2" height="2" fill="#fff" opacity="0.4" />
      <rect x="460" y="60" width="2" height="2" fill="#fff" opacity="0.5" />
      <rect x="200" y="240" width="2" height="2" fill="#fff" opacity="0.3" />
      <%!-- P1 ship (green triangle pointing right) --%>
      <polygon points="120,180 100,170 100,190" fill="#00ff41" />
      <%!-- P1 thrust flame --%>
      <polygon points="98,178 90,180 98,182" fill="#ff6600" opacity="0.7" />
      <%!-- P2 ship (cyan triangle pointing left) --%>
      <polygon points="380,200 400,190 400,210" fill="#00d4ff" />
      <%!-- Missiles --%>
      <rect x="132" y="178" width="4" height="4" fill="#ff0" />
      <rect x="156" y="176" width="4" height="4" fill="#ff0" />
      <%!-- Scores --%>
      <text x="30" y="44" fill="#00ff41" font-size="14" font-family="'Courier New',monospace">4</text>
      <text x="480" y="44" fill="#00d4ff" font-size="14" font-family="'Courier New',monospace">
        2
      </text>
    </svg>
    """
  end

  # ────────────────────────────────────────────────────────
  # 5. Block Breakers
  # ────────────────────────────────────────────────────────

  attr :class, :string, default: nil

  @spec diagram_game_breakout(map()) :: Phoenix.LiveView.Rendered.t()
  def diagram_game_breakout(assigns) do
    ~H"""
    <svg
      class={@class}
      viewBox="0 0 520 360"
      shape-rendering="crispEdges"
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-label="Block Breakers game screen: two paddles with colored block rows between them"
    >
      {win98_chrome("Block Breakers")}
      <%!-- Block rows --%>
      <%= for col <- 0..9 do %>
        <rect x={20 + col * 48} y="120" width="44" height="12" fill="#ff0066" />
        <rect x={20 + col * 48} y="136" width="44" height="12" fill="#ff6600" />
        <rect x={20 + col * 48} y="152" width="44" height="12" fill="#ffcc00" />
        <rect x={20 + col * 48} y="168" width="44" height="12" fill="#00ff66" />
        <rect x={20 + col * 48} y="184" width="44" height="12" fill="#00ccff" />
      <% end %>
      <%!-- Some blocks destroyed --%>
      <rect x="116" y="184" width="44" height="12" fill="#000" />
      <rect x="212" y="184" width="44" height="12" fill="#000" />
      <rect x="212" y="168" width="44" height="12" fill="#000" />
      <%!-- P2 paddle (top) --%>
      <rect x="220" y="40" width="60" height="8" fill="#00d4ff" />
      <%!-- P1 paddle (bottom) --%>
      <rect x="180" y="330" width="60" height="8" fill="#00ff41" />
      <%!-- Ball --%>
      <rect x="250" y="220" width="6" height="6" fill="#fff" />
      <%!-- Score + Lives --%>
      <text x="30" y="340" fill="#00ff41" font-size="10" font-family="'Courier New',monospace">
        Score: 340
      </text>
      <text x="420" y="340" fill="#ffaa00" font-size="10" font-family="'Courier New',monospace">
        Lives: 2
      </text>
    </svg>
    """
  end

  # ────────────────────────────────────────────────────────
  # 6. Hex Warlords
  # ────────────────────────────────────────────────────────

  attr :class, :string, default: nil

  @spec diagram_game_warlords(map()) :: Phoenix.LiveView.Rendered.t()
  def diagram_game_warlords(assigns) do
    ~H"""
    <svg
      class={@class}
      viewBox="0 0 520 360"
      shape-rendering="crispEdges"
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-label="Hex Warlords game screen: two castles with brick walls and a fireball bouncing between them"
    >
      {win98_chrome("Hex Warlords")}
      <%!-- P1 castle bricks (left, 4 cols x 6 rows) --%>
      <%= for row <- 0..5, col <- 0..3 do %>
        <rect
          x={30 + col * 18}
          y={100 + row * 14}
          width="16"
          height="12"
          fill={
            case col do
              3 -> "#00ff66"
              2 -> "#00ccff"
              1 -> "#ffcc00"
              0 -> "#ff3366"
            end
          }
        />
      <% end %>
      <%!-- P1 king --%>
      <rect x="18" y="134" width="10" height="10" fill="#ffcc00" />
      <%!-- P1 shield --%>
      <rect x="104" y="120" width="8" height="48" fill="#00ff41" />
      <%!-- P2 castle bricks (right, 4 cols x 6 rows, some destroyed) --%>
      <%= for row <- 0..5, col <- 0..3 do %>
        <%= if not (row in [2, 3] and col == 0) do %>
          <rect
            x={398 + col * 18}
            y={100 + row * 14}
            width="16"
            height="12"
            fill={
              case col do
                0 -> "#00ff66"
                1 -> "#00ccff"
                2 -> "#ffcc00"
                3 -> "#ff3366"
              end
            }
          />
        <% end %>
      <% end %>
      <%!-- P2 king --%>
      <rect x="484" y="134" width="10" height="10" fill="#ffcc00" />
      <%!-- P2 shield --%>
      <rect x="388" y="140" width="8" height="48" fill="#00d4ff" />
      <%!-- Fireball --%>
      <rect x="250" y="150" width="6" height="6" fill="#fff" />
      <rect x="252" y="152" width="3" height="3" fill="#ff6600" />
      <%!-- Lives --%>
      <text x="30" y="44" fill="#00ff41" font-size="12" font-family="'Courier New',monospace">
        Lives: 3
      </text>
      <text x="420" y="44" fill="#00d4ff" font-size="12" font-family="'Courier New',monospace">
        Lives: 2
      </text>
    </svg>
    """
  end

  # ────────────────────────────────────────────────────────
  # 7. Hex Raid
  # ────────────────────────────────────────────────────────

  attr :class, :string, default: nil

  @spec diagram_game_raid(map()) :: Phoenix.LiveView.Rendered.t()
  def diagram_game_raid(assigns) do
    ~H"""
    <svg
      class={@class}
      viewBox="0 0 520 360"
      shape-rendering="crispEdges"
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-label="Hex Raid game screen: two jets flying through a scrolling river with enemies"
    >
      {win98_chrome("Hex Raid")}
      <%!-- River banks (brown/dark) --%>
      <rect x="8" y="24" width="80" height="322" fill="#2a1a0a" />
      <rect x="420" y="24" width="86" height="322" fill="#2a1a0a" />
      <%!-- River water --%>
      <rect x="88" y="24" width="332" height="322" fill="#001428" />
      <%!-- P1 jet (green) --%>
      <polygon points="180,300 172,316 188,316" fill="#00ff41" />
      <%!-- P2 jet (cyan) --%>
      <polygon points="300,280 292,296 308,296" fill="#00d4ff" />
      <%!-- Enemy boat --%>
      <rect x="220" y="140" width="20" height="10" fill="#ff0" />
      <%!-- Enemy helicopter --%>
      <rect x="320" y="200" width="16" height="8" fill="#ff6600" />
      <%!-- Fuel depot --%>
      <rect x="140" y="240" width="16" height="16" fill="#00ff00" stroke="#00ff00" stroke-width="1" />
      <text
        x="144"
        y="252"
        fill="#000"
        font-size="8"
        font-family="'Courier New',monospace"
        font-weight="bold"
      >
        F
      </text>
      <%!-- Bridge --%>
      <rect x="88" y="80" width="332" height="8" fill="#808080" />
      <%!-- Mine from P1 --%>
      <rect x="260" y="260" width="6" height="6" fill="#ff0000" />
      <%!-- HUD --%>
      <text x="30" y="340" fill="#00ff41" font-size="10" font-family="'Courier New',monospace">
        P1: 2340
      </text>
      <text x="420" y="340" fill="#00d4ff" font-size="10" font-family="'Courier New',monospace">
        P2: 1820
      </text>
      <text x="220" y="340" fill="#ffaa00" font-size="10" font-family="'Courier New',monospace">
        SEC 4
      </text>
    </svg>
    """
  end

  # ────────────────────────────────────────────────────────
  # 8. Hex Boxing
  # ────────────────────────────────────────────────────────

  attr :class, :string, default: nil

  @spec diagram_game_boxing(map()) :: Phoenix.LiveView.Rendered.t()
  def diagram_game_boxing(assigns) do
    ~H"""
    <svg
      class={@class}
      viewBox="0 0 520 360"
      shape-rendering="crispEdges"
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-label="Hex Boxing game screen: two boxers in a ring, close quarters punching"
    >
      {win98_chrome("Hex Boxing")}
      <%!-- Ring ropes --%>
      <rect x="30" y="50" width="452" height="2" fill="#ff0" opacity="0.5" />
      <rect x="30" y="320" width="452" height="2" fill="#ff0" opacity="0.5" />
      <rect x="30" y="50" width="2" height="272" fill="#ff0" opacity="0.5" />
      <rect x="480" y="50" width="2" height="272" fill="#ff0" opacity="0.5" />
      <%!-- P1 boxer (green circle) --%>
      <circle cx="200" cy="185" r="8" fill="#00ff41" />
      <%!-- P1 fist (extending) --%>
      <rect x="210" y="182" width="6" height="6" fill="#00ff41" />
      <%!-- P2 boxer (cyan circle) --%>
      <circle cx="300" cy="185" r="8" fill="#00d4ff" />
      <%!-- P2 fist (extending) --%>
      <rect x="288" y="182" width="6" height="6" fill="#00d4ff" />
      <%!-- Scores --%>
      <text x="30" y="44" fill="#00ff41" font-size="14" font-family="'Courier New',monospace">
        P1: 47
      </text>
      <text x="420" y="44" fill="#00d4ff" font-size="14" font-family="'Courier New',monospace">
        P2: 63
      </text>
      <text x="200" y="44" fill="#ffaa00" font-size="12" font-family="'Courier New',monospace">
        R2  1:24
      </text>
    </svg>
    """
  end

  # ────────────────────────────────────────────────────────
  # 9. Hex Outlaw
  # ────────────────────────────────────────────────────────

  attr :class, :string, default: nil

  @spec diagram_game_outlaw(map()) :: Phoenix.LiveView.Rendered.t()
  def diagram_game_outlaw(assigns) do
    ~H"""
    <svg
      class={@class}
      viewBox="0 0 520 360"
      shape-rendering="crispEdges"
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-label="Hex Outlaw game screen: two gunslingers facing off across a cactus"
    >
      {win98_chrome("Hex Outlaw")}
      <%!-- Desert ground line --%>
      <rect x="8" y="310" width="496" height="2" fill="#8B6914" opacity="0.4" />
      <%!-- Cactus obstacle (center) --%>
      <rect x="250" y="120" width="12" height="160" fill="#2d5a1e" />
      <rect x="234" y="160" width="16" height="8" fill="#2d5a1e" />
      <rect x="234" y="160" width="8" height="40" fill="#2d5a1e" />
      <rect x="262" y="200" width="16" height="8" fill="#2d5a1e" />
      <rect x="270" y="200" width="8" height="36" fill="#2d5a1e" />
      <%!-- P1 gunslinger (left, green) --%>
      <rect x="68" y="180" width="10" height="20" fill="#00ff41" />
      <rect x="70" y="174" width="6" height="6" fill="#00ff41" />
      <%!-- P2 gunslinger (right, cyan) --%>
      <rect x="434" y="160" width="10" height="20" fill="#00d4ff" />
      <rect x="436" y="154" width="6" height="6" fill="#00d4ff" />
      <%!-- Bullet from P1 --%>
      <rect x="160" y="188" width="4" height="3" fill="#ff0" />
      <%!-- Scores --%>
      <text x="30" y="44" fill="#00ff41" font-size="14" font-family="'Courier New',monospace">
        P1: 6
      </text>
      <text x="440" y="44" fill="#00d4ff" font-size="14" font-family="'Courier New',monospace">
        P2: 4
      </text>
      <text x="210" y="44" fill="#ffaa00" font-size="12" font-family="'Courier New',monospace">
        ROUND 2
      </text>
    </svg>
    """
  end

  # ────────────────────────────────────────────────────────
  # 10. Hex Hockey
  # ────────────────────────────────────────────────────────

  attr :class, :string, default: nil

  @spec diagram_game_hockey(map()) :: Phoenix.LiveView.Rendered.t()
  def diagram_game_hockey(assigns) do
    ~H"""
    <svg
      class={@class}
      viewBox="0 0 520 360"
      shape-rendering="crispEdges"
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-label="Hex Hockey game screen: ice hockey rink with players, goalies, and a puck"
    >
      {win98_chrome("Hex Hockey")}
      <%!-- Rink outline --%>
      <rect
        x="20"
        y="36"
        width="472"
        height="300"
        fill="none"
        stroke="#00d4ff"
        stroke-width="2"
        opacity="0.4"
      />
      <%!-- Center line --%>
      <line x1="256" y1="36" x2="256" y2="336" stroke="#ff0000" stroke-width="2" opacity="0.3" />
      <%!-- Center circle --%>
      <circle cx="256" cy="186" r="30" fill="none" stroke="#00d4ff" stroke-width="1" opacity="0.3" />
      <%!-- Goals (left and right) --%>
      <rect x="20" y="150" width="8" height="72" fill="none" stroke="#ff0" stroke-width="2" />
      <rect x="484" y="150" width="8" height="72" fill="none" stroke="#ff0" stroke-width="2" />
      <%!-- P1 goalie (left) --%>
      <rect x="30" y="178" width="6" height="16" fill="#00ff41" opacity="0.7" />
      <%!-- P2 goalie (right) --%>
      <rect x="478" y="182" width="6" height="16" fill="#00d4ff" opacity="0.7" />
      <%!-- P1 field player --%>
      <circle cx="180" cy="180" r="6" fill="#00ff41" />
      <%!-- P2 field player --%>
      <circle cx="340" cy="200" r="6" fill="#00d4ff" />
      <%!-- Puck --%>
      <circle cx="260" cy="186" r="3" fill="#fff" />
      <%!-- Scores --%>
      <text
        x="200"
        y="50"
        text-anchor="middle"
        fill="#00ff41"
        font-size="20"
        font-family="'Courier New',monospace"
        font-weight="bold"
      >
        2
      </text>
      <text
        x="312"
        y="50"
        text-anchor="middle"
        fill="#00d4ff"
        font-size="20"
        font-family="'Courier New',monospace"
        font-weight="bold"
      >
        1
      </text>
      <text
        x="256"
        y="50"
        text-anchor="middle"
        fill="#ffaa00"
        font-size="10"
        font-family="'Courier New',monospace"
      >
        -
      </text>
      <text x="210" y="340" fill="#ffaa00" font-size="10" font-family="'Courier New',monospace">
        Period 2  1:34
      </text>
    </svg>
    """
  end

  # ────────────────────────────────────────────────────────
  # 11. Hex Tennis
  # ────────────────────────────────────────────────────────

  attr :class, :string, default: nil

  @spec diagram_game_tennis(map()) :: Phoenix.LiveView.Rendered.t()
  def diagram_game_tennis(assigns) do
    ~H"""
    <svg
      class={@class}
      viewBox="0 0 520 360"
      shape-rendering="crispEdges"
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-label="Hex Tennis game screen: top-down tennis court with two players and a ball"
    >
      {win98_chrome("Hex Tennis")}
      <%!-- Court outline --%>
      <rect
        x="60"
        y="40"
        width="392"
        height="296"
        fill="none"
        stroke="#fff"
        stroke-width="2"
        opacity="0.5"
      />
      <%!-- Net --%>
      <line x1="60" y1="188" x2="452" y2="188" stroke="#fff" stroke-width="2" opacity="0.6" />
      <%!-- Service boxes --%>
      <rect
        x="140"
        y="40"
        width="232"
        height="148"
        fill="none"
        stroke="#fff"
        stroke-width="1"
        opacity="0.3"
      />
      <rect
        x="140"
        y="188"
        width="232"
        height="148"
        fill="none"
        stroke="#fff"
        stroke-width="1"
        opacity="0.3"
      />
      <line x1="256" y1="40" x2="256" y2="336" stroke="#fff" stroke-width="1" opacity="0.2" />
      <%!-- P1 (top, green) --%>
      <rect x="200" y="100" width="10" height="14" fill="#00ff41" />
      <%!-- P2 (bottom, cyan) --%>
      <rect x="280" y="260" width="10" height="14" fill="#00d4ff" />
      <%!-- Ball --%>
      <circle cx="240" cy="160" r="3" fill="#ff0" />
      <%!-- Score --%>
      <text x="30" y="44" fill="#00ff41" font-size="10" font-family="'Courier New',monospace">
        P1: 30
      </text>
      <text x="430" y="44" fill="#00d4ff" font-size="10" font-family="'Courier New',monospace">
        P2: 15
      </text>
      <text x="200" y="44" fill="#ffaa00" font-size="10" font-family="'Courier New',monospace">
        4-3
      </text>
    </svg>
    """
  end

  # ────────────────────────────────────────────────────────
  # 12. Hex Enduro
  # ────────────────────────────────────────────────────────

  attr :class, :string, default: nil

  @spec diagram_game_enduro(map()) :: Phoenix.LiveView.Rendered.t()
  def diagram_game_enduro(assigns) do
    ~H"""
    <svg
      class={@class}
      viewBox="0 0 520 360"
      shape-rendering="crispEdges"
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-label="Hex Enduro game screen: pseudo-3D road with two racing cars and AI traffic"
    >
      {win98_chrome("Hex Enduro")}
      <%!-- Road (perspective trapezoid) --%>
      <polygon points="220,60 292,60 480,340 32,340" fill="#333" />
      <%!-- Road center line --%>
      <line
        x1="256"
        y1="60"
        x2="256"
        y2="340"
        stroke="#ff0"
        stroke-width="1"
        opacity="0.3"
        stroke-dasharray="8,8"
      />
      <%!-- Lane dividers --%>
      <line
        x1="236"
        y1="60"
        x2="144"
        y2="340"
        stroke="#fff"
        stroke-width="1"
        opacity="0.15"
        stroke-dasharray="4,8"
      />
      <line
        x1="276"
        y1="60"
        x2="368"
        y2="340"
        stroke="#fff"
        stroke-width="1"
        opacity="0.15"
        stroke-dasharray="4,8"
      />
      <%!-- AI car (ahead, small) --%>
      <rect x="242" y="140" width="10" height="6" fill="#ff6600" />
      <%!-- AI car (mid, medium) --%>
      <rect x="180" y="220" width="14" height="8" fill="#ff0066" />
      <%!-- P1 car (green, large, bottom) --%>
      <rect x="200" y="290" width="20" height="12" fill="#00ff41" />
      <%!-- P2 car (cyan, large, bottom) --%>
      <rect x="300" y="280" width="20" height="12" fill="#00d4ff" />
      <%!-- HUD --%>
      <text x="30" y="44" fill="#00ff41" font-size="10" font-family="'Courier New',monospace">
        P1: 42
      </text>
      <text x="430" y="44" fill="#00d4ff" font-size="10" font-family="'Courier New',monospace">
        P2: 38
      </text>
      <text x="200" y="44" fill="#ffaa00" font-size="10" font-family="'Courier New',monospace">
        DAY 1  2:15
      </text>
      <%!-- Fuel gauge --%>
      <rect x="30" y="320" width="60" height="6" fill="#333" />
      <rect x="30" y="320" width="40" height="6" fill="#00ff00" />
      <text x="30" y="338" fill="#aaa" font-size="8" font-family="'Courier New',monospace">FUEL</text>
    </svg>
    """
  end

  # ────────────────────────────────────────────────────────
  # 13. Hex Invaders
  # ────────────────────────────────────────────────────────

  attr :class, :string, default: nil

  @spec diagram_game_invaders(map()) :: Phoenix.LiveView.Rendered.t()
  def diagram_game_invaders(assigns) do
    ~H"""
    <svg
      class={@class}
      viewBox="0 0 520 360"
      shape-rendering="crispEdges"
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-label="Hex Invaders game screen: split-screen Space Invaders with alien grids on each side"
    >
      {win98_chrome("Hex Invaders")}
      <%!-- Divider --%>
      <line x1="256" y1="24" x2="256" y2="346" stroke="#fff" stroke-width="1" opacity="0.3" />
      <%!-- P1 aliens (left side, 6x5 grid) --%>
      <%= for row <- 0..4, col <- 0..5 do %>
        <rect
          x={30 + col * 34}
          y={60 + row * 24}
          width="12"
          height="8"
          fill={
            case row do
              0 -> "#ff0066"
              1 -> "#ff6600"
              _ -> "#00ff66"
            end
          }
        />
      <% end %>
      <%!-- P2 aliens (right side) --%>
      <%= for row <- 0..4, col <- 0..5 do %>
        <rect
          x={270 + col * 34}
          y={60 + row * 24}
          width="12"
          height="8"
          fill={
            case row do
              0 -> "#ff0066"
              1 -> "#ff6600"
              _ -> "#00ff66"
            end
          }
        />
      <% end %>
      <%!-- Shields (P1 side) --%>
      <rect x="60" y="270" width="24" height="12" fill="#00ff00" opacity="0.6" />
      <rect x="140" y="270" width="24" height="12" fill="#00ff00" opacity="0.6" />
      <%!-- Shields (P2 side) --%>
      <rect x="300" y="270" width="24" height="12" fill="#00ff00" opacity="0.6" />
      <rect x="380" y="270" width="24" height="12" fill="#00ff00" opacity="0.6" />
      <%!-- P1 cannon --%>
      <rect x="110" y="310" width="16" height="8" fill="#00ff41" />
      <rect x="116" y="306" width="4" height="4" fill="#00ff41" />
      <%!-- P2 cannon --%>
      <rect x="360" y="310" width="16" height="8" fill="#00d4ff" />
      <rect x="366" y="306" width="4" height="4" fill="#00d4ff" />
      <%!-- Missile from P1 --%>
      <rect x="117" y="280" width="2" height="6" fill="#fff" />
      <%!-- Scores --%>
      <text x="30" y="44" fill="#00ff41" font-size="10" font-family="'Courier New',monospace">
        P1: 820
      </text>
      <text x="420" y="44" fill="#00d4ff" font-size="10" font-family="'Courier New',monospace">
        P2: 640
      </text>
      <text x="210" y="44" fill="#ffaa00" font-size="10" font-family="'Courier New',monospace">
        WAVE 3
      </text>
    </svg>
    """
  end

  # ────────────────────────────────────────────────────────
  # 14. Hex Frost
  # ────────────────────────────────────────────────────────

  attr :class, :string, default: nil

  @spec diagram_game_frost(map()) :: Phoenix.LiveView.Rendered.t()
  def diagram_game_frost(assigns) do
    ~H"""
    <svg
      class={@class}
      viewBox="0 0 520 360"
      shape-rendering="crispEdges"
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-label="Hex Frost game screen: ice blocks floating on water with igloos on shore"
    >
      {win98_chrome("Hex Frost")}
      <%!-- Shore (top) --%>
      <rect x="8" y="24" width="496" height="50" fill="#1a3a5a" />
      <%!-- P1 igloo (left) --%>
      <rect x="30" y="40" width="30" height="20" fill="#ddf" />
      <polygon points="30,40 45,28 60,40" fill="#eef" />
      <%!-- P2 igloo (right, partially built) --%>
      <rect x="440" y="46" width="30" height="14" fill="#ddf" opacity="0.5" />
      <%!-- Water --%>
      <rect x="8" y="74" width="496" height="268" fill="#001840" />
      <%!-- Ice block rows (4 rows) --%>
      <%= for col <- 0..6 do %>
        <rect x={24 + col * 66} y="100" width="48" height="12" fill="#88ccff" />
        <rect x={50 + col * 66} y="160" width="48" height="12" fill="#88ccff" />
        <rect x={24 + col * 66} y="220" width="48" height="12" fill="#88ccff" />
        <rect x={50 + col * 66} y="280" width="48" height="12" fill="#88ccff" />
      <% end %>
      <%!-- Some claimed blocks (blue for P1, cyan for P2) --%>
      <rect x="90" y="100" width="48" height="12" fill="#0066ff" />
      <rect x="222" y="100" width="48" height="12" fill="#0066ff" />
      <rect x="182" y="160" width="48" height="12" fill="#00ccff" />
      <%!-- P1 player (on an ice block) --%>
      <rect x="160" y="92" width="6" height="8" fill="#00ff41" />
      <%!-- P2 player (on a different row) --%>
      <rect x="320" y="272" width="6" height="8" fill="#00d4ff" />
      <%!-- Polar bear on shore --%>
      <rect x="240" y="50" width="10" height="8" fill="#fff" />
      <%!-- Temperature --%>
      <text x="220" y="44" fill="#ffaa00" font-size="10" font-family="'Courier New',monospace">
        32°  R2
      </text>
      <text x="30" y="340" fill="#00ff41" font-size="10" font-family="'Courier New',monospace">
        P1: 8/15
      </text>
      <text x="420" y="340" fill="#00d4ff" font-size="10" font-family="'Courier New',monospace">
        P2: 5/15
      </text>
    </svg>
    """
  end

  # ────────────────────────────────────────────────────────
  # 15. Hex Skiing
  # ────────────────────────────────────────────────────────

  attr :class, :string, default: nil

  @spec diagram_game_skiing(map()) :: Phoenix.LiveView.Rendered.t()
  def diagram_game_skiing(assigns) do
    ~H"""
    <svg
      class={@class}
      viewBox="0 0 520 360"
      shape-rendering="crispEdges"
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-label="Hex Skiing game screen: two skiers descending through trees and slalom gates with avalanche behind"
    >
      {win98_chrome("Hex Skiing")}
      <%!-- Snow ground --%>
      <rect x="8" y="24" width="496" height="322" fill="#0a1428" />
      <%!-- Avalanche (top, red/orange gradient line) --%>
      <rect x="8" y="24" width="496" height="20" fill="#ff3300" opacity="0.3" />
      <rect x="8" y="44" width="496" height="10" fill="#ff3300" opacity="0.15" />
      <%!-- Trees --%>
      <polygon points="100,140 92,160 108,160" fill="#2d5a1e" />
      <polygon points="300,100 292,120 308,120" fill="#2d5a1e" />
      <polygon points="400,200 392,220 408,220" fill="#2d5a1e" />
      <polygon points="160,260 152,280 168,280" fill="#2d5a1e" />
      <polygon points="360,300 352,320 368,320" fill="#2d5a1e" />
      <%!-- Rocks --%>
      <rect x="220" y="180" width="12" height="8" fill="#666" />
      <rect x="440" y="280" width="10" height="6" fill="#666" />
      <%!-- Slalom gate --%>
      <rect x="180" y="200" width="4" height="12" fill="#ff0000" />
      <rect x="240" y="200" width="4" height="12" fill="#0000ff" />
      <%!-- P1 skier (green) --%>
      <rect x="200" y="300" width="6" height="8" fill="#00ff41" />
      <%!-- P2 skier (cyan) --%>
      <rect x="280" y="280" width="6" height="8" fill="#00d4ff" />
      <%!-- HUD --%>
      <text x="30" y="340" fill="#00ff41" font-size="10" font-family="'Courier New',monospace">
        P1: 42.3s
      </text>
      <text x="400" y="340" fill="#00d4ff" font-size="10" font-family="'Courier New',monospace">
        P2: 39.8s
      </text>
      <text x="210" y="340" fill="#ffaa00" font-size="10" font-family="'Courier New',monospace">
        R1
      </text>
    </svg>
    """
  end
end
