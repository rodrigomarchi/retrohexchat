defmodule RetroHexChat.Commands.Handlers.KickTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Handlers.Kick

  @base_context %{
    nickname: "Alice",
    active_channel: "#lobby",
    channels: ["#lobby"],
    identified: false,
    operator_in: ["#lobby"]
  }

  describe "validate/1" do
    test "accepts any input" do
      assert :ok = Kick.validate("user reason")
      assert :ok = Kick.validate("")
    end
  end

  describe "execute/2" do
    test "/kick user reason returns kick_user ui_action" do
      assert {:ok, :ui_action, :kick_user,
              %{channel: "#lobby", target: "user", reason: "misbehaving"}} =
               Kick.execute(["user", "misbehaving"], @base_context)
    end

    test "/kick user with multi-word reason joins reason words" do
      assert {:ok, :ui_action, :kick_user,
              %{channel: "#lobby", target: "user", reason: "bad behavior here"}} =
               Kick.execute(["user", "bad", "behavior", "here"], @base_context)
    end

    test "/kick user with no reason uses nil reason" do
      assert {:ok, :ui_action, :kick_user, %{channel: "#lobby", target: "user", reason: nil}} =
               Kick.execute(["user"], @base_context)
    end

    test "/kick with no target returns error" do
      assert {:error, "Usage: /kick <nickname> [reason]"} =
               Kick.execute([], @base_context)
    end

    test "no active channel returns error" do
      ctx = %{@base_context | active_channel: nil}

      assert {:error, "You are not in any channel"} =
               Kick.execute(["user"], ctx)
    end

    test "non-operator receives error" do
      ctx = %{@base_context | operator_in: []}

      assert {:error, "You must be a channel operator to kick users"} =
               Kick.execute(["user"], ctx)
    end
  end

  describe "help/0" do
    test "returns help map" do
      help = Kick.help()
      assert help.name == "kick"
      assert is_binary(help.syntax)
      assert is_binary(help.description)
      assert is_list(help.examples)
    end
  end
end
