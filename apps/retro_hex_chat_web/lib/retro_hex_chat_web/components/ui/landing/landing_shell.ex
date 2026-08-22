defmodule RetroHexChatWeb.Components.UI.Landing.LandingShell do
  @moduledoc """
  Visual shell and shared editorial components for the public landing pages.

  Landing LiveViews provide page state and content. This module owns the shared
  desktop chrome, menu bar, taskbar, footer and page intro composition.

  The desk carries nothing above the workspace: the menu bar hangs under the
  Connect window's title bar (`LandingHelpers.landing_connect_window/1` puts it
  there), which is the window that leads on every page.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Desktop
  import RetroHexChatWeb.Components.UI.Window
  import RetroHexChatWeb.Components.UI.MenuBar
  import RetroHexChatWeb.Components.UI.LanguageMenu
  import RetroHexChatWeb.Components.UI.ContextMenu
  import RetroHexChatWeb.Components.UI.DesktopLaunchers
  import RetroHexChatWeb.Components.UI.StartMenuApp

  alias RetroHexChatWeb.Icons

  @doc """
  The landing desktop: a workspace of real windows, one page per desktop.

  Each section of a page is a `desktop_window/1` the reader can move, resize,
  maximize or minimize, laid out in a cascade on a first visit. The workspace is
  the viewport — nothing scrolls outside a window — so the taskbar carries the
  page's windows and navigation between pages lives in the Start menu and the
  menu bar, both real links.

  With scripting off the whole thing degrades to the document it is built from:
  windows leave the absolute layer and stack in flow (see `window-manager.css`).
  """
  attr :active_page, :atom, required: true

  attr :windows, :list,
    required: true,
    doc: "%{id, label, icon} for each window on this page, in the order they cascade"

  slot :inner_block, required: true, doc: "desktop_window/1 children"

  @spec landing_layout(map()) :: Phoenix.LiveView.Rendered.t()
  def landing_layout(assigns) do
    ~H"""
    <div class="landing-desktop bg-background text-text font-system flex h-screen flex-col">
      <.desktop
        id="landing-desktop"
        persist_key={"landing:#{@active_page}"}
        cascade_on_mount
        window_manager_hook="PublicWindowManagerHook"
        class="flex-1"
      >
        {render_slot(@inner_block)}
        <.landing_about_window active_page={@active_page} />
        <.desktop_launcher_windows
          screen={:landing}
          current_path={active_page_path(@active_page)}
        />

        <:shortcuts>
          <.desktop_launcher_icons screen={:landing} />
        </:shortcuts>

        <.desktop_connect_required_dialog />

        <:taskbar>
          <.landing_taskbar active_page={@active_page} windows={@windows} />
        </:taskbar>
      </.desktop>
    </div>
    """
  end

  # The landing taskbar is the same taskbar the app runs, not a lookalike: the
  # `Desktop` components render it and the window manager drives it. Every page
  # button and Start-menu entry is a real `<a href>`, so a page that never runs
  # JavaScript still navigates — and still indexes. The manager recognises that
  # these point at other documents and leaves the clicks to the browser.
  attr :active_page, :atom, required: true
  attr :windows, :list, required: true

  defp landing_taskbar(assigns) do
    assigns =
      assigns
      |> assign(:start_windows, start_windows(assigns.windows))
      |> assign(:current_path, active_page_path(assigns.active_page))

    ~H"""
    <.taskbar
      id="landing-taskbar"
      class="fixed inset-x-0 bottom-0 !z-floating"
      data-testid="landing-taskbar"
    >
      <:start>
        <%!-- Closing a window takes its taskbar button with it, the way Win98
              does. Start ▸ Windows is how it comes back — without it a closed
              section would be unreachable. About is one of those sections. --%>
        <.start_menu_app
          id="landing-start-menu"
          screen={:landing}
          windows={@start_windows}
          current_path={@current_path}
        />
      </:start>

      <.desktop_launcher_taskbar_buttons screen={:landing} current_path={@current_path} />
      <%!-- One button per window on this page, exactly as the app's taskbar
            behaves. Reaching another page is the Start menu's job. --%>
      <%!-- `desktop-taskbar__window-button` is what the stacked (mobile) shell
            hides: a phone has no room for a strip of window buttons, and
            Start ▸ Windows switches between them there. --%>
      <%!-- Connect leads, because it is the one window here that does something
            rather than explains something. --%>
      <.taskbar_button
        window="connect"
        label={dgettext("landing", "Connect")}
        class="desktop-taskbar__window-button"
      >
        <:icon><Icons.icon_connect class="w-3 h-3" /></:icon>
      </.taskbar_button>
      <.taskbar_button
        :for={w <- @windows}
        window={w.id}
        label={w.label}
        class="desktop-taskbar__window-button"
      >
        <:icon>{apply(Icons, w.icon, [%{class: "w-3 h-3"}])}</:icon>
      </.taskbar_button>
      <.taskbar_button
        window="about"
        label={dgettext("landing", "About")}
        class="desktop-taskbar__window-button"
      >
        <:icon><Icons.icon_lightbulb class="w-3 h-3" /></:icon>
      </.taskbar_button>

      <%!-- A clock and nothing else, as on the chat and connect desktops. The
            Connect button that used to sit here was a second CTA in chrome no
            other shell puts one in; Start ▸ Open the app is the shared way. --%>
      <:tray>
        <.desktop_tray class="ml-auto">
          <Icons.icon_clock class="h-3 w-3 shrink-0" />
          <span data-clock class="font-mono tabular-nums">--:--</span>
        </.desktop_tray>
      </:tray>
    </.taskbar>
    """
  end

  # The page's own windows as the Start menu names them (`icon_fn`, the key the
  # shared taskbar components use), plus About — a section with a window and a
  # taskbar button, so it belongs in the list that brings closed ones back.
  defp start_windows(windows) do
    [%{id: "connect", label: dgettext("landing", "Connect"), icon_fn: :icon_connect}] ++
      Enum.map(windows, &%{id: &1.id, label: &1.label, icon_fn: &1.icon}) ++
      [%{id: "about", label: dgettext("landing", "About"), icon_fn: :icon_lightbulb}]
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

  @doc """
  Real dropdown menu bar (Navigate / Help / Language) for the public pages.

  Built from the shared MenuBar/ContextMenu primitives — the same DOM contract,
  the same rail, and since `public_pages.js` runs the very same engine the app
  does, the same behaviour too. No phx-hook: every item is a real `<a href>`, so
  the menus navigate and index with JavaScript off.

  Hangs under the Connect window's title bar rather than across the top of the
  screen, as the chat's does under its own. The window is open on arrival on
  every page; closing it takes the strip with it, and Start ▸ Windows brings
  both back — the same bargain every window on this desk makes.
  """
  attr :active_page, :atom, required: true
  attr :class, :any, default: nil

  @spec landing_menu_bar(map()) :: Phoenix.LiveView.Rendered.t()
  def landing_menu_bar(assigns) do
    assigns =
      assigns
      |> assign(:current_path, active_page_path(assigns.active_page))
      |> assign(:sections, mobile_sections())

    ~H"""
    <.menu_bar
      id="landing-menubar"
      testid="landing-menu-bar"
      class={classes(["app-menu-bar", @class])}
    >
      <.mobile_menu_drawer
        menu_id="landing-menubar"
        sections={@sections}
        active_section="navigate"
      >
        <:section id="navigate">
          <.navigate_menu_items active_page={@active_page} />
        </:section>
        <:section id="language">
          <.language_menu_items mode={:public} current_path={@current_path} />
        </:section>
        <:section id="help">
          <.help_menu_items />
        </:section>
      </.mobile_menu_drawer>

      <.mobile_menu_rail sections={@sections} />

      <.menu class="app-menu-bar__desktop-menu" label={dgettext("landing", "Navigate")}>
        <:icon><Icons.icon_btn_next class="h-4 w-4" /></:icon>
        <.navigate_menu_items active_page={@active_page} />
      </.menu>

      <.menu class="app-menu-bar__desktop-menu" label={dgettext("landing", "Help")}>
        <:icon><Icons.icon_btn_help_topics class="h-4 w-4" /></:icon>
        <.help_menu_items />
      </.menu>

      <.language_menu
        mode={:public}
        current_path={@current_path}
        class="app-menu-bar__desktop-menu"
      />
    </.menu_bar>
    """
  end

  # The rail and the drawer show the same three menus the desktop strip does.
  defp mobile_sections do
    [
      %{id: "navigate", label: dgettext("landing", "Navigate"), icon_fn: :icon_btn_next},
      %{id: "language", label: dgettext("ui", "Language"), icon_fn: :icon_globe},
      %{id: "help", label: dgettext("landing", "Help"), icon_fn: :icon_btn_help_topics}
    ]
  end

  attr :active_page, :atom, required: true

  defp navigate_menu_items(assigns) do
    assigns = assign(assigns, :pages, nav_pages())

    ~H"""
    <.context_menu_item :for={p <- @pages} data-testid={"landing-menu-nav-#{p.page}"}>
      <:icon>{apply(Icons, p.icon, [%{class: "h-[14px] w-[14px]"}])}</:icon>
      <a href={p.path} class={["block flex-1", p.page == @active_page && "font-bold"]}>
        {p.label}
      </a>
    </.context_menu_item>
    """
  end

  defp help_menu_items(assigns) do
    ~H"""
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
    <.desktop_window
      id="intro"
      title={@title}
      width={620}
      data-testid="landing-intro-window"
    >
      <:icon>{render_slot(@icon)}</:icon>
      <h1 id={@heading_id} class="text-lg font-bold mb-2 text-text">{@title}</h1>
      <p class="text-sm max-w-3xl">
        {@description}
      </p>
      <:status :if={@status}>
        <.window_status_bar_field grow>{@status}</.window_status_bar_field>
      </:status>
    </.desktop_window>
    """
  end

  attr :active_page, :atom, required: true

  defp landing_about_window(assigns) do
    assigns =
      assigns
      |> assign(:current_path, active_page_path(assigns.active_page))
      |> assign(:supported_locales, RetroHexChatWeb.I18n.supported_locales())

    ~H"""
    <.desktop_window
      id="about"
      title={dgettext("landing", "About")}
      width={640}
      data-testid="landing-about-window"
    >
      <:icon><Icons.icon_lightbulb class="w-4 h-4" /></:icon>
      <footer>
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
            <%!-- Channel names, not links. They used to point at /connect, which
                  is now only where the app sends you when a session ends — and
                  the window that gets you in is already open on this page. --%>
            <ul class="space-y-1">
              <li>#general</li>
              <li>#dev</li>
              <li>#help</li>
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
      </footer>

      <:status>
        <.window_status_bar_field grow>
          {dgettext("landing", "MIT License")}
        </.window_status_bar_field>
        <.window_status_bar_field>{dgettext("landing", "v0.1.0")}</.window_status_bar_field>
      </:status>
    </.desktop_window>
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
