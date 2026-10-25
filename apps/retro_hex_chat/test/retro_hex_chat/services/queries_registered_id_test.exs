defmodule RetroHexChat.Services.QueriesRegisteredIdTest do
  use RetroHexChat.DataCase, async: true

  @moduletag :integration

  alias RetroHexChat.Services.Queries

  test "a registered nickname's id is registered, and names that nickname" do
    {:ok, nick} =
      Queries.insert_registered_nick(
        "RegId#{rem(System.unique_integer([:positive]), 100_000)}",
        "pass123"
      )

    assert Queries.registered_id?(nick.id)
    assert Queries.get_nickname_by_id(nick.id) == nick.nickname
  end

  test "an id nobody holds, or none at all, is not" do
    refute Queries.registered_id?(-1)
    refute Queries.registered_id?(nil)
    assert Queries.get_nickname_by_id(nil) == nil
  end
end
