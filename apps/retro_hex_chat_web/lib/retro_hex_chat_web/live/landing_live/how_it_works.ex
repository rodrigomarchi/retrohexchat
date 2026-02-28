defmodule RetroHexChatWeb.LandingLive.HowItWorks do
  @moduledoc false
  use Phoenix.LiveView

  import RetroHexChatWeb.LandingLive.LandingHelpers
  import RetroHexChatWeb.Components.UI.Window
  import RetroHexChatWeb.Components.UI.Tabs
  import RetroHexChatWeb.Components.Diagrams

  alias RetroHexChatWeb.Icons

  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       active_page: :how_it_works,
       page_title: "How Retro Hex Chat Works — Server, P2P, Privacy & Security",
       page_description:
         "Learn how Retro Hex Chat works: self-hosted server architecture, WebRTC P2P calls, privacy protections, and security layers."
     )}
  end

  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <.landing_layout active_page={@active_page}>
      <section class="m-4" aria-labelledby="how-it-works-heading">
        <.window>
          <.window_title_bar title="How it works" controls={[:close]}>
            <:icon><Icons.icon_server class="w-4 h-4" /></:icon>
          </.window_title_bar>
          <.window_body>
            <h2 id="how-it-works-heading" class="sr-only">How It Works</h2>

            <.tabs :let={builder} id="how-tabs" default="server">
              <.tabs_list>
                <.tabs_trigger builder={builder} value="server">
                  <:icon><Icons.icon_server class="w-4 h-4" /></:icon>
                  Your Server
                </.tabs_trigger>
                <.tabs_trigger builder={builder} value="p2p">
                  <:icon><Icons.icon_p2p class="w-4 h-4" /></:icon>
                  P2P
                </.tabs_trigger>
                <.tabs_trigger builder={builder} value="privacy">
                  <:icon><Icons.icon_shield class="w-4 h-4" /></:icon>
                  Privacy
                </.tabs_trigger>
                <.tabs_trigger builder={builder} value="security">
                  <:icon><Icons.icon_security class="w-4 h-4" /></:icon>
                  Security
                </.tabs_trigger>
              </.tabs_list>

              <.tabs_content value="server">
                <h3 class="text-sm font-bold mb-2">One server. Fully yours.</h3>
                <div class="grid sm:grid-cols-3 gap-2 mb-3">
                  <div class="shadow-retro-field bg-white p-2 text-xs">
                    <strong><Icons.icon_database class="w-4 h-4 inline" /> Your database</strong>
                    <br /> Messages, users, channels &mdash; all stored on your machine.
                  </div>
                  <div class="shadow-retro-field bg-white p-2 text-xs">
                    <strong><Icons.icon_rules class="w-4 h-4 inline" /> Your rules</strong>
                    <br /> You decide who joins, what channels exist, and how moderation works.
                  </div>
                  <div class="shadow-retro-field bg-white p-2 text-xs">
                    <strong><Icons.icon_backup class="w-4 h-4 inline" /> Your backups</strong>
                    <br /> Export, restore, migrate &mdash; your data is always accessible.
                  </div>
                </div>
                <p class="text-sm mb-1">
                  Anyone can run a server. Install it on a $5/month VPS,
                  a Raspberry Pi, or your own hardware. You control everything.
                </p>
                <p class="text-sm">
                  <strong>Public:</strong> open to anyone who wants to join.<br />
                  <strong>Private:</strong> invite-only, for your company or group.
                </p>
              </.tabs_content>

              <.tabs_content value="p2p">
                <h3 class="text-sm font-bold mb-2">Direct connections via WebRTC.</h3>
                <div
                  class="shadow-retro-field bg-white p-3 mb-2"
                  aria-label="WebRTC signaling and data flow diagram"
                >
                  <.diagram_p2p_flow class="w-full max-w-lg mx-auto" />
                </div>
                <p class="text-sm mb-1">
                  The server only handles <strong>signaling</strong> &mdash;
                  helping users find each other. Once connected, all data flows
                  directly between browsers via WebRTC.
                </p>
                <p class="text-sm">
                  If a direct connection isn&rsquo;t possible (strict firewalls),
                  a <strong>TURN relay</strong> is used as fallback &mdash;
                  still encrypted end-to-end.
                </p>
              </.tabs_content>

              <.tabs_content value="privacy">
                <h3 class="text-sm font-bold mb-2">Big Tech vs. Retro Hex Chat.</h3>
                <div class="shadow-retro-field bg-white p-2 mb-2 overflow-x-auto">
                  <table class="w-full text-xs border-collapse">
                    <thead>
                      <tr>
                        <th class="text-left p-1 border-b border-gray-400"></th>
                        <th class="text-left p-1 border-b border-gray-400">Big Tech</th>
                        <th class="text-left p-1 border-b border-gray-400">Retro Hex Chat</th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr>
                        <td class="p-1 border-b border-gray-200"><strong>Messages</strong></td>
                        <td class="p-1 border-b border-gray-200">
                          Stored on their servers, mined for ads
                        </td>
                        <td class="p-1 border-b border-gray-200">
                          Stored on YOUR server, never leaves
                        </td>
                      </tr>
                      <tr>
                        <td class="p-1 border-b border-gray-200"><strong>Calls</strong></td>
                        <td class="p-1 border-b border-gray-200">
                          Routed through corporate infrastructure
                        </td>
                        <td class="p-1 border-b border-gray-200">
                          Direct P2P &mdash; server never sees them
                        </td>
                      </tr>
                      <tr>
                        <td class="p-1 border-b border-gray-200"><strong>Your data</strong></td>
                        <td class="p-1 border-b border-gray-200">
                          Trains their AI, sold to advertisers
                        </td>
                        <td class="p-1 border-b border-gray-200">
                          Stays in your database, period
                        </td>
                      </tr>
                      <tr>
                        <td class="p-1 border-b border-gray-200"><strong>Code</strong></td>
                        <td class="p-1 border-b border-gray-200">
                          Closed source &mdash; trust us
                        </td>
                        <td class="p-1 border-b border-gray-200">
                          Open source &mdash; verify yourself
                        </td>
                      </tr>
                      <tr>
                        <td class="p-1"><strong>Control</strong></td>
                        <td class="p-1">They can ban you anytime</td>
                        <td class="p-1">You own the server &mdash; nobody can</td>
                      </tr>
                    </tbody>
                  </table>
                </div>
                <p class="text-sm">
                  No tracking. No profiling. No algorithms.
                  Your conversations are <strong>your business</strong>.
                </p>
              </.tabs_content>

              <.tabs_content value="security">
                <h3 class="text-sm font-bold mb-2">Security at every layer.</h3>
                <div class="shadow-retro-field bg-white p-3 mb-2" aria-label="Security layers diagram">
                  <.diagram_security_layers class="w-full max-w-lg mx-auto" />
                </div>
                <p class="text-sm">
                  <strong>Server connection:</strong> HTTPS and WSS with TLS encryption.<br />
                  <strong>P2P calls:</strong> DTLS-SRTP encryption built into WebRTC.<br />
                  <strong>Passwords:</strong> bcrypt hashing, never stored in plain text.<br />
                  <strong>Open source:</strong> anyone can audit the code. No backdoors.
                </p>
              </.tabs_content>
            </.tabs>
          </.window_body>
          <.window_status_bar>
            <.window_status_bar_field grow>4 concepts</.window_status_bar_field>
            <.window_status_bar_field>~2 min read</.window_status_bar_field>
          </.window_status_bar>
        </.window>
      </section>
    </.landing_layout>
    """
  end
end
