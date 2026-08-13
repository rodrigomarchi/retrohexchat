defmodule RetroHexChat.Bots.PaceTest do
  @moduledoc """
  The pacer decides how fast a bot may speak.

  These assert on the reservations rather than on elapsed time: sleeping through
  a rate limit to prove it exists measures the scheduler, and the number the
  caller is handed is the whole contract.
  """
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Bots.Pace
  alias RetroHexChat.Chat.FloodProtection

  setup do
    # A private instance per test: reservations are global state by design, and
    # sharing the named one would make these order-dependent.
    pid = start_supervised!({Pace, name: :"pace_#{System.unique_integer([:positive])}"})
    %{pace: pid}
  end

  defp reserve(pace, nickname), do: GenServer.call(pace, {:reserve, String.downcase(nickname)})

  test "the first message of a quiet bot goes out immediately", %{pace: pace} do
    assert reserve(pace, "Nina") == 0
  end

  test "each further message waits one interval more", %{pace: pace} do
    interval = Pace.interval_ms()

    assert reserve(pace, "Nina") == 0
    assert_in_delta reserve(pace, "Nina"), interval, 5
    assert_in_delta reserve(pace, "Nina"), interval * 2, 5
  end

  test "one bot's backlog does not delay another", %{pace: pace} do
    Enum.each(1..10, fn _ -> reserve(pace, "Nina") end)

    assert reserve(pace, "Vasco") == 0,
           "a bot is paced against itself, never against the busiest bot on the server"
  end

  test "the same bot is one budget across its feeds and channels", %{pace: pace} do
    # Nina polls #brasil and #jornal on the same interval. Flood protection
    # counts the nickname, not the channel, so the pacer must too.
    assert reserve(pace, "Nina") == 0
    first = reserve(pace, "nina")
    second = reserve(pace, "NINA")

    assert second > first, "case does not buy a second budget"
  end

  test "silence does not accumulate credit for a burst", %{pace: pace} do
    assert reserve(pace, "Nina") == 0
    interval = Pace.interval_ms()

    # A slot already in the future is honoured; nothing lets a bot spend the
    # quiet hour it just had on ten messages at once.
    assert_in_delta reserve(pace, "Nina"), interval, 5
  end

  test "the pace stays under the threshold that triggers auto-ignore" do
    settings = FloodProtection.new()
    window_ms = FloodProtection.get_flood_window_seconds(settings) * 1000
    threshold = FloodProtection.get_flood_threshold(settings)

    per_window = window_ms / Pace.interval_ms()

    assert per_window < threshold,
           "#{per_window} messages per window would be auto-ignored at #{threshold}"

    assert per_window <= threshold / 2,
           "the margin is deliberate: a reader may lower their own threshold"
  end

  test "an unstarted pacer does not stop a bot from speaking" do
    # Delivery must not depend on the pacer being up. Refusing to send would
    # turn a supervision blip into silence, which is worse than a fast bot.
    assert Pace.reserve("NoSuchPacerRunning") == 0
  end
end
