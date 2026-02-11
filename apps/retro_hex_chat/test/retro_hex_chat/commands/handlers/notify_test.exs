defmodule RetroHexChat.Commands.Handlers.NotifyTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Handlers.Notify

  @context %{
    nickname: "Tester",
    active_channel: "#test",
    channels: ["#test"],
    identified: false,
    operator_in: []
  }

  describe "validate/1" do
    test "accepts empty string (bare /notify)" do
      assert :ok = Notify.validate("")
    end

    test "accepts list subcommand" do
      assert :ok = Notify.validate("list")
    end

    test "rejects add without nickname" do
      assert {:error, msg} = Notify.validate("add")
      assert msg == "Usage: /notify add <nickname> [note]"
    end

    test "accepts add with nickname" do
      assert :ok = Notify.validate("add Alice")
    end

    test "accepts add with nickname and note" do
      assert :ok = Notify.validate("add Alice some note words")
    end

    test "rejects remove without nickname" do
      assert {:error, msg} = Notify.validate("remove")
      assert msg == "Usage: /notify remove <nickname>"
    end

    test "accepts remove with nickname" do
      assert :ok = Notify.validate("remove Alice")
    end

    test "rejects edit without arguments" do
      assert {:error, msg} = Notify.validate("edit")
      assert msg == "Usage: /notify edit <nickname> <note>"
    end

    test "rejects edit with nickname but no note" do
      assert {:error, msg} = Notify.validate("edit Alice")
      assert msg == "Usage: /notify edit <nickname> <note>"
    end

    test "accepts edit with nickname and note" do
      assert :ok = Notify.validate("edit Alice new note")
    end

    test "rejects unknown subcommand" do
      assert {:error, msg} = Notify.validate("foobar")
      assert msg == "Unknown /notify subcommand. Use: add, remove, edit, list"
    end

    test "rejects another unknown subcommand" do
      assert {:error, msg} = Notify.validate("status")
      assert msg == "Unknown /notify subcommand. Use: add, remove, edit, list"
    end
  end

  describe "execute/2" do
    test "bare /notify opens notify list window" do
      assert {:ok, :ui_action, :open_notify_list, %{}} = Notify.execute([], @context)
    end

    test "add with nickname only sets note to nil" do
      assert {:ok, :ui_action, :notify_add, %{nickname: "Alice", note: nil}} =
               Notify.execute(["add", "Alice"], @context)
    end

    test "add with nickname and multi-word note joins note words" do
      assert {:ok, :ui_action, :notify_add, %{nickname: "Alice", note: "Works on Elixir"}} =
               Notify.execute(["add", "Alice", "Works", "on", "Elixir"], @context)
    end

    test "add with nickname and single-word note" do
      assert {:ok, :ui_action, :notify_add, %{nickname: "Bob", note: "friend"}} =
               Notify.execute(["add", "Bob", "friend"], @context)
    end

    test "remove returns notify_remove action with nickname" do
      assert {:ok, :ui_action, :notify_remove, %{nickname: "Alice"}} =
               Notify.execute(["remove", "Alice"], @context)
    end

    test "edit returns notify_edit action with nickname and joined note" do
      assert {:ok, :ui_action, :notify_edit, %{nickname: "Alice", note: "New note"}} =
               Notify.execute(["edit", "Alice", "New", "note"], @context)
    end

    test "edit with single-word note" do
      assert {:ok, :ui_action, :notify_edit, %{nickname: "Alice", note: "updated"}} =
               Notify.execute(["edit", "Alice", "updated"], @context)
    end

    test "list returns notify_list_display action" do
      assert {:ok, :ui_action, :notify_list_display, %{}} = Notify.execute(["list"], @context)
    end
  end

  describe "help/0" do
    test "returns help map with correct name" do
      help = Notify.help()
      assert help.name == "notify"
    end

    test "returns help map with syntax string" do
      help = Notify.help()
      assert is_binary(help.syntax)
      assert help.syntax =~ "/notify"
    end

    test "returns help map with description string" do
      help = Notify.help()
      assert is_binary(help.description)
    end

    test "returns help map with examples list" do
      help = Notify.help()
      assert is_list(help.examples)
      assert length(help.examples) > 0
    end
  end
end
