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
            <Icons.icon_notepad class="w-3.5 h-3.5" /> {dgettext("help", "Help Topics")}
          </div>

          <div class="flex p-1">
            <nav
              class="shadow-retro-sunken bg-white w-56 mr-2 shrink-0 overflow-y-auto p-1"
              style="max-height: calc(100vh - 120px)"
              aria-label={dgettext("help", "Help navigation")}
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

  defdelegate help_h4(assigns), to: RetroHexChatWeb.HelpContent.Helpers
  defdelegate help_link(assigns), to: RetroHexChatWeb.HelpContent.Helpers
  defdelegate help_icon(assigns), to: RetroHexChatWeb.HelpContent.Helpers

  @doc "Dynamically render a help topic's content by dispatching to HelpContent."
  attr :id, :string, required: true

  @help_content_modules [
    RetroHexChatWeb.HelpContent.CommandsAdmin,
    RetroHexChatWeb.HelpContent.CommandsAtoM,
    RetroHexChatWeb.HelpContent.CommandsNtoZ,
    RetroHexChatWeb.HelpContent.Bots,
    RetroHexChatWeb.HelpContent.Channels,
    RetroHexChatWeb.HelpContent.Arcade,
    RetroHexChatWeb.HelpContent.Games,
    RetroHexChatWeb.HelpContent.P2P,
    RetroHexChatWeb.HelpContent.UI,
    RetroHexChatWeb.HelpContent.ChatFeatures,
    RetroHexChatWeb.HelpContent.ChatStatusFeatures
  ]

  @spec render_topic_content(map()) :: Phoenix.LiveView.Rendered.t()
  def render_topic_content(assigns) do
    func = assigns.id |> String.replace("-", "_") |> String.to_existing_atom()

    @help_content_modules
    |> Enum.find(fn module ->
      Code.ensure_loaded?(module) and function_exported?(module, func, 1)
    end)
    |> case do
      nil -> raise ArgumentError, "missing help content template for #{assigns.id}"
      module -> apply(module, func, [assigns])
    end
  end
end
