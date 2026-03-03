defmodule RetroHexChat.Chat.HighlightTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.Chat.Highlight
  alias RetroHexChat.Chat.HighlightWord

  describe "check/4 own-nick matching" do
    @tag :unit
    test "highlights when own nick is present as a whole word" do
      assert {:highlight, nil} =
               Highlight.check("hey Bob, check this out", "Bob", [], "Alice")
    end

    @tag :unit
    test "case-insensitive matching" do
      assert {:highlight, nil} =
               Highlight.check("hey BOB", "Bob", [], "Alice")

      assert {:highlight, nil} =
               Highlight.check("hey bob", "Bob", [], "Alice")
    end

    @tag :unit
    test "does not match partial words" do
      assert :no_highlight = Highlight.check("Bo is great", "Bob", [], "Alice")
      assert :no_highlight = Highlight.check("Bobs house", "Bob", [], "Alice")
    end

    @tag :unit
    test "does not self-highlight" do
      assert :no_highlight =
               Highlight.check("I said Bob", "Bob", [], "Bob")
    end

    @tag :unit
    test "does not highlight when nick not present" do
      assert :no_highlight = Highlight.check("hello world", "Bob", [], "Alice")
    end

    @tag :unit
    test "does not highlight empty content" do
      assert :no_highlight = Highlight.check("", "Bob", [], "Alice")
    end

    @tag :unit
    test "matches nick adjacent to punctuation" do
      assert {:highlight, nil} =
               Highlight.check("hey Bob!", "Bob", [], "Alice")

      assert {:highlight, nil} =
               Highlight.check("Bob: check this", "Bob", [], "Alice")

      assert {:highlight, nil} =
               Highlight.check("(Bob)", "Bob", [], "Alice")

      assert {:highlight, nil} =
               Highlight.check("hey, Bob, hello", "Bob", [], "Alice")
    end

    @tag :unit
    test "matches nick at start and end of content" do
      assert {:highlight, nil} =
               Highlight.check("Bob", "Bob", [], "Alice")

      assert {:highlight, nil} =
               Highlight.check("hello Bob", "Bob", [], "Alice")
    end
  end

  describe "check/4 URL exclusion" do
    @tag :unit
    test "does not highlight nick inside HTTP URL" do
      assert :no_highlight =
               Highlight.check(
                 "see https://example.com/Bob/profile",
                 "Bob",
                 [],
                 "Alice"
               )
    end

    @tag :unit
    test "does not highlight nick inside HTTPS URL" do
      assert :no_highlight =
               Highlight.check(
                 "check http://bob.dev/page",
                 "Bob",
                 [],
                 "Alice"
               )
    end

    @tag :unit
    test "highlights nick outside URL even if URL also contains it" do
      assert {:highlight, nil} =
               Highlight.check(
                 "Bob see https://example.com/Bob",
                 "Bob",
                 [],
                 "Alice"
               )
    end
  end

  describe "check/4 formatting code stripping" do
    @tag :unit
    test "matches nick through bold formatting codes" do
      # \x02 = bold toggle
      content = "\x02Bob\x02 check this"

      assert {:highlight, nil} =
               Highlight.check(content, "Bob", [], "Alice")
    end

    @tag :unit
    test "matches nick through color formatting codes" do
      # \x03 followed by color number
      content = "\x034Bob\x03 is here"

      assert {:highlight, nil} =
               Highlight.check(content, "Bob", [], "Alice")
    end
  end

  describe "check/4 custom highlight words" do
    @tag :unit
    test "matches a custom word" do
      words = [HighlightWord.new(word: "phoenix", bg_color: nil, position: 0)]

      assert {:highlight, nil} =
               Highlight.check("I love phoenix framework", "Bob", words, "Alice")
    end

    @tag :unit
    test "uses custom color when set" do
      words = [HighlightWord.new(word: "deploy", bg_color: 4, position: 0)]

      assert {:highlight, color} =
               Highlight.check("we need to deploy now", "Bob", words, "Alice")

      assert color == 4
    end

    @tag :unit
    test "own nick takes priority over custom words" do
      words = [HighlightWord.new(word: "Bob", bg_color: 4, position: 0)]

      assert {:highlight, nil} =
               Highlight.check("hey Bob", "Bob", words, "Alice")
    end

    @tag :unit
    test "first custom word in list order wins when multiple match" do
      words = [
        HighlightWord.new(word: "phoenix", bg_color: 12, position: 0),
        HighlightWord.new(word: "elixir", bg_color: 4, position: 1)
      ]

      {:highlight, color} =
        Highlight.check("phoenix and elixir rock", "Bob", words, "Alice")

      # Should use first match (phoenix, color 12 = blue)
      assert color == 12
    end

    @tag :unit
    test "custom word uses whole-word matching" do
      words = [HighlightWord.new(word: "go", bg_color: nil, position: 0)]

      assert {:highlight, _} =
               Highlight.check("let's go!", "Bob", words, "Alice")

      assert :no_highlight =
               Highlight.check("going forward", "Bob", words, "Alice")
    end

    @tag :unit
    test "custom word matching is case-insensitive" do
      words = [HighlightWord.new(word: "deploy", bg_color: nil, position: 0)]

      assert {:highlight, _} =
               Highlight.check("DEPLOY NOW", "Bob", words, "Alice")
    end

    @tag :unit
    test "no highlight when custom words list is empty and nick not present" do
      assert :no_highlight = Highlight.check("hello world", "Bob", [], "Alice")
    end
  end

  describe "check/4 with special regex characters in nick" do
    @tag :unit
    test "escapes regex metacharacters in nick" do
      assert {:highlight, nil} =
               Highlight.check("hey Nick[away]!", "Nick[away]", [], "Alice")
    end

    @tag :unit
    test "escapes regex metacharacters in custom words" do
      words = [HighlightWord.new(word: "C++", bg_color: nil, position: 0)]

      assert {:highlight, _} =
               Highlight.check("I love C++!", "Bob", words, "Alice")
    end
  end
end
