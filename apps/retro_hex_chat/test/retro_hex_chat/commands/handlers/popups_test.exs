defmodule RetroHexChat.Commands.Handlers.PopupsTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Handlers.Popups

  @context %{
    nickname: "Test",
    active_channel: "#lobby",
    channels: ["#lobby"],
    identified: false,
    operator_in: []
  }

  describe "validate/1" do
    test "accepts empty string" do
      assert :ok = Popups.validate("")
    end
  end

  describe "execute/2" do
    test "bare /popups opens custom menus dialog" do
      assert {:ok, :ui_action, :open_custom_menus_dialog, %{}} = Popups.execute([], @context)
    end
  end
end
