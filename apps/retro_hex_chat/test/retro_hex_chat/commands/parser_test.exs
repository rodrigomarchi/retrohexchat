defmodule RetroHexChat.Commands.ParserTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  @moduletag :unit

  alias RetroHexChat.Commands.Parser

  describe "parse/1" do
    test "parses a simple command" do
      assert {:command, "join", ["#elixir"]} = Parser.parse("/join #elixir")
    end

    test "parses command with multiple args" do
      assert {:command, "kick", ["#elixir", "troll", "spamming"]} =
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
  end

  # StreamData property tests
  describe "property tests" do
    property "commands always start with /" do
      check all(
              cmd_name <- string(:alphanumeric, min_length: 1, max_length: 10),
              args <- string(:printable, max_length: 50)
            ) do
        input = "/#{cmd_name} #{args}"
        result = Parser.parse(input)
        assert {:command, _, _} = result
      end
    end

    property "non-slash messages are always :message" do
      check all(
              msg <- string(:printable, min_length: 1, max_length: 100),
              not String.starts_with?(msg, "/") or String.starts_with?(msg, "//")
            ) do
        assert {:message, _} = Parser.parse(msg)
      end
    end
  end
end
