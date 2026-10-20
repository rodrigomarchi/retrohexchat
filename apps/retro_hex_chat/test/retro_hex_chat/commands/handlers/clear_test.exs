defmodule RetroHexChat.Commands.Handlers.ClearTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Handlers.Clear

  @base_context %{
    nickname: "Alice",
    active_channel: "#lobby",
    channels: ["#lobby"],
    identified: false,
    operator_in: []
  }

  describe "validate/1" do
    test "accepts empty args" do
      assert :ok = Clear.validate("")
    end

    test "accepts any args" do
      assert :ok = Clear.validate("anything")
    end
  end

  describe "execute/2" do
    test "returns clear_chat action" do
      assert {:ok, :ui_action, :clear_chat, %{}} = Clear.execute([], @base_context)
    end

    test "returns clear_chat action ignoring args" do
      assert {:ok, :ui_action, :clear_chat, %{}} = Clear.execute(["extra"], @base_context)
    end
  end
end
