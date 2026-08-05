defmodule RetroHexChat.Jobs.RSSPollWorkerTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Bots.Queries, as: BotQueries
  alias RetroHexChat.Bots.Supervisor, as: BotSupervisor
  alias RetroHexChat.Channels
  alias RetroHexChat.Chat.Queries, as: ChatQueries
  alias RetroHexChat.Jobs.RSSPollWorker

  @channel "#rss-worker"
  @url "https://93.184.216.34/feed.xml"

  defmodule ScriptedFetcher do
    @moduledoc false
    @behaviour RetroHexChat.Bots.Capabilities.RSS.Fetcher

    @impl true
    def fetch(_url, _etag, _last_modified) do
      Agent.get_and_update(__MODULE__, fn [head | rest] ->
        {head, rest_or_repeat(rest, head)}
      end)
    end

    @spec script([RetroHexChat.Bots.Capabilities.RSS.Fetcher.result()]) ::
            {:ok, pid()} | :ok
    def script(pages) do
      case Process.whereis(__MODULE__) do
        nil -> Agent.start_link(fn -> pages end, name: __MODULE__)
        _pid -> Agent.update(__MODULE__, fn _ -> pages end)
      end
    end

    defp rest_or_repeat([], last), do: [last]
    defp rest_or_repeat(rest, _last), do: rest
  end

  defmodule RichPreview do
    @moduledoc false
    @behaviour RetroHexChat.Chat.LinkPreview

    @impl true
    def fetch_title(_url), do: {:ok, "Parsed worker story"}

    @impl true
    def fetch_metadata("https://example.com/3") do
      {:ok,
       %{
         title: "Parsed worker story",
         description: "Worker extracted this from standards metadata.",
         image: "https://example.com/worker-card.png",
         url: "https://example.com/3",
         site_name: "Worker News"
       }}
    end

    def fetch_metadata(_url), do: {:error, :fetch_failed}
  end

  setup do
    Application.put_env(:retro_hex_chat, :rss_fetcher, ScriptedFetcher)
    Application.put_env(:retro_hex_chat, :link_preview_fetcher, RichPreview)

    {:ok, chan} = Channels.Supervisor.start_child(@channel)
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "channel:#{@channel}")

    on_exit(fn ->
      Application.delete_env(:retro_hex_chat, :rss_fetcher)
      Application.delete_env(:retro_hex_chat, :link_preview_fetcher)
      BotSupervisor.stop_bot("RSSWorkerBot")
      if Process.alive?(chan), do: Channels.Supervisor.stop_child(chan)
    end)

    :ok
  end

  test "polls through Oban, seeds quietly, posts later changes, and schedules the next run" do
    feed = %{"id" => "f1", "url" => @url, "channel" => @channel, "seen" => []}
    page1 = feed_page([{2, "Second"}, {1, "First"}])
    page2 = feed_page([{3, "Third"}, {2, "Second"}, {1, "First"}])

    ScriptedFetcher.script([
      {:ok, page1, %{etag: "\"one\"", last_modified: nil}},
      {:ok, page2, %{etag: "\"two\"", last_modified: nil}}
    ])

    bot = create_and_start_bot(feed)

    assert :ok = perform("f1")
    assert bot_messages() == []

    stored = BotQueries.get_bot(bot.id)

    [%{"seen" => seen, "etag" => "\"one\"", "last_error" => nil}] =
      get_in(stored.capabilities, ["rss", "feeds"])

    assert Enum.sort(seen) == ["urn:worker:1", "urn:worker:2"]

    assert :ok = perform("f1")
    assert [payload] = bot_messages()

    assert payload.content_format == "markdown"
    assert payload.content =~ "**Worker News** | Parsed worker story"

    assert payload.content =~
             "![Worker News preview image](<https://example.com/worker-card.png>)"

    assert payload.content =~ "> Worker extracted this from standards metadata\\."
    assert payload.content =~ "[Read full story](<https://example.com/3>)"
    assert %{type: "message", content_format: "markdown"} = ChatQueries.get_message(payload.id)

    assert_enqueued(
      worker: RSSPollWorker,
      queue: :rss,
      args: %{bot_id: bot.id, feed_id: "f1"}
    )
  end

  test "emits observable RSS poll telemetry" do
    feed = %{"id" => "f1", "url" => @url, "channel" => @channel, "seen" => []}

    ScriptedFetcher.script([
      {:ok, feed_page([{2, "Second"}, {1, "First"}]), %{etag: "\"one\"", last_modified: nil}}
    ])

    bot = create_and_start_bot(feed)
    attach_telemetry()

    assert :ok = perform("f1")

    assert_receive {:telemetry_event, [:retro_hex_chat, :bots, :rss, :poll, :stop],
                    %{duration: duration}, metadata}

    assert is_integer(duration)
    assert metadata.context == "bots"
    assert metadata.operation == "rss_poll"
    assert metadata.result == "ok"
    assert metadata.bot_id == bot.id
    assert metadata.feed_id == "f1"

    assert_receive {:telemetry_event, [:retro_hex_chat, :observability, :operation, :stop],
                    %{duration: _}, generic_metadata}

    assert generic_metadata.context == "bots"
    assert generic_metadata.operation == "rss_poll"
  end

  test "real Oban execution leaves a successor poll after the current job completes" do
    feed = %{"id" => "f1", "url" => @url, "channel" => @channel, "seen" => []}
    page = feed_page([{2, "Second"}, {1, "First"}])

    ScriptedFetcher.script([
      {:ok, page, %{etag: "\"one\"", last_modified: nil}}
    ])

    bot = create_and_start_bot(feed)

    assert_enqueued(
      worker: RSSPollWorker,
      queue: :rss,
      args: %{bot_id: bot.id, feed_id: "f1"}
    )

    assert %{success: 1, failure: 0} =
             Oban.drain_queue(queue: :rss, with_scheduled: true, with_limit: 1)

    assert bot_messages() == []

    assert [
             %Oban.Job{
               state: "scheduled",
               args: %{"bot_id" => bot_id, "feed_id" => "f1"}
             }
           ] =
             all_enqueued(
               worker: RSSPollWorker,
               queue: :rss,
               args: %{bot_id: bot.id, feed_id: "f1"}
             )

    assert bot_id == bot.id
  end

  defp attach_telemetry do
    test_pid = self()
    handler_id = {__MODULE__, make_ref()}

    :telemetry.attach_many(
      handler_id,
      [
        [:retro_hex_chat, :bots, :rss, :poll, :stop],
        [:retro_hex_chat, :observability, :operation, :stop]
      ],
      fn event, measurements, metadata, _config ->
        send(test_pid, {:telemetry_event, event, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)
  end

  test "poll completion does not push sibling feed jobs into the future" do
    feed_a = %{"id" => "f1", "url" => @url, "channel" => @channel, "seen" => []}

    feed_b = %{
      "id" => "f2",
      "url" => @url,
      "channel" => @channel,
      "seen" => ["urn:worker:99"],
      "last_polled_at" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    ScriptedFetcher.script([
      {:ok, feed_page([{2, "Second"}, {1, "First"}]), %{etag: "\"one\"", last_modified: nil}}
    ])

    bot = create_and_start_bot([feed_a, feed_b])

    [%Oban.Job{scheduled_at: sibling_before}] =
      all_enqueued(
        worker: RSSPollWorker,
        queue: :rss,
        args: %{bot_id: bot.id, feed_id: "f2"}
      )

    assert %{success: 1, failure: 0} =
             Oban.drain_queue(queue: :rss, with_scheduled: true, with_limit: 1)

    [%Oban.Job{scheduled_at: sibling_after}] =
      all_enqueued(
        worker: RSSPollWorker,
        queue: :rss,
        args: %{bot_id: bot.id, feed_id: "f2"}
      )

    assert sibling_after == sibling_before
  end

  @spec create_and_start_bot(map() | [map()]) :: RetroHexChat.Bots.Bot.t()
  defp create_and_start_bot(feed_or_feeds) do
    feeds = List.wrap(feed_or_feeds)

    {:ok, bot} =
      BotQueries.create_bot(%{
        name: "RSSWorkerBot",
        nickname: "RSSWorkerBot",
        created_by: "admin",
        capabilities: %{
          "rss" => %{
            "enabled" => true,
            "feeds" => feeds,
            "poll_interval_min" => 30,
            "max_items_per_poll" => 3
          }
        }
      })

    {:ok, _} = BotQueries.add_channel_config(bot.id, @channel)

    {:ok, _pid} =
      BotSupervisor.start_bot(%{
        id: bot.id,
        name: bot.name,
        nickname: bot.nickname,
        command_prefix: "!",
        created_by: "admin",
        enabled: true,
        cooldown_ms: 0,
        capabilities: bot.capabilities,
        channel_configs: [%{channel_name: @channel, enabled: true, capability_overrides: %{}}],
        custom_commands: []
      })

    bot
  end

  @spec perform(String.t()) :: :ok | {:cancel, String.t()} | {:error, term()}
  defp perform(feed_id) do
    %Oban.Job{
      args: %{"bot_id" => BotQueries.get_bot_by_nickname("RSSWorkerBot").id, "feed_id" => feed_id}
    }
    |> RSSPollWorker.perform()
  end

  @spec bot_messages() :: [map()]
  defp bot_messages do
    receive do
      %{event: "new_message", payload: %{author: "RSSWorkerBot"} = payload} ->
        [payload | bot_messages()]
    after
      300 -> []
    end
  end

  @spec feed_page([{integer(), String.t()}]) :: String.t()
  defp feed_page(items) do
    items =
      Enum.map(items, fn {id, title} ->
        """
        <item>
          <title>#{title}</title>
          <link>https://example.com/#{id}</link>
          <guid>urn:worker:#{id}</guid>
        </item>
        """
      end)

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0">
      <channel>
        <title>Worker Feed</title>
        #{Enum.join(items)}
      </channel>
    </rss>
    """
  end
end
