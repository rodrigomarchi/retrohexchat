defmodule RetroHexChat.Presence.NotifyListTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Presence.NotifyList

  describe "new/0" do
    test "returns empty list with default settings" do
      list = NotifyList.new()
      assert list.entries == []
      assert list.settings == %{auto_whois: false}
    end
  end

  describe "add_entry/4" do
    test "adds an entry with a note" do
      list = NotifyList.new()
      assert {:ok, updated} = NotifyList.add_entry(list, "Owner", "Alice", "My friend")

      assert length(updated.entries) == 1
      entry = hd(updated.entries)
      assert entry.tracked_nickname == "Alice"
      assert entry.note == "My friend"
      assert entry.online == false
    end

    test "adds an entry with nil note" do
      list = NotifyList.new()
      assert {:ok, updated} = NotifyList.add_entry(list, "Owner", "Alice", nil)

      assert length(updated.entries) == 1
      entry = hd(updated.entries)
      assert entry.tracked_nickname == "Alice"
      assert entry.note == nil
    end

    test "returns error when adding self (exact case)" do
      list = NotifyList.new()
      assert {:error, :self_add} = NotifyList.add_entry(list, "Owner", "Owner", nil)
    end

    test "returns error when adding self (case-insensitive)" do
      list = NotifyList.new()
      assert {:error, :self_add} = NotifyList.add_entry(list, "Owner", "OWNER", nil)
    end

    test "returns error when adding self (mixed case)" do
      list = NotifyList.new()
      assert {:error, :self_add} = NotifyList.add_entry(list, "oWnEr", "OwNeR", nil)
    end

    test "returns error for duplicate entry (exact case)" do
      list = NotifyList.new()
      {:ok, list} = NotifyList.add_entry(list, "Owner", "Alice", nil)
      assert {:error, :duplicate} = NotifyList.add_entry(list, "Owner", "Alice", nil)
    end

    test "returns error for duplicate entry (case-insensitive)" do
      list = NotifyList.new()
      {:ok, list} = NotifyList.add_entry(list, "Owner", "Alice", nil)
      assert {:error, :duplicate} = NotifyList.add_entry(list, "Owner", "ALICE", nil)
    end

    test "returns error when list is full (50 entries)" do
      list = NotifyList.new()

      list =
        Enum.reduce(1..50, list, fn i, acc ->
          {:ok, updated} = NotifyList.add_entry(acc, "Owner", "User#{i}", nil)
          updated
        end)

      assert {:error, :list_full} = NotifyList.add_entry(list, "Owner", "User51", nil)
    end

    test "allows adding up to 50 entries" do
      list = NotifyList.new()

      list =
        Enum.reduce(1..50, list, fn i, acc ->
          {:ok, updated} = NotifyList.add_entry(acc, "Owner", "User#{i}", nil)
          updated
        end)

      assert length(list.entries) == 50
    end
  end

  describe "remove_entry/2" do
    test "removes an existing entry" do
      list = NotifyList.new()
      {:ok, list} = NotifyList.add_entry(list, "Owner", "Alice", nil)
      {:ok, list} = NotifyList.add_entry(list, "Owner", "Bob", nil)

      assert {:ok, updated} = NotifyList.remove_entry(list, "Alice")
      assert length(updated.entries) == 1
      assert hd(updated.entries).tracked_nickname == "Bob"
    end

    test "removes case-insensitively" do
      list = NotifyList.new()
      {:ok, list} = NotifyList.add_entry(list, "Owner", "Alice", nil)

      assert {:ok, updated} = NotifyList.remove_entry(list, "ALICE")
      assert updated.entries == []
    end

    test "returns error for not found" do
      list = NotifyList.new()
      assert {:error, :not_found} = NotifyList.remove_entry(list, "Ghost")
    end

    test "returns error when nickname does not match any entry" do
      list = NotifyList.new()
      {:ok, list} = NotifyList.add_entry(list, "Owner", "Alice", nil)

      assert {:error, :not_found} = NotifyList.remove_entry(list, "Bob")
    end
  end

  describe "update_note/3" do
    test "updates the note of an existing entry" do
      list = NotifyList.new()
      {:ok, list} = NotifyList.add_entry(list, "Owner", "Alice", "Old note")

      assert {:ok, updated} = NotifyList.update_note(list, "Alice", "New note")
      assert hd(updated.entries).note == "New note"
    end

    test "matches case-insensitively" do
      list = NotifyList.new()
      {:ok, list} = NotifyList.add_entry(list, "Owner", "Alice", nil)

      assert {:ok, updated} = NotifyList.update_note(list, "ALICE", "Updated")
      assert hd(updated.entries).note == "Updated"
    end

    test "truncates note to 200 characters" do
      list = NotifyList.new()
      {:ok, list} = NotifyList.add_entry(list, "Owner", "Alice", nil)
      long_note = String.duplicate("x", 250)

      assert {:ok, updated} = NotifyList.update_note(list, "Alice", long_note)
      assert String.length(hd(updated.entries).note) == 200
    end

    test "allows note at exactly 200 characters" do
      list = NotifyList.new()
      {:ok, list} = NotifyList.add_entry(list, "Owner", "Alice", nil)
      note_200 = String.duplicate("a", 200)

      assert {:ok, updated} = NotifyList.update_note(list, "Alice", note_200)
      assert hd(updated.entries).note == note_200
    end

    test "allows setting note to nil" do
      list = NotifyList.new()
      {:ok, list} = NotifyList.add_entry(list, "Owner", "Alice", "Some note")

      assert {:ok, updated} = NotifyList.update_note(list, "Alice", nil)
      assert hd(updated.entries).note == nil
    end

    test "returns error for not found" do
      list = NotifyList.new()
      assert {:error, :not_found} = NotifyList.update_note(list, "Ghost", "note")
    end
  end

  describe "update_nickname/3" do
    test "updates tracked nickname when found" do
      list = NotifyList.new()
      {:ok, list} = NotifyList.add_entry(list, "Owner", "OldNick", "A buddy")

      updated = NotifyList.update_nickname(list, "OldNick", "NewNick")
      assert hd(updated.entries).tracked_nickname == "NewNick"
      assert hd(updated.entries).note == "A buddy"
    end

    test "returns unchanged list when old nickname not found" do
      list = NotifyList.new()
      {:ok, list} = NotifyList.add_entry(list, "Owner", "Alice", nil)

      updated = NotifyList.update_nickname(list, "Nobody", "NewNick")
      assert updated == list
    end

    test "matches case-insensitively" do
      list = NotifyList.new()
      {:ok, list} = NotifyList.add_entry(list, "Owner", "Alice", nil)

      updated = NotifyList.update_nickname(list, "ALICE", "AliceNew")
      assert hd(updated.entries).tracked_nickname == "AliceNew"
    end
  end

  describe "set_online/3" do
    test "sets entry online to true" do
      list = NotifyList.new()
      {:ok, list} = NotifyList.add_entry(list, "Owner", "Alice", nil)

      updated = NotifyList.set_online(list, "Alice", true)
      assert hd(updated.entries).online == true
    end

    test "sets entry online to false and updates last_seen_at" do
      list = NotifyList.new()
      {:ok, list} = NotifyList.add_entry(list, "Owner", "Alice", nil)
      list = NotifyList.set_online(list, "Alice", true)

      updated = NotifyList.set_online(list, "Alice", false)
      entry = hd(updated.entries)
      assert entry.online == false
      assert %DateTime{} = entry.last_seen_at
    end

    test "matches case-insensitively" do
      list = NotifyList.new()
      {:ok, list} = NotifyList.add_entry(list, "Owner", "Alice", nil)

      updated = NotifyList.set_online(list, "ALICE", true)
      assert hd(updated.entries).online == true
    end

    test "returns unchanged list when nickname not found" do
      list = NotifyList.new()
      {:ok, list} = NotifyList.add_entry(list, "Owner", "Alice", nil)

      updated = NotifyList.set_online(list, "Ghost", true)
      assert updated == list
    end

    test "does not update last_seen_at when going online" do
      list = NotifyList.new()
      {:ok, list} = NotifyList.add_entry(list, "Owner", "Alice", nil)

      updated = NotifyList.set_online(list, "Alice", true)
      assert hd(updated.entries).last_seen_at == nil
    end
  end

  describe "set_auto_whois/2" do
    test "sets auto_whois to true" do
      list = NotifyList.new()
      updated = NotifyList.set_auto_whois(list, true)
      assert updated.settings.auto_whois == true
    end

    test "sets auto_whois to false" do
      list = NotifyList.new() |> NotifyList.set_auto_whois(true)
      updated = NotifyList.set_auto_whois(list, false)
      assert updated.settings.auto_whois == false
    end
  end

  describe "tracking?/2" do
    test "returns true when tracking a nickname" do
      list = NotifyList.new()
      {:ok, list} = NotifyList.add_entry(list, "Owner", "Alice", nil)

      assert NotifyList.tracking?(list, "Alice") == true
    end

    test "returns false when not tracking" do
      list = NotifyList.new()
      assert NotifyList.tracking?(list, "Alice") == false
    end

    test "matches case-insensitively" do
      list = NotifyList.new()
      {:ok, list} = NotifyList.add_entry(list, "Owner", "Alice", nil)

      assert NotifyList.tracking?(list, "ALICE") == true
      assert NotifyList.tracking?(list, "alice") == true
    end
  end

  describe "online_buddies/1" do
    test "returns only online entries sorted alphabetically" do
      list = NotifyList.new()
      {:ok, list} = NotifyList.add_entry(list, "Owner", "Charlie", nil)
      {:ok, list} = NotifyList.add_entry(list, "Owner", "Alice", nil)
      {:ok, list} = NotifyList.add_entry(list, "Owner", "Bob", nil)
      list = NotifyList.set_online(list, "Charlie", true)
      list = NotifyList.set_online(list, "Alice", true)

      online = NotifyList.online_buddies(list)
      assert length(online) == 2
      assert Enum.map(online, & &1.tracked_nickname) == ["Alice", "Charlie"]
    end

    test "returns empty list when no one is online" do
      list = NotifyList.new()
      {:ok, list} = NotifyList.add_entry(list, "Owner", "Alice", nil)

      assert NotifyList.online_buddies(list) == []
    end
  end

  describe "offline_buddies/1" do
    test "returns only offline entries sorted alphabetically" do
      list = NotifyList.new()
      {:ok, list} = NotifyList.add_entry(list, "Owner", "Charlie", nil)
      {:ok, list} = NotifyList.add_entry(list, "Owner", "Alice", nil)
      {:ok, list} = NotifyList.add_entry(list, "Owner", "Bob", nil)
      list = NotifyList.set_online(list, "Bob", true)

      offline = NotifyList.offline_buddies(list)
      assert length(offline) == 2
      assert Enum.map(offline, & &1.tracked_nickname) == ["Alice", "Charlie"]
    end

    test "returns all entries when no one is online" do
      list = NotifyList.new()
      {:ok, list} = NotifyList.add_entry(list, "Owner", "Bob", nil)
      {:ok, list} = NotifyList.add_entry(list, "Owner", "Alice", nil)

      offline = NotifyList.offline_buddies(list)
      assert length(offline) == 2
      assert Enum.map(offline, & &1.tracked_nickname) == ["Alice", "Bob"]
    end
  end

  describe "sorted_entries/1" do
    test "returns online first (alphabetical), then offline (alphabetical)" do
      list = NotifyList.new()
      {:ok, list} = NotifyList.add_entry(list, "Owner", "Dave", nil)
      {:ok, list} = NotifyList.add_entry(list, "Owner", "Alice", nil)
      {:ok, list} = NotifyList.add_entry(list, "Owner", "Charlie", nil)
      {:ok, list} = NotifyList.add_entry(list, "Owner", "Bob", nil)
      list = NotifyList.set_online(list, "Charlie", true)
      list = NotifyList.set_online(list, "Alice", true)

      sorted = NotifyList.sorted_entries(list)
      nicks = Enum.map(sorted, & &1.tracked_nickname)
      assert nicks == ["Alice", "Charlie", "Bob", "Dave"]
    end

    test "returns empty list for empty notify list" do
      list = NotifyList.new()
      assert NotifyList.sorted_entries(list) == []
    end
  end

  describe "count/1" do
    test "returns total number of entries" do
      list = NotifyList.new()
      assert NotifyList.count(list) == 0

      {:ok, list} = NotifyList.add_entry(list, "Owner", "Alice", nil)
      assert NotifyList.count(list) == 1

      {:ok, list} = NotifyList.add_entry(list, "Owner", "Bob", nil)
      assert NotifyList.count(list) == 2
    end
  end

  describe "full?/1" do
    test "returns false when under 50 entries" do
      list = NotifyList.new()
      assert NotifyList.full?(list) == false
    end

    test "returns false with some entries" do
      list = NotifyList.new()
      {:ok, list} = NotifyList.add_entry(list, "Owner", "Alice", nil)
      assert NotifyList.full?(list) == false
    end

    test "returns true when at exactly 50 entries" do
      list = NotifyList.new()

      list =
        Enum.reduce(1..50, list, fn i, acc ->
          {:ok, updated} = NotifyList.add_entry(acc, "Owner", "User#{i}", nil)
          updated
        end)

      assert NotifyList.full?(list) == true
    end
  end
end
