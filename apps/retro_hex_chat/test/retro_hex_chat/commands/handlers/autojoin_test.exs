defmodule RetroHexChat.Commands.Handlers.AutoJoinTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Handlers.AutoJoin

  @context %{
    nickname: "Test",
    active_channel: "#lobby",
    channels: ["#lobby"],
    identified: false,
    operator_in: []
  }

  # ── validate/1 ────────────────────────────────────────────

  describe "validate/1" do
    test "accepts empty string (bare /autojoin)" do
      assert :ok = AutoJoin.validate("")
    end

    test "accepts list subcommand" do
      assert :ok = AutoJoin.validate("list")
    end

    test "accepts clear subcommand" do
      assert :ok = AutoJoin.validate("clear")
    end

    test "accepts add with a channel" do
      assert :ok = AutoJoin.validate("add #elixir")
    end

    test "accepts add with a channel and key" do
      assert :ok = AutoJoin.validate("add #secret mykey")
    end

    test "rejects add without a channel" do
      assert {:error, msg} = AutoJoin.validate("add")
      assert msg =~ "Usage"
    end

    test "rejects add with whitespace-only argument" do
      assert {:error, msg} = AutoJoin.validate("add   ")
      assert msg =~ "Usage"
    end

    test "rejects add with channel not starting with #" do
      assert {:error, msg} = AutoJoin.validate("add lobby")
      assert msg =~ "must start with #"
    end

    test "accepts remove with a channel" do
      assert :ok = AutoJoin.validate("remove #elixir")
    end

    test "rejects remove without a channel" do
      assert {:error, msg} = AutoJoin.validate("remove")
      assert msg =~ "Usage"
    end

    test "rejects remove with channel not starting with #" do
      assert {:error, msg} = AutoJoin.validate("remove lobby")
      assert msg =~ "must start with #"
    end

    test "rejects unknown subcommand" do
      assert {:error, msg} = AutoJoin.validate("unknown")
      assert msg =~ "Unknown autojoin subcommand"
    end

    test "rejects another unknown subcommand" do
      assert {:error, msg} = AutoJoin.validate("edit #foo")
      assert msg =~ "Unknown autojoin subcommand"
    end
  end

  # ── execute/2 ────────────────────────────────────────────

  describe "execute/2" do
    test "bare /autojoin opens perform dialog on autojoin tab" do
      assert {:ok, :ui_action, :open_perform_dialog, %{tab: "autojoin"}} =
               AutoJoin.execute([], @context)
    end

    test "list returns autojoin_list_display ui_action" do
      assert {:ok, :ui_action, :autojoin_list_display, %{}} =
               AutoJoin.execute(["list"], @context)
    end

    test "add returns autojoin_add with channel and nil key" do
      assert {:ok, :ui_action, :autojoin_add, %{channel: "#elixir", key: nil}} =
               AutoJoin.execute(["add", "#elixir"], @context)
    end

    test "add returns autojoin_add with channel and key" do
      assert {:ok, :ui_action, :autojoin_add, %{channel: "#secret", key: "mykey"}} =
               AutoJoin.execute(["add", "#secret", "mykey"], @context)
    end

    test "remove returns autojoin_remove with channel" do
      assert {:ok, :ui_action, :autojoin_remove, %{channel: "#elixir"}} =
               AutoJoin.execute(["remove", "#elixir"], @context)
    end

    test "clear returns autojoin_clear ui_action" do
      assert {:ok, :ui_action, :autojoin_clear, %{}} =
               AutoJoin.execute(["clear"], @context)
    end
  end

  # ── help/0 ────────────────────────────────────────────────

  describe "help/0" do
    test "returns help map with correct name" do
      help = AutoJoin.help()
      assert help.name == "autojoin"
    end

    test "returns help map with syntax string" do
      help = AutoJoin.help()
      assert is_binary(help.syntax)
      assert help.syntax =~ "/autojoin"
    end

    test "returns help map with description" do
      help = AutoJoin.help()
      assert is_binary(help.description)
    end

    test "returns help map with examples list" do
      help = AutoJoin.help()
      assert [_ | _] = help.examples
    end
  end
end
