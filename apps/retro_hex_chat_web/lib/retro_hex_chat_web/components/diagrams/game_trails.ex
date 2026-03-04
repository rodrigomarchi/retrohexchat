defmodule RetroHexChatWeb.Components.Diagrams.GameTrails do
  @moduledoc "SVG game screen diagram for Light Trails."
  use Phoenix.Component

  import RetroHexChatWeb.Components.Diagrams.GameScreens, only: [win98_chrome: 1]

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
end
