defmodule RetroHexChatWeb.Components.Diagrams.GameRaid do
  @moduledoc "SVG game screen diagram for Hex Raid."
  use Phoenix.Component
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.Diagrams.GameScreens, only: [win98_chrome: 1]

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
      aria-label={
        dgettext(
          "diagrams",
          "Hex Raid game screen: two jets flying through a scrolling river with enemies"
        )
      }
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
        {dgettext("diagrams", "P1: 2340")}
      </text>
      <text x="420" y="340" fill="#00d4ff" font-size="10" font-family="'Courier New',monospace">
        {dgettext("diagrams", "P2: 1820")}
      </text>
      <text x="220" y="340" fill="#ffaa00" font-size="10" font-family="'Courier New',monospace">
        {dgettext("diagrams", "SEC 4")}
      </text>
    </svg>
    """
  end
end
