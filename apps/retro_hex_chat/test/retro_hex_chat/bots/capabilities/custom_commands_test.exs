defmodule RetroHexChat.Bots.Capabilities.CustomCommandsTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Bots.Capabilities.CustomCommands

  @commands %{
    "rules" => %{
      "response" => "Please read #rules",
      "description" => "Show rules",
      "enabled" => true
    },
    "faq" => %{"response" => "Check /help faq", "description" => "Show FAQ", "enabled" => true},
    "disabled" => %{"response" => "nope", "description" => "Disabled cmd", "enabled" => false}
  }

  @ctx %{
    bot_nickname: "HelpBot",
    bot_name: "HelpBot",
    channel: "#general",
    command_prefix: "!",
    config: %{"commands" => @commands}
  }

  describe "name/0" do
    test "returns :custom_commands" do
      assert CustomCommands.name() == :custom_commands
    end
  end

  describe "handle_message/3" do
    test "responds to valid command" do
      assert {:reply, "Please read #rules"} =
               CustomCommands.handle_message("!HelpBot rules", "Alice", @ctx)
    end

    test "responds to another command" do
      assert {:reply, "Check /help faq"} =
               CustomCommands.handle_message("!HelpBot faq", "Bob", @ctx)
    end

    test "ignores non-command messages" do
      assert :ignore == CustomCommands.handle_message("hello world", "Alice", @ctx)
    end

    test "ignores messages with wrong prefix" do
      assert :ignore == CustomCommands.handle_message("?HelpBot rules", "Alice", @ctx)
    end

    test "ignores unknown triggers" do
      assert :ignore == CustomCommands.handle_message("!HelpBot unknown", "Alice", @ctx)
    end

    test "uses template variables in response" do
      commands = %{
        "greet" => %{"response" => "Hello {nickname} in {channel}!", "enabled" => true}
      }

      ctx = put_in(@ctx.config["commands"], commands)

      assert {:reply, "Hello Alice in #general!"} =
               CustomCommands.handle_message("!HelpBot greet", "Alice", ctx)
    end
  end

  describe "handle_message/3 short format (!trigger without bot name)" do
    test "responds to !trigger directly" do
      assert {:reply, "Please read #rules"} =
               CustomCommands.handle_message("!rules", "Alice", @ctx)
    end

    test "responds to !trigger with extra whitespace" do
      assert {:reply, "Please read #rules"} =
               CustomCommands.handle_message("  !rules  ", "Alice", @ctx)
    end

    test "case insensitive trigger matching" do
      assert {:reply, "Please read #rules"} =
               CustomCommands.handle_message("!RULES", "Alice", @ctx)
    end

    test "ignores unknown short trigger" do
      assert :ignore == CustomCommands.handle_message("!unknown", "Alice", @ctx)
    end

    test "long format still works alongside short format" do
      assert {:reply, "Please read #rules"} =
               CustomCommands.handle_message("!HelpBot rules", "Alice", @ctx)
    end
  end

  describe "handle_event/3" do
    test "always ignores events" do
      assert :ignore == CustomCommands.handle_event(:user_joined, %{}, @ctx)
    end
  end
end
