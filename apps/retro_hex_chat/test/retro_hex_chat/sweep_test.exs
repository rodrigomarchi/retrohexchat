defmodule RetroHexChat.SweepTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.Sweep

  describe "tally/3" do
    test "counts each outcome beside the batch size" do
      step = fn
        :gone -> {:ok, :expired}
        :taken -> {:ok, :skipped}
        {:file, bytes} -> {:ok, %{expired: 1, bytes: bytes}}
      end

      assert Sweep.tally(
               [:gone, :taken, {:file, 10}, {:file, 5}],
               %{expired: 0, skipped: 0, bytes: 0},
               step
             ) ==
               {:ok, %{candidates: 4, expired: 3, skipped: 1, bytes: 15}}
    end

    test "stops at the first error without running the rest" do
      parent = self()

      step = fn candidate ->
        send(parent, {:ran, candidate})
        if candidate == 2, do: {:error, :db_down}, else: {:ok, :expired}
      end

      assert Sweep.tally([1, 2, 3], %{expired: 0}, step) == {:error, :db_down}
      refute_received {:ran, 3}
    end

    test "an empty batch reports zero candidates" do
      assert Sweep.tally([], %{expired: 0}, fn _ -> flunk("no step") end) ==
               {:ok, %{candidates: 0, expired: 0}}
    end
  end

  describe "positive_option/3" do
    test "keeps a positive integer and falls back otherwise" do
      assert Sweep.positive_option([limit: 5], :limit, 100) == 5

      for value <- [0, -1, "5", nil] do
        assert Sweep.positive_option([limit: value], :limit, 100) == 100
      end

      assert Sweep.positive_option([], :limit, 100) == 100
    end
  end
end
