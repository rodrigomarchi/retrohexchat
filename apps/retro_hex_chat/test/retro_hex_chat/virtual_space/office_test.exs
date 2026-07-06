defmodule RetroHexChat.VirtualSpace.OfficeTest do
  use RetroHexChat.DataCase, async: false

  import RetroHexChat.Factory

  alias RetroHexChat.VirtualSpace.{Queries, SessionServer, Supervisor}

  @moduletag :integration

  setup do
    Application.put_env(:retro_hex_chat, :virtual_space_step_ms, 0)
    Application.put_env(:retro_hex_chat, :virtual_space_chat_rate, {3, 1000})

    on_exit(fn ->
      Application.delete_env(:retro_hex_chat, :virtual_space_step_ms)
      Application.delete_env(:retro_hex_chat, :virtual_space_chat_rate)
    end)

    :ok
  end

  defp start_space do
    creator = insert(:registered_nick)

    {:ok, session} =
      Queries.insert_session(%{
        token: "office-#{System.unique_integer([:positive])}",
        channel_name: "#retro",
        creator_id: creator.id,
        creator_nick: creator.nickname,
        map_id: "tavern_cafe_v1",
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
      })

    {:ok, pid} = Supervisor.start_child(session.token)
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)

    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "space:#{session.token}")

    {:ok, joined} =
      SessionServer.join(session.token, %{user_id: creator.id, nickname: creator.nickname})

    %{token: session.token, key: joined.participant.key}
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

      # Walk right out of the spawn zone (x > 15) into main_cafe.
      walk_to(ctx, {16, entry(ctx.token, ctx.key).y})

      assert_receive %{
        event: "space_zone_changed",
        payload: %{zone_id: "main_cafe", from: "spawn"}
      }

      assert entry(ctx.token, ctx.key).zone_id == "main_cafe"
    end
  end

  describe "seating" do
    test "sitting reserves the seat, changes pose, and rejects a second occupant" do
      ctx = start_space()
      walk_to(ctx, {17, 14})
      flush()

      assert :ok =
               SessionServer.interact(ctx.token, ctx.key, %{
                 seq: 1,
                 kind: "sit",
                 target_id: "seat_bar_1"
               })

      p = entry(ctx.token, ctx.key)
      assert p.pose == "sitting"
      assert p.seat_id == "seat_bar_1"
      assert {p.x, p.y} == {18, 14}
      assert p.dir == "up"

      assert_receive %{event: "space_delta", payload: %{updates: updates}}
      assert updates[ctx.key].pose == "sitting"

      # A second participant cannot take the reserved seat.
      other = insert(:registered_nick)
      {:ok, o} = SessionServer.join(ctx.token, %{user_id: other.id, nickname: other.nickname})
      okey = o.participant.key
      octx = %{token: ctx.token, key: okey}
      walk_to(octx, {17, 14})

      assert {:error, :seat_taken} =
               SessionServer.interact(ctx.token, okey, %{
                 seq: 1,
                 kind: "sit",
                 target_id: "seat_bar_1"
               })
    end

    test "walking stands the participant up and frees the seat" do
      ctx = start_space()
      walk_to(ctx, {17, 14})

      :ok =
        SessionServer.interact(ctx.token, ctx.key, %{seq: 1, kind: "sit", target_id: "seat_bar_1"})

      assert entry(ctx.token, ctx.key).pose == "sitting"

      step(ctx, 0, -1)

      p = entry(ctx.token, ctx.key)
      assert p.pose == "standing"
      assert p.seat_id == nil

      {:ok, state} = SessionServer.get_state(ctx.token)
      refute Map.has_key?(state.seats, "seat_bar_1")
    end

    test "leaving frees the seat" do
      ctx = start_space()
      walk_to(ctx, {17, 14})

      :ok =
        SessionServer.interact(ctx.token, ctx.key, %{seq: 1, kind: "sit", target_id: "seat_bar_1"})

      SessionServer.leave(ctx.token, ctx.key)

      wait_until(fn ->
        {:ok, state} = SessionServer.get_state(ctx.token)
        not Map.has_key?(state.seats, "seat_bar_1")
      end)

      {:ok, state} = SessionServer.get_state(ctx.token)
      refute Map.has_key?(state.seats, "seat_bar_1")
    end

    test "sitting on an unknown or distant seat is rejected" do
      ctx = start_space()

      assert {:error, :invalid_target} =
               SessionServer.interact(ctx.token, ctx.key, %{
                 seq: 1,
                 kind: "sit",
                 target_id: "nope"
               })

      # Spawn is far from seat_bar_1.
      assert {:error, :too_far} =
               SessionServer.interact(ctx.token, ctx.key, %{
                 seq: 2,
                 kind: "sit",
                 target_id: "seat_bar_1"
               })
    end
  end

  describe "board interactables" do
    test "using a board returns a modal with the map's asset" do
      ctx = start_space()
      walk_to(ctx, {12, 11})

      assert {:ok, %{modal: modal}} =
               SessionServer.interact(ctx.token, ctx.key, %{
                 seq: 1,
                 kind: "use",
                 target_id: "menu_board"
               })

      assert modal.asset == "board_menu_v1"
      assert modal.title == "Tavern menu"
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
                 target_id: "menu_board"
               })
    end
  end

  describe "chat bubbles" do
    test "a message broadcasts space_message with the normalized text" do
      ctx = start_space()

      assert :ok = SessionServer.chat_bubble(ctx.token, ctx.key, "  hello   world  ")

      assert_receive %{event: "space_message", payload: payload}
      assert payload.key == ctx.key
      assert payload.text == "hello world"
      assert payload.nickname
    end

    test "a message over 160 chars is rejected" do
      ctx = start_space()
      long = String.duplicate("a", 161)

      assert {:error, :too_long} = SessionServer.chat_bubble(ctx.token, ctx.key, long)
    end

    test "a muted participant cannot send" do
      ctx = start_space()

      :sys.replace_state(
        elem(lookup(ctx.token), 1),
        &put_in(&1.participants[ctx.key].muted?, true)
      )

      assert {:error, :muted} = SessionServer.chat_bubble(ctx.token, ctx.key, "hi")
    end

    test "the rate limit rejects a burst" do
      ctx = start_space()

      assert :ok = SessionServer.chat_bubble(ctx.token, ctx.key, "1")
      assert :ok = SessionServer.chat_bubble(ctx.token, ctx.key, "2")
      assert :ok = SessionServer.chat_bubble(ctx.token, ctx.key, "3")
      assert {:error, :rate_limited} = SessionServer.chat_bubble(ctx.token, ctx.key, "4")
    end
  end

  defp lookup(token), do: RetroHexChat.VirtualSpace.Registry.lookup(token)

  defp wait_until(fun, retries \\ 50) do
    cond do
      fun.() -> :ok
      retries == 0 -> flunk("condition never became true")
      true -> Process.sleep(10) && wait_until(fun, retries - 1)
    end
  end
end
