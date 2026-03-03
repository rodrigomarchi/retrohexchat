defmodule RetroHexChat.Bots.Capabilities.ArcadeIntegrationTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Bots.Capabilities.Arcade
  alias RetroHexChat.Services.NickServ

  @ctx %{
    bot_nickname: "ArcadeBot",
    bot_name: "ArcadeBot",
    channel: "#games",
    command_prefix: "!",
    config: Arcade.default_config(),
    capability_state: %{}
  }

  describe "handle_message/3 — !play flow" do
    test "replies with error when user is not identified" do
      result = Arcade.handle_message("!play", "UnknownUser", @ctx)
      assert {:reply, text} = result
      assert text =~ "UnknownUser"
      assert text =~ "identified"
    end

    test "replies with error when user is identified but not registered" do
      # Register and identify, then drop nick to simulate "identified but no DB record"
      # Actually, NickServ.identified? checks the in-memory set, so we need to
      # add the nick to the identified set manually. But the simplest approach:
      # register + identify, then delete the DB record.
      nick = "ArcNoReg#{System.unique_integer([:positive])}"
      {:ok, _} = NickServ.register(nick, "testpass123")
      {:ok, _} = NickServ.identify(nick, "testpass123")

      # Delete the registered nick from DB to simulate "identified but no DB record"
      RetroHexChat.Repo.delete_all(
        from(rn in RetroHexChat.Services.RegisteredNick, where: rn.nickname == ^nick)
      )

      result = Arcade.handle_message("!play", nick, @ctx)
      assert {:reply, text} = result
      assert text =~ nick
      assert text =~ "registered"
    end

    test "creates arcade session and returns URL for identified+registered user" do
      nick = "ArcPlay#{System.unique_integer([:positive])}"
      {:ok, _} = NickServ.register(nick, "testpass123")
      {:ok, _} = NickServ.identify(nick, "testpass123")

      result = Arcade.handle_message("!play", nick, @ctx)
      assert {:reply, text} = result
      assert text =~ nick
      assert text =~ "/solo/"
      assert text =~ "Arcade session ready"
    end

    test "works with long format !ArcadeBot play" do
      nick = "ArcLong#{System.unique_integer([:positive])}"
      {:ok, _} = NickServ.register(nick, "testpass123")
      {:ok, _} = NickServ.identify(nick, "testpass123")

      result = Arcade.handle_message("!ArcadeBot play", nick, @ctx)
      assert {:reply, text} = result
      assert text =~ "/solo/"
    end

    test "is case insensitive" do
      nick = "ArcCase#{System.unique_integer([:positive])}"
      {:ok, _} = NickServ.register(nick, "testpass123")
      {:ok, _} = NickServ.identify(nick, "testpass123")

      result = Arcade.handle_message("!PLAY", nick, @ctx)
      assert {:reply, text} = result
      assert text =~ "/solo/"
    end
  end
end
