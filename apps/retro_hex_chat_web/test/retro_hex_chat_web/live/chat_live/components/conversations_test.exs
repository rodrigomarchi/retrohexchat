defmodule RetroHexChatWeb.ChatLive.Components.ConversationsTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChat.Chat.AutoJoinList
  alias RetroHexChatWeb.ChatLive.Components.Conversations

  @moduletag :unit

  defp render_conv(extra) do
    render_component(
      Conversations,
      Keyword.merge(
        [
          id: Conversations.id(),
          visible: true,
          channels: ["#lobby", "#elixir"],
          active_channel: "#lobby"
        ],
        extra
      )
    )
  end

  defp autojoin(entries) do
    Enum.reduce(entries, AutoJoinList.new(), fn
      {channel, key}, list ->
        {:ok, updated} = AutoJoinList.add_entry(list, channel, key)
        updated

      channel, list ->
        {:ok, updated} = AutoJoinList.add_entry(list, channel)
        updated
    end)
  end

  test "renders the joined channels" do
    html = render_conv([])
    assert html =~ "#lobby"
    assert html =~ "#elixir"
    # Row events bubble to the parent unchanged.
    assert html =~ "switch_channel"
  end

  test "renders popular channels as a semantic section even when only browse is available" do
    html =
      render_conv(
        on_browse_channels: "browse_channels",
        popular_channels: []
      )

    assert html =~ ~s(data-testid="conversations-section-popular")
    assert html =~ ~s(data-testid="conversations-browse-all")
    assert html =~ "Browse All Channels..."
  end

  test "renders popular channels with join affordances and a browse-all action" do
    html =
      render_conv(
        on_browse_channels: "browse_channels",
        popular_channels: [%{name: "#retro", user_count: 7}]
      )

    assert html =~ ~s(data-testid="conversations-section-popular")
    assert html =~ "Popular channels"
    assert html =~ ~s(data-testid="popular-#retro")
    assert html =~ ~s(data-testid="join-#retro")
    assert html =~ ~s(data-testid="conversations-browse-all")
  end

  test "an auto-join channel you are not in is one row in the channel list" do
    html = render_conv(autojoin_list: autojoin([{"#secret", "hunter2"}]))
    document = Floki.parse_document!(html)

    assert [row] = Floki.find(document, ~s([data-testid="channel-#secret"]))
    assert Floki.attribute(row, "data-joined") == ["false"]
    assert Floki.attribute(row, "data-pinned") == ["true"]
    # Going there is what a click does, so the row carries the same event an
    # open channel's row carries.
    assert Floki.attribute(row, "phx-click") == ["switch_channel"]
    refute html =~ "hunter2"
  end

  test "an auto-join channel you are in appears once, pinned" do
    html = render_conv(autojoin_list: autojoin(["#elixir"]))
    document = Floki.parse_document!(html)

    assert [row] = Floki.find(document, ~s([data-testid="channel-#elixir"]))
    assert Floki.attribute(row, "data-joined") == ["true"]
    assert Floki.attribute(row, "data-pinned") == ["true"]
    assert Floki.find(row, ~s([data-testid="channel-autojoin-pin-#elixir"])) != []
  end

  test "every row carries the menu button that right-click also opens" do
    html = render_conv(pm_conversations: ["alice"])
    document = Floki.parse_document!(html)

    for testid <- ["channel-#lobby", "pm-alice"] do
      assert [row] = Floki.find(document, ~s([data-testid="#{testid}"]))
      assert Floki.find(row, "[data-conversations-menu]") != []
    end
  end

  test "a suggestion is joined by its row, not only by a 16px button" do
    html = render_conv(popular_channels: [%{name: "#retro", user_count: 7}])
    document = Floki.parse_document!(html)

    assert [row] = Floki.find(document, ~s([data-testid="popular-#retro"]))
    assert Floki.attribute(row, "phx-click") == ["conversations_join_popular"]
    assert Floki.attribute(row, "phx-value-channel") == ["#retro"]
  end

  test "the desktop shortcuts are absent at a phone's width, not merely hidden" do
    desktop = render_conv(popular_channels: [%{name: "#retro", user_count: 7}])

    mobile =
      render_conv(popular_channels: [%{name: "#retro", user_count: 7}], mobile_viewport: true)

    assert desktop =~ ~s(data-testid="join-#retro")
    refute mobile =~ ~s(data-testid="join-#retro")

    # What is left on a phone is the row and its menu.
    assert mobile =~ ~s(data-testid="popular-#retro")
  end

  test "draws highlights in the canonical conversation rows" do
    html =
      render_conv(
        pm_conversations: ["alice", "bob"],
        highlight_channels: MapSet.new(["#elixir", "pm:alice"])
      )

    document = Floki.parse_document!(html)

    alice = Floki.find(document, ~s([data-testid="pm-alice"]))
    channel = Floki.find(document, ~s([data-testid="channel-#elixir"]))

    assert alice != []
    assert Floki.attribute(alice, "class") |> to_string() =~ "chat-conversations-row--highlight"
    assert Floki.attribute(channel, "class") |> to_string() =~ "chat-conversations-row--highlight"
  end

  test "orders open channels by recent activity before join order" do
    html =
      render_conv(
        channels: ["#lobby", "#elixir", "#zig"],
        channel_activity_order: %{"#elixir" => 2, "#zig" => 3}
      )

    zig_pos = :binary.match(html, ~s(data-testid="channel-#zig")) |> elem(0)
    elixir_pos = :binary.match(html, ~s(data-testid="channel-#elixir")) |> elem(0)
    lobby_pos = :binary.match(html, ~s(data-testid="channel-#lobby")) |> elem(0)

    assert zig_pos < elixir_pos
    assert elixir_pos < lobby_pos
  end

  test "a PM nobody highlighted is drawn plainly" do
    html =
      render_conv(
        pm_conversations: ["alice"],
        open_pm_tabs: ["alice"],
        highlight_channels: MapSet.new([])
      )

    document = Floki.parse_document!(html)
    alice = Floki.find(document, ~s([data-testid="pm-alice"]))

    assert alice != []
    refute Floki.attribute(alice, "class") |> to_string() =~ "chat-conversations-row--highlight"
  end

  test "a PM with no tab mounted reads as saved, the way an unopened channel does" do
    html =
      render_conv(
        open_pm_tabs: ["alice"],
        pm_conversations: ["alice", "bob"]
      )

    document = Floki.parse_document!(html)

    assert [alice] = Floki.find(document, ~s([data-testid="pm-alice"]))
    assert [bob] = Floki.find(document, ~s([data-testid="pm-bob"]))

    assert Floki.attribute(alice, "data-joined") == ["true"]
    assert Floki.attribute(bob, "data-joined") == ["false"]
  end

  test "an unopened conversation still shows that it is the loud one" do
    html =
      render_conv(
        pm_conversations: ["alice"],
        open_pm_tabs: [],
        highlight_channels: MapSet.new(["pm:alice"])
      )

    document = Floki.parse_document!(html)
    assert [alice] = Floki.find(document, ~s([data-testid="pm-alice"]))

    classes = Floki.attribute(alice, "class") |> to_string()
    assert classes =~ "chat-conversations-row--highlight"
    assert classes =~ "chat-conversations-row--saved"
  end

  test "collapses to the rail when not visible and expands when visible" do
    collapsed = render_conv(visible: false)
    assert collapsed =~ ~s(data-state="collapsed")
    assert collapsed =~ "chat-sidebar-shell--collapsed"
    assert collapsed =~ ~s(data-testid="conversations-rail")

    expanded = render_conv(visible: true)
    assert expanded =~ ~s(data-state="expanded")
    assert expanded =~ "chat-sidebar-shell--expanded"
    assert expanded =~ ~s(title="Collapse conversations")
    refute expanded =~ ~s(data-testid="conversations-rail")
  end

  test "renders the active P2P session glyph on the owning PM row" do
    html =
      render_conv(
        pm_conversations: ["alice", "bob"],
        p2p_pm_sessions: %{
          "alice" => %{peer_nick: "Alice", state: :connected, token: "tok"}
        }
      )

    assert html =~ ~s(data-testid="pm-p2p-glyph-alice")
    assert html =~ ~s(data-p2p-status="live")
    refute html =~ ~s(data-testid="pm-p2p-glyph-bob")
  end

  # It used to be an <li> inside the suggestions section, so collapsing the
  # suggestions took away the one door that is always right.
  test "the full channel list is the sidebar's footer, outside every section" do
    html = render_conv(collapsed_sections: ["popular"])
    doc = Floki.parse_document!(html)

    assert [button] = Floki.find(doc, ~s([data-testid="conversations-browse-all"]))

    assert Floki.find(
             doc,
             ~s(.chat-conversations-footer [data-testid="conversations-browse-all"])
           ) == [button]

    assert Floki.find(
             doc,
             ~s(.chat-conversations-section [data-testid="conversations-browse-all"])
           ) == []
  end

  describe "featured subjects" do
    defp featured do
      [
        %{
          category: "games",
          channels: [
            %{name: "#retro-games", user_count: 0, category: "games", locale: "en", lead?: true},
            %{name: "#hex-pong", user_count: 2, category: "games", locale: "en", lead?: false}
          ]
        },
        %{
          category: "news",
          channels: [%{name: "#jornal", user_count: 3, category: "news", locale: "pt_BR"}]
        }
      ]
    end

    defp live_match(token, players),
      do: %{token: token, game_id: "pong", players: players, watchers: 0}

    test "each subject is a section of its own, above the popular channels, games first" do
      html =
        render_conv(
          featured_channels: featured(),
          popular_channels: [%{name: "#lobby", user_count: 9}]
        )

      games = :binary.match(html, ~s(data-testid="conversations-section-games")) |> elem(0)
      news = :binary.match(html, ~s(data-testid="conversations-section-news")) |> elem(0)
      popular = :binary.match(html, ~s(data-testid="conversations-section-popular")) |> elem(0)

      assert games < news
      assert news < popular
    end

    test "the section says the subject once, so its rows carry only their language" do
      doc = Floki.parse_document!(render_conv(featured_channels: featured()))

      assert [header] =
               Floki.find(
                 doc,
                 ~s([data-testid="conversations-section-news"] .chat-conversations-section__trigger)
               )

      assert Floki.find(header, ~s([data-category="news"])) != []
      assert Floki.text(header) =~ "News"

      assert [row] = Floki.find(doc, ~s([data-testid="popular-#jornal"]))
      assert Floki.find(row, ~s([data-testid="channel-category"])) == []
      assert Floki.find(row, ~s([data-testid="channel-flag"])) != []
      assert Floki.attribute(row, "phx-click") == ["conversations_join_popular"]
    end

    test "the games section opens with the feed, then the matches being played, then the rooms" do
      html =
        render_conv(
          featured_channels: featured(),
          live_matches: [live_match("tok1", ["ana", "bob"])]
        )

      feed = :binary.match(html, ~s(data-testid="popular-#retro-games")) |> elem(0)
      match = :binary.match(html, ~s(data-testid="conversations-live-match")) |> elem(0)
      pong = :binary.match(html, ~s(data-testid="popular-#hex-pong")) |> elem(0)

      assert feed < match
      assert match < pong
    end

    test "at most three matches being played, and only in the games section" do
      matches = for n <- 1..5, do: live_match("tok#{n}", ["p#{n}", "q#{n}"])

      doc =
        Floki.parse_document!(render_conv(featured_channels: featured(), live_matches: matches))

      assert length(Floki.find(doc, ~s([data-testid="conversations-live-match"]))) == 3

      assert Floki.find(
               doc,
               ~s([data-testid="conversations-section-news"] [data-testid="conversations-live-match"])
             ) == []
    end

    test "see more opens the Channel List narrowed to the section's subject" do
      doc = Floki.parse_document!(render_conv(featured_channels: featured()))

      for category <- ["games", "news"] do
        assert [button] = Floki.find(doc, ~s([data-testid="conversations-more-#{category}"]))
        assert Floki.attribute(button, "phx-click") == ["conversations_browse_category"]
        assert Floki.attribute(button, "phx-value-category") == [category]
      end
    end

    test "a subject with nothing to offer draws no section" do
      html =
        render_conv(
          featured_channels: [
            %{category: "games", channels: []},
            %{category: "news", channels: []}
          ]
        )

      refute html =~ ~s(data-testid="conversations-section-games")
      refute html =~ ~s(data-testid="conversations-section-news")
    end

    test "a games section with only matches being played is still drawn" do
      html =
        render_conv(
          featured_channels: [%{category: "games", channels: []}],
          live_matches: [live_match("tok1", ["ana", "bob"])]
        )

      assert html =~ ~s(data-testid="conversations-section-games")
      assert html =~ ~s(data-testid="conversations-live-match")
    end

    test "the collapsed rail counts every suggestion, whichever section it is in" do
      html =
        render_conv(
          visible: false,
          featured_channels: featured(),
          popular_channels: [%{name: "#lobby", user_count: 9}]
        )

      assert html =~ "Popular channels: 4"
    end

    test "a closed section keeps its header and drops its rows" do
      html =
        render_conv(
          featured_channels: featured(),
          conversations_sections: %{games: false, news: true}
        )

      assert html =~ ~s(data-testid="conversations-section-games")
      refute html =~ ~s(data-testid="popular-#retro-games")
      assert html =~ ~s(data-testid="popular-#jornal")
    end
  end
end
