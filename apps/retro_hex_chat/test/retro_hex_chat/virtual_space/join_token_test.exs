defmodule RetroHexChat.VirtualSpace.JoinTokenTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.VirtualSpace.JoinToken

  @moduletag :unit

  test "signs and verifies the join payload" do
    token = JoinToken.sign("space-tok", 42, "alice")

    assert {:ok, data} = JoinToken.verify(token)
    assert data.space_token == "space-tok"
    assert data.user_id == 42
    assert data.nickname == "alice"
  end

  test "rejects a tampered token" do
    token = JoinToken.sign("space-tok", 42, "alice")
    assert {:error, :invalid} = JoinToken.verify(token <> "x")
  end

  test "rejects a token signed with a different salt" do
    secret = Application.get_env(:retro_hex_chat, :p2p_token_secret)
    foreign = Phoenix.Token.sign(secret, "other_salt", %{space_token: "space-tok"})

    assert {:error, :invalid} = JoinToken.verify(foreign)
  end

  test "expires after max_age" do
    token = JoinToken.sign("space-tok", 42, "alice")

    assert {:ok, _} = JoinToken.verify(token, max_age: JoinToken.max_age())
    assert {:error, :expired} = JoinToken.verify(token, max_age: -1)
  end
end
