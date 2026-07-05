defmodule RetroHexChat.VirtualSpace.MovementTest do
  use RetroHexChat.DataCase, async: false

  import RetroHexChat.Factory

  alias RetroHexChat.VirtualSpace
  alias RetroHexChat.VirtualSpace.{Queries, Registry, SessionServer, Supervisor}

  @moduletag :integration

  setup do
    # No cooldown by default; the cooldown test overrides this.
    Application.put_env(:retro_hex_chat, :virtual_space_step_ms, 0)
    on_exit(fn -> Application.delete_env(:retro_hex_chat, :virtual_space_step_ms) end)
    :ok
  end

  defp start_space(attrs \\ %{}) do
    creator = insert(:registered_nick)

    base = %{
      token: "mv-#{System.unique_integer([:positive])}",
      channel_name: "#retro",
      creator_id: creator.id,
      creator_nick: creator.nickname,
      expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
    }

    {:ok, session} = Queries.insert_session(Map.merge(base, attrs))
    {:ok, pid} = Supervisor.start_child(session.token)
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)

    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "space:#{session.token}")

    {:ok, joined} =
      SessionServer.join(session.token, %{user_id: creator.id, nickname: creator.nickname})

    %{token: session.token, key: joined.participant.key, spawn: joined.participant}
  end

  defp pos(token, key) do
    {:ok, state} = SessionServer.get_state(token)
    p = state.participants[key]
    {p.x, p.y, p.dir}
  end

  describe "valid movement" do
    test "an adjacent cardinal step moves the participant and broadcasts a delta with seq_ack" do
      ctx = start_space()
      {x0, y0, _} = pos(ctx.token, ctx.key)

      assert :ok = SessionServer.input(ctx.token, ctx.key, %{seq: 1, dx: 1, dy: 0})

      assert pos(ctx.token, ctx.key) == {x0 + 1, y0, "right"}

      assert_receive %{
        event: "space_delta",
        payload: %{seq_ack: seq_ack, updates: updates}
      }

      assert seq_ack[ctx.key] == 1
      assert updates[ctx.key].x == x0 + 1
      assert updates[ctx.key].dir == "right"
    end

    test "each cardinal direction sets the matching facing" do
      ctx = start_space()

      assert :ok = SessionServer.input(ctx.token, ctx.key, %{seq: 1, dx: 0, dy: -1})
      assert {_, _, "up"} = pos(ctx.token, ctx.key)

      assert :ok = SessionServer.input(ctx.token, ctx.key, %{seq: 2, dx: -1, dy: 0})
      assert {_, _, "left"} = pos(ctx.token, ctx.key)

      assert :ok = SessionServer.input(ctx.token, ctx.key, %{seq: 3, dx: 0, dy: 1})
      assert {_, _, "down"} = pos(ctx.token, ctx.key)
    end
  end

  describe "rejected movement" do
    test "a step into a collision tile is rejected and a correction delta is published" do
      # Spawn is at (10,12); the top wall row y=0 is collision. Walk up to it.
      ctx = start_space()
      # Move to (1,1): first get adjacent to the left wall at x=0.
      # Simpler: drive left until blocked by the x=0 wall.
      walk_to(ctx, {1, elem(pos(ctx.token, ctx.key), 1)})

      {x, y, _} = pos(ctx.token, ctx.key)
      assert x == 1

      flush_deltas()

      # A further step left targets x=0 (wall) → rejected, position unchanged.
      assert {:error, :blocked} =
               SessionServer.input(ctx.token, ctx.key, %{seq: 999, dx: -1, dy: 0})

      assert {^x, ^y, _} = pos(ctx.token, ctx.key)

      assert_receive %{event: "space_delta", payload: %{seq_ack: seq_ack, updates: updates}}
      assert seq_ack[ctx.key] == 999
      assert updates[ctx.key].x == 1
    end

    test "diagonal and non-unit steps are rejected without moving" do
      ctx = start_space()
      before = pos(ctx.token, ctx.key)

      assert {:error, :invalid_step} =
               SessionServer.input(ctx.token, ctx.key, %{seq: 1, dx: 1, dy: 1})

      assert {:error, :invalid_step} =
               SessionServer.input(ctx.token, ctx.key, %{seq: 2, dx: 2, dy: 0})

      assert {:error, :invalid_step} =
               SessionServer.input(ctx.token, ctx.key, %{seq: 3, dx: 0, dy: 0})

      assert pos(ctx.token, ctx.key) == before
    end

    test "a second input before the cooldown elapses is rejected" do
      Application.put_env(:retro_hex_chat, :virtual_space_step_ms, 10_000)
      ctx = start_space()

      assert :ok = SessionServer.input(ctx.token, ctx.key, %{seq: 1, dx: 1, dy: 0})
      {x, y, _} = pos(ctx.token, ctx.key)

      assert {:error, :cooldown} =
               SessionServer.input(ctx.token, ctx.key, %{seq: 2, dx: 1, dy: 0})

      assert {^x, ^y, _} = pos(ctx.token, ctx.key)
    end

    test "input from an absent participant is ignored" do
      ctx = start_space()

      assert {:error, :not_participant} =
               SessionServer.input(ctx.token, "registered:999999", %{seq: 1, dx: 1, dy: 0})
    end

    test "input on an unknown token returns not_found" do
      assert {:error, :not_found} =
               SessionServer.input("nope", "registered:1", %{seq: 1, dx: 1, dy: 0})
    end
  end

  # Drives the participant left/up toward a target tile with valid steps.
  defp walk_to(ctx, {tx, ty}) do
    {x, y, _} = pos(ctx.token, ctx.key)

    cond do
      x > tx ->
        :ok = SessionServer.input(ctx.token, ctx.key, %{seq: seq(), dx: -1, dy: 0})
        walk_to(ctx, {tx, ty})

      y > ty ->
        :ok = SessionServer.input(ctx.token, ctx.key, %{seq: seq(), dx: 0, dy: -1})
        walk_to(ctx, {tx, ty})

      true ->
        :ok
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
