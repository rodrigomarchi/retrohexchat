defmodule RetroHexChat.Commands.Handlers.NoticeRoutingTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Handlers.NoticeRouting

  @context %{
    nickname: "TestUser",
    active_channel: "#lobby",
    channels: ["#lobby"],
    identified: false,
    operator_in: []
  }

  describe "validate/1" do
    test "returns :ok for any input" do
      assert :ok = NoticeRouting.validate("")
      assert :ok = NoticeRouting.validate("anything")
    end
  end

  describe "execute/2" do
    test "always returns show action" do
      assert {:ok, :ui_action, :notice_routing_show, %{}} =
               NoticeRouting.execute([], @context)
    end

    test "returns show action even with args" do
      assert {:ok, :ui_action, :notice_routing_show, %{}} =
               NoticeRouting.execute(["active"], @context)
    end
  end

  describe "help/0" do
    test "returns correct help map" do
      help = NoticeRouting.help()
      assert help.name == "notice_routing"
      assert help.syntax =~ "/notice_routing"
      assert is_list(help.examples)
    end
  end
end
