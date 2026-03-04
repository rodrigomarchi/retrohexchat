defmodule RetroHexChatWeb.Components.Diagrams.GameWarlords do
  @moduledoc "SVG game screen diagram for Hex Warlords."
  use Phoenix.Component

  import RetroHexChatWeb.Components.Diagrams.GameScreens, only: [win98_chrome: 1]

  attr :class, :string, default: nil

  @spec diagram_game_warlords(map()) :: Phoenix.LiveView.Rendered.t()
  def diagram_game_warlords(assigns) do
    ~H"""
    <svg
      class={@class}
      viewBox="0 0 520 360"
      shape-rendering="crispEdges"
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-label="Hex Warlords game screen: two castles with brick walls and a fireball bouncing between them"
    >
      {win98_chrome("Hex Warlords")}
      <%!-- P1 castle bricks (left, 4 cols x 6 rows) --%>
      <%= for row <- 0..5, col <- 0..3 do %>
        <rect
          x={30 + col * 18}
          y={100 + row * 14}
          width="16"
          height="12"
          fill={
            case col do
              3 -> "#00ff66"
              2 -> "#00ccff"
              1 -> "#ffcc00"
              0 -> "#ff3366"
            end
          }
        />
      <% end %>
      <%!-- P1 king --%>
      <rect x="18" y="134" width="10" height="10" fill="#ffcc00" />
      <%!-- P1 shield --%>
      <rect x="104" y="120" width="8" height="48" fill="#00ff41" />
      <%!-- P2 castle bricks (right, 4 cols x 6 rows, some destroyed) --%>
      <%= for row <- 0..5, col <- 0..3 do %>
        <%= if not (row in [2, 3] and col == 0) do %>
          <rect
            x={398 + col * 18}
            y={100 + row * 14}
            width="16"
            height="12"
            fill={
              case col do
                0 -> "#00ff66"
                1 -> "#00ccff"
                2 -> "#ffcc00"
                3 -> "#ff3366"
              end
            }
          />
        <% end %>
      <% end %>
      <%!-- P2 king --%>
      <rect x="484" y="134" width="10" height="10" fill="#ffcc00" />
      <%!-- P2 shield --%>
      <rect x="388" y="140" width="8" height="48" fill="#00d4ff" />
      <%!-- Fireball --%>
      <rect x="250" y="150" width="6" height="6" fill="#fff" />
      <rect x="252" y="152" width="3" height="3" fill="#ff6600" />
      <%!-- Lives --%>
      <text x="30" y="44" fill="#00ff41" font-size="12" font-family="'Courier New',monospace">
        Lives: 3
      </text>
      <text x="420" y="44" fill="#00d4ff" font-size="12" font-family="'Courier New',monospace">
        Lives: 2
      </text>
    </svg>
    """
  end
end
