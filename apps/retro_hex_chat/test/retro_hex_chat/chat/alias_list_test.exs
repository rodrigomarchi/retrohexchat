defmodule RetroHexChat.Chat.AliasListTest do
  use RetroHexChat.DataCase, async: true

  alias RetroHexChat.Chat.AliasList

  # ── Unit Tests ──────────────────────────────────────────

  describe "new/0" do
    @tag :unit
    test "returns empty list" do
      list = AliasList.new()
      assert list.entries == []
    end
  end

  describe "add_entry/3" do
    @tag :unit
    test "adds an alias" do
      list = AliasList.new()
      assert {:ok, updated} = AliasList.add_entry(list, "hi", "/me says hello!")
      entries = AliasList.entries(updated)
      assert length(entries) == 1
      assert hd(entries).name == "hi"
      assert hd(entries).expansion == "/me says hello!"
      assert hd(entries).position == 0
    end

    @tag :unit
    test "appends aliases in order" do
      list = AliasList.new()
      {:ok, list} = AliasList.add_entry(list, "hi", "/me says hello!")
      {:ok, list} = AliasList.add_entry(list, "bye", "/me waves goodbye")
      entries = AliasList.entries(list)
      assert length(entries) == 2
      assert Enum.at(entries, 0).name == "hi"
      assert Enum.at(entries, 1).name == "bye"
    end

    @tag :unit
    test "rejects duplicate name (case-insensitive)" do
      list = AliasList.new()
      {:ok, list} = AliasList.add_entry(list, "hi", "/me says hello!")
      assert {:error, :duplicate_name} = AliasList.add_entry(list, "HI", "/me says hi!")
    end

    @tag :unit
    test "rejects invalid name with spaces" do
      list = AliasList.new()
      assert {:error, :invalid_name} = AliasList.add_entry(list, "my alias", "/me test")
    end

    @tag :unit
    test "rejects empty name" do
      list = AliasList.new()
      assert {:error, :invalid_name} = AliasList.add_entry(list, "", "/me test")
    end

    @tag :unit
    test "rejects name with special characters" do
      list = AliasList.new()
      assert {:error, :invalid_name} = AliasList.add_entry(list, "hi!", "/me test")
    end

    @tag :unit
    test "accepts name with alphanumeric, underscore, dash" do
      list = AliasList.new()
      assert {:ok, _} = AliasList.add_entry(list, "my-alias_1", "/me test")
    end

    @tag :unit
    test "rejects expansion too long" do
      list = AliasList.new()
      long_expansion = "/" <> String.duplicate("a", 500)
      assert {:error, :expansion_too_long} = AliasList.add_entry(list, "hi", long_expansion)
    end

    @tag :unit
    test "accepts expansion at exactly 500 characters" do
      list = AliasList.new()
      expansion = "/" <> String.duplicate("a", 499)
      assert {:ok, _} = AliasList.add_entry(list, "hi", expansion)
    end

    @tag :unit
    test "rejects expansion with command chaining" do
      list = AliasList.new()
      assert {:error, :command_chaining} = AliasList.add_entry(list, "hi", "/me hi | /quit")
    end

    @tag :unit
    test "rejects when list is full (50 entries)" do
      list =
        Enum.reduce(0..49, AliasList.new(), fn i, acc ->
          {:ok, updated} = AliasList.add_entry(acc, "alias#{i}", "/me test")
          updated
        end)

      assert {:error, :list_full} = AliasList.add_entry(list, "extra", "/me test")
    end
  end

  describe "remove_entry/2" do
    @tag :unit
    test "removes alias by name" do
      list = AliasList.new()
      {:ok, list} = AliasList.add_entry(list, "hi", "/me hello")
      {:ok, list} = AliasList.add_entry(list, "bye", "/me goodbye")

      {:ok, updated} = AliasList.remove_entry(list, "hi")
      entries = AliasList.entries(updated)
      assert length(entries) == 1
      assert hd(entries).name == "bye"
    end

    @tag :unit
    test "removes case-insensitively" do
      list = AliasList.new()
      {:ok, list} = AliasList.add_entry(list, "hi", "/me hello")

      {:ok, updated} = AliasList.remove_entry(list, "HI")
      assert AliasList.entries(updated) == []
    end

    @tag :unit
    test "returns error for non-existent name" do
      list = AliasList.new()
      assert {:error, :not_found} = AliasList.remove_entry(list, "nonexistent")
    end

    @tag :unit
    test "reindexes after removal" do
      list = AliasList.new()
      {:ok, list} = AliasList.add_entry(list, "a", "/me a")
      {:ok, list} = AliasList.add_entry(list, "b", "/me b")
      {:ok, list} = AliasList.add_entry(list, "c", "/me c")

      {:ok, updated} = AliasList.remove_entry(list, "b")
      entries = AliasList.entries(updated)
      assert length(entries) == 2
      assert Enum.at(entries, 0).position == 0
      assert Enum.at(entries, 1).position == 1
    end
  end

  describe "update_entry/3" do
    @tag :unit
    test "updates expansion of existing alias" do
      list = AliasList.new()
      {:ok, list} = AliasList.add_entry(list, "hi", "/me hello")

      {:ok, updated} = AliasList.update_entry(list, "hi", "/me waves hello!")
      entry = AliasList.find_entry(updated, "hi")
      assert entry.expansion == "/me waves hello!"
    end

    @tag :unit
    test "returns error for non-existent name" do
      list = AliasList.new()
      assert {:error, :not_found} = AliasList.update_entry(list, "nope", "/me test")
    end

    @tag :unit
    test "rejects expansion too long" do
      list = AliasList.new()
      {:ok, list} = AliasList.add_entry(list, "hi", "/me hello")
      long = "/" <> String.duplicate("a", 500)
      assert {:error, :expansion_too_long} = AliasList.update_entry(list, "hi", long)
    end

    @tag :unit
    test "rejects expansion with command chaining" do
      list = AliasList.new()
      {:ok, list} = AliasList.add_entry(list, "hi", "/me hello")
      assert {:error, :command_chaining} = AliasList.update_entry(list, "hi", "/me hi; /quit")
    end
  end

  describe "find_entry/2" do
    @tag :unit
    test "finds alias by name (case-insensitive)" do
      list = AliasList.new()
      {:ok, list} = AliasList.add_entry(list, "hi", "/me hello")

      entry = AliasList.find_entry(list, "HI")
      assert entry.name == "hi"
      assert entry.expansion == "/me hello"
    end

    @tag :unit
    test "returns nil for non-existent name" do
      list = AliasList.new()
      assert nil == AliasList.find_entry(list, "nonexistent")
    end
  end

  describe "entries/1" do
    @tag :unit
    test "returns entries sorted by position" do
      list = AliasList.new()
      {:ok, list} = AliasList.add_entry(list, "a", "/me a")
      {:ok, list} = AliasList.add_entry(list, "b", "/me b")

      entries = AliasList.entries(list)
      assert Enum.at(entries, 0).position == 0
      assert Enum.at(entries, 1).position == 1
    end

    @tag :unit
    test "returns empty list for new list" do
      assert AliasList.entries(AliasList.new()) == []
    end
  end

  describe "shadows_builtin?/1" do
    @tag :unit
    test "returns true for built-in commands" do
      assert AliasList.shadows_builtin?("join")
      assert AliasList.shadows_builtin?("nick")
      assert AliasList.shadows_builtin?("quit")
    end

    @tag :unit
    test "returns false for non-builtin names" do
      refute AliasList.shadows_builtin?("hi")
      refute AliasList.shadows_builtin?("greet")
    end
  end

  # ── Integration Tests (Persistence) ─────────────────────

  describe "save/2 and load/1" do
    @tag :integration
    test "persists and loads alias list" do
      owner = "AliasUser#{System.unique_integer([:positive])}"
      register_nick(owner)

      list = AliasList.new()
      {:ok, list} = AliasList.add_entry(list, "hi", "/me says hello!")
      {:ok, list} = AliasList.add_entry(list, "bye", "/me waves goodbye")

      assert :ok = AliasList.save(owner, list)

      assert {:ok, loaded} = AliasList.load(owner)
      entries = AliasList.entries(loaded)
      assert length(entries) == 2
      assert Enum.at(entries, 0).name == "hi"
      assert Enum.at(entries, 1).name == "bye"
    end

    @tag :integration
    test "save replaces previous entries" do
      owner = "AliasUser#{System.unique_integer([:positive])}"
      register_nick(owner)

      list1 = AliasList.new()
      {:ok, list1} = AliasList.add_entry(list1, "old", "/me old")
      assert :ok = AliasList.save(owner, list1)

      list2 = AliasList.new()
      {:ok, list2} = AliasList.add_entry(list2, "new", "/me new")
      assert :ok = AliasList.save(owner, list2)

      assert {:ok, loaded} = AliasList.load(owner)
      entries = AliasList.entries(loaded)
      assert length(entries) == 1
      assert hd(entries).name == "new"
    end

    @tag :integration
    test "load returns error for unknown user" do
      assert {:error, :not_found} = AliasList.load("NonExistentUser")
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
