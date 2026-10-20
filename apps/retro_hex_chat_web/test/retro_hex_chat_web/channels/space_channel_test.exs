defmodule RetroHexChatWeb.SpaceChannelTest do
  use RetroHexChatWeb.ChannelCase, async: false

  alias RetroHexChat.Accounts.NickLocales
  alias RetroHexChat.Channels.Registry, as: ChannelRegistry
  alias RetroHexChat.Channels.{Server, Supervisor}
  alias RetroHexChat.Presence.Tracker
  alias RetroHexChat.Services.NickServ

  alias RetroHexChat.VirtualSpace.{
    ChannelJoinToken,
    ChannelSpaceServer,
    CharacterRecipe,
    DirectMessageSpace,
    Registry
  }

  alias RetroHexChat.VirtualSpace.Map, as: SpaceMap
  alias RetroHexChatWeb.UserSocket

  @moduletag :integration

  setup do
    Application.put_env(:retro_hex_chat, :virtual_space_step_ms, 0)
    on_exit(fn -> Application.delete_env(:retro_hex_chat, :virtual_space_step_ms) end)
    :ok
  end

  defp uid, do: System.unique_integer([:positive])

  defp unique_channel, do: "#space-channel-#{uid()}"

  defp unique_dm_participants do
    suffix = uid()
    ["dm_alice_#{suffix}", "dm_bob_#{suffix}"]
  end

  defp participant_key(nickname), do: "nick:#{String.downcase(nickname)}"

  defp track_online(nickname) do
    assert {:ok, _ref} = Tracker.track_user("presence:global", nickname)
    Process.sleep(50)
  end

  defp start_channel(channel) do
    {:ok, pid} = Supervisor.start_child(channel)

    on_exit(fn ->
      case Registry.lookup({:channel_space, channel}) do
        {:ok, space_pid} -> GenServer.stop(space_pid, :normal)
        {:error, :not_found} -> :ok
      end

      case ChannelRegistry.lookup(channel) do
        {:ok, ^pid} -> Supervisor.stop_child(pid)
        _ -> :ok
      end
    end)

    {:ok, pid}
  end

  defp join_channel_space(channel, nickname, opts \\ []) do
    {:ok, socket} = connect(UserSocket, %{})

    signed_channel = Keyword.get(opts, :signed_channel, channel)
    signed_nick = Keyword.get(opts, :signed_nick, nickname)

    join_token =
      Keyword.get_lazy(opts, :token, fn ->
        ChannelJoinToken.sign(signed_channel, nil, signed_nick)
      end)

    params =
      case Keyword.get(opts, :avatar) do
        nil -> %{"join_token" => join_token}
        avatar -> %{"join_token" => join_token, "avatar" => avatar}
      end

    subscribe_and_join(socket, "space:#{channel}", params)
  end

  defp join_direct_message_space(space_id, nickname, participants, opts \\ []) do
    {:ok, socket} = connect(UserSocket, %{})

    signed_space_id = Keyword.get(opts, :signed_space_id, space_id)
    signed_nick = Keyword.get(opts, :signed_nick, nickname)
    signed_participants = Keyword.get(opts, :signed_participants, participants)

    join_token =
      Keyword.get_lazy(opts, :token, fn ->
        ChannelJoinToken.sign_direct_message(
          signed_space_id,
          nil,
          signed_nick,
          signed_participants
        )
      end)

    subscribe_and_join(socket, "space:#{space_id}", %{"join_token" => join_token})
  end

  defp cleanup_direct_message_space(space_id) do
    on_exit(fn ->
      case Registry.lookup({:direct_message_space, space_id}) do
        {:ok, space_pid} -> GenServer.stop(space_pid, :normal)
        {:error, :not_found} -> :ok
      end
    end)
  end

  # Drives the socket's participant to a target tile with valid input steps.
  defp walk_channel_to(socket, channel, key, {tx, ty}) do
    {:ok, state} = ChannelSpaceServer.get_state(channel)
    %{x: x, y: y} = state.participants[key]

    step =
      cond do
        x < tx -> %{"dx" => 1, "dy" => 0}
        x > tx -> %{"dx" => -1, "dy" => 0}
        y < ty -> %{"dx" => 0, "dy" => 1}
        y > ty -> %{"dx" => 0, "dy" => -1}
        true -> nil
      end

    if step do
      push(socket, "space_input", Map.put(step, "seq", uid()))
      assert_push "space_delta", %{}
      walk_channel_to(socket, channel, key, {tx, ty})
    else
      :ok
    end
  end

  defp separated?(positions) do
    positions
    |> Enum.with_index()
    |> Enum.all?(fn {{x, y}, index} ->
      positions
      |> Enum.with_index()
      |> Enum.all?(fn
        {_other, ^index} -> true
        {{other_x, other_y}, _other_index} -> max(abs(x - other_x), abs(y - other_y)) > 1
      end)
    end)
  end

  defp visually_clear_spawn?(blocked, {x, y}) do
    Enum.all?((y - 2)..y, fn tile_y ->
      Enum.all?((x - 1)..(x + 1), fn tile_x ->
        not MapSet.member?(blocked, {tile_x, tile_y})
      end)
    end)
  end

  describe "join" do
    test "channel spaces join by channel name and mirror current channel members" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)
      {:ok, _} = Server.join(channel, "alice")
      {:ok, _} = Server.join(channel, "bob")

      assert {:ok, space_init, _socket} = join_channel_space(channel, "alice")

      assert space_init.version == 1
      assert space_init.channel_name == channel
      assert space_init.self_key == "nick:alice"
      assert space_init.map.id == "end_of_time"
      assert is_list(space_init.map.collision)
      assert is_list(space_init.map.seats)
      assert space_init.map.tile_size == 32
      # The client paces held-key repeat steps to the server's step cooldown.
      assert space_init.config.step_ms == RetroHexChat.VirtualSpace.step_ms()
      assert is_integer(space_init.snapshot.server_time)
      assert Map.has_key?(space_init.snapshot.participants, "nick:alice")
      assert Map.has_key?(space_init.snapshot.participants, "nick:bob")
    end

    test "a tampered channel_join_token is refused" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)
      {:ok, _} = Server.join(channel, "alice")

      forged = ChannelJoinToken.sign(channel, nil, "alice") <> "x"

      assert {:error, %{reason: "invalid_token"}} =
               join_channel_space(channel, "alice", token: forged)
    end

    test "a channel_join_token for another channel is refused" do
      channel = unique_channel()
      other_channel = unique_channel()
      {:ok, _pid} = start_channel(channel)
      {:ok, _} = Server.join(channel, "alice")

      assert {:error, %{reason: "invalid_token"}} =
               join_channel_space(channel, "alice", signed_channel: other_channel)
    end

    test "non-channel space topics are rejected" do
      {:ok, socket} = connect(UserSocket, %{})
      join_token = ChannelJoinToken.sign("#lobby", nil, "alice")

      assert {:error, %{reason: "not_found"}} =
               subscribe_and_join(socket, "space:lobby-token", %{"join_token" => join_token})
    end

    test "channel spaces reject a signed nickname that is not in the channel" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)
      {:ok, _} = Server.join(channel, "alice")

      assert {:error, %{reason: "not_in_channel"}} = join_channel_space(channel, "mallory")
    end

    test "direct message spaces use the End of Time scene and show only members in the space" do
      [local, peer] = participants = unique_dm_participants()
      # The peer is connected to the chat but has not entered the space.
      track_online(peer)
      space_id = DirectMessageSpace.space_id(local, peer)
      cleanup_direct_message_space(space_id)

      assert {:ok, space_init, _socket} =
               join_direct_message_space(space_id, local, participants)

      assert space_init.version == 1
      assert space_init.channel_name == space_id
      assert space_init.self_key == participant_key(local)
      assert space_init.map.id == "end_of_time"
      assert space_init.map.width == 96
      assert space_init.map.height == 72

      expected_label = "#{local} + #{peer}"

      assert %{text: ^expected_label} =
               Enum.find(space_init.map.labels, &(&1.id == "dm_nameplate"))

      # Being online in the app is not enough: only members present in the space
      # are shown, so the peer's seat stays empty (no orphan nickname).
      assert Map.keys(space_init.snapshot.participants) == [participant_key(local)]
      refute Map.has_key?(space_init.snapshot.participants, participant_key(peer))
    end

    test "a direct message peer appears once they enter the space" do
      [local, peer] = participants = unique_dm_participants()
      space_id = DirectMessageSpace.space_id(local, peer)
      cleanup_direct_message_space(space_id)

      assert {:ok, _local_init, _s1} =
               join_direct_message_space(space_id, local, participants)

      assert {:ok, peer_init, _s2} =
               join_direct_message_space(space_id, peer, participants)

      assert Map.keys(peer_init.snapshot.participants) |> Enum.sort() ==
               [participant_key(local), participant_key(peer)] |> Enum.sort()
    end

    test "direct message spaces reject a signed nickname outside the conversation" do
      participants = ["alice", "bob"]
      space_id = DirectMessageSpace.space_id("alice", "bob")
      cleanup_direct_message_space(space_id)

      assert {:error, %{reason: "invalid_token"}} =
               join_direct_message_space(space_id, "charlie", participants,
                 signed_nick: "charlie"
               )
    end

    test "direct message spaces reject a token for another private room" do
      space_id = DirectMessageSpace.space_id("alice", "bob")
      other_space_id = DirectMessageSpace.space_id("alice", "charlie")
      cleanup_direct_message_space(space_id)
      cleanup_direct_message_space(other_space_id)

      assert {:error, %{reason: "invalid_token"}} =
               join_direct_message_space(space_id, "alice", ["alice", "charlie"],
                 signed_space_id: other_space_id
               )
    end

    test "channel spaces expand spawn positions beyond the seed spawn with clearance" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      nicks = for idx <- 1..9, do: "spawn#{idx}"
      Enum.each(nicks, fn nick -> assert {:ok, _} = Server.join(channel, nick) end)

      assert {:ok, space_init, _socket} = join_channel_space(channel, "spawn1")

      positions =
        space_init.snapshot.participants
        |> Map.values()
        |> Enum.map(&{&1.x, &1.y})

      blocked = SpaceMap.collision_set(space_init.map)

      assert length(Enum.uniq(positions)) == 9
      assert Enum.all?(positions, &(not MapSet.member?(blocked, &1)))
      assert separated?(positions)
      assert Enum.all?(positions, &visually_clear_spawn?(blocked, &1))
    end
  end

  describe "presence and chat" do
    test "channel spaces mirror joins, parts and public channel messages as bubbles" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)
      {:ok, _} = Server.join(channel, "alice")

      assert {:ok, _space_init, _socket} = join_channel_space(channel, "alice")

      {:ok, _} = Server.join(channel, "bob")
      assert_push "space_delta", %{joined: %{"nick:bob" => %{nickname: "bob"}}}

      {:ok, _id} = Server.send_message(channel, "alice", "hello from chat")

      assert_push "space_message", %{
        key: "nick:alice",
        nickname: "alice",
        text: "hello from chat"
      }

      :ok = Server.part(channel, "bob")
      assert_push "space_delta", %{left: ["nick:bob"]}
    end
  end

  describe "movement" do
    test "a valid space_input push moves the participant and broadcasts a delta" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)
      {:ok, _} = Server.join(channel, "alice")

      assert {:ok, init, socket} = join_channel_space(channel, "alice")
      self_key = init.self_key
      %{x: x0, y: y0} = init.snapshot.participants[self_key]

      push(socket, "space_input", %{"seq" => 1, "dx" => 1, "dy" => 0})

      assert_push "space_delta", %{seq_ack: seq_ack, updates: updates}
      assert seq_ack[self_key] == 1
      assert updates[self_key].x == x0 + 1
      assert updates[self_key].dir == "right"

      {:ok, state} = ChannelSpaceServer.get_state(channel)
      assert {state.participants[self_key].x, state.participants[self_key].y} == {x0 + 1, y0}
    end
  end

  describe "visual actions" do
    # Actions in a row: the cooldown between them is the server's own test.
    setup do
      Application.put_env(:retro_hex_chat, :virtual_space_action_ms, 0)
      on_exit(fn -> Application.delete_env(:retro_hex_chat, :virtual_space_action_ms) end)
      :ok
    end

    test "a space_action sword push broadcasts a visual action without moving the participant" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)
      {:ok, _} = Server.join(channel, "alice")

      assert {:ok, init, socket} = join_channel_space(channel, "alice")
      self_key = init.self_key
      %{x: x0, y: y0} = init.snapshot.participants[self_key]

      push(socket, "space_action", %{"kind" => "sword", "dir" => "left"})

      assert_push "space_action", %{
        key: ^self_key,
        kind: "sword",
        dir: "left"
      }

      {:ok, state} = ChannelSpaceServer.get_state(channel)
      assert {state.participants[self_key].x, state.participants[self_key].y} == {x0, y0}
    end

    test "a wave is pushed to the space, a dance comes back as the pose, anything else is dropped" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)
      {:ok, _} = Server.join(channel, "alice")

      assert {:ok, init, socket} = join_channel_space(channel, "alice")
      self_key = init.self_key

      push(socket, "space_action", %{"kind" => "wave"})
      assert_push "space_action", %{key: ^self_key, kind: "wave"}

      push(socket, "space_action", %{"kind" => "dance"})
      assert_push "space_delta", %{updates: %{^self_key => %{pose: "dancing"}}}

      push(socket, "space_action", %{"kind" => "moonwalk"})
      refute_push "space_action", %{kind: "moonwalk"}, 100
    end
  end

  describe "language flags" do
    # The nameplate's flag is the language the person uses the chat in: the
    # screen they have open for somebody here, the row's memory for a member
    # who is not.
    test "every seat carries its person's language, and the join names the flags" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)
      member = "flagmember#{uid()}"
      {:ok, _} = NickServ.register(member, "password123")
      :ok = NickLocales.remember(member, "ja", store: true)
      {:ok, _} = Server.join(channel, "alice")
      {:ok, _} = Server.join(channel, member)
      assert {:ok, _ref} = Tracker.track_user("presence:global", "alice", %{locale: "es"})

      assert {:ok, init, _socket} = join_channel_space(channel, "alice")

      assert init.snapshot.participants[init.self_key].locale == "es"
      assert init.snapshot.participants[participant_key(member)].locale == "ja"
      assert "data:image/svg+xml;base64," <> encoded = init.config.flags["es"]
      svg = Base.decode64!(encoded)
      assert svg =~ ~s(<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14")
      assert svg =~ "<rect"
      refute svg =~ "data-phx"
      assert Map.has_key?(init.config.flags, "pt_BR")
    end
  end

  describe "avatar selection" do
    @tunic "c1.b-av.s-2.o-tun-0-3.h-lng-2.w-0.f-0"
    @bald "c1.b-av.s-5.o-bas-0-0.h-0.w-0.f-0"

    # The client makes the character before the canvas mounts and names it in
    # the join params, so the snapshot already wears it rather than showing a
    # stranger who changes a moment later.
    test "the character named at join is what the snapshot already wears" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)
      {:ok, _} = Server.join(channel, "alice")

      assert {:ok, init, _socket} = join_channel_space(channel, "alice", avatar: @tunic)

      assert init.snapshot.participants[init.self_key].avatar == @tunic
    end

    test "a recipe named at join that the art cannot compose leaves the seat's own" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)
      {:ok, _} = Server.join(channel, "alice")

      assert {:ok, init, _socket} = join_channel_space(channel, "alice", avatar: "wizard")

      assert init.snapshot.participants[init.self_key].avatar ==
               CharacterRecipe.random(init.self_key)
    end

    test "a space_select_avatar push swaps the character and broadcasts a delta" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)
      {:ok, _} = Server.join(channel, "alice")

      assert {:ok, init, socket} = join_channel_space(channel, "alice")
      self_key = init.self_key

      push(socket, "space_select_avatar", %{"avatar" => @bald})

      # Match the selection delta specifically (a join presence delta also fires).
      assert_push "space_delta", %{updates: %{^self_key => %{avatar: @bald}}}

      {:ok, state} = ChannelSpaceServer.get_state(channel)
      assert state.participants[self_key].avatar == @bald
    end

    test "a recipe the art cannot compose leaves the character as it was" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)
      {:ok, _} = Server.join(channel, "alice")

      assert {:ok, init, socket} = join_channel_space(channel, "alice")
      before = init.snapshot.participants[init.self_key].avatar

      push(socket, "space_select_avatar", %{"avatar" => "dragon_lord"})
      # Round-trip a benign call so the invalid push is fully processed first.
      {:ok, state} = ChannelSpaceServer.get_state(channel)
      assert state.participants[init.self_key].avatar == before
    end
  end

  describe "interactions" do
    test "a space_interact use on a board pushes a space_modal to the requester" do
      # The production End of Time has no interactables; inject a fixture map with
      # a notice board so this exercises the channel's interaction round-trip.
      Application.put_env(:retro_hex_chat, :channel_space_map_override, channel_fixture_map())
      on_exit(fn -> Application.delete_env(:retro_hex_chat, :channel_space_map_override) end)

      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)
      {:ok, _} = Server.join(channel, "alice")

      assert {:ok, init, socket} = join_channel_space(channel, "alice")

      # Walk beside the notice_board at (4,15) and interact.
      walk_channel_to(socket, channel, init.self_key, {3, 15})

      push(socket, "space_interact", %{"seq" => 1, "kind" => "use", "target_id" => "notice_board"})

      assert_push "space_modal", %{asset: "board_menu_v1", title: "Notice board"}
    end
  end

  # A minimal isometric channel map with a reachable notice board, injected for
  # interaction tests since the production End of Time carries no interactables.
  defp channel_fixture_map do
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
      labels: [],
      collision: [],
      zones: [%{id: "spawn", kind: "zone", x: 0, y: 0, w: 40, h: 24}],
      interactables: [
        %{
          id: "notice_board",
          x: 4,
          y: 15,
          title: "Notice board",
          modal: %{kind: "image", asset: "board_menu_v1"}
        }
      ],
      seats: []
    }
  end

  describe "leave" do
    test "closing the last channel-space socket hibernates the runtime space" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)
      {:ok, _} = Server.join(channel, "alice")

      assert {:ok, _init, socket} = join_channel_space(channel, "alice")

      Process.unlink(socket.channel_pid)
      :ok = close(socket)

      wait_until(fn ->
        Registry.lookup({:channel_space, channel}) == {:error, :not_found}
      end)
    end
  end

  describe "a Construct" do
    setup do
      Application.put_env(:retro_hex_chat, :virtual_space_build_ms, 0)
      on_exit(fn -> Application.delete_env(:retro_hex_chat, :virtual_space_build_ms) end)

      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)
      {:ok, _} = Server.join(channel, "alice")
      {:ok, _} = Server.join(channel, "bob")
      construct_id = "construct:" <> channel

      on_exit(fn ->
        case Registry.lookup({:construct_space, construct_id}) do
          {:ok, pid} -> GenServer.stop(pid, :normal)
          {:error, :not_found} -> :ok
        end
      end)

      %{channel: channel, construct_id: construct_id}
    end

    defp join_construct(construct_id, nickname, token \\ nil) do
      {:ok, socket} = connect(UserSocket, %{})
      token = token || ChannelJoinToken.sign_construct(construct_id, nil, nickname, nil)
      subscribe_and_join(socket, "space:" <> construct_id, %{"join_token" => token})
    end

    test "joins its own room, buildable, showing only who walked in", ctx do
      assert {:ok, init, _socket} = join_construct(ctx.construct_id, "alice")

      assert init.channel_name == ctx.construct_id
      assert init.map.id == "construct"
      assert init.config.buildable
      assert ~w(chair lamp sign arcade board screen) -- Map.keys(init.map.catalog) == []
      assert [_ | _] = init.map.materials
      assert Map.keys(init.snapshot.participants) == ["nick:alice"]
    end

    test "a token for the space itself, or for another Construct, is refused", ctx do
      space_token = ChannelJoinToken.sign(ctx.channel, nil, "alice")
      other = ChannelJoinToken.sign_construct("construct:#elsewhere", nil, "alice", nil)

      assert {:error, %{reason: "invalid_token"}} =
               join_construct(ctx.construct_id, "alice", space_token)

      assert {:error, %{reason: "invalid_token"}} =
               join_construct(ctx.construct_id, "alice", other)
    end

    test "somebody outside the channel is refused", ctx do
      assert {:error, %{reason: "not_in_channel"}} = join_construct(ctx.construct_id, "mallory")
    end

    test "the Game Room is joined on its own token, furnished with its cabinets", ctx do
      room_id = "game_room:" <> ctx.channel

      on_exit(fn ->
        case Registry.lookup({:construct_space, room_id}) do
          {:ok, pid} -> GenServer.stop(pid, :normal)
          {:error, :not_found} -> :ok
        end
      end)

      office_token = ChannelJoinToken.sign_construct("office:" <> ctx.channel, nil, "alice", nil)

      assert {:error, %{reason: "invalid_token"}} =
               join_construct(room_id, "alice", office_token)

      assert {:ok, init, _socket} = join_construct(room_id, "alice")
      assert init.map.id == "game_room"
      assert init.config.buildable
      assert Enum.any?(init.map.items, &(&1.fixed and &1.kind == "racing_arcade"))
    end

    test "the Office is joined the same way, furnished and buildable, on its own token", ctx do
      office_id = "office:" <> ctx.channel

      on_exit(fn ->
        case Registry.lookup({:construct_space, office_id}) do
          {:ok, pid} -> GenServer.stop(pid, :normal)
          {:error, :not_found} -> :ok
        end
      end)

      construct_token = ChannelJoinToken.sign_construct(ctx.construct_id, nil, "alice", nil)

      assert {:error, %{reason: "invalid_token"}} =
               join_construct(office_id, "alice", construct_token)

      assert {:ok, init, socket} = join_construct(office_id, "alice")
      assert init.map.id == "office"
      assert init.config.buildable
      assert [%{fixed: true} | _] = init.map.items

      ref =
        push(socket, "construct_build", %{
          "op" => "place",
          "kind" => "plant",
          "x" => 20,
          "y" => 20
        })

      assert_reply ref, :ok
    end

    test "an edit is answered, and redrawn for everyone from the layout broadcast", ctx do
      {:ok, _init, socket} = join_construct(ctx.construct_id, "alice")

      ref =
        push(socket, "construct_build", %{"op" => "place", "kind" => "tree", "x" => 18, "y" => 18})

      assert_reply ref, :ok, %{revision: 1}
      assert_push "construct_layout", %{revision: 1, items: [%{kind: "tree", id: id}]}

      ref =
        push(socket, "construct_build", %{"op" => "place", "kind" => "lamp", "x" => 18, "y" => 18})

      assert_reply ref, :error, %{reason: "occupied"}

      ref = push(socket, "construct_build", %{"op" => "rotate", "item_id" => id})
      assert_reply ref, :ok, %{revision: 2}

      ref = push(socket, "construct_build", %{"op" => "move", "item_id" => id, "x" => "far"})
      assert_reply ref, :error, %{reason: "invalid"}
    end

    test "a sign is written on and the floor painted through the same edit", ctx do
      {:ok, _init, socket} = join_construct(ctx.construct_id, "alice")

      ref =
        push(socket, "construct_build", %{"op" => "place", "kind" => "sign", "x" => 13, "y" => 13})

      assert_reply ref, :ok, %{revision: 1}
      assert_push "construct_layout", %{items: [%{id: id}]}

      ref = push(socket, "construct_build", %{"op" => "label", "item_id" => id, "text" => "Hi"})
      assert_reply ref, :ok, %{revision: 2}
      assert_push "construct_layout", %{labels: [%{text: "Hi"}]}

      paint = %{"op" => "paint", "x0" => 20, "y0" => 20, "x1" => 21, "y1" => 21}
      ref = push(socket, "construct_build", Map.put(paint, "material", "wood"))
      assert_reply ref, :ok, %{revision: 3}
      assert_push "construct_layout", %{revision: 3, floor: [_ | _]}

      ref = push(socket, "construct_build", Map.put(paint, "material", "lava"))
      assert_reply ref, :error, %{reason: "unknown_material"}

      too_long = String.duplicate("a", 401)

      ref =
        push(socket, "construct_build", %{"op" => "label", "item_id" => id, "text" => too_long})

      assert_reply ref, :error, %{reason: "invalid"}
    end

    test "E on a piece opens its panel, filled in for whoever pressed it", ctx do
      {:ok, _init, socket} = join_construct(ctx.construct_id, "alice")

      for {kind, x} <- [{"arcade", 13}, {"sign", 12}] do
        ref =
          push(socket, "construct_build", %{"op" => "place", "kind" => kind, "x" => x, "y" => 13})

        assert_reply ref, :ok, _revision
      end

      {:ok, state} = ChannelSpaceServer.get_state(ctx.construct_id)
      arcade = Enum.find(state.items, &(&1.kind == "arcade"))
      sign = Enum.find(state.items, &(&1.kind == "sign"))

      push(socket, "space_interact", %{"kind" => "use", "target_id" => "item:" <> arcade.id})
      assert_push "space_modal", %{kind: "arcade", games: [%{url: "/play/" <> _} | _]}

      push(socket, "space_interact", %{"kind" => "use", "target_id" => "item:" <> sign.id})
      assert_push "space_modal", %{kind: "sign", can_edit: true}
    end

    test "the End of Time is not buildable over the channel", ctx do
      {:ok, _init, socket} = join_channel_space(ctx.channel, "alice")

      push(socket, "construct_build", %{"op" => "remove", "item_id" => "x"})
      refute_reply_within(socket)
    end

    test "the last one out closes the room", ctx do
      {:ok, _init, socket} = join_construct(ctx.construct_id, "alice")
      Process.unlink(socket.channel_pid)
      :ok = close(socket)

      wait_until(fn ->
        Registry.lookup({:construct_space, ctx.construct_id}) == {:error, :not_found}
      end)
    end
  end

  # A push to an event the socket does not answer gets no reply at all.
  defp refute_reply_within(_socket), do: refute_receive(%Phoenix.Socket.Reply{}, 100)

  defp wait_until(fun, retries \\ 50) do
    cond do
      fun.() ->
        :ok

      retries == 0 ->
        flunk("condition never became true")

      true ->
        Process.sleep(10)
        wait_until(fun, retries - 1)
    end
  end
end
