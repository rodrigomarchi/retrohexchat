defmodule RetroHexChat.Chat.AutoJoinListTest do
  use RetroHexChat.DataCase, async: true

  alias RetroHexChat.Chat.AutoJoinList

  describe "new/0" do
    test "returns empty list" do
      list = AutoJoinList.new()
      assert list.entries == []
    end
  end

  describe "add_entry/3" do
    test "adds a channel" do
      list = AutoJoinList.new()
      assert {:ok, updated} = AutoJoinList.add_entry(list, "#elixir")
      assert AutoJoinList.count(updated) == 1
      [entry] = AutoJoinList.entries(updated)
      assert entry.channel_name == "#elixir"
      assert entry.channel_key == nil
      assert entry.position == 0
    end

    test "adds a channel with key" do
      list = AutoJoinList.new()
      assert {:ok, updated} = AutoJoinList.add_entry(list, "#secret", "mykey")
      [entry] = AutoJoinList.entries(updated)
      assert entry.channel_name == "#secret"
      assert entry.channel_key == "mykey"
    end

    test "appends channels in order" do
      list = AutoJoinList.new()
      {:ok, list} = AutoJoinList.add_entry(list, "#elixir")
      {:ok, list} = AutoJoinList.add_entry(list, "#phoenix")
      {:ok, list} = AutoJoinList.add_entry(list, "#nerves")

      entries = AutoJoinList.entries(list)
      assert length(entries) == 3
      assert Enum.at(entries, 0).channel_name == "#elixir"
      assert Enum.at(entries, 1).channel_name == "#phoenix"
      assert Enum.at(entries, 2).channel_name == "#nerves"
    end

    test "trims whitespace" do
      list = AutoJoinList.new()
      {:ok, updated} = AutoJoinList.add_entry(list, "  #elixir  ")
      [entry] = AutoJoinList.entries(updated)
      assert entry.channel_name == "#elixir"
    end

    test "treats empty key as nil" do
      list = AutoJoinList.new()
      {:ok, updated} = AutoJoinList.add_entry(list, "#elixir", "")
      [entry] = AutoJoinList.entries(updated)
      assert entry.channel_key == nil
    end

    test "treats whitespace-only key as nil" do
      list = AutoJoinList.new()
      {:ok, updated} = AutoJoinList.add_entry(list, "#elixir", "   ")
      [entry] = AutoJoinList.entries(updated)
      assert entry.channel_key == nil
    end

    test "rejects channel not starting with #" do
      list = AutoJoinList.new()
      assert {:error, :invalid_channel} = AutoJoinList.add_entry(list, "elixir")
    end

    test "rejects channel with spaces" do
      list = AutoJoinList.new()
      assert {:error, :invalid_channel} = AutoJoinList.add_entry(list, "#my channel")
    end

    test "rejects single # character" do
      list = AutoJoinList.new()
      assert {:error, :invalid_channel} = AutoJoinList.add_entry(list, "#")
    end

    test "rejects duplicate channels (case-insensitive)" do
      list = AutoJoinList.new()
      {:ok, list} = AutoJoinList.add_entry(list, "#Elixir")
      assert {:error, :duplicate} = AutoJoinList.add_entry(list, "#elixir")
      assert {:error, :duplicate} = AutoJoinList.add_entry(list, "#ELIXIR")
    end

    test "rejects when list is full (20 entries)" do
      list =
        Enum.reduce(0..19, AutoJoinList.new(), fn i, acc ->
          {:ok, updated} = AutoJoinList.add_entry(acc, "#ch#{i}")
          updated
        end)

      assert AutoJoinList.full?(list)
      assert {:error, :list_full} = AutoJoinList.add_entry(list, "#extra")
    end
  end

  describe "remove_entry/2" do
    test "removes entry by channel name" do
      list = AutoJoinList.new()
      {:ok, list} = AutoJoinList.add_entry(list, "#elixir")
      {:ok, list} = AutoJoinList.add_entry(list, "#phoenix")
      assert AutoJoinList.count(list) == 2

      {:ok, updated} = AutoJoinList.remove_entry(list, "#elixir")
      assert AutoJoinList.count(updated) == 1
      [entry] = AutoJoinList.entries(updated)
      assert entry.channel_name == "#phoenix"
      assert entry.position == 0
    end

    test "is case-insensitive" do
      list = AutoJoinList.new()
      {:ok, list} = AutoJoinList.add_entry(list, "#Elixir")
      {:ok, updated} = AutoJoinList.remove_entry(list, "#elixir")
      assert AutoJoinList.count(updated) == 0
    end

    test "returns error for non-existent channel" do
      list = AutoJoinList.new()
      assert {:error, :not_found} = AutoJoinList.remove_entry(list, "#missing")
    end

    test "reindexes after removal" do
      list = AutoJoinList.new()
      {:ok, list} = AutoJoinList.add_entry(list, "#ch1")
      {:ok, list} = AutoJoinList.add_entry(list, "#ch2")
      {:ok, list} = AutoJoinList.add_entry(list, "#ch3")

      {:ok, updated} = AutoJoinList.remove_entry(list, "#ch2")
      entries = AutoJoinList.entries(updated)
      assert Enum.at(entries, 0).position == 0
      assert Enum.at(entries, 1).position == 1
    end
  end

  describe "update_entry/3" do
    test "updates channel key" do
      list = AutoJoinList.new()
      {:ok, list} = AutoJoinList.add_entry(list, "#secret", "oldkey")
      {:ok, updated} = AutoJoinList.update_entry(list, "#secret", "newkey")
      [entry] = AutoJoinList.entries(updated)
      assert entry.channel_key == "newkey"
    end

    test "removes channel key by setting nil" do
      list = AutoJoinList.new()
      {:ok, list} = AutoJoinList.add_entry(list, "#secret", "mykey")
      {:ok, updated} = AutoJoinList.update_entry(list, "#secret", nil)
      [entry] = AutoJoinList.entries(updated)
      assert entry.channel_key == nil
    end

    test "is case-insensitive" do
      list = AutoJoinList.new()
      {:ok, list} = AutoJoinList.add_entry(list, "#Secret", "old")
      {:ok, updated} = AutoJoinList.update_entry(list, "#secret", "new")
      [entry] = AutoJoinList.entries(updated)
      assert entry.channel_key == "new"
    end

    test "returns error for non-existent channel" do
      list = AutoJoinList.new()
      assert {:error, :not_found} = AutoJoinList.update_entry(list, "#missing", "key")
    end
  end

  describe "clear/1" do
    test "removes all entries" do
      list = AutoJoinList.new()
      {:ok, list} = AutoJoinList.add_entry(list, "#ch1")
      {:ok, list} = AutoJoinList.add_entry(list, "#ch2")

      {:ok, cleared} = AutoJoinList.clear(list)
      assert AutoJoinList.count(cleared) == 0
      assert AutoJoinList.entries(cleared) == []
    end
  end

  describe "entries/1" do
    test "returns entries sorted by position" do
      list = AutoJoinList.new()
      {:ok, list} = AutoJoinList.add_entry(list, "#ch1")
      {:ok, list} = AutoJoinList.add_entry(list, "#ch2")

      entries = AutoJoinList.entries(list)
      assert Enum.at(entries, 0).position == 0
      assert Enum.at(entries, 1).position == 1
    end

    test "returns empty list for new list" do
      assert AutoJoinList.entries(AutoJoinList.new()) == []
    end
  end

  describe "count/1" do
    test "returns 0 for empty list" do
      assert AutoJoinList.count(AutoJoinList.new()) == 0
    end

    test "returns correct count" do
      list = AutoJoinList.new()
      {:ok, list} = AutoJoinList.add_entry(list, "#ch1")
      {:ok, list} = AutoJoinList.add_entry(list, "#ch2")
      assert AutoJoinList.count(list) == 2
    end
  end

  describe "full?/1" do
    test "returns false for empty list" do
      refute AutoJoinList.full?(AutoJoinList.new())
    end

    test "returns true at 20 entries" do
      list =
        Enum.reduce(0..19, AutoJoinList.new(), fn i, acc ->
          {:ok, updated} = AutoJoinList.add_entry(acc, "#ch#{i}")
          updated
        end)

      assert AutoJoinList.full?(list)
    end
  end

  describe "save/2 and load/1" do
    @tag :integration
    test "persists and loads autojoin list with entries" do
      owner = "AJUser#{System.unique_integer([:positive])}"
      register_nick(owner)

      list = AutoJoinList.new()
      {:ok, list} = AutoJoinList.add_entry(list, "#elixir")
      {:ok, list} = AutoJoinList.add_entry(list, "#phoenix")
      {:ok, list} = AutoJoinList.add_entry(list, "#secret", "mykey")

      assert :ok = AutoJoinList.save(owner, list)

      assert {:ok, loaded} = AutoJoinList.load(owner)
      entries = AutoJoinList.entries(loaded)
      assert length(entries) == 3
      assert Enum.at(entries, 0).channel_name == "#elixir"
      assert Enum.at(entries, 0).channel_key == nil
      assert Enum.at(entries, 1).channel_name == "#phoenix"
      assert Enum.at(entries, 2).channel_name == "#secret"
      assert Enum.at(entries, 2).channel_key == "mykey"
    end

    @tag :integration
    test "save replaces previous entries" do
      owner = "AJUser#{System.unique_integer([:positive])}"
      register_nick(owner)

      list1 = AutoJoinList.new()
      {:ok, list1} = AutoJoinList.add_entry(list1, "#old")
      assert :ok = AutoJoinList.save(owner, list1)

      list2 = AutoJoinList.new()
      {:ok, list2} = AutoJoinList.add_entry(list2, "#new")
      assert :ok = AutoJoinList.save(owner, list2)

      assert {:ok, loaded} = AutoJoinList.load(owner)
      entries = AutoJoinList.entries(loaded)
      assert length(entries) == 1
      assert Enum.at(entries, 0).channel_name == "#new"
    end

    @tag :integration
    test "load returns error for unknown user" do
      assert {:error, :not_found} = AutoJoinList.load("NonExistent")
    end

    @tag :integration
    test "preserves channel key as nil when not set" do
      owner = "AJUser#{System.unique_integer([:positive])}"
      register_nick(owner)

      list = AutoJoinList.new()
      {:ok, list} = AutoJoinList.add_entry(list, "#nokey")
      assert :ok = AutoJoinList.save(owner, list)

      assert {:ok, loaded} = AutoJoinList.load(owner)
      [entry] = AutoJoinList.entries(loaded)
      assert entry.channel_key == nil
    end
  end

  defp register_nick(nickname) do
    RetroHexChat.Repo.insert_all("registered_nicks", [
      %{
        nickname: nickname,
        password_hash: Bcrypt.hash_pwd_salt("password"),
        inserted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }
    ])
  end
end
