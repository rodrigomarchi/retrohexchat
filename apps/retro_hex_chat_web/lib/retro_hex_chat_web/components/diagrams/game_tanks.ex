defmodule RetroHexChatWeb.Components.Diagrams.GameTanks do
  @moduledoc "SVG game screen diagram for Pixel Tanks."
  use Phoenix.Component
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.Diagrams.GameScreens, only: [win98_chrome: 1]

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
      aria-label={dgettext("diagrams", "Pixel Tanks game screen: two tanks in a maze arena")}
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
        {dgettext("diagrams", "P1: 3")}
      </text>
      <text x="440" y="44" fill="#00d4ff" font-size="12" font-family="'Courier New',monospace">
        {dgettext("diagrams", "P2: 1")}
      </text>
      <text x="210" y="44" fill="#ffaa00" font-size="12" font-family="'Courier New',monospace">
        {dgettext("diagrams", "ROUND 2 1:24")}
      </text>
    </svg>
    """
  end
end
