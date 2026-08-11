defmodule RetroHexChat.GroupCall.JoinTokenTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.GroupCall.JoinToken
  alias RetroHexChat.VirtualSpace.ChannelJoinToken

  test "binds the room, the channel and who is joining" do
    token = JoinToken.sign("room-abc", "#lobby", 42, "alice")

    assert {:ok, data} = JoinToken.verify(token)
    assert data.room_token == "room-abc"
    assert data.channel_name == "#lobby"
    assert data.user_id == 42
    assert data.nickname == "alice"
  end

  test "rejects a tampered token" do
    token = JoinToken.sign("room-abc", "#lobby", 42, "alice")

    assert {:error, :invalid} = JoinToken.verify(token <> "x")
  end

  test "expires after max_age" do
    token = JoinToken.sign("room-abc", "#lobby", 42, "alice")

    assert {:ok, _data} = JoinToken.verify(token, max_age: JoinToken.max_age())
    assert {:error, :expired} = JoinToken.verify(token, max_age: -1)
  end

  # Both kinds of join token are signed with the same secret in every
  # environment — `:group_call_join_secret` is configured nowhere, so the group
  # call falls back to the virtual space's. The salt is the only thing keeping
  # one door's token from opening the other, so it is worth saying out loud.
  test "a virtual-space token does not open the group call" do
    space_token = ChannelJoinToken.sign("#lobby", 42, "alice")

    assert {:error, :invalid} = JoinToken.verify(space_token)
  end

  test "a direct-message space token does not open the group call either" do
    dm_token = ChannelJoinToken.sign_direct_message("dm:alice:bob", 42, "alice", ["alice", "bob"])

    assert {:error, :invalid} = JoinToken.verify(dm_token)
  end
end
