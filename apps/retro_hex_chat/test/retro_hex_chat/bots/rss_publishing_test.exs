defmodule RetroHexChat.Bots.RSSPublishingTest do
  @moduledoc """
  The whole chain, once: a poll fires, a feed is read, and a headline appears in
  the channel — then does not appear again.

  Everything else about RSS is tested a layer at a time. This is the only test
  that runs the layers together, which is where the interesting failures were:
  a feed nobody polled, a greeting that ate the reply, a parser that rejected
  every real document. The fetcher is injected because the guard, correctly,
  refuses to fetch from loopback, so there is no serving a fixture locally.
  """
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Bots.{Queries, Supervisor}
  alias RetroHexChat.Channels

  @channel "#wire"
  @url "https://93.184.216.34/feed.xml"

  defmodule ScriptedFetcher do
    @moduledoc false
    @behaviour RetroHexChat.Bots.Capabilities.RSS.Fetcher

    @impl true
    def fetch(_url, _etag, _last_modified) do
      case Agent.get_and_update(__MODULE__, fn [head | rest] ->
             {head, rest_or_repeat(rest, head)}
           end) do
        {:error, _} = err -> err
        body -> {:ok, body, %{etag: nil, last_modified: nil}}
      end
    end

    defp rest_or_repeat([], last), do: [last]
    defp rest_or_repeat(rest, _last), do: rest

    def script(pages) do
      case Process.whereis(__MODULE__) do
        nil -> Agent.start_link(fn -> pages end, name: __MODULE__)
        _pid -> Agent.update(__MODULE__, fn _ -> pages end)
      end
    end
  end

  defp feed_page(titles) do
    items =
      Enum.map(titles, fn {id, title} ->
        """
        <item>
          <title>#{title}</title>
          <link>https://example.com/#{id}</link>
          <guid>urn:wire:#{id}</guid>
        </item>
        """
      end)

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0">
      <channel>
        <title>The Wire</title>
        #{Enum.join(items)}
      </channel>
    </rss>
    """
  end

  defp start_bot(feeds) do
    {:ok, bot} =
      Queries.create_bot(%{
        name: "WireBot",
        nickname: "WireBot",
        created_by: "admin",
        capabilities: %{
          "rss" => %{"enabled" => true, "feeds" => feeds, "max_items_per_poll" => 3}
        }
      })

    {:ok, _} = Queries.add_channel_config(bot.id, @channel)

    {:ok, pid} =
      Supervisor.start_bot(%{
        id: bot.id,
        name: bot.name,
        nickname: bot.nickname,
        command_prefix: "!",
        created_by: "admin",
        enabled: true,
        cooldown_ms: 0,
        capabilities: bot.capabilities,
        channel_configs: [
          %{channel_name: @channel, enabled: true, capability_overrides: %{}}
        ],
        custom_commands: []
      })

    {bot, pid}
  end

  defp poll(pid),
    do: send(pid, {:capability_timer, :rss, %{type: :poll, feed_id: "f1", channel: @channel}})

  defp headlines do
    receive do
      %{event: "new_message", payload: %{author: "WireBot", content: content}} ->
        [content | headlines()]
    after
      300 -> []
    end
  end

  setup do
    Application.put_env(:retro_hex_chat, :rss_fetcher, ScriptedFetcher)
    {:ok, chan} = Channels.Supervisor.start_child(@channel)
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "channel:#{@channel}")

    on_exit(fn ->
      Application.delete_env(:retro_hex_chat, :rss_fetcher)
      Supervisor.stop_bot("WireBot")
      if Process.alive?(chan), do: Channels.Supervisor.stop_child(chan)
    end)

    :ok
  end

  @unseen [%{"id" => "f1", "url" => @url, "channel" => @channel, "seen" => []}]

  test "the first poll posts one headline and learns the rest of the page" do
    # Listed newest first, so item 3 is the newest.
    ScriptedFetcher.script([feed_page([{3, "Newest story"}, {2, "Middle"}, {1, "Oldest"}])])
    {_bot, pid} = start_bot(@unseen)

    poll(pid)
    lines = headlines()

    assert length(lines) == 1,
           "one headline proves the feed works without dumping its archive"

    assert hd(lines) =~ "Newest story"
  end

  test "the next poll announces only what arrived since" do
    page1 = feed_page([{2, "Newer story"}, {1, "Older story"}])
    page2 = feed_page([{3, "Breaking news"}, {2, "Newer story"}, {1, "Older story"}])

    ScriptedFetcher.script([page1, page2])
    {_bot, pid} = start_bot(@unseen)

    poll(pid)
    assert [first] = headlines()
    assert first =~ "Newer story", "the first poll introduces the feed"

    poll(pid)
    lines = headlines()

    assert length(lines) == 1
    assert hd(lines) =~ "Breaking news"
    assert hd(lines) =~ "The Wire"
    assert hd(lines) =~ "https://example.com/3"
  end

  test "the same page twice is not news twice" do
    page = feed_page([{2, "Newer story"}, {1, "Older story"}])
    ScriptedFetcher.script([page, page, page])
    {_bot, pid} = start_bot(@unseen)

    poll(pid)
    assert [_introduction] = headlines()

    poll(pid)
    poll(pid)

    assert headlines() == [], "nothing changed, so there is nothing to say"
  end

  test "what it has published outlives the process" do
    page1 = feed_page([{1, "Older story"}])
    page2 = feed_page([{2, "Newer story"}, {1, "Older story"}])

    ScriptedFetcher.script([page1, page2])
    {bot, pid} = start_bot(@unseen)

    poll(pid)
    assert [_introduction] = headlines()
    poll(pid)
    assert [line] = headlines()
    assert line =~ "Newer story"

    # The bot dies and comes back, as it does on every deploy.
    Supervisor.stop_bot("WireBot")
    stored = Queries.get_bot(bot.id)

    ScriptedFetcher.script([page2])

    {:ok, pid2} =
      Supervisor.start_bot(%{
        id: stored.id,
        name: stored.name,
        nickname: stored.nickname,
        command_prefix: "!",
        created_by: "admin",
        enabled: true,
        cooldown_ms: 0,
        capabilities: stored.capabilities,
        channel_configs: [%{channel_name: @channel, enabled: true, capability_overrides: %{}}],
        custom_commands: []
      })

    poll(pid2)

    assert headlines() == [],
           "a restart must not replay the day's news into the channel"
  end

  test "a failure is recorded on the feed rather than swallowed" do
    ScriptedFetcher.script([{:error, "HTTP 503"}])
    {_bot, pid} = start_bot(@unseen)

    poll(pid)
    Process.sleep(80)

    assert headlines() == []

    %{feeds: [feed]} = :sys.get_state(pid).capability_states[:rss]
    assert feed["last_error"] =~ "503"
    assert feed["last_polled_at"], "an operator needs to see that it tried"
  end

  describe "a forced check" do
    defp check(pid, author \\ "operator") do
      send(pid, %{
        event: "new_message",
        payload: %{
          id: 99,
          channel: @channel,
          author: author,
          content: "!WireBot rss check f1",
          type: :message,
          timestamp: DateTime.utc_now(),
          reply_to_id: nil,
          reply_to_author: nil,
          reply_to_preview: nil
        }
      })
    end

    setup do
      # The command needs operator standing, and the first human in owns the room.
      {:ok, _} = Channels.Server.join(@channel, "operator")
      :ok
    end

    test "publishes what it finds instead of eating it" do
      page1 = feed_page([{1, "Older story"}])
      page2 = feed_page([{2, "Breaking news"}, {1, "Older story"}])

      ScriptedFetcher.script([page1, page2])
      {_bot, pid} = start_bot(@unseen)

      poll(pid)
      assert [_introduction] = headlines()

      check(pid)
      lines = headlines()

      assert Enum.any?(lines, &(&1 =~ "Breaking news")),
             "a forced check that reports new items and prints none has consumed them: " <>
               "they are marked seen and can never arrive"
    end

    test "what a check published is not published again by the next poll" do
      page1 = feed_page([{1, "Older story"}])
      page2 = feed_page([{2, "Breaking news"}, {1, "Older story"}])

      ScriptedFetcher.script([page1, page2])
      {_bot, pid} = start_bot(@unseen)

      poll(pid)
      assert [_introduction] = headlines()
      check(pid)
      assert Enum.any?(headlines(), &(&1 =~ "Breaking news"))

      poll(pid)
      assert headlines() == []
    end

    test "a check with nothing new keeps the record of having run" do
      page = feed_page([{1, "Older story"}])
      ScriptedFetcher.script([page, page])
      {_bot, pid} = start_bot(@unseen)

      poll(pid)
      assert [_introduction] = headlines()

      check(pid)
      Process.sleep(120)

      %{feeds: [feed]} = :sys.get_state(pid).capability_states[:rss]

      assert feed["last_polled_at"],
             "the check ran; dropping its state loses when it ran and why it failed"
    end
  end
end
