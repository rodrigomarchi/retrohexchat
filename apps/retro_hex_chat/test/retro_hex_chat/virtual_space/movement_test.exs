defmodule RetroHexChat.VirtualSpace.MovementTest do
  use RetroHexChat.DataCase, async: false

  alias RetroHexChat.Channels.Registry, as: ChannelRegistry
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Channels.Supervisor, as: ChannelSupervisor
  alias RetroHexChat.VirtualSpace.ChannelSpaceServer
  alias RetroHexChat.VirtualSpace.Supervisor

  @moduletag :integration

  setup do
    # No cooldown by default; the cooldown test overrides this.
    Application.put_env(:retro_hex_chat, :virtual_space_step_ms, 0)
    on_exit(fn -> Application.delete_env(:retro_hex_chat, :virtual_space_step_ms) end)
    :ok
  end

  defp start_space(nickname \\ "alice") do
    channel = "#mv-#{System.unique_integer([:positive])}"

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

    # Drop any presence delta so tests assert on movement deltas.
    flush_deltas()
    %{channel_name: channel, key: joined.participant.key, spawn: joined.participant}
  end

  defp pos(channel_name, key) do
    {:ok, state} = ChannelSpaceServer.get_state(channel_name)
    p = state.participants[key]
    {p.x, p.y, p.dir}
  end

  describe "valid movement" do
    test "an adjacent cardinal step moves the participant and broadcasts a delta with seq_ack" do
      ctx = start_space()
      {x0, y0, _} = pos(ctx.channel_name, ctx.key)

      assert :ok = ChannelSpaceServer.input(ctx.channel_name, ctx.key, %{seq: 1, dx: 1, dy: 0})

      assert pos(ctx.channel_name, ctx.key) == {x0 + 1, y0, "right"}

      assert_receive %{
        event: "space_delta",
        payload: %{seq_ack: seq_ack, updates: updates}
      }

      assert seq_ack[ctx.key] == 1
      assert updates[ctx.key].x == x0 + 1
      assert updates[ctx.key].dir == "right"
    end

    test "emits participant count and step telemetry" do
      count_ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:retro_hex_chat, :virtual_space, :participant_count]
        ])

      step_ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:retro_hex_chat, :virtual_space, :step]
        ])

      ctx = start_space()

      assert_received {[:retro_hex_chat, :virtual_space, :participant_count], ^count_ref,
                       %{value: 1}, %{channel: channel}}

      assert channel == ctx.channel_name

      assert :ok = ChannelSpaceServer.input(ctx.channel_name, ctx.key, %{seq: 1, dx: 1, dy: 0})

      assert_received {[:retro_hex_chat, :virtual_space, :step], ^step_ref,
                       %{count: 1, duration: duration},
                       %{channel: ^channel, result: :accepted, reason: :ok}}

      assert is_integer(duration)
    end

    test "each cardinal direction sets the matching facing" do
      ctx = start_space()

      assert :ok = ChannelSpaceServer.input(ctx.channel_name, ctx.key, %{seq: 1, dx: 0, dy: -1})
      assert {_, _, "up"} = pos(ctx.channel_name, ctx.key)

      assert :ok = ChannelSpaceServer.input(ctx.channel_name, ctx.key, %{seq: 2, dx: -1, dy: 0})
      assert {_, _, "left"} = pos(ctx.channel_name, ctx.key)

      assert :ok = ChannelSpaceServer.input(ctx.channel_name, ctx.key, %{seq: 3, dx: 0, dy: 1})
      assert {_, _, "down"} = pos(ctx.channel_name, ctx.key)
    end
  end

  describe "rejected movement" do
    test "a step into a collision tile is rejected and a correction delta is published" do
      ctx = start_space()
      # Walk up from the spawn plaza until the forest/cliff wall blocks the step.
      step_up_until_blocked(ctx)

      {x, y, _} = pos(ctx.channel_name, ctx.key)
      flush_deltas()

      # The next step up hits the wall -> rejected, position unchanged.
      assert {:error, :blocked} =
               ChannelSpaceServer.input(ctx.channel_name, ctx.key, %{seq: 999, dx: 0, dy: -1})

      assert {^x, ^y, _} = pos(ctx.channel_name, ctx.key)

      assert_receive %{event: "space_delta", payload: %{seq_ack: seq_ack, updates: updates}}
      assert seq_ack[ctx.key] == 999
      assert updates[ctx.key].y == y
    end

    test "diagonal and non-unit steps are rejected without moving" do
      ctx = start_space()
      before = pos(ctx.channel_name, ctx.key)

      assert {:error, :invalid_step} =
               ChannelSpaceServer.input(ctx.channel_name, ctx.key, %{seq: 1, dx: 1, dy: 1})

      assert {:error, :invalid_step} =
               ChannelSpaceServer.input(ctx.channel_name, ctx.key, %{seq: 2, dx: 2, dy: 0})

      assert {:error, :invalid_step} =
               ChannelSpaceServer.input(ctx.channel_name, ctx.key, %{seq: 3, dx: 0, dy: 0})

      assert pos(ctx.channel_name, ctx.key) == before
    end

    test "a second input before the cooldown elapses is rejected" do
      Application.put_env(:retro_hex_chat, :virtual_space_step_ms, 10_000)
      ctx = start_space()

      assert :ok = ChannelSpaceServer.input(ctx.channel_name, ctx.key, %{seq: 1, dx: 1, dy: 0})
      {x, y, _} = pos(ctx.channel_name, ctx.key)

      assert {:error, :cooldown} =
               ChannelSpaceServer.input(ctx.channel_name, ctx.key, %{seq: 2, dx: 1, dy: 0})

      assert {^x, ^y, _} = pos(ctx.channel_name, ctx.key)
    end

    test "input from an absent participant is ignored" do
      ctx = start_space()

      assert {:error, :not_participant} =
               ChannelSpaceServer.input(ctx.channel_name, "nick:missing", %{seq: 1, dx: 1, dy: 0})
    end

    test "input on an unknown channel returns not_found" do
      assert {:error, :not_found} =
               ChannelSpaceServer.input("#nope", "nick:alice", %{seq: 1, dx: 1, dy: 0})
    end
  end

  # Steps the participant north until a wall (forest/cliff) rejects the move.
  defp step_up_until_blocked(ctx, guard \\ 60) do
    if guard > 0 do
      case ChannelSpaceServer.input(ctx.channel_name, ctx.key, %{seq: seq(), dx: 0, dy: -1}) do
        :ok -> step_up_until_blocked(ctx, guard - 1)
        {:error, :blocked} -> :ok
      end
    else
      flunk("never hit a wall stepping north")
    end
  end

  defp seq, do: System.unique_integer([:positive])

  defp flush_deltas do
    receive do
      %{event: "space_delta"} -> flush_deltas()
    after
      0 -> :ok
    end
  end
end
