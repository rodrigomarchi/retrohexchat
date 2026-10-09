defmodule RetroHexChat.Channels.NicknameCaseTest do
  @moduledoc "A channel names each member once, whatever case anyone types their nickname in."

  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Channels.{Server, Supervisor}

  defp channel_with(members) do
    channel = "#case-#{System.unique_integer([:positive])}"
    {:ok, pid} = Supervisor.start_child(channel)
    on_exit(fn -> if Process.alive?(pid), do: Supervisor.stop_child(pid) end)
    for nick <- members, do: {:ok, _} = Server.join(channel, nick)
    channel
  end

  test "a case variant of a member cannot join beside them" do
    channel = channel_with(["Owner", "AlIcE"])

    assert {:error, _already_in} = Server.join(channel, "alice")
    {:ok, state} = Server.get_state(channel)
    assert state.member_count == 2
  end

  test "/op alice finds AlIcE, and the channel shows her spelling" do
    channel = channel_with(["Owner", "AlIcE"])

    assert :ok = Server.set_mode(channel, "owner", "+o", ["alice"])

    {:ok, state} = Server.get_state(channel)
    assert {"AlIcE", :operator} in state.members
  end

  test "a role change is announced under the member's own spelling" do
    channel = channel_with(["Owner", "AlIcE"])
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, RetroHexChat.Topics.channel(channel))

    assert :ok = Server.set_mode(channel, "owner", "+v", ["ALICE"])

    assert_receive {:mode_changed, %{mode_string: "+v", params: ["AlIcE"]}}
  end

  test "a kick typed in another case removes the member and names them as they spell it" do
    channel = channel_with(["Owner", "AlIcE"])
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, RetroHexChat.Topics.channel(channel))

    assert :ok = Server.kick(channel, "OWNER", "alice", "bye")

    assert_receive {:user_kicked, %{target: "AlIcE"}}
    {:ok, state} = Server.get_state(channel)
    refute Enum.any?(state.members, fn {nick, _} -> nick == "AlIcE" end)
  end

  test "a ban on one case keeps every case out, and unban in any case lifts it" do
    channel = channel_with(["Owner", "AlIcE"])

    assert :ok = Server.ban(channel, "owner", "alice")
    assert {:error, _banned} = Server.join(channel, "ALICE")

    assert :ok = Server.unban(channel, "owner", "ALICE")
    assert {:ok, _} = Server.join(channel, "alice")
  end

  test "a mute on one case silences every case" do
    channel = channel_with(["Owner", "AlIcE"])

    assert :ok = Server.channel_mute(channel, "owner", "alice")
    assert {:error, _muted} = Server.send_message(channel, "ALICE", "still here?")
  end
end
