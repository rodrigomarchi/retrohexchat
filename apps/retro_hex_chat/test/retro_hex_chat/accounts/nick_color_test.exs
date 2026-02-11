defmodule RetroHexChat.Accounts.NickColorTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Accounts.NickColor

  describe "new/1" do
    test "creates struct with valid keyword list" do
      color = NickColor.new(target_nickname: "Alice", color_index: 4)
      assert color.target_nickname == "Alice"
      assert color.color_index == 4
    end

    test "creates struct with valid map" do
      color = NickColor.new(%{target_nickname: "Bob", color_index: 12})
      assert color.target_nickname == "Bob"
      assert color.color_index == 12
    end

    test "raises when target_nickname is missing" do
      assert_raise ArgumentError, fn ->
        NickColor.new(color_index: 5)
      end
    end

    test "raises when color_index is missing" do
      assert_raise ArgumentError, fn ->
        NickColor.new(target_nickname: "Alice")
      end
    end
  end
end
