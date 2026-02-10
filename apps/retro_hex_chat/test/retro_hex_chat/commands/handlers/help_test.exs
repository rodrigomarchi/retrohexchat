defmodule RetroHexChat.Commands.Handlers.HelpTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Handlers.Help

  @base_context %{
    nickname: "Rodrigo",
    active_channel: "#lobby",
    channels: ["#lobby"],
    identified: false,
    operator_in: []
  }

  describe "validate/1" do
    test "accepts empty args" do
      assert :ok = Help.validate("")
    end

    test "accepts non-empty args" do
      assert :ok = Help.validate("join")
    end
  end

  describe "execute/2" do
    test "returns list of all commands when no args" do
      assert {:ok, :ui_action, :show_help, %{commands: commands}} =
               Help.execute([], @base_context)

      assert is_list(commands)
      assert "join" in commands
      assert "help" in commands
    end

    test "returns help for specific command" do
      assert {:ok, :ui_action, :show_command_help, %{help: help_map}} =
               Help.execute(["join"], @base_context)

      assert help_map.name == "join"
      assert is_binary(help_map.syntax)
      assert is_binary(help_map.description)
      assert is_list(help_map.examples)
    end

    test "errors when command not found" do
      assert {:error, _} = Help.execute(["nonexistent"], @base_context)
    end

    test "returns help for me command" do
      assert {:ok, :ui_action, :show_command_help, %{help: help_map}} =
               Help.execute(["me"], @base_context)

      assert help_map.name == "me"
    end
  end

  describe "help/0" do
    test "returns help map" do
      help = Help.help()
      assert help.name == "help"
      assert is_binary(help.syntax)
      assert is_binary(help.description)
      assert is_list(help.examples)
    end
  end
end
