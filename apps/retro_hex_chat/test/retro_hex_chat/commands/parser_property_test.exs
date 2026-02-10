defmodule RetroHexChat.Commands.ParserPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  @moduletag :unit

  alias RetroHexChat.Commands.Parser

  describe "property: non-slash strings return {:message, text}" do
    property "any string not starting with '/' returns {:message, text}" do
      check all(text <- string(:printable, max_length: 200)) do
        if not String.starts_with?(text, "/") do
          assert {:message, ^text} = Parser.parse(text)
        end
      end
    end
  end

  describe "property: double-slash strings return {:message, text}" do
    property "strings starting with '//' return {:message, text}" do
      check all(rest <- string(:printable, max_length: 200)) do
        input = "//" <> rest
        assert {:message, ^input} = Parser.parse(input)
      end
    end
  end

  describe "property: single slash + alphanumeric returns {:command, _, _}" do
    property "strings starting with '/' followed by alphanumeric always return a command" do
      check all(
              cmd <- string(:alphanumeric, min_length: 1, max_length: 20),
              args <- string(:printable, max_length: 100)
            ) do
        input = "/#{cmd} #{args}"
        assert {:command, parsed_cmd, _args} = Parser.parse(input)
        assert parsed_cmd == String.downcase(cmd) |> String.trim()
      end
    end
  end

  describe "property: empty string returns {:message, ''}" do
    test "empty string returns {:message, ''}" do
      assert {:message, ""} = Parser.parse("")
    end
  end

  describe "property: command name is always lowercase" do
    property "command name is always lowercase" do
      check all(
              cmd <- string(:alphanumeric, min_length: 1, max_length: 20),
              args <-
                list_of(string(:alphanumeric, min_length: 1, max_length: 10),
                  min_length: 0,
                  max_length: 5
                )
            ) do
        input = "/#{cmd} #{Enum.join(args, " ")}"
        {:command, parsed_cmd, _} = Parser.parse(input)
        assert parsed_cmd == String.downcase(parsed_cmd)
      end
    end
  end

  describe "property: very long input doesn't crash" do
    property "very long input (up to 10000 chars) doesn't crash" do
      check all(text <- string(:printable, min_length: 1, max_length: 10_000)) do
        result = Parser.parse(text)
        assert match?({:message, _}, result) or match?({:command, _, _}, result)
      end
    end
  end

  describe "property: unicode input doesn't crash" do
    property "unicode input doesn't crash" do
      check all(text <- string(:printable, min_length: 0, max_length: 500)) do
        result = Parser.parse(text)
        assert match?({:message, _}, result) or match?({:command, _, _}, result)
      end
    end

    property "command with unicode arguments doesn't crash" do
      check all(
              cmd <- string(:alphanumeric, min_length: 1, max_length: 10),
              arg <- string(:printable, min_length: 1, max_length: 200)
            ) do
        input = "/#{cmd} #{arg}"
        result = Parser.parse(input)
        assert {:command, _, _} = result
      end
    end
  end
end
