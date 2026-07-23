defmodule RetroHexChatWeb.Components.UI.Landing.LandingShell do
  @moduledoc """
  Visual shell and shared editorial components for the public landing pages.

  Landing LiveViews provide page state and content. This module owns the shared
  desktop chrome, menu bar, taskbar, footer and page intro composition.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.AppHeader
  import RetroHexChatWeb.Components.UI.Window
  import RetroHexChatWeb.Components.UI.MenuBar
  import RetroHexChatWeb.Components.UI.LanguageMenu
  import RetroHexChatWeb.Components.UI.ContextMenu

  alias RetroHexChatWeb.Icons

  attr :active_page, :atom, required: true
  slot :inner_block, required: true

  @spec landing_layout(map()) :: Phoenix.LiveView.Rendered.t()
  def landing_layout(assigns) do
    ~H"""
    <div class="landing-desktop min-h-screen flex flex-col bg-background pb-10">
      <.landing_header active_page={@active_page} />
      <main class="flex-1">
        {render_slot(@inner_block)}
      </main>
      <.landing_footer active_page={@active_page} />
      <.landing_taskbar active_page={@active_page} />
    </div>
    """
  end

  # Static Win98 taskbar for the landing desktop. It mirrors the window manager's
  # look (`desktop-taskbar*` classes) but is fully static — no LiveSocket, no
  # WindowManagerHook. The Start menu opens via the existing `data-toggle-target`
  # vanilla toggle (public_pages.js); page buttons and menu items are real
  # `<a href>` links, so navigation and SEO stay intact. Each landing page is a
  # "window": its taskbar button shows pressed (`is-active`) for the current page.
  attr :active_page, :atom, required: true

  defp landing_taskbar(assigns) do
    assigns = assign(assigns, :pages, nav_pages())

    ~H"""
    <div class="desktop-taskbar shadow-retro-window bg-surface fixed inset-x-0 bottom-0 z-floating flex items-center gap-[3px] p-[2px]">
      <%!-- Start button + menu (toggled by the existing data-toggle-target JS) --%>
      <div class="relative shrink-0">
        <button
          type="button"
          data-toggle-target="#landing-start-menu"
          aria-controls="landing-start-menu"
          aria-expanded="false"
          class="desktop-start-button shadow-retro-raised bg-surface active:shadow-retro-sunken inline-flex items-center gap-1 px-2 py-[2px] text-xs font-bold"
        >
          <span class="inline-flex h-4 w-4 shrink-0 items-center justify-center">
            <Icons.icon_hex_stone class="h-4 w-4" />
          </span>
          {dgettext("landing", "Start")}
        </button>
        <div
          id="landing-start-menu"
          hidden
          class="desktop-start-menu shadow-retro-window bg-surface absolute bottom-full left-0 z-floating mb-[2px] w-56 p-[3px]"
        >
          <.start_link :for={p <- @pages} href={p.path} label={p.label}>
            <:icon>{apply(Icons, p.icon, [%{class: "h-4 w-4"}])}</:icon>
          </.start_link>
          <div class="shadow-retro-status my-[2px] h-[2px]"></div>
          <.start_link href="/chat/help" label={dgettext("landing", "Documentation")}>
            <:icon><Icons.icon_notepad class="h-4 w-4" /></:icon>
          </.start_link>
          <.start_link href="/connect" label={dgettext("landing", "Open the app")} emphasis>
            <:icon><Icons.icon_connect class="h-4 w-4" /></:icon>
          </.start_link>
        </div>
      </div>

      <%!-- Page "windows" (hidden on mobile — navigation lives in the Start menu) --%>
      <div class="hidden md:flex flex-1 items-center gap-[3px] overflow-x-auto">
        <a
          :for={p <- @pages}
          href={p.path}
          aria-current={(p.page == @active_page && "page") || nil}
          class={[
            "desktop-taskbar__button shadow-retro-raised bg-surface no-underline text-text",
            "inline-flex shrink-0 items-center gap-1 px-2 py-[2px] text-xs",
            p.page == @active_page && "is-active"
          ]}
        >
          <span class="inline-flex h-4 w-4 shrink-0 items-center justify-center">
            {apply(Icons, p.icon, [%{class: "w-3 h-3"}])}
          </span>
          <span class="max-w-[12ch] truncate">{p.label}</span>
        </a>
      </div>

      <%!-- Tray: persistent Connect CTA + clock (bottom-right, like the real desktop) --%>
      <a
        href="/connect"
        class="shadow-retro-raised bg-surface active:shadow-retro-sunken ml-auto md:ml-0 inline-flex shrink-0 items-center gap-1 px-2 py-[2px] text-xs font-bold no-underline text-text"
      >
        <Icons.icon_connect class="w-4 h-4" /> {dgettext("landing", "Connect")}
      </a>
      <div class="shadow-retro-status ml-[2px] flex shrink-0 items-center gap-1 px-2 py-[2px] text-xs">
        <Icons.icon_clock class="h-3 w-3 shrink-0" />
        <span data-clock class="font-mono tabular-nums">--:--</span>
      </div>
    </div>
    """
  end

  attr :href, :string, required: true
  attr :label, :string, required: true
  attr :emphasis, :boolean, default: false
  slot :icon, required: true

  defp start_link(assigns) do
    ~H"""
    <a
      href={@href}
      class={[
        "flex items-center gap-2 px-2 py-1 text-xs no-underline hover:bg-primary hover:text-white",
        if(@emphasis, do: "font-bold text-primary", else: "text-text")
      ]}
    >
      <span class="inline-flex h-4 w-4 shrink-0 items-center justify-center">
        {render_slot(@icon)}
      </span>
      {@label}
    </a>
    """
  end

  # The 7 landing pages, shared by the taskbar buttons, Start menu and menu bar.
  defp nav_pages do
    [
      %{page: :home, path: "/", label: dgettext("landing", "Home"), icon: :icon_hex_stone},
      %{
        page: :how_it_works,
        path: "/how-it-works",
        label: dgettext("landing", "How It Works"),
        icon: :icon_server
      },
      %{
        page: :features,
        path: "/features",
        label: dgettext("landing", "Features"),
        icon: :icon_chat
      },
      %{
        page: :privacy,
        path: "/privacy",
        label: dgettext("landing", "Privacy"),
        icon: :icon_lock
      },
      %{
        page: :install,
        path: "/install",
        label: dgettext("landing", "Install"),
        icon: :icon_terminal
      },
      %{
        page: :community,
        path: "/community",
        label: dgettext("landing", "Community"),
        icon: :icon_code
      },
      %{page: :faq, path: "/faq", label: dgettext("landing", "FAQ"), icon: :icon_question}
    ]
  end

  # Real dropdown menu bar (Navigate / Help / Language) built from the shared
  # MenuBar/ContextMenu primitives — same DOM contract (data-menubar-*) as the
  # logged-in app. Behaviour is wired by public_pages.js (vanilla), so no
  # phx-hook/LiveSocket. All items are real <a href> links (navigation + SEO).
  attr :active_page, :atom, required: true
  attr :class, :any, default: nil

  defp landing_menu_bar(assigns) do
    assigns =
      assigns
      |> assign(:pages, nav_pages())
      |> assign(:current_path, active_page_path(assigns.active_page))

    ~H"""
    <.menu_bar id="landing-menubar" testid="landing-menu-bar" class={@class}>
      <.menu label={dgettext("landing", "Navigate")}>
        <:icon><Icons.icon_btn_next class="h-4 w-4" /></:icon>
        <.context_menu_item :for={p <- @pages} data-testid={"landing-menu-nav-#{p.page}"}>
          <:icon>{apply(Icons, p.icon, [%{class: "h-[14px] w-[14px]"}])}</:icon>
          <a href={p.path} class={["block flex-1", p.page == @active_page && "font-bold"]}>
            {p.label}
          </a>
        </.context_menu_item>
      </.menu>

      <.menu label={dgettext("landing", "Help")}>
        <:icon><Icons.icon_btn_help_topics class="h-4 w-4" /></:icon>
        <.context_menu_item data-testid="landing-menu-docs">
          <:icon><Icons.icon_notepad class="h-[14px] w-[14px]" /></:icon>
          <a href="/chat/help" class="block flex-1">{dgettext("landing", "Documentation")}</a>
        </.context_menu_item>
        <.context_menu_separator />
        <.context_menu_item data-testid="landing-menu-github">
          <:icon><Icons.icon_code class="h-[14px] w-[14px]" /></:icon>
          <a
            href="https://github.com/rodrigomarchi/retro_hex_chat"
            target="_blank"
            rel="noopener"
            class="block flex-1"
          >
            GitHub
          </a>
        </.context_menu_item>
        <.context_menu_item data-testid="landing-menu-license">
          <:icon><Icons.icon_legal class="h-[14px] w-[14px]" /></:icon>
          <a
            href="https://github.com/rodrigomarchi/retro_hex_chat/blob/main/LICENSE"
            target="_blank"
            rel="noopener"
            class="block flex-1"
          >
            {dgettext("landing", "License (MIT)")}
          </a>
        </.context_menu_item>
      </.menu>

      <.language_menu mode={:public} current_path={@current_path} />
    </.menu_bar>
    """
  end

  attr :heading_id, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :status, :string, default: nil
  slot :icon, required: true

  @spec landing_page_intro(map()) :: Phoenix.LiveView.Rendered.t()
  def landing_page_intro(assigns) do
    ~H"""
    <.window class="mb-4">
      <.window_title_bar title={@title} controls={[:close]}>
        <:icon>{render_slot(@icon)}</:icon>
      </.window_title_bar>
      <.window_body>
        <h1 id={@heading_id} class="text-lg font-bold mb-2 text-text">{@title}</h1>
        <p class="text-sm max-w-3xl">
          {@description}
        </p>
      </.window_body>
      <.window_status_bar :if={@status}>
        <.window_status_bar_field grow>{@status}</.window_status_bar_field>
      </.window_status_bar>
    </.window>
    """
  end

  attr :active_page, :atom, required: true

  defp landing_header(assigns) do
    ~H"""
    <div class="sticky top-0 z-modal">
      <.app_header logo_href="/">
        <:panels>
          <div class="flex items-center flex-1">
            <%!-- Real dropdown menu bar (behaviour wired by public_pages.js, no LiveSocket) --%>
            <.landing_menu_bar active_page={@active_page} class="hidden lg:flex" />
            <a href="/connect" class="ml-auto no-underline">
              <button
                type="button"
                class="inline-flex items-center gap-1 h-7 px-3 text-xs shadow-retro-raised bg-surface active:shadow-retro-sunken"
              >
                <Icons.icon_connect class="w-4 h-4" /> {dgettext("landing", "Connect")}
              </button>
            </a>
            <%!-- Mobile menu toggle --%>
            <button
              type="button"
              class="lg:hidden ml-1 inline-flex items-center h-7 px-2 text-xs shadow-retro-raised bg-surface active:shadow-retro-sunken"
              data-toggle-target="#mobile-nav"
              aria-controls="mobile-nav"
              aria-expanded="false"
              aria-label={dgettext("landing", "Menu")}
            >
              <Icons.icon_btn_menu class="w-4 h-4" />
            </button>
          </div>
        </:panels>
      </.app_header>
      <%!-- Mobile dropdown nav --%>
      <nav
        id="mobile-nav"
        hidden
        class="lg:hidden bg-surface shadow-retro-window border-t border-gray-400 p-2"
      >
        <div class="flex flex-col gap-1">
          <.mobile_nav_link
            href="/how-it-works"
            label={dgettext("landing", "How It Works")}
            active={@active_page == :how_it_works}
          >
            <Icons.icon_server class="w-3 h-3" />
          </.mobile_nav_link>
          <.mobile_nav_link
            href="/features"
            label={dgettext("landing", "Features")}
            active={@active_page == :features}
          >
            <Icons.icon_chat class="w-3 h-3" />
          </.mobile_nav_link>
          <.mobile_nav_link
            href="/privacy"
            label={dgettext("landing", "Privacy")}
            active={@active_page == :privacy}
          >
            <Icons.icon_lock class="w-3 h-3" />
          </.mobile_nav_link>
          <.mobile_nav_link
            href="/install"
            label={dgettext("landing", "Install")}
            active={@active_page == :install}
          >
            <Icons.icon_terminal class="w-3 h-3" />
          </.mobile_nav_link>
          <.mobile_nav_link
            href="/community"
            label={dgettext("landing", "Community")}
            active={@active_page == :community}
          >
            <Icons.icon_code class="w-3 h-3" />
          </.mobile_nav_link>
          <.mobile_nav_link
            href="/faq"
            label={dgettext("landing", "FAQ")}
            active={@active_page == :faq}
          >
            <Icons.icon_question class="w-3 h-3" />
          </.mobile_nav_link>
          <.mobile_nav_link href="/chat/help" label={dgettext("landing", "Docs")} active={false}>
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

  attr :active_page, :atom, required: true

  defp landing_footer(assigns) do
    assigns =
      assigns
      |> assign(:current_path, active_page_path(assigns.active_page))
      |> assign(:supported_locales, RetroHexChatWeb.I18n.supported_locales())

    ~H"""
    <footer class="m-4 mt-8">
      <.window>
        <.window_title_bar title={dgettext("landing", "About")} inactive controls={[:close]}>
          <:icon><Icons.icon_lightbulb class="w-4 h-4" /></:icon>
        </.window_title_bar>
        <.window_body>
          <p class="text-sm mb-3">
            {dgettext("landing", "Retro Hex Chat is free software, licensed under MIT.")}<br />
            {dgettext("landing", "Built with Elixir, Phoenix, and LiveView.")}<br />
            {dgettext("landing", "Inspired by the IRC of the 2000s and the freedom it represented.")}
          </p>

          <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 text-xs mb-3">
            <div>
              <h3 class="font-bold mb-1">
                <Icons.icon_code class="w-3 h-3 inline" /> {dgettext("landing", "Project")}
              </h3>
              <ul class="space-y-1">
                <li>
                  <a
                    href="https://github.com/rodrigomarchi/retro_hex_chat"
                    target="_blank"
                    rel="noopener"
                  >
                    {dgettext("landing", "GitHub")}
                  </a>
                </li>
                <li>
                  <a
                    href="https://github.com/rodrigomarchi/retro_hex_chat/blob/main/CONTRIBUTING.md"
                    target="_blank"
                    rel="noopener"
                  >
                    {dgettext("landing", "Contribute")}
                  </a>
                </li>
                <li>
                  <a
                    href="https://github.com/rodrigomarchi/retro_hex_chat/blob/main/LICENSE"
                    target="_blank"
                    rel="noopener"
                  >
                    {dgettext("landing", "License (MIT)")}
                  </a>
                </li>
                <li><a href="/chat/help">{dgettext("landing", "Documentation")}</a></li>
              </ul>
            </div>
            <div>
              <h3 class="font-bold mb-1">
                <Icons.icon_community class="w-3 h-3 inline" /> {dgettext("landing", "Community")}
              </h3>
              <ul class="space-y-1">
                <li><a href="/connect">#general</a></li>
                <li><a href="/connect">#dev</a></li>
                <li><a href="/connect">#help</a></li>
              </ul>
            </div>
            <div>
              <h3 class="font-bold mb-1">
                <Icons.icon_legal class="w-3 h-3 inline" /> {dgettext("landing", "Legal")}
              </h3>
              <ul class="space-y-1">
                <li>
                  <a
                    href="https://github.com/rodrigomarchi/retro_hex_chat/blob/main/LICENSE"
                    target="_blank"
                    rel="noopener"
                  >
                    {dgettext("landing", "MIT License")}
                  </a>
                </li>
                <li>
                  <a
                    href="https://github.com/rodrigomarchi/retro_hex_chat/blob/main/SECURITY.md"
                    target="_blank"
                    rel="noopener"
                  >
                    {dgettext("landing", "Security")}
                  </a>
                </li>
              </ul>
            </div>
            <div>
              <h3 class="font-bold mb-1">
                <Icons.icon_heart class="w-3 h-3 inline" /> {dgettext("landing", "Support")}
              </h3>
              <ul class="space-y-1">
                <li>
                  <a href="https://github.com/sponsors/rodrigomarchi" target="_blank" rel="noopener">
                    {dgettext("landing", "GitHub Sponsors")}
                  </a>
                </li>
              </ul>
            </div>
          </div>

          <div class="border-t border-gray-400 pt-3 mb-3">
            <h3 class="font-bold text-xs mb-2">
              <Icons.icon_link class="w-3 h-3 inline" /> {dgettext("landing", "Languages")}
            </h3>
            <div class="flex flex-wrap gap-x-3 gap-y-1 text-xs">
              <a
                :for={{code, label} <- @supported_locales}
                href={RetroHexChatWeb.SEO.localized_path(@current_path, code)}
                hreflang={RetroHexChatWeb.I18n.Locales.bcp47(code)}
              >
                {label}
              </a>
            </div>
          </div>

          <p class="text-sm text-center italic mb-2">
            {dgettext("landing", "“Your data. Your rules. Nobody in between.”")}
          </p>

          <div class="flex justify-center gap-4 text-xs text-gray-600">
            <span>{dgettext("landing", "v0.1.0")}</span>
            <span>{dgettext("landing", "Made by humans")}</span>
            <span>{dgettext("landing", "2025–2026")}</span>
          </div>
        </.window_body>
        <.window_status_bar>
          <.window_status_bar_field grow>
            {dgettext("landing", "MIT License")}
          </.window_status_bar_field>
          <.window_status_bar_field>{dgettext("landing", "v0.1.0")}</.window_status_bar_field>
        </.window_status_bar>
      </.window>
    </footer>
    """
  end

  defp active_page_path(:home), do: "/"
  defp active_page_path(:how_it_works), do: "/how-it-works"
  defp active_page_path(:features), do: "/features"
  defp active_page_path(:privacy), do: "/privacy"
  defp active_page_path(:install), do: "/install"
  defp active_page_path(:community), do: "/community"
  defp active_page_path(:faq), do: "/faq"
  defp active_page_path(_active_page), do: "/"
end
