defmodule RetroHexChat.Commands.Handlers.MsgTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Handlers.Msg

  @base_context %{
    nickname: "Rodrigo",
    active_channel: "#lobby",
    channels: ["#lobby"],
    identified: false,
    operator_in: []
  }

  describe "validate/1" do
    test "accepts non-empty args" do
      assert :ok = Msg.validate("Nick Hello")
    end

    test "rejects empty args" do
      assert {:error, _} = Msg.validate("")
    end
  end

  describe "execute/2" do
    test "sends a PM with target and content" do
      assert {:ok, :message, %{target: "Nick", content: "Hello"}} =
               Msg.execute(["Nick", "Hello"], @base_context)
    end

    test "sends a PM with multi-word content" do
      assert {:ok, :message, %{target: "Nick", content: "Hello world!"}} =
               Msg.execute(["Nick", "Hello", "world!"], @base_context)
    end

    test "returns error when no args" do
      assert {:error, _} = Msg.execute([], @base_context)
    end

    test "returns error when no content" do
      assert {:error, _} = Msg.execute(["Nick"], @base_context)
    end
  end

  describe "help/0" do
    test "returns help map" do
      help = Msg.help()
      assert help.name == "msg"
      assert is_binary(help.syntax)
    end
  end
end
