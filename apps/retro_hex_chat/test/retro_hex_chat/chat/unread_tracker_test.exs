defmodule RetroHexChat.Chat.UnreadTrackerTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.Chat.UnreadTracker

  describe "increment/2" do
    @tag :unit
    test "increments count for a new channel" do
      counts = UnreadTracker.increment(%{}, "#general")
      assert UnreadTracker.get_count(counts, "#general") == 1
    end

    @tag :unit
    test "increments count for an existing channel" do
      counts =
        %{}
        |> UnreadTracker.increment("#general")
        |> UnreadTracker.increment("#general")
        |> UnreadTracker.increment("#general")

      assert UnreadTracker.get_count(counts, "#general") == 3
    end

    @tag :unit
    test "increments independently per channel" do
      counts =
        %{}
        |> UnreadTracker.increment("#general")
        |> UnreadTracker.increment("#random")
        |> UnreadTracker.increment("#general")

      assert UnreadTracker.get_count(counts, "#general") == 2
      assert UnreadTracker.get_count(counts, "#random") == 1
    end

    @tag :unit
    test "works with PM keys" do
      counts = UnreadTracker.increment(%{}, "pm:bob")
      assert UnreadTracker.get_count(counts, "pm:bob") == 1
    end
  end

  describe "reset/2" do
    @tag :unit
    test "resets count to zero (removes key)" do
      counts =
        %{}
        |> UnreadTracker.increment("#general")
        |> UnreadTracker.increment("#general")
        |> UnreadTracker.reset("#general")

      assert UnreadTracker.get_count(counts, "#general") == 0
    end

    @tag :unit
    test "is a no-op for non-existent key" do
      counts = UnreadTracker.reset(%{}, "#general")
      assert counts == %{}
    end
  end

  describe "get_count/2" do
    @tag :unit
    test "returns 0 for non-existent key" do
      assert UnreadTracker.get_count(%{}, "#general") == 0
    end

    @tag :unit
    test "returns the current count" do
      counts =
        %{}
        |> UnreadTracker.increment("#general")
        |> UnreadTracker.increment("#general")

      assert UnreadTracker.get_count(counts, "#general") == 2
    end
  end

  describe "display_count/1" do
    @tag :unit
    test "returns empty string for 0" do
      assert UnreadTracker.display_count(0) == ""
    end

    @tag :unit
    test "returns number as string for 1..99" do
      assert UnreadTracker.display_count(1) == "1"
      assert UnreadTracker.display_count(42) == "42"
      assert UnreadTracker.display_count(99) == "99"
    end

    @tag :unit
    test "returns 99+ for counts above 99" do
      assert UnreadTracker.display_count(100) == "99+"
      assert UnreadTracker.display_count(999) == "99+"
    end
  end

  describe "unread?/2" do
    @tag :unit
    test "returns false for non-existent key" do
      refute UnreadTracker.unread?(%{}, "#general")
    end

    @tag :unit
    test "returns true when count > 0" do
      counts = UnreadTracker.increment(%{}, "#general")
      assert UnreadTracker.unread?(counts, "#general")
    end

    @tag :unit
    test "returns false after reset" do
      counts =
        %{}
        |> UnreadTracker.increment("#general")
        |> UnreadTracker.reset("#general")

      refute UnreadTracker.unread?(counts, "#general")
    end
  end

  describe "unread_keys/1" do
    @tag :unit
    test "returns empty list for empty counts" do
      assert UnreadTracker.unread_keys(%{}) == []
    end

    @tag :unit
    test "returns keys with non-zero counts" do
      counts =
        %{}
        |> UnreadTracker.increment("#general")
        |> UnreadTracker.increment("#random")

      keys = UnreadTracker.unread_keys(counts)
      assert Enum.sort(keys) == ["#general", "#random"]
    end
  end
end
