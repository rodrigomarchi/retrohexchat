defmodule RetroHexChat.Bots.FeedsTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Bots.{Feeds, Queries, Registry, Supervisor}
  alias RetroHexChat.Jobs.RSSPollWorker

  # A literal address needs no resolver, so these stay hermetic.
  @public "https://93.184.216.34/feed.xml"

  defp bot(capabilities \\ %{"rss" => %{"enabled" => true, "feeds" => []}}) do
    {:ok, bot} =
      Queries.create_bot(%{
        name: "FeedsBot#{System.unique_integer([:positive])}",
        nickname: "FeedsBot#{System.unique_integer([:positive])}",
        created_by: "admin",
        capabilities: capabilities
      })

    # A feed can only target a room the bot is in.
    {:ok, _} = Queries.add_channel_config(bot.id, "#news")
    bot
  end

  describe "add/3" do
    test "stores the feed where a restart will find it" do
      assert {:ok, updated} = Feeds.add(bot(), @public, "#news")

      assert [%{"url" => @public, "channel" => "#news"}] = Feeds.list(updated)
      assert Feeds.list(Queries.get_bot(updated.id)) == Feeds.list(updated)
    end

    test "a new feed starts with no memory, so its first poll stays quiet" do
      {:ok, updated} = Feeds.add(bot(), @public, "#news")

      assert [%{"seen" => [], "last_polled_at" => nil}] = Feeds.list(updated)
    end

    test "names the channel even when the hash is left off" do
      {:ok, updated} = Feeds.add(bot(), @public, "news")
      assert [%{"channel" => "#news"}] = Feeds.list(updated)
    end

    test "refuses a room the bot has not joined" do
      assert {:error, reason} = Feeds.add(bot(), @public, "#nowhere")
      assert reason =~ "not in #nowhere"
    end

    test "refuses an address inside the host's own network" do
      assert {:error, reason} = Feeds.add(bot(), "http://169.254.169.254/latest/", "#news")
      assert reason =~ "public"
    end

    test "refuses anything that is not a fetchable address" do
      assert {:error, _} = Feeds.add(bot(), "file:///etc/passwd", "#news")
      assert {:error, _} = Feeds.add(bot(), "nonsense", "#news")
    end

    test "refuses a feed with nowhere to post" do
      assert {:error, reason} = Feeds.add(bot(), @public, "")
      assert reason =~ "channel"
    end

    test "stops at the configured ceiling" do
      full =
        bot(%{
          "rss" => %{
            "enabled" => true,
            "max_feeds" => 2,
            "feeds" => [%{"id" => "a"}, %{"id" => "b"}]
          }
        })

      assert {:error, reason} = Feeds.add(full, @public, "#news")
      assert reason =~ "maximum"
    end

    test "works on a bot whose rss capability was only just switched on" do
      assert {:ok, updated} = Feeds.add(bot(%{}), @public, "#news")
      assert [%{"url" => @public}] = Feeds.list(updated)
    end
  end

  describe "remove/2" do
    test "takes the feed out and persists the absence" do
      {:ok, with_feed} = Feeds.add(bot(), @public, "#news")
      [%{"id" => id}] = Feeds.list(with_feed)

      assert {:ok, updated} = Feeds.remove(with_feed, id)
      assert Feeds.list(updated) == []
      assert Feeds.list(Queries.get_bot(updated.id)) == []
    end

    test "says so when there is nothing to remove" do
      assert {:error, reason} = Feeds.remove(bot(), "nope")
      assert reason =~ "no feed"
    end
  end

  describe "the running bot picks the feed up" do
    # The provisioning script and the admin dialog both come through here, not
    # through the in-channel command. If this path does not enqueue a poll, no
    # feed added by an operator is ever fetched — which looks exactly like a
    # server where nothing publishes.
    test "adding a feed enqueues its first durable poll" do
      bot = bot()

      {:ok, pid} =
        RetroHexChat.Bots.Supervisor.start_bot(%{
          id: bot.id,
          name: bot.name,
          nickname: bot.nickname,
          command_prefix: "!",
          created_by: "admin",
          enabled: true,
          cooldown_ms: 0,
          capabilities: bot.capabilities,
          channel_configs: [%{channel_name: "#news", enabled: true, capability_overrides: %{}}],
          custom_commands: []
        })

      on_exit(fn -> RetroHexChat.Bots.Supervisor.stop_bot(bot.nickname) end)

      assert :sys.get_state(pid).capability_timers == %{}

      {:ok, _} = Feeds.add(bot, @public, "#news")
      Process.sleep(80)

      [%{"id" => id}] = Feeds.list(Queries.get_bot(bot.id))

      assert_enqueued(
        worker: RSSPollWorker,
        queue: :rss,
        args: %{bot_id: bot.id, feed_id: id}
      )

      assert :sys.get_state(pid).capability_timers == %{}
    end

    test "adding a feed to a stopped enabled bot starts it and enqueues its poll" do
      bot = bot()

      assert {:error, :not_found} = Registry.lookup(bot.nickname)

      {:ok, updated} = Feeds.add(bot, @public, "#news")
      Process.sleep(80)

      assert {:ok, pid} = Registry.lookup(updated.nickname)
      assert Process.alive?(pid)

      on_exit(fn -> Supervisor.stop_bot(updated.nickname) end)

      [%{"id" => id}] = Feeds.list(updated)

      assert_enqueued(
        worker: RSSPollWorker,
        queue: :rss,
        args: %{bot_id: updated.id, feed_id: id}
      )
    end

    test "removing it cancels its durable poll" do
      bot = bot()
      {:ok, with_feed} = Feeds.add(bot, @public, "#news")
      [%{"id" => id}] = Feeds.list(with_feed)

      assert {:ok, pid} = Registry.lookup(with_feed.nickname)

      on_exit(fn -> Supervisor.stop_bot(with_feed.nickname) end)

      assert_enqueued(
        worker: RSSPollWorker,
        queue: :rss,
        args: %{bot_id: with_feed.id, feed_id: id}
      )

      {:ok, _} = Feeds.remove(with_feed, id)
      Process.sleep(80)

      refute_enqueued(
        worker: RSSPollWorker,
        queue: :rss,
        args: %{bot_id: with_feed.id, feed_id: id}
      )

      assert :sys.get_state(pid).capability_timers == %{}
    end
  end
end
