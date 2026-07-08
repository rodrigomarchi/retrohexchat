defmodule RetroHexChat.VirtualSpace.OfficeTest do
  use RetroHexChat.DataCase, async: false

  alias RetroHexChat.Channels.Registry, as: ChannelRegistry
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Channels.Supervisor, as: ChannelSupervisor
  alias RetroHexChat.VirtualSpace.SessionServer
  alias RetroHexChat.VirtualSpace.Supervisor

  @moduletag :integration

  setup do
    Application.put_env(:retro_hex_chat, :virtual_space_step_ms, 0)
    on_exit(fn -> Application.delete_env(:retro_hex_chat, :virtual_space_step_ms) end)
    :ok
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

    {:ok, joined} = SessionServer.join(channel, %{user_id: nil, nickname: nickname})

    %{
      token: channel,
      nickname: nickname,
      key: joined.participant.key
    }
  end

  defp join_member(ctx, nickname) do
    {:ok, _} = Server.join(ctx.token, nickname)
    {:ok, joined} = SessionServer.join(ctx.token, %{user_id: nil, nickname: nickname})
    joined.participant.key
  end

  defp entry(token, key) do
    {:ok, state} = SessionServer.get_state(token)
    state.participants[key]
  end

  defp walk_to(ctx, {tx, ty}) do
    p = entry(ctx.token, ctx.key)

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
      SessionServer.input(ctx.token, ctx.key, %{
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
      assert entry(ctx.token, ctx.key).zone_id == "spawn"

      # Walk right out of the spawn zone (x > 44) into the village.
      walk_to(ctx, {46, entry(ctx.token, ctx.key).y})

      assert_receive %{
        event: "space_zone_changed",
        payload: %{zone_id: "village", from: "spawn"}
      }

      assert entry(ctx.token, ctx.key).zone_id == "village"
    end
  end

  describe "seating" do
    test "sitting reserves the seat, changes pose, and rejects a second occupant" do
      ctx = start_space()
      walk_to(ctx, {49, 26})
      flush()

      assert :ok =
               SessionServer.interact(ctx.token, ctx.key, %{
                 seq: 1,
                 kind: "sit",
                 target_id: "seat_market_a"
               })

      p = entry(ctx.token, ctx.key)
      assert p.pose == "sitting"
      assert p.seat_id == "seat_market_a"
      assert {p.x, p.y} == {49, 27}
      assert p.dir == "down"

      assert_receive %{event: "space_delta", payload: %{updates: updates}}
      assert updates[ctx.key].pose == "sitting"

      # A second participant cannot take the reserved seat.
      okey = join_member(ctx, "bob")
      octx = %{token: ctx.token, key: okey}
      walk_to(octx, {50, 26})

      assert {:error, :seat_taken} =
               SessionServer.interact(ctx.token, okey, %{
                 seq: 1,
                 kind: "sit",
                 target_id: "seat_market_a"
               })
    end

    test "walking stands the participant up and frees the seat" do
      ctx = start_space()
      walk_to(ctx, {49, 26})

      :ok =
        SessionServer.interact(ctx.token, ctx.key, %{
          seq: 1,
          kind: "sit",
          target_id: "seat_market_a"
        })

      assert entry(ctx.token, ctx.key).pose == "sitting"

      step(ctx, 0, 1)

      p = entry(ctx.token, ctx.key)
      assert p.pose == "standing"
      assert p.seat_id == nil

      {:ok, state} = SessionServer.get_state(ctx.token)
      refute Map.has_key?(state.seats, "seat_market_a")
    end

    test "leaving the text channel frees the seat" do
      ctx = start_space()
      walk_to(ctx, {49, 26})

      :ok =
        SessionServer.interact(ctx.token, ctx.key, %{
          seq: 1,
          kind: "sit",
          target_id: "seat_market_a"
        })

      Server.part(ctx.token, ctx.nickname)

      wait_until(fn ->
        {:ok, state} = SessionServer.get_state(ctx.token)
        not Map.has_key?(state.seats, "seat_market_a")
      end)

      {:ok, state} = SessionServer.get_state(ctx.token)
      refute Map.has_key?(state.seats, "seat_market_a")
      refute Map.has_key?(state.participants, ctx.key)
    end

    test "sitting on an unknown or distant seat is rejected" do
      ctx = start_space()

      assert {:error, :invalid_target} =
               SessionServer.interact(ctx.token, ctx.key, %{
                 seq: 1,
                 kind: "sit",
                 target_id: "nope"
               })

      # Spawn is far from seat_market_a.
      assert {:error, :too_far} =
               SessionServer.interact(ctx.token, ctx.key, %{
                 seq: 2,
                 kind: "sit",
                 target_id: "seat_market_a"
               })
    end
  end

  describe "board interactables" do
    test "using a board returns a modal with the map's asset" do
      ctx = start_space()
      walk_to(ctx, {40, 19})

      assert {:ok, %{modal: modal}} =
               SessionServer.interact(ctx.token, ctx.key, %{
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
               SessionServer.interact(ctx.token, ctx.key, %{
                 seq: 1,
                 kind: "use",
                 target_id: "ghost"
               })

      assert {:error, :too_far} =
               SessionServer.interact(ctx.token, ctx.key, %{
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

      assert {:ok, _id} = Server.send_message(ctx.token, ctx.nickname, "  hello   world  ")

      assert_receive %{event: "space_message", payload: payload}
      assert payload.key == ctx.key
      assert payload.text == "hello world"
      assert payload.nickname == ctx.nickname
    end

    test "space_chat_bubble remains a no-op in channel spaces" do
      ctx = start_space()
      flush()

      assert :ok = SessionServer.chat_bubble(ctx.token, ctx.key, "local-only")
      refute_receive %{event: "space_message"}, 100
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
