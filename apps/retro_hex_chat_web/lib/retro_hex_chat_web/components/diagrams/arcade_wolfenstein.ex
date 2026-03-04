defmodule RetroHexChatWeb.Components.Diagrams.ArcadeWolfenstein do
  @moduledoc """
  SVG logo/cover art for the Wolfenstein 3D arcade help page.
  """
  use Phoenix.Component

  import RetroHexChatWeb.Components.Diagrams.GameScreens, only: [win98_chrome: 1]

  attr :class, :string, default: nil

  @spec diagram_arcade_wolfenstein(map()) :: Phoenix.LiveView.Rendered.t()
  def diagram_arcade_wolfenstein(assigns) do
    ~H"""
    <svg
      class={@class}
      viewBox="0 0 520 360"
      shape-rendering="crispEdges"
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-label="Wolfenstein 3D arcade logo: shield emblem in grey tones on dark blue background"
    >
      {win98_chrome("Wolfenstein 3D - Arcade")}
      <%!-- Background --%>
      <rect x="7" y="23" width="498" height="324" fill="#0a0a14" />
      <%!-- Shield shape --%>
      <polygon
        points="256,80 330,110 330,200 256,260 182,200 182,110"
        fill="#2a2a3a"
        stroke="#808080"
        stroke-width="3"
      />
      <polygon
        points="256,90 320,116 320,195 256,248 192,195 192,116"
        fill="#1a1a2a"
        stroke="#606060"
        stroke-width="2"
      />
      <%!-- W letter in shield --%>
      <text
        x="256"
        y="185"
        text-anchor="middle"
        fill="#c0c0c0"
        font-size="60"
        font-family="'Courier New',monospace"
        font-weight="bold"
      >
        W
      </text>
      <%!-- 3D text below --%>
      <text
        x="256"
        y="210"
        text-anchor="middle"
        fill="#808080"
        font-size="14"
        font-family="'Courier New',monospace"
      >
        3D
      </text>
      <%!-- Crossed swords behind shield --%>
      <line x1="170" y1="80" x2="342" y2="260" stroke="#606060" stroke-width="3" />
      <line x1="342" y1="80" x2="170" y2="260" stroke="#606060" stroke-width="3" />
      <%!-- Title --%>
      <text
        x="256"
        y="295"
        text-anchor="middle"
        fill="#c0c0c0"
        font-size="18"
        font-family="'Courier New',monospace"
        font-weight="bold"
      >
        WOLFENSTEIN 3D
      </text>
      <%!-- Subtitle --%>
      <text
        x="256"
        y="315"
        text-anchor="middle"
        fill="#808080"
        font-size="11"
        font-family="'Courier New',monospace"
      >
        ECWolf WebAssembly
      </text>
    </svg>
    """
  end
end
