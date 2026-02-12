defmodule RetroHexChat.Commands.Handlers.NoticeTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Handlers.Notice

  @context %{
    nickname: "TestUser",
    active_channel: "#lobby",
    channels: ["#lobby"],
    identified: false,
    operator_in: []
  }

  describe "validate/1" do
    test "returns error for empty input" do
      assert {:error, msg} = Notice.validate("")
      assert msg =~ "/notice"
    end

    test "returns :ok for valid input" do
      assert :ok = Notice.validate("Alice hello")
    end

    test "returns :ok for channel target" do
      assert :ok = Notice.validate("#elixir Server maintenance")
    end
  end

  describe "execute/2" do
    test "returns error for empty args" do
      assert {:error, _msg} = Notice.execute([], @context)
    end

    test "returns error for target only (no message)" do
      assert {:error, msg} = Notice.execute(["Alice"], @context)
      assert msg =~ "message"
    end

    test "returns :notice result for user target with message" do
      assert {:ok, :notice, %{target: "Alice", content: "hello world"}} =
               Notice.execute(["Alice", "hello", "world"], @context)
    end

    test "returns :notice result for channel target" do
      assert {:ok, :notice, %{target: "#elixir", content: "Server maintenance"}} =
               Notice.execute(["#elixir", "Server", "maintenance"], @context)
    end

    test "preserves single-word message" do
      assert {:ok, :notice, %{target: "Alice", content: "hi"}} =
               Notice.execute(["Alice", "hi"], @context)
    end
  end

  describe "help/0" do
    test "returns correct help map" do
      help = Notice.help()
      assert help.name == "notice"
      assert help.syntax =~ "/notice"
      assert help.description =~ "notice"
      assert is_list(help.examples)
      assert length(help.examples) > 0
    end
  end
end
