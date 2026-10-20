defmodule RetroHexChat.Chat.FloodTrackerTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.Chat.FloodTracker

  @moduletag :unit

  describe "record_message/2" do
    test "tracks multiple senders independently" do
      tracker =
        FloodTracker.new()
        |> FloodTracker.record_message("userA")
        |> FloodTracker.record_message("userB")

      assert Map.has_key?(tracker.senders, "usera")
      assert Map.has_key?(tracker.senders, "userb")
    end

    test "evicts oldest sender when cap is reached" do
      tracker = %{FloodTracker.new() | max_senders: 3}

      tracker =
        tracker
        |> FloodTracker.record_message("first")
        |> FloodTracker.record_message("second")
        |> FloodTracker.record_message("third")

      assert map_size(tracker.senders) == 3

      # Adding a 4th should evict the oldest
      tracker = FloodTracker.record_message(tracker, "fourth")
      assert map_size(tracker.senders) == 3
      refute Map.has_key?(tracker.senders, "first")
      assert Map.has_key?(tracker.senders, "fourth")
    end

    test "does not evict when adding to existing sender" do
      tracker = %{FloodTracker.new() | max_senders: 2}

      tracker =
        tracker
        |> FloodTracker.record_message("first")
        |> FloodTracker.record_message("second")
        |> FloodTracker.record_message("first")

      assert map_size(tracker.senders) == 2
      assert length(tracker.senders["first"].timestamps) == 2
    end
  end

  describe "flooded?/4" do
    test "returns false when below threshold" do
      tracker =
        FloodTracker.new()
        |> FloodTracker.record_message("sender")
        |> FloodTracker.record_message("sender")

      refute FloodTracker.flooded?(tracker, "sender", 3, 15)
    end

    test "returns true when at threshold" do
      tracker =
        FloodTracker.new()
        |> FloodTracker.record_message("sender")
        |> FloodTracker.record_message("sender")
        |> FloodTracker.record_message("sender")

      assert FloodTracker.flooded?(tracker, "sender", 3, 15)
    end

    test "returns true when above threshold" do
      tracker =
        FloodTracker.new()
        |> FloodTracker.record_message("sender")
        |> FloodTracker.record_message("sender")
        |> FloodTracker.record_message("sender")
        |> FloodTracker.record_message("sender")

      assert FloodTracker.flooded?(tracker, "sender", 3, 15)
    end

    test "returns false for unknown sender" do
      tracker = FloodTracker.new()
      refute FloodTracker.flooded?(tracker, "unknown", 3, 15)
    end

    test "is case-insensitive" do
      tracker =
        FloodTracker.new()
        |> FloodTracker.record_message("Sender")
        |> FloodTracker.record_message("SENDER")
        |> FloodTracker.record_message("sender")

      assert FloodTracker.flooded?(tracker, "SENDER", 3, 15)
    end
  end

  describe "prune_expired/2" do
    test "removes senders with no recent timestamps" do
      # Create a tracker with an old timestamp
      old_ts = System.monotonic_time(:millisecond) - 20_000

      tracker = %{
        FloodTracker.new()
        | senders: %{"old" => %{timestamps: [old_ts], added_at: old_ts}}
      }

      pruned = FloodTracker.prune_expired(tracker, 15)
      assert pruned.senders == %{}
    end

    test "keeps senders with recent timestamps" do
      tracker = FloodTracker.new() |> FloodTracker.record_message("recent")
      pruned = FloodTracker.prune_expired(tracker, 15)
      assert Map.has_key?(pruned.senders, "recent")
    end
  end

  describe "reset_sender/2" do
    test "removes tracking data for specific sender" do
      tracker =
        FloodTracker.new()
        |> FloodTracker.record_message("target")
        |> FloodTracker.record_message("other")

      reset = FloodTracker.reset_sender(tracker, "target")
      refute Map.has_key?(reset.senders, "target")
      assert Map.has_key?(reset.senders, "other")
    end

    test "is case-insensitive" do
      tracker = FloodTracker.new() |> FloodTracker.record_message("Target")
      reset = FloodTracker.reset_sender(tracker, "TARGET")
      refute Map.has_key?(reset.senders, "target")
    end

    test "returns unchanged tracker for unknown sender" do
      tracker = FloodTracker.new()
      assert FloodTracker.reset_sender(tracker, "unknown") == tracker
    end
  end
end
