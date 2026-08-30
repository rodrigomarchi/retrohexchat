defmodule RetroHexChat.Lobby.JoinTokenTest do
  @moduledoc """
  The token a browser joins the P2P signaling channel with.

  The salt is the point: a token minted at one door is not currency at another,
  and that is the only thing standing between three signed-token doors and one.
  """
  use ExUnit.Case, async: true

  alias RetroHexChat.GroupCall.JoinToken, as: GroupCallToken
  alias RetroHexChat.Lobby.JoinToken
  alias RetroHexChat.VirtualSpace.ChannelJoinToken

  @moduletag :unit

  test "binds one session to one person" do
    token = JoinToken.sign("session-abc", 42, "ana")

    assert {:ok, data} = JoinToken.verify(token)
    assert data.session_token == "session-abc"
    assert data.user_id == 42
    assert data.nickname == "ana"
  end

  test "a token minted at another door does not open this one" do
    for foreign <- [
          GroupCallToken.sign("session-abc", "#retro", 42, "ana"),
          ChannelJoinToken.sign("#retro", 42, "ana")
        ] do
      assert {:error, :invalid} = JoinToken.verify(foreign)
    end
  end

  test "a token this one minted does not open another door" do
    token = JoinToken.sign("session-abc", 42, "ana")

    assert {:error, :invalid} = GroupCallToken.verify(token)
    assert {:error, :invalid} = ChannelJoinToken.verify(token)
  end

  test "garbage is refused rather than trusted" do
    assert {:error, :invalid} = JoinToken.verify("not-a-token")
  end

  # A call outliving a socket reconnect has to be able to rejoin its own
  # channel, so the window is a working day rather than an hour — and the
  # session's own policy is what actually decides who may signal.
  test "expires, and the window is long enough for a call to outlive a reconnect" do
    token = JoinToken.sign("session-abc", 42, "ana")

    assert JoinToken.max_age() == 12 * 60 * 60
    assert {:error, :expired} = JoinToken.verify(token, max_age: -1)
  end
end
