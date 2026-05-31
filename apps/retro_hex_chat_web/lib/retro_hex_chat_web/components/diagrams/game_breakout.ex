defmodule RetroHexChatWeb.Components.Diagrams.GameBreakout do
  @moduledoc "SVG game screen diagram for Block Breakers."
  use Phoenix.Component
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.Diagrams.GameScreens, only: [win98_chrome: 1]

  attr :class, :string, default: nil

  @spec diagram_game_breakout(map()) :: Phoenix.LiveView.Rendered.t()
  def diagram_game_breakout(assigns) do
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
          "Block Breakers game screen: two paddles with colored block rows between them"
        )
      }
    >
      {win98_chrome("Block Breakers")}
      <%!-- Block rows --%>
      <%= for col <- 0..9 do %>
        <rect x={20 + col * 48} y="120" width="44" height="12" fill="#ff0066" />
        <rect x={20 + col * 48} y="136" width="44" height="12" fill="#ff6600" />
        <rect x={20 + col * 48} y="152" width="44" height="12" fill="#ffcc00" />
        <rect x={20 + col * 48} y="168" width="44" height="12" fill="#00ff66" />
        <rect x={20 + col * 48} y="184" width="44" height="12" fill="#00ccff" />
      <% end %>
      <%!-- Some blocks destroyed --%>
      <rect x="116" y="184" width="44" height="12" fill="#000" />
      <rect x="212" y="184" width="44" height="12" fill="#000" />
      <rect x="212" y="168" width="44" height="12" fill="#000" />
      <%!-- P2 paddle (top) --%>
      <rect x="220" y="40" width="60" height="8" fill="#00d4ff" />
      <%!-- P1 paddle (bottom) --%>
      <rect x="180" y="330" width="60" height="8" fill="#00ff41" />
      <%!-- Ball --%>
      <rect x="250" y="220" width="6" height="6" fill="#fff" />
      <%!-- Score + Lives --%>
      <text x="30" y="340" fill="#00ff41" font-size="10" font-family="'Courier New',monospace">
        {dgettext("diagrams", "Score: 340")}
      </text>
      <text x="420" y="340" fill="#ffaa00" font-size="10" font-family="'Courier New',monospace">
        {dgettext("diagrams", "Lives: 2")}
      </text>
    </svg>
    """
  end
end
