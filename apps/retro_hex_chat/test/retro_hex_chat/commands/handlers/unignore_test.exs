defmodule RetroHexChat.Commands.Handlers.UnignoreTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Handlers.Unignore

  @context %{
    nickname: "Tester",
    active_channel: "#test",
    channels: ["#test"],
    identified: false,
    operator_in: []
  }

  describe "validate/1" do
    test "rejects empty string" do
      assert {:error, msg} = Unignore.validate("")
      assert msg =~ "Usage:"
    end

    test "accepts nickname" do
      assert :ok = Unignore.validate("SpamBot")
    end
  end

  describe "execute/2" do
    test "with nickname returns ignore_remove ui_action" do
      assert {:ok, :ui_action, :ignore_remove, %{nickname: "SpamBot"}} =
               Unignore.execute(["SpamBot"], @context)
    end
  end

  describe "help/0" do
    test "returns help map with correct name" do
      help = Unignore.help()
      assert help.name == "unignore"
    end

    test "returns help map with syntax string" do
      help = Unignore.help()
      assert is_binary(help.syntax)
      assert help.syntax =~ "/unignore"
    end

    test "returns help map with examples list" do
      help = Unignore.help()
      assert [_ | _] = help.examples
    end
  end
end
