defmodule RetroHexChat.VirtualSpace.ConstructTest do
  use RetroHexChat.DataCase, async: false

  alias RetroHexChat.Channels.Registry, as: ChannelRegistry
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Channels.Supervisor, as: ChannelSupervisor
  alias RetroHexChat.VirtualSpace
  alias RetroHexChat.VirtualSpace.ChannelSpaceServer
  alias RetroHexChat.VirtualSpace.Construct.Store
  alias RetroHexChat.VirtualSpace.DirectMessageSpace
  alias RetroHexChat.VirtualSpace.Registry

  @moduletag :integration

  setup do
    Application.put_env(:retro_hex_chat, :virtual_space_step_ms, 0)
    Application.put_env(:retro_hex_chat, :virtual_space_build_ms, 0)

    on_exit(fn ->
      Application.delete_env(:retro_hex_chat, :virtual_space_step_ms)
      Application.delete_env(:retro_hex_chat, :virtual_space_build_ms)
    end)

    :ok
  end

  defp channel_with(members) do
    channel = "#construct-#{System.unique_integer([:positive])}"
    {:ok, channel_pid} = ChannelSupervisor.start_child(channel)
    Enum.each(members, &({:ok, _} = Server.join(channel, &1)))
    construct_id = VirtualSpace.construct_id(channel)

    on_exit(fn ->
      stop_construct(construct_id)

      case ChannelRegistry.lookup(channel) do
        {:ok, ^channel_pid} -> ChannelSupervisor.stop_child(channel_pid)
        _ -> :ok
      end
    end)

    %{channel: channel, construct_id: construct_id}
  end

  defp stop_construct(construct_id) do
    case Registry.lookup({:construct_space, construct_id}) do
      {:ok, pid} ->
        ref = Process.monitor(pid)
        GenServer.stop(pid, :normal)
        assert_receive {:DOWN, ^ref, :process, ^pid, _reason}

      {:error, :not_found} ->
        :ok
    end
  catch
    :exit, _gone -> :ok
  end

  defp enter(construct_id, nickname, participants \\ nil) do
    {:ok, joined} =
      VirtualSpace.join_construct_space(
        construct_id,
        %{user_id: nil, nickname: nickname},
        participants
      )

    joined
  end

  defp key(nickname), do: "nick:#{String.downcase(nickname)}"

  defp place(construct_id, nickname, kind, x, y) do
    VirtualSpace.build_construct(
      construct_id,
      key(nickname),
      nickname,
      {:place, kind, x, y, "down"}
    )
  end

  describe "who is in a channel's Construct" do
    test "only the members who walked in are drawn, and nobody outside the channel" do
      ctx = channel_with(["alice", "bob"])
      joined = enter(ctx.construct_id, "alice")

      assert joined.map.id == "construct"
      assert joined.session == nil
      assert Map.keys(joined.snapshot.participants) == [key("alice")]
      assert VirtualSpace.roster(ctx.construct_id) == ["alice"]

      assert {:error, :not_in_channel} =
               VirtualSpace.join_construct_space(
                 ctx.construct_id,
                 %{user_id: nil, nickname: "mallory"},
                 nil
               )
    end

    test "leaving the room takes a member out of it, and the last one closes it" do
      ctx = channel_with(["alice", "bob"])
      enter(ctx.construct_id, "alice")
      enter(ctx.construct_id, "bob")
      assert VirtualSpace.roster(ctx.construct_id) == ["alice", "bob"]

      VirtualSpace.leave_construct_space_viewer(ctx.construct_id, key("bob"))
      assert VirtualSpace.roster(ctx.construct_id) == ["alice"]

      {:ok, pid} = Registry.lookup({:construct_space, ctx.construct_id})
      ref = Process.monitor(pid)
      VirtualSpace.leave_construct_space_viewer(ctx.construct_id, key("alice"))
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
    end

    test "parting the channel takes a member out of its Construct" do
      ctx = channel_with(["alice", "bob"])
      enter(ctx.construct_id, "alice")
      enter(ctx.construct_id, "bob")

      :ok = Server.part(ctx.channel, "bob", nil)
      Process.sleep(50)
      assert VirtualSpace.roster(ctx.construct_id) == ["alice"]
    end
  end

  describe "a private space's Construct" do
    test "admits the pair and nobody else" do
      suffix = System.unique_integer([:positive])
      [a, b] = pair = ["cst_a_#{suffix}", "cst_b_#{suffix}"]
      construct_id = VirtualSpace.construct_id(DirectMessageSpace.space_id(a, b))
      on_exit(fn -> stop_construct(construct_id) end)

      joined = enter(construct_id, a, pair)
      assert Map.keys(joined.snapshot.participants) == [key(a)]

      assert {:error, :invalid_participants} =
               VirtualSpace.join_construct_space(
                 construct_id,
                 %{user_id: nil, nickname: a},
                 [a, "intruder"]
               )

      assert {:error, :not_in_direct_message} =
               VirtualSpace.join_construct_space(
                 construct_id,
                 %{user_id: nil, nickname: "intruder"},
                 pair
               )
    end
  end

  describe "the gates" do
    test "the End of Time gate asks before taking anyone to the Construct" do
      {:ok, map} = VirtualSpace.get_map("end_of_time")

      assert %{modal: %{kind: "confirm", action: "enter_construct"}} =
               Enum.find(map.interactables, &(&1.id == "construct_portal"))
    end

    test "the Construct's own gate asks before taking anyone back" do
      ctx = channel_with(["alice"])
      enter(ctx.construct_id, "alice")

      # Spawned at (4,4); the gate stands at (2,2). Walk up to it.
      for {dx, dy} <- [{-1, 0}, {0, -1}] do
        :ok =
          ChannelSpaceServer.input(ctx.construct_id, key("alice"), %{
            seq: System.unique_integer([:positive]),
            dx: dx,
            dy: dy
          })
      end

      assert {:ok, %{modal: %{kind: "confirm", action: "exit_construct", title: "End of Time"}}} =
               VirtualSpace.interact(ctx.construct_id, key("alice"), %{
                 kind: "use",
                 target_id: "construct_exit"
               })
    end
  end

  describe "building" do
    test "an edit reaches everyone inside and is stored" do
      ctx = channel_with(["alice", "bob"])
      enter(ctx.construct_id, "alice")
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "space:" <> ctx.construct_id)

      assert {:ok, 1} = place(ctx.construct_id, "alice", "table", 10, 10)

      assert_receive %{
        event: "construct_layout",
        payload: %{revision: 1, items: [%{kind: "table", x: 10, y: 10} = table]}
      }

      assert %{revision: 1, items: [%{"id" => id}]} = Store.load(ctx.construct_id)
      assert id == table.id

      assert {:ok, 2} =
               VirtualSpace.build_construct(
                 ctx.construct_id,
                 key("alice"),
                 "alice",
                 {:move, table.id, 11, 10}
               )

      assert {:ok, 3} =
               VirtualSpace.build_construct(
                 ctx.construct_id,
                 key("alice"),
                 "alice",
                 {:remove, table.id}
               )

      assert %{revision: 3, items: []} = Store.load(ctx.construct_id)
    end

    test "a placed piece blocks the way" do
      ctx = channel_with(["alice"])
      enter(ctx.construct_id, "alice")
      {:ok, _} = place(ctx.construct_id, "alice", "tree", 5, 4)

      assert {:error, :blocked} =
               ChannelSpaceServer.input(ctx.construct_id, key("alice"), %{seq: 1, dx: 1, dy: 0})
    end

    test "what was built is there the next time the room opens" do
      ctx = channel_with(["alice"])
      enter(ctx.construct_id, "alice")
      {:ok, _} = place(ctx.construct_id, "alice", "lamp", 12, 12)
      stop_construct(ctx.construct_id)

      joined = enter(ctx.construct_id, "alice")
      assert [%{kind: "lamp", x: 12, y: 12}] = joined.map.items
      assert {:ok, 2} = place(ctx.construct_id, "alice", "tree", 13, 13)
    end

    test "a placed chair can be sat in, and is left alone while it is" do
      ctx = channel_with(["alice"])
      enter(ctx.construct_id, "alice")
      {:ok, _} = place(ctx.construct_id, "alice", "chair", 6, 4)
      {:ok, state} = ChannelSpaceServer.get_state(ctx.construct_id)
      [seat] = state.map.seats
      [chair] = state.items

      # Spawned at (4,4); one step east is next to the chair.
      :ok = ChannelSpaceServer.input(ctx.construct_id, key("alice"), %{seq: 1, dx: 1, dy: 0})

      assert :ok =
               VirtualSpace.interact(ctx.construct_id, key("alice"), %{
                 kind: "sit",
                 target_id: seat.id
               })

      assert {:error, :seat_taken} =
               VirtualSpace.build_construct(
                 ctx.construct_id,
                 key("alice"),
                 "alice",
                 {:remove, chair.id}
               )
    end

    test "only somebody inside can build, and only in a Construct" do
      ctx = channel_with(["alice", "bob"])
      enter(ctx.construct_id, "alice")

      assert {:error, :not_participant} = place(ctx.construct_id, "bob", "tree", 10, 10)
      assert {:error, :not_found} = place("construct:#nowhere", "bob", "tree", 10, 10)
    end

    test "edits are paced per person" do
      Application.put_env(:retro_hex_chat, :virtual_space_build_ms, 60_000)
      ctx = channel_with(["alice"])
      enter(ctx.construct_id, "alice")

      assert {:ok, 1} = place(ctx.construct_id, "alice", "tree", 10, 10)
      assert {:error, :cooldown} = place(ctx.construct_id, "alice", "tree", 11, 11)
    end
  end

  describe "a gathering through the gate" do
    setup do
      Application.put_env(:retro_hex_chat, :virtual_space_gathering_grace_ms, 150)

      on_exit(fn ->
        Application.put_env(:retro_hex_chat, :virtual_space_gathering_grace_ms, 0)
      end)

      :ok
    end

    defp stop_world(key) do
      {:ok, pid} = Registry.lookup(key)
      ref = Process.monitor(pid)
      GenServer.stop(pid, :normal)
      assert_receive {:DOWN, ^ref, :process, ^pid, _reason}
      _drained = :sys.get_state(VirtualSpace.SessionRecorder)
    end

    test "goes on while anybody is in the Construct, and keeps one card through a hop back" do
      ctx = channel_with(["alice"])

      {:ok, opened} =
        VirtualSpace.join_channel_space(ctx.channel, %{user_id: nil, nickname: "alice"})

      token = opened.session.token

      # Through the gate: the island empties, the Construct fills.
      enter(ctx.construct_id, "alice")
      _ = :sys.get_state(VirtualSpace.SessionRecorder)
      stop_world({:channel_space, ctx.channel})
      Process.sleep(250)
      assert {:ok, %{status: "open"}} = VirtualSpace.get_session(token)
      assert "alice" in VirtualSpace.roster(ctx.channel)

      # And back: the island restarts inside the same gathering, with no card.
      stop_construct(ctx.construct_id)

      {:ok, back} =
        VirtualSpace.join_channel_space(ctx.channel, %{user_id: nil, nickname: "alice"})

      assert back.session == nil
      assert VirtualSpace.open_session(ctx.channel).token == token

      # Everybody gone, for longer than a hop: the gathering is over.
      stop_world({:channel_space, ctx.channel})
      Process.sleep(250)

      assert {:ok, %{status: "closed", closed_reason: "emptied"}} =
               VirtualSpace.get_session(token)
    end
  end

  describe "Store.save/4" do
    test "only ever moves a room forward in revision" do
      id = "construct:#store-#{System.unique_integer([:positive])}"
      tree = %{id: "t", kind: "tree", x: 9, y: 9, dir: "down", placed_by: "alice"}

      assert %{items: [], revision: 0} = Store.load(id)
      assert :ok = Store.save(id, [tree], 2, "alice")
      # A write that left later but arrived first must not be undone by the older one.
      assert :ok = Store.save(id, [], 1, "bob")

      assert %{revision: 2, items: [%{"id" => "t"}]} = Store.load(id)
      assert :ok = Store.save(id, [], 3, "bob")
      assert %{revision: 3, items: []} = Store.load(id)
    end
  end

  describe "a channel space is not buildable" do
    test "building there is refused" do
      ctx = channel_with(["alice"])
      {:ok, _} = VirtualSpace.join_channel_space(ctx.channel, %{user_id: nil, nickname: "alice"})

      on_exit(fn ->
        case Registry.lookup({:channel_space, ctx.channel}) do
          {:ok, pid} -> GenServer.stop(pid, :normal)
          _ -> :ok
        end
      end)

      assert {:error, :not_buildable} =
               ChannelSpaceServer.build(ctx.channel, key("alice"), {:remove, "x"})
    end
  end
end
