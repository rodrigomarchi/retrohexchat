defmodule RetroHexChat.Chat.AutoJoinEntryTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Chat.AutoJoinEntry

  describe "new/1" do
    test "creates entry from keyword list" do
      entry = AutoJoinEntry.new(channel_name: "#elixir", position: 0)
      assert entry.channel_name == "#elixir"
      assert entry.channel_key == nil
      assert entry.position == 0
    end

    test "creates entry with channel key" do
      entry = AutoJoinEntry.new(channel_name: "#secret", channel_key: "mykey", position: 1)
      assert entry.channel_name == "#secret"
      assert entry.channel_key == "mykey"
      assert entry.position == 1
    end

    test "creates entry from map" do
      entry = AutoJoinEntry.new(%{channel_name: "#phoenix", position: 2})
      assert entry.channel_name == "#phoenix"
      assert entry.position == 2
    end

    test "position defaults to 0" do
      entry = AutoJoinEntry.new(channel_name: "#lobby")
      assert entry.position == 0
    end

    test "raises on missing channel_name" do
      assert_raise ArgumentError, fn ->
        AutoJoinEntry.new(position: 0)
      end
    end
  end
end
