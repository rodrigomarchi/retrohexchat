defmodule RetroHexChatWeb.Components.Diagrams.GameInvaders do
  @moduledoc "SVG game screen diagram for Hex Invaders."
  use Phoenix.Component
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.Diagrams.GameScreens, only: [win98_chrome: 1]

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
      aria-label={
        gettext("Hex Invaders game screen: split-screen Space Invaders with alien grids on each side")
      }
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
        {gettext("P1: 820")}
      </text>
      <text x="420" y="44" fill="#00d4ff" font-size="10" font-family="'Courier New',monospace">
        {gettext("P2: 640")}
      </text>
      <text x="210" y="44" fill="#ffaa00" font-size="10" font-family="'Courier New',monospace">
        {gettext("WAVE 3")}
      </text>
    </svg>
    """
  end
end
