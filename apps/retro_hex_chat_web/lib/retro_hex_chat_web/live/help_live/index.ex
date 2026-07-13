defmodule RetroHexChatWeb.HelpLive.Index do
  @moduledoc """
  Help system LiveView at `/chat/help` and `/chat/help/:topic`.

  Topic navigation uses LiveView navigate for instant client-side
  switching without full page reloads.
  """
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.HelpLive.HelpHelpers

  alias RetroHexChat.Chat.HelpTopics
  @default_topic "welcome"

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    all_topics = HelpTopics.all_topics()

    {:ok,
     assign(socket,
       topics_by_category: HelpTopics.topics_by_category(),
       all_topics: all_topics,
       topic_count: length(all_topics),
       nav_tab: :contents,
       search_query: "",
       search_results: []
     )}
  end

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
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

  def handle_event("help_back_to_chat", _params, socket) do
    {:noreply, redirect(socket, to: "/chat")}
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  @impl true
  @spec handle_params(map(), String.t(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_params(params, _uri, socket) do
    selected_topic = resolve_topic(params)

    canonical_path =
      if selected_topic, do: "/chat/help/#{selected_topic.id}", else: "/chat/help"

    {:noreply,
     socket
     |> assign(:selected_topic, selected_topic)
     |> assign(:page_title, page_title(selected_topic))
     |> assign(:page_description, page_description(selected_topic))
     |> assign(:canonical_path, canonical_path)}
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <.help_layout
      topics_by_category={@topics_by_category}
      all_topics={@all_topics}
      topic_count={@topic_count}
      selected_topic={@selected_topic}
      nav_tab={@nav_tab}
      search_query={@search_query}
      search_results={@search_results}
      canonical_path={@canonical_path}
    >
      <.help_topic :if={@selected_topic} topic={@selected_topic}>
        <.render_topic_content id={@selected_topic.id} />
      </.help_topic>

      <.help_empty_state :if={!@selected_topic} />
    </.help_layout>
    """
  end

  # ── Private ────────────────────────────────────────────────

  @spec parse_tab(String.t()) :: :contents | :index | :search
  defp parse_tab("index"), do: :index
  defp parse_tab("search"), do: :search
  defp parse_tab(_tab), do: :contents

  @spec resolve_topic(map()) :: map() | nil
  defp resolve_topic(%{"topic" => topic_id}) do
    HelpTopics.get_topic(topic_id) || HelpTopics.get_topic(@default_topic)
  end

  defp resolve_topic(_params), do: HelpTopics.get_topic(@default_topic)

  @spec page_title(map() | nil) :: String.t()
  defp page_title(nil), do: dgettext("help", "Help — RetroHexChat")
  defp page_title(topic), do: dgettext("help", "%{topic} — RetroHexChat Help", topic: topic.title)

  @spec page_description(map() | nil) :: String.t()
  defp page_description(nil) do
    dgettext(
      "help",
      "RetroHexChat help documentation. Learn about IRC commands, channel modes, features, and keyboard shortcuts."
    )
  end

  defp page_description(topic), do: topic.description
end
