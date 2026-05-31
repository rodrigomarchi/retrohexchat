defmodule RetroHexChatWeb.Components.Diagrams.GameHockey do
  @moduledoc "SVG game screen diagram for Hex Hockey."
  use Phoenix.Component
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.Diagrams.GameScreens, only: [win98_chrome: 1]

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
      aria-label={
        gettext("Hex Hockey game screen: ice hockey rink with players, goalies, and a puck")
      }
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
        {gettext("Period 2 1:34")}
      </text>
    </svg>
    """
  end
end
