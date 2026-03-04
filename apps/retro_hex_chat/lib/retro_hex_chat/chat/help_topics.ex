defmodule RetroHexChat.Chat.HelpTopics do
  @moduledoc """
  Static help topic metadata for the CHM-style help system.
  All topics are compiled at build time — no database required.

  Topic content is rendered via HEEx templates in the web layer
  (`RetroHexChatWeb.HelpContent`). This module only holds metadata:
  id, title, category, keywords, icon, and description.

  Topics are organized into category modules under `HelpTopics.*`
  and aggregated here at compile time.
  """

  alias RetroHexChat.Chat.HelpTopics.{
    Bots,
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
          icon: atom(),
          description: String.t()
        }

  @category_icons %{
    "Getting Started" => :icon_lightbulb,
    "Chat & Messaging" => :icon_chat,
    "Users & Identity" => :icon_status_user,
    "Contacts & Notify" => :icon_dialog_address_book,
    "Channels" => :icon_channels,
    "Channel Settings" => :icon_dialog_channel_central,
    "Moderation" => :icon_ban,
    "Channel Modes" => :icon_tab_modes,
    "Services & Protocols" => :icon_lock,
    "Bots" => :icon_robot,
    "Admin & Server" => :icon_shield,
    "Server Messages" => :icon_megaphone,
    "Automation" => :icon_code,
    "Chat Input" => :icon_terminal,
    "Chat Display" => :icon_notepad,
    "Notifications & Sounds" => :icon_dialog_sound,
    "Settings & Preferences" => :icon_dialog_options,
    "User Interface" => :icon_laptop,
    "Text Formatting" => :icon_palette,
    "Connection" => :icon_websocket,
    "P2P & Calls" => :icon_p2p,
    "P2P Games: Action" => :icon_game_generic,
    "P2P Games: Sports" => :icon_game_tennis,
    "Solo Arcade" => :icon_game_arcade
  }

  @categories [
    "Getting Started",
    "Chat & Messaging",
    "Users & Identity",
    "Contacts & Notify",
    "Channels",
    "Channel Settings",
    "Moderation",
    "Channel Modes",
    "Services & Protocols",
    "Bots",
    "Admin & Server",
    "Server Messages",
    "Automation",
    "Chat Input",
    "Chat Display",
    "Notifications & Sounds",
    "Settings & Preferences",
    "User Interface",
    "Text Formatting",
    "Connection",
    "P2P & Calls",
    "P2P Games: Action",
    "P2P Games: Sports",
    "Solo Arcade"
  ]

  @topics GettingStarted.topics() ++
            Commands.topics() ++
            Services.topics() ++
            Bots.topics() ++
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

  @doc "Return topics grouped by category, in display order. Each tuple includes the category icon."
  @spec topics_by_category() :: [{String.t(), atom(), [topic()]}]
  def topics_by_category do
    Enum.map(@categories, fn cat ->
      {cat, Map.fetch!(@category_icons, cat), Enum.filter(@topics, &(&1.category == cat))}
    end)
  end

  @doc "Return the icon atom for a category name."
  @spec category_icon(String.t()) :: atom()
  def category_icon(name), do: Map.fetch!(@category_icons, name)

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
