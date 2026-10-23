defmodule RetroHexChatWeb.ParamsTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChatWeb.Params

  test "integer/2 reads one whole number, given as a number or as text" do
    assert Params.integer(7) == 7
    assert Params.integer(" 42 ") == 42
    assert Params.integer("-3") == -3
  end

  test "anything else is the default" do
    assert Params.integer("pending_3") == nil
    assert Params.integer("12abc", 0) == 0
    assert Params.integer(nil, 0) == 0
    assert Params.integer(%{}) == nil
  end

  test "truthy?/1 says yes only for the ways a form or JSON says yes" do
    for yes <- [true, "true", "on", "1", 1], do: assert(Params.truthy?(yes))
    for no <- [false, "false", "off", nil, "yes", 2], do: refute(Params.truthy?(no))
  end

  test "boolean/2 reads yes and no, and the default for anything else" do
    assert Params.boolean("on", false) == true
    assert Params.boolean("0", true) == false
    assert Params.boolean("maybe", :keep) == :keep
  end

  test "value/2 reads a field under its atom or its string key" do
    assert Params.value(%{audio: true}, :audio) == true
    assert Params.value(%{"audio" => false}, :audio) == false
    assert Params.value(%{}, :audio) == nil
    assert Params.value(nil, :audio) == nil
    assert Params.value(%{"reason" => "ice"}, "reason") == "ice"
  end
end
