defmodule RetroHexChat.Bots.OutputTelemetryTest do
  @moduledoc """
  The producing side of a flood has to be visible on its own.

  An auto-ignore is only reported when a reader is present to be bothered by it,
  so a burst into an empty channel at four in the morning left no trace on either
  side. Throttling does leave one, and it arrives first: the pacer knows a bot is
  pressing against the limit before any reader does.
  """
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Bots.Output
  alias RetroHexChat.Bots.Pace
  alias RetroHexChat.Channels

  @sent [:retro_hex_chat, :bots, :output, :sent]
  @throttled [:retro_hex_chat, :bots, :output, :throttled]

  setup do
    handler = "output-telemetry-#{System.unique_integer([:positive])}"
    test = self()

    :telemetry.attach_many(
      handler,
      [@sent, @throttled],
      fn event, measurements, metadata, _config ->
        send(test, {:telemetry, List.last(event), measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler) end)

    channel = "#out#{System.unique_integer([:positive])}"
    {:ok, _pid} = Channels.Supervisor.start_child(channel)

    %{channel: channel}
  end

  defp output(content), do: %{delivery: :public, content: content}

  # A bot only speaks in a room it is in, exactly like a person.
  defp bot_in(channel, prefix) do
    nickname = "#{prefix}#{System.unique_integer([:positive])}"
    {:ok, _} = Channels.Server.join(channel, nickname)
    nickname
  end

  test "a delivered message is counted, with the bot and channel that sent it", %{
    channel: channel
  } do
    bot = bot_in(channel, "Wire")

    assert :ok = Output.send(channel, bot, output("one headline"))

    assert_receive {:telemetry, :sent, measurements, metadata}, 1_000
    assert measurements.count == 1
    assert metadata.bot == bot
    assert metadata.channel == channel
    assert metadata.type == "message"
  end

  test "a batch reports what the pacer held back, and for how long", %{channel: channel} do
    bot = bot_in(channel, "Burst")
    interval = Pace.interval_ms()

    assert :ok = Output.send_many(channel, bot, Enum.map(1..3, &output("item #{&1}")))

    # The first message of a batch from a quiet bot goes out free; the two
    # behind it each wait. The waits do not grow, because the caller sleeps
    # through each one — every reservation is measured from a later instant, so
    # a steady batch is a steady drip of about one interval apiece.
    assert_receive {:telemetry, :throttled, first, metadata}, 5_000
    assert first.count == 1
    assert metadata.bot == bot
    assert metadata.channel == channel
    assert first.delay_ms <= interval and first.delay_ms > div(interval, 2)

    assert_receive {:telemetry, :throttled, second, _metadata}, 5_000
    assert second.delay_ms <= interval and second.delay_ms > div(interval, 2)

    refute_receive {:telemetry, :throttled, _measurements, _metadata},
                   300,
                   "three messages cost two waits, not three — the first one was free"
  end

  test "a message that goes out without waiting reports no throttling", %{channel: channel} do
    bot = bot_in(channel, "Quiet")

    assert :ok = Output.send(channel, bot, output("only one"))

    assert_receive {:telemetry, :sent, _measurements, _metadata}, 1_000

    refute_receive {:telemetry, :throttled, _measurements, _metadata},
                   300,
                   "a bot under the limit must not look throttled"
  end
end
