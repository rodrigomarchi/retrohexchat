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
end
