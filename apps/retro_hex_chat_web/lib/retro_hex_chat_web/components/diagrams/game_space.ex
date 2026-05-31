defmodule RetroHexChatWeb.Components.Diagrams.GameSpace do
  @moduledoc "SVG game screen diagram for Star Duel."
  use Phoenix.Component
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.Diagrams.GameScreens, only: [win98_chrome: 1]

  attr :class, :string, default: nil

  @spec diagram_game_space(map()) :: Phoenix.LiveView.Rendered.t()
  def diagram_game_space(assigns) do
    ~H"""
    <svg
      class={@class}
      viewBox="0 0 520 360"
      shape-rendering="crispEdges"
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-label={
        dgettext("diagrams", "Star Duel game screen: two ships in open space with missiles")
      }
    >
      {win98_chrome("Star Duel")}
      <%!-- Stars background --%>
      <rect x="50" y="60" width="2" height="2" fill="#fff" opacity="0.5" />
      <rect x="150" y="120" width="2" height="2" fill="#fff" opacity="0.4" />
      <rect x="300" y="80" width="2" height="2" fill="#fff" opacity="0.6" />
      <rect x="420" y="140" width="2" height="2" fill="#fff" opacity="0.3" />
      <rect x="380" y="280" width="2" height="2" fill="#fff" opacity="0.5" />
      <rect x="100" y="300" width="2" height="2" fill="#fff" opacity="0.4" />
      <rect x="460" y="60" width="2" height="2" fill="#fff" opacity="0.5" />
      <rect x="200" y="240" width="2" height="2" fill="#fff" opacity="0.3" />
      <%!-- P1 ship (green triangle pointing right) --%>
      <polygon points="120,180 100,170 100,190" fill="#00ff41" />
      <%!-- P1 thrust flame --%>
      <polygon points="98,178 90,180 98,182" fill="#ff6600" opacity="0.7" />
      <%!-- P2 ship (cyan triangle pointing left) --%>
      <polygon points="380,200 400,190 400,210" fill="#00d4ff" />
      <%!-- Missiles --%>
      <rect x="132" y="178" width="4" height="4" fill="#ff0" />
      <rect x="156" y="176" width="4" height="4" fill="#ff0" />
      <%!-- Scores --%>
      <text x="30" y="44" fill="#00ff41" font-size="14" font-family="'Courier New',monospace">4</text>
      <text x="480" y="44" fill="#00d4ff" font-size="14" font-family="'Courier New',monospace">
        2
      </text>
    </svg>
    """
  end
end
