defmodule RetroHexChatWeb.Components.UI.Help.HelpViewer do
  @moduledoc """
  Visual composition for the CHM-style help viewer.

  `RetroHexChatWeb.Site.HelpViewer` owns navigation and search state. This
  module owns the viewer's toolbar, navigator, topic frame and empty state; the
  help is a document window on the one desktop, so its menus hang under that
  window's title bar and the topic it shows is reported along its bottom edge,
  the way a CHM viewer did.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Inset
  import RetroHexChatWeb.Components.UI.ToolButton
  import RetroHexChatWeb.Components.UI.TreeView

  alias RetroHexChat.Chat.HelpTopics
  alias RetroHexChatWeb.Components.UI.Landing.GameCards
  alias RetroHexChatWeb.GameCatalog
  alias RetroHexChatWeb.HelpLive.ContentIndex
  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.PublicPages

  attr :topics_by_category, :list, required: true
  attr :all_topics, :list, default: []
  attr :selected_topic, :map, default: nil
  attr :nav_tab, :atom, default: :contents
  attr :search_query, :string, default: ""
  attr :search_results, :list, default: []
  attr :target, :any, default: nil, doc: "the live component the toolbar and tabs talk to"

  attr :full_tree, :boolean,
    default: true,
    doc: "every category's topics in the contents tree, or only the open category's"

  slot :inner_block, required: true

  @doc """
  The viewer inside the help's document window: toolbar, navigator and the
  topic. The window around it carries the viewer's menus and status zones
  (`help_menu_bar/1`, `help_status_zones/1`).
  """
  @spec help_window_body(map()) :: Phoenix.LiveView.Rendered.t()
  def help_window_body(assigns) do
    ~H"""
    <div class="flex flex-col h-full" data-testid="help-window">
      <.help_toolbar query={@search_query} target={@target} />

      <div class="flex flex-col md:flex-row flex-1 min-h-0 gap-1 p-1">
        <.help_navigator
          nav_tab={@nav_tab}
          search_query={@search_query}
          search_results={@search_results}
          topics_by_category={@topics_by_category}
          all_topics={@all_topics}
          selected_topic={@selected_topic}
          full_tree={@full_tree}
          target={@target}
        />

        <main
          class="shadow-retro-sunken bg-white flex-1 min-h-0 overflow-y-auto p-6"
          data-testid="help-content-pane"
        >
          {render_slot(@inner_block)}
        </main>
      </div>
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

      <%!-- The description is the topic in one sentence, shown first unless
            the topic's own text already opens by saying it. --%>
      <p
        :if={!ContentIndex.description_repeats_opening?(@topic.id)}
        class="text-sm text-text mb-3"
        data-testid="help-topic-description"
      >
        {@topic.description}
      </p>

      <article class={topic_article_class()}>
        {render_slot(@inner_block)}
      </article>

      <.help_catalogue_link topic_id={@topic.id} />
      <.help_mirc_link :if={@topic.id == "commands-overview"} />

      <.see_also_section topic_id={@topic.id} see_also={Map.get(@topic, :see_also, [])} />
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

  attr :topic_id, :string, required: true

  # A game's help page teaches how to play it; its catalogue page is where it
  # is shown off, and this is the way from one to the other.
  defp help_catalogue_link(assigns) do
    assigns = assign(assigns, :path, catalogue_path(assigns.topic_id))

    ~H"""
    <GameCards.catalogue_link
      :if={@path}
      path={@path}
      class="mt-4 text-xs"
      data-testid="help-catalogue-link"
    >
      {dgettext("help", "Screenshots and more games in the games catalogue")}
    </GameCards.catalogue_link>
    """
  end

  # The overview lists this chat's commands; a reader arriving from mIRC wants
  # the other question answered — which of theirs still work — and that page
  # is public, so it is linked rather than repeated here.
  defp help_mirc_link(assigns) do
    assigns =
      assign(assigns, :path, PublicPages.localized_path(PublicPages.path(:mirc_commands)))

    ~H"""
    <p class="mt-4 text-xs">
      <.link
        patch={@path}
        class="inline-flex items-center gap-1 underline"
        data-testid="help-mirc-link"
      >
        <Icons.icon_terminal class="w-3 h-3 shrink-0" />
        {dgettext("help", "Coming from mIRC? See which of its commands work the same here")}
      </.link>
    </p>
    """
  end

  # Every topic about the games leads to the catalogue: a game's own topic to
  # its page, the Arcade, an engine and the Retro Games to the whole catalogue.
  defp catalogue_path(topic_id) when topic_id in ~w(feature-retro-games feature-arcade),
    do: PublicPages.localized_path("/games")

  defp catalogue_path(topic_id) do
    case Enum.find(GameCatalog.list(), &(&1.help_topic == topic_id)) do
      %{} = game -> PublicPages.localized_path(GameCatalog.page_path(game))
      nil -> engine_catalogue_path(topic_id)
    end
  end

  defp engine_catalogue_path("feature-arcade-" <> _engine),
    do: PublicPages.localized_path("/games")

  defp engine_catalogue_path(_topic_id), do: nil

  # The topics a body lists from the catalogue (`help_game_list`) rather than
  # writing out, which the template scan cannot see.
  defp listed("feature-arcade"), do: help_topics(:arcade)
  defp listed("feature-retro-games"), do: help_topics(:multiplayer)
  defp listed(_topic_id), do: MapSet.new()

  defp help_topics(kind), do: kind |> GameCatalog.list() |> MapSet.new(& &1.help_topic)

  attr :topic_id, :string, default: nil
  attr :see_also, :list, default: []

  # One "See Also" per page. The topics the body already links are left out;
  # when the body ends with its own See Also, the rest continue it without a
  # second heading.
  @spec see_also_section(map()) :: Phoenix.LiveView.Rendered.t()
  def see_also_section(assigns) do
    linked =
      if assigns.topic_id,
        do: MapSet.union(ContentIndex.body_links(assigns.topic_id), listed(assigns.topic_id)),
        else: MapSet.new()

    assigns =
      assigns
      |> assign(:related, assigns.see_also |> Enum.reject(&(&1 in linked)) |> resolve_related())
      |> assign(:continues?, assigns.topic_id != nil and ContentIndex.see_also?(assigns.topic_id))

    ~H"""
    <section
      :if={@related != []}
      class={if @continues?, do: "mt-1", else: "mt-6 pt-3 border-t border-gray-300"}
      data-testid="help-see-also"
    >
      <h2 :if={!@continues?} class="text-xs font-bold text-text mb-2">
        {dgettext("help", "See Also")}
      </h2>
      <ul class="list-none m-0 p-0 flex flex-wrap gap-x-4 gap-y-1">
        <li :for={topic <- @related}>
          <.link
            patch={PublicPages.help_topic_path(topic.id)}
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
  attr :target, :any, default: nil

  defp help_toolbar(assigns) do
    ~H"""
    <div
      id="help-toolbar"
      phx-hook="HelpNavHook"
      class="flex items-center gap-1 p-1 shrink-0 border-b border-separator"
    >
      <.tool_button label={dgettext("help", "Back")} size="sm" data-help-nav="back">
        <Icons.icon_btn_prev class="w-4 h-4" />
      </.tool_button>
      <.tool_button label={dgettext("help", "Forward")} size="sm" data-help-nav="forward">
        <Icons.icon_btn_next class="w-4 h-4" />
      </.tool_button>
      <.link
        patch={PublicPages.localized_path("/chat/help")}
        class={tool_button_class(size: "sm")}
        title={dgettext("help", "Home")}
        aria-label={dgettext("help", "Home")}
      >
        <Icons.icon_hex_stone class="w-4 h-4" />
      </.link>

      <form
        phx-change="help_search"
        phx-submit="help_search"
        phx-target={@target}
        class="ml-auto flex-1 max-w-xs"
      >
        <label class="flex items-center gap-1 shadow-retro-sunken bg-white px-1">
          <Icons.icon_btn_search class="w-3.5 h-3.5 shrink-0 text-muted-foreground" />
          <input
            type="text"
            name="q"
            value={@query}
            autocomplete="off"
            phx-debounce="150"
            placeholder={dgettext("help", "Search topics...")}
            class="flex-1 min-w-0 bg-transparent py-0.5 text-xs"
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
  attr :full_tree, :boolean, default: true
  attr :target, :any, default: nil

  # Before the socket connects only the open category lists its topics: the
  # first HTML is what a search engine reads, and 297 titles repeated on every
  # topic page outweigh the topic itself. The help home keeps the whole tree,
  # one step from every topic; once connected every page has it.
  defp help_navigator(assigns) do
    ~H"""
    <nav
      class="flex flex-col md:w-64 shrink-0 min-h-0"
      aria-label={dgettext("help", "Help navigation")}
    >
      <div class="flex shrink-0" role="tablist">
        <.nav_tab_button
          tab={:contents}
          active={@nav_tab}
          target={@target}
          label={dgettext("help", "Contents")}
        />
        <.nav_tab_button
          tab={:index}
          active={@nav_tab}
          target={@target}
          label={dgettext("help", "Index")}
        />
        <.nav_tab_button
          tab={:search}
          active={@nav_tab}
          target={@target}
          label={dgettext("help", "Search")}
        />
      </div>

      <.inset bevel="sunken" tone="paper" class="flex-1 min-h-0 max-h-56 md:max-h-none overflow-y-auto p-1">
        <.tree_view :if={@nav_tab == :contents} class="!shadow-none !p-0 !bg-transparent">
          <.tree_view_group
            :for={{category, cat_icon, topics} <- @topics_by_category}
            label={category}
            open={@selected_topic != nil && @selected_topic.category == category}
          >
            <:icon>{apply(Icons, cat_icon, [%{class: "w-4 h-4"}])}</:icon>
            <.link
              :for={topic <- tree_topics(@full_tree, @selected_topic, category, topics)}
              patch={PublicPages.help_topic_path(topic.id)}
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
      </.inset>
    </nav>
    """
  end

  defp tree_topics(true, _selected, _category, topics), do: topics
  defp tree_topics(false, %{category: category}, category, topics), do: topics
  defp tree_topics(false, _selected, _category, _topics), do: []

  attr :tab, :atom, required: true
  attr :active, :atom, required: true
  attr :label, :string, required: true
  attr :target, :any, default: nil

  defp nav_tab_button(assigns) do
    ~H"""
    <button
      type="button"
      role="tab"
      phx-click="help_nav_tab"
      phx-value-tab={@tab}
      phx-target={@target}
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
        patch={PublicPages.help_topic_path(@topic.id)}
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
          <.link patch={PublicPages.localized_path("/chat/help")} class="hover:underline text-link">
            {dgettext("help", "Help")}
          </.link>
          {" > "}{@topic.category}{" > "}{@topic.title}
        </nav>
      </div>
    </div>
    """
  end

  defp resolve_related(ids) do
    ids
    |> Enum.map(&HelpTopics.get_topic/1)
    |> Enum.reject(&is_nil/1)
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
end
