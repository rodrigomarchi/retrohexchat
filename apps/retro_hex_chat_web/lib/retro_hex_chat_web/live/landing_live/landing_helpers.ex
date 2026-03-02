defmodule RetroHexChatWeb.LandingLive.LandingHelpers do
  @moduledoc false
  use Phoenix.Component

  import RetroHexChatWeb.Components.UI.AppHeader
  import RetroHexChatWeb.Components.UI.Window

  alias Phoenix.LiveView.JS
  alias RetroHexChatWeb.Icons

  attr :active_page, :atom, required: true
  slot :inner_block, required: true

  @spec landing_layout(map()) :: Phoenix.LiveView.Rendered.t()
  def landing_layout(assigns) do
    ~H"""
    <div class="min-h-screen flex flex-col">
      <.landing_header active_page={@active_page} />
      <main class="flex-1">
        {render_slot(@inner_block)}
      </main>
      <.landing_footer />
    </div>
    """
  end

  attr :active_page, :atom, required: true

  defp landing_header(assigns) do
    ~H"""
    <div class="sticky top-0 z-modal">
      <.app_header logo_href="/">
        <:panels>
          <nav class="flex items-center flex-1">
            <a href="/connect" class="no-underline">
              <button
                type="button"
                class="inline-flex items-center gap-1 h-7 px-3 text-xs shadow-retro-raised bg-surface active:shadow-retro-sunken"
              >
                <Icons.icon_connect class="w-4 h-4" /> Connect
              </button>
            </a>
            <.nav_link
              href="/how-it-works"
              label="How It Works"
              active={@active_page == :how_it_works}
            >
              <Icons.icon_server class="w-3 h-3" />
            </.nav_link>
            <.nav_link href="/features" label="Features" active={@active_page == :features}>
              <Icons.icon_chat class="w-3 h-3" />
            </.nav_link>
            <.nav_link href="/privacy" label="Privacy" active={@active_page == :privacy}>
              <Icons.icon_lock class="w-3 h-3" />
            </.nav_link>
            <.nav_link href="/install" label="Install" active={@active_page == :install}>
              <Icons.icon_terminal class="w-3 h-3" />
            </.nav_link>
            <.nav_link href="/community" label="Community" active={@active_page == :community}>
              <Icons.icon_code class="w-3 h-3" />
            </.nav_link>
            <.nav_link href="/faq" label="FAQ" active={@active_page == :faq}>
              <Icons.icon_question class="w-3 h-3" />
            </.nav_link>
            <a
              href="/chat/help"
              class="hidden lg:inline-flex items-center gap-1 px-2 text-xs hover:underline no-underline text-text"
            >
              <Icons.icon_notepad class="w-3 h-3" /> Docs
            </a>
            <%!-- Mobile menu toggle --%>
            <button
              type="button"
              class="lg:hidden ml-auto inline-flex items-center h-7 px-2 text-xs shadow-retro-raised bg-surface active:shadow-retro-sunken"
              phx-click={JS.toggle(to: "#mobile-nav")}
              aria-label="Menu"
            >
              <Icons.icon_btn_menu class="w-4 h-4" />
            </button>
          </nav>
        </:panels>
      </.app_header>
      <%!-- Mobile dropdown nav --%>
      <nav
        id="mobile-nav"
        class="hidden lg:hidden bg-surface shadow-retro-window border-t border-gray-400 p-2"
      >
        <div class="flex flex-col gap-1">
          <.mobile_nav_link
            href="/how-it-works"
            label="How It Works"
            active={@active_page == :how_it_works}
          >
            <Icons.icon_server class="w-3 h-3" />
          </.mobile_nav_link>
          <.mobile_nav_link href="/features" label="Features" active={@active_page == :features}>
            <Icons.icon_chat class="w-3 h-3" />
          </.mobile_nav_link>
          <.mobile_nav_link href="/privacy" label="Privacy" active={@active_page == :privacy}>
            <Icons.icon_lock class="w-3 h-3" />
          </.mobile_nav_link>
          <.mobile_nav_link href="/install" label="Install" active={@active_page == :install}>
            <Icons.icon_terminal class="w-3 h-3" />
          </.mobile_nav_link>
          <.mobile_nav_link href="/community" label="Community" active={@active_page == :community}>
            <Icons.icon_code class="w-3 h-3" />
          </.mobile_nav_link>
          <.mobile_nav_link href="/faq" label="FAQ" active={@active_page == :faq}>
            <Icons.icon_question class="w-3 h-3" />
          </.mobile_nav_link>
          <.mobile_nav_link href="/chat/help" label="Docs" active={false}>
            <Icons.icon_notepad class="w-3 h-3" />
          </.mobile_nav_link>
        </div>
      </nav>
    </div>
    """
  end

  attr :href, :string, required: true
  attr :label, :string, required: true
  attr :active, :boolean, default: false
  slot :inner_block, required: true

  defp nav_link(assigns) do
    ~H"""
    <a
      href={@href}
      class={[
        "hidden lg:inline-flex items-center gap-1 px-2 text-xs hover:underline no-underline whitespace-nowrap",
        if(@active, do: "font-bold text-primary", else: "text-text")
      ]}
    >
      {render_slot(@inner_block)} {@label}
    </a>
    """
  end

  attr :href, :string, required: true
  attr :label, :string, required: true
  attr :active, :boolean, default: false
  slot :inner_block, required: true

  defp mobile_nav_link(assigns) do
    ~H"""
    <a
      href={@href}
      class={[
        "flex items-center gap-2 px-2 py-1 text-xs no-underline hover:bg-highlight-light hover:text-white",
        if(@active, do: "font-bold text-primary", else: "text-text")
      ]}
    >
      {render_slot(@inner_block)} {@label}
    </a>
    """
  end

  defp landing_footer(assigns) do
    assigns = Map.put_new(assigns, :dummy, nil)

    ~H"""
    <footer class="m-4 mt-8">
      <.window>
        <.window_title_bar title="About" inactive controls={[:close]}>
          <:icon><Icons.icon_lightbulb class="w-4 h-4" /></:icon>
        </.window_title_bar>
        <.window_body>
          <p class="text-sm mb-3">
            Retro Hex Chat is free software, licensed under MIT.<br />
            Built with Elixir, Phoenix, and LiveView.<br />
            Inspired by the IRC of the 2000s and the freedom it represented.
          </p>

          <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 text-xs mb-3">
            <div>
              <h3 class="font-bold mb-1"><Icons.icon_code class="w-3 h-3 inline" /> Project</h3>
              <ul class="space-y-1">
                <li>
                  <a
                    href="https://github.com/rodrigomarchi/retro_hex_chat"
                    target="_blank"
                    rel="noopener"
                  >
                    GitHub
                  </a>
                </li>
                <li>
                  <a
                    href="https://github.com/rodrigomarchi/retro_hex_chat/blob/main/CONTRIBUTING.md"
                    target="_blank"
                    rel="noopener"
                  >
                    Contribute
                  </a>
                </li>
                <li>
                  <a
                    href="https://github.com/rodrigomarchi/retro_hex_chat/blob/main/LICENSE"
                    target="_blank"
                    rel="noopener"
                  >
                    License (MIT)
                  </a>
                </li>
                <li><a href="/chat/help">Documentation</a></li>
              </ul>
            </div>
            <div>
              <h3 class="font-bold mb-1">
                <Icons.icon_community class="w-3 h-3 inline" /> Community
              </h3>
              <ul class="space-y-1">
                <li><a href="/connect">#general</a></li>
                <li><a href="/connect">#dev</a></li>
                <li><a href="/connect">#help</a></li>
              </ul>
            </div>
            <div>
              <h3 class="font-bold mb-1"><Icons.icon_legal class="w-3 h-3 inline" /> Legal</h3>
              <ul class="space-y-1">
                <li>
                  <a
                    href="https://github.com/rodrigomarchi/retro_hex_chat/blob/main/LICENSE"
                    target="_blank"
                    rel="noopener"
                  >
                    MIT License
                  </a>
                </li>
                <li>
                  <a
                    href="https://github.com/rodrigomarchi/retro_hex_chat/blob/main/SECURITY.md"
                    target="_blank"
                    rel="noopener"
                  >
                    Security
                  </a>
                </li>
              </ul>
            </div>
            <div>
              <h3 class="font-bold mb-1"><Icons.icon_heart class="w-3 h-3 inline" /> Support</h3>
              <ul class="space-y-1">
                <li>
                  <a href="https://github.com/sponsors/rodrigomarchi" target="_blank" rel="noopener">
                    GitHub Sponsors
                  </a>
                </li>
              </ul>
            </div>
          </div>

          <p class="text-sm text-center italic mb-2">
            &ldquo;Your data. Your rules. Nobody in between.&rdquo;
          </p>

          <div class="flex justify-center gap-4 text-xs text-gray-600">
            <span>v0.1.0</span>
            <span>Made by humans</span>
            <span>2025&ndash;2026</span>
          </div>
        </.window_body>
      </.window>
    </footer>
    """
  end
end
