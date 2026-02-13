defmodule RetroHexChat.Chat.HelpTopics do
  @moduledoc """
  Static help content for the CHM-style help system.
  All topics are compiled at build time — no database required.

  Topics are organized into category modules under `HelpTopics.*`
  and aggregated here at compile time.
  """

  alias RetroHexChat.Chat.HelpTopics.{
    ChannelModes,
    Commands,
    Features,
    GettingStarted,
    KeyboardShortcuts,
    Services,
    SpecialMessages,
    TextFormatting,
    UserInterface
  }

  @type topic :: %{
          id: String.t(),
          title: String.t(),
          category: String.t(),
          keywords: [String.t()],
          content: String.t()
        }

  @categories [
    "Getting Started",
    "Commands",
    "Services",
    "Channel Modes",
    "Text Formatting",
    "Features",
    "User Interface",
    "Keyboard Shortcuts"
  ]

  @topics GettingStarted.topics() ++
            Commands.topics() ++
            Services.topics() ++
            ChannelModes.topics() ++
            TextFormatting.topics() ++
            Features.topics() ++
            SpecialMessages.topics() ++
            UserInterface.topics() ++
            KeyboardShortcuts.topics()

  @topic_map Map.new(@topics, &{&1.id, &1})

  @doc "Return all help topics."
  @spec all_topics() :: [topic()]
  def all_topics, do: @topics

  @doc "Look up a single topic by id. Returns nil if not found."
  @spec get_topic(String.t()) :: topic() | nil
  def get_topic(id), do: Map.get(@topic_map, id)

  @doc "Return topics grouped by category, in display order."
  @spec topics_by_category() :: [{String.t(), [topic()]}]
  def topics_by_category do
    Enum.map(@categories, fn cat ->
      {cat, Enum.filter(@topics, &(&1.category == cat))}
    end)
  end

  @doc "Search topics by query (case-insensitive match on title, keywords, content)."
  @spec search(String.t()) :: [topic()]
  def search(query) when byte_size(query) < 2, do: []

  def search(query) do
    q = String.downcase(query)

    Enum.filter(@topics, fn topic ->
      String.contains?(String.downcase(topic.title), q) or
        Enum.any?(topic.keywords, &String.contains?(String.downcase(&1), q)) or
        String.contains?(String.downcase(topic.content), q)
    end)
  end

  @doc "Return a sorted list of {keyword, topic_id} for the index tab."
  @spec all_keywords() :: [{String.t(), String.t()}]
  def all_keywords do
    @topics
    |> Enum.flat_map(fn topic ->
      Enum.map(topic.keywords, &{&1, topic.id})
    end)
    |> Enum.sort_by(&elem(&1, 0))
  end
end
