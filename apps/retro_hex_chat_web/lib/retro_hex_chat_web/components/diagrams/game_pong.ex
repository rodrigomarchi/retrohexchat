defmodule RetroHexChatWeb.Components.Diagrams.GamePong do
  @moduledoc "SVG game screen diagram for Hex Pong."
  use Phoenix.Component
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.Diagrams.GameScreens, only: [win98_chrome: 1]

  attr :class, :string, default: nil

  @spec diagram_game_pong(map()) :: Phoenix.LiveView.Rendered.t()
  def diagram_game_pong(assigns) do
    ~H"""
    <svg
      class={@class}
      viewBox="0 0 520 360"
      shape-rendering="crispEdges"
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-label={
        dgettext(
          "diagrams",
          "Hex Pong game screen: two paddles and a ball on a dark field with dashed center line"
        )
      }
    >
      {win98_chrome("Hex Pong")}
      <%!-- Center dashed line --%>
      <%= for y <- 0..15 do %>
        <rect x="254" y={26 + y * 20} width="4" height="10" fill="#00ff00" opacity="0.3" />
      <% end %>
      <%!-- Scores --%>
      <text
        x="200"
        y="52"
        text-anchor="middle"
        fill="#00ff00"
        font-size="28"
        font-family="'Courier New',monospace"
        font-weight="bold"
      >
        3
      </text>
      <text
        x="312"
        y="52"
        text-anchor="middle"
        fill="#00ff00"
        font-size="28"
        font-family="'Courier New',monospace"
        font-weight="bold"
      >
        7
      </text>
      <%!-- Left paddle (P1) --%>
      <rect x="36" y="140" width="8" height="60" fill="#00ff00" />
      <%!-- Right paddle (P2) --%>
      <rect x="468" y="200" width="8" height="60" fill="#00ff00" />
      <%!-- Ball --%>
      <rect x="280" y="180" width="8" height="8" fill="#fff" />
      <%!-- Ball trail --%>
      <rect x="272" y="184" width="6" height="6" fill="#00ff00" opacity="0.3" />
      <rect x="264" y="188" width="4" height="4" fill="#00ff00" opacity="0.15" />
      <%!-- CRT scanlines hint --%>
      <%= for y <- 0..7 do %>
        <rect x="6" y={24 + y * 40} width="500" height="1" fill="#000" opacity="0.08" />
      <% end %>
    </svg>
    """
  end
end
