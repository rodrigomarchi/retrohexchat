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
    # Most of these exercise the feed list, which only an administrator may
    # touch. `TestAdmin` is one by config; the identity source is stubbed, so no
    # NickServ registration is involved.
    author: "TestAdmin"
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
      ctx = %{@ctx | author: "nobody"}
      result = RSS.handle_message("!FeedBot rss add https://93.184.216.34/f #news", "nobody", ctx)

      assert {:reply, text} = result
      assert text =~ "administrators"
    end

    test "a channel operator is not standing enough" do
      # The room's ops used to be the gate. A bot is server configuration, so
      # holding ops where it happens to sit buys nothing — not even to read the
      # list of addresses the server has been told to fetch.
      ctx = %{@ctx | author: "roomop"}

      assert {:reply, text} = RSS.handle_message("!FeedBot rss list", "roomop", ctx)
      assert text =~ "administrators"
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

  describe "format_item/2 — the house style for every RSS bot" do
    defp an_item(opts \\ []) do
      %{
        title: Keyword.get(opts, :title, "A headline"),
        link: Keyword.get(opts, :link, "https://example.com/a"),
        guid: nil,
        published: nil
      }
    end

    test "formats a compact Markdown card with source, headline, and final link" do
      line = RSS.format_item(an_item(), "The GitHub Blog")

      assert line ==
               "**The GitHub Blog** | A headline\n\n[Read full story](<https://example.com/a>)"
    end

    test "a publisher's tagline does not become the label" do
      assert RSS.format_item(an_item(), "cs.LG updates on arXiv.org") =~ "**cs\\.LG**"

      assert RSS.format_item(an_item(), "Phys.org - latest science and technology news") =~
               "**Phys\\.org**"

      assert RSS.format_item(an_item(), "Al Jazeera – Breaking News, World News") =~
               "**Al Jazeera**"
    end

    test "a name with no tagline is left alone" do
      assert RSS.format_item(an_item(), "Anime News Network") =~ "**Anime News Network**"
      assert RSS.format_item(an_item(), "Krebs on Security") =~ "**Krebs on Security**"
    end

    test "a paper-length headline is cut, and the link remains clickable" do
      long = String.duplicate("word ", 60)
      line = RSS.format_item(an_item(title: long), "Src")

      assert String.contains?(line, "\\.\\.\\.")
      assert String.contains?(line, "https://example.com/a")
      assert String.length(line) < 330, "a headline that wraps several times is what we replaced"
    end

    test "newlines from the publisher's markup do not break the headline" do
      line = RSS.format_item(an_item(title: "Two\n\n  lines   here"), "Src")

      refute line =~ "Two\n"
      assert line =~ "Two lines here"
      assert line =~ "[Read full story](<https://example.com/a>)"
    end

    test "an item with no link is still a readable line" do
      line = RSS.format_item(an_item(link: ""), "Src")

      assert line =~ "**Src**"
      assert line =~ "A headline"
      refute String.ends_with?(line, " ")
    end

    test "a feed that never gave its title still gets a label" do
      assert RSS.format_item(an_item(), nil) =~ "**RSS**"
    end

    test "uses parsed page preview metadata when available" do
      line =
        RSS.format_item(an_item(), "Src", %{
          title: "Parsed title",
          description: "A clean professional summary.",
          image: "https://example.com/cover.jpg",
          url: "https://example.com/canonical",
          site_name: "Example"
        })

      assert line =~ "**Example**"
      assert line =~ "**Example** | Parsed title"
      refute line =~ "[Parsed title](<https://example.com/canonical>)"
      assert line =~ "![Example preview image](<https://example.com/cover.jpg>)"
      refute line =~ "![Parsed title]"
      assert line =~ "> A clean professional summary\\."
      assert line =~ "[Read full story](<https://example.com/canonical>)"
    end

    test "escapes Markdown punctuation from publishers" do
      line =
        RSS.format_item(
          an_item(title: "A [headline] *with* _syntax_"),
          "Src",
          %{site_name: "Src | Source", description: "Use > carefully."}
        )

      assert line =~ "A \\[headline\\] \\*with\\* \\_syntax\\_"
      assert line =~ "**Src \\| Source**"
      assert line =~ "> Use \\> carefully\\."
    end

    test "keeps the final Markdown within the chat message limit" do
      line =
        RSS.format_item(
          an_item(title: String.duplicate("headline ", 80)),
          String.duplicate("source ", 30),
          %{
            description: String.duplicate("description ", 120),
            image: "https://example.com/#{String.duplicate("x", 360)}.jpg"
          }
        )

      assert String.length(line) <= 1_000
    end
  end
end
