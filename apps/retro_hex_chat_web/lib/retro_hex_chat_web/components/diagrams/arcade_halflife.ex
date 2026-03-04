defmodule RetroHexChatWeb.Components.Diagrams.ArcadeHalflife do
  @moduledoc """
  SVG logo/cover art for the Half-Life arcade help page.
  """
  use Phoenix.Component

  import RetroHexChatWeb.Components.Diagrams.GameScreens, only: [win98_chrome: 1]

  attr :class, :string, default: nil

  @spec diagram_arcade_halflife(map()) :: Phoenix.LiveView.Rendered.t()
  def diagram_arcade_halflife(assigns) do
    ~H"""
    <svg
      class={@class}
      viewBox="0 0 520 360"
      shape-rendering="crispEdges"
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-label="Half-Life arcade logo: orange lambda symbol on dark background"
    >
      {win98_chrome("Half-Life - Arcade")}
      <%!-- Background --%>
      <rect x="7" y="23" width="498" height="324" fill="#0a0808" />
      <%!-- Orange circle (Black Mesa logo background) --%>
      <circle cx="256" cy="165" r="75" fill="#1a1008" stroke="#ff8c00" stroke-width="3" />
      <circle cx="256" cy="165" r="70" fill="none" stroke="#cc7000" stroke-width="2" />
      <%!-- Lambda (λ) symbol --%>
      <text
        x="256"
        y="200"
        text-anchor="middle"
        fill="#ff8c00"
        font-size="100"
        font-family="serif"
        font-weight="bold"
      >
        λ
      </text>
      <%!-- Title --%>
      <text
        x="256"
        y="280"
        text-anchor="middle"
        fill="#ff8c00"
        font-size="22"
        font-family="'Courier New',monospace"
        font-weight="bold"
      >
        HALF-LIFE
      </text>
      <%!-- Subtitle --%>
      <text
        x="256"
        y="300"
        text-anchor="middle"
        fill="#808080"
        font-size="11"
        font-family="'Courier New',monospace"
      >
        Xash3D-FWGS WebAssembly
      </text>
      <%!-- Uplink badge --%>
      <rect
        x="200"
        y="308"
        width="112"
        height="18"
        fill="none"
        stroke="#ff8c00"
        stroke-width="1"
        opacity="0.5"
      />
      <text
        x="256"
        y="321"
        text-anchor="middle"
        fill="#ff8c00"
        font-size="10"
        font-family="'Courier New',monospace"
        opacity="0.7"
      >
        UPLINK DEMO
      </text>
    </svg>
    """
  end
end
