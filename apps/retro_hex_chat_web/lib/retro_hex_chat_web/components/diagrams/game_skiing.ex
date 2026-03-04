defmodule RetroHexChatWeb.Components.Diagrams.GameSkiing do
  @moduledoc "SVG game screen diagram for Hex Skiing."
  use Phoenix.Component

  import RetroHexChatWeb.Components.Diagrams.GameScreens, only: [win98_chrome: 1]

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
