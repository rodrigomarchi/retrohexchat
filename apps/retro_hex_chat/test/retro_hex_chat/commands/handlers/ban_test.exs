defmodule RetroHexChat.Commands.Handlers.BanTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Handlers.Ban

  @base_context %{
    nickname: "Rodrigo",
    active_channel: "#lobby",
    channels: ["#lobby"],
    identified: false,
    operator_in: ["#lobby"]
  }

  describe "validate/1" do
    test "accepts any input" do
      assert :ok = Ban.validate("user reason")
      assert :ok = Ban.validate("")
    end
  end

  describe "execute/2" do
    test "/ban user reason returns ban_user ui_action" do
      assert {:ok, :ui_action, :ban_user,
              %{channel: "#lobby", target: "user", reason: "spamming"}} =
               Ban.execute(["user", "spamming"], @base_context)
    end

    test "/ban user with multi-word reason joins reason words" do
      assert {:ok, :ui_action, :ban_user,
              %{channel: "#lobby", target: "user", reason: "repeated spam here"}} =
               Ban.execute(["user", "repeated", "spam", "here"], @base_context)
    end

    test "/ban user with no reason uses nil reason" do
      assert {:ok, :ui_action, :ban_user, %{channel: "#lobby", target: "user", reason: nil}} =
               Ban.execute(["user"], @base_context)
    end

    test "/ban with no target returns error" do
      assert {:error, "Usage: /ban <nickname> [reason]"} =
               Ban.execute([], @base_context)
    end

    test "no active channel returns error" do
      ctx = %{@base_context | active_channel: nil}

      assert {:error, "You are not in any channel"} =
               Ban.execute(["user"], ctx)
    end

    test "non-operator receives error" do
      ctx = %{@base_context | operator_in: []}

      assert {:error, "You must be a channel operator to ban users"} =
               Ban.execute(["user"], ctx)
    end
  end

  describe "help/0" do
    test "returns help map" do
      help = Ban.help()
      assert help.name == "ban"
      assert is_binary(help.syntax)
      assert is_binary(help.description)
      assert is_list(help.examples)
    end
  end
end
