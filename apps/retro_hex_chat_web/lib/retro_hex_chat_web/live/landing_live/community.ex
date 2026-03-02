defmodule RetroHexChatWeb.LandingLive.Community do
  @moduledoc false
  use Phoenix.LiveView

  import RetroHexChatWeb.LandingLive.LandingHelpers
  import RetroHexChatWeb.Components.UI.Window

  alias RetroHexChatWeb.Icons

  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       active_page: :community,
       page_title: "Open Source & Community — Retro Hex Chat",
       page_description:
         "Retro Hex Chat is MIT-licensed open source software. Contribute, star, share, or sponsor the project on GitHub."
     )}
  end

  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <.landing_layout active_page={@active_page}>
      <section class="m-4" aria-labelledby="community-heading">
        <h2 id="community-heading" class="sr-only">Community</h2>

        <div class="grid md:grid-cols-2 gap-4 mb-4">
          <%!-- ══════════════ OPEN SOURCE ══════════════ --%>
          <.window>
            <.window_title_bar title="Open Source" controls={[:close]}>
              <:icon><Icons.icon_code class="w-4 h-4" /></:icon>
            </.window_title_bar>
            <.window_body>
              <h3 class="text-lg font-bold mb-2">
                Open code. Open community.
              </h3>

              <div class="shadow-retro-field bg-white p-3 mb-3 text-sm">
                <p class="mb-1">
                  <strong>Repository:</strong>
                  <a
                    href="https://github.com/rodrigomarchi/retro_hex_chat"
                    target="_blank"
                    rel="noopener"
                  >
                    github.com/rodrigomarchi/retro_hex_chat
                  </a>
                </p>
                <p><strong>License:</strong> MIT</p>
              </div>

              <p class="text-sm">
                Contributions are welcome! See the <a
                  href="https://github.com/rodrigomarchi/retro_hex_chat/blob/main/CONTRIBUTING.md"
                  target="_blank"
                  rel="noopener"
                >contributing guide</a>.
              </p>
            </.window_body>
            <.window_status_bar>
              <.window_status_bar_field grow>MIT License</.window_status_bar_field>
              <.window_status_bar_field>Contribute!</.window_status_bar_field>
            </.window_status_bar>
          </.window>

          <%!-- ══════════════ SUPPORT ══════════════ --%>
          <.window>
            <.window_title_bar title="Support the Project" controls={[:close]}>
              <:icon><Icons.icon_heart class="w-4 h-4" /></:icon>
            </.window_title_bar>
            <.window_body>
              <h3 class="text-lg font-bold mb-2">
                Help keep Retro Hex Chat alive.
              </h3>

              <p class="text-sm mb-3">
                Retro Hex Chat is 100% volunteer-driven. No investors, no ads, no data collection.
                If you believe in this project, consider supporting it:
              </p>

              <div class="space-y-3">
                <div class="shadow-retro-field bg-white p-3">
                  <p class="text-sm font-bold mb-2">GitHub Sponsors</p>
                  <p class="text-sm mb-2">
                    Support directly on GitHub with monthly or one-time sponsorship.
                  </p>
                  <a
                    href="https://github.com/sponsors/rodrigomarchi"
                    target="_blank"
                    rel="noopener"
                    class="no-underline"
                  >
                    <button
                      type="button"
                      class="inline-flex items-center gap-1 h-8 px-3 text-xs shadow-retro-raised bg-surface active:shadow-retro-sunken"
                    >
                      &#9829; Sponsor on GitHub
                    </button>
                  </a>
                </div>

                <div class="shadow-retro-field bg-white p-3">
                  <p class="text-sm font-bold mb-1">Other ways to help</p>
                  <ul class="text-sm space-y-1">
                    <li>&#11088; Star the repository</li>
                    <li>&#x1F4E2; Share with friends</li>
                    <li>&#x1F41B; Report bugs and suggest features</li>
                    <li>&#x1F4BB; Contribute code</li>
                  </ul>
                </div>
              </div>
            </.window_body>
            <.window_status_bar>
              <.window_status_bar_field grow>Thank you!</.window_status_bar_field>
            </.window_status_bar>
          </.window>
        </div>

        <%!-- ══════════════ TECH STACK ══════════════ --%>
        <.window>
          <.window_title_bar title="Tech Stack" controls={[:close]}>
            <:icon><Icons.icon_server class="w-4 h-4" /></:icon>
          </.window_title_bar>
          <.window_body>
            <div class="grid sm:grid-cols-5 gap-2">
              <div class="shadow-retro-field bg-white p-2 text-xs text-center">
                <Icons.icon_elixir class="w-6 h-6 mx-auto mb-1" />
                <strong>Backend</strong>
                <br /> Elixir, Phoenix, LiveView
              </div>
              <div class="shadow-retro-field bg-white p-2 text-xs text-center">
                <Icons.icon_postgres class="w-6 h-6 mx-auto mb-1" />
                <strong>Database</strong>
                <br /> PostgreSQL
              </div>
              <div class="shadow-retro-field bg-white p-2 text-xs text-center">
                <Icons.icon_palette class="w-6 h-6 mx-auto mb-1" />
                <strong>Frontend</strong>
                <br /> Retro CSS, Vanilla JS
              </div>
              <div class="shadow-retro-field bg-white p-2 text-xs text-center">
                <Icons.icon_websocket class="w-6 h-6 mx-auto mb-1" />
                <strong>Real-time</strong>
                <br /> Phoenix Channels
              </div>
              <div class="shadow-retro-field bg-white p-2 text-xs text-center">
                <Icons.icon_webrtc class="w-6 h-6 mx-auto mb-1" />
                <strong>P2P</strong>
                <br /> WebRTC
              </div>
            </div>
          </.window_body>
          <.window_status_bar>
            <.window_status_bar_field grow>
              <Icons.icon_checkmark class="w-3 h-3 inline" /> Open source stack
            </.window_status_bar_field>
          </.window_status_bar>
        </.window>
      </section>
    </.landing_layout>
    """
  end
end
