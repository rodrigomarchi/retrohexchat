defmodule RetroHexChat.Bots.Capabilities.HelpTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Bots.Capabilities.Help

  @commands %{
    "rules" => %{"response" => "Read #rules", "description" => "Show rules", "enabled" => true},
    "faq" => %{"response" => "Check FAQ", "description" => "Show FAQ", "enabled" => true}
  }

  @ctx %{
    bot_nickname: "HelpBot",
    bot_name: "HelpBot",
    channel: "#general",
    command_prefix: "!",
    config: %{"commands" => @commands}
  }

  describe "name/0" do
    test "returns :help" do
      assert Help.name() == :help
    end
  end

  describe "handle_message/3" do
    test "responds to !BotName help" do
      assert {:multi_reply, lines} = Help.handle_message("!HelpBot help", "Alice", @ctx)
      assert hd(lines) =~ "HelpBot"
      assert length(lines) >= 2
    end

    test "responds to !BotNamehelp (no space)" do
      assert {:multi_reply, _} = Help.handle_message("!HelpBothelp", "Alice", @ctx)
    end

    test "case insensitive" do
      assert {:multi_reply, _} = Help.handle_message("!helpbot HELP", "Alice", @ctx)
    end

    test "lists available commands" do
      assert {:multi_reply, lines} = Help.handle_message("!HelpBot help", "Alice", @ctx)
      text = Enum.join(lines, "\n")
      assert text =~ "faq"
      assert text =~ "rules"
      assert text =~ "help"
    end

    test "ignores non-help messages" do
      assert :ignore == Help.handle_message("hello", "Alice", @ctx)
      assert :ignore == Help.handle_message("!HelpBot rules", "Alice", @ctx)
    end

    test "works with empty commands" do
      ctx = put_in(@ctx.config["commands"], %{})
      assert {:multi_reply, lines} = Help.handle_message("!HelpBot help", "Alice", ctx)
      assert length(lines) == 2
    end
  end

  describe "commands/0" do
    test "returns help command entry" do
      cmds = Help.commands()
      assert [%{trigger: "help", description: _}] = cmds
    end
  end
end
