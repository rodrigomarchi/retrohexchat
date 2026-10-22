defmodule RetroHexChat.Channels.NameTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Channels.Name

  describe "check/1" do
    test "accepts an ordinary name, accents included" do
      assert Name.check("#retro") == :ok
      assert Name.check("#café") == :ok
    end

    test "names each problem" do
      assert Name.check("retro") == {:error, :no_prefix}
      assert Name.check("#") == {:error, :empty}
      assert Name.check("#a b") == {:error, :whitespace}
      assert Name.check("#a\tb") == {:error, :whitespace}
      assert Name.check(nil) == {:error, :no_prefix}
    end

    test "the limit counts characters, up to the stored width" do
      assert Name.check("#" <> String.duplicate("é", Name.max_length() - 1)) == :ok
      assert Name.check("#" <> String.duplicate("a", Name.max_length())) == {:error, :too_long}
    end
  end

  test "ensure_prefix/1 adds the # only when it is missing" do
    assert Name.ensure_prefix("retro") == "#retro"
    assert Name.ensure_prefix("#retro") == "#retro"
  end
end
