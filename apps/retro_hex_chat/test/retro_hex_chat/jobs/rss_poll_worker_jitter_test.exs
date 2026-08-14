defmodule RetroHexChat.Jobs.RSSPollWorkerJitterTest do
  @moduledoc """
  Feeds sharing an interval have to drift apart.

  Provisioning gave 132 feeds the same twenty minutes and a restart put them all
  on the same clock, so they arrived as a cohort — which is how the burst that
  exhausted file descriptors happened, and how several feeds of one bot land on
  a reader's flood counter at the same moment.
  """
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Jobs.RSSPollWorker

  @interval :timer.minutes(20)

  test "a delay stays within a tenth of what was asked" do
    spread = div(@interval, 10)

    for _ <- 1..500 do
      delay = RSSPollWorker.jitter(@interval)

      assert delay >= @interval - spread,
             "a feed must not drift so early that its cadence changes"

      assert delay <= @interval + spread,
             "nor so late"
    end
  end

  test "a cohort on one clock spreads out" do
    delays = for _ <- 1..200, do: RSSPollWorker.jitter(@interval)
    distinct = delays |> Enum.uniq() |> length()

    assert distinct > 100,
           "200 feeds due together produced only #{distinct} distinct delays — still a cohort"
  end

  test "the spread is centred, not a systematic delay" do
    # A jitter that only ever added would push every feed's cadence out over
    # time; one that only subtracted would tighten it.
    delays = for _ <- 1..2000, do: RSSPollWorker.jitter(@interval)
    mean = Enum.sum(delays) / length(delays)

    assert_in_delta mean, @interval, @interval * 0.01
    assert Enum.any?(delays, &(&1 < @interval)), "nothing ever came early"
    assert Enum.any?(delays, &(&1 > @interval)), "nothing ever came late"
  end

  test "a short drain delay still jitters without going negative" do
    for _ <- 1..200 do
      delay = RSSPollWorker.jitter(1)
      assert delay >= 0
    end
  end

  test "an immediate poll stays immediate" do
    assert RSSPollWorker.jitter(0) == 0
  end
end
