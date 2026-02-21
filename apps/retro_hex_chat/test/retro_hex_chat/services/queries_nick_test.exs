defmodule RetroHexChat.Services.QueriesNickTest do
  use RetroHexChat.DataCase, async: true

  @moduletag :integration

  alias RetroHexChat.Services.Queries
  alias RetroHexChat.Services.RegisteredNick

  describe "insert_registered_nick/2" do
    test "creates a registered nick with hashed password" do
      assert {:ok, %RegisteredNick{} = nick} =
               Queries.insert_registered_nick("TestNick", "secret123")

      assert nick.nickname == "TestNick"
      assert nick.password_hash != nil
      assert nick.password_hash != "secret123"
      assert nick.registered_at != nil
    end

    test "returns error for duplicate nickname" do
      assert {:ok, _} = Queries.insert_registered_nick("DupeNick", "secret123")
      assert {:error, changeset} = Queries.insert_registered_nick("DupeNick", "secret456")
      assert %{nickname: _} = errors_on(changeset)
    end

    test "returns error for invalid password (too short)" do
      assert {:error, changeset} = Queries.insert_registered_nick("ShortPw", "ab")
      assert %{password: _} = errors_on(changeset)
    end
  end

  describe "find_by_nickname/1" do
    test "finds an existing registered nick" do
      {:ok, _} = Queries.insert_registered_nick("FindMe", "secret123")
      assert %RegisteredNick{nickname: "FindMe"} = Queries.find_by_nickname("FindMe")
    end

    test "returns nil for nonexistent nickname" do
      assert nil == Queries.find_by_nickname("NoSuchNick")
    end
  end

  describe "delete_registered_nick/1" do
    test "deletes a registered nick" do
      {:ok, nick} = Queries.insert_registered_nick("DeleteMe", "secret123")
      assert {:ok, %RegisteredNick{}} = Queries.delete_registered_nick(nick)
      assert nil == Queries.find_by_nickname("DeleteMe")
    end
  end

  describe "update_last_seen/1" do
    test "updates the last_seen_at timestamp" do
      {:ok, nick} = Queries.insert_registered_nick("SeenNick", "secret123")
      assert nick.last_seen_at != nil

      original_last_seen = nick.last_seen_at
      Process.sleep(10)
      assert {:ok, updated} = Queries.update_last_seen(nick)
      assert DateTime.compare(updated.last_seen_at, original_last_seen) == :gt
    end
  end
end
