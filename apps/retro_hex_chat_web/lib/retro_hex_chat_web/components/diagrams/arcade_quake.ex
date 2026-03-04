defmodule RetroHexChatWeb.Components.Diagrams.ArcadeQuake do
  @moduledoc """
  SVG logo/cover art for the Quake arcade help page.
  """
  use Phoenix.Component

  import RetroHexChatWeb.Components.Diagrams.GameScreens, only: [win98_chrome: 1]

  attr :class, :string, default: nil

  @spec diagram_arcade_quake(map()) :: Phoenix.LiveView.Rendered.t()
  def diagram_arcade_quake(assigns) do
    ~H"""
    <svg
      class={@class}
      viewBox="0 0 520 360"
      shape-rendering="crispEdges"
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-label="Quake arcade logo: stylized Q symbol in bronze on dark background"
    >
      {win98_chrome("Quake - Arcade")}
      <%!-- Background --%>
      <rect x="7" y="23" width="498" height="324" fill="#0a0a08" />
      <%!-- Quake nail/axe symbol - simplified --%>
      <%!-- Outer circle --%>
      <circle cx="256" cy="170" r="80" fill="none" stroke="#8b6914" stroke-width="6" />
      <%!-- Inner angular Q shape --%>
      <circle cx="256" cy="170" r="50" fill="none" stroke="#cd853f" stroke-width="4" />
      <%!-- Axe blade / nail going through --%>
      <line x1="256" y1="90" x2="256" y2="250" stroke="#cd853f" stroke-width="8" />
      <line x1="230" y1="100" x2="256" y2="130" stroke="#8b6914" stroke-width="4" />
      <line x1="282" y1="100" x2="256" y2="130" stroke="#8b6914" stroke-width="4" />
      <%!-- Cross bar --%>
      <line x1="210" y1="170" x2="302" y2="170" stroke="#cd853f" stroke-width="4" />
      <%!-- Title text --%>
      <text
        x="256"
        y="290"
        text-anchor="middle"
        fill="#cd853f"
        font-size="28"
        font-family="'Courier New',monospace"
        font-weight="bold"
      >
        QUAKE
      </text>
      <%!-- Subtitle --%>
      <text
        x="256"
        y="310"
        text-anchor="middle"
        fill="#808080"
        font-size="11"
        font-family="'Courier New',monospace"
      >
        QuakeSpasm WebAssembly
      </text>
      <%!-- Corner rivets --%>
      <circle cx="30" cy="46" r="4" fill="#8b6914" opacity="0.5" />
      <circle cx="490" cy="46" r="4" fill="#8b6914" opacity="0.5" />
      <circle cx="30" cy="324" r="4" fill="#8b6914" opacity="0.5" />
      <circle cx="490" cy="324" r="4" fill="#8b6914" opacity="0.5" />
    </svg>
    """
  end
end
