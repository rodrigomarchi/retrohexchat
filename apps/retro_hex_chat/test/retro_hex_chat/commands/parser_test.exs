defmodule RetroHexChat.Commands.ParserTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Parser

  describe "parse/1" do
    test "parses a simple command" do
      assert {:command, "join", ["#elixir"]} = Parser.parse("/join #elixir")
    end

    test "parses command with multiple args" do
      assert {:command, "kick", ["#elixir", "troll spamming"]} =
               Parser.parse("/kick #elixir troll spamming")
    end

    test "parses command without args" do
      assert {:command, "list", []} = Parser.parse("/list")
    end

    test "parses plain message" do
      assert {:message, "Hello, world!"} = Parser.parse("Hello, world!")
    end

    test "treats double slash as message" do
      assert {:message, "//not a command"} = Parser.parse("//not a command")
    end

    test "lowercases command name" do
      assert {:command, "join", ["#Elixir"]} = Parser.parse("/JOIN #Elixir")
    end

    test "handles empty string as empty message" do
      assert {:message, ""} = Parser.parse("")
    end

    test "preserves argument case" do
      assert {:command, "nick", ["RodrigoNew"]} = Parser.parse("/nick RodrigoNew")
    end

    test "handles extra whitespace in args" do
      assert {:command, "join", ["#elixir"]} = Parser.parse("/join   #elixir")
    end

    test "handles leading whitespace before commands" do
      assert {:command, "help", []} = Parser.parse("   /HELP   ")
    end

    test "bare slash is parsed as an empty command instead of crashing" do
      assert {:command, "", []} = Parser.parse("/")
      assert {:command, "", []} = Parser.parse("/   ")
    end

    test "preserves repeated spaces in free-text command arguments" do
      assert {:command, "me", ["waves  with   spacing"]} =
               Parser.parse("/me waves  with   spacing")

      assert {:command, "msg", ["Nick", "hello  unicode áé  \x02bold\x02"]} =
               Parser.parse("/msg Nick hello  unicode áé  \x02bold\x02")
    end
  end
end
