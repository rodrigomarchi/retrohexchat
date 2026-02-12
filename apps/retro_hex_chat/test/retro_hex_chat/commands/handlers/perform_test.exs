defmodule RetroHexChat.Commands.Handlers.PerformTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Handlers.Perform

  @context %{
    nickname: "Test",
    active_channel: "#lobby",
    channels: ["#lobby"],
    identified: false,
    operator_in: []
  }

  # ── validate/1 ────────────────────────────────────────────

  describe "validate/1" do
    test "accepts empty string (bare /perform)" do
      assert :ok = Perform.validate("")
    end

    test "accepts list subcommand" do
      assert :ok = Perform.validate("list")
    end

    test "accepts add with a command" do
      assert :ok = Perform.validate("add /join #elixir")
    end

    test "rejects add without a command" do
      assert {:error, "Usage: /perform add <command>"} = Perform.validate("add")
    end

    test "accepts remove with a number" do
      assert :ok = Perform.validate("remove 0")
    end

    test "rejects remove without a number" do
      assert {:error, "Usage: /perform remove <number>"} = Perform.validate("remove")
    end

    test "rejects remove with non-numeric argument" do
      assert {:error, msg} = Perform.validate("remove abc")
      assert msg =~ "Invalid position"
    end

    test "accepts move with two numbers" do
      assert :ok = Perform.validate("move 0 1")
    end

    test "rejects move with no arguments" do
      assert {:error, "Usage: /perform move <from> <to>"} = Perform.validate("move")
    end

    test "rejects move with only one argument" do
      assert {:error, "Usage: /perform move <from> <to>"} = Perform.validate("move 0")
    end

    test "rejects move with non-numeric arguments" do
      assert {:error, msg} = Perform.validate("move a b")
      assert msg =~ "Invalid position"
    end

    test "accepts clear subcommand" do
      assert :ok = Perform.validate("clear")
    end

    test "rejects unknown subcommand" do
      assert {:error, msg} = Perform.validate("unknown")
      assert msg =~ "Unknown subcommand"
    end
  end

  # ── execute/2 ────────────────────────────────────────────

  describe "execute/2" do
    test "bare /perform opens perform dialog" do
      assert {:ok, :ui_action, :open_perform_dialog, %{}} = Perform.execute([], @context)
    end

    test "list returns perform_list_display ui_action" do
      assert {:ok, :ui_action, :perform_list_display, %{}} = Perform.execute(["list"], @context)
    end

    test "add returns perform_add with joined command" do
      assert {:ok, :ui_action, :perform_add, %{command: "/join #elixir"}} =
               Perform.execute(["add", "/join", "#elixir"], @context)
    end

    test "remove with position 0 returns perform_remove" do
      assert {:ok, :ui_action, :perform_remove, %{position: 0}} =
               Perform.execute(["remove", "0"], @context)
    end

    test "remove with position 5 returns perform_remove" do
      assert {:ok, :ui_action, :perform_remove, %{position: 5}} =
               Perform.execute(["remove", "5"], @context)
    end

    test "move returns perform_move with from and to positions" do
      assert {:ok, :ui_action, :perform_move, %{from: 0, to: 2}} =
               Perform.execute(["move", "0", "2"], @context)
    end

    test "clear returns perform_clear ui_action" do
      assert {:ok, :ui_action, :perform_clear, %{}} = Perform.execute(["clear"], @context)
    end
  end

  # ── help/0 ────────────────────────────────────────────────

  describe "help/0" do
    test "returns help map with correct name" do
      help = Perform.help()
      assert help.name == "perform"
    end

    test "returns help map with syntax string" do
      help = Perform.help()
      assert is_binary(help.syntax)
      assert help.syntax =~ "/perform"
    end

    test "returns help map with description" do
      help = Perform.help()
      assert is_binary(help.description)
    end

    test "returns help map with examples list" do
      help = Perform.help()
      assert [_ | _] = help.examples
    end
  end
end
