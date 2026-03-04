defmodule RetroHexChatWeb.Components.Diagrams.ArcadeDoom do
  @moduledoc """
  SVG logo/cover art for the DOOM arcade help page.
  """
  use Phoenix.Component

  import RetroHexChatWeb.Components.Diagrams.GameScreens, only: [win98_chrome: 1]

  attr :class, :string, default: nil

  @spec diagram_arcade_doom(map()) :: Phoenix.LiveView.Rendered.t()
  def diagram_arcade_doom(assigns) do
    ~H"""
    <svg
      class={@class}
      viewBox="0 0 520 360"
      shape-rendering="crispEdges"
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-label="DOOM arcade logo: bold red angular letters on dark background"
    >
      {win98_chrome("DOOM - Arcade")}
      <%!-- Background gradient effect --%>
      <rect x="7" y="23" width="498" height="324" fill="#1a0000" />
      <%!-- Flame effect at bottom --%>
      <%= for i <- 0..49 do %>
        <rect
          x={7 + i * 10}
          y={300 - rem(i * 7 + 3, 20)}
          width="10"
          height={47 + rem(i * 7 + 3, 20)}
          fill={
            if rem(i, 3) == 0, do: "#8b0000", else: if(rem(i, 3) == 1, do: "#cc3300", else: "#ff6600")
          }
          opacity="0.4"
        />
      <% end %>
      <%!-- DOOM letters - blocky pixel style --%>
      <%!-- D --%>
      <rect x="100" y="100" width="16" height="120" fill="#cc0000" />
      <rect x="116" y="100" width="16" height="16" fill="#cc0000" />
      <rect x="132" y="100" width="16" height="16" fill="#cc0000" />
      <rect x="148" y="116" width="16" height="16" fill="#cc0000" />
      <rect x="148" y="132" width="16" height="56" fill="#cc0000" />
      <rect x="148" y="188" width="16" height="16" fill="#cc0000" />
      <rect x="132" y="204" width="16" height="16" fill="#cc0000" />
      <rect x="116" y="204" width="16" height="16" fill="#cc0000" />
      <%!-- O (first) --%>
      <rect x="180" y="116" width="16" height="16" fill="#cc0000" />
      <rect x="196" y="100" width="32" height="16" fill="#cc0000" />
      <rect x="228" y="116" width="16" height="16" fill="#cc0000" />
      <rect x="180" y="132" width="16" height="56" fill="#cc0000" />
      <rect x="228" y="132" width="16" height="56" fill="#cc0000" />
      <rect x="180" y="188" width="16" height="16" fill="#cc0000" />
      <rect x="196" y="204" width="32" height="16" fill="#cc0000" />
      <rect x="228" y="188" width="16" height="16" fill="#cc0000" />
      <%!-- O (second) --%>
      <rect x="260" y="116" width="16" height="16" fill="#cc0000" />
      <rect x="276" y="100" width="32" height="16" fill="#cc0000" />
      <rect x="308" y="116" width="16" height="16" fill="#cc0000" />
      <rect x="260" y="132" width="16" height="56" fill="#cc0000" />
      <rect x="308" y="132" width="16" height="56" fill="#cc0000" />
      <rect x="260" y="188" width="16" height="16" fill="#cc0000" />
      <rect x="276" y="204" width="32" height="16" fill="#cc0000" />
      <rect x="308" y="188" width="16" height="16" fill="#cc0000" />
      <%!-- M --%>
      <rect x="340" y="100" width="16" height="120" fill="#cc0000" />
      <rect x="356" y="116" width="16" height="16" fill="#cc0000" />
      <rect x="372" y="132" width="16" height="16" fill="#cc0000" />
      <rect x="388" y="116" width="16" height="16" fill="#cc0000" />
      <rect x="404" y="100" width="16" height="120" fill="#cc0000" />
      <%!-- Highlight edges --%>
      <rect x="100" y="100" width="64" height="4" fill="#ff3333" />
      <rect x="180" y="100" width="64" height="4" fill="#ff3333" />
      <rect x="260" y="100" width="64" height="4" fill="#ff3333" />
      <rect x="340" y="100" width="80" height="4" fill="#ff3333" />
      <%!-- Subtitle --%>
      <text
        x="256"
        y="260"
        text-anchor="middle"
        fill="#808080"
        font-size="11"
        font-family="'Courier New',monospace"
      >
        PrBoom+ WebAssembly
      </text>
      <%!-- Pentagram star (simplified) --%>
      <polygon
        points="256,270 260,282 274,282 263,290 267,302 256,294 245,302 249,290 238,282 252,282"
        fill="#8b0000"
        opacity="0.6"
      />
    </svg>
    """
  end
end
