defmodule RetroHexChat.GroupCall.RuntimeTest do
  use RetroHexChat.DataCase, async: false

  alias RetroHexChat.Channels.Registry, as: ChannelRegistry
  alias RetroHexChat.Channels.{Server, Supervisor}
  alias RetroHexChat.GroupCall
  alias RetroHexChat.GroupCall.{PeerSupervisor, Queries, Registry, RoomServer}
  alias RetroHexChat.Services.RegisteredNick

  @moduletag :integration

  setup do
    previous_trap_exit = Process.flag(:trap_exit, true)
    previous_port_range = Application.get_env(:retro_hex_chat, :sfu_ice_port_range)
    previous_ready_timeout = Application.get_env(:retro_hex_chat, :group_call_ready_timeout_ms)

    previous_peerless_timeout =
      Application.get_env(:retro_hex_chat, :group_call_peerless_timeout_ms)

    previous_reconnect_timeout =
      Application.get_env(:retro_hex_chat, :group_call_reconnect_timeout_ms)

    Application.put_env(:retro_hex_chat, :sfu_ice_port_range, [0])
    Application.put_env(:retro_hex_chat, :group_call_ready_timeout_ms, 5_000)
    Application.put_env(:retro_hex_chat, :group_call_peerless_timeout_ms, 20)
    Application.put_env(:retro_hex_chat, :group_call_reconnect_timeout_ms, 30)

    on_exit(fn ->
      Process.flag(:trap_exit, previous_trap_exit)
      restore_env(:sfu_ice_port_range, previous_port_range)
      restore_env(:group_call_ready_timeout_ms, previous_ready_timeout)
      restore_env(:group_call_peerless_timeout_ms, previous_peerless_timeout)
      restore_env(:group_call_reconnect_timeout_ms, previous_reconnect_timeout)
    end)

    :ok
  end

  defp restore_env(key, nil), do: Application.delete_env(:retro_hex_chat, key)
  defp restore_env(key, value), do: Application.put_env(:retro_hex_chat, key, value)

  defp uid, do: System.unique_integer([:positive])
  defp unique_channel, do: "#gcall#{uid()}"
  defp unique_nick(prefix), do: "#{prefix}#{uid()}" |> String.slice(0, 16)

  defp create_registered_nick(nickname) do
    {:ok, nick} =
      %RegisteredNick{}
      |> RegisteredNick.registration_changeset(%{nickname: nickname, password: "password123"})
      |> Repo.insert()

    nick
  end

  defp start_channel(channel) do
    {:ok, pid} = Supervisor.start_child(channel)

    on_exit(fn ->
      case ChannelRegistry.lookup(channel) do
        {:ok, ^pid} -> Supervisor.stop_child(pid)
        _ -> :ok
      end
    end)

    {:ok, pid}
  end

  defp cleanup_room(token) do
    on_exit(fn ->
      case Registry.lookup_room({:room, token}) do
        {:ok, pid} -> GenServer.stop(pid, :normal)
        {:error, :not_found} -> :ok
      end
    end)
  end

  defp create_call_with_member(channel_prefix, nick_prefix) do
    channel = "#gcall#{channel_prefix}#{uid()}"
    nick = create_registered_nick(unique_nick(nick_prefix))
    {:ok, _pid} = start_channel(channel)
    {:ok, _state} = Server.join(channel, nick.nickname, nil, identified: true)

    {:ok, %{room: room, token: token}} =
      GroupCall.create_channel_call(channel, %{user_id: nick.id, nickname: nick.nickname})

    cleanup_room(token)

    %{channel: channel, nick: nick, room: room, token: token}
  end

  defp join_call(ctx, nick \\ nil) do
    nick = nick || ctx.nick

    {:ok, payload} =
      GroupCall.join_call(
        ctx.token,
        %{user_id: nick.id, nickname: nick.nickname},
        self(),
        %{"browser" => "test"},
        %{}
      )

    assert_receive {:"$gen_cast", {:group_call_push, "group_call_offer", _payload}}, 2_000
    payload
  end

  defp join_channel_member(ctx, nick) do
    {:ok, _state} = Server.join(ctx.channel, nick.nickname, nil, identified: true)
    join_call(ctx, nick)
  end

  defp mark_ready(ctx, payload) do
    {:ok, room_pid} = Registry.lookup_room({:room, ctx.token})
    :ok = RoomServer.mark_ready(room_pid, payload.participant.id)
    wait_for_participant_status(payload.participant.id, "connected")
  end

  defp announce_media_tracks(ctx, payload, prefix) do
    {:ok, room_pid} = Registry.lookup_room({:room, ctx.token})

    Enum.each([:audio, :video], fn kind ->
      :ok =
        RoomServer.track_added(room_pid, payload.participant.id, %{
          kind: kind,
          webrtc_track_id: "#{prefix}-#{kind}-#{uid()}",
          stream_id: "#{prefix}-stream-#{uid()}",
          codec: codec_for(kind)
        })
    end)
  end

  defp codec_for(:audio), do: "opus"
  defp codec_for(:video), do: "vp8"

  defp wait_until(fun, retries \\ 50) do
    case fun.() do
      true ->
        :ok

      _other when retries <= 0 ->
        flunk("condition was not met before timeout")

      _other ->
        Process.sleep(10)
        wait_until(fun, retries - 1)
    end
  end

  defp wait_for_participant_status(participant_id, status, retries \\ 50) do
    wait_until(
      fn ->
        case Queries.get_participant(participant_id) do
          %{status: ^status} -> true
          _other -> false
        end
      end,
      retries
    )

    Queries.get_participant(participant_id)
  end

  defp simulate_ice_failure(room_id, participant_id) do
    {:ok, peer_pid} = Registry.lookup_peer({:peer, room_id, participant_id})
    peer_state = :sys.get_state(peer_pid)

    send(peer_pid, {:ex_webrtc, peer_state.pc, {:connection_state_change, :failed}})

    :ok
  end

  describe "create_channel_call/3" do
    test "creates a persisted room and starts the room server" do
      channel = unique_channel()
      nick = create_registered_nick(unique_nick("creator"))
      {:ok, _pid} = start_channel(channel)
      {:ok, _state} = Server.join(channel, nick.nickname, nil, identified: true)
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "channel:#{channel}")

      assert {:ok, %{room: room, token: token}} =
               GroupCall.create_channel_call(channel, %{user_id: nick.id, nickname: nick.nickname})

      cleanup_room(token)
      assert_receive {:group_call_started, %{channel: ^channel, token: ^token}}, 500

      assert room.channel_name == channel
      assert room.status == "open"
      assert GroupCall.active_room_for_channel(channel).id == room.id
      assert {:ok, _pid} = Registry.lookup_room({:room, token})
      assert {:ok, _pid} = Registry.lookup_room({:channel, channel})

      assert :ok = GroupCall.close_call(token, %{user_id: nick.id, nickname: nick.nickname})
      assert_receive {:group_call_ended, %{channel: ^channel, token: ^token}}, 500
    end

    test "rejects creation by a user who is not in the channel" do
      channel = unique_channel()
      nick = create_registered_nick(unique_nick("creator"))
      {:ok, _pid} = start_channel(channel)

      assert {:error, message} =
               GroupCall.create_channel_call(channel, %{
                 user_id: nick.id,
                 nickname: nick.nickname
               })

      assert message =~ "not in this channel"
    end
  end

  describe "join_call/5" do
    test "persists a joining participant and emits an SDP offer through the signal process" do
      channel = unique_channel()
      nick = create_registered_nick(unique_nick("member"))
      {:ok, _pid} = start_channel(channel)
      {:ok, _state} = Server.join(channel, nick.nickname, nil, identified: true)

      assert {:ok, %{room: room, token: token}} =
               GroupCall.create_channel_call(channel, %{user_id: nick.id, nickname: nick.nickname})

      cleanup_room(token)

      assert {:ok, payload} =
               GroupCall.join_call(
                 token,
                 %{user_id: nick.id, nickname: nick.nickname},
                 self(),
                 %{"browser" => "test"},
                 %{}
               )

      assert payload.room.token == token
      assert payload.participant.nickname == nick.nickname

      participant = Queries.get_participant(payload.participant.id)
      assert participant.room_id == room.id
      assert participant.status == "joining"

      assert_receive {:"$gen_cast",
                      {:group_call_push, "group_call_offer",
                       %{sdp: sdp, participant_id: participant_id, ice_servers: ice_servers}}},
                     2_000

      assert participant_id == participant.id
      assert is_binary(sdp)
      assert sdp =~ "v=0"
      assert is_list(ice_servers)
    end

    test "queues ICE candidates that arrive before the SDP answer" do
      ctx = create_call_with_member("icequeue", "member")
      payload = join_call(ctx)

      candidate = %{
        "candidate" => "candidate:1 1 udp 2122260223 127.0.0.1 54321 typ host",
        "sdpMid" => "0",
        "sdpMLineIndex" => 0
      }

      assert :ok = GroupCall.add_ice_candidate(ctx.token, payload.participant.id, candidate)

      {:ok, peer_pid} = Registry.lookup_peer({:peer, ctx.room.id, payload.participant.id})

      wait_until(fn ->
        case :sys.get_state(peer_pid).pending_remote_candidates do
          [_candidate] -> true
          _other -> false
        end
      end)

      assert [^candidate] = :sys.get_state(peer_pid).pending_remote_candidates
    end

    test "persists track lifecycle, mute state, leave, and peerless room closure" do
      ctx = create_call_with_member("track", "member")
      payload = join_call(ctx)

      {:ok, room_pid} = Registry.lookup_room({:room, ctx.token})

      :ok =
        RoomServer.track_added(room_pid, payload.participant.id, %{
          kind: :audio,
          webrtc_track_id: "audio-#{uid()}",
          stream_id: "stream-#{uid()}",
          codec: "opus"
        })

      assert_receive {:"$gen_cast",
                      {:group_call_push, "group_call_track_added",
                       %{track: %{id: track_id, status: "active"}}}},
                     2_000

      track = Queries.get_track(track_id)
      assert track.status == "active"

      assert :ok =
               GroupCall.set_media_state(ctx.token, payload.participant.id, %{
                 "audio" => false,
                 "video" => true
               })

      assert Queries.get_track(track_id).status == "muted"

      assert :ok = GroupCall.leave_call(ctx.token, payload.participant.id, "left")
      assert Queries.get_track(track_id).status == "ended"

      wait_until(fn -> Queries.get_room(ctx.room.id).status == "closed" end)
      assert Queries.get_room(ctx.room.id).status == "closed"
    end

    test "reconnects a briefly disconnected participant using the same product record" do
      ctx = create_call_with_member("reconnect", "member")
      payload = join_call(ctx)

      {:ok, room_pid} = Registry.lookup_room({:room, ctx.token})

      :ok =
        RoomServer.track_added(room_pid, payload.participant.id, %{
          kind: :audio,
          webrtc_track_id: "audio-#{uid()}",
          stream_id: "stream-#{uid()}",
          codec: "opus"
        })

      assert_receive {:"$gen_cast",
                      {:group_call_push, "group_call_track_added",
                       %{track: %{id: track_id, status: "active"}}}},
                     2_000

      assert :ok = PeerSupervisor.terminate_peer(ctx.room.id, payload.participant.id)

      disconnected =
        wait_for_participant_status(payload.participant.id, "disconnected")

      assert disconnected.disconnected_at
      assert disconnected.reason == "peer_down"
      assert Queries.get_track(track_id).status == "ended"

      rejoined = join_call(ctx)

      assert rejoined.participant.id == payload.participant.id

      participant = Queries.get_participant(payload.participant.id)
      assert participant.status == "joining"
      refute participant.disconnected_at
      refute participant.reason
    end

    test "marks a briefly disconnected participant as failed after reconnect timeout" do
      ctx = create_call_with_member("reconnect-timeout", "member")
      payload = join_call(ctx)

      assert :ok = PeerSupervisor.terminate_peer(ctx.room.id, payload.participant.id)

      assert %{status: "disconnected"} =
               wait_for_participant_status(payload.participant.id, "disconnected")

      failed = wait_for_participant_status(payload.participant.id, "failed")

      assert failed.left_at
      assert failed.reason == "reconnect_timeout"
    end

    test "keeps N:N track lifecycle coherent when a connected participant leaves" do
      ctx = create_call_with_member("nntracks", "owner")
      bob = create_registered_nick(unique_nick("bob"))
      carol = create_registered_nick(unique_nick("carol"))

      owner_payload = join_call(ctx)
      mark_ready(ctx, owner_payload)

      bob_payload = join_channel_member(ctx, bob)
      mark_ready(ctx, bob_payload)

      carol_payload = join_channel_member(ctx, carol)
      mark_ready(ctx, carol_payload)

      announce_media_tracks(ctx, owner_payload, "owner")
      announce_media_tracks(ctx, bob_payload, "bob")
      announce_media_tracks(ctx, carol_payload, "carol")

      wait_until(fn -> length(Queries.list_active_tracks(ctx.room.id)) == 6 end)

      assert ctx.room.id
             |> Queries.list_active_participants()
             |> Enum.map(& &1.nickname)
             |> Enum.sort() == Enum.sort([ctx.nick.nickname, bob.nickname, carol.nickname])

      assert :ok = GroupCall.leave_call(ctx.token, bob_payload.participant.id, "left")

      wait_until(fn -> length(Queries.list_active_tracks(ctx.room.id)) == 4 end)

      tracks = Queries.list_tracks(ctx.room.id)
      bob_tracks = Enum.filter(tracks, &(&1.participant_id == bob_payload.participant.id))
      surviving_tracks = Enum.reject(tracks, &(&1.participant_id == bob_payload.participant.id))

      assert length(bob_tracks) == 2
      assert Enum.all?(bob_tracks, &(&1.status == "ended"))
      assert Enum.all?(bob_tracks, &(&1.ended_reason == "left"))
      assert Enum.count(surviving_tracks, &(&1.status == "active")) == 4

      active_nicknames =
        ctx.room.id
        |> Queries.list_active_participants()
        |> Enum.map(& &1.nickname)

      assert bob.nickname not in active_nicknames
      assert ctx.nick.nickname in active_nicknames
      assert carol.nickname in active_nicknames
      assert Queries.get_room(ctx.room.id).status == "active"
    end

    test "records ICE failure as a specific disconnect reason before reconnect timeout" do
      ctx = create_call_with_member("ice-failed", "member")
      payload = join_call(ctx)

      assert :ok = simulate_ice_failure(ctx.room.id, payload.participant.id)

      disconnected =
        wait_for_participant_status(payload.participant.id, "disconnected")

      assert disconnected.reason == "ice_connection_failed"

      failed = wait_for_participant_status(payload.participant.id, "failed")

      assert failed.left_at
      assert failed.reason == "reconnect_timeout"
    end

    test "moderators can mute and kick lower-ranked participants" do
      ctx = create_call_with_member("mod", "owner")
      regular = create_registered_nick(unique_nick("regular"))
      {:ok, _state} = Server.join(ctx.channel, regular.nickname, nil, identified: true)

      owner_payload = join_call(ctx)
      regular_payload = join_call(ctx, regular)

      actor = %{user_id: ctx.nick.id, nickname: ctx.nick.nickname}

      assert {:ok, muted} =
               GroupCall.mute_participant(ctx.token, actor, regular_payload.participant.id)

      assert muted.media_state["audio"] == false
      assert muted.media_state["server_audio_muted"] == true

      assert_receive {:"$gen_cast",
                      {:group_call_push, "group_call_set_media_state", %{audio: false}}},
                     2_000

      assert :ok =
               GroupCall.set_media_state(ctx.token, regular_payload.participant.id, %{
                 "audio" => true,
                 "video" => true
               })

      still_muted = Queries.get_participant(regular_payload.participant.id)
      assert still_muted.media_state["audio"] == false
      assert still_muted.media_state["server_audio_muted"] == true

      assert :ok = GroupCall.kick_participant(ctx.token, actor, regular_payload.participant.id)
      assert Queries.get_participant(regular_payload.participant.id).status == "kicked"

      assert :ok = GroupCall.close_call(ctx.token, actor, "moderation")
      assert Queries.get_room(ctx.room.id).status == "closed"
      assert Queries.get_participant(owner_payload.participant.id).status == "left"
    end
  end
end
