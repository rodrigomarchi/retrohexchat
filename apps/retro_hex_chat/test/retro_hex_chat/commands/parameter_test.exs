defmodule RetroHexChat.Commands.ParameterTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.CommandSyntax.Parameter
  alias RetroHexChat.Commands.Handlers.{Ignore, Query}

  test "a parameter is required or optional, and takes its position from the list" do
    assert [
             %Parameter{name: "nickname", required: true, type: :nick, position: 0},
             %Parameter{
               name: "reason",
               required: false,
               type: :text,
               position: 1,
               description: "why"
             }
           ] =
             Parameter.positioned([
               Parameter.required(:nick, "nickname"),
               Parameter.optional(:text, "reason", "why")
             ])
  end

  test "a command declared with usage: refuses being typed bare, and accepts anything else" do
    assert {:error, "Usage: /query <nickname>"} = Query.validate("")
    assert :ok = Query.validate("alice")
  end

  test "a command without usage: accepts anything" do
    assert :ok = Ignore.validate("")
  end
end
