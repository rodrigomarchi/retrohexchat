defmodule RetroHexChat.VirtualSpace.ChannelJoinTokenTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.GroupCall.JoinToken
  alias RetroHexChat.VirtualSpace.ChannelJoinToken

  @moduletag :unit

  test "signs and verifies the channel join payload" do
    token = ChannelJoinToken.sign("#lobby", 42, "alice")

    assert {:ok, data} = ChannelJoinToken.verify(token)
    assert data.space_kind == "channel"
    assert data.channel_name == "#lobby"
    assert data.user_id == 42
    assert data.nickname == "alice"
  end

  test "signs and verifies a direct-message join payload" do
    token = ChannelJoinToken.sign_direct_message("dm:alice:bob", 42, "alice", ["alice", "bob"])

    assert {:ok, data} = ChannelJoinToken.verify(token)
    assert data.space_kind == "direct_message"
    assert data.space_id == "dm:alice:bob"
    assert data.user_id == 42
    assert data.nickname == "alice"
    assert data.participants == ["alice", "bob"]
  end

  test "rejects a tampered token" do
    token = ChannelJoinToken.sign("#lobby", 42, "alice")
    assert {:error, :invalid} = ChannelJoinToken.verify(token <> "x")
  end

  test "rejects a token signed with a different salt" do
    secret = Application.get_env(:retro_hex_chat, :channel_space_join_secret)
    foreign = Phoenix.Token.sign(secret, "other_salt", %{channel_name: "#lobby"})

    assert {:error, :invalid} = ChannelJoinToken.verify(foreign)
  end

  test "expires after max_age" do
    token = ChannelJoinToken.sign("#lobby", 42, "alice")

    assert {:ok, _} = ChannelJoinToken.verify(token, max_age: ChannelJoinToken.max_age())
    assert {:error, :expired} = ChannelJoinToken.verify(token, max_age: -1)
  end

  # `:group_call_join_secret` is configured nowhere, so a group-call token is
  # signed with this module's secret. The salt is what keeps the two doors
  # apart, and the check runs in both directions.
  test "a group-call token does not open a virtual space" do
    call_token = JoinToken.sign("room-abc", "#lobby", 42, "alice")

    assert {:error, :invalid} = ChannelJoinToken.verify(call_token)
  end
end
