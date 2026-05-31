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
    dgettext_noop("help", "Getting Started") => :icon_lightbulb,
    dgettext_noop("help", "Chat & Messaging") => :icon_chat,
    dgettext_noop("help", "Users & Identity") => :icon_status_user,
    dgettext_noop("help", "Contacts & Notify") => :icon_dialog_address_book,
    dgettext_noop("help", "Channels") => :icon_channels,
    dgettext_noop("help", "Channel Settings") => :icon_dialog_channel_central,
    dgettext_noop("help", "Moderation") => :icon_ban,
    dgettext_noop("help", "Channel Modes") => :icon_tab_modes,
    dgettext_noop("help", "Services & Protocols") => :icon_lock,
    dgettext_noop("help", "Bots") => :icon_robot,
    dgettext_noop("help", "Admin & Server") => :icon_shield,
    dgettext_noop("help", "Server Messages") => :icon_megaphone,
    dgettext_noop("help", "Automation") => :icon_code,
    dgettext_noop("help", "Chat Input") => :icon_terminal,
    dgettext_noop("help", "Chat Display") => :icon_notepad,
    dgettext_noop("help", "Notifications & Sounds") => :icon_dialog_sound,
    dgettext_noop("help", "Settings & Preferences") => :icon_dialog_options,
    dgettext_noop("help", "User Interface") => :icon_laptop,
    dgettext_noop("help", "Text Formatting") => :icon_palette,
    dgettext_noop("help", "Connection") => :icon_websocket,
    dgettext_noop("help", "P2P & Calls") => :icon_p2p,
    dgettext_noop("help", "P2P Games: Action") => :icon_game_generic,
    dgettext_noop("help", "P2P Games: Sports") => :icon_game_tennis,
    dgettext_noop("help", "Solo Arcade: FPS") => :icon_game_arcade,
    dgettext_noop("help", "Solo Arcade: Adventures") => :icon_game_bass
  }

  @categories [
    dgettext_noop("help", "Getting Started"),
    dgettext_noop("help", "Chat & Messaging"),
    dgettext_noop("help", "Users & Identity"),
    dgettext_noop("help", "Contacts & Notify"),
    dgettext_noop("help", "Channels"),
    dgettext_noop("help", "Channel Settings"),
    dgettext_noop("help", "Moderation"),
    dgettext_noop("help", "Channel Modes"),
    dgettext_noop("help", "Services & Protocols"),
    dgettext_noop("help", "Bots"),
    dgettext_noop("help", "Admin & Server"),
    dgettext_noop("help", "Server Messages"),
    dgettext_noop("help", "Automation"),
    dgettext_noop("help", "Chat Input"),
    dgettext_noop("help", "Chat Display"),
    dgettext_noop("help", "Notifications & Sounds"),
    dgettext_noop("help", "Settings & Preferences"),
    dgettext_noop("help", "User Interface"),
    dgettext_noop("help", "Text Formatting"),
    dgettext_noop("help", "Connection"),
    dgettext_noop("help", "P2P & Calls"),
    dgettext_noop("help", "P2P Games: Action"),
    dgettext_noop("help", "P2P Games: Sports"),
    dgettext_noop("help", "Solo Arcade: FPS"),
    dgettext_noop("help", "Solo Arcade: Adventures")
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

  defp t(msgid), do: Gettext.dgettext(RetroHexChat.Gettext, "help", msgid)
end
