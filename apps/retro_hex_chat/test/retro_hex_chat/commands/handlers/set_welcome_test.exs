defmodule RetroHexChat.Commands.Handlers.SetWelcomeTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Handlers.SetWelcome

  @base_context %{
    nickname: "TestUser",
    active_channel: "#test",
    channels: ["#test"],
    identified: false,
    operator_in: ["#test"],
    half_operator_in: [],
    is_admin: false,
    is_server_operator: false
  }

  describe "validate/1" do
    test "accepts any input" do
      assert :ok = SetWelcome.validate("Welcome message")
      assert :ok = SetWelcome.validate("")
    end
  end

  describe "execute/2" do
    test "no channel error" do
      ctx = %{@base_context | active_channel: nil}

      assert {:error, "You must be in a channel to use this command."} =
               SetWelcome.execute(["Welcome"], ctx)
    end

    test "non-operator rejected" do
      ctx = %{@base_context | operator_in: []}

      assert {:error, "Permission denied: you must be a channel operator."} =
               SetWelcome.execute(["Welcome"], ctx)
    end

    test "operator can set welcome" do
      assert {:ok, :ui_action, :set_welcome,
              %{channel: "#test", message: "Welcome to our channel!"}} =
               SetWelcome.execute(["Welcome", "to", "our", "channel!"], @base_context)
    end

    test "operator can set welcome with single word" do
      assert {:ok, :ui_action, :set_welcome, %{channel: "#test", message: "Welcome"}} =
               SetWelcome.execute(["Welcome"], @base_context)
    end

    test "empty args treated as clear_welcome action" do
      assert {:ok, :ui_action, :clear_welcome, %{channel: "#test"}} =
               SetWelcome.execute([], @base_context)
    end

    test "empty args by non-operator rejected" do
      ctx = %{@base_context | operator_in: []}

      assert {:error, "Permission denied: you must be a channel operator."} =
               SetWelcome.execute([], ctx)
    end
  end

  describe "help/0" do
    test "returns help map" do
      help = SetWelcome.help()
      assert help.name == "setwelcome"
      assert is_binary(help.syntax)
      assert is_binary(help.description)
      assert is_list(help.examples)
    end
  end
end
