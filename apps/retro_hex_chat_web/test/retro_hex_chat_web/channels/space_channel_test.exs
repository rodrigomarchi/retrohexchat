defmodule RetroHexChatWeb.SpaceChannelTest do
  use RetroHexChatWeb.ChannelCase, async: false

  alias RetroHexChat.Channels.Registry, as: ChannelRegistry
  alias RetroHexChat.Channels.{Server, Supervisor}
  alias RetroHexChat.Presence.Tracker

  alias RetroHexChat.VirtualSpace.{
    ChannelJoinToken,
    ChannelSpaceServer,
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

    subscribe_and_join(socket, "space:#{channel}", %{"join_token" => join_token})
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

    test "direct message spaces omit a peer who is not in the space" do
      [local, peer] = participants = unique_dm_participants()
      space_id = DirectMessageSpace.space_id(local, peer)
      cleanup_direct_message_space(space_id)

      assert {:ok, space_init, _socket} =
               join_direct_message_space(space_id, local, participants)

      assert Map.keys(space_init.snapshot.participants) == [participant_key(local)]
      refute Map.has_key?(space_init.snapshot.participants, participant_key(peer))
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
  end

  describe "avatar selection" do
    test "a space_select_avatar push swaps the avatar and broadcasts a delta" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)
      {:ok, _} = Server.join(channel, "alice")

      assert {:ok, init, socket} = join_channel_space(channel, "alice")
      self_key = init.self_key
      assert init.snapshot.participants[self_key].avatar == "hero"

      push(socket, "space_select_avatar", %{"avatar" => "sorceress"})

      # Match the selection delta specifically (a join presence delta also fires).
      assert_push "space_delta", %{updates: %{^self_key => %{avatar: "sorceress"}}}

      {:ok, state} = ChannelSpaceServer.get_state(channel)
      assert state.participants[self_key].avatar == "sorceress"
    end

    test "an unknown avatar id leaves the participant on the default hero" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)
      {:ok, _} = Server.join(channel, "alice")

      assert {:ok, init, socket} = join_channel_space(channel, "alice")

      push(socket, "space_select_avatar", %{"avatar" => "dragon_lord"})
      # Round-trip a benign call so the invalid push is fully processed first.
      {:ok, state} = ChannelSpaceServer.get_state(channel)
      assert state.participants[init.self_key].avatar == "hero"
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
      parallax: [],
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
