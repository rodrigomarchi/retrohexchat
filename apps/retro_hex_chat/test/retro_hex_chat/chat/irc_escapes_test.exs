defmodule RetroHexChat.Chat.IrcEscapesTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.Chat.Formatter
  alias RetroHexChat.Chat.IrcEscapes

  @bold <<0x02>>
  @colour <<0x03>>
  @reset <<0x0F>>
  @reverse <<0x16>>
  @italic <<0x1D>>
  @strikethrough <<0x1E>>
  @underline <<0x1F>>

  describe "decode/1" do
    test "decodes readable colour and style escapes to mIRC control bytes" do
      assert IrcEscapes.decode("\\c04\\bRed\\o") ==
               @colour <> "04" <> @bold <> "Red" <> @reset
    end

    test "pads one-digit colour arguments and preserves visible text" do
      decoded = IrcEscapes.decode("\\c3Green")

      assert decoded == @colour <> "03" <> "Green"
      assert Formatter.strip(decoded) == "Green"
    end

    test "decodes foreground/background colour arguments" do
      assert IrcEscapes.decode("\\c04,01Alert") == @colour <> "04,01" <> "Alert"
    end

    test "decodes all short style escapes" do
      assert IrcEscapes.decode("\\iI\\uU\\sS\\vV\\o") ==
               @italic <>
                 "I" <>
                 @underline <>
                 "U" <>
                 @strikethrough <>
                 "S" <>
                 @reverse <>
                 "V" <> @reset
    end

    test "decodes explicit hexadecimal control escapes" do
      assert IrcEscapes.decode("\\x02bold\\x0F") == @bold <> "bold" <> @reset
    end

    test "keeps unknown escapes readable" do
      assert IrcEscapes.decode("\\q no-op \\x7F") == "\\q no-op \\x7F"
    end

    test "allows literal backslashes" do
      assert IrcEscapes.decode("Use \\\\c04 to explain colour") ==
               "Use \\c04 to explain colour"
    end
  end
end
