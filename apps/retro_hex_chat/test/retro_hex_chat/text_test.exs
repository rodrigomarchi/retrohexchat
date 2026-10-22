defmodule RetroHexChat.TextTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Text

  doctest RetroHexChat.Text

  describe "truncate/3" do
    test "the result, omission included, never exceeds the limit" do
      text = String.duplicate("a", 50)

      for max <- 1..60 do
        assert String.length(Text.truncate(text, max)) <= max
      end
    end

    test "text that fits is returned unchanged" do
      assert Text.truncate("exactly ten", 11) == "exactly ten"
    end

    test "cuts by graphemes, so an accent or an emoji is never split" do
      assert Text.truncate("ação é coração", 8) == "ação ..."
      assert Text.truncate("👍🏽👍🏽👍🏽👍🏽👍🏽", 4) == "👍🏽..."
    end

    test "takes another omission" do
      assert Text.truncate("Nintendo anuncia", 10, omission: "…") == "Nintendo …"
    end

    test "a limit smaller than the omission keeps the text's own start" do
      assert Text.truncate("abcdef", 2) == "ab"
    end

    test "nil stays nil and a non-positive limit gives an empty string" do
      assert Text.truncate(nil, 10) == nil
      assert Text.truncate("abc", 0) == ""
    end
  end

  describe "blank_to_nil/1" do
    test "nil, empty and whitespace-only become nil" do
      assert Text.blank_to_nil(nil) == nil
      assert Text.blank_to_nil("") == nil
      assert Text.blank_to_nil("  \n ") == nil
    end

    test "anything else is returned unchanged" do
      assert Text.blank_to_nil(" note ") == " note "
      assert Text.blank_to_nil(42) == 42
    end
  end

  describe "word_count/1" do
    test "counts whitespace-separated words" do
      assert Text.word_count("one  two\nthree") == 3
    end

    test "nil for nil or empty text" do
      assert Text.word_count(nil) == nil
      assert Text.word_count("") == nil
    end
  end
end
