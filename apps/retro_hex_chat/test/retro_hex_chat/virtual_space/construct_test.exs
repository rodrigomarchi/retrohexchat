defmodule RetroHexChat.VirtualSpace.ConstructTest do
  use RetroHexChat.DataCase, async: false

  alias RetroHexChat.Admin.GlobalMutes
  alias RetroHexChat.Channels.Registry, as: ChannelRegistry
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Channels.Supervisor, as: ChannelSupervisor
  alias RetroHexChat.Topics
  alias RetroHexChat.VirtualSpace
  alias RetroHexChat.VirtualSpace.ChannelSpaceServer
  alias RetroHexChat.VirtualSpace.Construct
  alias RetroHexChat.VirtualSpace.Construct.Store
  alias RetroHexChat.VirtualSpace.DirectMessageSpace
  alias RetroHexChat.VirtualSpace.Registry

  @moduletag :integration

  @gathering_grace_ms 20

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

  # The SessionRecorder announces a gathering's end as an empty roster on the
  # space's roster topic, after the session row is closed.
  defp subscribe_gathering_end(space_id) do
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.space_roster(space_id))
  end

  # Waits several graces for an end that must not come. What a stopped world
  # broadcast before it went down is already queued, so it is flushed first.
  defp refute_gathering_end(space_id) do
    flush_roster(space_id)

    refute_receive {:space_roster, %{space_id: ^space_id, participants: []}},
                   @gathering_grace_ms * 4
  end

  defp assert_gathering_end(token) do
    assert_receive {:space_roster, %{participants: []}}, 2_000

    case VirtualSpace.get_session(token) do
      {:ok, %{status: "closed"}} -> :ok
      _still_open -> assert_gathering_end(token)
    end
  end

  defp flush_roster(space_id) do
    receive do
      {:space_roster, %{space_id: ^space_id}} -> flush_roster(space_id)
    after
      0 -> :ok
    end
  end

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

      # The channel broadcasts the part while it handles the call, so the
      # Construct has it queued; a call into the Construct settles it.
      :ok = Server.part(ctx.channel, "bob", nil)
      {:ok, pid} = Registry.lookup({:construct_space, ctx.construct_id})
      _ = :sys.get_state(pid)
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

      # Spawned at (12,12); the gate stands at (10,10). Walk up to it.
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

      assert {:ok, 1} = place(ctx.construct_id, "alice", "table", 18, 18)

      assert_receive %{
        event: "construct_layout",
        payload: %{revision: 1, items: [%{kind: "table", x: 18, y: 18} = table]}
      }

      assert %{revision: 1, items: [%{"id" => id}]} = Store.load(ctx.construct_id)
      assert id == table.id

      assert {:ok, 2} =
               VirtualSpace.build_construct(
                 ctx.construct_id,
                 key("alice"),
                 "alice",
                 {:move, table.id, 19, 18}
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
      {:ok, _} = place(ctx.construct_id, "alice", "tree", 13, 12)

      assert {:error, :blocked} =
               ChannelSpaceServer.input(ctx.construct_id, key("alice"), %{seq: 1, dx: 1, dy: 0})
    end

    test "what was built is there the next time the room opens" do
      ctx = channel_with(["alice"])
      enter(ctx.construct_id, "alice")
      {:ok, _} = place(ctx.construct_id, "alice", "lamp", 20, 20)
      stop_construct(ctx.construct_id)

      joined = enter(ctx.construct_id, "alice")
      assert [%{kind: "lamp", x: 20, y: 20}] = joined.map.items
      assert {:ok, 2} = place(ctx.construct_id, "alice", "tree", 21, 21)
    end

    test "a placed chair can be sat in, and is left alone while it is" do
      ctx = channel_with(["alice"])
      enter(ctx.construct_id, "alice")
      {:ok, _} = place(ctx.construct_id, "alice", "chair", 14, 12)
      {:ok, state} = ChannelSpaceServer.get_state(ctx.construct_id)
      [seat] = state.map.seats
      [chair] = state.items

      # Spawned at (12,12); one step east is next to the chair.
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

      assert {:error, :not_participant} = place(ctx.construct_id, "bob", "tree", 18, 18)
      assert {:error, :not_found} = place("construct:#nowhere", "bob", "tree", 18, 18)
    end

    test "edits are paced per person" do
      Application.put_env(:retro_hex_chat, :virtual_space_build_ms, 60_000)
      ctx = channel_with(["alice"])
      enter(ctx.construct_id, "alice")

      assert {:ok, 1} = place(ctx.construct_id, "alice", "tree", 18, 18)
      assert {:error, :cooldown} = place(ctx.construct_id, "alice", "tree", 19, 19)
    end
  end

  describe "pieces in use" do
    defp use_piece(ctx, nickname, item) do
      VirtualSpace.interact(
        ctx.construct_id,
        key(nickname),
        %{kind: "use", target_id: "item:" <> item.id},
        nickname
      )
    end

    defp item_at(construct_id, x, y) do
      {:ok, state} = ChannelSpaceServer.get_state(construct_id)
      Enum.find(state.items, &(&1.x == x and &1.y == y))
    end

    test "a lamp switched off is seen by everyone inside and stays off" do
      ctx = channel_with(["alice"])
      enter(ctx.construct_id, "alice")
      {:ok, _} = place(ctx.construct_id, "alice", "lamp", 13, 13)
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "space:" <> ctx.construct_id)

      assert :ok = use_piece(ctx, "alice", item_at(ctx.construct_id, 13, 13))

      assert_receive %{
        event: "construct_layout",
        payload: %{revision: 2, items: [%{state: %{"on" => false}}], interactables: interactables}
      }

      assert Enum.any?(interactables, &(&1[:use] == "toggle_light"))

      assert %{revision: 2, items: [%{"state" => %{"on" => false}}]} =
               Store.load(ctx.construct_id)

      stop_construct(ctx.construct_id)
      joined = enter(ctx.construct_id, "alice")
      assert [%{state: %{"on" => false}}] = joined.map.items
    end

    test "a die rolled is said in the channel by whoever rolled it" do
      ctx = channel_with(["alice"])
      enter(ctx.construct_id, "alice")
      {:ok, _} = place(ctx.construct_id, "alice", "die", 13, 13)
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.channel(ctx.channel))

      assert :ok = use_piece(ctx, "alice", item_at(ctx.construct_id, 13, 13))

      assert_receive %{
        event: "new_message",
        payload: %{author: "alice", type: "action", content: "threw the dice and got " <> face}
      }

      assert String.to_integer(face) in 1..6
      assert %{state: %{"face" => rolled}} = item_at(ctx.construct_id, 13, 13)
      assert "#{rolled}" == face
    end

    test "a teleporter sends you to its twin" do
      ctx = channel_with(["alice"])
      enter(ctx.construct_id, "alice")
      {:ok, _} = place(ctx.construct_id, "alice", "teleporter", 13, 13)
      {:ok, _} = place(ctx.construct_id, "alice", "teleporter", 30, 30)

      assert :ok = use_piece(ctx, "alice", item_at(ctx.construct_id, 13, 13))
      {:ok, state} = ChannelSpaceServer.get_state(ctx.construct_id)
      assert %{x: 30, y: 30, pose: "standing"} = state.participants[key("alice")]
    end

    test "a sign opens its panel, and only somebody next to it can use it" do
      ctx = channel_with(["alice"])
      enter(ctx.construct_id, "alice")
      {:ok, _} = place(ctx.construct_id, "alice", "sign", 13, 13)
      {:ok, _} = place(ctx.construct_id, "alice", "sign", 30, 30)
      sign = item_at(ctx.construct_id, 13, 13)

      assert {:ok, %{modal: %{kind: "sign", item_id: id, placed_by: "alice"}}} =
               use_piece(ctx, "alice", sign)

      assert id == sign.id
      assert {:error, :too_far} = use_piece(ctx, "alice", item_at(ctx.construct_id, 30, 30))
    end

    test "a panel opens right after an edit, and holds back no edit after it" do
      Application.put_env(:retro_hex_chat, :virtual_space_build_ms, 60_000)
      ctx = channel_with(["alice"])
      enter(ctx.construct_id, "alice")
      {:ok, _} = place(ctx.construct_id, "alice", "sign", 13, 13)
      {:ok, before} = ChannelSpaceServer.get_state(ctx.construct_id)

      assert {:ok, %{modal: %{kind: "sign"}}} =
               use_piece(ctx, "alice", item_at(ctx.construct_id, 13, 13))

      {:ok, after_panel} = ChannelSpaceServer.get_state(ctx.construct_id)
      assert after_panel.build_times == before.build_times
    end

    test "the author writes on a sign; the muted cannot" do
      ctx = channel_with(["alice"])
      enter(ctx.construct_id, "alice")
      {:ok, _} = place(ctx.construct_id, "alice", "sign", 13, 13)
      sign = item_at(ctx.construct_id, 13, 13)
      label = {:label, sign.id, "Welcome"}

      assert {:ok, 2} =
               VirtualSpace.build_construct(ctx.construct_id, key("alice"), "alice", label)

      assert %{state: %{"text" => "Welcome"}} = item_at(ctx.construct_id, 13, 13)

      GlobalMutes.mute("alice")
      on_exit(fn -> GlobalMutes.unmute("alice") end)

      assert {:error, :muted} =
               VirtualSpace.build_construct(ctx.construct_id, key("alice"), "alice", label)
    end

    test "a board cannot be built in a private Construct" do
      space_id = DirectMessageSpace.space_id("alice", "bob")
      construct_id = VirtualSpace.construct_id(space_id)
      on_exit(fn -> stop_construct(construct_id) end)
      enter(construct_id, "alice", ["alice", "bob"])

      assert {:error, :unknown_kind} = place(construct_id, "alice", "board", 13, 13)
      assert {:ok, 1} = place(construct_id, "alice", "screen", 13, 13)
    end
  end

  describe "pieces bigger than a tile" do
    test "a sofa seats two, and either of them stops it being moved" do
      ctx = channel_with(["alice"])
      enter(ctx.construct_id, "alice")
      # Alice arrives at (12,12); the sofa runs from (13,13) down to (13,14).
      {:ok, _} = place(ctx.construct_id, "alice", "sofa", 13, 13)
      {:ok, state} = ChannelSpaceServer.get_state(ctx.construct_id)
      [sofa] = state.items
      seats = Enum.filter(state.map.seats, &(&1.item_id == sofa.id))
      assert [{13, 13}, {13, 14}] == Enum.map(seats, &{&1.x, &1.y})

      second = Enum.find(seats, &(&1.y == 14))
      :ok = ChannelSpaceServer.input(ctx.construct_id, key("alice"), %{seq: 1, dx: 0, dy: 1})
      :ok = ChannelSpaceServer.input(ctx.construct_id, key("alice"), %{seq: 2, dx: 0, dy: 1})

      assert :ok =
               VirtualSpace.interact(ctx.construct_id, key("alice"), %{
                 kind: "sit",
                 target_id: second.id
               })

      assert {:error, :seat_taken} =
               VirtualSpace.build_construct(
                 ctx.construct_id,
                 key("alice"),
                 "alice",
                 {:move, sofa.id, 30, 30}
               )
    end

    test "a long table blocks its far tile as well as its corner" do
      ctx = channel_with(["alice"])
      enter(ctx.construct_id, "alice")
      # Alice arrives at (12,12); the long table covers (14,12) and (14,13).
      {:ok, _} = place(ctx.construct_id, "alice", "long_table", 14, 12)

      move = fn seq, dx, dy ->
        ChannelSpaceServer.input(ctx.construct_id, key("alice"), %{seq: seq, dx: dx, dy: dy})
      end

      assert :ok = move.(1, 1, 0)
      assert {:error, :blocked} = move.(2, 1, 0)
      assert :ok = move.(3, 0, 1)
      assert {:error, :blocked} = move.(4, 1, 0)
    end
  end

  describe "painting the floor" do
    test "reaches everyone inside, and is there the next time the room opens" do
      ctx = channel_with(["alice"])
      enter(ctx.construct_id, "alice")
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "space:" <> ctx.construct_id)

      assert {:ok, 1} =
               VirtualSpace.build_construct(
                 ctx.construct_id,
                 key("alice"),
                 "alice",
                 {:paint, 20, 20, 22, 21, "carpet_red"}
               )

      assert_receive %{event: "construct_layout", payload: %{revision: 1, floor: rows}}
      assert String.at(Enum.at(rows, 21), 22) == "4"
      assert %{floor: floor} = Store.load(ctx.construct_id)
      assert is_binary(floor)

      # A later edit that paints nothing keeps the floor, and sends no rows.
      {:ok, 2} = place(ctx.construct_id, "alice", "tree", 30, 30)
      assert_receive %{event: "construct_layout", payload: %{revision: 2} = patch}
      refute Map.has_key?(patch, :floor)
      assert %{floor: ^floor} = Store.load(ctx.construct_id)

      stop_construct(ctx.construct_id)
      joined = enter(ctx.construct_id, "alice")
      assert String.at(Enum.at(joined.map.layers.floor, 20), 20) == "4"
    end
  end

  describe "a gathering through the gate" do
    setup do
      Application.put_env(:retro_hex_chat, :virtual_space_gathering_grace_ms, @gathering_grace_ms)

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
      subscribe_gathering_end(ctx.channel)
      stop_world({:channel_space, ctx.channel})
      refute_gathering_end(ctx.channel)
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
      assert_gathering_end(token)

      assert {:ok, %{status: "closed", closed_reason: "emptied"}} =
               VirtualSpace.get_session(token)
    end
  end

  describe "Store.save/4" do
    test "only ever moves a room forward in revision" do
      id = "construct:#store-#{System.unique_integer([:positive])}"
      tree = %{id: "t", kind: "tree", x: 9, y: 9, dir: "down", placed_by: "alice"}

      assert %{items: [], revision: 0} = Store.load(id)
      assert :ok = Store.save(id, %{items: [tree], floor: nil}, 2, "alice")
      # A write that left later but arrived first must not be undone by the older one.
      assert :ok = Store.save(id, %{items: [], floor: nil}, 1, "bob")

      assert %{revision: 2, items: [%{"id" => "t"}]} = Store.load(id)
      assert :ok = Store.save(id, %{items: [], floor: nil}, 3, "bob")
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

  describe "a room's id" do
    test "names its kind and the space it belongs to, once" do
      assert Construct.space_id("#c", :office) == "office:#c"
      assert Construct.space_id("dm:a:b") == "construct:dm:a:b"
      assert {:ok, :office} = Construct.kind("office:dm:a:b")
      assert {:ok, "dm:a:b"} = Construct.parent_id("office:dm:a:b")
      assert Construct.map_id("office:#c") == "office"
      assert Construct.map_id("construct:#c") == "construct"
      assert VirtualSpace.space_kind("office:#c") == :construct

      for id <- ~w(office:construct:#c construct:office:#c office: office:# office:lobby) do
        refute Construct.construct?(id), id
      end

      assert Construct.space_id("#c", :game_room) == "game_room:#c"
      assert {:ok, :game_room} = Construct.kind("game_room:dm:a:b")
      assert Construct.map_id("game_room:#c") == "game_room"

      for id <- ~w(game_room:office:#c office:game_room:#c game_room: game_room:lobby) do
        refute Construct.construct?(id), id
      end
    end
  end

  describe "the Game Room" do
    setup do
      ctx = channel_with(["alice", "bob"])
      room_id = VirtualSpace.construct_id(ctx.channel, :game_room)
      on_exit(fn -> stop_construct(room_id) end)
      Map.put(ctx, :room_id, room_id)
    end

    test "its door stands beside the Office's and asks first" do
      {:ok, map} = VirtualSpace.get_map("end_of_time")

      assert %{x: 39, y: 28, modal: %{kind: "confirm", action: "enter_game_room"}} =
               Enum.find(map.interactables, &(&1.id == "game_room_portal"))
    end

    test "comes furnished with arcade cabinets that stay where they are", ctx do
      joined = enter(ctx.room_id, "alice")

      assert joined.map.id == "game_room"
      cabinet = Enum.find(joined.map.items, &(&1.fixed and &1.kind == "arcade"))
      assert cabinet

      assert {:error, :fixed} =
               VirtualSpace.build_construct(
                 ctx.room_id,
                 key("alice"),
                 "alice",
                 {:remove, cabinet.id}
               )
    end

    test "takes pieces, kept apart from the Construct's and the Office's", ctx do
      enter(ctx.room_id, "alice")
      assert {:ok, 1} = place(ctx.room_id, "alice", "plant", 20, 20)

      assert %{revision: 1, items: items} = Store.load(ctx.room_id)
      assert Enum.any?(items, &(&1["kind"] == "plant"))
      assert %{revision: 0, items: []} = Store.load(ctx.construct_id)

      assert %{revision: 0, items: []} =
               Store.load(VirtualSpace.construct_id(ctx.channel, :office))
    end

    test "whoever is in it is in the space", ctx do
      enter(ctx.room_id, "bob")
      assert "bob" in VirtualSpace.roster(ctx.channel)
    end
  end

  describe "the Office" do
    setup do
      ctx = channel_with(["alice", "bob"])
      office_id = VirtualSpace.construct_id(ctx.channel, :office)
      on_exit(fn -> stop_construct(office_id) end)
      Map.put(ctx, :office_id, office_id)
    end

    test "its door stands on the End of Time and asks before taking anyone in" do
      {:ok, map} = VirtualSpace.get_map("end_of_time")

      assert %{x: 42, y: 28, modal: %{kind: "confirm", action: "enter_office"}} =
               Enum.find(map.interactables, &(&1.id == "office_portal"))
    end

    test "comes furnished, and its furniture stays where it is", ctx do
      joined = enter(ctx.office_id, "alice")

      assert joined.map.id == "office"
      assert [%{id: "fixed:" <> _} = piece | _] = Enum.filter(joined.map.items, & &1.fixed)

      assert {:error, :fixed} =
               VirtualSpace.build_construct(
                 ctx.office_id,
                 key("alice"),
                 "alice",
                 {:remove, piece.id}
               )
    end

    test "takes pieces like the Construct, kept apart from the Construct's", ctx do
      enter(ctx.office_id, "alice")
      assert {:ok, 1} = place(ctx.office_id, "alice", "plant", 20, 20)

      assert %{revision: 1, items: items} = Store.load(ctx.office_id)
      assert Enum.any?(items, &(&1["kind"] == "plant"))
      assert %{revision: 0, items: []} = Store.load(ctx.construct_id)

      stop_construct(ctx.office_id)
      joined = enter(ctx.office_id, "alice")
      assert Enum.any?(joined.map.items, &(&1.kind == "plant" and &1.x == 20))
    end

    test "a private space's Office admits the pair and nobody else" do
      suffix = System.unique_integer([:positive])
      [a, b] = pair = ["off_a_#{suffix}", "off_b_#{suffix}"]
      office_id = VirtualSpace.construct_id(DirectMessageSpace.space_id(a, b), :office)
      on_exit(fn -> stop_construct(office_id) end)

      assert enter(office_id, a, pair).map.id == "office"

      assert {:error, :not_in_direct_message} =
               VirtualSpace.join_construct_space(
                 office_id,
                 %{user_id: nil, nickname: "intruder"},
                 pair
               )
    end

    test "a hop into it keeps the space's gathering open", ctx do
      Application.put_env(:retro_hex_chat, :virtual_space_gathering_grace_ms, @gathering_grace_ms)

      on_exit(fn ->
        Application.put_env(:retro_hex_chat, :virtual_space_gathering_grace_ms, 0)
      end)

      {:ok, opened} =
        VirtualSpace.join_channel_space(ctx.channel, %{user_id: nil, nickname: "alice"})

      enter(ctx.office_id, "alice")
      _ = :sys.get_state(VirtualSpace.SessionRecorder)
      subscribe_gathering_end(ctx.channel)

      {:ok, pid} = Registry.lookup({:channel_space, ctx.channel})
      ref = Process.monitor(pid)
      GenServer.stop(pid, :normal)
      assert_receive {:DOWN, ^ref, :process, ^pid, _reason}
      refute_gathering_end(ctx.channel)

      assert {:ok, %{status: "open"}} = VirtualSpace.get_session(opened.session.token)
    end

    test "whoever is in it is in the space", ctx do
      enter(ctx.office_id, "bob")
      assert "bob" in VirtualSpace.roster(ctx.channel)
    end
  end
end
