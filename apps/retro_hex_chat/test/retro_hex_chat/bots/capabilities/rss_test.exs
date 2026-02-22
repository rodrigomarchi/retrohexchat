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
    capability_state: RSS.init_state(@default_config)
  }

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
        RSS.handle_message("!FeedBot rss add https://example.com/feed #news", "admin", @ctx)

      assert {:reply, text, new_state} = result
      assert text =~ "added"
      assert length(new_state.feeds) == 1
      assert hd(new_state.feeds)["url"] == "https://example.com/feed"
      assert hd(new_state.feeds)["channel"] == "#news"
    end

    test "rejects invalid URL" do
      result = RSS.handle_message("!FeedBot rss add notaurl #news", "admin", @ctx)
      assert {:reply, text} = result
      assert text =~ "Invalid URL"
    end

    test "rejects when max feeds reached" do
      state = %{feeds: Enum.map(1..5, fn i -> %{"id" => "f#{i}"} end)}
      ctx = %{@ctx | capability_state: state}
      result = RSS.handle_message("!FeedBot rss add https://example.com/feed #news", "admin", ctx)
      assert {:reply, text} = result
      assert text =~ "Maximum"
    end

    test "adds # prefix to channel if missing" do
      result = RSS.handle_message("!FeedBot rss add https://example.com/feed news", "admin", @ctx)
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

  describe "ignores unrelated messages" do
    test "ignores non-rss messages" do
      assert :ignore == RSS.handle_message("hello", "user", @ctx)
    end
  end
end
