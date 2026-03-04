defmodule RetroHexChatWeb.Components.Diagrams.GameBoxing do
  @moduledoc "SVG game screen diagram for Hex Boxing."
  use Phoenix.Component

  import RetroHexChatWeb.Components.Diagrams.GameScreens, only: [win98_chrome: 1]

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
end
