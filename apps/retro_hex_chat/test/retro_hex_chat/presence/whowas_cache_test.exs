defmodule RetroHexChat.Presence.WhowasCacheTest do
  use ExUnit.Case, async: false

  @moduletag :unit

  alias RetroHexChat.Presence.WhowasCache

  setup do
    WhowasCache.clear()
    :ok
  end

  describe "record/3 and lookup/1" do
    test "records and retrieves a disconnected user" do
      WhowasCache.record("Alice", ["#elixir", "#lobby"])
      assert {:ok, entry} = WhowasCache.lookup("Alice")
      assert entry.nickname == "Alice"
      assert entry.channels == ["#elixir", "#lobby"]
      assert entry.quit_message == nil
    end

    test "records with quit message" do
      WhowasCache.record("Bob", ["#general"], "See you tomorrow!")
      assert {:ok, entry} = WhowasCache.lookup("Bob")
      assert entry.quit_message == "See you tomorrow!"
    end

    test "lookup is case-insensitive" do
      WhowasCache.record("Alice", ["#elixir"])
      assert {:ok, _} = WhowasCache.lookup("alice")
      assert {:ok, _} = WhowasCache.lookup("ALICE")
      assert {:ok, _} = WhowasCache.lookup("Alice")
    end

    test "returns error for non-existent entry" do
      assert {:error, :not_found} = WhowasCache.lookup("Nobody")
    end

    test "overwrites on re-disconnect" do
      WhowasCache.record("Alice", ["#old"])
      WhowasCache.record("Alice", ["#new"], "Bye!")
      assert {:ok, entry} = WhowasCache.lookup("Alice")
      assert entry.channels == ["#new"]
      assert entry.quit_message == "Bye!"
    end
  end

  describe "TTL expiry" do
    test "expired entries are not returned" do
      past = DateTime.add(DateTime.utc_now(), -3601, :second)

      entry = %{
        nickname: "Expired",
        channels: ["#test"],
        quit_message: nil,
        disconnected_at: past
      }

      :ets.insert(:whowas_cache, {"expired", entry})

      assert {:error, :not_found} = WhowasCache.lookup("Expired")
    end
  end

  describe "capacity eviction" do
    test "evicts oldest when exceeding max entries" do
      now = DateTime.utc_now()

      for i <- 1..1001 do
        entry = %{
          nickname: "User#{i}",
          channels: ["#test"],
          quit_message: nil,
          disconnected_at: DateTime.add(now, i, :second)
        }

        :ets.insert(:whowas_cache, {"user#{i}", entry})
      end

      # This triggers enforce_capacity
      WhowasCache.record("LastUser", ["#final"])

      assert WhowasCache.size() <= 1001
    end
  end

  describe "size/0" do
    test "returns 0 for empty cache" do
      assert WhowasCache.size() == 0
    end

    test "returns correct count" do
      WhowasCache.record("A", [])
      WhowasCache.record("B", [])
      assert WhowasCache.size() == 2
    end
  end

  describe "clear/0" do
    test "removes all entries" do
      WhowasCache.record("A", [])
      WhowasCache.record("B", [])
      WhowasCache.clear()
      assert WhowasCache.size() == 0
    end
  end
end
