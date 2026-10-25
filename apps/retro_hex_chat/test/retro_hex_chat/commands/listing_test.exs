defmodule RetroHexChat.Commands.ListingTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Listing

  test "says there are none when there are none" do
    assert Listing.text([], "*** None.", &"*** #{&1} ***", &to_string/1) == "*** None."
  end

  test "puts the header, counting the items, over one line per item" do
    assert Listing.text([:a, :b], "*** None.", &"*** List (#{&1}) ***", &"  #{&1}") ==
             "*** List (2) ***\n  a\n  b"
  end
end
