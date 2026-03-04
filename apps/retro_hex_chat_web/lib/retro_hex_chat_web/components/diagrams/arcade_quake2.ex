defmodule RetroHexChatWeb.Components.Diagrams.ArcadeQuake2 do
  @moduledoc """
  SVG logo/cover art for the Quake II arcade help page.
  """
  use Phoenix.Component

  import RetroHexChatWeb.Components.Diagrams.GameScreens, only: [win98_chrome: 1]

  attr :class, :string, default: nil

  @spec diagram_arcade_quake2(map()) :: Phoenix.LiveView.Rendered.t()
  def diagram_arcade_quake2(assigns) do
    ~H"""
    <svg
      class={@class}
      viewBox="0 0 520 360"
      shape-rendering="crispEdges"
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-label="Quake II arcade logo: metallic Q2 emblem on dark industrial background"
    >
      {win98_chrome("Quake II - Arcade")}
      <%!-- Background --%>
      <rect x="7" y="23" width="498" height="324" fill="#080a0a" />
      <%!-- Industrial grid pattern --%>
      <%= for i <- 0..9 do %>
        <line
          x1={7 + i * 50}
          y1="23"
          x2={7 + i * 50}
          y2="347"
          stroke="#1a1a1a"
          stroke-width="1"
        />
      <% end %>
      <%= for i <- 0..6 do %>
        <line
          x1="7"
          y1={23 + i * 50}
          x2="505"
          y2={23 + i * 50}
          stroke="#1a1a1a"
          stroke-width="1"
        />
      <% end %>
      <%!-- Strogg emblem - angular metallic shape --%>
      <polygon
        points="256,80 310,110 310,210 256,240 202,210 202,110"
        fill="#2a2a2a"
        stroke="#707070"
        stroke-width="2"
      />
      <%!-- Q2 text --%>
      <text
        x="256"
        y="180"
        text-anchor="middle"
        fill="#a0a0a0"
        font-size="52"
        font-family="'Courier New',monospace"
        font-weight="bold"
      >
        Q2
      </text>
      <%!-- Metallic shine line --%>
      <line x1="210" y1="115" x2="302" y2="115" stroke="#c0c0c0" stroke-width="1" opacity="0.4" />
      <%!-- Title --%>
      <text
        x="256"
        y="280"
        text-anchor="middle"
        fill="#a0a0a0"
        font-size="24"
        font-family="'Courier New',monospace"
        font-weight="bold"
      >
        QUAKE II
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
        Yamagi Quake II WebAssembly
      </text>
      <%!-- Strogg invasion badge --%>
      <rect
        x="195"
        y="308"
        width="122"
        height="18"
        fill="none"
        stroke="#707070"
        stroke-width="1"
        opacity="0.5"
      />
      <text
        x="256"
        y="321"
        text-anchor="middle"
        fill="#a0a0a0"
        font-size="10"
        font-family="'Courier New',monospace"
        opacity="0.7"
      >
        THE INVASION
      </text>
    </svg>
    """
  end
end
