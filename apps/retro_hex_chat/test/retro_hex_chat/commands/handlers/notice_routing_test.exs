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
    test "returns :ok for empty input (shows current)" do
      assert :ok = NoticeRouting.validate("")
    end

    test "returns :ok for valid routing value" do
      assert :ok = NoticeRouting.validate("active")
      assert :ok = NoticeRouting.validate("status")
      assert :ok = NoticeRouting.validate("sender")
    end

    test "returns :ok for invalid input (error handled in execute)" do
      assert :ok = NoticeRouting.validate("invalid")
    end
  end

  describe "execute/2" do
    test "returns show action for empty args" do
      assert {:ok, :ui_action, :notice_routing_show, %{}} =
               NoticeRouting.execute([], @context)
    end

    test "returns set action for 'active'" do
      assert {:ok, :ui_action, :notice_routing_set, %{routing: :active}} =
               NoticeRouting.execute(["active"], @context)
    end

    test "returns set action for 'status'" do
      assert {:ok, :ui_action, :notice_routing_set, %{routing: :status}} =
               NoticeRouting.execute(["status"], @context)
    end

    test "returns set action for 'sender'" do
      assert {:ok, :ui_action, :notice_routing_set, %{routing: :sender}} =
               NoticeRouting.execute(["sender"], @context)
    end

    test "returns error for invalid routing value" do
      assert {:error, msg} = NoticeRouting.execute(["invalid"], @context)
      assert msg =~ "active"
      assert msg =~ "status"
      assert msg =~ "sender"
    end
  end

  describe "help/0" do
    test "returns correct help map" do
      help = NoticeRouting.help()
      assert help.name == "notice_routing"
      assert help.syntax =~ "/notice_routing"
      assert help.description =~ "notices"
      assert is_list(help.examples)
      assert help.examples != []
    end
  end
end
