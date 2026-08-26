defmodule RetroHexChat.Chat.RosterTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Channels.Supervisor
  alias RetroHexChat.Chat.Roster
  alias RetroHexChat.Presence.Tracker
  alias RetroHexChat.Topics

  defp unique_channel, do: "#roster-#{System.unique_integer([:positive])}"
  defp unique_nick(prefix), do: "#{prefix}#{System.unique_integer([:positive])}"

  defp start_channel(channel) do
    {:ok, pid} = Supervisor.start_child(channel)
    on_exit(fn -> if Process.alive?(pid), do: Supervisor.stop_child(pid) end)
    :ok
  end

  # Presence is tracked by the process that owns the connection. A test process
  # standing in for one has to stay alive while the roster is read, so it tracks
  # and then waits to be told it may stop.
  defp track(topic, nickname, meta) do
    test = self()

    pid =
      spawn(fn ->
        Tracker.track_user(topic, nickname, meta)
        send(test, :tracked)

        receive do
          :stop -> :ok
        end
      end)

    assert_receive :tracked, 1_000
    on_exit(fn -> send(pid, :stop) end)
    :ok
  end

  defp member(roster, nickname) do
    Enum.find(roster.members, &(&1.nickname == nickname))
  end

  describe "of/1 for a channel" do
    test "describes the members, the topic and the modes in one read" do
      channel = unique_channel()
      founder = unique_nick("founder")
      guest = unique_nick("guest")
      :ok = start_channel(channel)

      {:ok, _} = Server.join(channel, founder)
      {:ok, _} = Server.join(channel, guest)
      :ok = Server.set_topic(channel, founder, "the topic")

      roster = Roster.of({:channel, channel})

      assert roster.kind == :channel
      assert roster.label == channel
      assert roster.topic == "the topic"
      assert is_binary(roster.modes)
      assert member(roster, founder).role == :owner
      assert member(roster, guest).role == :regular
    end

    test "ranks members by role so the sections come out owner first" do
      channel = unique_channel()
      founder = unique_nick("founder")
      guest = unique_nick("guest")
      :ok = start_channel(channel)

      {:ok, _} = Server.join(channel, founder)
      {:ok, _} = Server.join(channel, guest)

      roster = Roster.of({:channel, channel})

      assert member(roster, founder).rank < member(roster, guest).rank
    end

    test "carries the away state presence knows about" do
      channel = unique_channel()
      nick = unique_nick("away")
      :ok = start_channel(channel)

      {:ok, _} = Server.join(channel, nick)
      :ok = track(Topics.channel(channel), nick, %{away: true, away_message: "back later"})

      member = member(Roster.of({:channel, channel}), nick)

      assert member.away
      assert member.away_message == "back later"
    end

    test "a member the channel knows about counts as present" do
      channel = unique_channel()
      nick = unique_nick("member")
      :ok = start_channel(channel)

      {:ok, _} = Server.join(channel, nick)

      assert member(Roster.of({:channel, channel}), nick).online
    end

    # An empty user list and a channel that is not there look the same on
    # screen; only one of them is normal, and neither may crash the render.
    test "a channel that is not running yields an empty roster rather than raising" do
      roster = Roster.of({:channel, unique_channel()})

      assert roster.kind == :channel
      assert roster.members == []
      assert roster.topic == nil
    end
  end

  describe "of/1 for a private conversation" do
    test "is the two people in it, the other one first" do
      viewer = unique_nick("viewer")
      peer = unique_nick("peer")

      roster = Roster.of({:private, viewer, peer})

      assert roster.kind == :private
      assert roster.label == peer
      assert Enum.map(roster.members, & &1.nickname) == [peer, viewer]
      assert member(roster, peer).rank < member(roster, viewer).rank
    end

    test "reads presence from the server-wide topic, not from a shared channel" do
      viewer = unique_nick("viewer")
      peer = unique_nick("peer")
      :ok = track(Topics.presence(), peer, %{away: true, away_message: "afk"})

      roster = Roster.of({:private, viewer, peer})

      assert member(roster, peer).online
      assert member(roster, peer).away
      assert member(roster, peer).away_message == "afk"
    end

    test "somebody who is not connected reads as offline rather than missing" do
      viewer = unique_nick("viewer")
      peer = unique_nick("peer")

      member = member(Roster.of({:private, viewer, peer}), peer)

      refute member.online
      refute member.away
    end

    test "a person carries no channel role and no channel mute" do
      viewer = unique_nick("viewer")
      peer = unique_nick("peer")

      roster = Roster.of({:private, viewer, peer})

      assert Enum.all?(roster.members, &(&1.role == :regular))
      refute Enum.any?(roster.members, & &1.muted)
      assert roster.topic == nil
      assert roster.modes == nil
    end
  end

  describe "put_role/2" do
    # A promoted operator that kept its old rank would draw in the operator
    # section and still sort where it used to.
    test "moves the rank with the role" do
      member = Roster.channel_member("nick", :regular)

      promoted = Roster.put_role(member, :operator)

      assert promoted.role == :operator
      assert promoted.rank == Roster.role_rank(:operator)
      assert promoted.rank < member.rank
    end
  end

  describe "channel_member/2" do
    test "builds the same shape a full read produces" do
      loaded_keys =
        {:private, "a", "b"}
        |> Roster.of()
        |> Map.fetch!(:members)
        |> hd()
        |> Map.keys()
        |> Enum.sort()

      assert "nick" |> Roster.channel_member(:voiced) |> Map.keys() |> Enum.sort() == loaded_keys
    end
  end
end
