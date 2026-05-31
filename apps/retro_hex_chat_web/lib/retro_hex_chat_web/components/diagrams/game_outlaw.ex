defmodule RetroHexChatWeb.Components.Diagrams.GameOutlaw do
  @moduledoc "SVG game screen diagram for Hex Outlaw."
  use Phoenix.Component
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.Diagrams.GameScreens, only: [win98_chrome: 1]

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
      aria-label={
        dgettext("diagrams", "Hex Outlaw game screen: two gunslingers facing off across a cactus")
      }
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
        {dgettext("diagrams", "P1: 6")}
      </text>
      <text x="440" y="44" fill="#00d4ff" font-size="14" font-family="'Courier New',monospace">
        {dgettext("diagrams", "P2: 4")}
      </text>
      <text x="210" y="44" fill="#ffaa00" font-size="12" font-family="'Courier New',monospace">
        {dgettext("diagrams", "ROUND 2")}
      </text>
    </svg>
    """
  end
end
