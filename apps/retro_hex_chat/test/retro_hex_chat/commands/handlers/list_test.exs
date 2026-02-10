defmodule RetroHexChat.Commands.Handlers.ListTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Handlers.List

  describe "execute/2" do
    test "returns ui_action to open channel list" do
      ctx = %{
        nickname: "Rodrigo",
        active_channel: nil,
        channels: [],
        identified: false,
        operator_in: []
      }

      assert {:ok, :ui_action, :open_channel_list, %{}} = List.execute([], ctx)
    end
  end

  describe "validate/1" do
    test "accepts any input" do
      assert :ok = List.validate("anything")
      assert :ok = List.validate("")
    end
  end

  describe "help/0" do
    test "returns help map" do
      help = List.help()
      assert help.name == "list"
    end
  end
end
