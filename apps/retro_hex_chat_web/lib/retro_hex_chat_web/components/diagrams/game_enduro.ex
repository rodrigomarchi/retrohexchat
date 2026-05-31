defmodule RetroHexChatWeb.Components.Diagrams.GameEnduro do
  @moduledoc "SVG game screen diagram for Hex Enduro."
  use Phoenix.Component
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.Diagrams.GameScreens, only: [win98_chrome: 1]

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
      aria-label={
        gettext("Hex Enduro game screen: pseudo-3D road with two racing cars and AI traffic")
      }
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
        {gettext("P1: 42")}
      </text>
      <text x="430" y="44" fill="#00d4ff" font-size="10" font-family="'Courier New',monospace">
        {gettext("P2: 38")}
      </text>
      <text x="200" y="44" fill="#ffaa00" font-size="10" font-family="'Courier New',monospace">
        {gettext("DAY 1 2:15")}
      </text>
      <%!-- Fuel gauge --%>
      <rect x="30" y="320" width="60" height="6" fill="#333" />
      <rect x="30" y="320" width="40" height="6" fill="#00ff00" />
      <text x="30" y="338" fill="#aaa" font-size="8" font-family="'Courier New',monospace">
        {gettext("FUEL")}
      </text>
    </svg>
    """
  end
end
