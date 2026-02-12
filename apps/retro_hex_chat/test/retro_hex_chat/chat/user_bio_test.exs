defmodule RetroHexChat.Chat.UserBioTest do
  use RetroHexChat.DataCase, async: true

  alias RetroHexChat.Chat.UserBio
  alias RetroHexChat.Services.Queries

  @moduletag :integration

  setup do
    nick = "BioUser#{System.unique_integer([:positive])}"
    {:ok, _} = Queries.insert_registered_nick(nick, "password123")
    %{nick: nick}
  end

  describe "save/2" do
    test "saves a bio for a registered user", %{nick: nick} do
      assert :ok = UserBio.save(nick, "Hello world")
    end

    test "overwrites existing bio on save", %{nick: nick} do
      :ok = UserBio.save(nick, "First bio")
      :ok = UserBio.save(nick, "Updated bio")
      assert {:ok, "Updated bio"} = UserBio.load(nick)
    end
  end

  describe "load/1" do
    test "returns bio text for existing user", %{nick: nick} do
      :ok = UserBio.save(nick, "My bio text")
      assert {:ok, "My bio text"} = UserBio.load(nick)
    end

    test "returns error for user with no bio", %{nick: nick} do
      assert {:error, :not_found} = UserBio.load(nick)
    end

    test "returns error for non-existent user" do
      assert {:error, :not_found} = UserBio.load("NonExistentUser")
    end
  end

  describe "delete/1" do
    test "deletes existing bio", %{nick: nick} do
      :ok = UserBio.save(nick, "To be deleted")
      assert :ok = UserBio.delete(nick)
      assert {:error, :not_found} = UserBio.load(nick)
    end

    test "returns :ok when no bio exists", %{nick: nick} do
      assert :ok = UserBio.delete(nick)
    end
  end
end
