defmodule RetroHexChat.VirtualSpace.RosterTest do
  @moduledoc """
  Who is inside a space, for the screens that are outside it.

  The antechamber and the chat's card ask the same question and want none of
  the movement the space's own topic carries, so the answer has a topic of its
  own. What is asserted here is that the roster topic says the same thing the
  read does, and that it says it when — and only when — the list changes.

  The two kinds of space answer "inside" differently, and that is the domain's
  answer rather than this module's: in a channel space every member of the
  channel is drawn on the map whether or not they ever opened it, so the roster
  is the channel's membership; in a private space nobody is drawn until they
  walk in.
  """
  use RetroHexChat.DataCase, async: false

  alias RetroHexChat.Channels.Registry, as: ChannelRegistry
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Channels.Supervisor, as: ChannelSupervisor
  alias RetroHexChat.Topics
  alias RetroHexChat.VirtualSpace
  alias RetroHexChat.VirtualSpace.ChannelSpaceServer
  alias RetroHexChat.VirtualSpace.DirectMessageSpace
  alias RetroHexChat.VirtualSpace.Registry
  alias RetroHexChat.VirtualSpace.Supervisor

  @moduletag :integration

  defp start_channel_space(members) do
    channel = "#roster-#{System.unique_integer([:positive])}"

    {:ok, channel_pid} = ChannelSupervisor.start_child(channel)
    Enum.each(members, fn nickname -> {:ok, _state} = Server.join(channel, nickname) end)
    {:ok, space_pid} = Supervisor.start_channel_child(channel)

    on_exit(fn ->
      if Process.alive?(space_pid), do: GenServer.stop(space_pid, :normal)

      case ChannelRegistry.lookup(channel) do
        {:ok, ^channel_pid} -> ChannelSupervisor.stop_child(channel_pid)
        _absent -> :ok
      end
    end)

    channel
  end

  defp private_participants do
    suffix = System.unique_integer([:positive])
    ["dm_ana_#{suffix}", "dm_bob_#{suffix}"]
  end

  defp start_private_space(participants) do
    [left, right] = participants
    space_id = DirectMessageSpace.space_id(left, right)

    on_exit(fn ->
      case Registry.lookup({:direct_message_space, space_id}) do
        {:ok, pid} -> GenServer.stop(pid, :normal)
        {:error, :not_found} -> :ok
      end
    end)

    space_id
  end

  describe "roster/1" do
    test "a channel space is standing room for everyone in the channel" do
      channel = start_channel_space(["ana", "bob"])

      assert VirtualSpace.roster(channel) == ["ana", "bob"]
    end

    test "a private space holds nobody until somebody walks in" do
      [ana, bob] = participants = private_participants()
      space_id = start_private_space(participants)

      {:ok, _joined} =
        VirtualSpace.join_direct_message_space(
          space_id,
          %{user_id: nil, nickname: ana},
          participants
        )

      assert VirtualSpace.roster(space_id) == [ana]
      refute bob in VirtualSpace.roster(space_id)
    end

    test "a space nobody has opened answers with nobody, not with an error" do
      assert VirtualSpace.roster("#never-opened-#{System.unique_integer([:positive])}") == []
      assert VirtualSpace.roster("dm:nobody:nowhere") == []
    end
  end

  describe "the roster topic" do
    test "carries the new list when the space gains somebody" do
      channel = start_channel_space(["ana"])
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.space_roster(channel))

      {:ok, _state} = Server.join(channel, "bob")

      assert_receive {:space_roster, %{space_id: ^channel, participants: ["ana", "bob"]}}, 1_000
    end

    test "carries none of the movement the space's own topic carries" do
      channel = start_channel_space(["ana"])
      {:ok, joined} = ChannelSpaceServer.join(channel, %{user_id: nil, nickname: "ana"})

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.space_roster(channel))
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.space(channel))

      :ok = ChannelSpaceServer.input(channel, joined.participant.key, %{seq: 1, dx: 1, dy: 0})

      # The step is on the space's topic, and the roster topic stays silent —
      # which is the whole reason it exists.
      assert_receive %{event: "space_delta"}, 1_000
      refute_receive {:space_roster, _payload}, 100
    end
  end
end
