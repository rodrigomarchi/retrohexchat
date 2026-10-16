defmodule RetroHexChatWeb.Site.HelpViewer do
  @moduledoc """
  The help viewer inside its document window: which tab of the navigator is
  open and what is being searched.

  A live component rather than state on the desktop, so the viewer's own
  controls reach it directly (`phx-target`): for a visitor the desktop's gate
  never sees them, and reading the help is something everybody may do. Which
  topic is shown is the address's business — the desktop passes it in from
  `Site.Pages.Help`.
  """
  use Phoenix.LiveComponent

  import RetroHexChatWeb.Components.UI.Help.HelpViewer
  import RetroHexChatWeb.HelpLive.HelpHelpers, only: [render_topic_content: 1]

  alias RetroHexChat.Chat.HelpTopics

  @impl true
  def mount(socket) do
    all_topics = HelpTopics.all_topics()

    {:ok,
     assign(socket,
       topics_by_category: HelpTopics.topics_by_category(),
       all_topics: all_topics,
       nav_tab: :contents,
       search_query: "",
       search_results: []
     )}
  end

  @impl true
  def handle_event("help_nav_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :nav_tab, parse_tab(tab))}
  end

  def handle_event("help_search", %{"q" => query}, socket) do
    {:noreply,
     assign(socket,
       search_query: query,
       search_results: HelpTopics.search(query),
       nav_tab: if(String.trim(query) == "", do: socket.assigns.nav_tab, else: :search)
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} class="contents">
      <.help_window_body
        topics_by_category={@topics_by_category}
        all_topics={@all_topics}
        selected_topic={@selected_topic}
        nav_tab={@nav_tab}
        search_query={@search_query}
        search_results={@search_results}
        full_tree={@full_tree}
        target={@myself}
      >
        <.help_topic :if={@selected_topic} topic={@selected_topic}>
          <.render_topic_content id={@selected_topic.id} />
        </.help_topic>

        <.help_empty_state :if={!@selected_topic} />
      </.help_window_body>
    </div>
    """
  end

  defp parse_tab("index"), do: :index
  defp parse_tab("search"), do: :search
  defp parse_tab(_tab), do: :contents
end
