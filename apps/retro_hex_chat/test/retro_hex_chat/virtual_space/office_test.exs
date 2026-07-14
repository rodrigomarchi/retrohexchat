defmodule RetroHexChat.VirtualSpace.OfficeTest do
  use RetroHexChat.DataCase, async: false

  alias RetroHexChat.Channels.Registry, as: ChannelRegistry
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Channels.Supervisor, as: ChannelSupervisor
  alias RetroHexChat.VirtualSpace.ChannelSpaceServer
  alias RetroHexChat.VirtualSpace.Supervisor

  @moduletag :integration

  setup do
    Application.put_env(:retro_hex_chat, :virtual_space_step_ms, 0)
    # Channels render the End of Time in production, which carries no seats, zones
    # or boards. Inject a fully-walkable iso fixture so these tests exercise the
    # server's interaction logic against known seat/zone/board coordinates.
    Application.put_env(:retro_hex_chat, :channel_space_map_override, fixture_map())

    on_exit(fn ->
      Application.delete_env(:retro_hex_chat, :virtual_space_step_ms)
      Application.delete_env(:retro_hex_chat, :channel_space_map_override)
    end)

    :ok
  end

  # A minimal isometric channel map: a 40×24 walkable plane split into a spawn
  # zone (left) and a plaza (right), with one bench seat and one notice board.
  defp fixture_map do
    %{
      id: "channel_space_fixture",
      version: 1,
      width: 40,
      height: 24,
      tile_size: 32,
      projection: "isometric",
      iso: %{tile_w: 64, tile_h: 32, z_step: 16, headroom: 6},
      slabs: [],
      vignette: nil,
      sea: nil,
      railings: [],
      railing_posts: [],
      tilesets: [],
      tiles: %{},
      ground: nil,
      spawn: [%{x: 6, y: 15, dir: "right"}],
      layers: %{floor: [], decor: [], above: []},
      lights: [],
      ambient: nil,
      parallax: [],
      labels: [],
      collision: [],
      zones: [
        %{id: "spawn", kind: "zone", x: 0, y: 0, w: 20, h: 24},
        %{id: "plaza", kind: "zone", x: 20, y: 0, w: 20, h: 24}
      ],
      interactables: [
        %{
          id: "notice_board",
          x: 4,
          y: 15,
          title: "Notice board",
          modal: %{kind: "image", asset: "board_menu_v1"}
        }
      ],
      seats: [%{id: "seat_bench_a", x: 24, y: 11, dir: "down"}]
    }
  end

  defp start_space(nickname \\ "alice") do
    channel = "#office-#{System.unique_integer([:positive])}"

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

    %{
      channel_name: channel,
      nickname: nickname,
      key: joined.participant.key
    }
  end

  defp join_member(ctx, nickname) do
    {:ok, _} = Server.join(ctx.channel_name, nickname)
    {:ok, joined} = ChannelSpaceServer.join(ctx.channel_name, %{user_id: nil, nickname: nickname})
    joined.participant.key
  end

  defp entry(channel_name, key) do
    {:ok, state} = ChannelSpaceServer.get_state(channel_name)
    state.participants[key]
  end

  defp walk_to(ctx, {tx, ty}) do
    p = entry(ctx.channel_name, ctx.key)

    case step_toward(p, tx, ty) do
      nil ->
        :ok

      {dx, dy} ->
        step(ctx, dx, dy)
        walk_to(ctx, {tx, ty})
    end
  end

  defp step_toward(p, tx, ty) do
    cond do
      p.x < tx -> {1, 0}
      p.x > tx -> {-1, 0}
      p.y < ty -> {0, 1}
      p.y > ty -> {0, -1}
      true -> nil
    end
  end

  defp step(ctx, dx, dy) do
    :ok =
      ChannelSpaceServer.input(ctx.channel_name, ctx.key, %{
        seq: System.unique_integer([:positive]),
        dx: dx,
        dy: dy
      })

    true
  end

  defp flush do
    receive do
      _ -> flush()
    after
      0 -> :ok
    end
  end

  describe "zones" do
    test "sets the spawn zone on join and broadcasts space_zone_changed on crossing" do
      ctx = start_space()
      assert entry(ctx.channel_name, ctx.key).zone_id == "spawn"

      # Walk right across the centre line into the plaza zone.
      walk_to(ctx, {30, entry(ctx.channel_name, ctx.key).y})

      assert_receive %{
        event: "space_zone_changed",
        payload: %{zone_id: "plaza", from: "spawn"}
      }

      assert entry(ctx.channel_name, ctx.key).zone_id == "plaza"
    end
  end

  describe "seating" do
    test "sitting reserves the seat, changes pose, and rejects a second occupant" do
      ctx = start_space()
      walk_to(ctx, {24, 12})
      flush()

      assert :ok =
               ChannelSpaceServer.interact(ctx.channel_name, ctx.key, %{
                 seq: 1,
                 kind: "sit",
                 target_id: "seat_bench_a"
               })

      p = entry(ctx.channel_name, ctx.key)
      assert p.pose == "sitting"
      assert p.seat_id == "seat_bench_a"
      assert {p.x, p.y} == {24, 11}
      assert p.dir == "down"

      assert_receive %{event: "space_delta", payload: %{updates: updates}}
      assert updates[ctx.key].pose == "sitting"

      # A second participant cannot take the reserved seat.
      okey = join_member(ctx, "bob")
      octx = %{channel_name: ctx.channel_name, key: okey}
      walk_to(octx, {24, 12})

      assert {:error, :seat_taken} =
               ChannelSpaceServer.interact(ctx.channel_name, okey, %{
                 seq: 1,
                 kind: "sit",
                 target_id: "seat_bench_a"
               })
    end

    test "walking stands the participant up and frees the seat" do
      ctx = start_space()
      walk_to(ctx, {24, 12})

      :ok =
        ChannelSpaceServer.interact(ctx.channel_name, ctx.key, %{
          seq: 1,
          kind: "sit",
          target_id: "seat_bench_a"
        })

      assert entry(ctx.channel_name, ctx.key).pose == "sitting"

      step(ctx, 0, 1)

      p = entry(ctx.channel_name, ctx.key)
      assert p.pose == "standing"
      assert p.seat_id == nil

      {:ok, state} = ChannelSpaceServer.get_state(ctx.channel_name)
      refute Map.has_key?(state.seats, "seat_bench_a")
    end

    test "leaving the text channel frees the seat" do
      ctx = start_space()
      walk_to(ctx, {24, 12})

      :ok =
        ChannelSpaceServer.interact(ctx.channel_name, ctx.key, %{
          seq: 1,
          kind: "sit",
          target_id: "seat_bench_a"
        })

      Server.part(ctx.channel_name, ctx.nickname)

      wait_until(fn ->
        {:ok, state} = ChannelSpaceServer.get_state(ctx.channel_name)
        not Map.has_key?(state.seats, "seat_bench_a")
      end)

      {:ok, state} = ChannelSpaceServer.get_state(ctx.channel_name)
      refute Map.has_key?(state.seats, "seat_bench_a")
      refute Map.has_key?(state.participants, ctx.key)
    end

    test "sitting on an unknown or distant seat is rejected" do
      ctx = start_space()

      assert {:error, :invalid_target} =
               ChannelSpaceServer.interact(ctx.channel_name, ctx.key, %{
                 seq: 1,
                 kind: "sit",
                 target_id: "nope"
               })

      # Spawn is far from seat_bench_a.
      assert {:error, :too_far} =
               ChannelSpaceServer.interact(ctx.channel_name, ctx.key, %{
                 seq: 2,
                 kind: "sit",
                 target_id: "seat_bench_a"
               })
    end
  end

  describe "board interactables" do
    test "using a board returns a modal with the map's asset" do
      ctx = start_space()
      walk_to(ctx, {3, 15})

      assert {:ok, %{modal: modal}} =
               ChannelSpaceServer.interact(ctx.channel_name, ctx.key, %{
                 seq: 1,
                 kind: "use",
                 target_id: "notice_board"
               })

      assert modal.asset == "board_menu_v1"
      assert modal.title == "Notice board"
    end

    test "an unknown or distant board is rejected" do
      ctx = start_space()

      assert {:error, :invalid_target} =
               ChannelSpaceServer.interact(ctx.channel_name, ctx.key, %{
                 seq: 1,
                 kind: "use",
                 target_id: "ghost"
               })

      assert {:error, :too_far} =
               ChannelSpaceServer.interact(ctx.channel_name, ctx.key, %{
                 seq: 2,
                 kind: "use",
                 target_id: "notice_board"
               })
    end
  end

  describe "chat bubbles" do
    test "public channel messages become virtual space bubbles" do
      ctx = start_space()
      flush()

      assert {:ok, _id} = Server.send_message(ctx.channel_name, ctx.nickname, "  hello   world  ")

      assert_receive %{event: "space_message", payload: payload}
      assert payload.key == ctx.key
      assert payload.text == "hello world"
      assert payload.nickname == ctx.nickname
    end
  end

  defp wait_until(fun, retries \\ 50) do
    cond do
      fun.() -> :ok
      retries == 0 -> flunk("condition never became true")
      true -> Process.sleep(10) && wait_until(fun, retries - 1)
    end
  end
end
