defmodule RetroHexChatWeb.ShowcaseHelpers do
  @moduledoc false
  use Phoenix.Component
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.UI.TreeView
  import RetroHexChatWeb.Components.UI.Desktop
  import RetroHexChatWeb.Components.UI.AppHeader
  import RetroHexChatWeb.Components.UI.MenuBarApp
  import RetroHexChatWeb.Components.UI.StartMenuApp
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]
  import RetroHexChatWeb.Components.UI.AboutDialog

  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.ShowcaseCatalog

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  @doc """
  Full-page showcase shell: a Win98 desktop whose focused window is the page.

  One component per URL. The page renders its window body inline, so the
  document stands complete before any JavaScript runs — the window manager only
  decorates it afterwards. Every way to reach another component (Start menu,
  taskbar, navigator) is a real link for the same reason.
  """
  attr :active_page, :string, required: true
  slot :inner_block, required: true

  @spec showcase_layout(map()) :: Phoenix.LiveView.Rendered.t()
  def showcase_layout(assigns) do
    assigns =
      assigns
      |> assign(:nav_tree, ShowcaseCatalog.nav_tree())
      |> assign(:page, page_meta(assigns.active_page))

    ~H"""
    <div class="bg-desktop font-system text-text flex h-screen flex-col">
      <.desktop id="showcase-desktop" persist_key="showcase" class="flex-1">
        <:header>
          <.app_header on_logo_click={show_modal("about-dialog")}>
            <:panels>
              <.menu_bar_app id="menubar" phx-hook="MenuBarHook" connected={false} />
            </:panels>
          </.app_header>
        </:header>

        <%!-- The page itself. Pinned: closing the document you navigated to
              would leave nothing behind. One stable id across every component
              page, so a layout the reader adjusts survives navigation. --%>
        <.desktop_window
          id="component"
          title={@page.title}
          pinned
          default_x={272}
          default_y={16}
          width={880}
          height={620}
          body_class="bg-gray-100"
          data-testid="showcase-component-window"
        >
          <:icon>{apply(Icons, @page.icon, [%{class: "w-4 h-4"}])}</:icon>
          {render_slot(@inner_block)}
        </.desktop_window>

        <.desktop_window
          id="navigator"
          title={dgettext("showcase", "Components")}
          default_x={16}
          default_y={16}
          width={240}
          height={620}
          data-testid="showcase-navigator-window"
        >
          <:icon><Icons.icon_folder class="w-4 h-4" /></:icon>
          <.showcase_navigator active_page={@active_page} nav_tree={@nav_tree} />
        </.desktop_window>

        <:taskbar>
          <.taskbar id="showcase-taskbar">
            <%!-- The component catalog left the Start menu when the menu became
                  the same on every screen. It is not lost: the Components window
                  IS the catalog, and Start ▸ Windows is what reopens it — the
                  same route the landing desktop uses to bring a closed section
                  back. --%>
            <:start>
              <.start_menu_app
                id="showcase-start-menu"
                screen={:showcase}
                windows={[
                  %{id: "component", label: @page.title, icon_fn: @page.icon},
                  %{
                    id: "navigator",
                    label: dgettext("showcase", "Components"),
                    icon_fn: :icon_folder
                  }
                ]}
              />
            </:start>

            <.taskbar_button window="component" label={@page.title}>
              <:icon>{apply(Icons, @page.icon, [%{class: "w-3 h-3"}])}</:icon>
            </.taskbar_button>
            <.taskbar_button window="navigator" label={dgettext("showcase", "Components")}>
              <:icon><Icons.icon_folder class="w-3 h-3" /></:icon>
            </.taskbar_button>

            <:tray>
              <.desktop_tray>
                <span
                  id="showcase-tray-clock"
                  data-clock
                  phx-hook="ClockHook"
                  class="font-mono tabular-nums"
                >
                </span>
              </.desktop_tray>
            </:tray>
          </.taskbar>
        </:taskbar>
      </.desktop>

      <.about_dialog id="about-dialog" />
    </div>
    """
  end

  attr :active_page, :string, required: true
  attr :nav_tree, :list, required: true

  defp showcase_navigator(assigns) do
    ~H"""
    <.tree_view class="!shadow-none !bg-transparent !p-0">
      <.link navigate={ShowcaseCatalog.root()} class="block no-underline">
        <.tree_view_item active={@active_page == "index"}>
          <:icon><Icons.icon_palette class="w-3 h-3" /></:icon>
          {dgettext("showcase", "Design System")}
        </.tree_view_item>
      </.link>
      <.tree_view_group
        :for={{group, entries} <- @nav_tree}
        label={group.label}
        open={Enum.any?(entries, &(&1.id == @active_page))}
      >
        <:icon>{apply(Icons, group.icon, [%{class: "w-4 h-4"}])}</:icon>
        <.link
          :for={entry <- entries}
          navigate={ShowcaseCatalog.path(entry)}
          class="block no-underline"
        >
          <.tree_view_item active={@active_page == entry.id}>
            <:icon>{apply(Icons, entry.icon, [%{class: "w-3 h-3"}])}</:icon>
            {entry.label}
          </.tree_view_item>
        </.link>
      </.tree_view_group>
    </.tree_view>
    """
  end

  # The index is not a catalog entry — it is the desk the components sit on.
  defp page_meta("index"),
    do: %{
      title: Gettext.dgettext(RetroHexChatWeb.Gettext, "showcase", "Design System"),
      icon: :icon_palette
    }

  defp page_meta(id) do
    case ShowcaseCatalog.fetch(id) do
      {:ok, entry} -> %{title: ShowcaseCatalog.label(entry), icon: entry.icon}
      :error -> %{title: id, icon: :icon_group_view}
    end
  end

  @doc "Retro-styled showcase card with title bar, description, and rendered content."
  attr :title, :string, required: true
  attr :description, :string, required: true
  slot :inner_block, required: true

  def showcase_card(assigns) do
    ~H"""
    <div class="shadow-retro-window bg-surface p-1 mb-4">
      <div class="bg-gradient-to-r from-primary to-highlight-light text-white px-2 py-1 font-bold text-xs">
        {@title}
      </div>
      <div class="p-2">
        <p class="text-xs text-muted-foreground mb-2">{@description}</p>
        <div class="shadow-retro-sunken bg-white p-3">
          {render_slot(@inner_block)}
        </div>
      </div>
    </div>
    """
  end

  @doc "Dark terminal-style code block with syntax highlighting."
  attr :language, :string, default: "elixir"
  slot :inner_block, required: true

  def code_example(assigns) do
    assigns = assign(assigns, :uid, System.unique_integer([:positive]))

    ~H"""
    <div
      id={"code-#{@uid}"}
      phx-hook="Highlight"
      class="shadow-retro-field bg-canvas-bg text-canvas-fg p-3 mt-2 overflow-x-auto"
    >
      <pre class="text-xs font-mono whitespace-pre"><code class={"language-#{@language}"}>{render_slot(@inner_block)}</code></pre>
    </div>
    """
  end
end
