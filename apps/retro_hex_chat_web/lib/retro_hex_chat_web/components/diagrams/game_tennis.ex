defmodule RetroHexChatWeb.Components.Diagrams.GameTennis do
  @moduledoc "SVG game screen diagram for Hex Tennis."
  use Phoenix.Component
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.Diagrams.GameScreens, only: [win98_chrome: 1]

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
      aria-label={
        gettext("Hex Tennis game screen: top-down tennis court with two players and a ball")
      }
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
        {gettext("P1: 30")}
      </text>
      <text x="430" y="44" fill="#00d4ff" font-size="10" font-family="'Courier New',monospace">
        {gettext("P2: 15")}
      </text>
      <text x="200" y="44" fill="#ffaa00" font-size="10" font-family="'Courier New',monospace">
        4-3
      </text>
    </svg>
    """
  end
end
