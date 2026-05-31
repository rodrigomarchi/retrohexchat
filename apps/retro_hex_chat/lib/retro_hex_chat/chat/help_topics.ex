defmodule RetroHexChat.Chat.HelpTopics do
  @moduledoc """
  Static help topic metadata for the CHM-style help system.
  All topics are compiled at build time — no database required.

  Topic content is rendered via HEEx templates in the web layer
  (`RetroHexChatWeb.HelpContent`). This module only holds metadata:
  id, title, category, keywords, icon, and description.

  Topics are organized into category modules under `HelpTopics.*`
  and aggregated here at runtime so locale changes are respected.
  """

  use Gettext, backend: RetroHexChat.Gettext

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
    gettext_noop("Getting Started") => :icon_lightbulb,
    gettext_noop("Chat & Messaging") => :icon_chat,
    gettext_noop("Users & Identity") => :icon_status_user,
    gettext_noop("Contacts & Notify") => :icon_dialog_address_book,
    gettext_noop("Channels") => :icon_channels,
    gettext_noop("Channel Settings") => :icon_dialog_channel_central,
    gettext_noop("Moderation") => :icon_ban,
    gettext_noop("Channel Modes") => :icon_tab_modes,
    gettext_noop("Services & Protocols") => :icon_lock,
    gettext_noop("Bots") => :icon_robot,
    gettext_noop("Admin & Server") => :icon_shield,
    gettext_noop("Server Messages") => :icon_megaphone,
    gettext_noop("Automation") => :icon_code,
    gettext_noop("Chat Input") => :icon_terminal,
    gettext_noop("Chat Display") => :icon_notepad,
    gettext_noop("Notifications & Sounds") => :icon_dialog_sound,
    gettext_noop("Settings & Preferences") => :icon_dialog_options,
    gettext_noop("User Interface") => :icon_laptop,
    gettext_noop("Text Formatting") => :icon_palette,
    gettext_noop("Connection") => :icon_websocket,
    gettext_noop("P2P & Calls") => :icon_p2p,
    gettext_noop("P2P Games: Action") => :icon_game_generic,
    gettext_noop("P2P Games: Sports") => :icon_game_tennis,
    gettext_noop("Solo Arcade: FPS") => :icon_game_arcade,
    gettext_noop("Solo Arcade: Adventures") => :icon_game_bass
  }

  @categories [
    gettext_noop("Getting Started"),
    gettext_noop("Chat & Messaging"),
    gettext_noop("Users & Identity"),
    gettext_noop("Contacts & Notify"),
    gettext_noop("Channels"),
    gettext_noop("Channel Settings"),
    gettext_noop("Moderation"),
    gettext_noop("Channel Modes"),
    gettext_noop("Services & Protocols"),
    gettext_noop("Bots"),
    gettext_noop("Admin & Server"),
    gettext_noop("Server Messages"),
    gettext_noop("Automation"),
    gettext_noop("Chat Input"),
    gettext_noop("Chat Display"),
    gettext_noop("Notifications & Sounds"),
    gettext_noop("Settings & Preferences"),
    gettext_noop("User Interface"),
    gettext_noop("Text Formatting"),
    gettext_noop("Connection"),
    gettext_noop("P2P & Calls"),
    gettext_noop("P2P Games: Action"),
    gettext_noop("P2P Games: Sports"),
    gettext_noop("Solo Arcade: FPS"),
    gettext_noop("Solo Arcade: Adventures")
  ]

  @doc "Return all help topics."
  @spec all_topics() :: [topic()]
  def all_topics, do: topics()

  @doc "Look up a single topic by id. Returns nil if not found."
  @spec get_topic(String.t()) :: topic() | nil
  def get_topic(id), do: Map.get(topic_map(), id)

  @doc "Return topics grouped by category, in display order. Each tuple includes the category icon."
  @spec topics_by_category() :: [{String.t(), atom(), [topic()]}]
  def topics_by_category do
    topic_list = topics()

    Enum.map(@categories, fn cat ->
      label = t(cat)
      {label, Map.fetch!(@category_icons, cat), Enum.filter(topic_list, &(&1.category == label))}
    end)
  end

  @doc "Return the icon atom for a category name."
  @spec category_icon(String.t()) :: atom()
  def category_icon(name) do
    name
    |> canonical_category()
    |> then(&Map.fetch!(@category_icons, &1))
  end

  @doc "Return a sorted list of {keyword, topic_id} for the index tab."
  @spec all_keywords() :: [{String.t(), String.t()}]
  def all_keywords do
    topics()
    |> Enum.flat_map(fn topic ->
      Enum.map(topic.keywords, &{&1, topic.id})
    end)
    |> Enum.sort_by(&elem(&1, 0))
  end

  defp topics do
    GettingStarted.topics() ++
      Commands.topics() ++
      Services.topics() ++
      Bots.topics() ++
      ChannelModes.topics() ++
      TextFormatting.topics() ++
      Features.topics() ++
      SpecialMessages.topics() ++
      UserInterface.topics() ++
      KeyboardShortcuts.topics()
  end

  defp topic_map, do: Map.new(topics(), &{&1.id, &1})

  defp canonical_category(name) do
    Enum.find(@categories, fn category ->
      name in [category, t(category)]
    end) || name
  end

  defp t(msgid), do: Gettext.gettext(RetroHexChat.Gettext, msgid)
end
