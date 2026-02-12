defmodule RetroHexChat.Commands.Handlers.AutoRespondTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Handlers.AutoRespond

  describe "validate/1" do
    test "accepts empty string" do
      assert :ok = AutoRespond.validate("")
    end

    test "accepts list subcommand" do
      assert :ok = AutoRespond.validate("list")
    end

    test "accepts add with trigger and command" do
      assert :ok = AutoRespond.validate("add on_join /say hi")
    end

    test "accepts add with trigger, channel, and command" do
      assert :ok = AutoRespond.validate("add on_join #test /notice $nick hi")
    end

    test "rejects add without enough arguments" do
      assert {:error, _} = AutoRespond.validate("add")
    end

    test "accepts remove with position" do
      assert :ok = AutoRespond.validate("remove 0")
    end

    test "rejects remove without position" do
      assert {:error, _} = AutoRespond.validate("remove")
    end
  end

  describe "execute/2" do
    test "no args opens dialog" do
      assert {:ok, :ui_action, :open_autorespond_dialog, %{}} = AutoRespond.execute([], %{})
    end

    test "list returns ui action" do
      assert {:ok, :ui_action, :autorespond_list_display, %{}} =
               AutoRespond.execute(["list"], %{})
    end

    test "add with trigger and command (no channel)" do
      result = AutoRespond.execute(["add", "on_join", "/notice", "$nick", "Welcome!"], %{})
      assert {:ok, :ui_action, :autorespond_added, data} = result
      assert data.trigger_event == :on_join
      assert data.channel_filter == nil
      assert data.command == "/notice $nick Welcome!"
    end

    test "add with trigger, channel, and command" do
      result =
        AutoRespond.execute(["add", "on_join", "#test", "/notice", "$nick", "Welcome!"], %{})

      assert {:ok, :ui_action, :autorespond_added, data} = result
      assert data.trigger_event == :on_join
      assert data.channel_filter == "#test"
      assert data.command == "/notice $nick Welcome!"
    end

    test "add with on_part trigger" do
      result = AutoRespond.execute(["add", "on_part", "/say", "bye"], %{})
      assert {:ok, :ui_action, :autorespond_added, data} = result
      assert data.trigger_event == :on_part
    end

    test "add with on_nick_change trigger" do
      result = AutoRespond.execute(["add", "on_nick_change", "/say", "$nick", "changed"], %{})
      assert {:ok, :ui_action, :autorespond_added, data} = result
      assert data.trigger_event == :on_nick_change
    end

    test "add with invalid trigger returns error" do
      result = AutoRespond.execute(["add", "on_kick", "/say", "hi"], %{})
      assert {:error, _} = result
    end

    test "remove with position" do
      assert {:ok, :ui_action, :autorespond_removed, %{position: 0}} =
               AutoRespond.execute(["remove", "0"], %{})
    end

    test "remove with non-numeric position returns error" do
      assert {:error, _} = AutoRespond.execute(["remove", "abc"], %{})
    end
  end

  describe "help/0" do
    test "returns help map" do
      help = AutoRespond.help()
      assert help.name == "autorespond"
      assert is_binary(help.syntax)
      assert is_binary(help.description)
      assert is_list(help.examples)
    end
  end
end
