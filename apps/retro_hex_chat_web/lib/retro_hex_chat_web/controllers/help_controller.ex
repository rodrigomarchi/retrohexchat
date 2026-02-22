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

    selected_topic = resolve_topic(params)

    current_url =
      if selected_topic, do: "/chat/help/#{selected_topic.id}", else: "/chat/help"

    conn
    |> assign(:topics_by_category, topics_by_category)
    |> assign(:selected_topic, selected_topic)
    |> assign(:page_title, page_title(selected_topic))
    |> assign(:page_description, page_description(selected_topic))
    |> assign(:breadcrumbs, breadcrumbs(selected_topic))
    |> assign(:current_url, current_url)
    |> render(:index)
  end

  @default_topic "welcome"

  @spec resolve_topic(map()) :: map() | nil
  defp resolve_topic(%{"topic" => topic_id}) do
    HelpTopics.get_topic(topic_id) || HelpTopics.get_topic(@default_topic)
  end

  defp resolve_topic(_params), do: HelpTopics.get_topic(@default_topic)

  @spec page_title(map() | nil) :: String.t()
  defp page_title(nil), do: "Help - RetroHexChat"
  defp page_title(topic), do: "#{topic.title} - RetroHexChat Help"

  @spec page_description(map() | nil) :: String.t()
  defp page_description(nil) do
    "RetroHexChat help documentation. Learn about IRC commands, " <>
      "channel modes, features, and keyboard shortcuts."
  end

  defp page_description(topic), do: topic.description

  @spec breadcrumbs(map() | nil) :: [{String.t(), String.t() | nil}]
  defp breadcrumbs(nil), do: [{"Help", nil}]

  defp breadcrumbs(topic) do
    [
      {"Help", ~p"/chat/help"},
      {topic.category, nil},
      {topic.title, nil}
    ]
  end
end
