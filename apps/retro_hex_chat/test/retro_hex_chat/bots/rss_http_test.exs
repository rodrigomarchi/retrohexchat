defmodule RetroHexChat.Bots.RSSHTTPTest do
  @moduledoc """
  The one path that talks to the network, over a real socket.

  Every other RSS test injects a fetcher, which left `Fetcher.HTTP` — the
  request, the redirect, the conditional headers, the decoding of the body Req
  hands back — with no test at all. That is precisely the layer nobody could
  vouch for when production went quiet, so it gets a real HTTP server and a real
  request.

  The guard refuses loopback, which is why this could not be written before;
  `:rss_allow_private_addresses` opens it for the duration of the test only.
  """
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Bots.Capabilities.RSS.Fetcher
  alias RetroHexChat.Bots.{Queries, Supervisor}
  alias RetroHexChat.Channels

  @channel "#wire-http"

  # A feed with the characters that broke the parser against every real source.
  @feed """
  <?xml version="1.0" encoding="UTF-8"?>
  <rss version="2.0">
    <channel>
      <title>Notícias — the wire</title>
      <item>
        <title>It’s here — the “long-awaited” one…</title>
        <link>http://example.com/2</link>
        <guid>urn:http:2</guid>
      </item>
      <item>
        <title>Older story</title>
        <link>http://example.com/1</link>
        <guid>urn:http:1</guid>
      </item>
    </channel>
  </rss>
  """

  defmodule FeedServer do
    @moduledoc false

    # A socket that speaks just enough HTTP: the point is that Req makes a real
    # request over a real connection, not that this is a web server.
    def start(body) do
      {:ok, socket} = :gen_tcp.listen(0, [:binary, packet: :raw, active: false, reuseaddr: true])
      {:ok, port} = :inet.port(socket)

      pid =
        spawn_link(fn ->
          serve(socket, body)
        end)

      {pid, port, socket}
    end

    defp serve(listen, body) do
      case :gen_tcp.accept(listen) do
        {:ok, conn} ->
          _request = :gen_tcp.recv(conn, 0, 2_000)

          response =
            "HTTP/1.1 200 OK\r\n" <>
              "content-type: application/rss+xml; charset=utf-8\r\n" <>
              "etag: \"wire-1\"\r\n" <>
              "content-length: #{byte_size(body)}\r\n" <>
              "connection: close\r\n\r\n" <> body

          :gen_tcp.send(conn, response)
          :gen_tcp.close(conn)
          serve(listen, body)

        {:error, :closed} ->
          :ok
      end
    end
  end

  defmodule NoopPreview do
    @moduledoc false
    @behaviour RetroHexChat.Chat.LinkPreview

    @impl true
    def fetch_title(_url), do: {:error, :fetch_failed}

    @impl true
    def fetch_metadata(_url), do: {:error, :fetch_failed}
  end

  setup do
    Application.put_env(:retro_hex_chat, :rss_allow_private_addresses, true)
    Application.put_env(:retro_hex_chat, :link_preview_fetcher, NoopPreview)
    {server, port, socket} = FeedServer.start(@feed)
    {:ok, chan} = Channels.Supervisor.start_child(@channel)
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "channel:#{@channel}")

    on_exit(fn ->
      Application.delete_env(:retro_hex_chat, :rss_allow_private_addresses)
      Application.delete_env(:retro_hex_chat, :link_preview_fetcher)
      Supervisor.stop_bot("HttpWireBot")
      if Process.alive?(server), do: Process.exit(server, :kill)
      :gen_tcp.close(socket)
      if Process.alive?(chan), do: Channels.Supervisor.stop_child(chan)
    end)

    {:ok, url: "http://127.0.0.1:#{port}/feed.xml"}
  end

  defp headlines do
    receive do
      %{event: "new_message", payload: %{author: "HttpWireBot", content: content}} ->
        [content | headlines()]
    after
      500 -> []
    end
  end

  defp start_bot(url, seen) do
    feeds = [%{"id" => "f1", "url" => url, "channel" => @channel, "seen" => seen}]

    {:ok, bot} =
      Queries.create_bot(%{
        name: "HttpWireBot",
        nickname: "HttpWireBot",
        created_by: "admin",
        capabilities: %{"rss" => %{"enabled" => true, "feeds" => feeds}}
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
        channel_configs: [%{channel_name: @channel, enabled: true, capability_overrides: %{}}],
        custom_commands: []
      })

    pid
  end

  defp poll(pid),
    do: send(pid, {:capability_timer, :rss, %{type: :poll, feed_id: "f1", channel: @channel}})

  describe "Fetcher.HTTP" do
    test "fetches and parses over a real connection", %{url: url} do
      assert {:ok, body, headers} = Fetcher.HTTP.fetch(url, nil, nil)

      assert body =~ "Notícias"
      assert headers.etag == "\"wire-1\""
    end

    test "still refuses a private address when the flag is off", %{url: url} do
      Application.delete_env(:retro_hex_chat, :rss_allow_private_addresses)

      assert {:error, {:blocked, reason}} = Fetcher.HTTP.fetch(url, nil, nil)
      assert reason =~ "public"
    end
  end

  describe "the whole chain over HTTP" do
    test "a headline reaches the channel", %{url: url} do
      # Already primed with the older item, so the newer one is news.
      pid = start_bot(url, ["urn:http:1"])

      poll(pid)
      lines = headlines()

      assert length(lines) == 1
      line = hd(lines)

      assert line =~ "**Notícias**",
             "the label is the publisher's name, not its whole tagline"

      assert line =~ "It’s here — the “long\\-awaited” one…",
             "the characters that broke the parser against every real feed"

      assert line =~ "http://example.com/2"
    end

    test "a feed added fresh stays quiet and learns the page", %{url: url} do
      pid = start_bot(url, [])

      poll(pid)

      assert headlines() == [],
             "a real first fetch should seed history without posting old headlines"

      %{feeds: [feed]} = :sys.get_state(pid).capability_states[:rss]
      assert length(feed["seen"]) == 2, "it should have learned the page it just read"
      assert feed["title"] == "Notícias — the wire"
      assert feed["etag"] == "\"wire-1\"", "the etag is what makes the next poll cheap"
      refute feed["last_error"]
    end
  end
end
