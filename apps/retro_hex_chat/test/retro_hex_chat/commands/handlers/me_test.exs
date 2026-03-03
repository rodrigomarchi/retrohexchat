defmodule RetroHexChat.Commands.Handlers.MeTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Handlers.Me

  @base_context %{
    nickname: "Alice",
    active_channel: "#lobby",
    channels: ["#lobby"],
    identified: false,
    operator_in: []
  }

  describe "validate/1" do
    test "accepts non-empty args" do
      assert :ok = Me.validate("dances around")
    end

    test "rejects empty args" do
      assert {:error, _} = Me.validate("")
    end
  end

  describe "execute/2" do
    test "returns action with content" do
      assert {:ok, :action, %{content: "dances around"}} =
               Me.execute(["dances", "around"], @base_context)
    end

    test "returns action for single word" do
      assert {:ok, :action, %{content: "waves"}} =
               Me.execute(["waves"], @base_context)
    end

    test "errors when no args provided" do
      assert {:error, _} = Me.execute([], @base_context)
    end

    test "errors when no active channel" do
      ctx = %{@base_context | active_channel: nil}
      assert {:error, _} = Me.execute(["waves"], ctx)
    end
  end

  describe "help/0" do
    test "returns help map" do
      help = Me.help()
      assert help.name == "me"
      assert is_binary(help.syntax)
      assert is_binary(help.description)
      assert is_list(help.examples)
    end
  end
end
