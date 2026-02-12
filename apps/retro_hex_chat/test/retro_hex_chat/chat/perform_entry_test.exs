defmodule RetroHexChat.Chat.PerformEntryTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Chat.PerformEntry

  describe "new/1" do
    test "creates entry from keyword list" do
      entry = PerformEntry.new(command: "/join #elixir", position: 0)
      assert entry.command == "/join #elixir"
      assert entry.position == 0
    end

    test "creates entry from map" do
      entry = PerformEntry.new(%{command: "/ns identify pass", position: 1})
      assert entry.command == "/ns identify pass"
      assert entry.position == 1
    end

    test "position defaults to 0" do
      entry = PerformEntry.new(command: "/join #lobby")
      assert entry.position == 0
    end

    test "raises on missing command" do
      assert_raise ArgumentError, fn ->
        PerformEntry.new(position: 0)
      end
    end
  end
end
