defmodule RetroHexChat.Commands.Handlers.ClearWelcomeTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Handlers.ClearWelcome

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
      assert :ok = ClearWelcome.validate("")
      assert :ok = ClearWelcome.validate("anything")
    end
  end

  describe "execute/2" do
    test "no channel error" do
      ctx = %{@base_context | active_channel: nil}

      assert {:error, "You must be in a channel to use this command."} =
               ClearWelcome.execute([], ctx)
    end

    test "non-operator rejected" do
      ctx = %{@base_context | operator_in: []}

      assert {:error, "Permission denied: you must be a channel operator."} =
               ClearWelcome.execute([], ctx)
    end

    test "operator can clear welcome" do
      assert {:ok, :ui_action, :clear_welcome, %{channel: "#test"}} =
               ClearWelcome.execute([], @base_context)
    end

    test "operator can clear welcome with extra args (args ignored)" do
      assert {:ok, :ui_action, :clear_welcome, %{channel: "#test"}} =
               ClearWelcome.execute(["ignored", "args"], @base_context)
    end
  end

  describe "help/0" do
    test "returns help map" do
      help = ClearWelcome.help()
      assert help.name == "clearwelcome"
      assert is_binary(help.syntax)
      assert is_binary(help.description)
      assert is_list(help.examples)
    end
  end
end
