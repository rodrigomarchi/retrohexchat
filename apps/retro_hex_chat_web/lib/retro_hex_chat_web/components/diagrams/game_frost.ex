defmodule RetroHexChatWeb.Components.Diagrams.GameFrost do
  @moduledoc "SVG game screen diagram for Hex Frost."
  use Phoenix.Component
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.Diagrams.GameScreens, only: [win98_chrome: 1]

  attr :class, :string, default: nil

  @spec diagram_game_frost(map()) :: Phoenix.LiveView.Rendered.t()
  def diagram_game_frost(assigns) do
    ~H"""
    <svg
      class={@class}
      viewBox="0 0 520 360"
      shape-rendering="crispEdges"
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-label={gettext("Hex Frost game screen: ice blocks floating on water with igloos on shore")}
    >
      {win98_chrome("Hex Frost")}
      <%!-- Shore (top) --%>
      <rect x="8" y="24" width="496" height="50" fill="#1a3a5a" />
      <%!-- P1 igloo (left) --%>
      <rect x="30" y="40" width="30" height="20" fill="#ddf" />
      <polygon points="30,40 45,28 60,40" fill="#eef" />
      <%!-- P2 igloo (right, partially built) --%>
      <rect x="440" y="46" width="30" height="14" fill="#ddf" opacity="0.5" />
      <%!-- Water --%>
      <rect x="8" y="74" width="496" height="268" fill="#001840" />
      <%!-- Ice block rows (4 rows) --%>
      <%= for col <- 0..6 do %>
        <rect x={24 + col * 66} y="100" width="48" height="12" fill="#88ccff" />
        <rect x={50 + col * 66} y="160" width="48" height="12" fill="#88ccff" />
        <rect x={24 + col * 66} y="220" width="48" height="12" fill="#88ccff" />
        <rect x={50 + col * 66} y="280" width="48" height="12" fill="#88ccff" />
      <% end %>
      <%!-- Some claimed blocks (blue for P1, cyan for P2) --%>
      <rect x="90" y="100" width="48" height="12" fill="#0066ff" />
      <rect x="222" y="100" width="48" height="12" fill="#0066ff" />
      <rect x="182" y="160" width="48" height="12" fill="#00ccff" />
      <%!-- P1 player (on an ice block) --%>
      <rect x="160" y="92" width="6" height="8" fill="#00ff41" />
      <%!-- P2 player (on a different row) --%>
      <rect x="320" y="272" width="6" height="8" fill="#00d4ff" />
      <%!-- Polar bear on shore --%>
      <rect x="240" y="50" width="10" height="8" fill="#fff" />
      <%!-- Temperature --%>
      <text x="220" y="44" fill="#ffaa00" font-size="10" font-family="'Courier New',monospace">
        {gettext("32° R2")}
      </text>
      <text x="30" y="340" fill="#00ff41" font-size="10" font-family="'Courier New',monospace">
        {gettext("P1: 8/15")}
      </text>
      <text x="420" y="340" fill="#00d4ff" font-size="10" font-family="'Courier New',monospace">
        {gettext("P2: 5/15")}
      </text>
    </svg>
    """
  end
end
