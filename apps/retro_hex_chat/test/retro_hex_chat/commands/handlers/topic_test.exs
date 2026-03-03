defmodule RetroHexChat.Commands.Handlers.TopicTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Handlers.Topic

  @base_context %{
    nickname: "Alice",
    active_channel: "#lobby",
    channels: ["#lobby"],
    identified: false,
    operator_in: []
  }

  describe "validate/1" do
    test "accepts non-empty args" do
      assert :ok = Topic.validate("New topic here")
    end

    test "accepts empty args (view topic)" do
      assert :ok = Topic.validate("")
    end
  end

  describe "execute/2" do
    test "sets topic when args provided" do
      assert {:ok, :ui_action, :set_topic, %{channel: "#lobby", topic: "New topic"}} =
               Topic.execute(["New", "topic"], @base_context)
    end

    test "views topic when no args provided" do
      assert {:ok, :ui_action, :view_topic, %{channel: "#lobby"}} =
               Topic.execute([], @base_context)
    end

    test "errors when not in any channel with args" do
      ctx = %{@base_context | active_channel: nil}
      assert {:error, _} = Topic.execute(["New", "topic"], ctx)
    end

    test "errors when not in any channel without args" do
      ctx = %{@base_context | active_channel: nil}
      assert {:error, _} = Topic.execute([], ctx)
    end
  end

  describe "help/0" do
    test "returns help map" do
      help = Topic.help()
      assert help.name == "topic"
      assert is_binary(help.syntax)
      assert is_binary(help.description)
      assert is_list(help.examples)
    end
  end
end
