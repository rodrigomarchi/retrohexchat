defmodule RetroHexChat.VirtualSpace.CombatTest do
  use RetroHexChat.DataCase, async: false

  alias RetroHexChat.Channels.Registry, as: ChannelRegistry
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Channels.Supervisor, as: ChannelSupervisor
  alias RetroHexChat.VirtualSpace.ChannelSpaceServer
  alias RetroHexChat.VirtualSpace.Supervisor

  @moduletag :integration

  setup do
    Application.put_env(:retro_hex_chat, :virtual_space_step_ms, 0)
    Application.put_env(:retro_hex_chat, :virtual_space_action_ms, 0)
    # Long enough that the mid-KO assertions (a 100ms refute window) finish
    # before the getup timer fires, short enough to keep the test fast.
    Application.put_env(:retro_hex_chat, :virtual_space_ko_down_ms, 600)

    on_exit(fn ->
      Application.delete_env(:retro_hex_chat, :virtual_space_step_ms)
      Application.delete_env(:retro_hex_chat, :virtual_space_action_ms)
      Application.delete_env(:retro_hex_chat, :virtual_space_ko_down_ms)
    end)

    :ok
  end

  defp start_space do
    channel = "#cb-#{System.unique_integer([:positive])}"

    {:ok, channel_pid} = ChannelSupervisor.start_child(channel)
    {:ok, _} = Server.join(channel, "alice")
    {:ok, _} = Server.join(channel, "bob")
    {:ok, space_pid} = Supervisor.start_channel_child(channel)

    on_exit(fn ->
      if Process.alive?(space_pid), do: GenServer.stop(space_pid, :normal)

      case ChannelRegistry.lookup(channel) do
        {:ok, ^channel_pid} -> ChannelSupervisor.stop_child(channel_pid)
        _ -> :ok
      end
    end)

    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "space:#{channel}")

    {:ok, alice} = ChannelSpaceServer.join(channel, %{user_id: nil, nickname: "alice"})
    {:ok, bob} = ChannelSpaceServer.join(channel, %{user_id: nil, nickname: "bob"})

    flush_space_events()

    %{
      channel_name: channel,
      alice: alice.participant.key,
      bob: bob.participant.key
    }
  end

  defp participant(channel_name, key) do
    {:ok, state} = ChannelSpaceServer.get_state(channel_name)
    state.participants[key]
  end

  # Walk `key` one cardinal step at a time until it stands adjacent
  # (8-neighbour) to `other_key`. The spawn cluster is open ground, so a
  # greedy x-then-y walk is enough.
  defp approach(ctx, key, other_key, seq \\ 100) do
    if seq > 160, do: flunk("could not walk adjacent to the target in 60 steps")

    mover = participant(ctx.channel_name, key)
    target = participant(ctx.channel_name, other_key)

    if abs(mover.x - target.x) <= 1 and abs(mover.y - target.y) <= 1 do
      :ok
    else
      {dx, dy} =
        if mover.x != target.x,
          do: {sign(target.x - mover.x), 0},
          else: {0, sign(target.y - mover.y)}

      ChannelSpaceServer.input(ctx.channel_name, key, %{seq: seq, dx: dx, dy: dy})
      approach(ctx, key, other_key, seq + 1)
    end
  end

  defp sign(n) when n > 0, do: 1
  defp sign(_), do: -1

  defp swing(ctx), do: ChannelSpaceServer.action(ctx.channel_name, ctx.alice, %{kind: "sword"})

  defp flush_space_events do
    receive do
      %{event: _} -> flush_space_events()
    after
      0 -> :ok
    end
  end

  describe "melee swings" do
    test "a swing damages the adjacent target and broadcasts the hit" do
      ctx = start_space()
      approach(ctx, ctx.alice, ctx.bob)
      flush_space_events()

      assert :ok = swing(ctx)

      bob_key = ctx.bob
      assert_receive %{event: "space_action", payload: %{kind: "sword", key: alice_key}}
      assert alice_key == ctx.alice
      assert_receive %{event: "space_action", payload: %{kind: "hit", key: ^bob_key}}
      assert_receive %{event: "space_delta", payload: %{updates: %{^bob_key => %{hp: 75}}}}

      assert participant(ctx.channel_name, ctx.bob).hp == 75
      assert participant(ctx.channel_name, ctx.bob).pose == "standing"
    end

    test "a swing with nobody adjacent hits no one" do
      ctx = start_space()
      flush_space_events()
      bob_before = participant(ctx.channel_name, ctx.bob)

      # Only swing if bob spawned out of reach; adjacent spawns are covered by
      # the other tests, so this one just documents the no-target path.
      alice = participant(ctx.channel_name, ctx.alice)

      if abs(alice.x - bob_before.x) > 1 or abs(alice.y - bob_before.y) > 1 do
        assert :ok = swing(ctx)
        bob_key = ctx.bob
        refute_receive %{event: "space_action", payload: %{kind: "hit", key: ^bob_key}}, 100
        assert participant(ctx.channel_name, ctx.bob).hp == bob_before.hp
      end
    end
  end

  describe "knockout cycle" do
    test "four hits knock the target down, block it, and it recovers on its own" do
      ctx = start_space()
      approach(ctx, ctx.alice, ctx.bob)
      flush_space_events()
      bob_key = ctx.bob

      for _ <- 1..4, do: assert(:ok = swing(ctx))

      assert_receive %{event: "space_action", payload: %{kind: "ko", key: ^bob_key}}
      downed = participant(ctx.channel_name, ctx.bob)
      assert downed.hp == 0
      assert downed.pose == "down"

      # A downed participant can't walk and can't be hit again. Drain the
      # earlier swing broadcasts so the refute below sees only the new swing.
      assert {:error, :down} =
               ChannelSpaceServer.input(ctx.channel_name, ctx.bob, %{seq: 500, dx: 1, dy: 0})

      flush_space_events()
      assert :ok = swing(ctx)
      refute_receive %{event: "space_action", payload: %{kind: "hit", key: ^bob_key}}, 100
      assert participant(ctx.channel_name, ctx.bob).hp == 0

      # Recovery: back on their feet with full HP after the down window.
      assert_receive %{event: "space_action", payload: %{kind: "getup", key: ^bob_key}}, 1_000
      recovered = participant(ctx.channel_name, ctx.bob)
      assert recovered.pose == "standing"
      assert recovered.hp == 100
    end
  end
end
