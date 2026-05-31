defmodule RetroHexChatWeb.Components.Diagrams.Security do
  @moduledoc """
  Security-related SVG diagrams: encryption layers and protocol illustrations.
  """
  use Phoenix.Component
  use Gettext, backend: RetroHexChatWeb.Gettext

  # ──────────────────────────────────────────────────
  # Security Layers Diagram (how_it_works — tab-security)
  # ──────────────────────────────────────────────────

  attr :class, :string, default: nil

  @spec diagram_security_layers(map()) :: Phoenix.LiveView.Rendered.t()
  def diagram_security_layers(assigns) do
    ~H"""
    <svg
      class={@class}
      viewBox="0 0 520 290"
      shape-rendering="crispEdges"
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-label={
        dgettext(
          "diagrams",
          "Two security layers: browser to server via HTTPS/WSS with TLS, and browser to browser via DTLS-SRTP for P2P calls"
        )
      }
    >
      <!-- Common Window styles -->

      <!-- Layer 1 label -->
      <text
        x="260"
        y="20"
        text-anchor="middle"
        fill="#000"
        font-size="12"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        {dgettext("diagrams", "LAYER 1 — Server Connection")}
      </text>
      
    <!-- Browser box (left) -->
      <!-- Shadow -->
      <rect x="34" y="34" width="120" height="50" fill="#000" />
      <!-- Window Background -->
      <rect x="30" y="30" width="120" height="50" fill="#c0c0c0" stroke="#000" stroke-width="1" />
      <polyline points="31,79 31,31 149,31" fill="none" stroke="#fff" stroke-width="1" />
      <polyline points="149,32 149,79 31,79" fill="none" stroke="#808080" stroke-width="1" />
      
    <!-- Title bar -->
      <rect x="33" y="33" width="114" height="18" fill="#000080" />
      <text
        x="90"
        y="46"
        text-anchor="middle"
        fill="#fff"
        font-size="11"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        {dgettext("diagrams", "Browser")}
      </text>
      
    <!-- Inside lock area -->
      <rect x="74" y="55" width="12" height="10" fill="#008080" stroke="#000" stroke-width="1" />
      <!-- Lock hoop -->
      <path d="M77 55 v-3 h6 v3" fill="none" stroke="#000" stroke-width="1.5" />
      <path d="M78 55 v-2 h4 v2" fill="none" stroke="#fff" stroke-width="1" />
      <text
        x="96"
        y="64"
        text-anchor="start"
        fill="#000"
        font-size="10"
        font-family="Tahoma,sans-serif"
      >
        {dgettext("diagrams", "TLS 1.3")}
      </text>
      
    <!-- Server box (right) -->
      <!-- Shadow -->
      <rect x="374" y="34" width="120" height="50" fill="#000" />
      <!-- Window Background -->
      <rect x="370" y="30" width="120" height="50" fill="#c0c0c0" stroke="#000" stroke-width="1" />
      <polyline points="371,79 371,31 489,31" fill="none" stroke="#fff" stroke-width="1" />
      <polyline points="489,32 489,79 371,79" fill="none" stroke="#808080" stroke-width="1" />
      
    <!-- Title bar -->
      <rect x="373" y="33" width="114" height="18" fill="#000080" />
      <text
        x="430"
        y="46"
        text-anchor="middle"
        fill="#fff"
        font-size="11"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        {dgettext("diagrams", "Server")}
      </text>
      
    <!-- Shield icon -->
      <path d="M422 55 h10 v6 l-5 5 l-5 -5 z" fill="#008080" stroke="#000" stroke-width="1" />
      <path d="M423 56 h8 v5 l-4 4 l-4 -4 z" fill="none" stroke="#fff" stroke-width="1" />
      <text
        x="438"
        y="64"
        text-anchor="start"
        fill="#000"
        font-size="10"
        font-family="Tahoma,sans-serif"
      >
        {dgettext("diagrams", "Protected")}
      </text>
      
    <!-- HTTPS/WSS connection line -->
      <rect x="156" y="54" width="208" height="4" fill="#000" />
      <path d="M152 56 l8 -6 v12 z" fill="#000" />
      <path d="M368 56 l-8 -6 v12 z" fill="#000" />
      
    <!-- Inner line accent -->
      <rect x="160" y="55" width="200" height="2" fill="#008080" />
      <path d="M154 56 l6 -4 v8 z" fill="#008080" />
      <path d="M366 56 l-6 -4 v8 z" fill="#008080" />
      
    <!-- Protocol label inset -->
      <rect x="220" y="45" width="80" height="18" fill="#008080" stroke="#000" stroke-width="1" />
      <polyline points="221,62 221,46 299,46" fill="none" stroke="#005500" stroke-width="1" />
      <polyline points="299,47 299,62 221,62" fill="none" stroke="#00ff00" stroke-width="1" />
      <text
        x="260"
        y="58"
        text-anchor="middle"
        fill="#fff"
        font-size="10"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        {dgettext("diagrams", "HTTPS / WSS")}
      </text>
      
    <!-- Server features (Tooltip style) -->
      <rect x="374" y="90" width="120" height="44" fill="#ffffcc" stroke="#000" stroke-width="1" />
      <polyline points="375,133 375,91 493,91" fill="none" stroke="#fff" stroke-width="1" />
      <polyline points="493,92 493,133 375,133" fill="none" stroke="#808080" stroke-width="1" />
      <text
        x="434"
        y="103"
        text-anchor="middle"
        fill="#000"
        font-size="10"
        font-family="Tahoma,sans-serif"
      >
        {dgettext("diagrams", "· bcrypt hashing")}
      </text>
      <text
        x="434"
        y="115"
        text-anchor="middle"
        fill="#000"
        font-size="10"
        font-family="Tahoma,sans-serif"
      >
        {dgettext("diagrams", "· rate limiting")}
      </text>
      <text
        x="434"
        y="127"
        text-anchor="middle"
        fill="#000"
        font-size="10"
        font-family="Tahoma,sans-serif"
      >
        {dgettext("diagrams", "· CSRF protection")}
      </text>
      
    <!-- Separator line (engraved style) -->
      <line
        x1="10"
        y1="145"
        x2="510"
        y2="145"
        stroke="#808080"
        stroke-width="1"
        stroke-dasharray="4,4"
      />
      <line x1="10" y1="146" x2="510" y2="146" stroke="#fff" stroke-width="1" stroke-dasharray="4,4" />
      
    <!-- Layer 2 label -->
      <text
        x="260"
        y="170"
        text-anchor="middle"
        fill="#000"
        font-size="12"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        {dgettext("diagrams", "LAYER 2 — P2P Calls (end-to-end)")}
      </text>
      
    <!-- Browser box (left, Bottom) -->
      <rect x="34" y="184" width="120" height="50" fill="#000" />
      <rect x="30" y="180" width="120" height="50" fill="#c0c0c0" stroke="#000" stroke-width="1" />
      <polyline points="31,229 31,181 149,181" fill="none" stroke="#fff" stroke-width="1" />
      <polyline points="149,182 149,229 31,229" fill="none" stroke="#808080" stroke-width="1" />

      <rect x="33" y="183" width="114" height="18" fill="#000080" />
      <text
        x="90"
        y="196"
        text-anchor="middle"
        fill="#fff"
        font-size="11"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        {dgettext("diagrams", "Browser")}
      </text>

      <rect x="54" y="205" width="12" height="10" fill="#008080" stroke="#000" stroke-width="1" />
      <path d="M57 205 v-3 h6 v3" fill="none" stroke="#000" stroke-width="1.5" />
      <path d="M58 205 v-2 h4 v2" fill="none" stroke="#fff" stroke-width="1" />
      <text
        x="74"
        y="214"
        text-anchor="start"
        fill="#000"
        font-size="10"
        font-family="Tahoma,sans-serif"
      >
        {dgettext("diagrams", "E2E enc")}
      </text>
      
    <!-- Browser box (right, Bottom) -->
      <rect x="374" y="184" width="120" height="50" fill="#000" />
      <rect x="370" y="180" width="120" height="50" fill="#c0c0c0" stroke="#000" stroke-width="1" />
      <polyline points="371,229 371,181 489,181" fill="none" stroke="#fff" stroke-width="1" />
      <polyline points="489,182 489,229 371,229" fill="none" stroke="#808080" stroke-width="1" />

      <rect x="373" y="183" width="114" height="18" fill="#000080" />
      <text
        x="430"
        y="196"
        text-anchor="middle"
        fill="#fff"
        font-size="11"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        {dgettext("diagrams", "Browser")}
      </text>

      <rect x="394" y="205" width="12" height="10" fill="#008080" stroke="#000" stroke-width="1" />
      <path d="M397 205 v-3 h6 v3" fill="none" stroke="#000" stroke-width="1.5" />
      <path d="M398 205 v-2 h4 v2" fill="none" stroke="#fff" stroke-width="1" />
      <text
        x="414"
        y="214"
        text-anchor="start"
        fill="#000"
        font-size="10"
        font-family="Tahoma,sans-serif"
      >
        {dgettext("diagrams", "E2E enc")}
      </text>
      
    <!-- DTLS-SRTP connection line -->
      <rect x="156" y="204" width="208" height="4" fill="#000" />
      <path d="M152 206 l8 -6 v12 z" fill="#000" />
      <path d="M368 206 l-8 -6 v12 z" fill="#000" />

      <rect x="160" y="205" width="200" height="2" fill="#008080" />
      <path d="M154 206 l6 -4 v8 z" fill="#008080" />
      <path d="M366 206 l-6 -4 v8 z" fill="#008080" />
      
    <!-- Protocol label inset -->
      <rect x="220" y="195" width="80" height="18" fill="#008080" stroke="#000" stroke-width="1" />
      <polyline points="221,212 221,196 299,196" fill="none" stroke="#005500" stroke-width="1" />
      <polyline points="299,197 299,212 221,212" fill="none" stroke="#00ff00" stroke-width="1" />
      <text
        x="260"
        y="208"
        text-anchor="middle"
        fill="#fff"
        font-size="10"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        {dgettext("diagrams", "DTLS / SRTP")}
      </text>
      
    <!-- P2P description -->
      <!-- Tooltip container -->
      <rect x="140" y="240" width="240" height="34" fill="#ffffcc" stroke="#000" stroke-width="1" />
      <polyline points="141,273 141,241 379,241" fill="none" stroke="#fff" stroke-width="1" />
      <polyline points="379,242 379,273 141,273" fill="none" stroke="#808080" stroke-width="1" />
      <text
        x="260"
        y="254"
        text-anchor="middle"
        fill="#000"
        font-size="10"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        {dgettext("diagrams", "P2P calls encrypted end-to-end via WebRTC")}
      </text>
      <text
        x="260"
        y="268"
        text-anchor="middle"
        fill="#444"
        font-size="10"
        font-family="Tahoma,sans-serif"
      >
        {dgettext("diagrams", "Server never sees voice/video data")}
      </text>
    </svg>
    """
  end
end
