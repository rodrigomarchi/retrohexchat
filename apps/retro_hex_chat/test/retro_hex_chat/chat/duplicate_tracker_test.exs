defmodule RetroHexChat.Chat.DuplicateTrackerTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.Chat.DuplicateTracker

  @moduletag :unit

  describe "new/0" do
    test "returns empty tracker with max_senders cap" do
      tracker = DuplicateTracker.new()
      assert tracker.entries == %{}
      assert tracker.max_senders == 50
    end
  end

  describe "record_message/4" do
    test "stores message content for sender-target pair" do
      tracker =
        DuplicateTracker.new()
        |> DuplicateTracker.record_message("sender", {:channel, "#test"}, "hello")

      key = {"sender", {:channel, "#test"}}
      assert Map.has_key?(tracker.entries, key)
      assert length(tracker.entries[key]) == 1
      assert hd(tracker.entries[key]).content == "hello"
    end

    test "accumulates multiple messages for same pair" do
      tracker =
        DuplicateTracker.new()
        |> DuplicateTracker.record_message("sender", {:channel, "#test"}, "hello")
        |> DuplicateTracker.record_message("sender", {:channel, "#test"}, "hello")
        |> DuplicateTracker.record_message("sender", {:channel, "#test"}, "world")

      key = {"sender", {:channel, "#test"}}
      assert length(tracker.entries[key]) == 3
    end

    test "is case-insensitive on sender" do
      tracker =
        DuplicateTracker.new()
        |> DuplicateTracker.record_message("Sender", {:channel, "#test"}, "hello")
        |> DuplicateTracker.record_message("SENDER", {:channel, "#test"}, "hello")

      key = {"sender", {:channel, "#test"}}
      assert length(tracker.entries[key]) == 2
    end

    test "tracks different targets independently" do
      tracker =
        DuplicateTracker.new()
        |> DuplicateTracker.record_message("sender", {:channel, "#one"}, "hello")
        |> DuplicateTracker.record_message("sender", {:channel, "#two"}, "hello")

      key1 = {"sender", {:channel, "#one"}}
      key2 = {"sender", {:channel, "#two"}}
      assert length(tracker.entries[key1]) == 1
      assert length(tracker.entries[key2]) == 1
    end
  end

  describe "duplicate?/6" do
    test "returns false below threshold" do
      tracker =
        DuplicateTracker.new()
        |> DuplicateTracker.record_message("sender", {:channel, "#test"}, "spam")
        |> DuplicateTracker.record_message("sender", {:channel, "#test"}, "spam")

      refute DuplicateTracker.duplicate?(tracker, "sender", {:channel, "#test"}, "spam", 3, 10)
    end

    test "returns true at threshold" do
      tracker =
        DuplicateTracker.new()
        |> DuplicateTracker.record_message("sender", {:channel, "#test"}, "spam")
        |> DuplicateTracker.record_message("sender", {:channel, "#test"}, "spam")
        |> DuplicateTracker.record_message("sender", {:channel, "#test"}, "spam")

      assert DuplicateTracker.duplicate?(tracker, "sender", {:channel, "#test"}, "spam", 3, 10)
    end

    test "returns false for different content" do
      tracker =
        DuplicateTracker.new()
        |> DuplicateTracker.record_message("sender", {:channel, "#test"}, "spam")
        |> DuplicateTracker.record_message("sender", {:channel, "#test"}, "spam")
        |> DuplicateTracker.record_message("sender", {:channel, "#test"}, "spam")

      refute DuplicateTracker.duplicate?(
               tracker,
               "sender",
               {:channel, "#test"},
               "not spam",
               3,
               10
             )
    end

    test "only matches exact content, not similar" do
      tracker =
        DuplicateTracker.new()
        |> DuplicateTracker.record_message("sender", {:channel, "#test"}, "hello world")
        |> DuplicateTracker.record_message("sender", {:channel, "#test"}, "hello world")
        |> DuplicateTracker.record_message("sender", {:channel, "#test"}, "hello world!")

      refute DuplicateTracker.duplicate?(
               tracker,
               "sender",
               {:channel, "#test"},
               "hello world!",
               3,
               10
             )
    end

    test "different targets are independent" do
      tracker =
        DuplicateTracker.new()
        |> DuplicateTracker.record_message("sender", {:channel, "#one"}, "spam")
        |> DuplicateTracker.record_message("sender", {:channel, "#one"}, "spam")
        |> DuplicateTracker.record_message("sender", {:channel, "#two"}, "spam")

      refute DuplicateTracker.duplicate?(
               tracker,
               "sender",
               {:channel, "#one"},
               "spam",
               3,
               10
             )

      refute DuplicateTracker.duplicate?(
               tracker,
               "sender",
               {:channel, "#two"},
               "spam",
               3,
               10
             )
    end

    test "is case-insensitive on sender" do
      tracker =
        DuplicateTracker.new()
        |> DuplicateTracker.record_message("Sender", {:channel, "#test"}, "spam")
        |> DuplicateTracker.record_message("SENDER", {:channel, "#test"}, "spam")
        |> DuplicateTracker.record_message("sender", {:channel, "#test"}, "spam")

      assert DuplicateTracker.duplicate?(
               tracker,
               "SENDER",
               {:channel, "#test"},
               "spam",
               3,
               10
             )
    end

    test "returns false for unknown sender-target pair" do
      tracker = DuplicateTracker.new()

      refute DuplicateTracker.duplicate?(
               tracker,
               "unknown",
               {:channel, "#test"},
               "hello",
               3,
               10
             )
    end
  end

  describe "duplicate_count/5" do
    test "returns count of matching messages" do
      tracker =
        DuplicateTracker.new()
        |> DuplicateTracker.record_message("sender", {:channel, "#test"}, "spam")
        |> DuplicateTracker.record_message("sender", {:channel, "#test"}, "other")
        |> DuplicateTracker.record_message("sender", {:channel, "#test"}, "spam")

      assert DuplicateTracker.duplicate_count(
               tracker,
               "sender",
               {:channel, "#test"},
               "spam",
               10
             ) == 2
    end

    test "returns 0 for unknown sender-target pair" do
      assert DuplicateTracker.duplicate_count(
               DuplicateTracker.new(),
               "unknown",
               {:channel, "#test"},
               "hello",
               10
             ) == 0
    end
  end

  describe "prune_expired/2" do
    test "removes entries older than window" do
      old_ts = System.monotonic_time(:millisecond) - 20_000

      tracker = %{
        DuplicateTracker.new()
        | entries: %{{"sender", {:channel, "#test"}} => [%{content: "old", timestamp: old_ts}]}
      }

      pruned = DuplicateTracker.prune_expired(tracker, 15)
      assert pruned.entries == %{}
    end

    test "keeps recent entries" do
      tracker =
        DuplicateTracker.new()
        |> DuplicateTracker.record_message("sender", {:channel, "#test"}, "recent")

      pruned = DuplicateTracker.prune_expired(tracker, 15)
      key = {"sender", {:channel, "#test"}}
      assert Map.has_key?(pruned.entries, key)
    end
  end
end
