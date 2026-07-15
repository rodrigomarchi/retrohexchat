defmodule RetroHexChatWeb.Components.Diagrams.ChatWorkspace do
  @moduledoc "SVG diagram for the persistent chat workspace."
  use Phoenix.Component
  use Gettext, backend: RetroHexChatWeb.Gettext

  attr :class, :string, default: nil

  @spec diagram_chat_workspace(map()) :: Phoenix.LiveView.Rendered.t()
  def diagram_chat_workspace(assigns) do
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
          "Chat workspace diagram showing channels, direct messages, message history, commands, bots, presence, replies, and moderation"
        )
      }
    >
      <rect x="18" y="18" width="484" height="284" fill="#000" />
      <rect x="14" y="14" width="484" height="284" fill="#c0c0c0" stroke="#000" stroke-width="1" />
      <polyline points="15,297 15,15 497,15" fill="none" stroke="#fff" stroke-width="1" />
      <polyline points="497,16 497,297 15,297" fill="none" stroke="#808080" stroke-width="1" />

      <rect x="18" y="18" width="476" height="20" fill="#000080" />
      <text
        x="256"
        y="32"
        text-anchor="middle"
        fill="#fff"
        font-size="11"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        {dgettext("diagrams", "Chat: durable conversation layer")}
      </text>

      <%!-- left navigation --%>
      <rect x="22" y="46" width="106" height="220" fill="#dfdfdf" stroke="#000" stroke-width="1" />
      <polyline points="23,265 23,47 127,47" fill="none" stroke="#808080" stroke-width="1" />
      <polyline points="127,48 127,265 23,265" fill="none" stroke="#fff" stroke-width="1" />
      <rect x="28" y="54" width="92" height="18" fill="#000080" />
      <text
        x="34"
        y="67"
        fill="#fff"
        font-size="10"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        {dgettext("diagrams", "Channels")}
      </text>
      <text x="34" y="92" fill="#000" font-size="10" font-family="'Courier New',monospace">
        # general
      </text>
      <rect x="30" y="101" width="82" height="14" fill="#fff" stroke="#808080" stroke-width="1" />
      <text x="34" y="112" fill="#000080" font-size="10" font-family="'Courier New',monospace">
        # dev-room
      </text>
      <text x="34" y="136" fill="#000" font-size="10" font-family="'Courier New',monospace">
        # games
      </text>
      <rect x="28" y="156" width="92" height="18" fill="#808080" />
      <text
        x="34"
        y="169"
        fill="#fff"
        font-size="10"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        {dgettext("diagrams", "Direct messages")}
      </text>
      <text x="34" y="194" fill="#000" font-size="10" font-family="'Courier New',monospace">
        Ana
      </text>
      <text x="34" y="214" fill="#000" font-size="10" font-family="'Courier New',monospace">
        Mika
      </text>
      <text x="34" y="244" fill="#008000" font-size="9" font-family="Tahoma,sans-serif">
        {dgettext("diagrams", "auto-join")}
      </text>

      <%!-- message stream --%>
      <rect x="138" y="46" width="238" height="220" fill="#fff" stroke="#000" stroke-width="1" />
      <polyline points="139,265 139,47 375,47" fill="none" stroke="#808080" stroke-width="1" />
      <polyline points="375,48 375,265 139,265" fill="none" stroke="#fff" stroke-width="1" />
      <rect x="146" y="54" width="222" height="22" fill="#f0f0f0" stroke="#808080" stroke-width="1" />
      <text
        x="154"
        y="69"
        fill="#000080"
        font-size="10"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        {dgettext("diagrams", "Topic: ship the room")}
      </text>
      <text x="150" y="100" fill="#808080" font-size="9" font-family="'Courier New',monospace">
        14:02
      </text>
      <text
        x="190"
        y="100"
        fill="#000080"
        font-size="10"
        font-family="'Courier New',monospace"
        font-weight="bold"
      >
        Ana
      </text>
      <text x="224" y="100" fill="#000" font-size="10" font-family="'Courier New',monospace">
        {dgettext("diagrams", "space is live")}
      </text>
      <rect x="170" y="116" width="164" height="26" fill="#e8dcc0" stroke="#20232b" stroke-width="1" />
      <text x="180" y="133" fill="#20232b" font-size="10" font-family="Tahoma,sans-serif">
        {dgettext("diagrams", "reply thread + reaction")}
      </text>
      <text x="150" y="166" fill="#808080" font-size="9" font-family="'Courier New',monospace">
        14:03
      </text>
      <text
        x="190"
        y="166"
        fill="#800080"
        font-size="10"
        font-family="'Courier New',monospace"
        font-weight="bold"
      >
        Bot
      </text>
      <text x="224" y="166" fill="#000" font-size="10" font-family="'Courier New',monospace">
        {dgettext("diagrams", "moderation logged")}
      </text>
      <text x="150" y="196" fill="#808080" font-size="9" font-family="'Courier New',monospace">
        14:04
      </text>
      <text
        x="190"
        y="196"
        fill="#008080"
        font-size="10"
        font-family="'Courier New',monospace"
        font-weight="bold"
      >
        Mika
      </text>
      <text x="224" y="196" fill="#000" font-size="10" font-family="'Courier New',monospace">
        {dgettext("diagrams", "see you in Space")}
      </text>
      <rect x="146" y="232" width="222" height="22" fill="#dfdfdf" stroke="#000" stroke-width="1" />
      <text x="154" y="247" fill="#000" font-size="10" font-family="'Courier New',monospace">
        /topic {dgettext("diagrams", "conference at 3")}
      </text>

      <%!-- right presence/moderation rail --%>
      <rect x="386" y="46" width="96" height="220" fill="#dfdfdf" stroke="#000" stroke-width="1" />
      <polyline points="387,265 387,47 481,47" fill="none" stroke="#808080" stroke-width="1" />
      <polyline points="481,48 481,265 387,265" fill="none" stroke="#fff" stroke-width="1" />
      <rect x="394" y="54" width="80" height="18" fill="#000080" />
      <text
        x="434"
        y="67"
        text-anchor="middle"
        fill="#fff"
        font-size="10"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        {dgettext("diagrams", "Presence")}
      </text>
      <circle cx="404" cy="94" r="4" fill="#00aa00" stroke="#000" />
      <text x="416" y="98" fill="#000" font-size="10" font-family="Tahoma,sans-serif">Ana</text>
      <circle cx="404" cy="118" r="4" fill="#00aa00" stroke="#000" />
      <text x="416" y="122" fill="#000" font-size="10" font-family="Tahoma,sans-serif">Mika</text>
      <circle cx="404" cy="142" r="4" fill="#ffaa00" stroke="#000" />
      <text x="416" y="146" fill="#000" font-size="10" font-family="Tahoma,sans-serif">Rio</text>
      <rect x="394" y="172" width="80" height="60" fill="#c0c0c0" stroke="#000" />
      <text
        x="434"
        y="188"
        text-anchor="middle"
        fill="#000080"
        font-size="10"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        {dgettext("diagrams", "Controls")}
      </text>
      <text x="402" y="206" fill="#000" font-size="9" font-family="Tahoma,sans-serif">
        {dgettext("diagrams", "roles")}
      </text>
      <text x="402" y="220" fill="#000" font-size="9" font-family="Tahoma,sans-serif">
        {dgettext("diagrams", "modes")}
      </text>
      <text x="402" y="244" fill="#008000" font-size="9" font-family="Tahoma,sans-serif">
        {dgettext("diagrams", "history saved")}
      </text>

      <rect x="22" y="274" width="460" height="14" fill="#dfdfdf" stroke="#808080" />
      <text x="30" y="285" fill="#000" font-size="9" font-family="Tahoma,sans-serif">
        {dgettext("diagrams", "One persistent conversation powers chat, spaces, and conferences.")}
      </text>
    </svg>
    """
  end
end
