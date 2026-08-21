defmodule RetroHexChatWeb.Components.UI.Help.HelpViewer do
  @moduledoc """
  Visual composition for the CHM-style help desktop.

  The Help LiveView owns navigation/search state. This module owns the help
  desktop shell, toolbar, navigator, topic frame and empty state.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.AboutDialog
  import RetroHexChatWeb.Components.UI.AppHeader
  import RetroHexChatWeb.Components.UI.Desktop
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]
  import RetroHexChatWeb.Components.UI.Help.HelpMenuBar
  import RetroHexChatWeb.Components.UI.Help.HelpStatusBar
  import RetroHexChatWeb.Components.UI.StartMenuApp
  import RetroHexChatWeb.Components.UI.TreeView

  alias RetroHexChat.Chat.HelpTopics
  alias RetroHexChatWeb.Icons

  attr :topics_by_category, :list, required: true
  attr :all_topics, :list, default: []
  attr :selected_topic, :map, default: nil
  attr :topic_count, :integer, default: 0
  attr :nav_tab, :atom, default: :contents
  attr :search_query, :string, default: ""
  attr :search_results, :list, default: []
  attr :canonical_path, :string, default: "/chat/help"
  slot :inner_block, required: true

  @spec help_layout(map()) :: Phoenix.LiveView.Rendered.t()
  def help_layout(assigns) do
    ~H"""
    <div class="flex flex-col h-screen bg-background font-system text-text">
      <.desktop id="help-desktop" persist_key="help" data-testid="help-desktop">
        <:header>
          <.app_header on_logo_click={show_modal("about-dialog")}>
            <:panels>
              <.help_menu_bar
                id="help-menubar"
                current_path={@canonical_path}
                phx-hook="MenuBarHook"
              />
              <.help_status_bar
                class="ml-auto"
                selected_topic={@selected_topic}
                topic_count={@topic_count}
              />
            </:panels>
          </.app_header>
        </:header>

        <.desktop_window
          id="help"
          title={dgettext("help", "Help — RetroHexChat")}
          pinned
          default_maximized
          body_class="p-0"
          data-testid="help-window"
        >
          <:icon><Icons.icon_notepad class="w-4 h-4" /></:icon>
          <div class="flex flex-col h-full">
            <.help_toolbar query={@search_query} />

            <div class="flex flex-col md:flex-row flex-1 min-h-0 gap-1 p-1">
              <.help_navigator
                nav_tab={@nav_tab}
                search_query={@search_query}
                search_results={@search_results}
                topics_by_category={@topics_by_category}
                all_topics={@all_topics}
                selected_topic={@selected_topic}
              />

              <main
                class="shadow-retro-sunken bg-white flex-1 min-h-0 overflow-y-auto p-6"
                data-testid="help-content-pane"
              >
                {render_slot(@inner_block)}
              </main>
            </div>
          </div>
        </.desktop_window>

        <:taskbar>
          <.help_taskbar current_path={@canonical_path} />
        </:taskbar>
      </.desktop>

      <.about_dialog id="about-dialog" />
    </div>
    """
  end

  attr :topic, :map, required: true
  slot :inner_block, required: true

  @spec help_topic(map()) :: Phoenix.LiveView.Rendered.t()
  def help_topic(assigns) do
    ~H"""
    <div>
      <.help_topic_header topic={@topic} />

      <article class={topic_article_class()}>
        {render_slot(@inner_block)}
      </article>

      <.see_also_section see_also={Map.get(@topic, :see_also, [])} />
    </div>
    """
  end

  @spec help_empty_state(map()) :: Phoenix.LiveView.Rendered.t()
  def help_empty_state(assigns) do
    ~H"""
    <div class="text-center py-12 text-muted-foreground">
      <Icons.icon_notepad class="w-8 h-8 mx-auto mb-3 opacity-50" />
      <h2 class="text-base font-bold mb-2 text-text">{dgettext("help", "RetroHexChat Help")}</h2>
      <p class="text-sm">
        {dgettext("help", "Select a topic from the navigation pane to get started.")}
      </p>
      <p class="text-xs mt-1">
        {dgettext("help", "Browse by category or open Help Topics from the chat menu.")}
      </p>
    </div>
    """
  end

  attr :see_also, :list, default: []

  @spec see_also_section(map()) :: Phoenix.LiveView.Rendered.t()
  def see_also_section(assigns) do
    assigns = assign(assigns, :related, resolve_related(assigns.see_also))

    ~H"""
    <section
      :if={@related != []}
      class="mt-6 pt-3 border-t border-gray-300"
      data-testid="help-see-also"
    >
      <h2 class="text-xs font-bold text-text mb-2 uppercase tracking-wide">
        {dgettext("help", "See Also")}
      </h2>
      <ul class="list-none m-0 p-0 flex flex-wrap gap-x-4 gap-y-1">
        <li :for={topic <- @related}>
          <.link
            navigate={help_topic_path(topic.id)}
            class="inline-flex items-center gap-1 text-xs text-link hover:underline no-underline"
          >
            {apply(Icons, topic.icon, [%{class: "w-3 h-3 shrink-0"}])}
            <span>{topic.title}</span>
          </.link>
        </li>
      </ul>
    </section>
    """
  end

  attr :query, :string, default: ""

  defp help_toolbar(assigns) do
    ~H"""
    <div
      id="help-toolbar"
      phx-hook="HelpNavHook"
      class="flex items-center gap-1 p-1 shrink-0 border-b border-separator"
    >
      <button
        type="button"
        data-help-nav="back"
        class={toolbar_btn_class()}
        title={dgettext("help", "Back")}
      >
        <Icons.icon_btn_prev class="w-4 h-4" />
      </button>
      <button
        type="button"
        data-help-nav="forward"
        class={toolbar_btn_class()}
        title={dgettext("help", "Forward")}
      >
        <Icons.icon_btn_next class="w-4 h-4" />
      </button>
      <.link navigate="/chat/help" class={toolbar_btn_class()} title={dgettext("help", "Home")}>
        <Icons.icon_hex_stone class="w-4 h-4" />
      </.link>

      <form phx-change="help_search" phx-submit="help_search" class="ml-auto flex-1 max-w-xs">
        <label class="flex items-center gap-1 shadow-retro-sunken bg-white px-1">
          <Icons.icon_btn_search class="w-3.5 h-3.5 shrink-0 text-muted-foreground" />
          <input
            type="text"
            name="q"
            value={@query}
            autocomplete="off"
            phx-debounce="150"
            placeholder={dgettext("help", "Search topics...")}
            class="flex-1 min-w-0 bg-transparent py-0.5 text-xs focus:outline-none"
            data-testid="help-search-input"
          />
        </label>
      </form>
    </div>
    """
  end

  attr :nav_tab, :atom, required: true
  attr :search_query, :string, required: true
  attr :search_results, :list, required: true
  attr :topics_by_category, :list, required: true
  attr :all_topics, :list, required: true
  attr :selected_topic, :map, default: nil

  defp help_navigator(assigns) do
    ~H"""
    <nav
      class="flex flex-col md:w-64 shrink-0 min-h-0"
      aria-label={dgettext("help", "Help navigation")}
    >
      <div class="flex shrink-0" role="tablist">
        <.nav_tab_button tab={:contents} active={@nav_tab} label={dgettext("help", "Contents")} />
        <.nav_tab_button tab={:index} active={@nav_tab} label={dgettext("help", "Index")} />
        <.nav_tab_button tab={:search} active={@nav_tab} label={dgettext("help", "Search")} />
      </div>

      <div class="shadow-retro-sunken bg-white flex-1 min-h-0 max-h-56 md:max-h-none overflow-y-auto p-1">
        <.tree_view :if={@nav_tab == :contents} class="!shadow-none !p-0 !bg-transparent">
          <.tree_view_group
            :for={{category, cat_icon, topics} <- @topics_by_category}
            label={category}
            open={@selected_topic != nil && @selected_topic.category == category}
          >
            <:icon>{apply(Icons, cat_icon, [%{class: "w-4 h-4"}])}</:icon>
            <.link
              :for={topic <- topics}
              navigate={help_topic_path(topic.id)}
              class="block no-underline"
            >
              <.tree_view_item active={@selected_topic != nil && @selected_topic.id == topic.id}>
                <:icon>{apply(Icons, topic.icon, [%{class: "w-3 h-3"}])}</:icon>
                {topic.title}
              </.tree_view_item>
            </.link>
          </.tree_view_group>
        </.tree_view>

        <ul :if={@nav_tab == :index} class="list-none m-0 p-0">
          <.nav_result_item
            :for={topic <- Enum.sort_by(@all_topics, & &1.title)}
            topic={topic}
            active={@selected_topic != nil && @selected_topic.id == topic.id}
          />
        </ul>

        <div :if={@nav_tab == :search}>
          <p :if={@search_query == ""} class="text-xs text-muted-foreground p-2">
            {dgettext("help", "Type in the search box to find topics.")}
          </p>
          <p
            :if={@search_query != "" && @search_results == []}
            class="text-xs text-muted-foreground p-2"
            data-testid="help-search-empty"
          >
            {dgettext("help", "No topics match \"%{query}\".", query: @search_query)}
          </p>
          <ul :if={@search_results != []} class="list-none m-0 p-0" data-testid="help-search-results">
            <.nav_result_item
              :for={topic <- @search_results}
              topic={topic}
              active={@selected_topic != nil && @selected_topic.id == topic.id}
            />
          </ul>
        </div>
      </div>
    </nav>
    """
  end

  attr :tab, :atom, required: true
  attr :active, :atom, required: true
  attr :label, :string, required: true

  defp nav_tab_button(assigns) do
    ~H"""
    <button
      type="button"
      role="tab"
      phx-click="help_nav_tab"
      phx-value-tab={@tab}
      aria-selected={to_string(@tab == @active)}
      data-testid={"help-tab-#{@tab}"}
      class={[
        "flex-1 px-2 py-0.5 text-xs border border-separator -mb-px cursor-pointer",
        if(@tab == @active,
          do: "bg-white font-bold border-b-white",
          else: "bg-surface hover:bg-hover-bg"
        )
      ]}
    >
      {@label}
    </button>
    """
  end

  attr :topic, :map, required: true
  attr :active, :boolean, default: false

  defp nav_result_item(assigns) do
    ~H"""
    <li>
      <.link
        navigate={help_topic_path(@topic.id)}
        class={[
          "flex items-center gap-1.5 px-2 py-1 no-underline text-xs",
          if(@active, do: "bg-selection-bg text-selection-fg", else: "hover:bg-hover-bg text-text")
        ]}
      >
        {apply(Icons, @topic.icon, [%{class: "w-3 h-3 shrink-0"}])}
        <span class="truncate">{@topic.title}</span>
      </.link>
    </li>
    """
  end

  attr :topic, :map, required: true

  defp help_topic_header(assigns) do
    ~H"""
    <div class="flex items-center gap-2 mb-3 pb-2 border-b border-gray-300">
      {apply(Icons, @topic.icon, [%{class: "w-6 h-6 flex-shrink-0"}])}
      <div>
        <h1 class="text-base font-bold text-text">{@topic.title}</h1>
        <nav aria-label={dgettext("help", "Breadcrumb")} class="text-xs text-muted-foreground">
          <.link navigate="/chat/help" class="hover:underline text-link">
            {dgettext("help", "Help")}
          </.link>
          {" > "}{@topic.category}{" > "}{@topic.title}
        </nav>
      </div>
    </div>
    """
  end

  attr :current_path, :string, required: true

  defp help_taskbar(assigns) do
    ~H"""
    <.taskbar>
      <:start>
        <.start_menu_app
          id="help-start-menu"
          screen={:help}
          current_path={@current_path}
          windows={[%{id: "help", label: dgettext("help", "Help"), icon_fn: :icon_notepad}]}
        />
      </:start>

      <.taskbar_button window="help" label={dgettext("help", "Help")}>
        <:icon><Icons.icon_notepad class="h-4 w-4" /></:icon>
      </.taskbar_button>

      <:tray>
        <.desktop_tray>
          <span id="help-tray-clock" data-clock phx-hook="ClockHook" class="font-mono tabular-nums">
          </span>
        </.desktop_tray>
      </:tray>
    </.taskbar>
    """
  end

  @spec resolve_related([String.t()]) :: [HelpTopics.topic()]
  defp resolve_related(ids) when is_list(ids) do
    ids
    |> Enum.map(&HelpTopics.get_topic/1)
    |> Enum.reject(&is_nil/1)
  end

  defp resolve_related(_ids), do: []

  defp toolbar_btn_class do
    "inline-flex items-center justify-center w-6 h-6 shadow-retro-raised bg-surface " <>
      "active:shadow-retro-sunken hover:bg-hover-bg cursor-pointer"
  end

  defp topic_article_class do
    [
      "text-sm leading-relaxed space-y-2",
      "[&_p]:my-1.5",
      "[&_pre]:bg-gray-100 [&_pre]:border [&_pre]:border-gray-300 [&_pre]:p-2 [&_pre]:text-xs [&_pre]:overflow-x-auto [&_pre]:my-2",
      "[&_code]:bg-gray-100 [&_code]:px-0.5 [&_code]:text-xs",
      "[&_ul]:list-disc [&_ul]:pl-5 [&_ul]:my-1",
      "[&_ol]:list-decimal [&_ol]:pl-5 [&_ol]:my-1",
      "[&_li]:my-0.5",
      "[&_table]:w-full [&_table]:border-collapse [&_table]:text-xs [&_table]:my-2",
      "[&_th]:border [&_th]:border-gray-300 [&_th]:bg-gray-50 [&_th]:px-2 [&_th]:py-1 [&_th]:text-left [&_th]:font-bold",
      "[&_td]:border [&_td]:border-gray-300 [&_td]:px-2 [&_td]:py-1"
    ]
  end

  defp help_topic_path(topic_id), do: "/chat/help/#{topic_id}"
end
