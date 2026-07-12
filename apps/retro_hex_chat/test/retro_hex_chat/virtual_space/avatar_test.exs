defmodule RetroHexChat.VirtualSpace.AvatarTest do
  use RetroHexChat.DataCase, async: false

  alias RetroHexChat.Channels.Registry, as: ChannelRegistry
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Channels.Supervisor, as: ChannelSupervisor
  alias RetroHexChat.VirtualSpace.ChannelSpaceServer
  alias RetroHexChat.VirtualSpace.Supervisor

  @moduletag :integration

  defp start_space(nickname \\ "alice") do
    channel = "#av-#{System.unique_integer([:positive])}"

    {:ok, channel_pid} = ChannelSupervisor.start_child(channel)
    {:ok, _} = Server.join(channel, nickname)
    {:ok, space_pid} = Supervisor.start_channel_child(channel)

    on_exit(fn ->
      if Process.alive?(space_pid), do: GenServer.stop(space_pid, :normal)

      case ChannelRegistry.lookup(channel) do
        {:ok, ^channel_pid} -> ChannelSupervisor.stop_child(channel_pid)
        _ -> :ok
      end
    end)

    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "space:#{channel}")

    {:ok, joined} = ChannelSpaceServer.join(channel, %{user_id: nil, nickname: nickname})

    flush_deltas()
    %{channel_name: channel, key: joined.participant.key}
  end

  defp avatar_of(channel_name, key) do
    {:ok, state} = ChannelSpaceServer.get_state(channel_name)
    state.participants[key].avatar
  end

  describe "avatar catalog" do
    test "exposes the hero, the class avatars, and the premium iso knight, in sync with the JS atlas" do
      assert ChannelSpaceServer.avatars() ==
               ~w(redtunic_hero sorceress knight archer barbarian rogue cleric monk iso_knight)
    end
  end

  describe "select_avatar" do
    test "swaps the participant's avatar and broadcasts a delta carrying it" do
      ctx = start_space()

      assert :ok = ChannelSpaceServer.select_avatar(ctx.channel_name, ctx.key, "knight")
      assert avatar_of(ctx.channel_name, ctx.key) == "knight"

      assert_receive %{event: "space_delta", payload: %{updates: updates}}
      assert updates[ctx.key].avatar == "knight"
    end

    test "rejects an unknown avatar id without mutating or broadcasting" do
      ctx = start_space()
      before = avatar_of(ctx.channel_name, ctx.key)

      assert {:error, :invalid_avatar} =
               ChannelSpaceServer.select_avatar(ctx.channel_name, ctx.key, "dragon_lord")

      assert avatar_of(ctx.channel_name, ctx.key) == before
      refute_receive %{event: "space_delta"}
    end

    test "is a no-op broadcast when picking the avatar already worn" do
      ctx = start_space()
      current = avatar_of(ctx.channel_name, ctx.key)

      assert :ok = ChannelSpaceServer.select_avatar(ctx.channel_name, ctx.key, current)
      assert avatar_of(ctx.channel_name, ctx.key) == current
      refute_receive %{event: "space_delta"}
    end

    test "rejects a non-participant key" do
      ctx = start_space()

      assert {:error, :not_participant} =
               ChannelSpaceServer.select_avatar(ctx.channel_name, "nick:ghost", "rogue")
    end
  end

  defp flush_deltas do
    receive do
      %{event: "space_delta"} -> flush_deltas()
    after
      0 -> :ok
    end
  end
end
