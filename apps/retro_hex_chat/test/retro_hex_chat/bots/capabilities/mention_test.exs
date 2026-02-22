defmodule RetroHexChat.Bots.Capabilities.MentionTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Bots.Capabilities.Mention

  @ctx %{
    bot_nickname: "TestBot",
    bot_name: "TestBot",
    channel: "#general",
    command_prefix: "!",
    config: %{"response" => "Hi {nickname}! Try {prefix}help for my commands."}
  }

  describe "name/0" do
    test "returns :mention" do
      assert Mention.name() == :mention
    end
  end

  describe "handle_message/3" do
    test "responds when bot is mentioned" do
      assert {:reply, reply} = Mention.handle_message("hey TestBot", "Alice", @ctx)
      assert reply == "Hi Alice! Try !help for my commands."
    end

    test "case-insensitive mention detection" do
      assert {:reply, _} = Mention.handle_message("hey testbot", "Alice", @ctx)
      assert {:reply, _} = Mention.handle_message("hey TESTBOT", "Alice", @ctx)
    end

    test "ignores messages without mention" do
      assert :ignore == Mention.handle_message("hello world", "Alice", @ctx)
    end

    test "uses custom response from config" do
      ctx = put_in(@ctx.config["response"], "What's up {nickname}?")
      assert {:reply, "What's up Bob?"} = Mention.handle_message("TestBot hi", "Bob", ctx)
    end
  end

  describe "handle_event/3" do
    test "always ignores events" do
      assert :ignore == Mention.handle_event(:user_joined, %{}, @ctx)
    end
  end

  describe "default_config/0" do
    test "returns config with response" do
      config = Mention.default_config()
      assert is_binary(config["response"])
      assert config["enabled"] == true
    end
  end

  describe "validate_config/1" do
    test "accepts valid config" do
      assert :ok == Mention.validate_config(%{"response" => "hello"})
    end

    test "rejects empty response" do
      assert {:error, _} = Mention.validate_config(%{"response" => ""})
    end
  end
end
