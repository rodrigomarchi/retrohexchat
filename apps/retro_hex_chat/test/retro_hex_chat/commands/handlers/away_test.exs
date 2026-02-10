defmodule RetroHexChat.Commands.Handlers.AwayTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Handlers.Away

  @base_context %{
    nickname: "Rodrigo",
    active_channel: "#lobby",
    channels: ["#lobby"],
    identified: false,
    operator_in: []
  }

  describe "validate/1" do
    test "accepts empty args" do
      assert :ok = Away.validate("")
    end

    test "accepts non-empty args" do
      assert :ok = Away.validate("Gone to lunch")
    end
  end

  describe "execute/2" do
    test "sets away with message" do
      assert {:ok, :ui_action, :set_away, %{message: "Gone to lunch"}} =
               Away.execute(["Gone", "to", "lunch"], @base_context)
    end

    test "clears away when no args" do
      assert {:ok, :ui_action, :clear_away, %{}} = Away.execute([], @base_context)
    end

    test "sets away with single word message" do
      assert {:ok, :ui_action, :set_away, %{message: "brb"}} =
               Away.execute(["brb"], @base_context)
    end
  end

  describe "help/0" do
    test "returns help map" do
      help = Away.help()
      assert help.name == "away"
      assert is_binary(help.syntax)
      assert is_binary(help.description)
      assert is_list(help.examples)
    end
  end
end
