defmodule RetroHexChat.Services.QueriesChannelTest do
  use RetroHexChat.DataCase, async: true

  @moduletag :integration

  alias RetroHexChat.Services.Queries

  describe "insert_registered_channel/2" do
    test "creates a registered channel" do
      assert {:ok, channel} = Queries.insert_registered_channel("#test", "founder1")
      assert channel.name == "#test"
      assert channel.founder_nickname == "founder1"
      assert channel.registered_at != nil
    end

    test "returns error for duplicate channel name" do
      {:ok, _} = Queries.insert_registered_channel("#dupe", "founder1")
      assert {:error, changeset} = Queries.insert_registered_channel("#dupe", "founder2")
      assert errors_on(changeset)[:name] != nil
    end
  end

  describe "find_registered_channel/1" do
    test "finds an existing channel" do
      {:ok, _} = Queries.insert_registered_channel("#findme", "founder1")
      assert %{name: "#findme"} = Queries.find_registered_channel("#findme")
    end

    test "returns nil for non-existent channel" do
      assert nil == Queries.find_registered_channel("#nosuch")
    end
  end

  describe "delete_registered_channel/1" do
    test "deletes a registered channel" do
      {:ok, channel} = Queries.insert_registered_channel("#delme", "founder1")
      assert {:ok, _} = Queries.delete_registered_channel(channel)
      assert nil == Queries.find_registered_channel("#delme")
    end
  end

  describe "add_access/4" do
    test "creates an access list entry" do
      assert {:ok, entry} = Queries.add_access("#chan", "nick1", "sop", "founder1")
      assert entry.channel_name == "#chan"
      assert entry.nickname == "nick1"
      assert entry.level == "sop"
      assert entry.added_by == "founder1"
    end

    test "returns error for duplicate channel+nickname" do
      {:ok, _} = Queries.add_access("#chan2", "nick1", "sop", "founder1")
      assert {:error, changeset} = Queries.add_access("#chan2", "nick1", "aop", "founder1")
      assert errors_on(changeset) != %{}
    end
  end

  describe "remove_access/2" do
    test "removes an access list entry" do
      {:ok, _} = Queries.add_access("#rmchan", "nick1", "sop", "founder1")
      assert :ok = Queries.remove_access("#rmchan", "nick1")
    end

    test "returns error when entry not found" do
      assert {:error, :not_found} = Queries.remove_access("#nosuch", "nobody")
    end
  end

  describe "list_access/1" do
    test "returns all entries for a channel" do
      {:ok, _} = Queries.add_access("#listchan", "nick1", "sop", "founder1")
      {:ok, _} = Queries.add_access("#listchan", "nick2", "aop", "founder1")

      entries = Queries.list_access("#listchan")
      assert length(entries) == 2
    end

    test "returns empty list when no entries" do
      assert [] == Queries.list_access("#emptychan")
    end
  end

  describe "find_access/2" do
    test "finds an access entry" do
      {:ok, _} = Queries.add_access("#findaccess", "nick1", "sop", "founder1")
      entry = Queries.find_access("#findaccess", "nick1")
      assert entry.nickname == "nick1"
      assert entry.level == "sop"
    end

    test "returns nil when not found" do
      assert nil == Queries.find_access("#nosuch", "nobody")
    end
  end

  describe "add_ban/3" do
    test "creates a ban entry" do
      assert {:ok, ban} = Queries.add_ban("#banchan", "badnick", "op1")
      assert ban.channel_name == "#banchan"
      assert ban.banned_nickname == "badnick"
      assert ban.banned_by == "op1"
    end
  end

  describe "remove_ban/2" do
    test "removes a ban entry" do
      {:ok, _} = Queries.add_ban("#rmbanchan", "badnick", "op1")
      assert :ok = Queries.remove_ban("#rmbanchan", "badnick")
    end

    test "returns error when ban not found" do
      assert {:error, :not_found} = Queries.remove_ban("#nosuch", "nobody")
    end
  end

  describe "list_bans/1" do
    test "returns all bans for a channel" do
      {:ok, _} = Queries.add_ban("#listbans", "bad1", "op1")
      {:ok, _} = Queries.add_ban("#listbans", "bad2", "op1")

      bans = Queries.list_bans("#listbans")
      assert length(bans) == 2
    end

    test "returns empty list when no bans" do
      assert [] == Queries.list_bans("#nobans")
    end
  end

  # ── Ban exceptions ────────────────────────────────────────

  describe "add_ban_exception/3" do
    test "creates a ban exception entry" do
      assert {:ok, entry} = Queries.add_ban_exception("#bexchan", "nick1", "op1")
      assert entry.channel_name == "#bexchan"
      assert entry.nickname == "nick1"
      assert entry.added_by == "op1"
    end

    test "returns error for duplicate channel+nickname" do
      {:ok, _} = Queries.add_ban_exception("#bexdup", "nick1", "op1")
      assert {:error, changeset} = Queries.add_ban_exception("#bexdup", "nick1", "op2")
      assert errors_on(changeset) != %{}
    end
  end

  describe "remove_ban_exception/2" do
    test "removes a ban exception entry" do
      {:ok, _} = Queries.add_ban_exception("#rmbex", "nick1", "op1")
      assert :ok = Queries.remove_ban_exception("#rmbex", "nick1")
    end

    test "returns error when entry not found" do
      assert {:error, :not_found} = Queries.remove_ban_exception("#nosuch", "nobody")
    end
  end

  describe "list_ban_exceptions/1" do
    test "returns all ban exceptions for a channel" do
      {:ok, _} = Queries.add_ban_exception("#listbex", "nick1", "op1")
      {:ok, _} = Queries.add_ban_exception("#listbex", "nick2", "op1")

      entries = Queries.list_ban_exceptions("#listbex")
      assert length(entries) == 2
    end

    test "returns empty list when no ban exceptions" do
      assert [] == Queries.list_ban_exceptions("#nobex")
    end
  end

  # ── Invite exceptions ─────────────────────────────────────

  describe "add_invite_exception/3" do
    test "creates an invite exception entry" do
      assert {:ok, entry} = Queries.add_invite_exception("#iexchan", "nick1", "op1")
      assert entry.channel_name == "#iexchan"
      assert entry.nickname == "nick1"
      assert entry.added_by == "op1"
    end

    test "returns error for duplicate channel+nickname" do
      {:ok, _} = Queries.add_invite_exception("#iexdup", "nick1", "op1")
      assert {:error, changeset} = Queries.add_invite_exception("#iexdup", "nick1", "op2")
      assert errors_on(changeset) != %{}
    end
  end

  describe "remove_invite_exception/2" do
    test "removes an invite exception entry" do
      {:ok, _} = Queries.add_invite_exception("#rmiex", "nick1", "op1")
      assert :ok = Queries.remove_invite_exception("#rmiex", "nick1")
    end

    test "returns error when entry not found" do
      assert {:error, :not_found} = Queries.remove_invite_exception("#nosuch", "nobody")
    end
  end

  describe "list_invite_exceptions/1" do
    test "returns all invite exceptions for a channel" do
      {:ok, _} = Queries.add_invite_exception("#listiex", "nick1", "op1")
      {:ok, _} = Queries.add_invite_exception("#listiex", "nick2", "op1")

      entries = Queries.list_invite_exceptions("#listiex")
      assert length(entries) == 2
    end

    test "returns empty list when no invite exceptions" do
      assert [] == Queries.list_invite_exceptions("#noiex")
    end
  end
end
