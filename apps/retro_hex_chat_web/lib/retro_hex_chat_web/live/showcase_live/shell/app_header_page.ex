defmodule RetroHexChatWeb.ShowcaseLive.Shell.AppHeaderPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.AppHeader
  import RetroHexChatWeb.Components.UI.MenuBarApp
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("App Header"), active_page: "app-header")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{gettext("App Header")}</h2>

      <.showcase_card
        title={gettext("Default")}
        description="Responsive header with hex stone logo, app title (hidden on mobile), and toolbar buttons."
      >
        <.app_header />
        <.code_example>
          &lt;.app_header /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={gettext("With Logo Link")}
        description="Logo becomes a clickable link when logo_href is provided."
      >
        <.app_header logo_href="/" />
        <.code_example>
          &lt;.app_header logo_href="/" /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={gettext("With Menu Bar (Disconnected)")}
        description="macOS-style menu bar with disabled menus (only Help active)."
      >
        <.app_header>
          <:panels>
            <.menu_bar_app id="menubar-demo-disconnected" connected={false} />
          </:panels>
        </.app_header>
        <.code_example>
          &lt;.app_header&gt;
          &lt;:panels&gt;
          &lt;.menu_bar_app connected={false} /&gt;
          &lt;/:panels&gt;
          &lt;/.app_header&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={gettext("With Menu Bar (Connected)")}
        description="macOS-style menu bar with all menus enabled."
      >
        <.app_header>
          <:panels>
            <.menu_bar_app id="menubar-demo-connected" phx-hook="MenuBarHook" connected={true} />
          </:panels>
        </.app_header>
        <.code_example>
          &lt;.app_header&gt;
          &lt;:panels&gt;
          &lt;.menu_bar_app connected={true} on_action="toolbar_action" /&gt;
          &lt;/:panels&gt;
          &lt;/.app_header&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
