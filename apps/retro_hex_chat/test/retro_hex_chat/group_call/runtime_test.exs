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

    previous_reaction_rate_limit =
      Application.get_env(:retro_hex_chat, :group_call_reaction_rate_limit)

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
      restore_env(:group_call_reaction_rate_limit, previous_reaction_rate_limit)
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

  defp ice_candidate(seq \\ 1) do
    %{
      "candidate" => "candidate:#{seq} 1 udp 2122260223 127.0.0.1 #{54_320 + seq} typ host",
      "sdpMid" => "0",
      "sdpMLineIndex" => 0
    }
  end

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

  # Returns the record that matched, never a fresh read taken afterwards. The
  # status this waits for is often a step on the way to another one — the
  # suite's 30 ms reconnect timer turns "disconnected" into "failed" — so a
  # second query hands back whatever came next, and the case asserting on the
  # step reads the state that replaced it.
  defp wait_for_participant_status(participant_id, status, retries \\ 50) do
    participant = Queries.get_participant(participant_id)

    cond do
      match?(%{status: ^status}, participant) ->
        participant

      retries <= 0 ->
        flunk("participant never reached status #{status}")

      true ->
        Process.sleep(10)
        wait_for_participant_status(participant_id, status, retries - 1)
    end
  end

  defp audit_events(room_id) when is_integer(room_id) do
    room_id
    |> Queries.get_room()
    |> Map.fetch!(:metadata)
    |> Map.get("audit_events", [])
  end

  defp audit_event_types(room_id) do
    room_id
    |> audit_events()
    |> Enum.map(&Map.get(&1, "type"))
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

      assert [%{"type" => "conference_started", "actor" => actor, "channel" => ^channel}] =
               room.metadata["audit_events"]

      assert actor == nick.nickname
      assert GroupCall.active_room_for_channel(channel).id == room.id
      assert {:ok, _pid} = Registry.lookup_room({:room, token})
      assert {:ok, _pid} = Registry.lookup_room({:channel, channel})

      assert :ok = GroupCall.close_call(token, %{user_id: nick.id, nickname: nick.nickname})
      assert_receive {:group_call_ended, %{channel: ^channel, token: ^token}}, 500

      assert audit_event_types(room.id) == ["conference_started", "conference_ended"]
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

      candidate = ice_candidate()

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

    test "rejects ICE candidates that arrive after participant leave" do
      ctx = create_call_with_member("icelate", "member")
      payload = join_call(ctx)
      participant_id = payload.participant.id

      assert :ok = GroupCall.leave_call(ctx.token, participant_id, "left")

      wait_until(fn ->
        Registry.lookup_peer({:peer, ctx.room.id, participant_id}) == {:error, :not_found}
      end)

      assert {:error, :not_found} =
               GroupCall.add_ice_candidate(ctx.token, participant_id, ice_candidate(2))
    end

    test "keeps ICE candidates queued while retry offer is still pending" do
      ctx = create_call_with_member("icestale", "member")
      payload = join_call(ctx)
      participant_id = payload.participant.id
      first_candidate = ice_candidate(1)
      stale_candidate = ice_candidate(2)

      assert :ok = GroupCall.add_ice_candidate(ctx.token, participant_id, first_candidate)
      assert :ok = GroupCall.request_offer(ctx.token, participant_id)

      assert_receive {:"$gen_cast",
                      {:group_call_push, "group_call_offer", %{participant_id: ^participant_id}}},
                     2_000

      assert :ok = GroupCall.add_ice_candidate(ctx.token, participant_id, stale_candidate)

      {:ok, peer_pid} = Registry.lookup_peer({:peer, ctx.room.id, participant_id})

      wait_until(fn ->
        case :sys.get_state(peer_pid).pending_remote_candidates do
          [^stale_candidate, ^first_candidate] -> true
          _other -> false
        end
      end)
    end

    test "request_offer sends a fresh ICE restart offer for retry" do
      ctx = create_call_with_member("retry", "member")
      payload = join_call(ctx)

      assert :ok = GroupCall.request_offer(ctx.token, payload.participant.id)

      assert_receive {:"$gen_cast",
                      {:group_call_push, "group_call_offer",
                       %{sdp: sdp, participant_id: participant_id, ice_servers: ice_servers}}},
                     2_000

      assert participant_id == payload.participant.id
      assert is_binary(sdp)
      assert sdp =~ "v=0"
      assert is_list(ice_servers)
    end

    test "broadcasts participant reactions and rate limits bursts" do
      Application.put_env(:retro_hex_chat, :group_call_reaction_rate_limit, {1, 60_000})

      ctx = create_call_with_member("react", "member")
      payload = join_call(ctx)
      actor = %{user_id: ctx.nick.id, nickname: ctx.nick.nickname}

      assert {:ok, reaction} =
               GroupCall.send_reaction(ctx.token, actor, payload.participant.id, "heart")

      assert reaction.participant_id == payload.participant.id
      assert reaction.nickname == ctx.nick.nickname
      assert reaction.reaction == "heart"

      assert_receive {:"$gen_cast",
                      {:group_call_push, "group_call_reaction",
                       %{participant_id: participant_id, reaction: "heart", emoji: _emoji}}},
                     2_000

      assert participant_id == payload.participant.id

      assert {:error, {:rate_limited, seconds}} =
               GroupCall.send_reaction(ctx.token, actor, payload.participant.id, "clap")

      assert seconds > 0
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

    test "preserves track metadata supplied with immediate track announcement" do
      ctx = create_call_with_member("trackmeta", "member")
      late = create_registered_nick(unique_nick("late"))
      payload = join_call(ctx)
      metadata = %{"label" => "updatedMetadataOnStart", "role" => "presenter"}

      {:ok, room_pid} = Registry.lookup_room({:room, ctx.token})

      :ok =
        RoomServer.track_added(room_pid, payload.participant.id, %{
          kind: :video,
          webrtc_track_id: "video-#{uid()}",
          stream_id: "stream-#{uid()}",
          codec: "vp8",
          metadata: metadata
        })

      assert_receive {:"$gen_cast",
                      {:group_call_push, "group_call_track_added",
                       %{track: %{id: track_id, metadata: ^metadata}}}},
                     2_000

      assert Queries.get_track(track_id).metadata == metadata

      {:ok, _state} = Server.join(ctx.channel, late.nickname, nil, identified: true)
      _late_payload = join_call(ctx, late)

      assert {:ok, %{tracks: tracks}} = GroupCall.get_summary(ctx.token)
      assert Enum.any?(tracks, &(&1.id == track_id and &1.metadata == metadata))
    end

    test "updates the active video track source during screen share lifecycle" do
      ctx = create_call_with_member("screen", "member")
      payload = join_call(ctx)

      {:ok, room_pid} = Registry.lookup_room({:room, ctx.token})

      :ok =
        RoomServer.track_added(room_pid, payload.participant.id, %{
          kind: :video,
          webrtc_track_id: "video-#{uid()}",
          stream_id: "stream-#{uid()}",
          codec: "vp8"
        })

      assert_receive {:"$gen_cast",
                      {:group_call_push, "group_call_track_added",
                       %{track: %{id: track_id, source: "camera", status: "active"}}}},
                     2_000

      assert {:ok, %{active: true, track: %{source: "screen"}}} =
               GroupCall.set_screen_share_state(ctx.token, payload.participant.id, true, %{
                 "track_id" => "screen-track",
                 "stream_id" => "screen-stream"
               })

      screen_track = Queries.get_track(track_id)
      assert screen_track.source == "screen"
      assert screen_track.metadata["screen_track_id"] == "screen-track"
      assert Queries.get_participant(payload.participant.id).media_state["screen"] == true

      assert {:ok, %{active: false, track: %{source: "camera"}}} =
               GroupCall.set_screen_share_state(ctx.token, payload.participant.id, false, %{})

      camera_track = Queries.get_track(track_id)
      assert camera_track.source == "camera"
      refute Map.has_key?(camera_track.metadata, "screen_track_id")
      assert Queries.get_participant(payload.participant.id).media_state["screen"] == false
    end

    test "moderators can stop and block participant screen sharing" do
      ctx = create_call_with_member("screenmod", "owner")
      regular = create_registered_nick(unique_nick("regular"))
      {:ok, _state} = Server.join(ctx.channel, regular.nickname, nil, identified: true)

      _owner_payload = join_call(ctx)
      regular_payload = join_call(ctx, regular)

      {:ok, room_pid} = Registry.lookup_room({:room, ctx.token})

      :ok =
        RoomServer.track_added(room_pid, regular_payload.participant.id, %{
          kind: :video,
          webrtc_track_id: "video-#{uid()}",
          stream_id: "stream-#{uid()}",
          codec: "vp8"
        })

      assert_receive {:"$gen_cast",
                      {:group_call_push, "group_call_track_added",
                       %{track: %{id: track_id, source: "camera"}}}},
                     2_000

      assert {:ok, %{active: true, track: %{source: "screen"}}} =
               GroupCall.set_screen_share_state(
                 ctx.token,
                 regular_payload.participant.id,
                 true,
                 %{
                   "track_id" => "screen-track",
                   "stream_id" => "screen-stream"
                 }
               )

      actor = %{user_id: ctx.nick.id, nickname: ctx.nick.nickname}

      assert {:ok, blocked} =
               GroupCall.block_participant_screen_share(
                 ctx.token,
                 actor,
                 regular_payload.participant.id
               )

      assert blocked.media_state["screen"] == false
      assert blocked.media_state["server_screen_blocked"] == true
      assert blocked.media_state["screen_blocked_by"] == ctx.nick.nickname
      refute Map.has_key?(blocked.media_state, "screen_track_id")

      assert_receive {:"$gen_cast",
                      {:group_call_push, "group_call_stop_screen_share",
                       %{reason: "moderation", server_screen_blocked: true}}},
                     2_000

      assert Queries.get_track(track_id).source == "camera"

      assert :ok =
               GroupCall.set_media_state(ctx.token, regular_payload.participant.id, %{
                 "audio" => true,
                 "video" => true,
                 "screen" => true
               })

      still_blocked = Queries.get_participant(regular_payload.participant.id)
      assert still_blocked.media_state["screen"] == false
      assert still_blocked.media_state["server_screen_blocked"] == true

      assert {:error, message} =
               GroupCall.set_screen_share_state(
                 ctx.token,
                 regular_payload.participant.id,
                 true,
                 %{
                   "track_id" => "blocked-screen-track"
                 }
               )

      assert message =~ "disabled by a moderator"

      assert {:ok, allowed} =
               GroupCall.unblock_participant_screen_share(
                 ctx.token,
                 actor,
                 regular_payload.participant.id
               )

      assert allowed.media_state["server_screen_blocked"] == false

      assert {:ok, %{active: true}} =
               GroupCall.set_screen_share_state(
                 ctx.token,
                 regular_payload.participant.id,
                 true,
                 %{
                   "track_id" => "allowed-screen-track"
                 }
               )
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
      # Both states have to be observable, and the suite's 30 ms timeout closes
      # the first one before a loaded CI box can look. The room captures its
      # config at start, so this goes before the call is created.
      Application.put_env(:retro_hex_chat, :group_call_reconnect_timeout_ms, 500)

      ctx = create_call_with_member("reconnect-timeout", "member")
      payload = join_call(ctx)

      assert :ok = PeerSupervisor.terminate_peer(ctx.room.id, payload.participant.id)

      assert %{status: "disconnected"} =
               wait_for_participant_status(payload.participant.id, "disconnected")

      failed = wait_for_participant_status(payload.participant.id, "failed", 150)

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
      # The suite runs a 30 ms reconnect timeout so other cases reach "failed"
      # without waiting. This one is about the state *before* that timer, and
      # 30 ms is not a window a CI box running three partitions can be relied on
      # to look inside — the room captures its config at start, so the wider
      # timeout has to be in place before the call is created.
      Application.put_env(:retro_hex_chat, :group_call_reconnect_timeout_ms, 500)

      ctx = create_call_with_member("ice-failed", "member")
      payload = join_call(ctx)

      assert :ok = simulate_ice_failure(ctx.room.id, payload.participant.id)

      disconnected =
        wait_for_participant_status(payload.participant.id, "disconnected")

      assert disconnected.reason == "ice_connection_failed"

      failed = wait_for_participant_status(payload.participant.id, "failed", 150)

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

      assert {:ok, video_blocked} =
               GroupCall.block_participant_video(ctx.token, actor, regular_payload.participant.id)

      assert video_blocked.media_state["video"] == false
      assert video_blocked.media_state["server_video_blocked"] == true
      assert video_blocked.media_state["video_blocked_by"] == ctx.nick.nickname

      assert_receive {:"$gen_cast",
                      {:group_call_push, "group_call_set_media_state", %{video: false}}},
                     2_000

      assert :ok =
               GroupCall.set_media_state(ctx.token, regular_payload.participant.id, %{
                 "audio" => false,
                 "video" => true
               })

      still_video_blocked = Queries.get_participant(regular_payload.participant.id)
      assert still_video_blocked.media_state["video"] == false
      assert still_video_blocked.media_state["server_video_blocked"] == true

      assert {:ok, video_unblocked} =
               GroupCall.unblock_participant_video(
                 ctx.token,
                 actor,
                 regular_payload.participant.id
               )

      assert video_unblocked.media_state["video"] == true
      assert video_unblocked.media_state["server_video_blocked"] == false

      assert :ok = GroupCall.kick_participant(ctx.token, actor, regular_payload.participant.id)
      assert Queries.get_participant(regular_payload.participant.id).status == "kicked"

      assert :ok = GroupCall.close_call(ctx.token, actor, "moderation")
      assert Queries.get_room(ctx.room.id).status == "closed"
      assert Queries.get_participant(owner_payload.participant.id).status == "left"
    end

    test "force kick remains authoritative after the channel ban is applied first" do
      ctx = create_call_with_member("forcekick", "owner")
      regular = create_registered_nick(unique_nick("regular"))
      {:ok, _state} = Server.join(ctx.channel, regular.nickname, nil, identified: true)

      _owner_payload = join_call(ctx)
      regular_payload = join_call(ctx, regular)

      actor = %{user_id: ctx.nick.id, nickname: ctx.nick.nickname}

      assert :ok =
               Server.ban(
                 ctx.channel,
                 ctx.nick.nickname,
                 regular.nickname,
                 "Removed from channel conference"
               )

      assert {:error, _message} =
               Server.join(ctx.channel, regular.nickname, nil, identified: true)

      assert :ok =
               GroupCall.force_kick_participant(
                 ctx.token,
                 actor,
                 regular_payload.participant.id,
                 "channel_kick"
               )

      kicked = Queries.get_participant(regular_payload.participant.id)
      assert kicked.status == "kicked"
      assert kicked.reason == "channel_kick"

      assert :ok =
               GroupCall.force_kick_participant(
                 ctx.token,
                 actor,
                 regular_payload.participant.id,
                 "channel_kick"
               )
    end

    test "bulk media moderation affects only lower-ranked participants" do
      ctx = create_call_with_member("bulk", "owner")
      operator = create_registered_nick(unique_nick("op"))
      half = create_registered_nick(unique_nick("half"))
      regular = create_registered_nick(unique_nick("regular"))

      for nick <- [operator, half, regular] do
        {:ok, _state} = Server.join(ctx.channel, nick.nickname, nil, identified: true)
      end

      :ok = Server.set_mode(ctx.channel, ctx.nick.nickname, "+o", [operator.nickname])
      :ok = Server.set_mode(ctx.channel, ctx.nick.nickname, "+h", [half.nickname])

      owner_payload = join_call(ctx)
      operator_payload = join_call(ctx, operator)
      half_payload = join_call(ctx, half)
      regular_payload = join_call(ctx, regular)

      actor = %{user_id: operator.id, nickname: operator.nickname}

      assert {:ok, audio_summary} = GroupCall.mute_all_participants(ctx.token, actor)
      assert audio_summary.changed_count == 2
      assert audio_summary.skipped_count == 2

      assert_receive {:"$gen_cast",
                      {:group_call_push, "group_call_set_media_state", %{audio: false}}},
                     2_000

      assert_receive {:"$gen_cast",
                      {:group_call_push, "group_call_set_media_state", %{audio: false}}},
                     2_000

      owner_audio = Queries.get_participant(owner_payload.participant.id).media_state
      operator_audio = Queries.get_participant(operator_payload.participant.id).media_state

      assert Map.get(owner_audio, "audio", true) == true
      assert Map.get(operator_audio, "audio", true) == true

      half_after_mute = Queries.get_participant(half_payload.participant.id)
      regular_after_mute = Queries.get_participant(regular_payload.participant.id)

      assert half_after_mute.media_state["audio"] == false
      assert half_after_mute.media_state["server_audio_muted"] == true
      assert regular_after_mute.media_state["audio"] == false
      assert regular_after_mute.media_state["server_audio_muted"] == true

      assert {:ok, video_summary} = GroupCall.block_all_participant_videos(ctx.token, actor)
      assert video_summary.changed_count == 2
      assert video_summary.skipped_count == 2

      owner_video = Queries.get_participant(owner_payload.participant.id).media_state
      operator_video = Queries.get_participant(operator_payload.participant.id).media_state

      assert Map.get(owner_video, "video", true) == true
      assert Map.get(operator_video, "video", true) == true

      half_after_video = Queries.get_participant(half_payload.participant.id)
      regular_after_video = Queries.get_participant(regular_payload.participant.id)

      assert half_after_video.media_state["video"] == false
      assert half_after_video.media_state["server_video_blocked"] == true
      assert regular_after_video.media_state["video"] == false
      assert regular_after_video.media_state["server_video_blocked"] == true
    end

    test "locked rooms reject lower-ranked joins but allow moderators" do
      ctx = create_call_with_member("lock", "owner")
      regular = create_registered_nick(unique_nick("regular"))
      operator = create_registered_nick(unique_nick("op"))

      {:ok, _state} = Server.join(ctx.channel, regular.nickname, nil, identified: true)
      {:ok, _state} = Server.join(ctx.channel, operator.nickname, nil, identified: true)
      :ok = Server.set_mode(ctx.channel, ctx.nick.nickname, "+o", [operator.nickname])

      actor = %{user_id: ctx.nick.id, nickname: ctx.nick.nickname}

      assert {:ok, %{locked: true, room: locked_room}} = GroupCall.lock_call(ctx.token, actor)
      assert locked_room.metadata["locked"] == true

      assert {:error, message} =
               GroupCall.join_call(
                 ctx.token,
                 %{user_id: regular.id, nickname: regular.nickname},
                 self(),
                 %{},
                 %{}
               )

      assert message =~ "locked"

      assert {:ok, _payload} =
               GroupCall.join_call(
                 ctx.token,
                 %{user_id: operator.id, nickname: operator.nickname},
                 self(),
                 %{},
                 %{}
               )

      assert_receive {:"$gen_cast", {:group_call_push, "group_call_offer", _payload}}, 2_000

      assert {:ok, %{locked: false, room: unlocked_room}} =
               GroupCall.unlock_call(ctx.token, actor)

      assert unlocked_room.metadata["locked"] == false
    end

    test "participants can request to speak and moderators can allow speech" do
      ctx = create_call_with_member("speak", "owner")
      regular = create_registered_nick(unique_nick("regular"))
      {:ok, _state} = Server.join(ctx.channel, regular.nickname, nil, identified: true)

      owner_payload = join_call(ctx)
      regular_payload = join_call(ctx, regular)

      owner_actor = %{user_id: ctx.nick.id, nickname: ctx.nick.nickname}
      regular_actor = %{user_id: regular.id, nickname: regular.nickname}

      assert {:ok, muted} =
               GroupCall.mute_participant(ctx.token, owner_actor, regular_payload.participant.id)

      assert muted.media_state["audio"] == false
      assert muted.media_state["server_audio_muted"] == true

      assert_receive {:"$gen_cast",
                      {:group_call_push, "group_call_set_media_state", %{audio: false}}},
                     2_000

      assert {:ok, raised} =
               GroupCall.set_hand_raised(
                 ctx.token,
                 regular_actor,
                 regular_payload.participant.id,
                 true
               )

      assert raised.media_state["hand_raised"] == true
      assert raised.media_state["hand_raised_by"] == regular.nickname
      assert is_binary(raised.media_state["hand_raised_at"])

      assert {:error, message} =
               GroupCall.set_hand_raised(
                 ctx.token,
                 regular_actor,
                 owner_payload.participant.id,
                 true
               )

      assert message =~ "Cannot raise another participant"

      assert {:ok, allowed} =
               GroupCall.allow_participant_speak(
                 ctx.token,
                 owner_actor,
                 regular_payload.participant.id
               )

      assert allowed.media_state["audio"] == true
      assert allowed.media_state["server_audio_muted"] == false
      assert allowed.media_state["hand_raised"] == false
      refute Map.has_key?(allowed.media_state, "hand_raised_at")

      assert_receive {:"$gen_cast",
                      {:group_call_push, "group_call_set_media_state",
                       %{audio: true, hand_raised: false}}},
                     2_000
    end

    test "records structured audit events and administrative PubSub messages" do
      ctx = create_call_with_member("audit", "owner")
      regular = create_registered_nick(unique_nick("regular"))
      {:ok, _state} = Server.join(ctx.channel, regular.nickname, nil, identified: true)
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "channel:#{ctx.channel}")

      _owner_payload = join_call(ctx)
      regular_payload = join_call(ctx, regular)

      actor = %{user_id: ctx.nick.id, nickname: ctx.nick.nickname}

      assert {:ok, %{active: true}} =
               GroupCall.set_screen_share_state(
                 ctx.token,
                 regular_payload.participant.id,
                 true,
                 %{
                   "track_id" => "audit-screen-track",
                   "stream_id" => "audit-screen-stream"
                 }
               )

      assert_receive {:group_call_moderation,
                      %{
                        action: :screen_share_started,
                        target: target,
                        event: %{"type" => "screen_share_started"}
                      }},
                     500

      assert target == regular.nickname

      assert {:ok, muted} =
               GroupCall.mute_participant(ctx.token, actor, regular_payload.participant.id)

      assert muted.media_state["server_audio_muted"] == true

      assert_receive {:group_call_moderation,
                      %{
                        action: :participant_muted,
                        actor: actor_nick,
                        target: target,
                        event: %{"type" => "participant_muted", "kind" => "audio"}
                      }},
                     500

      assert actor_nick == ctx.nick.nickname
      assert target == regular.nickname

      assert {:ok, _blocked_video} =
               GroupCall.block_participant_video(ctx.token, actor, regular_payload.participant.id)

      assert_receive {:group_call_moderation,
                      %{
                        action: :participant_camera_blocked,
                        event: %{"type" => "participant_camera_blocked", "kind" => "video"}
                      }},
                     500

      assert {:ok, _blocked_screen} =
               GroupCall.block_participant_screen_share(
                 ctx.token,
                 actor,
                 regular_payload.participant.id
               )

      assert_receive {:group_call_moderation,
                      %{
                        action: :screen_share_blocked,
                        event: %{"type" => "screen_share_blocked", "kind" => "screen"}
                      }},
                     500

      assert :ok = GroupCall.kick_participant(ctx.token, actor, regular_payload.participant.id)

      assert_receive {:group_call_moderation,
                      %{
                        action: :participant_kicked,
                        event: %{"type" => "participant_kicked", "reason" => "kicked"}
                      }},
                     500

      assert :ok = GroupCall.close_call(ctx.token, actor, "moderation")

      wait_until(fn -> Queries.get_room(ctx.room.id).status == "closed" end)

      assert audit_event_types(ctx.room.id) == [
               "conference_started",
               "screen_share_started",
               "participant_muted",
               "participant_camera_blocked",
               "screen_share_blocked",
               "participant_kicked",
               "conference_ended"
             ]
    end

    test "frequent media and presence updates do not emit administrative messages" do
      ctx = create_call_with_member("auditquiet", "owner")
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "channel:#{ctx.channel}")

      payload = join_call(ctx)
      mark_ready(ctx, payload)

      assert_receive {:group_call_updated, %{reason: "participant_joined"}}, 500

      assert :ok =
               GroupCall.set_media_state(ctx.token, payload.participant.id, %{
                 "audio" => false,
                 "video" => true
               })

      refute_receive {:group_call_moderation, _payload}, 100

      assert audit_event_types(ctx.room.id) == ["conference_started"]
    end
  end
end
