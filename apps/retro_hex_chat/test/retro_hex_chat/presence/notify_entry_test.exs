defmodule RetroHexChat.Presence.NotifyEntryTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Presence.NotifyEntry

  describe "new/1" do
    test "creates entry with keyword list" do
      entry = NotifyEntry.new(tracked_nickname: "Alice")
      assert entry.tracked_nickname == "Alice"
    end

    test "creates entry with map" do
      entry = NotifyEntry.new(%{tracked_nickname: "Alice"})
      assert entry.tracked_nickname == "Alice"
    end

    test "defaults online to false" do
      entry = NotifyEntry.new(tracked_nickname: "Alice")
      assert entry.online == false
    end

    test "defaults note to nil" do
      entry = NotifyEntry.new(tracked_nickname: "Alice")
      assert entry.note == nil
    end

    test "defaults last_seen_at to nil" do
      entry = NotifyEntry.new(tracked_nickname: "Alice")
      assert entry.last_seen_at == nil
    end

    test "accepts all fields" do
      now = DateTime.utc_now()

      entry =
        NotifyEntry.new(
          tracked_nickname: "Alice",
          note: "A friend",
          last_seen_at: now,
          online: true
        )

      assert entry.tracked_nickname == "Alice"
      assert entry.note == "A friend"
      assert entry.last_seen_at == now
      assert entry.online == true
    end

    test "raises on missing tracked_nickname" do
      assert_raise ArgumentError, fn ->
        NotifyEntry.new(note: "oops")
      end
    end
  end
end
