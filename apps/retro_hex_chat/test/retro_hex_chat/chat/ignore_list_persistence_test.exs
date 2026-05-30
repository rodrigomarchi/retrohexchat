defmodule RetroHexChat.Chat.IgnoreListPersistenceTest do
  use RetroHexChat.DataCase, async: true

  @moduletag :integration

  alias RetroHexChat.Chat.IgnoreList
  alias RetroHexChat.Repo

  @owner "PersistUser"

  setup do
    # Ensure registered nick exists for FK
    Repo.insert_all("registered_nicks", [
      %{
        nickname: @owner,
        password_hash: Bcrypt.hash_pwd_salt("password"),
        inserted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }
    ])

    :ok
  end

  describe "save/2" do
    test "saves ignore list entries to database" do
      list = IgnoreList.new()
      {:ok, list} = IgnoreList.add_entry(list, "SpamBot", :all, nil)
      {:ok, list} = IgnoreList.add_entry(list, "Troll", :pms, nil)

      assert :ok = IgnoreList.save(@owner, list)
    end

    test "replaces all entries on save (delete-then-reinsert)" do
      list = IgnoreList.new()
      {:ok, list} = IgnoreList.add_entry(list, "SpamBot", :all, nil)
      assert :ok = IgnoreList.save(@owner, list)

      # Save again with different entries
      list2 = IgnoreList.new()
      {:ok, list2} = IgnoreList.add_entry(list2, "NewTroll", :messages, nil)
      assert :ok = IgnoreList.save(@owner, list2)

      # Load should only have NewTroll
      {:ok, loaded} = IgnoreList.load(@owner)
      assert IgnoreList.count(loaded) == 1
      assert IgnoreList.get_entry(loaded, "NewTroll") != nil
      assert IgnoreList.get_entry(loaded, "SpamBot") == nil
    end

    test "saves empty list (clears all entries)" do
      list = IgnoreList.new()
      {:ok, list} = IgnoreList.add_entry(list, "SpamBot", :all, nil)
      assert :ok = IgnoreList.save(@owner, list)

      # Save empty list
      assert :ok = IgnoreList.save(@owner, IgnoreList.new())

      assert {:error, :not_found} = IgnoreList.load(@owner)
    end

    test "saves timed entries with expires_at" do
      list = IgnoreList.new()
      expires = DateTime.add(DateTime.utc_now(), 300, :second)
      {:ok, list} = IgnoreList.add_entry(list, "TempIgnore", :all, expires)

      assert :ok = IgnoreList.save(@owner, list)

      {:ok, loaded} = IgnoreList.load(@owner)
      entry = IgnoreList.get_entry(loaded, "TempIgnore")
      assert entry != nil
      assert entry.expires_at != nil
    end
  end

  describe "load/1" do
    test "returns {:error, :not_found} when no entries exist" do
      assert {:error, :not_found} = IgnoreList.load(@owner)
    end

    test "loads saved entries with correct types" do
      list = IgnoreList.new()
      {:ok, list} = IgnoreList.add_entry(list, "SpamBot", :all, nil)
      {:ok, list} = IgnoreList.add_entry(list, "Troll", :pms, nil)
      {:ok, list} = IgnoreList.add_entry(list, "Annoying", :actions, nil)
      {:ok, list} = IgnoreList.add_entry(list, "InfoBot", :notices, nil)
      :ok = IgnoreList.save(@owner, list)

      {:ok, loaded} = IgnoreList.load(@owner)
      assert IgnoreList.count(loaded) == 4

      spam_entry = IgnoreList.get_entry(loaded, "SpamBot")
      assert spam_entry.ignore_type == :all

      troll_entry = IgnoreList.get_entry(loaded, "Troll")
      assert troll_entry.ignore_type == :pms

      annoying_entry = IgnoreList.get_entry(loaded, "Annoying")
      assert annoying_entry.ignore_type == :actions

      info_entry = IgnoreList.get_entry(loaded, "InfoBot")
      assert info_entry.ignore_type == :notices
    end

    test "filters out expired entries on load" do
      list = IgnoreList.new()
      # Already expired
      past = DateTime.add(DateTime.utc_now(), -60, :second)
      {:ok, list} = IgnoreList.add_entry(list, "Expired", :all, past)
      # Still valid
      future = DateTime.add(DateTime.utc_now(), 300, :second)
      {:ok, list} = IgnoreList.add_entry(list, "Active", :all, future)
      # Permanent
      {:ok, list} = IgnoreList.add_entry(list, "Permanent", :all, nil)
      :ok = IgnoreList.save(@owner, list)

      {:ok, loaded} = IgnoreList.load(@owner)
      assert IgnoreList.count(loaded) == 2
      assert IgnoreList.get_entry(loaded, "Expired") == nil
      assert IgnoreList.get_entry(loaded, "Active") != nil
      assert IgnoreList.get_entry(loaded, "Permanent") != nil
    end

    test "returns {:error, :not_found} when only expired entries exist" do
      list = IgnoreList.new()
      past = DateTime.add(DateTime.utc_now(), -60, :second)
      {:ok, list} = IgnoreList.add_entry(list, "Expired", :all, past)
      :ok = IgnoreList.save(@owner, list)

      assert {:error, :not_found} = IgnoreList.load(@owner)
    end
  end
end
