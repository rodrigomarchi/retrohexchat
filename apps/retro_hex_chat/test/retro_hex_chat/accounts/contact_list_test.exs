defmodule RetroHexChat.Accounts.ContactListTest do
  use RetroHexChat.DataCase, async: true

  alias RetroHexChat.Accounts.Contact
  alias RetroHexChat.Accounts.ContactList

  # ---------------------------------------------------------------------------
  # Unit Tests — In-Memory CRUD
  # ---------------------------------------------------------------------------

  describe "new/0" do
    @tag :unit
    test "returns empty contact list" do
      list = ContactList.new()
      assert list.entries == []
    end
  end

  describe "add_entry/4" do
    @tag :unit
    test "adds an entry with a note" do
      list = ContactList.new()
      assert {:ok, updated} = ContactList.add_entry(list, "Owner", "Alice", "My friend")

      assert length(updated.entries) == 1
      entry = hd(updated.entries)
      assert entry.contact_nickname == "Alice"
      assert entry.note == "My friend"
      assert %DateTime{} = entry.first_contact_date
    end

    @tag :unit
    test "adds an entry with nil note" do
      list = ContactList.new()
      assert {:ok, updated} = ContactList.add_entry(list, "Owner", "Alice", nil)

      assert length(updated.entries) == 1
      entry = hd(updated.entries)
      assert entry.contact_nickname == "Alice"
      assert entry.note == nil
    end

    @tag :unit
    test "adds an entry with default nil note" do
      list = ContactList.new()
      assert {:ok, updated} = ContactList.add_entry(list, "Owner", "Alice")

      assert length(updated.entries) == 1
      assert hd(updated.entries).note == nil
    end

    @tag :unit
    test "returns error when adding self (exact case)" do
      list = ContactList.new()
      assert {:error, :self_add} = ContactList.add_entry(list, "Owner", "Owner", nil)
    end

    @tag :unit
    test "returns error when adding self (case-insensitive)" do
      list = ContactList.new()
      assert {:error, :self_add} = ContactList.add_entry(list, "Owner", "OWNER", nil)
    end

    @tag :unit
    test "returns error when adding self (mixed case)" do
      list = ContactList.new()
      assert {:error, :self_add} = ContactList.add_entry(list, "oWnEr", "OwNeR", nil)
    end

    @tag :unit
    test "returns error for duplicate entry (exact case)" do
      list = ContactList.new()
      {:ok, list} = ContactList.add_entry(list, "Owner", "Alice", nil)
      assert {:error, :duplicate} = ContactList.add_entry(list, "Owner", "Alice", nil)
    end

    @tag :unit
    test "returns error for duplicate entry (case-insensitive)" do
      list = ContactList.new()
      {:ok, list} = ContactList.add_entry(list, "Owner", "Alice", nil)
      assert {:error, :duplicate} = ContactList.add_entry(list, "Owner", "ALICE", nil)
    end

    @tag :unit
    test "returns error when list is full (100 entries)" do
      list = ContactList.new()

      list =
        Enum.reduce(1..100, list, fn i, acc ->
          {:ok, updated} = ContactList.add_entry(acc, "Owner", "User#{i}", nil)
          updated
        end)

      assert {:error, :list_full} = ContactList.add_entry(list, "Owner", "User101", nil)
    end

    @tag :unit
    test "allows adding up to 100 entries" do
      list = ContactList.new()

      list =
        Enum.reduce(1..100, list, fn i, acc ->
          {:ok, updated} = ContactList.add_entry(acc, "Owner", "User#{i}", nil)
          updated
        end)

      assert length(list.entries) == 100
    end

    @tag :unit
    test "returns error for empty nickname" do
      list = ContactList.new()
      assert {:error, :invalid_nickname} = ContactList.add_entry(list, "Owner", "", nil)
    end

    @tag :unit
    test "returns error for whitespace-only nickname" do
      list = ContactList.new()
      assert {:error, :invalid_nickname} = ContactList.add_entry(list, "Owner", "   ", nil)
    end

    @tag :unit
    test "returns error for nickname longer than 16 chars" do
      list = ContactList.new()
      long_nick = String.duplicate("a", 17)
      assert {:error, :invalid_nickname} = ContactList.add_entry(list, "Owner", long_nick, nil)
    end

    @tag :unit
    test "accepts nickname at exactly 16 chars" do
      list = ContactList.new()
      nick_16 = String.duplicate("a", 16)
      assert {:ok, _updated} = ContactList.add_entry(list, "Owner", nick_16, nil)
    end

    @tag :unit
    test "truncates note to 200 chars on add" do
      list = ContactList.new()
      long_note = String.duplicate("x", 250)
      assert {:ok, updated} = ContactList.add_entry(list, "Owner", "Alice", long_note)
      assert String.length(hd(updated.entries).note) == 200
    end
  end

  describe "remove_entry/2" do
    @tag :unit
    test "removes an existing entry" do
      list = ContactList.new()
      {:ok, list} = ContactList.add_entry(list, "Owner", "Alice", nil)
      {:ok, list} = ContactList.add_entry(list, "Owner", "Bob", nil)

      assert {:ok, updated} = ContactList.remove_entry(list, "Alice")
      assert length(updated.entries) == 1
      assert hd(updated.entries).contact_nickname == "Bob"
    end

    @tag :unit
    test "removes case-insensitively" do
      list = ContactList.new()
      {:ok, list} = ContactList.add_entry(list, "Owner", "Alice", nil)

      assert {:ok, updated} = ContactList.remove_entry(list, "ALICE")
      assert updated.entries == []
    end

    @tag :unit
    test "returns error for not found" do
      list = ContactList.new()
      assert {:error, :not_found} = ContactList.remove_entry(list, "Ghost")
    end

    @tag :unit
    test "returns error when nickname does not match any entry" do
      list = ContactList.new()
      {:ok, list} = ContactList.add_entry(list, "Owner", "Alice", nil)

      assert {:error, :not_found} = ContactList.remove_entry(list, "Bob")
    end
  end

  describe "update_note/3" do
    @tag :unit
    test "updates the note of an existing entry" do
      list = ContactList.new()
      {:ok, list} = ContactList.add_entry(list, "Owner", "Alice", "Old note")

      assert {:ok, updated} = ContactList.update_note(list, "Alice", "New note")
      assert hd(updated.entries).note == "New note"
    end

    @tag :unit
    test "matches case-insensitively" do
      list = ContactList.new()
      {:ok, list} = ContactList.add_entry(list, "Owner", "Alice", nil)

      assert {:ok, updated} = ContactList.update_note(list, "ALICE", "Updated")
      assert hd(updated.entries).note == "Updated"
    end

    @tag :unit
    test "truncates note to 200 characters" do
      list = ContactList.new()
      {:ok, list} = ContactList.add_entry(list, "Owner", "Alice", nil)
      long_note = String.duplicate("x", 250)

      assert {:ok, updated} = ContactList.update_note(list, "Alice", long_note)
      assert String.length(hd(updated.entries).note) == 200
    end

    @tag :unit
    test "allows note at exactly 200 characters" do
      list = ContactList.new()
      {:ok, list} = ContactList.add_entry(list, "Owner", "Alice", nil)
      note_200 = String.duplicate("a", 200)

      assert {:ok, updated} = ContactList.update_note(list, "Alice", note_200)
      assert hd(updated.entries).note == note_200
    end

    @tag :unit
    test "allows setting note to nil" do
      list = ContactList.new()
      {:ok, list} = ContactList.add_entry(list, "Owner", "Alice", "Some note")

      assert {:ok, updated} = ContactList.update_note(list, "Alice", nil)
      assert hd(updated.entries).note == nil
    end

    @tag :unit
    test "returns error for not found" do
      list = ContactList.new()
      assert {:error, :not_found} = ContactList.update_note(list, "Ghost", "note")
    end
  end

  describe "sorted_entries/1" do
    @tag :unit
    test "returns entries sorted alphabetically by contact_nickname (case-insensitive)" do
      list = ContactList.new()
      {:ok, list} = ContactList.add_entry(list, "Owner", "Charlie", nil)
      {:ok, list} = ContactList.add_entry(list, "Owner", "alice", nil)
      {:ok, list} = ContactList.add_entry(list, "Owner", "Bob", nil)

      sorted = ContactList.sorted_entries(list)
      nicks = Enum.map(sorted, & &1.contact_nickname)
      assert nicks == ["alice", "Bob", "Charlie"]
    end

    @tag :unit
    test "returns empty list for empty contact list" do
      list = ContactList.new()
      assert ContactList.sorted_entries(list) == []
    end
  end

  describe "count/1" do
    @tag :unit
    test "returns total number of entries" do
      list = ContactList.new()
      assert ContactList.count(list) == 0

      {:ok, list} = ContactList.add_entry(list, "Owner", "Alice", nil)
      assert ContactList.count(list) == 1

      {:ok, list} = ContactList.add_entry(list, "Owner", "Bob", nil)
      assert ContactList.count(list) == 2
    end
  end

  describe "full?/1" do
    @tag :unit
    test "returns false when under 100 entries" do
      list = ContactList.new()
      assert ContactList.full?(list) == false
    end

    @tag :unit
    test "returns false with some entries" do
      list = ContactList.new()
      {:ok, list} = ContactList.add_entry(list, "Owner", "Alice", nil)
      assert ContactList.full?(list) == false
    end

    @tag :unit
    test "returns true when at exactly 100 entries" do
      list = ContactList.new()

      list =
        Enum.reduce(1..100, list, fn i, acc ->
          {:ok, updated} = ContactList.add_entry(acc, "Owner", "User#{i}", nil)
          updated
        end)

      assert ContactList.full?(list) == true
    end
  end

  # ---------------------------------------------------------------------------
  # Integration Tests — Persistence
  # ---------------------------------------------------------------------------

  describe "save/2 and load/1" do
    @tag :integration
    setup do
      {:ok, _} =
        RetroHexChat.Repo.insert(%RetroHexChat.Services.RegisteredNick{
          nickname: "TestOwner",
          password_hash: Bcrypt.hash_pwd_salt("password123"),
          registered_at: DateTime.utc_now()
        })

      :ok
    end

    test "save persists entries for a registered user" do
      list = ContactList.new()
      {:ok, list} = ContactList.add_entry(list, "TestOwner", "Alice", "Best friend")
      {:ok, list} = ContactList.add_entry(list, "TestOwner", "Bob", nil)

      assert :ok = ContactList.save("TestOwner", list)
    end

    test "load restores all entries and notes" do
      list = ContactList.new()
      {:ok, list} = ContactList.add_entry(list, "TestOwner", "Alice", "Best friend")
      {:ok, list} = ContactList.add_entry(list, "TestOwner", "Bob", "Colleague")
      :ok = ContactList.save("TestOwner", list)

      assert {:ok, loaded} = ContactList.load("TestOwner")
      assert length(loaded.entries) == 2

      alice = Enum.find(loaded.entries, &(&1.contact_nickname == "Alice"))
      bob = Enum.find(loaded.entries, &(&1.contact_nickname == "Bob"))

      assert alice != nil
      assert alice.note == "Best friend"
      assert %DateTime{} = alice.first_contact_date
      assert bob != nil
      assert bob.note == "Colleague"
    end

    test "load returns error for unknown user" do
      assert {:error, :not_found} = ContactList.load("UnknownUser")
    end

    test "save overwrites previous entries" do
      list = ContactList.new()
      {:ok, list} = ContactList.add_entry(list, "TestOwner", "Alice", "First")
      :ok = ContactList.save("TestOwner", list)

      list2 = ContactList.new()
      {:ok, list2} = ContactList.add_entry(list2, "TestOwner", "Bob", "Second")
      :ok = ContactList.save("TestOwner", list2)

      {:ok, loaded} = ContactList.load("TestOwner")
      assert length(loaded.entries) == 1
      assert hd(loaded.entries).contact_nickname == "Bob"
    end
  end

  describe "save_entry/2" do
    @tag :integration
    setup do
      {:ok, _} =
        RetroHexChat.Repo.insert(%RetroHexChat.Services.RegisteredNick{
          nickname: "TestOwner",
          password_hash: Bcrypt.hash_pwd_salt("password123"),
          registered_at: DateTime.utc_now()
        })

      :ok
    end

    test "inserts a single entry" do
      list = ContactList.new()
      {:ok, list} = ContactList.add_entry(list, "TestOwner", "Alice", "First note")
      entry = hd(list.entries)

      assert :ok = ContactList.save_entry("TestOwner", entry)

      {:ok, loaded} = ContactList.load("TestOwner")
      assert length(loaded.entries) == 1
      assert hd(loaded.entries).contact_nickname == "Alice"
      assert hd(loaded.entries).note == "First note"
    end

    test "upserts overwrites existing entry" do
      list = ContactList.new()
      {:ok, list} = ContactList.add_entry(list, "TestOwner", "Alice", "First note")
      entry = hd(list.entries)
      :ok = ContactList.save_entry("TestOwner", entry)

      {:ok, list} = ContactList.update_note(list, "Alice", "Updated note")
      updated_entry = hd(list.entries)
      :ok = ContactList.save_entry("TestOwner", updated_entry)

      {:ok, loaded} = ContactList.load("TestOwner")
      assert length(loaded.entries) == 1
      assert hd(loaded.entries).note == "Updated note"
    end

    test "upserts case-insensitively" do
      list = ContactList.new()
      {:ok, list} = ContactList.add_entry(list, "TestOwner", "Alice", "First")
      :ok = ContactList.save_entry("TestOwner", hd(list.entries))

      # Create entry with different case
      upper_entry = Contact.new(contact_nickname: "ALICE", note: "Updated")
      :ok = ContactList.save_entry("TestOwner", upper_entry)

      {:ok, loaded} = ContactList.load("TestOwner")
      assert length(loaded.entries) == 1
      assert hd(loaded.entries).note == "Updated"
    end
  end

  describe "delete_entry/2" do
    @tag :integration
    setup do
      {:ok, _} =
        RetroHexChat.Repo.insert(%RetroHexChat.Services.RegisteredNick{
          nickname: "TestOwner",
          password_hash: Bcrypt.hash_pwd_salt("password123"),
          registered_at: DateTime.utc_now()
        })

      :ok
    end

    test "removes entry from the database" do
      list = ContactList.new()
      {:ok, list} = ContactList.add_entry(list, "TestOwner", "Alice", nil)
      {:ok, list} = ContactList.add_entry(list, "TestOwner", "Bob", nil)
      :ok = ContactList.save("TestOwner", list)

      assert :ok = ContactList.delete_entry("TestOwner", "Alice")

      {:ok, loaded} = ContactList.load("TestOwner")
      assert length(loaded.entries) == 1
      assert hd(loaded.entries).contact_nickname == "Bob"
    end

    test "returns ok even when entry does not exist" do
      assert :ok = ContactList.delete_entry("TestOwner", "Ghost")
    end

    test "deletes case-insensitively" do
      list = ContactList.new()
      {:ok, list} = ContactList.add_entry(list, "TestOwner", "Alice", nil)
      :ok = ContactList.save("TestOwner", list)

      assert :ok = ContactList.delete_entry("TestOwner", "ALICE")

      assert {:error, :not_found} = ContactList.load("TestOwner")
    end
  end
end
