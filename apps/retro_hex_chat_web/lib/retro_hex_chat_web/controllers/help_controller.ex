defmodule RetroHexChatWeb.HelpController do
  @moduledoc """
  Serves the dedicated help page at `/chat/help`.

  This is a standard Phoenix controller (not LiveView) to save WebSocket
  connections — help is read-only content that doesn't need real-time updates.
  """
  use RetroHexChatWeb, :controller

  alias RetroHexChat.Chat.HelpTopics

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    topics_by_category = HelpTopics.topics_by_category()
    all_keywords = HelpTopics.all_keywords()

    {selected_topic, search_results} = resolve_params(params)

    active_tab = if params["q"], do: "search", else: "contents"

    current_url =
      if params["topic"], do: "/chat/help?topic=#{params["topic"]}", else: "/chat/help"

    conn
    |> assign(:topics_by_category, topics_by_category)
    |> assign(:all_keywords, all_keywords)
    |> assign(:selected_topic, selected_topic)
    |> assign(:search_results, search_results)
    |> assign(:search_query, params["q"] || "")
    |> assign(:active_tab, active_tab)
    |> assign(:page_title, page_title(selected_topic))
    |> assign(:page_description, page_description(selected_topic))
    |> assign(:breadcrumbs, breadcrumbs(selected_topic))
    |> assign(:current_url, current_url)
    |> render(:index)
  end

  @spec resolve_params(map()) :: {map() | nil, [map()]}
  defp resolve_params(%{"topic" => topic_id}) do
    {HelpTopics.get_topic(topic_id), []}
  end

  defp resolve_params(%{"q" => query}) when byte_size(query) >= 2 do
    {nil, HelpTopics.search(query)}
  end

  defp resolve_params(_params), do: {nil, []}

  @spec page_title(map() | nil) :: String.t()
  defp page_title(nil), do: "Help - RetroHexChat"
  defp page_title(topic), do: "#{topic.title} - RetroHexChat Help"

  @spec page_description(map() | nil) :: String.t()
  defp page_description(nil) do
    "RetroHexChat help documentation. Learn about IRC commands, " <>
      "channel modes, features, and keyboard shortcuts."
  end

  defp page_description(topic) do
    topic.content
    |> String.replace(~r/<[^>]+>/, "")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
    |> String.slice(0, 160)
  end

  @spec breadcrumbs(map() | nil) :: [{String.t(), String.t() | nil}]
  defp breadcrumbs(nil), do: [{"Help", nil}]

  defp breadcrumbs(topic) do
    [
      {"Help", "/chat/help"},
      {topic.category, nil},
      {topic.title, nil}
    ]
  end
end
