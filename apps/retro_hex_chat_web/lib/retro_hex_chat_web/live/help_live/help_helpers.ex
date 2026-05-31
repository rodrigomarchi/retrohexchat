defmodule RetroHexChatWeb.HelpLive.HelpHelpers do
  @moduledoc false
  use Phoenix.Component
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.UI.TreeView
  import RetroHexChatWeb.Components.UI.AppHeader
  import RetroHexChatWeb.Components.UI.MenuBarApp

  alias RetroHexChatWeb.Icons

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  # ── Layout ──────────────────────────────────────────────────

  @doc "Full-page help wrapper: app_header + two-pane layout (tree sidebar + content area)."
  attr :topics_by_category, :list, required: true
  attr :selected_topic, :map, default: nil
  slot :inner_block, required: true

  @spec help_layout(map()) :: Phoenix.LiveView.Rendered.t()
  def help_layout(assigns) do
    ~H"""
    <div class="min-h-screen bg-desktop font-system text-text flex flex-col">
      <.app_header logo_href="/">
        <:panels>
          <.menu_bar_app id="help-menubar" phx-hook="MenuBarHook" connected={false} />
        </:panels>
      </.app_header>

      <div class="flex-1 m-4 mt-2">
        <div class="shadow-retro-window bg-surface p-1">
          <div class="bg-gradient-to-r from-primary to-highlight-light text-white px-2 py-1 font-bold text-xs flex items-center gap-2">
            <Icons.icon_notepad class="w-3.5 h-3.5" /> {gettext("Help Topics")}
          </div>

          <div class="flex p-1">
            <nav
              class="shadow-retro-sunken bg-white w-56 mr-2 shrink-0 overflow-y-auto p-1"
              style="max-height: calc(100vh - 120px)"
              aria-label={gettext("Help navigation")}
            >
              <.tree_view class="!shadow-none !p-0 !bg-transparent">
                <.tree_view_group
                  :for={{category, cat_icon, topics} <- @topics_by_category}
                  label={category}
                  open={@selected_topic != nil && @selected_topic.category == category}
                >
                  <:icon>{apply(Icons, cat_icon, [%{class: "w-4 h-4"}])}</:icon>
                  <.link
                    :for={topic <- topics}
                    navigate={~p"/chat/help/#{topic.id}"}
                    class="block no-underline"
                  >
                    <.tree_view_item active={@selected_topic != nil && @selected_topic.id == topic.id}>
                      <:icon>{apply(Icons, topic.icon, [%{class: "w-3 h-3"}])}</:icon>
                      {topic.title}
                    </.tree_view_item>
                  </.link>
                </.tree_view_group>
              </.tree_view>
            </nav>

            <main
              class="shadow-retro-sunken bg-white flex-1 p-6 overflow-y-auto"
              style="max-height: calc(100vh - 120px)"
              data-testid="help-content-pane"
            >
              {render_slot(@inner_block)}
            </main>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ── Content helpers ─────────────────────────────────────────
  # Same API as the old HelpHTML helpers so 213 templates need zero changes.

  @doc "Section heading with icon, used inside help content templates."
  attr :icon, :atom, required: true
  slot :inner_block, required: true

  @spec help_h4(map()) :: Phoenix.LiveView.Rendered.t()
  def help_h4(assigns) do
    ~H"""
    <h4 class="flex items-center gap-1.5 text-sm font-bold mt-4 mb-1.5 text-text">
      <.help_icon name={@icon} class="w-3.5 h-3.5 flex-shrink-0" />
      {render_slot(@inner_block)}
    </h4>
    """
  end

  @doc "Cross-reference link to another help topic."
  attr :topic, :string, required: true
  slot :inner_block, required: true

  @spec help_link(map()) :: Phoenix.LiveView.Rendered.t()
  def help_link(assigns) do
    ~H"""
    <.link navigate={~p"/chat/help/#{@topic}"} class="text-link hover:underline">
      {render_slot(@inner_block)}
    </.link>
    """
  end

  @doc "Render an icon by name. Dispatches to the Icons facade at runtime."
  attr :name, :atom, required: true
  attr :class, :string, default: "w-3.5 h-3.5"

  @spec help_icon(map()) :: Phoenix.LiveView.Rendered.t()
  def help_icon(assigns) do
    apply(Icons, assigns.name, [%{class: assigns.class}])
  end

  @doc "Dynamically render a help topic's content by dispatching to HelpContent."
  attr :id, :string, required: true

  @spec render_topic_content(map()) :: Phoenix.LiveView.Rendered.t()
  def render_topic_content(assigns) do
    func = assigns.id |> String.replace("-", "_") |> String.to_existing_atom()
    apply(RetroHexChatWeb.HelpContent, func, [assigns])
  end
end
