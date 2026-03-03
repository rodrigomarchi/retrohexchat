defmodule RetroHexChat.Commands.Handlers.PartTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Handlers.Part

  @base_context %{
    nickname: "Alice",
    active_channel: "#lobby",
    channels: ["#lobby", "#elixir"],
    identified: false,
    operator_in: []
  }

  describe "execute/2" do
    test "parts active channel when no args" do
      assert {:ok, :part, "#lobby", nil} = Part.execute([], @base_context)
    end

    test "parts specified channel" do
      assert {:ok, :part, "#elixir", nil} = Part.execute(["#elixir"], @base_context)
    end

    test "parts with message" do
      assert {:ok, :part, "#elixir", "Goodbye!"} =
               Part.execute(["#elixir", "Goodbye!"], @base_context)
    end

    test "parts active channel with message when first arg is not a channel" do
      assert {:ok, :part, "#lobby", "See you later"} =
               Part.execute(["See", "you", "later"], @base_context)
    end

    test "error when not in specified channel" do
      assert {:error, _} = Part.execute(["#unknown"], @base_context)
    end

    test "error when no active channel and no args" do
      ctx = %{@base_context | active_channel: nil}
      assert {:error, _} = Part.execute([], ctx)
    end
  end

  describe "validate/1" do
    test "accepts any input" do
      assert :ok = Part.validate("anything")
      assert :ok = Part.validate("")
    end
  end

  describe "execute/2 - nil active channel with non-channel args" do
    test "returns error when active_channel is nil and args don't start with #" do
      ctx = %{@base_context | active_channel: nil}
      assert {:error, "You are not in any channel"} = Part.execute(["goodbye"], ctx)
    end
  end

  describe "help/0" do
    test "returns help map" do
      help = Part.help()
      assert help.name == "part"
    end
  end
end
