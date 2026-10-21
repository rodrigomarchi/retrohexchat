defmodule RetroHexChat.Channels.CategoriesTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Channels.Categories

  test "every category names itself and has a label" do
    for code <- Categories.codes() do
      assert Categories.normalize(code) == code
      assert is_binary(Categories.label(code))
    end
  end

  test "a name is read in any case, and anything else is nil" do
    assert Categories.normalize(" News ") == "news"
    assert Categories.normalize("cooking") == nil
    assert Categories.normalize(nil) == nil
    assert Categories.label("cooking") == nil
  end
end
