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

  describe "help/0" do
    test "returns help map with correct name" do
      help = Popups.help()
      assert help.name == "popups"
    end

    test "returns help map with syntax" do
      help = Popups.help()
      assert is_binary(help.syntax)
    end

    test "returns help map with examples" do
      help = Popups.help()
      assert [_ | _] = help.examples
    end
  end
end
