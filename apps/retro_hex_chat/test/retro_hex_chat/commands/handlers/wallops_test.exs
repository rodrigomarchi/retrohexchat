defmodule RetroHexChat.Commands.Handlers.WallopsTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Handlers.Wallops

  @base_context %{
    nickname: "ServerOp",
    active_channel: nil,
    channels: [],
    identified: false,
    operator_in: [],
    half_operator_in: [],
    is_admin: false,
    is_server_operator: true
  }

  describe "validate/1" do
    test "accepts any input" do
      assert :ok = Wallops.validate("Important message")
      assert :ok = Wallops.validate("")
    end
  end

  describe "execute/2" do
    test "non-operator and non-admin rejected" do
      ctx = %{@base_context | is_admin: false, is_server_operator: false}

      assert {:error, "Permission denied: you must be a server operator."} =
               Wallops.execute(["Message"], ctx)
    end

    test "empty args returns usage error" do
      assert {:error, "Usage: /wallops <message>"} =
               Wallops.execute([], @base_context)
    end

    test "server operator can send wallops" do
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "server:wallops")

      assert {:ok, :system, %{content: "Wallops sent."}} =
               Wallops.execute(["Server", "maintenance", "soon"], @base_context)

      assert_receive {:wallops, %{sender: "ServerOp", content: "Server maintenance soon"}}
    end

    test "admin can also send wallops" do
      ctx = %{@base_context | is_admin: true, is_server_operator: false}

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "server:wallops")

      assert {:ok, :system, %{content: "Wallops sent."}} =
               Wallops.execute(["Admin", "message"], ctx)

      assert_receive {:wallops, %{sender: "ServerOp", content: "Admin message"}}
    end

    test "broadcasts {:wallops, ...} to server:wallops" do
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "server:wallops")

      Wallops.execute(["Test", "wallops"], @base_context)

      assert_receive {:wallops,
                      %{sender: "ServerOp", content: "Test wallops", timestamp: %DateTime{}}}
    end
  end

  describe "help/0" do
    test "returns help map" do
      help = Wallops.help()
      assert help.name == "wallops"
      assert is_binary(help.syntax)
      assert is_binary(help.description)
      assert is_list(help.examples)
    end
  end
end
