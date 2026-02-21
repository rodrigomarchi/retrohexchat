defmodule RetroHexChat.Commands.Handlers.UnbanTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Handlers.Unban

  @base_context %{
    nickname: "Rodrigo",
    active_channel: "#lobby",
    channels: ["#lobby"],
    identified: false,
    operator_in: ["#lobby"]
  }

  describe "validate/1" do
    test "accepts any input" do
      assert :ok = Unban.validate("user")
      assert :ok = Unban.validate("")
    end
  end

  describe "execute/2" do
    test "/unban user returns unban_user ui_action" do
      assert {:ok, :ui_action, :unban_user, %{channel: "#lobby", target: "user"}} =
               Unban.execute(["user"], @base_context)
    end

    test "/unban with no target returns error" do
      assert {:error, "Usage: /unban <nickname>"} =
               Unban.execute([], @base_context)
    end

    test "no active channel returns error" do
      ctx = %{@base_context | active_channel: nil}

      assert {:error, "You are not in any channel"} =
               Unban.execute(["user"], ctx)
    end

    test "non-operator receives error" do
      ctx = %{@base_context | operator_in: []}

      assert {:error, "You must be a channel operator to unban users"} =
               Unban.execute(["user"], ctx)
    end
  end

  describe "help/0" do
    test "returns help map" do
      help = Unban.help()
      assert help.name == "unban"
      assert is_binary(help.syntax)
      assert is_binary(help.description)
      assert is_list(help.examples)
    end
  end
end
