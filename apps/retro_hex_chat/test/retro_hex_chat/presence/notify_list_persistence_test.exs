defmodule RetroHexChat.Presence.NotifyListPersistenceTest do
  use RetroHexChat.DataCase, async: true

  @moduletag :integration

  alias Ecto.Adapters.SQL.Sandbox
  alias RetroHexChat.Presence.NotifyList
  alias RetroHexChat.Services.Queries

  setup do
    {:ok, _nick} = Queries.insert_registered_nick("TestOwner", "password123")

    # Allow NickServ GenServer to access sandbox connection (for whois_info/1 tests)
    if pid = GenServer.whereis(RetroHexChat.Services.NickServ) do
      Sandbox.allow(RetroHexChat.Repo, self(), pid)
    end

    :ok
  end

  describe "save/2 and load/1" do
    test "save persists entries for a registered user" do
      list = NotifyList.new()
      {:ok, list} = NotifyList.add_entry(list, "TestOwner", "Alice", "Best friend")
      {:ok, list} = NotifyList.add_entry(list, "TestOwner", "Bob", nil)

      assert :ok = NotifyList.save("TestOwner", list)
    end

    test "load restores all entries and notes" do
      list = NotifyList.new()
      {:ok, list} = NotifyList.add_entry(list, "TestOwner", "Alice", "Best friend")
      {:ok, list} = NotifyList.add_entry(list, "TestOwner", "Bob", "Colleague")
      :ok = NotifyList.save("TestOwner", list)

      assert {:ok, loaded} = NotifyList.load("TestOwner")
      assert length(loaded.entries) == 2

      alice = Enum.find(loaded.entries, &(&1.tracked_nickname == "Alice"))
      bob = Enum.find(loaded.entries, &(&1.tracked_nickname == "Bob"))

      assert alice != nil
      assert alice.note == "Best friend"
      assert bob != nil
      assert bob.note == "Colleague"
    end

    test "load sets all entries as offline" do
      list = NotifyList.new()
      {:ok, list} = NotifyList.add_entry(list, "TestOwner", "Alice", nil)
      list = NotifyList.set_online(list, "Alice", true)
      :ok = NotifyList.save("TestOwner", list)

      assert {:ok, loaded} = NotifyList.load("TestOwner")
      entry = hd(loaded.entries)
      assert entry.online == false
    end

    test "load returns error for unknown user" do
      assert {:error, :not_found} = NotifyList.load("UnknownUser")
    end
  end

  describe "save_entry/2" do
    test "upserts a single entry" do
      list = NotifyList.new()
      {:ok, list} = NotifyList.add_entry(list, "TestOwner", "Alice", "First note")
      entry = hd(list.entries)

      assert :ok = NotifyList.save_entry("TestOwner", entry)

      {:ok, loaded} = NotifyList.load("TestOwner")
      assert length(loaded.entries) == 1
      assert hd(loaded.entries).tracked_nickname == "Alice"
      assert hd(loaded.entries).note == "First note"
    end

    test "upserts overwrites existing entry" do
      list = NotifyList.new()
      {:ok, list} = NotifyList.add_entry(list, "TestOwner", "Alice", "First note")
      entry = hd(list.entries)
      :ok = NotifyList.save_entry("TestOwner", entry)

      {:ok, list} = NotifyList.update_note(list, "Alice", "Updated note")
      updated_entry = hd(list.entries)
      :ok = NotifyList.save_entry("TestOwner", updated_entry)

      {:ok, loaded} = NotifyList.load("TestOwner")
      assert length(loaded.entries) == 1
      assert hd(loaded.entries).note == "Updated note"
    end
  end

  describe "delete_entry/2" do
    test "removes entry from the database" do
      list = NotifyList.new()
      {:ok, list} = NotifyList.add_entry(list, "TestOwner", "Alice", nil)
      {:ok, list} = NotifyList.add_entry(list, "TestOwner", "Bob", nil)
      :ok = NotifyList.save("TestOwner", list)

      assert :ok = NotifyList.delete_entry("TestOwner", "Alice")

      {:ok, loaded} = NotifyList.load("TestOwner")
      assert length(loaded.entries) == 1
      assert hd(loaded.entries).tracked_nickname == "Bob"
    end

    test "returns ok even when entry does not exist" do
      assert :ok = NotifyList.delete_entry("TestOwner", "Ghost")
    end
  end

  describe "save_settings/2" do
    test "persists auto_whois setting" do
      list = NotifyList.new() |> NotifyList.set_auto_whois(true)

      assert :ok = NotifyList.save_settings("TestOwner", list.settings)

      # Save an entry so load returns something
      {:ok, list_with_entry} = NotifyList.add_entry(list, "TestOwner", "Alice", nil)
      :ok = NotifyList.save("TestOwner", list_with_entry)

      {:ok, loaded} = NotifyList.load("TestOwner")
      assert loaded.settings.auto_whois == true
    end

    test "persists auto_whois as false" do
      # First set to true
      list = NotifyList.new() |> NotifyList.set_auto_whois(true)
      :ok = NotifyList.save_settings("TestOwner", list.settings)

      # Then set to false
      list = NotifyList.set_auto_whois(list, false)
      :ok = NotifyList.save_settings("TestOwner", list.settings)

      {:ok, list_with_entry} = NotifyList.add_entry(list, "TestOwner", "Alice", nil)
      :ok = NotifyList.save("TestOwner", list_with_entry)

      {:ok, loaded} = NotifyList.load("TestOwner")
      assert loaded.settings.auto_whois == false
    end
  end

  describe "whois_info/1" do
    test "returns info for a registered user" do
      {:ok, info} = NotifyList.whois_info("TestOwner")
      assert info.nickname == "TestOwner"
      assert info.registered == true
      assert info.identified == false
      assert info.registered_at != nil
    end

    test "returns info for an unregistered user" do
      {:ok, info} = NotifyList.whois_info("RandomGuest")
      assert info.nickname == "RandomGuest"
      assert info.registered == false
      assert info.identified == false
      assert info.registered_at == nil
    end
  end

  describe "CASCADE on registered nick deletion" do
    test "deleting a registered nick removes all notify list entries" do
      list = NotifyList.new()
      {:ok, list} = NotifyList.add_entry(list, "TestOwner", "Alice", "Friend")
      {:ok, list} = NotifyList.add_entry(list, "TestOwner", "Bob", nil)
      list = NotifyList.set_auto_whois(list, true)
      :ok = NotifyList.save("TestOwner", list)
      :ok = NotifyList.save_settings("TestOwner", list.settings)

      # Delete the registered nick — should cascade
      nick = Queries.find_by_nickname("TestOwner")
      {:ok, _} = Queries.delete_registered_nick(nick)

      # Entries and settings should be gone
      assert {:error, :not_found} = NotifyList.load("TestOwner")
    end
  end
end
