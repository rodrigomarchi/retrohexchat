defmodule RetroHexChat.Commands.RegistryTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Registry

  describe "lookup/1" do
    test "returns {:ok, module} for known command" do
      assert {:ok, RetroHexChat.Commands.Handlers.Join} = Registry.lookup("join")
    end

    test "returns {:error, :unknown_command} for unknown command" do
      assert {:error, :unknown_command} = Registry.lookup("nonexistent")
    end
  end

  describe "list_commands/0" do
    test "returns list with all registered commands" do
      commands = Registry.list_commands()
      assert is_list(commands)
      assert "join" in commands
      assert "part" in commands
      assert "nick" in commands
      assert length(commands) == 22
    end
  end

  describe "known?/1" do
    test "returns true for known command" do
      assert Registry.known?("join")
    end

    test "returns false for unknown command" do
      refute Registry.known?("nonexistent")
    end
  end
end
