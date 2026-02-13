defmodule RetroHexChat.Commands.Handlers.AnnounceTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Handlers.Announce

  @base_context %{
    nickname: "Admin",
    active_channel: nil,
    channels: [],
    identified: true,
    operator_in: [],
    half_operator_in: [],
    is_admin: true,
    is_server_operator: false
  }

  describe "validate/1" do
    test "accepts any input" do
      assert :ok = Announce.validate("Important announcement")
      assert :ok = Announce.validate("")
    end
  end

  describe "execute/2" do
    test "non-admin rejected" do
      ctx = %{@base_context | is_admin: false}

      assert {:error, "Permission denied: you must be a server administrator."} =
               Announce.execute(["Message"], ctx)
    end

    test "empty args returns usage error" do
      assert {:error, "Usage: /announce <message>"} =
               Announce.execute([], @base_context)
    end

    test "admin can announce" do
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "server:announcements")

      assert {:ok, :system, %{content: "Announcement sent to all users."}} =
               Announce.execute(["Server", "restart", "at", "midnight"], @base_context)

      assert_receive {:announcement, %{sender: "Admin", content: "Server restart at midnight"}}
    end

    test "broadcasts {:announcement, ...} to server:announcements" do
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "server:announcements")

      Announce.execute(["Test", "announcement"], @base_context)

      assert_receive {:announcement,
                      %{sender: "Admin", content: "Test announcement", timestamp: %DateTime{}}}
    end

    test "admin can announce single word" do
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "server:announcements")

      assert {:ok, :system, %{content: "Announcement sent to all users."}} =
               Announce.execute(["Maintenance"], @base_context)

      assert_receive {:announcement, %{sender: "Admin", content: "Maintenance"}}
    end
  end

  describe "help/0" do
    test "returns help map" do
      help = Announce.help()
      assert help.name == "announce"
      assert is_binary(help.syntax)
      assert is_binary(help.description)
      assert is_list(help.examples)
    end
  end
end
