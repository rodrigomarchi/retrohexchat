defmodule RetroHexChat.Chat.HighlightWordsTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.Chat.HighlightWords

  @moduletag :unit

  describe "new/0" do
    test "returns empty entries list" do
      hw = HighlightWords.new()
      assert hw.entries == []
    end
  end

  describe "add_entry/3" do
    test "adds a word with no color" do
      hw = HighlightWords.new()
      assert {:ok, hw} = HighlightWords.add_entry(hw, "phoenix", nil)
      assert length(hw.entries) == 1
      [entry] = hw.entries
      assert entry.word == "phoenix"
      assert entry.bg_color == nil
      assert entry.position == 0
    end

    test "adds a word with color index" do
      hw = HighlightWords.new()
      assert {:ok, hw} = HighlightWords.add_entry(hw, "deploy", 4)
      [entry] = hw.entries
      assert entry.bg_color == 4
    end

    test "assigns incrementing positions" do
      hw = HighlightWords.new()
      {:ok, hw} = HighlightWords.add_entry(hw, "phoenix", nil)
      {:ok, hw} = HighlightWords.add_entry(hw, "elixir", nil)
      {:ok, hw} = HighlightWords.add_entry(hw, "deploy", nil)

      positions = Enum.map(hw.entries, & &1.position)
      assert positions == [0, 1, 2]
    end

    test "rejects empty word" do
      hw = HighlightWords.new()
      assert {:error, :invalid_word} = HighlightWords.add_entry(hw, "", nil)
      assert {:error, :invalid_word} = HighlightWords.add_entry(hw, "   ", nil)
    end

    test "rejects word longer than 50 chars" do
      hw = HighlightWords.new()
      long = String.duplicate("a", 51)
      assert {:error, :invalid_word} = HighlightWords.add_entry(hw, long, nil)
    end

    test "trims whitespace" do
      hw = HighlightWords.new()
      {:ok, hw} = HighlightWords.add_entry(hw, "  phoenix  ", nil)
      [entry] = hw.entries
      assert entry.word == "phoenix"
    end

    test "rejects duplicate word case-insensitively" do
      hw = HighlightWords.new()
      {:ok, hw} = HighlightWords.add_entry(hw, "phoenix", nil)
      assert {:error, :duplicate} = HighlightWords.add_entry(hw, "Phoenix", nil)
      assert {:error, :duplicate} = HighlightWords.add_entry(hw, "PHOENIX", nil)
    end

    test "rejects invalid color index" do
      hw = HighlightWords.new()
      assert {:error, :invalid_color} = HighlightWords.add_entry(hw, "test", -1)
      assert {:error, :invalid_color} = HighlightWords.add_entry(hw, "test", 16)
    end

    test "accepts color index 0 to 15" do
      hw = HighlightWords.new()
      assert {:ok, _} = HighlightWords.add_entry(hw, "test0", 0)
      assert {:ok, _} = HighlightWords.add_entry(hw, "test15", 15)
    end

    test "rejects when list is full (50 entries)" do
      hw =
        Enum.reduce(1..50, HighlightWords.new(), fn i, acc ->
          {:ok, hw} = HighlightWords.add_entry(acc, "word#{i}", nil)
          hw
        end)

      assert {:error, :list_full} = HighlightWords.add_entry(hw, "word51", nil)
    end
  end

  describe "remove_entry/2" do
    test "removes an existing entry" do
      hw = HighlightWords.new()
      {:ok, hw} = HighlightWords.add_entry(hw, "phoenix", nil)
      {:ok, hw} = HighlightWords.add_entry(hw, "elixir", nil)

      assert {:ok, hw} = HighlightWords.remove_entry(hw, "phoenix")
      assert length(hw.entries) == 1
      assert hd(hw.entries).word == "elixir"
    end

    test "removes case-insensitively" do
      hw = HighlightWords.new()
      {:ok, hw} = HighlightWords.add_entry(hw, "Phoenix", nil)
      assert {:ok, hw} = HighlightWords.remove_entry(hw, "phoenix")
      assert hw.entries == []
    end

    test "returns error for non-existent entry" do
      hw = HighlightWords.new()
      assert {:error, :not_found} = HighlightWords.remove_entry(hw, "nope")
    end
  end

  describe "update_entry/3" do
    test "updates color of existing entry" do
      hw = HighlightWords.new()
      {:ok, hw} = HighlightWords.add_entry(hw, "deploy", nil)
      assert {:ok, hw} = HighlightWords.update_entry(hw, "deploy", 4)
      [entry] = hw.entries
      assert entry.bg_color == 4
    end

    test "can set color to nil" do
      hw = HighlightWords.new()
      {:ok, hw} = HighlightWords.add_entry(hw, "deploy", 4)
      assert {:ok, hw} = HighlightWords.update_entry(hw, "deploy", nil)
      [entry] = hw.entries
      assert entry.bg_color == nil
    end

    test "case-insensitive word lookup" do
      hw = HighlightWords.new()
      {:ok, hw} = HighlightWords.add_entry(hw, "Deploy", nil)
      assert {:ok, hw} = HighlightWords.update_entry(hw, "deploy", 12)
      [entry] = hw.entries
      assert entry.bg_color == 12
    end

    test "returns error for non-existent entry" do
      hw = HighlightWords.new()
      assert {:error, :not_found} = HighlightWords.update_entry(hw, "nope", 4)
    end

    test "rejects invalid color on update" do
      hw = HighlightWords.new()
      {:ok, hw} = HighlightWords.add_entry(hw, "test", nil)
      assert {:error, :invalid_color} = HighlightWords.update_entry(hw, "test", 16)
    end
  end

  describe "entries/1" do
    test "returns entries sorted by position" do
      hw = HighlightWords.new()
      {:ok, hw} = HighlightWords.add_entry(hw, "charlie", nil)
      {:ok, hw} = HighlightWords.add_entry(hw, "alpha", nil)
      {:ok, hw} = HighlightWords.add_entry(hw, "bravo", nil)

      words = HighlightWords.entries(hw) |> Enum.map(& &1.word)
      assert words == ["charlie", "alpha", "bravo"]
    end
  end
end
