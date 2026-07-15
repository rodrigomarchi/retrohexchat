defmodule RetroHexChatWeb.Components.Diagrams.ConferenceTopology do
  @moduledoc "SVG diagram for channel conference topology and controls."
  use Phoenix.Component
  use Gettext, backend: RetroHexChatWeb.Gettext

  attr :class, :string, default: nil

  @spec diagram_conference_topology(map()) :: Phoenix.LiveView.Rendered.t()
  def diagram_conference_topology(assigns) do
    ~H"""
    <svg
      class={@class}
      viewBox="0 0 520 320"
      shape-rendering="crispEdges"
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-label={
        dgettext(
          "diagrams",
          "Channel conference topology diagram showing channel members joining a self-hosted SFU with moderation, screen sharing, layouts, reactions, and statistics"
        )
      }
    >
      <rect x="24" y="18" width="472" height="284" fill="#000" />
      <rect x="20" y="14" width="472" height="284" fill="#c0c0c0" stroke="#000" stroke-width="1" />
      <polyline points="21,297 21,15 491,15" fill="none" stroke="#fff" stroke-width="1" />
      <polyline points="491,16 491,297 21,297" fill="none" stroke="#808080" stroke-width="1" />
      <rect x="24" y="18" width="464" height="20" fill="#000080" />
      <text
        x="256"
        y="32"
        text-anchor="middle"
        fill="#fff"
        font-size="11"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        {dgettext("diagrams", "Conference: channel media on your infrastructure")}
      </text>

      <%!-- channel membership gate --%>
      <rect x="40" y="56" width="132" height="82" fill="#dfdfdf" stroke="#000" />
      <polyline points="41,137 41,57 171,57" fill="none" stroke="#808080" stroke-width="1" />
      <polyline points="171,58 171,137 41,137" fill="none" stroke="#fff" stroke-width="1" />
      <rect x="46" y="62" width="120" height="18" fill="#000080" />
      <text
        x="106"
        y="75"
        text-anchor="middle"
        fill="#fff"
        font-size="10"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        # dev-room
      </text>
      <text x="52" y="100" fill="#000" font-size="10" font-family="Tahoma,sans-serif">
        {dgettext("diagrams", "members only")}
      </text>
      <text x="52" y="118" fill="#000" font-size="10" font-family="Tahoma,sans-serif">
        {dgettext("diagrams", "channel roles")}
      </text>

      <%!-- self-hosted SFU --%>
      <rect x="210" y="86" width="116" height="92" fill="#000" />
      <rect x="204" y="80" width="116" height="92" fill="#c0c0c0" stroke="#000" />
      <polyline points="205,171 205,81 319,81" fill="none" stroke="#fff" stroke-width="1" />
      <polyline points="319,82 319,171 205,171" fill="none" stroke="#808080" stroke-width="1" />
      <rect x="210" y="86" width="104" height="18" fill="#008080" />
      <text
        x="262"
        y="99"
        text-anchor="middle"
        fill="#fff"
        font-size="10"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        {dgettext("diagrams", "Self-hosted SFU")}
      </text>
      <rect x="224" y="118" width="76" height="12" fill="#00ff41" stroke="#000" />
      <rect x="224" y="138" width="76" height="12" fill="#00d4ff" stroke="#000" />
      <text
        x="262"
        y="164"
        text-anchor="middle"
        fill="#000"
        font-size="9"
        font-family="Tahoma,sans-serif"
      >
        {dgettext("diagrams", "routes streams")}
      </text>

      <%!-- participant tiles --%>
      <g fill="#dfdfdf" stroke="#000">
        <rect x="378" y="52" width="92" height="62" />
        <rect x="378" y="130" width="92" height="62" />
        <rect x="378" y="208" width="92" height="62" />
      </g>
      <g fill="none" stroke="#fff">
        <polyline points="379,113 379,53 469,53" />
        <polyline points="379,191 379,131 469,131" />
        <polyline points="379,269 379,209 469,209" />
      </g>
      <g fill="none" stroke="#808080">
        <polyline points="469,54 469,113 379,113" />
        <polyline points="469,132 469,191 379,191" />
        <polyline points="469,210 469,269 379,269" />
      </g>
      <rect x="384" y="58" width="80" height="28" fill="#20232b" />
      <circle cx="404" cy="72" r="8" fill="#00d4ff" />
      <text x="424" y="76" fill="#fff" font-size="10" font-family="Tahoma,sans-serif">Ana</text>
      <rect x="388" y="92" width="16" height="12" fill="#00aa00" stroke="#000" />
      <rect x="410" y="92" width="16" height="12" fill="#00aa00" stroke="#000" />
      <rect x="432" y="92" width="16" height="12" fill="#ffaa00" stroke="#000" />

      <rect x="384" y="136" width="80" height="28" fill="#20232b" />
      <circle cx="404" cy="150" r="8" fill="#ff66cc" />
      <text x="424" y="154" fill="#fff" font-size="10" font-family="Tahoma,sans-serif">Mika</text>
      <rect x="388" y="170" width="16" height="12" fill="#00aa00" stroke="#000" />
      <rect x="410" y="170" width="16" height="12" fill="#808080" stroke="#000" />
      <rect x="432" y="170" width="16" height="12" fill="#00d4ff" stroke="#000" />

      <rect x="384" y="214" width="80" height="28" fill="#20232b" />
      <circle cx="404" cy="228" r="8" fill="#ffe169" />
      <text x="424" y="232" fill="#fff" font-size="10" font-family="Tahoma,sans-serif">Rio</text>
      <rect x="388" y="248" width="16" height="12" fill="#808080" stroke="#000" />
      <rect x="410" y="248" width="16" height="12" fill="#00aa00" stroke="#000" />
      <rect x="432" y="248" width="16" height="12" fill="#ff6666" stroke="#000" />

      <%!-- media routes --%>
      <g stroke="#008080" stroke-width="5" fill="none">
        <path d="M172 98 H204" />
        <path d="M320 112 C346 92 354 82 378 82" />
        <path d="M320 130 C348 138 352 154 378 160" />
        <path d="M320 150 C346 184 352 224 378 238" />
      </g>
      <g stroke="#00d4ff" stroke-width="2" fill="none" stroke-dasharray="6,4">
        <path d="M204 116 H172" />
        <path d="M378 92 C354 94 346 104 320 118" />
        <path d="M378 170 C352 162 348 146 320 134" />
        <path d="M378 248 C352 226 346 188 320 154" />
      </g>
      <path d="M188 90 L204 98 L188 106 Z" fill="#008080" stroke="#000" />

      <%!-- operator controls --%>
      <rect x="40" y="166" width="132" height="86" fill="#dfdfdf" stroke="#000" />
      <rect x="46" y="172" width="120" height="18" fill="#800000" />
      <text
        x="106"
        y="185"
        text-anchor="middle"
        fill="#fff"
        font-size="10"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        {dgettext("diagrams", "Operator controls")}
      </text>
      <text x="52" y="208" fill="#000" font-size="9" font-family="Tahoma,sans-serif">
        {dgettext("diagrams", "lock room")}
      </text>
      <text x="52" y="224" fill="#000" font-size="9" font-family="Tahoma,sans-serif">
        {dgettext("diagrams", "mute / camera off")}
      </text>
      <text x="52" y="240" fill="#000" font-size="9" font-family="Tahoma,sans-serif">
        {dgettext("diagrams", "remove participant")}
      </text>

      <rect x="202" y="220" width="126" height="46" fill="#dfdfdf" stroke="#000" />
      <text
        x="265"
        y="238"
        text-anchor="middle"
        fill="#000080"
        font-size="10"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        {dgettext("diagrams", "Stats + layouts")}
      </text>
      <rect x="214" y="248" width="28" height="10" fill="#00aa00" stroke="#000" />
      <rect x="248" y="248" width="28" height="10" fill="#ffaa00" stroke="#000" />
      <rect x="282" y="248" width="28" height="10" fill="#00d4ff" stroke="#000" />
    </svg>
    """
  end
end
