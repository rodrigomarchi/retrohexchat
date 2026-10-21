defmodule RetroHexChatWeb.IconsCategoriesTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Channels.Categories
  alias RetroHexChatWeb.Icons.Registry

  # A category a founder can pick but nobody drew would never show a plaque.
  test "every category has its plaque, and every plaque is a category" do
    for code <- Categories.codes(), do: assert(Registry.category(code), code)

    drawn =
      for {name, _module} <- Registry.all(),
          "icon_category_" <> code <- [Atom.to_string(name)],
          do: code

    assert Enum.sort(drawn) == Enum.sort(Categories.codes())
  end
end
