defmodule RetroHexChat.Bots.Capabilities.RSSTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Bots.Capabilities.RSS

  @default_config RSS.default_config()

  @ctx %{
    bot_nickname: "FeedBot",
    bot_name: "FeedBot",
    channel: "#general",
    command_prefix: "!",
    config: @default_config,
    capability_state: RSS.init_state(@default_config),
    # Most of these exercise the feed list, which only an operator may change.
    author_privileged?: true
  }

  # Literal addresses need no resolver, so these stay hermetic.

  describe "name/0" do
    test "returns :rss" do
      assert RSS.name() == :rss
    end
  end

  describe "description/0" do
    test "does not say Coming soon" do
      refute RSS.description() =~ "Coming soon"
    end
  end

  describe "init_state/1" do
    test "initializes empty feeds" do
      state = RSS.init_state(@default_config)
      assert state.feeds == []
    end

    test "loads existing feeds from config" do
      config =
        Map.put(@default_config, "feeds", [
          %{"id" => "f1", "url" => "https://example.com/feed", "channel" => "#test"}
        ])

      state = RSS.init_state(config)
      assert length(state.feeds) == 1
    end
  end

  describe "rss add" do
    test "adds a feed" do
      result =
        RSS.handle_message("!FeedBot rss add https://93.184.216.34/feed #news", "admin", @ctx)

      assert {:reply, text, new_state} = result
      assert text =~ "added"
      assert length(new_state.feeds) == 1
      assert hd(new_state.feeds)["url"] == "https://93.184.216.34/feed"
      assert hd(new_state.feeds)["channel"] == "#news"
    end

    test "rejects invalid URL" do
      result = RSS.handle_message("!FeedBot rss add notaurl #news", "admin", @ctx)
      assert {:reply, text} = result
      assert text =~ "Refusing"
    end

    test "rejects when max feeds reached" do
      state = %{feeds: Enum.map(1..5, fn i -> %{"id" => "f#{i}"} end)}
      ctx = %{@ctx | capability_state: state}

      result =
        RSS.handle_message("!FeedBot rss add https://93.184.216.34/feed #news", "admin", ctx)

      assert {:reply, text} = result
      assert text =~ "Maximum"
    end

    test "a passer-by cannot aim the server at a URL" do
      ctx = %{@ctx | author_privileged?: false}
      result = RSS.handle_message("!FeedBot rss add https://93.184.216.34/f #news", "nobody", ctx)

      assert {:reply, text} = result
      assert text =~ "operators"
    end

    test "refuses an address inside the host's own network" do
      for url <- ["http://127.0.0.1/f", "http://169.254.169.254/f", "http://10.0.0.1/f"] do
        assert {:reply, text} =
                 RSS.handle_message("!FeedBot rss add #{url} #news", "admin", @ctx)

        assert text =~ "Refusing", "#{url} must not be fetchable"
      end
    end

    test "adds # prefix to channel if missing" do
      result =
        RSS.handle_message("!FeedBot rss add https://93.184.216.34/feed news", "admin", @ctx)

      assert {:reply, _, new_state} = result
      assert hd(new_state.feeds)["channel"] == "#news"
    end
  end

  describe "rss list" do
    test "shows empty list" do
      result = RSS.handle_message("!FeedBot rss list", "admin", @ctx)
      assert {:reply, text} = result
      assert text =~ "No RSS feeds"
    end

    test "shows feeds" do
      state = %{
        feeds: [
          %{
            "id" => "f1",
            "url" => "https://example.com/feed",
            "channel" => "#news",
            "title" => "Example"
          }
        ]
      }

      ctx = %{@ctx | capability_state: state}
      result = RSS.handle_message("!FeedBot rss list", "admin", ctx)
      assert {:multi_reply, lines} = result
      assert length(lines) >= 2
    end
  end

  describe "rss remove" do
    test "removes existing feed" do
      state = %{
        feeds: [
          %{
            "id" => "f1",
            "url" => "https://example.com/feed",
            "channel" => "#news",
            "title" => "Example"
          }
        ]
      }

      ctx = %{@ctx | capability_state: state}
      result = RSS.handle_message("!FeedBot rss remove f1", "admin", ctx)
      assert {:reply, text, new_state} = result
      assert text =~ "removed"
      assert new_state.feeds == []
    end

    test "reports not found" do
      result = RSS.handle_message("!FeedBot rss remove nonexistent", "admin", @ctx)
      assert {:reply, text} = result
      assert text =~ "not found"
    end
  end

  describe "commands/0" do
    test "returns rss commands" do
      cmds = RSS.commands()
      triggers = Enum.map(cmds, & &1.trigger)
      assert "rss add" in triggers
      assert "rss list" in triggers
      assert "rss remove" in triggers
    end
  end

  describe "reschedule_delay/2" do
    test "returns poll_interval_ms from state" do
      state = %{
        feeds: [%{"id" => "f1", "url" => "https://example.com/feed", "channel" => "#news"}],
        poll_interval_ms: 1_800_000
      }

      payload = %{type: :poll, feed_id: "f1", channel: "#news"}
      assert {:reschedule, 1_800_000, ^payload} = RSS.reschedule_delay(payload, state)
    end

    test "returns :no_reschedule when feeds list is empty" do
      state = %{feeds: [], poll_interval_ms: 1_800_000}
      payload = %{type: :poll, feed_id: "f1", channel: "#news"}
      assert :no_reschedule == RSS.reschedule_delay(payload, state)
    end

    test "preserves original payload for next poll" do
      state = %{
        feeds: [%{"id" => "f1", "url" => "https://example.com/feed", "channel" => "#news"}],
        poll_interval_ms: 60_000
      }

      payload = %{type: :poll, feed_id: "f1", channel: "#news"}
      assert {:reschedule, 60_000, returned_payload} = RSS.reschedule_delay(payload, state)
      assert returned_payload == payload
    end

    test "returns :no_reschedule for non-poll payload" do
      state = %{feeds: [%{"id" => "f1"}], poll_interval_ms: 60_000}
      assert :no_reschedule == RSS.reschedule_delay(%{type: :other}, state)
    end
  end

  describe "ignores unrelated messages" do
    test "ignores non-rss messages" do
      assert :ignore == RSS.handle_message("hello", "user", @ctx)
    end
  end

  describe "plan_publication/3 — only new items, never twice" do
    defp item(id, opts \\ []) do
      %{
        title: "Item #{id}",
        link: Keyword.get(opts, :link, "https://example.com/#{id}"),
        guid: Keyword.get(opts, :guid),
        published: nil
      }
    end

    # Feeds list newest first.
    defp page(ids), do: Enum.map(ids, &item/1)

    test "the first sight announces one item and remembers the page" do
      {to_post, seen} = RSS.plan_publication([], page([3, 2, 1]), 3)

      assert Enum.map(to_post, & &1.title) == ["Item 3"],
             "one headline proves the feed works; silence proves nothing"

      assert length(seen) == 3, "the rest of the page is history, not news"
    end

    test "an empty feed announces nothing" do
      assert {[], []} = RSS.plan_publication([], [], 3)
    end

    test "announces only what appeared since last time" do
      {_, seen} = RSS.plan_publication([], page([2, 1]), 3)
      {to_post, _} = RSS.plan_publication(seen, page([3, 2, 1]), 3)

      assert Enum.map(to_post, & &1.title) == ["Item 3"]
    end

    test "a backlog arrives oldest first" do
      {_, seen} = RSS.plan_publication([], page([1]), 3)
      {to_post, _} = RSS.plan_publication(seen, page([4, 3, 2, 1]), 3)

      assert Enum.map(to_post, & &1.title) == ["Item 2", "Item 3", "Item 4"]
    end

    test "what does not fit waits for the next poll instead of vanishing" do
      {_, seen} = RSS.plan_publication([], page([1]), 2)
      feed = page([5, 4, 3, 2, 1])

      {first, newly} = RSS.plan_publication(seen, feed, 2)
      {second, newly2} = RSS.plan_publication(newly ++ seen, feed, 2)
      {third, _} = RSS.plan_publication(newly2 ++ newly ++ seen, feed, 2)

      assert Enum.map(first, & &1.title) == ["Item 2", "Item 3"]
      assert Enum.map(second, & &1.title) == ["Item 4", "Item 5"]
      assert third == []
    end

    test "an item pinned back to the top is not news again" do
      {_, seen} = RSS.plan_publication([], page([3, 2, 1]), 5)
      # The publisher bumps Item 1 to the top; nothing was actually written.
      {to_post, _} = RSS.plan_publication(seen, page([1, 3, 2]), 5)

      assert to_post == []
    end

    test "a rewritten link does not resurrect an item that carries a guid" do
      original = [item(1, guid: "urn:1", link: "https://example.com/a")]
      {_, seen} = RSS.plan_publication([], original, 5)

      moved = [item(1, guid: "urn:1", link: "https://example.com/a-renamed")]
      {to_post, _} = RSS.plan_publication(seen, moved, 5)

      assert to_post == []
    end

    test "the memory survives being rebuilt from stored config" do
      {_, seen} = RSS.plan_publication([], page([2, 1]), 5)

      stored = %{
        "feeds" => [%{"id" => "f1", "url" => "https://e/f", "channel" => "#n", "seen" => seen}]
      }

      [restored] = RSS.init_state(stored).feeds

      {to_post, _} = RSS.plan_publication(restored["seen"], page([2, 1]), 5)

      assert to_post == [], "a restart must not replay the feed into the channel"
    end

    test "a feed stored before the seen-set existed keeps its last item quiet" do
      [feed] =
        RSS.init_state(%{
          "feeds" => [
            %{
              "id" => "f1",
              "url" => "https://e/f",
              "channel" => "#n",
              "last_seen_link" => "https://example.com/2"
            }
          ]
        }).feeds

      {to_post, _} = RSS.plan_publication(feed["seen"], page([2]), 5)
      assert to_post == []
    end
  end
end
