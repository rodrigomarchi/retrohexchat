defmodule RetroHexChat.Notifications.EnqueueTest do
  @moduledoc """
  Which messages are worth waking somebody up for.

  This is the decision that makes or breaks the feature, and it is made on the
  message path, before anything is encrypted or sent. Almost every line written
  on this server today comes from a bot, and almost every human line names
  nobody: if either of those turned into a job, the queue would be the whole
  traffic of the server and the notification would be the thing people turn off
  first.

  A channel message and a private message reach the same decision by two
  different code paths — `Chat.Service` and `Channels.Server` both insert and
  broadcast — so every assertion here is made twice, once per path, for as long
  as both exist.
  """
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Bots.Queries, as: BotQueries
  alias RetroHexChat.Bots.Registry, as: BotRegistry
  alias RetroHexChat.Bots.Supervisor, as: BotSupervisor
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Channels.Supervisor, as: ChannelSupervisor
  alias RetroHexChat.Chat.Service
  alias RetroHexChat.Jobs.PushDispatchWorker
  alias RetroHexChat.Services.RegisteredNick

  setup do
    Application.put_env(:web_push_ex, :vapid,
      public_key: "public",
      private_key: "private",
      subject: "mailto:push@example.com"
    )

    on_exit(fn -> Application.delete_env(:web_push_ex, :vapid) end)

    %{channel: open_channel("#push#{System.unique_integer([:positive])}")}
  end

  describe "a channel message, through Chat.Service" do
    test "naming somebody enqueues one dispatch", ctx do
      author = register("Author")
      {:ok, _} = Service.send_message(ctx.channel, author, "hey Reader are you there")

      assert [job] = enqueued()
      assert job.args["conversation"] == ctx.channel
      assert job.args["author"] == author
      assert "reader" in Enum.map(job.args["tokens"], &String.downcase/1)
    end

    # A line that names nobody can wake nobody. Enqueuing it anyway would put
    # every message on this server through the queue to learn that.
    test "naming nobody enqueues nothing", ctx do
      author = register("Quiet")
      {:ok, _} = Service.send_message(ctx.channel, author, "...")

      assert enqueued() == []
    end

    test "a bot's line enqueues nothing", ctx do
      bot = start_bot()
      {:ok, _} = Service.send_message(ctx.channel, bot, "hey Reader the feed updated")

      assert enqueued() == []
    end

    test "a system line enqueues nothing", ctx do
      {:ok, _} = Service.send_system_message(ctx.channel, "Reader has joined")

      assert enqueued() == []
    end

    test "an action enqueues like a message", ctx do
      author = register("Emoter")
      {:ok, _} = Service.send_message(ctx.channel, author, "waves at Reader", "action")

      assert [_] = enqueued()
    end
  end

  describe "a channel message, through Channels.Server" do
    test "naming somebody enqueues one dispatch", ctx do
      author = register("Runtime")
      :ok = join(ctx.channel, author)
      {:ok, _} = Server.send_message(ctx.channel, author, "hey Reader are you there")

      assert [job] = enqueued()
      assert job.args["conversation"] == ctx.channel
      assert job.args["author"] == author
    end

    test "naming nobody enqueues nothing", ctx do
      author = register("RtQuiet")
      :ok = join(ctx.channel, author)
      {:ok, _} = Server.send_message(ctx.channel, author, "...")

      assert enqueued() == []
    end

    test "a bot's line enqueues nothing", ctx do
      bot = start_bot()
      :ok = join(ctx.channel, bot)
      {:ok, _} = Server.send_message(ctx.channel, bot, "hey Reader the feed updated")

      assert enqueued() == []
    end
  end

  describe "a private message" do
    test "always enqueues, named or not" do
      sender = register("Sender")
      recipient = register("Recipient")
      {:ok, _} = Service.send_private_message(sender, recipient, "...")

      assert [job] = enqueued()
      assert job.args["nickname"] == recipient
      assert job.args["conversation"] == "pm:#{sender}"
    end

    test "a bot's private message enqueues nothing" do
      bot = start_bot()
      recipient = register("BotTarget")
      {:ok, _} = Service.send_private_message(bot, recipient, "your feed updated")

      assert enqueued() == []
    end
  end

  describe "with no VAPID keys" do
    setup do
      Application.delete_env(:web_push_ex, :vapid)
      :ok
    end

    test "a named channel line enqueues nothing", ctx do
      author = register("NoKeys")
      {:ok, _} = Service.send_message(ctx.channel, author, "hey Reader are you there")

      assert enqueued() == []
    end

    test "a private message enqueues nothing" do
      sender = register("NoKeysPm")
      recipient = register("NoKeysTo")
      {:ok, _} = Service.send_private_message(sender, recipient, "hello")

      assert enqueued() == []
    end
  end

  # A room where three people are talking at once is one thing happening, not
  # twenty. The window is what turns a conversation into a single notification.
  describe "bursts" do
    test "two lines in the same channel inside the window are one job", ctx do
      author = register("Burst")
      {:ok, _} = Service.send_message(ctx.channel, author, "hey Reader")
      {:ok, _} = Service.send_message(ctx.channel, author, "hey Reader again")

      assert [_] = enqueued()
    end

    test "two lines in different channels are two jobs", ctx do
      other = open_channel("#other#{System.unique_integer([:positive])}")
      author = register("TwoRooms")
      {:ok, _} = Service.send_message(ctx.channel, author, "hey Reader")
      {:ok, _} = Service.send_message(other, author, "hey Reader")

      assert length(enqueued()) == 2
    end

    test "two private messages from the same sender are one job" do
      sender = register("PmBurst")
      recipient = register("PmBurstTo")
      {:ok, _} = Service.send_private_message(sender, recipient, "one")
      {:ok, _} = Service.send_private_message(sender, recipient, "two")

      assert [_] = enqueued()
    end
  end

  defp enqueued do
    all_enqueued(worker: PushDispatchWorker)
  end

  defp register(prefix) do
    nickname = "#{prefix}#{System.unique_integer([:positive])}" |> String.slice(0, 16)

    {:ok, _} =
      Repo.insert(%RegisteredNick{
        nickname: nickname,
        password_hash: "x",
        registered_at: DateTime.utc_now(),
        last_seen_at: DateTime.utc_now()
      })

    nickname
  end

  defp open_channel(name) do
    {:ok, pid} = ChannelSupervisor.start_child(name)

    on_exit(fn ->
      if Process.alive?(pid), do: ChannelSupervisor.stop_child(ChannelSupervisor, pid)
    end)

    name
  end

  defp join(channel, nickname) do
    {:ok, _} = Server.join(channel, nickname)
    :ok
  end

  # A bot is a running process, not a row: `Bots.Registry.bot?/1` asks the
  # registry, which is exactly the question the enqueue path asks.
  defp start_bot do
    nickname = "Bot#{System.unique_integer([:positive])}" |> String.slice(0, 16)

    {:ok, bot} =
      BotQueries.create_bot(%{
        name: nickname,
        nickname: nickname,
        created_by: "tester"
      })

    {:ok, pid} =
      BotSupervisor.start_bot(%{
        id: bot.id,
        name: bot.name,
        nickname: bot.nickname,
        command_prefix: bot.command_prefix || "!",
        created_by: bot.created_by,
        enabled: true,
        cooldown_ms: 2000,
        capabilities: bot.capabilities,
        channel_configs: [],
        custom_commands: []
      })

    on_exit(fn -> if Process.alive?(pid), do: BotSupervisor.stop_bot(nickname) end)

    assert BotRegistry.bot?(nickname)

    nickname
  end
end
