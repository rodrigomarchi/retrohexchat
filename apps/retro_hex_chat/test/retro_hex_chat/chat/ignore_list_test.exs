defmodule RetroHexChat.Chat.IgnoreListTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Chat.IgnoreList

  describe "new/0" do
    test "returns empty entries list" do
      list = IgnoreList.new()
      assert list.entries == []
    end
  end

  describe "add_entry/4" do
    test "adds a permanent ignore entry" do
      list = IgnoreList.new()
      assert {:ok, updated} = IgnoreList.add_entry(list, "SpamBot", :all, nil)
      assert length(updated.entries) == 1
      entry = hd(updated.entries)
      assert entry.nickname == "SpamBot"
      assert entry.ignore_type == :all
      assert entry.expires_at == nil
    end

    test "adds a timed ignore entry" do
      list = IgnoreList.new()
      expires = DateTime.add(DateTime.utc_now(), 300, :second)
      assert {:ok, updated} = IgnoreList.add_entry(list, "LoudUser", :all, expires)
      entry = hd(updated.entries)
      assert entry.expires_at == expires
    end

    test "upserts existing entry (case-insensitive)" do
      list = IgnoreList.new()
      {:ok, list} = IgnoreList.add_entry(list, "SpamBot", :all, nil)
      {:ok, updated} = IgnoreList.add_entry(list, "spambot", :pms, nil)

      assert length(updated.entries) == 1
      assert hd(updated.entries).ignore_type == :pms
    end

    test "upsert preserves original nickname casing from first add" do
      list = IgnoreList.new()
      {:ok, list} = IgnoreList.add_entry(list, "SpamBot", :all, nil)
      {:ok, updated} = IgnoreList.add_entry(list, "SPAMBOT", :pms, nil)

      # The map operation updates the existing entry's type, keeping original nickname
      assert hd(updated.entries).nickname == "SpamBot"
    end

    test "rejects invalid ignore type" do
      list = IgnoreList.new()
      assert {:error, :invalid_type} = IgnoreList.add_entry(list, "User", :invalid, nil)
    end

    test "rejects when list is full (100 entries)" do
      list =
        Enum.reduce(1..100, IgnoreList.new(), fn i, acc ->
          {:ok, updated} = IgnoreList.add_entry(acc, "User#{i}", :all, nil)
          updated
        end)

      assert {:error, :list_full} = IgnoreList.add_entry(list, "User101", :all, nil)
    end

    test "allows all five valid types" do
      list = IgnoreList.new()

      Enum.each([:all, :messages, :pms, :invites, :actions], fn type ->
        assert {:ok, _} = IgnoreList.add_entry(list, "User_#{type}", type, nil)
      end)
    end
  end

  describe "remove_entry/2" do
    test "removes an existing entry" do
      list = IgnoreList.new()
      {:ok, list} = IgnoreList.add_entry(list, "SpamBot", :all, nil)
      {:ok, list} = IgnoreList.add_entry(list, "Troll", :pms, nil)

      assert {:ok, updated} = IgnoreList.remove_entry(list, "SpamBot")
      assert length(updated.entries) == 1
      assert hd(updated.entries).nickname == "Troll"
    end

    test "removes case-insensitively" do
      list = IgnoreList.new()
      {:ok, list} = IgnoreList.add_entry(list, "SpamBot", :all, nil)
      assert {:ok, updated} = IgnoreList.remove_entry(list, "spambot")
      assert updated.entries == []
    end

    test "returns error for not found" do
      list = IgnoreList.new()
      assert {:error, :not_found} = IgnoreList.remove_entry(list, "Nobody")
    end
  end

  describe "ignored?/3" do
    test "returns true when :all type matches any message type" do
      list = IgnoreList.new()
      {:ok, list} = IgnoreList.add_entry(list, "SpamBot", :all, nil)

      assert IgnoreList.ignored?(list, "SpamBot", :message)
      assert IgnoreList.ignored?(list, "SpamBot", :pm)
      assert IgnoreList.ignored?(list, "SpamBot", :action)
      assert IgnoreList.ignored?(list, "SpamBot", :invite)
    end

    test "returns true only for matching message type" do
      list = IgnoreList.new()
      {:ok, list} = IgnoreList.add_entry(list, "SpamBot", :messages, nil)

      assert IgnoreList.ignored?(list, "SpamBot", :message)
      refute IgnoreList.ignored?(list, "SpamBot", :pm)
      refute IgnoreList.ignored?(list, "SpamBot", :action)
      refute IgnoreList.ignored?(list, "SpamBot", :invite)
    end

    test ":pms type matches only :pm" do
      list = IgnoreList.new()
      {:ok, list} = IgnoreList.add_entry(list, "SpamBot", :pms, nil)

      refute IgnoreList.ignored?(list, "SpamBot", :message)
      assert IgnoreList.ignored?(list, "SpamBot", :pm)
      refute IgnoreList.ignored?(list, "SpamBot", :action)
    end

    test ":actions type matches only :action" do
      list = IgnoreList.new()
      {:ok, list} = IgnoreList.add_entry(list, "SpamBot", :actions, nil)

      refute IgnoreList.ignored?(list, "SpamBot", :message)
      refute IgnoreList.ignored?(list, "SpamBot", :pm)
      assert IgnoreList.ignored?(list, "SpamBot", :action)
    end

    test ":invites type matches only :invite" do
      list = IgnoreList.new()
      {:ok, list} = IgnoreList.add_entry(list, "SpamBot", :invites, nil)

      refute IgnoreList.ignored?(list, "SpamBot", :message)
      assert IgnoreList.ignored?(list, "SpamBot", :invite)
    end

    test "matches case-insensitively" do
      list = IgnoreList.new()
      {:ok, list} = IgnoreList.add_entry(list, "SpamBot", :all, nil)

      assert IgnoreList.ignored?(list, "spambot", :message)
      assert IgnoreList.ignored?(list, "SPAMBOT", :pm)
    end

    test "returns false for non-ignored user" do
      list = IgnoreList.new()
      refute IgnoreList.ignored?(list, "FriendlyUser", :message)
    end

    test "returns false for expired entry" do
      list = IgnoreList.new()
      past = DateTime.add(DateTime.utc_now(), -60, :second)
      {:ok, list} = IgnoreList.add_entry(list, "SpamBot", :all, past)

      refute IgnoreList.ignored?(list, "SpamBot", :message)
    end
  end

  describe "get_entry/2" do
    test "returns entry when found" do
      list = IgnoreList.new()
      {:ok, list} = IgnoreList.add_entry(list, "SpamBot", :pms, nil)

      entry = IgnoreList.get_entry(list, "SpamBot")
      assert entry.nickname == "SpamBot"
      assert entry.ignore_type == :pms
    end

    test "matches case-insensitively" do
      list = IgnoreList.new()
      {:ok, list} = IgnoreList.add_entry(list, "SpamBot", :all, nil)

      assert IgnoreList.get_entry(list, "spambot") != nil
    end

    test "returns nil when not found" do
      list = IgnoreList.new()
      assert IgnoreList.get_entry(list, "Nobody") == nil
    end
  end

  describe "update_nickname/3" do
    test "updates nickname when found" do
      list = IgnoreList.new()
      {:ok, list} = IgnoreList.add_entry(list, "OldNick", :all, nil)

      updated = IgnoreList.update_nickname(list, "OldNick", "NewNick")
      assert hd(updated.entries).nickname == "NewNick"
      assert hd(updated.entries).ignore_type == :all
    end

    test "matches case-insensitively" do
      list = IgnoreList.new()
      {:ok, list} = IgnoreList.add_entry(list, "OldNick", :all, nil)

      updated = IgnoreList.update_nickname(list, "OLDNICK", "NewNick")
      assert hd(updated.entries).nickname == "NewNick"
    end

    test "returns unchanged list when not found" do
      list = IgnoreList.new()
      {:ok, list} = IgnoreList.add_entry(list, "Alice", :all, nil)

      updated = IgnoreList.update_nickname(list, "Nobody", "NewNick")
      assert updated == list
    end
  end

  describe "sorted_entries/1" do
    test "returns entries sorted alphabetically by nickname" do
      list = IgnoreList.new()
      {:ok, list} = IgnoreList.add_entry(list, "Charlie", :all, nil)
      {:ok, list} = IgnoreList.add_entry(list, "Alice", :pms, nil)
      {:ok, list} = IgnoreList.add_entry(list, "Bob", :messages, nil)

      nicks = list |> IgnoreList.sorted_entries() |> Enum.map(& &1.nickname)
      assert nicks == ["Alice", "Bob", "Charlie"]
    end

    test "sorts case-insensitively" do
      list = IgnoreList.new()
      {:ok, list} = IgnoreList.add_entry(list, "charlie", :all, nil)
      {:ok, list} = IgnoreList.add_entry(list, "Alice", :all, nil)
      {:ok, list} = IgnoreList.add_entry(list, "BOB", :all, nil)

      nicks = list |> IgnoreList.sorted_entries() |> Enum.map(& &1.nickname)
      assert nicks == ["Alice", "BOB", "charlie"]
    end

    test "returns empty list for empty ignore list" do
      list = IgnoreList.new()
      assert IgnoreList.sorted_entries(list) == []
    end
  end

  describe "count/1" do
    test "returns total number of entries" do
      list = IgnoreList.new()
      assert IgnoreList.count(list) == 0

      {:ok, list} = IgnoreList.add_entry(list, "Alice", :all, nil)
      assert IgnoreList.count(list) == 1

      {:ok, list} = IgnoreList.add_entry(list, "Bob", :pms, nil)
      assert IgnoreList.count(list) == 2
    end
  end

  describe "full?/1" do
    test "returns false when under limit" do
      list = IgnoreList.new()
      refute IgnoreList.full?(list)
    end

    test "returns true at exactly 100 entries" do
      list =
        Enum.reduce(1..100, IgnoreList.new(), fn i, acc ->
          {:ok, updated} = IgnoreList.add_entry(acc, "User#{i}", :all, nil)
          updated
        end)

      assert IgnoreList.full?(list)
    end
  end

  describe "remove_expired/1" do
    test "removes expired entries and returns their nicknames" do
      list = IgnoreList.new()
      past = DateTime.add(DateTime.utc_now(), -60, :second)
      future = DateTime.add(DateTime.utc_now(), 3600, :second)

      {:ok, list} = IgnoreList.add_entry(list, "Expired1", :all, past)
      {:ok, list} = IgnoreList.add_entry(list, "Active", :all, future)
      {:ok, list} = IgnoreList.add_entry(list, "Permanent", :pms, nil)

      {updated, expired_nicks} = IgnoreList.remove_expired(list)

      assert length(updated.entries) == 2
      assert "Expired1" in expired_nicks
      nicks = Enum.map(updated.entries, & &1.nickname)
      assert "Active" in nicks
      assert "Permanent" in nicks
    end

    test "returns empty list when no entries expired" do
      list = IgnoreList.new()
      {:ok, list} = IgnoreList.add_entry(list, "Active", :all, nil)

      {updated, expired_nicks} = IgnoreList.remove_expired(list)
      assert updated == list
      assert expired_nicks == []
    end

    test "handles empty list" do
      list = IgnoreList.new()
      {updated, expired_nicks} = IgnoreList.remove_expired(list)
      assert updated == list
      assert expired_nicks == []
    end
  end
end
