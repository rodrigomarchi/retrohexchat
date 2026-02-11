defmodule RetroHexChat.Accounts.NickColorsTest do
  use RetroHexChat.DataCase, async: true

  alias RetroHexChat.Accounts.{NickColor, NickColors}

  # ---------------------------------------------------------------------------
  # Unit Tests
  # ---------------------------------------------------------------------------

  describe "new/0" do
    @tag :unit
    test "returns empty nick colors map" do
      nc = NickColors.new()
      assert nc.entries == []
    end
  end

  describe "add_entry/3" do
    @tag :unit
    test "adds an entry successfully" do
      nc = NickColors.new()
      assert {:ok, updated} = NickColors.add_entry(nc, "Alice", 4)

      assert length(updated.entries) == 1
      entry = hd(updated.entries)
      assert entry.target_nickname == "Alice"
      assert entry.color_index == 4
    end

    @tag :unit
    test "returns error for duplicate entry (exact case)" do
      nc = NickColors.new()
      {:ok, nc} = NickColors.add_entry(nc, "Alice", 4)
      assert {:error, :duplicate} = NickColors.add_entry(nc, "Alice", 7)
    end

    @tag :unit
    test "returns error for duplicate entry (case-insensitive)" do
      nc = NickColors.new()
      {:ok, nc} = NickColors.add_entry(nc, "Alice", 4)
      assert {:error, :duplicate} = NickColors.add_entry(nc, "ALICE", 7)
    end

    @tag :unit
    test "returns error when list is full (50 entries)" do
      nc = NickColors.new()

      nc =
        Enum.reduce(1..50, nc, fn i, acc ->
          {:ok, updated} = NickColors.add_entry(acc, "User#{i}", rem(i, 16))
          updated
        end)

      assert {:error, :list_full} = NickColors.add_entry(nc, "User51", 0)
    end

    @tag :unit
    test "returns error for empty nickname" do
      nc = NickColors.new()
      assert {:error, :invalid_nickname} = NickColors.add_entry(nc, "", 4)
    end

    @tag :unit
    test "returns error for nickname longer than 16 chars" do
      nc = NickColors.new()
      long_nick = String.duplicate("a", 17)
      assert {:error, :invalid_nickname} = NickColors.add_entry(nc, long_nick, 4)
    end

    @tag :unit
    test "returns error for negative color index" do
      nc = NickColors.new()
      assert {:error, :invalid_color} = NickColors.add_entry(nc, "Alice", -1)
    end

    @tag :unit
    test "returns error for color index >= 16" do
      nc = NickColors.new()
      assert {:error, :invalid_color} = NickColors.add_entry(nc, "Alice", 16)
    end
  end

  describe "remove_entry/2" do
    @tag :unit
    test "removes an existing entry" do
      nc = NickColors.new()
      {:ok, nc} = NickColors.add_entry(nc, "Alice", 4)
      {:ok, nc} = NickColors.add_entry(nc, "Bob", 7)

      assert {:ok, updated} = NickColors.remove_entry(nc, "Alice")
      assert length(updated.entries) == 1
      assert hd(updated.entries).target_nickname == "Bob"
    end

    @tag :unit
    test "removes case-insensitively" do
      nc = NickColors.new()
      {:ok, nc} = NickColors.add_entry(nc, "Alice", 4)

      assert {:ok, updated} = NickColors.remove_entry(nc, "ALICE")
      assert updated.entries == []
    end

    @tag :unit
    test "returns error for not found" do
      nc = NickColors.new()
      assert {:error, :not_found} = NickColors.remove_entry(nc, "Ghost")
    end
  end

  describe "update_color/3" do
    @tag :unit
    test "updates color of an existing entry" do
      nc = NickColors.new()
      {:ok, nc} = NickColors.add_entry(nc, "Alice", 4)

      assert {:ok, updated} = NickColors.update_color(nc, "Alice", 12)
      assert hd(updated.entries).color_index == 12
    end

    @tag :unit
    test "matches case-insensitively" do
      nc = NickColors.new()
      {:ok, nc} = NickColors.add_entry(nc, "Alice", 4)

      assert {:ok, updated} = NickColors.update_color(nc, "ALICE", 9)
      assert hd(updated.entries).color_index == 9
    end

    @tag :unit
    test "returns error for not found" do
      nc = NickColors.new()
      assert {:error, :not_found} = NickColors.update_color(nc, "Ghost", 5)
    end

    @tag :unit
    test "returns error for invalid color" do
      nc = NickColors.new()
      {:ok, nc} = NickColors.add_entry(nc, "Alice", 4)
      assert {:error, :invalid_color} = NickColors.update_color(nc, "Alice", 16)
    end
  end

  describe "add_or_update/3" do
    @tag :unit
    test "adds new entry when not present" do
      nc = NickColors.new()
      assert {:ok, updated} = NickColors.add_or_update(nc, "Alice", 4)
      assert length(updated.entries) == 1
      assert hd(updated.entries).color_index == 4
    end

    @tag :unit
    test "updates existing entry color" do
      nc = NickColors.new()
      {:ok, nc} = NickColors.add_entry(nc, "Alice", 4)

      assert {:ok, updated} = NickColors.add_or_update(nc, "Alice", 12)
      assert length(updated.entries) == 1
      assert hd(updated.entries).color_index == 12
    end
  end

  describe "color_for/2" do
    @tag :unit
    test "returns hex string for existing override" do
      nc = NickColors.new()
      {:ok, nc} = NickColors.add_entry(nc, "Alice", 4)

      assert NickColors.color_for(nc, "Alice") == "#ff0000"
    end

    @tag :unit
    test "returns nil when no override exists" do
      nc = NickColors.new()
      assert NickColors.color_for(nc, "Alice") == nil
    end

    @tag :unit
    test "matches case-insensitively" do
      nc = NickColors.new()
      {:ok, nc} = NickColors.add_entry(nc, "Alice", 11)

      assert NickColors.color_for(nc, "ALICE") == "#00ffff"
    end
  end

  describe "sorted_entries/1" do
    @tag :unit
    test "returns entries sorted alphabetically by target_nickname (case-insensitive)" do
      nc = NickColors.new()
      {:ok, nc} = NickColors.add_entry(nc, "Charlie", 3)
      {:ok, nc} = NickColors.add_entry(nc, "alice", 4)
      {:ok, nc} = NickColors.add_entry(nc, "Bob", 7)

      sorted = NickColors.sorted_entries(nc)
      assert Enum.map(sorted, & &1.target_nickname) == ["alice", "Bob", "Charlie"]
    end

    @tag :unit
    test "returns empty list for empty nick colors" do
      nc = NickColors.new()
      assert NickColors.sorted_entries(nc) == []
    end
  end

  describe "count/1" do
    @tag :unit
    test "returns total number of entries" do
      nc = NickColors.new()
      assert NickColors.count(nc) == 0

      {:ok, nc} = NickColors.add_entry(nc, "Alice", 4)
      assert NickColors.count(nc) == 1

      {:ok, nc} = NickColors.add_entry(nc, "Bob", 7)
      assert NickColors.count(nc) == 2
    end
  end

  describe "full?/1" do
    @tag :unit
    test "returns false when under 50 entries" do
      nc = NickColors.new()
      assert NickColors.full?(nc) == false
    end

    @tag :unit
    test "returns true when at exactly 50 entries" do
      nc = NickColors.new()

      nc =
        Enum.reduce(1..50, nc, fn i, acc ->
          {:ok, updated} = NickColors.add_entry(acc, "User#{i}", rem(i, 16))
          updated
        end)

      assert NickColors.full?(nc) == true
    end
  end

  describe "hex_for_index/1" do
    @tag :unit
    test "returns hex string for valid indices" do
      assert NickColors.hex_for_index(0) == "#ffffff"
      assert NickColors.hex_for_index(4) == "#ff0000"
      assert NickColors.hex_for_index(15) == "#d2d2d2"
    end

    @tag :unit
    test "returns nil for invalid index" do
      assert NickColors.hex_for_index(16) == nil
      assert NickColors.hex_for_index(-1) == nil
    end
  end

  # ---------------------------------------------------------------------------
  # Integration Tests (Persistence)
  # ---------------------------------------------------------------------------

  describe "save/2 and load/1" do
    setup do
      {:ok, _} =
        RetroHexChat.Repo.insert(%RetroHexChat.Services.RegisteredNick{
          nickname: "TestOwner",
          password_hash: Bcrypt.hash_pwd_salt("password123"),
          registered_at: DateTime.utc_now()
        })

      :ok
    end

    @tag :integration
    test "save and load round-trip" do
      nc = NickColors.new()
      {:ok, nc} = NickColors.add_entry(nc, "Alice", 4)
      {:ok, nc} = NickColors.add_entry(nc, "Bob", 12)

      assert :ok = NickColors.save("TestOwner", nc)

      assert {:ok, loaded} = NickColors.load("TestOwner")
      assert length(loaded.entries) == 2

      alice = Enum.find(loaded.entries, &(&1.target_nickname == "Alice"))
      bob = Enum.find(loaded.entries, &(&1.target_nickname == "Bob"))

      assert alice != nil
      assert alice.color_index == 4
      assert bob != nil
      assert bob.color_index == 12
    end

    @tag :integration
    test "load returns error for unknown user" do
      assert {:error, :not_found} = NickColors.load("UnknownUser")
    end

    @tag :integration
    test "save_entry upsert inserts new and updates existing" do
      entry = NickColor.new(target_nickname: "Alice", color_index: 4)
      assert :ok = NickColors.save_entry("TestOwner", entry)

      {:ok, loaded} = NickColors.load("TestOwner")
      assert length(loaded.entries) == 1
      assert hd(loaded.entries).color_index == 4

      # Update the same entry
      updated_entry = NickColor.new(target_nickname: "Alice", color_index: 9)
      assert :ok = NickColors.save_entry("TestOwner", updated_entry)

      {:ok, loaded} = NickColors.load("TestOwner")
      assert length(loaded.entries) == 1
      assert hd(loaded.entries).color_index == 9
    end

    @tag :integration
    test "delete_entry removes entry from database" do
      nc = NickColors.new()
      {:ok, nc} = NickColors.add_entry(nc, "Alice", 4)
      {:ok, nc} = NickColors.add_entry(nc, "Bob", 7)
      :ok = NickColors.save("TestOwner", nc)

      assert :ok = NickColors.delete_entry("TestOwner", "Alice")

      {:ok, loaded} = NickColors.load("TestOwner")
      assert length(loaded.entries) == 1
      assert hd(loaded.entries).target_nickname == "Bob"
    end

    @tag :integration
    test "delete_entry returns ok even when entry does not exist" do
      assert :ok = NickColors.delete_entry("TestOwner", "Ghost")
    end

    @tag :integration
    test "case-insensitive persistence" do
      entry = NickColor.new(target_nickname: "Alice", color_index: 4)
      :ok = NickColors.save_entry("TestOwner", entry)

      # Save with different case should upsert
      updated = NickColor.new(target_nickname: "ALICE", color_index: 11)
      :ok = NickColors.save_entry("TestOwner", updated)

      {:ok, loaded} = NickColors.load("TestOwner")
      assert length(loaded.entries) == 1
      assert hd(loaded.entries).color_index == 11
    end

    @tag :integration
    test "color_index preserved correctly through save/load" do
      nc = NickColors.new()
      {:ok, nc} = NickColors.add_entry(nc, "Red", 4)
      {:ok, nc} = NickColors.add_entry(nc, "Green", 3)
      {:ok, nc} = NickColors.add_entry(nc, "Blue", 2)
      :ok = NickColors.save("TestOwner", nc)

      {:ok, loaded} = NickColors.load("TestOwner")

      red = Enum.find(loaded.entries, &(&1.target_nickname == "Red"))
      green = Enum.find(loaded.entries, &(&1.target_nickname == "Green"))
      blue = Enum.find(loaded.entries, &(&1.target_nickname == "Blue"))

      assert red.color_index == 4
      assert green.color_index == 3
      assert blue.color_index == 2
    end
  end
end
