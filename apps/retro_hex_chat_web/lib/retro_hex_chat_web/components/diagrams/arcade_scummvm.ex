defmodule RetroHexChatWeb.Components.Diagrams.ArcadeScummvm do
  @moduledoc """
  SVG logo/cover art for the ScummVM arcade help page.
  """
  use Phoenix.Component
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.Diagrams.GameScreens, only: [win98_chrome: 1]

  attr :class, :string, default: nil

  @spec diagram_arcade_scummvm(map()) :: Phoenix.LiveView.Rendered.t()
  def diagram_arcade_scummvm(assigns) do
    ~H"""
    <svg
      class={@class}
      viewBox="0 0 520 360"
      shape-rendering="crispEdges"
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-label={
        dgettext("diagrams", "ScummVM arcade logo: point and click adventure scene with cursor")
      }
    >
      {win98_chrome("ScummVM - Arcade")}
      <%!-- Background - adventure game scene --%>
      <rect x="7" y="23" width="498" height="324" fill="#1a1a2e" />
      <%!-- Starry sky --%>
      <%= for {x, y} <- [{50, 50}, {120, 70}, {200, 40}, {300, 60}, {380, 45}, {440, 75}, {80, 90}, {350, 85}, {160, 55}, {420, 55}, {260, 38}, {480, 65}] do %>
        <rect x={x} y={y} width="2" height="2" fill="#fff" opacity="0.6" />
      <% end %>
      <%!-- Moon --%>
      <circle cx="420" cy="70" r="20" fill="#e8e8a0" />
      <circle cx="428" cy="65" r="18" fill="#1a1a2e" />
      <%!-- Castle silhouette --%>
      <rect x="100" y="150" width="30" height="100" fill="#0a0a1a" />
      <rect x="100" y="140" width="30" height="14" fill="#0a0a1a" />
      <rect x="100" y="136" width="8" height="8" fill="#0a0a1a" />
      <rect x="122" y="136" width="8" height="8" fill="#0a0a1a" />
      <rect x="130" y="170" width="80" height="80" fill="#0a0a1a" />
      <rect x="130" y="158" width="80" height="16" fill="#0a0a1a" />
      <rect x="130" y="152" width="16" height="10" fill="#0a0a1a" />
      <rect x="152" y="152" width="16" height="10" fill="#0a0a1a" />
      <rect x="178" y="152" width="16" height="10" fill="#0a0a1a" />
      <rect x="196" y="152" width="16" height="10" fill="#0a0a1a" />
      <rect x="210" y="160" width="20" height="90" fill="#0a0a1a" />
      <rect x="210" y="148" width="20" height="16" fill="#0a0a1a" />
      <rect x="210" y="142" width="8" height="10" fill="#0a0a1a" />
      <rect x="222" y="142" width="8" height="10" fill="#0a0a1a" />
      <%!-- Castle windows (lit) --%>
      <rect x="148" y="185" width="10" height="14" fill="#cc9900" opacity="0.7" />
      <rect x="178" y="185" width="10" height="14" fill="#cc9900" opacity="0.7" />
      <rect x="163" y="210" width="12" height="18" fill="#cc9900" opacity="0.5" />
      <%!-- Ground --%>
      <rect x="7" y="250" width="498" height="97" fill="#0a0a1a" />
      <%!-- Path --%>
      <polygon points="240,250 280,250 350,347 200,347" fill="#1a1a30" />
      <%!-- Point-and-click cursor --%>
      <polygon
        points="340,180 340,210 348,204 354,218 360,216 354,202 364,198"
        fill="#fff"
        stroke="#000"
        stroke-width="1"
      />
      <%!-- Verb bar at bottom --%>
      <rect x="7" y="310" width="498" height="37" fill="#2a2a4a" />
      <text
        x="60"
        y="332"
        text-anchor="middle"
        fill="#00ff00"
        font-size="10"
        font-family="'Courier New',monospace"
      >
        {dgettext("diagrams", "Open")}
      </text>
      <text
        x="130"
        y="332"
        text-anchor="middle"
        fill="#00ff00"
        font-size="10"
        font-family="'Courier New',monospace"
      >
        {dgettext("diagrams", "Close")}
      </text>
      <text
        x="200"
        y="332"
        text-anchor="middle"
        fill="#00ff00"
        font-size="10"
        font-family="'Courier New',monospace"
      >
        {dgettext("diagrams", "Give")}
      </text>
      <text
        x="270"
        y="332"
        text-anchor="middle"
        fill="#00ff00"
        font-size="10"
        font-family="'Courier New',monospace"
      >
        {dgettext("diagrams", "Pick up")}
      </text>
      <text
        x="340"
        y="332"
        text-anchor="middle"
        fill="#00ff00"
        font-size="10"
        font-family="'Courier New',monospace"
      >
        {dgettext("diagrams", "Look at")}
      </text>
      <text
        x="410"
        y="332"
        text-anchor="middle"
        fill="#00ff00"
        font-size="10"
        font-family="'Courier New',monospace"
      >
        {dgettext("diagrams", "Talk to")}
      </text>
      <text
        x="470"
        y="332"
        text-anchor="middle"
        fill="#00ff00"
        font-size="10"
        font-family="'Courier New',monospace"
      >
        {dgettext("diagrams", "Use")}
      </text>
    </svg>
    """
  end
end
