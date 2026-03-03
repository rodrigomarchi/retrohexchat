defmodule RetroHexChat.Bots.Capabilities.ArcadeTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Bots.Capabilities.Arcade

  @ctx %{
    bot_nickname: "ArcadeBot",
    bot_name: "ArcadeBot",
    channel: "#games",
    command_prefix: "!",
    config: Arcade.default_config(),
    capability_state: %{}
  }

  describe "name/0" do
    test "returns :arcade" do
      assert Arcade.name() == :arcade
    end
  end

  describe "description/0" do
    test "returns description without 'Coming soon'" do
      desc = Arcade.description()
      assert is_binary(desc)
      refute desc =~ "Coming soon"
    end
  end

  describe "commands/0" do
    test "returns play command" do
      cmds = Arcade.commands()
      assert length(cmds) == 1
      assert hd(cmds).trigger == "play"
    end
  end

  describe "default_config/0" do
    test "returns a map with enabled" do
      config = Arcade.default_config()
      assert is_map(config)
      assert config["enabled"] == true
    end
  end

  describe "validate_config/1" do
    test "accepts any config" do
      assert :ok == Arcade.validate_config(%{})
      assert :ok == Arcade.validate_config(Arcade.default_config())
    end
  end

  describe "handle_event/3" do
    test "always returns :ignore" do
      assert :ignore == Arcade.handle_event(:user_joined, %{}, @ctx)
    end
  end

  describe "handle_message/3 — command parsing" do
    test "ignores unrelated messages" do
      assert :ignore == Arcade.handle_message("hello world", "user", @ctx)
    end

    test "ignores messages for other bots" do
      assert :ignore == Arcade.handle_message("!OtherBot play", "user", @ctx)
    end

    test "ignores partial matches" do
      assert :ignore == Arcade.handle_message("!playing", "user", @ctx)
      assert :ignore == Arcade.handle_message("!playback", "user", @ctx)
    end

    test "ignores messages without prefix" do
      assert :ignore == Arcade.handle_message("play", "user", @ctx)
    end
  end
end
