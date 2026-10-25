defmodule RetroHexChat.MapKeyTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.MapKey

  test "reads an atom key, else its string spelling" do
    assert MapKey.get(%{reason: "x"}, :reason) == "x"
    assert MapKey.get(%{"reason" => "y"}, :reason) == "y"
    assert MapKey.get(%{"reason" => "y"}, "reason") == "y"
  end

  test "an atom key present wins even with false or nil" do
    assert MapKey.get(%{"touch" => true, touch: false}, :touch) == false
    assert MapKey.get(%{"os" => "linux", os: nil}, :os) == nil
  end

  test "anything that is not a map has no fields" do
    assert MapKey.get(nil, :reason) == nil
    assert MapKey.get("text", :reason) == nil
  end
end
