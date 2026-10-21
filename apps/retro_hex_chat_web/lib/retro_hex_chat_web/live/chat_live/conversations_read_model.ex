defmodule RetroHexChatWeb.ChatLive.ConversationsReadModel do
  @moduledoc """
  Read-model helpers for the conversations sidebar.

  This module keeps the sidebar on top of the existing IRC channel directory.
  Rooms the session is not in are offered in two kinds of section: one per
  featured subject — games, news — and, below them, the popular channels about
  anything else. Every suggestion is a public room one click gets you into.
  """

  import Phoenix.Component, only: [assign: 2]

  alias RetroHexChat.Chat.AutoJoinList
  alias RetroHexChat.Commands.Autocomplete
  alias RetroHexChat.Games.Channels, as: GameChannels

  @max_popular_channels 10

  # The subjects with a section of their own, in the order the sidebar draws
  # them. Games come first because they are what brings most people here, and a
  # game's room is the place to go for it even when nobody is in it yet; a news
  # room with nobody in it is only yesterday's.
  @featured [
    %{category: "games", limit: 6, empty_rooms?: true, by_language?: false},
    %{category: "news", limit: 5, empty_rooms?: false, by_language?: true}
  ]

  @featured_categories Enum.map(@featured, & &1.category)

  # Three rooms is the line between somebody finding their way in and somebody
  # who lives here: below it the suggestions are the point of the sidebar, at
  # it they are rows of something you already solved.
  @discovery_room_threshold 3

  @typedoc "A featured subject's section: its category and the rooms it offers."
  @type featured_section :: %{category: String.t(), channels: [map()]}

  @spec touch_channel_activity(Phoenix.LiveView.Socket.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  def touch_channel_activity(socket, channel_name) when is_binary(channel_name) do
    next_sequence = Map.get(socket.assigns, :channel_activity_sequence, 0) + 1
    activity_order = Map.get(socket.assigns, :channel_activity_order, %{})

    assign(socket,
      channel_activity_sequence: next_sequence,
      channel_activity_order: Map.put(activity_order, channel_name, next_sequence)
    )
  end

  def touch_channel_activity(socket, _channel_name), do: socket

  @spec drop_channel_activity(Phoenix.LiveView.Socket.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  def drop_channel_activity(socket, channel_name) when is_binary(channel_name) do
    activity_order = Map.get(socket.assigns, :channel_activity_order, %{})

    assign(socket, channel_activity_order: Map.delete(activity_order, channel_name))
  end

  def drop_channel_activity(socket, _channel_name), do: socket

  @doc """
  Whether the suggestions open by themselves for `session`: while it has
  fewer than three rooms, counting the ones its account joins on connect —
  those arrive a moment after the mount, and somebody who has them is not
  arriving.
  """
  @spec discovery_open?(map()) :: boolean()
  def discovery_open?(session) do
    saved =
      session
      |> Map.get(:autojoin_list)
      |> Kernel.||(AutoJoinList.new())
      |> AutoJoinList.entries()
      |> Enum.map(& &1.channel_name)

    (session.channels ++ saved)
    |> Enum.map(&String.downcase/1)
    |> Enum.uniq()
    |> length() < @discovery_room_threshold
  end

  @doc """
  Opens or shuts the suggestion sections by `discovery_open?/1`, once the
  session knows its rooms. Games stay as they are: they are open for everybody
  until somebody closes them.
  """
  @spec settle_discovery_sections(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def settle_discovery_sections(socket) do
    open? = discovery_open?(socket.assigns.session)
    sections = Map.merge(socket.assigns.conversations_sections, %{news: open?, popular: open?})
    assign(socket, conversations_sections: sections)
  end

  @doc "The subjects that get a section of their own, in the order they are drawn."
  @spec featured_categories() :: [String.t()]
  def featured_categories, do: @featured_categories

  @doc """
  Reads the channel directory once and fills every suggestion section:
  `featured_channels`, one per featured subject, and `popular_channels`.
  """
  @spec load_discovery(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def load_discovery(socket) do
    joined = socket.assigns.session.channels

    joined
    |> Autocomplete.list_visible_channels()
    |> suggestions(joined, socket.assigns[:locale])
    |> then(&assign(socket, &1))
  end

  @doc """
  Every suggestion section out of one directory listing, for a reader of
  `locale` in `joined_names`: the featured subjects' sections, and the popular
  channels about anything else. A room about a featured subject is never a
  popular suggestion too — its section, and its "see more", is where it is.
  """
  @spec suggestions([map()], [String.t()], String.t() | nil) :: %{
          featured_channels: [featured_section()],
          popular_channels: [map()]
        }
  def suggestions(channels, joined_names, locale) do
    %{
      featured_channels: featured_channels(channels, joined_names, locale),
      popular_channels:
        channels
        |> Enum.reject(&(Map.get(&1, :category) in @featured_categories))
        |> popular_channels(joined_names)
    }
  end

  @doc """
  The featured subjects' sections out of a channel directory listing, for a
  reader of `locale`.

  Each offers the public rooms about its subject the session is not in: its
  lead room first (`#retro-games` for games), then — where the subject is read
  in a language — the rooms in the reader's, then the busiest, then the most
  recently used. A section with nothing to offer is still returned, empty.
  """
  @spec featured_channels([map()], [String.t()], String.t() | nil) :: [featured_section()]
  def featured_channels(channels, joined_names, locale) do
    candidates = suggestible(channels, joined_names)

    Enum.map(@featured, fn spec ->
      rooms =
        candidates
        |> Enum.filter(&(Map.get(&1, :category) == spec.category))
        |> Enum.filter(&(spec.empty_rooms? or occupied?(&1)))
        |> Enum.map(&Map.put(&1, :lead?, &1.name == lead(spec.category)))
        |> Enum.sort_by(&featured_rank(&1, spec, locale))
        |> Enum.take(spec.limit)

      %{category: spec.category, channels: rooms}
    end)
  end

  @doc """
  Picks the suggestions out of a channel directory listing: the ones this
  session has not joined, public and joinable, most populated first — the most
  recently used of equally busy ones first — capped at what the sidebar shows.

  The selection lives here, apart from the directory lookup, so it can be
  exercised on a known list instead of on whatever channels happen to be running.
  """
  @spec popular_channels([map()], [String.t()]) :: [map()]
  def popular_channels(channels, joined_names) do
    channels
    |> suggestible(joined_names)
    |> Enum.filter(&occupied?/1)
    |> Enum.sort_by(&{-&1.user_count, recency(&1)})
    |> Enum.take(@max_popular_channels)
  end

  defp suggestible(channels, joined_names) do
    joined = MapSet.new(joined_names)

    channels
    |> Enum.reject(fn channel -> MapSet.member?(joined, channel.name) end)
    |> Enum.filter(&joinable_public_channel?/1)
  end

  # The room a subject's section opens with, whoever is in it.
  defp lead("games"), do: GameChannels.feed()
  defp lead(_category), do: nil

  defp featured_rank(channel, spec, locale) do
    {
      if(channel.lead?, do: 0, else: 1),
      if(spec.by_language?, do: language_rank(Map.get(channel, :locale), locale), else: 0),
      -Map.get(channel, :user_count, 0),
      recency(channel)
    }
  end

  # The reader's own language first, then the same language spoken elsewhere
  # (pt_PT for a pt_BR reader), then everything else.
  defp language_rank(_channel_locale, nil), do: 0
  defp language_rank(locale, locale), do: 0

  defp language_rank(channel_locale, locale) when is_binary(channel_locale) do
    if language(channel_locale) == language(locale), do: 1, else: 2
  end

  defp language_rank(_channel_locale, _locale), do: 2

  defp language(locale), do: locale |> String.split("_") |> hd()

  # Among rooms as busy as each other, the one used most recently first. A room
  # that never said when it was used goes last.
  defp recency(%{last_activity_at: %DateTime{} = at}), do: -DateTime.to_unix(at, :microsecond)
  defp recency(_channel), do: 0

  # The catalogue behind this carries registered channels nobody is in, which is
  # the right answer for somebody browsing on purpose and the wrong one for a
  # suggestion: the sidebar offered three rooms with nobody in them to whoever
  # had just arrived. Browsing them is one click away under "Browse all".
  defp occupied?(channel), do: Map.get(channel, :user_count, 0) > 0

  defp joinable_public_channel?(%{name: name} = channel) when is_binary(name) do
    String.starts_with?(name, "#") and not Map.get(channel, :invite_only?, false) and
      not keyed?(channel)
  end

  defp joinable_public_channel?(_channel), do: false

  defp keyed?(%{modes: modes}) when is_binary(modes), do: String.contains?(modes, "k")
  defp keyed?(_channel), do: false
end
