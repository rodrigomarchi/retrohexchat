defmodule RetroHexChatWeb.Site.Pages.Help do
  @moduledoc """
  The help, at `/chat/help` and `/chat/help/:topic`: a CHM-style viewer in a
  document window of its own, so reading it keeps whatever page or
  conversation it was opened from.

  Every topic is an address, and every topic is indexed as an article with its
  breadcrumb. The welcome topic is the help's home and has no address of its
  own: asking for it, or for a topic that does not exist, goes home.
  """
  use RetroHexChatWeb.Site.Page

  alias RetroHexChat.Chat.HelpTopics
  alias RetroHexChatWeb.{I18n, SEO}

  @default_topic "welcome"

  @impl RetroHexChatWeb.Site.Page
  def slot, do: :help

  @impl RetroHexChatWeb.Site.Page
  def load(params, ctx) do
    case resolve_topic(params) do
      {:ok, topic, canonical_path} ->
        title = page_title(topic)

        {:ok,
         %{
           selected_topic: topic,
           # Before the socket connects only the open category lists its
           # topics: the first HTML is what a search engine reads, and every
           # title repeated on every topic page outweighs the topic itself.
           full_tree: Map.get(ctx, :connected?, false) or topic.id == @default_topic,
           window_title: dgettext("help", "Help — RetroHexChat"),
           window_icon: :icon_notepad,
           menu: :help,
           windows: [],
           page_title: title,
           page_description: topic.description,
           canonical_path: canonical_path,
           og_type: "article",
           json_ld: [
             SEO.breadcrumb_json_ld(breadcrumb_items(topic, canonical_path)),
             SEO.tech_article_json_ld(title, topic.description, canonical_path)
           ]
         }}

      {:redirect, path} ->
        {:redirect, path}
    end
  end

  @impl RetroHexChatWeb.Site.Page
  def render(assigns) do
    ~H"""
    <.live_component
      module={RetroHexChatWeb.Site.HelpViewer}
      id="help-viewer"
      selected_topic={@selected_topic}
      full_tree={@full_tree}
    />
    """
  end

  defp resolve_topic(%{"topic" => @default_topic}), do: {:redirect, help_root_path()}

  defp resolve_topic(%{"topic" => topic_id}) do
    case HelpTopics.get_topic(topic_id) do
      nil -> {:redirect, help_root_path()}
      topic -> {:ok, topic, "/chat/help/#{topic.id}"}
    end
  end

  defp resolve_topic(_params), do: {:ok, HelpTopics.get_topic(@default_topic), "/chat/help"}

  defp help_root_path, do: SEO.localized_path("/chat/help", I18n.current_locale())

  # The trail names and links each step in the reader's language, like every
  # other public page's.
  defp breadcrumb_items(%{id: @default_topic}, _canonical_path) do
    [{dgettext("help", "Home"), localized("/")}, {dgettext("help", "Help"), help_root_path()}]
  end

  defp breadcrumb_items(topic, canonical_path) do
    breadcrumb_items(%{id: @default_topic}, canonical_path) ++
      [{topic.title, localized(canonical_path)}]
  end

  defp localized(path), do: SEO.localized_path(path, I18n.current_locale())

  defp page_title(topic), do: dgettext("help", "%{topic} — RetroHexChat Help", topic: topic.title)
end
