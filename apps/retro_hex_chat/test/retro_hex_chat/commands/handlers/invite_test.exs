defmodule RetroHexChat.Commands.Handlers.InviteTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Handlers.Invite

  @base_context %{
    nickname: "Rodrigo",
    active_channel: "#private",
    channels: ["#private"],
    identified: false,
    operator_in: ["#private"]
  }

  describe "validate/1" do
    test "accepts any input" do
      assert :ok = Invite.validate("Alice #private")
      assert :ok = Invite.validate("")
    end
  end

  describe "execute/2" do
    test "/invite with no args returns usage error" do
      assert {:error, "Usage: /invite <nickname> [#channel]"} =
               Invite.execute([], @base_context)
    end

    test "/invite auto returns toggle_auto_join_on_invite ui_action" do
      assert {:ok, :ui_action, :toggle_auto_join_on_invite, %{}} =
               Invite.execute(["auto"], @base_context)
    end

    test "/invite nickname returns send_invite ui_action with active channel" do
      assert {:ok, :ui_action, :send_invite, %{target: "Alice", channel: "#private"}} =
               Invite.execute(["Alice"], @base_context)
    end

    test "/invite nickname #channel returns send_invite ui_action with specified channel" do
      assert {:ok, :ui_action, :send_invite, %{target: "Alice", channel: "#secret"}} =
               Invite.execute(["Alice", "#secret"], @base_context)
    end

    test "/invite nickname with no active channel returns error" do
      ctx = %{@base_context | active_channel: nil}

      assert {:error, "You are not in any channel"} =
               Invite.execute(["Alice"], ctx)
    end

    test "/invite auto works regardless of active channel" do
      ctx = %{@base_context | active_channel: nil}

      assert {:ok, :ui_action, :toggle_auto_join_on_invite, %{}} =
               Invite.execute(["auto"], ctx)
    end
  end

  describe "help/0" do
    test "returns help map" do
      help = Invite.help()
      assert help.name == "invite"
      assert is_binary(help.syntax)
      assert is_binary(help.description)
      assert is_list(help.examples)
    end

    test "examples include all usage patterns" do
      help = Invite.help()
      assert "/invite Alice" in help.examples
      assert "/invite Alice #private" in help.examples
      assert "/invite auto" in help.examples
    end
  end
end
