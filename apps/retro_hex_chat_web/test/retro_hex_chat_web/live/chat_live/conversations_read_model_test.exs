defmodule RetroHexChatWeb.ChatLive.ConversationsReadModelTest do
  use RetroHexChat.DataCase, async: false

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Channels.{Registry, Server, Supervisor}
  alias RetroHexChat.Chat.AutoJoinList
  alias RetroHexChatWeb.ChatLive.ConversationsReadModel

  @moduletag :integration

  import ExUnit.Callbacks, only: [on_exit: 1]

  defp unique(prefix), do: "##{prefix}#{System.unique_integer([:positive])}"

  defp start_channel(name) do
    case Registry.lookup(name) do
      {:ok, pid} -> pid
      {:error, :not_found} -> start_supervised_channel(name)
    end
  end

  defp start_supervised_channel(name) do
    {:ok, pid} = Supervisor.start_child(name)

    on_exit(fn ->
      if Process.alive?(pid), do: Supervisor.stop_child(RetroHexChat.Channels.Supervisor, pid)
    end)

    pid
  end

  defp listing(entries) do
    Enum.map(entries, fn {name, user_count, extra} ->
      Map.merge(
        %{name: name, topic: nil, user_count: user_count, joined?: false, modes: ""},
        Map.new(extra)
      )
    end)
  end

  # The selection is tested on a known listing: the channel directory is global
  # to the suite, so "is this channel among the top ten?" cannot be asserted
  # against whatever channels the other tests left running.
  describe "popular_channels/2" do
    test "orders unjoined public channels by popularity" do
      channels = listing([{"#quiet", 1, []}, {"#busy", 9, []}, {"#middling", 4, []}])

      assert Enum.map(ConversationsReadModel.popular_channels(channels, []), & &1.name) ==
               ["#busy", "#middling", "#quiet"]
    end

    test "drops the channels this session already joined" do
      channels = listing([{"#joined", 9, []}, {"#open", 1, []}])

      assert Enum.map(ConversationsReadModel.popular_channels(channels, ["#joined"]), & &1.name) ==
               ["#open"]
    end

    test "drops private placeholders — they are not a name anyone can join" do
      channels = listing([{"Prv", 9, []}, {"#open", 1, []}])

      assert Enum.map(ConversationsReadModel.popular_channels(channels, []), & &1.name) ==
               ["#open"]
    end

    test "drops invite-only and keyed channels — one click cannot get you in" do
      channels =
        listing([
          {"#invite", 9, [invite_only?: true]},
          {"#keyed", 8, [modes: "+k"]},
          {"#open", 1, []}
        ])

      assert Enum.map(ConversationsReadModel.popular_channels(channels, []), & &1.name) ==
               ["#open"]
    end

    test "shows at most ten suggestions" do
      channels = listing(for n <- 1..15, do: {"#c#{n}", n, []})

      assert length(ConversationsReadModel.popular_channels(channels, [])) == 10
    end

    test "of rooms as busy as each other, the one used most recently comes first" do
      channels =
        listing([
          {"#alpha", 3, [last_activity_at: ~U[2026-10-01 10:00:00Z]]},
          {"#never", 3, []},
          {"#zulu", 3, [last_activity_at: ~U[2026-10-20 10:00:00Z]]}
        ])

      assert Enum.map(ConversationsReadModel.popular_channels(channels, []), & &1.name) ==
               ["#zulu", "#alpha", "#never"]
    end
  end

  defp section(sections, category) do
    sections
    |> Enum.find(&(&1.category == category))
    |> Map.fetch!(:channels)
    |> Enum.map(& &1.name)
  end

  describe "featured_channels/3" do
    test "one section per featured subject, games first, each returned even when empty" do
      assert [%{category: "games", channels: []}, %{category: "news", channels: []}] =
               ConversationsReadModel.featured_channels([], [], "en")
    end

    test "the games section opens with the feed, busy or not, and keeps empty game rooms last" do
      channels =
        listing([
          {"#hex-pong", 4, [category: "games"]},
          {"#hex-snake", 0, [category: "games"]},
          {"#retro-games", 0, [category: "games"]},
          {"#hex-tetris", 7, [category: "games"]},
          {"#lobby", 9, [category: "social"]}
        ])

      sections = ConversationsReadModel.featured_channels(channels, [], "pt_BR")

      assert section(sections, "games") ==
               ["#retro-games", "#hex-tetris", "#hex-pong", "#hex-snake"]

      assert [%{lead?: true} | rest] =
               Enum.find(sections, &(&1.category == "games")).channels

      refute Enum.any?(rest, & &1.lead?)
    end

    test "the games section offers at most six rooms" do
      channels = listing(for n <- 1..9, do: {"#game#{n}", n, [category: "games"]})

      assert length(section(ConversationsReadModel.featured_channels(channels, [], nil), "games")) ==
               6
    end

    test "the news section leaves out rooms nobody is in" do
      channels =
        listing([
          {"#jornal", 2, [category: "news"]},
          {"#empty-news", 0, [category: "news"]}
        ])

      assert section(ConversationsReadModel.featured_channels(channels, [], "pt_BR"), "news") ==
               ["#jornal"]
    end

    test "news in the reader's language first, then the same language elsewhere, then the rest" do
      channels =
        listing([
          {"#news", 9, [category: "news", locale: "en"]},
          {"#ultimahora", 5, [category: "news", locale: "pt_PT"]},
          {"#nolocale", 8, [category: "news"]},
          {"#jornal", 1, [category: "news", locale: "pt_BR"]}
        ])

      assert section(ConversationsReadModel.featured_channels(channels, [], "pt_BR"), "news") ==
               ["#jornal", "#ultimahora", "#news", "#nolocale"]
    end

    test "the news section offers at most five rooms" do
      channels = listing(for n <- 1..8, do: {"#news#{n}", n, [category: "news"]})

      assert length(section(ConversationsReadModel.featured_channels(channels, [], nil), "news")) ==
               5
    end

    test "joined, invite-only and keyed rooms are not suggested in a section either" do
      channels =
        listing([
          {"#retro-games", 3, [category: "games"]},
          {"#locked", 3, [category: "games", invite_only?: true]},
          {"#keyed", 3, [category: "games", modes: "+k"]},
          {"#hex-pong", 0, [category: "games"]}
        ])

      assert section(
               ConversationsReadModel.featured_channels(channels, ["#retro-games"], nil),
               "games"
             ) == ["#hex-pong"]
    end
  end

  describe "discovery_open?/1 and settle_discovery_sections/1" do
    defp with_autojoin(session, channels) do
      list =
        Enum.reduce(channels, AutoJoinList.new(), fn channel, list ->
          {:ok, list} = AutoJoinList.add_entry(list, channel)
          list
        end)

      %{session | autojoin_list: list}
    end

    defp settled(session) do
      %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          session: session,
          conversations_sections: %{channels: true, games: true, news: true, popular: true}
        }
      }
      |> ConversationsReadModel.settle_discovery_sections()
      |> then(& &1.assigns.conversations_sections)
    end

    test "an arrival with fewer than three rooms gets the suggestions open" do
      session = "Newbie" |> Session.new() |> Session.add_channel("#lobby")

      assert ConversationsReadModel.discovery_open?(session)
      assert %{games: true, news: true, popular: true} = settled(session)
    end

    # The mount starts from an empty session and the account's rooms are joined
    # a moment later: counting only the joined ones opened the suggestions for
    # everybody, every time.
    test "rooms the account joins on connect count before they are joined" do
      session = "Regular" |> Session.new() |> with_autojoin(["#a", "#b", "#c"])

      refute ConversationsReadModel.discovery_open?(session)
      assert %{games: true, news: false, popular: false} = settled(session)
    end

    test "a room both joined and saved counts once" do
      session =
        "Twice"
        |> Session.new()
        |> Session.add_channel("#a")
        |> Session.add_channel("#b")
        |> with_autojoin(["#A", "#b"])

      assert ConversationsReadModel.discovery_open?(session)
    end
  end

  describe "suggestions/3" do
    test "a room about a featured subject is never also a popular suggestion" do
      channels =
        listing(
          [{"#lobby", 2, [category: "social"]}, {"#plain", 1, []}] ++
            for(n <- 1..8, do: {"#news#{n}", 10 + n, [category: "news"]}) ++
            for(n <- 1..8, do: {"#game#{n}", 10 + n, [category: "games"]})
        )

      %{featured_channels: featured, popular_channels: popular} =
        ConversationsReadModel.suggestions(channels, [], "en")

      assert Enum.map(popular, & &1.name) == ["#lobby", "#plain"]
      assert length(section(featured, "news")) == 5
      assert length(section(featured, "games")) == 6
    end
  end

  describe "channel activity order" do
    test "touch_channel_activity/2 records monotonic activity per channel" do
      socket =
        "Viewer"
        |> Session.new()
        |> socket_with_session()
        |> ConversationsReadModel.touch_channel_activity("#one")
        |> ConversationsReadModel.touch_channel_activity("#two")
        |> ConversationsReadModel.touch_channel_activity("#one")

      assert socket.assigns.channel_activity_sequence == 3
      assert socket.assigns.channel_activity_order == %{"#one" => 3, "#two" => 2}
    end

    test "drop_channel_activity/2 removes a parted channel without rewinding the sequence" do
      socket =
        "Viewer"
        |> Session.new()
        |> socket_with_session()
        |> ConversationsReadModel.touch_channel_activity("#one")
        |> ConversationsReadModel.touch_channel_activity("#two")
        |> ConversationsReadModel.drop_channel_activity("#one")

      assert socket.assigns.channel_activity_sequence == 2
      assert socket.assigns.channel_activity_order == %{"#two" => 2}
    end
  end

  describe "load_discovery/1" do
    test "reads the live channel directory and leaves out the joined ones" do
      popular = unique("sidebarpopular")
      joined = unique("sidebarjoined")

      start_channel(popular)
      start_channel(joined)

      Enum.each(["Alice", "Bob", "Carol"], fn nick ->
        assert {:ok, _state} = Server.join(popular, nick)
      end)

      assert {:ok, _state} = Server.join(joined, "Viewer")

      session =
        "Viewer"
        |> Session.new()
        |> Session.add_channel(joined)

      socket = session |> socket_with_session() |> ConversationsReadModel.load_discovery()

      names = Enum.map(socket.assigns.popular_channels, & &1.name)
      counts = Enum.map(socket.assigns.popular_channels, & &1.user_count)

      assert Enum.map(socket.assigns.featured_channels, & &1.category) ==
               ConversationsReadModel.featured_categories()

      # Which channels make the top ten depends on every channel the suite has
      # running, so assert the contract rather than a membership: the directory
      # was read, the joined channel is out, and the rest is ordered and capped.
      refute names == []
      refute joined in names
      assert Enum.all?(names, &String.starts_with?(&1, "#"))
      assert counts == Enum.sort(counts, :desc)
      assert length(names) <= 10
    end

    test "does not offer private placeholders as joinable popular channels" do
      private = unique("sidebarprivate")

      start_channel(private)
      assert {:ok, _state} = Server.join(private, "Owner")
      assert :ok = Server.set_mode(private, "Owner", "+p", [])

      socket =
        "Viewer"
        |> Session.new()
        |> socket_with_session()
        |> ConversationsReadModel.load_discovery()

      refute Enum.any?(socket.assigns.popular_channels, fn channel ->
               not String.starts_with?(channel.name, "#")
             end)
    end

    test "does not offer restricted channels as one-click popular suggestions" do
      invite_only = unique("sidebarinvite")
      keyed = unique("sidebarkey")

      start_channel(invite_only)
      start_channel(keyed)

      assert {:ok, _state} = Server.join(invite_only, "Owner")
      assert :ok = Server.set_mode(invite_only, "Owner", "+i", [])
      assert {:ok, _state} = Server.join(keyed, "Owner")
      assert :ok = Server.set_mode(keyed, "Owner", "+k", ["secret"])

      socket =
        "Viewer"
        |> Session.new()
        |> socket_with_session()
        |> ConversationsReadModel.load_discovery()

      names = Enum.map(socket.assigns.popular_channels, & &1.name)

      refute invite_only in names
      refute keyed in names
    end
  end

  defp socket_with_session(session) do
    %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}, session: session}}
  end

  describe "popular_channels/2 with an empty room in the catalogue" do
    # The catalogue now carries registered channels nobody is in, which is the
    # right answer for someone browsing on purpose and the wrong one for a
    # suggestion: "popular" offered three rooms with nobody in them to whoever
    # had just arrived.
    test "a room with nobody in it is never suggested" do
      channels = [
        %{name: "#busy", user_count: 4, invite_only?: false, modes: ""},
        %{name: "#quiet", user_count: 0, invite_only?: false, modes: ""}
      ]

      names = channels |> ConversationsReadModel.popular_channels([]) |> Enum.map(& &1.name)

      assert names == ["#busy"]
    end

    test "a catalogue of nothing but empty rooms suggests nothing" do
      channels = [
        %{name: "#quiet", user_count: 0, invite_only?: false, modes: ""},
        %{name: "#quieter", user_count: 0, invite_only?: false, modes: ""}
      ]

      assert ConversationsReadModel.popular_channels(channels, []) == []
    end
  end
end
