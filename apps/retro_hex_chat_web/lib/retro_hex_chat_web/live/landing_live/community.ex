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
      <%!-- ══════════════ OPEN SOURCE ══════════════ --%>
      <section class="m-4" aria-labelledby="opensource-heading">
        <.window class="mb-4">
          <.window_title_bar title="Open Source" controls={[:close]}>
            <:icon><Icons.icon_code class="w-4 h-4" /></:icon>
          </.window_title_bar>
          <.window_body>
            <h2 id="opensource-heading" class="text-lg font-bold mb-2">
              Open code. Open community.
            </h2>

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

            <div class="mb-3">
              <h3 class="text-sm font-bold mb-1">Stack</h3>
              <ul class="text-sm space-y-1">
                <li class="flex items-center gap-2">
                  <Icons.icon_elixir class="w-4 h-4 shrink-0" />
                  <span><strong>Backend:</strong> Elixir, Phoenix, LiveView</span>
                </li>
                <li class="flex items-center gap-2">
                  <Icons.icon_postgres class="w-4 h-4 shrink-0" />
                  <span><strong>Database:</strong> PostgreSQL</span>
                </li>
                <li class="flex items-center gap-2">
                  <Icons.icon_palette class="w-4 h-4 shrink-0" />
                  <span><strong>Frontend:</strong> Retro CSS, Vanilla JS</span>
                </li>
                <li class="flex items-center gap-2">
                  <Icons.icon_websocket class="w-4 h-4 shrink-0" />
                  <span><strong>Real-time:</strong> Phoenix Channels, WebSocket</span>
                </li>
                <li class="flex items-center gap-2">
                  <Icons.icon_webrtc class="w-4 h-4 shrink-0" />
                  <span><strong>P2P:</strong> WebRTC</span>
                </li>
              </ul>
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
      </section>

      <%!-- ══════════════ SUPPORT ══════════════ --%>
      <section class="m-4" aria-labelledby="support-heading">
        <.window>
          <.window_title_bar title="Support the Project" controls={[:close]}>
            <:icon><Icons.icon_heart class="w-4 h-4" /></:icon>
          </.window_title_bar>
          <.window_body>
            <h2 id="support-heading" class="text-lg font-bold mb-2">
              Help keep Retro Hex Chat alive.
            </h2>

            <p class="text-sm mb-3">
              Retro Hex Chat is 100% volunteer-driven. No investors, no ads, no data collection.
              If you believe in this project, consider supporting it:
            </p>

            <div class="grid md:grid-cols-2 gap-3">
              <fieldset class="border-2 border-gray-400 p-3">
                <legend class="text-sm font-bold px-1">GitHub Sponsors</legend>
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
              </fieldset>

              <fieldset class="border-2 border-gray-400 p-3">
                <legend class="text-sm font-bold px-1">Other ways to help</legend>
                <ul class="text-sm space-y-1">
                  <li>&#11088; Star the repository</li>
                  <li>&#x1F4E2; Share with friends</li>
                  <li>&#x1F41B; Report bugs and suggest features</li>
                  <li>&#x1F4BB; Contribute code</li>
                </ul>
              </fieldset>
            </div>
          </.window_body>
          <.window_status_bar>
            <.window_status_bar_field grow>Thank you!</.window_status_bar_field>
          </.window_status_bar>
        </.window>
      </section>
    </.landing_layout>
    """
  end
end
