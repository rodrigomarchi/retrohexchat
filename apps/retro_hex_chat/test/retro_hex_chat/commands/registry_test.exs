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
      assert "invite" in commands
      assert length(commands) == 47
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

  describe "command_metadata/0" do
    test "returns all commands with metadata" do
      metadata = Registry.command_metadata()
      assert is_list(metadata)
      assert length(metadata) == 47

      join = Enum.find(metadata, &(&1.name == "join"))
      assert join.description =~ "chat channel"
      assert join.category == "Channel"
      assert join.category_atom == :channel
    end

    test "each command has required fields" do
      for cmd <- Registry.command_metadata() do
        assert is_binary(cmd.name)
        assert is_binary(cmd.description)
        assert is_binary(cmd.category)
        assert cmd.category_atom in [:basics, :channel, :user, :config, :advanced]
      end
    end
  end

  describe "commands_by_category/0" do
    test "returns commands grouped in display order" do
      categories = Registry.commands_by_category()
      labels = Enum.map(categories, &elem(&1, 0))

      assert labels == ["Basics", "Channel", "User", "Configuration", "Advanced"]
    end

    test "each group contains sorted commands with name and description" do
      for {_label, commands} <- Registry.commands_by_category() do
        assert commands != []
        names = Enum.map(commands, & &1.name)
        assert names == Enum.sort(names)

        for cmd <- commands do
          assert Map.has_key?(cmd, :name)
          assert Map.has_key?(cmd, :description)
        end
      end
    end

    test "all commands are covered across categories" do
      all_names =
        Registry.commands_by_category()
        |> Enum.flat_map(fn {_label, cmds} -> Enum.map(cmds, & &1.name) end)

      # 46 unique commands (leave is alias for part, both in registry but Part handler covers both)
      assert length(all_names) == 47
    end
  end
end
