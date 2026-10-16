defmodule RetroHexChatWeb.Components.UI.Landing.LandingShell do
  @moduledoc """
  The shared chrome of a page of the site: the menu bar under its document
  window's title bar, the page intro that opens it, and the About section that
  closes it. The pages themselves are `RetroHexChatWeb.Site.Pages.*`.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Site.Document
  import RetroHexChatWeb.Components.UI.Window
  import RetroHexChatWeb.Components.UI.MenuBar
  import RetroHexChatWeb.Components.UI.LanguageMenu
  import RetroHexChatWeb.Components.UI.ContextMenu

  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.PublicPages

  @doc """
  Real dropdown menu bar (Navigate / Help / Language) for the public pages.

  Built from the shared MenuBar/ContextMenu primitives — the same DOM contract,
  the same rail, and since `desktop.js` runs the very same engine the chat's
  menus do, the same behaviour too. No phx-hook: every item is a real `<a href>`, so
  the menus navigate and index with JavaScript off.

  Hangs under the page's own document window title bar, as the chat's hangs
  under its own (`Site.DocumentWindow`).
  """
  attr :active_page, :atom, required: true
  attr :current_path, :string, default: nil, doc: "the page's own address, for the language links"
  attr :class, :any, default: nil

  @spec landing_menu_bar(map()) :: Phoenix.LiveView.Rendered.t()
  def landing_menu_bar(assigns) do
    assigns =
      assigns
      |> assign(:current_path, current_path(assigns))
      |> assign(:sections, mobile_sections())

    ~H"""
    <.menu_bar
      id="landing-menubar"
      testid="landing-menu-bar"
      phx-hook="MenuBarHook"
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
    assigns = assign(assigns, :pages, PublicPages.all())

    ~H"""
    <.context_menu_item :for={p <- @pages} data-testid={"landing-menu-nav-#{p.page}"}>
      <:icon>{apply(Icons, p.icon, [%{class: "h-[14px] w-[14px]"}])}</:icon>
      <.link
        patch={PublicPages.localized_path(p.path)}
        class={["block flex-1", p.page == @active_page && "font-bold"]}
      >
        {p.label}
      </.link>
    </.context_menu_item>
    """
  end

  defp help_menu_items(assigns) do
    ~H"""
    <.context_menu_item data-testid="landing-menu-docs">
      <:icon><Icons.icon_notepad class="h-[14px] w-[14px]" /></:icon>
      <.link patch={PublicPages.localized_path("/chat/help")} class="block flex-1">
        {dgettext("landing", "Documentation")}
      </.link>
    </.context_menu_item>
    <.context_menu_separator />
    <.context_menu_item data-testid="landing-menu-github">
      <:icon><Icons.icon_code class="h-[14px] w-[14px]" /></:icon>
      <a
        href="https://github.com/rodrigomarchi/retrohexchat"
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
        href="https://github.com/rodrigomarchi/retrohexchat/blob/main/LICENSE"
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
    <.document_section id="intro" title={@title} data-testid="landing-intro-window">
      <:icon>{render_slot(@icon)}</:icon>
      <h1 id={@heading_id} class="text-lg font-bold mb-2 text-text">{@title}</h1>
      <p class="text-sm max-w-3xl">
        {@description}
      </p>
      <:status :if={@status}>
        <.window_status_bar_field grow>{@status}</.window_status_bar_field>
      </:status>
    </.document_section>
    """
  end

  @doc """
  The site's About: the project, its community, the legal notes and every
  language the page exists in. The footer of every page of the site.
  """
  attr :current_path, :string, required: true

  @spec site_about(map()) :: Phoenix.LiveView.Rendered.t()
  def site_about(assigns) do
    assigns = assign(assigns, :supported_locales, RetroHexChatWeb.I18n.supported_locales())

    ~H"""
    <.document_section
      id="about"
      title={dgettext("landing", "About")}
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
                  href="https://github.com/rodrigomarchi/retrohexchat"
                  target="_blank"
                  rel="noopener"
                >
                  {dgettext("landing", "GitHub")}
                </a>
              </li>
              <li>
                <a
                  href="https://github.com/rodrigomarchi/retrohexchat/blob/main/CONTRIBUTING.md"
                  target="_blank"
                  rel="noopener"
                >
                  {dgettext("landing", "Contribute")}
                </a>
              </li>
              <li>
                <a
                  href="https://github.com/rodrigomarchi/retrohexchat/blob/main/LICENSE"
                  target="_blank"
                  rel="noopener"
                >
                  {dgettext("landing", "License (MIT)")}
                </a>
              </li>
              <li>
                <.link patch={PublicPages.localized_path("/chat/help")}>
                  {dgettext("landing", "Documentation")}
                </.link>
              </li>
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
                  href="https://github.com/rodrigomarchi/retrohexchat/blob/main/LICENSE"
                  target="_blank"
                  rel="noopener"
                >
                  {dgettext("landing", "MIT License")}
                </a>
              </li>
              <li>
                <a
                  href="https://github.com/rodrigomarchi/retrohexchat/blob/main/SECURITY.md"
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
    </.document_section>
    """
  end

  # The page's own path when it named one, else its menu entry's.
  defp current_path(%{current_path: path}) when is_binary(path), do: path
  defp current_path(%{active_page: page}), do: PublicPages.path(page)
end
