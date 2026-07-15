defmodule RetroHexChat.GroupCall.SFUMediaPathTest do
  use RetroHexChat.DataCase, async: false

  alias RetroHexChat.Channels.Registry, as: ChannelRegistry
  alias RetroHexChat.Channels.{Server, Supervisor}
  alias RetroHexChat.GroupCall
  alias RetroHexChat.GroupCall.{Queries, Registry}
  alias RetroHexChat.Services.RegisteredNick

  @moduletag :integration
  @moduletag timeout: 60_000

  @video_packet_burst 40
  @audio_packet_burst 40
  @min_forwarded_packets 12

  setup do
    previous_port_range = Application.get_env(:retro_hex_chat, :sfu_ice_port_range)
    previous_ready_timeout = Application.get_env(:retro_hex_chat, :group_call_ready_timeout_ms)

    previous_peerless_timeout =
      Application.get_env(:retro_hex_chat, :group_call_peerless_timeout_ms)

    previous_reconnect_timeout =
      Application.get_env(:retro_hex_chat, :group_call_reconnect_timeout_ms)

    Application.put_env(:retro_hex_chat, :sfu_ice_port_range, [0])
    Application.put_env(:retro_hex_chat, :group_call_ready_timeout_ms, 10_000)
    Application.put_env(:retro_hex_chat, :group_call_peerless_timeout_ms, 100)
    Application.put_env(:retro_hex_chat, :group_call_reconnect_timeout_ms, 100)

    on_exit(fn ->
      restore_env(:sfu_ice_port_range, previous_port_range)
      restore_env(:group_call_ready_timeout_ms, previous_ready_timeout)
      restore_env(:group_call_peerless_timeout_ms, previous_peerless_timeout)
      restore_env(:group_call_reconnect_timeout_ms, previous_reconnect_timeout)
    end)

    :ok
  end

  describe "headless SFU media path" do
    test "forwards RTP video both ways between two synthetic WebRTC clients" do
      ctx = create_call_with_member("media", "alice")
      bob = create_registered_nick(unique_nick("bob"))
      {:ok, _state} = Server.join(ctx.channel, bob.nickname, nil, identified: true)

      alice_client = start_synthetic_peer(ctx, ctx.nick, :alice)
      assert_participant_connected(alice_client.participant_id)

      bob_client = start_synthetic_peer(ctx, bob, :bob)
      assert_participant_connected(bob_client.participant_id)

      assert_receive {:sfu_probe, :alice, :connection_state, :connected}, 10_000
      assert_receive {:sfu_probe, :bob, :connection_state, :connected}, 10_000

      assert_remote_video_track(:alice)
      assert_remote_video_track(:bob)
      assert_eventually_server_stats_subscriber_count(ctx.token, alice_client.participant_id, 1)
      assert_eventually_server_stats_subscriber_count(ctx.token, bob_client.participant_id, 1)

      send(bob_client.pid, {:send_rtp, :video, @video_packet_burst})
      assert_video_rtp_counts([:alice])

      send(alice_client.pid, {:send_rtp, :video, @video_packet_burst})
      assert_video_rtp_counts([:bob])

      assert_server_stats_route(ctx.token, alice_client.participant_id, bob_client.participant_id)
      assert_server_stats_route(ctx.token, bob_client.participant_id, alice_client.participant_id)
    after
      stop_all_synthetic_peers()
    end

    test "keeps forwarding video RTP through gaps duplicates and reorder" do
      ctx = create_call_with_member("rtpgap", "alice")
      bob = create_registered_nick(unique_nick("bob"))
      {:ok, _state} = Server.join(ctx.channel, bob.nickname, nil, identified: true)

      alice_client = start_synthetic_peer(ctx, ctx.nick, :alice)
      assert_participant_connected(alice_client.participant_id)

      bob_client = start_synthetic_peer(ctx, bob, :bob)
      assert_participant_connected(bob_client.participant_id)

      assert_remote_video_track(:alice)
      assert_remote_video_track(:bob)
      assert_eventually_server_stats_subscriber_count(ctx.token, alice_client.participant_id, 1)
      assert_eventually_server_stats_subscriber_count(ctx.token, bob_client.participant_id, 1)

      send(bob_client.pid, {:send_rtp_sequence, :video, [1, 2, 3, 4, 5]})
      assert_rtp_packet_count(:alice, :video, 5)
      assert_eventually_active_track(ctx.room.id, bob_client.participant_id, "video", "camera")

      drain_probe_rtp()

      send(bob_client.pid, {:send_rtp_sequence, :video, [100, 102, 101, 101, 103]})

      sequences = assert_rtp_packet_count(:alice, :video, 4)
      assert length(Enum.uniq(sequences)) == 4
      refute_receive {:sfu_probe, :alice, :rtp, :video, _track_id, _sequence}, 500
    after
      stop_all_synthetic_peers()
    end

    test "reports monotonic server RTP stats while video flows" do
      ctx = create_call_with_member("rtpstats", "alice")
      bob = create_registered_nick(unique_nick("bob"))
      {:ok, _state} = Server.join(ctx.channel, bob.nickname, nil, identified: true)

      alice_client = start_synthetic_peer(ctx, ctx.nick, :alice)
      assert_participant_connected(alice_client.participant_id)

      bob_client = start_synthetic_peer(ctx, bob, :bob)
      assert_participant_connected(bob_client.participant_id)

      assert_remote_video_track(:alice)
      assert_remote_video_track(:bob)
      assert_eventually_server_stats_subscriber_count(ctx.token, alice_client.participant_id, 1)
      assert_eventually_server_stats_subscriber_count(ctx.token, bob_client.participant_id, 1)

      before =
        server_rtp_snapshot(ctx.token, bob_client.participant_id, alice_client.participant_id)

      send(bob_client.pid, {:send_rtp_sequence, :video, Enum.to_list(1..20)})
      assert_rtp_packet_count(:alice, :video, 20)

      first =
        assert_server_rtp_growth(
          ctx.token,
          bob_client.participant_id,
          alice_client.participant_id,
          before
        )

      drain_probe_rtp()

      send(bob_client.pid, {:send_rtp_sequence, :video, Enum.to_list(30..45)})
      assert_rtp_packet_count(:alice, :video, 16)

      second =
        assert_server_rtp_growth(
          ctx.token,
          bob_client.participant_id,
          alice_client.participant_id,
          first
        )

      assert rtp_packets(second.publisher, :inbound_rtp) >=
               rtp_packets(first.publisher, :inbound_rtp)

      assert rtp_packets(second.subscriber, :outbound_rtp) >=
               rtp_packets(first.subscriber, :outbound_rtp)

      assert Map.get(second.totals, :inbound_packets, 0) >=
               Map.get(first.totals, :inbound_packets, 0)

      assert Map.get(second.totals, :outbound_packets, 0) >=
               Map.get(first.totals, :outbound_packets, 0)
    after
      stop_all_synthetic_peers()
    end

    test "routes subscriber PLI feedback to the video publisher" do
      ctx = create_call_with_member("pli", "alice")
      bob = create_registered_nick(unique_nick("bob"))
      {:ok, _state} = Server.join(ctx.channel, bob.nickname, nil, identified: true)

      alice_client = start_synthetic_peer(ctx, ctx.nick, :alice)
      assert_participant_connected(alice_client.participant_id)

      bob_client = start_synthetic_peer(ctx, bob, :bob)
      assert_participant_connected(bob_client.participant_id)

      assert_receive {:sfu_probe, :alice, :connection_state, :connected}, 10_000
      assert_receive {:sfu_probe, :bob, :connection_state, :connected}, 10_000

      assert_remote_video_track(:alice)
      assert_remote_video_track(:bob)
      assert_eventually_server_stats_subscriber_count(ctx.token, alice_client.participant_id, 1)
      assert_eventually_server_stats_subscriber_count(ctx.token, bob_client.participant_id, 1)

      send(bob_client.pid, {:send_rtp, :video, @video_packet_burst})
      assert_video_rtp_counts([:alice])
      drain_probe_rtcp()

      send(alice_client.pid, {:send_pli, :video})

      assert_receive {:sfu_probe, :bob, :rtcp_pli, _track_id}, 5_000
    after
      stop_all_synthetic_peers()
    end

    test "keeps media fanout healthy when a third participant joins late" do
      ctx = create_call_with_member("mesh", "alice")
      bob = create_registered_nick(unique_nick("bob"))
      carol = create_registered_nick(unique_nick("carol"))
      {:ok, _state} = Server.join(ctx.channel, bob.nickname, nil, identified: true)
      {:ok, _state} = Server.join(ctx.channel, carol.nickname, nil, identified: true)

      alice_client = start_synthetic_peer(ctx, ctx.nick, :alice)
      assert_participant_connected(alice_client.participant_id)

      bob_client = start_synthetic_peer(ctx, bob, :bob)
      assert_participant_connected(bob_client.participant_id)

      carol_client = start_synthetic_peer(ctx, carol, :carol)
      assert_participant_connected(carol_client.participant_id)

      assert_remote_track_count(:alice, :video, 2)
      assert_remote_track_count(:bob, :video, 2)
      assert_remote_track_count(:carol, :video, 2)

      assert_live_sfu_shape(ctx, [alice_client, bob_client, carol_client])

      prime_video_track(ctx, alice_client)
      prime_video_track(ctx, bob_client)
      prime_video_track(ctx, carol_client)

      send(carol_client.pid, {:send_rtp, :video, @video_packet_burst})
      assert_video_rtp_counts([:alice, :bob])

      drain_probe_rtp()

      send(alice_client.pid, {:send_rtp, :video, @video_packet_burst})
      assert_video_rtp_counts([:bob, :carol])

      drain_probe_rtp()

      send(bob_client.pid, {:send_rtp, :video, @video_packet_burst})
      assert_video_rtp_counts([:alice, :carol])

      assert_server_stats_subscriber_count(ctx.token, alice_client.participant_id, 2)
      assert_server_stats_subscriber_count(ctx.token, bob_client.participant_id, 2)
      assert_server_stats_subscriber_count(ctx.token, carol_client.participant_id, 2)
    after
      stop_all_synthetic_peers()
    end

    test "keeps the transceiver graph sane when four participants join concurrently" do
      ctx = create_call_with_member("burst", "alice")
      bob = create_registered_nick(unique_nick("bob"))
      carol = create_registered_nick(unique_nick("carol"))
      dave = create_registered_nick(unique_nick("dave"))
      {:ok, _state} = Server.join(ctx.channel, bob.nickname, nil, identified: true)
      {:ok, _state} = Server.join(ctx.channel, carol.nickname, nil, identified: true)
      {:ok, _state} = Server.join(ctx.channel, dave.nickname, nil, identified: true)

      peers = %{
        alice: spawn_synthetic_peer(ctx, ctx.nick, :alice),
        bob: spawn_synthetic_peer(ctx, bob, :bob),
        carol: spawn_synthetic_peer(ctx, carol, :carol),
        dave: spawn_synthetic_peer(ctx, dave, :dave)
      }

      participants = await_joined_participants(Map.keys(peers))

      Enum.each(participants, fn {_name, participant_id} ->
        assert_participant_connected(participant_id)
      end)

      assert_remote_track_count(:alice, :video, 3)
      assert_remote_track_count(:bob, :video, 3)
      assert_remote_track_count(:carol, :video, 3)
      assert_remote_track_count(:dave, :video, 3)

      Enum.each(participants, fn {_name, participant_id} ->
        assert_eventually_server_stats_subscriber_count(ctx.token, participant_id, 3)
        assert_eventually_server_transceiver_shape(ctx.room.id, participant_id, 3)
      end)
    after
      stop_all_synthetic_peers()
    end

    test "keeps video routes healthy when one participant joins without camera" do
      ctx = create_call_with_member("novideo", "alice")
      bob = create_registered_nick(unique_nick("bob"))
      carol = create_registered_nick(unique_nick("carol"))
      {:ok, _state} = Server.join(ctx.channel, bob.nickname, nil, identified: true)
      {:ok, _state} = Server.join(ctx.channel, carol.nickname, nil, identified: true)

      alice_client = start_synthetic_peer(ctx, ctx.nick, :alice)
      assert_participant_connected(alice_client.participant_id)

      bob_client = start_synthetic_peer(ctx, bob, :bob, media: %{audio: true, video: false})
      assert_participant_connected(bob_client.participant_id)

      carol_client = start_synthetic_peer(ctx, carol, :carol)
      assert_participant_connected(carol_client.participant_id)

      assert_remote_video_track(:alice)
      assert_remote_video_track(:bob)
      assert_remote_video_track(:carol)
      assert_remote_track_count(:alice, :audio, 2)
      assert_remote_track_count(:bob, :audio, 2)
      assert_remote_track_count(:carol, :audio, 2)
      assert_eventually_server_stats_subscriber_count(ctx.token, alice_client.participant_id, 2)
      assert_eventually_server_stats_subscriber_count(ctx.token, bob_client.participant_id, 2)
      assert_eventually_server_stats_subscriber_count(ctx.token, carol_client.participant_id, 2)

      send(bob_client.pid, {:send_rtp, :audio, @audio_packet_burst})

      assert_eventually_active_track(
        ctx.room.id,
        bob_client.participant_id,
        "audio",
        "microphone"
      )

      drain_probe_rtp()

      send_and_assert_audio_rtp_counts(bob_client, [:alice, :carol])

      drain_probe_rtp()

      send(bob_client.pid, {:send_rtp, :video, @video_packet_burst})
      assert_receive {:sfu_probe, :bob, :missing_local_track, :video}, 1_000
      refute_rtp_for([:alice, :carol], :video)

      send(alice_client.pid, {:send_rtp, :video, @video_packet_burst})
      assert_video_rtp_counts([:bob, :carol])

      drain_probe_rtp()

      send(carol_client.pid, {:send_rtp, :video, @video_packet_burst})
      assert_video_rtp_counts([:alice, :bob])
    after
      stop_all_synthetic_peers()
    end

    test "keeps audio-only routes healthy when participants gradually join and leave" do
      ctx = create_call_with_member("audioonly", "alice")
      bob = create_registered_nick(unique_nick("bob"))
      carol = create_registered_nick(unique_nick("carol"))
      {:ok, _state} = Server.join(ctx.channel, bob.nickname, nil, identified: true)
      {:ok, _state} = Server.join(ctx.channel, carol.nickname, nil, identified: true)

      alice_client = start_synthetic_peer(ctx, ctx.nick, :alice, media: audio_only_media())
      assert_participant_connected(alice_client.participant_id)

      bob_client = start_synthetic_peer(ctx, bob, :bob, media: audio_only_media())
      assert_participant_connected(bob_client.participant_id)

      carol_client = start_synthetic_peer(ctx, carol, :carol, media: audio_only_media())
      assert_participant_connected(carol_client.participant_id)

      assert_remote_track_count(:alice, :audio, 2)
      assert_remote_track_count(:bob, :audio, 2)
      assert_remote_track_count(:carol, :audio, 2)

      assert_eventually_server_stats_subscriber_count(ctx.token, alice_client.participant_id, 2)
      assert_eventually_server_stats_subscriber_count(ctx.token, bob_client.participant_id, 2)
      assert_eventually_server_stats_subscriber_count(ctx.token, carol_client.participant_id, 2)

      Enum.each([alice_client, bob_client, carol_client], fn client ->
        send(client.pid, {:send_rtp, :audio, @audio_packet_burst})
      end)

      assert_eventually_active_track_counts(ctx.room.id, %{audio: 3, video: 0})
      drain_probe_rtp()

      send_and_assert_audio_rtp_counts(carol_client, [:alice, :bob])

      drain_probe_rtp()

      send_and_assert_audio_rtp_counts(alice_client, [:bob, :carol])

      drain_probe_rtp()

      send_and_assert_audio_rtp_counts(bob_client, [:alice, :carol])

      drain_probe_rtp()

      Enum.each([alice_client, bob_client, carol_client], fn client ->
        send(client.pid, {:send_rtp, :video, @video_packet_burst})
      end)

      assert_missing_local_track(:alice, :video)
      assert_missing_local_track(:bob, :video)
      assert_missing_local_track(:carol, :video)
      refute_rtp_for([:alice, :bob, :carol], :video)

      drain_probe_messages()

      :ok = GroupCall.leave_call(ctx.token, bob_client.participant_id, "left")

      assert_receive {:sfu_probe, :alice, :answered_offer}, 10_000
      assert_receive {:sfu_probe, :carol, :answered_offer}, 10_000

      assert_eventually_active_track_counts(ctx.room.id, %{audio: 2, video: 0})
      assert_eventually_server_stats_subscriber_count(ctx.token, alice_client.participant_id, 1)
      assert_eventually_server_stats_subscriber_count(ctx.token, carol_client.participant_id, 1)

      drain_probe_rtp()

      send_and_assert_audio_rtp_counts(carol_client, [:alice])

      drain_probe_rtp()

      send_and_assert_audio_rtp_counts(alice_client, [:carol])
    after
      stop_all_synthetic_peers()
    end

    test "keeps audio-only routing sane when four participants join concurrently" do
      ctx = create_call_with_member("aoburst", "alice")
      bob = create_registered_nick(unique_nick("bob"))
      carol = create_registered_nick(unique_nick("carol"))
      dave = create_registered_nick(unique_nick("dave"))
      {:ok, _state} = Server.join(ctx.channel, bob.nickname, nil, identified: true)
      {:ok, _state} = Server.join(ctx.channel, carol.nickname, nil, identified: true)
      {:ok, _state} = Server.join(ctx.channel, dave.nickname, nil, identified: true)

      peers = %{
        alice: spawn_synthetic_peer(ctx, ctx.nick, :alice, media: audio_only_media()),
        bob: spawn_synthetic_peer(ctx, bob, :bob, media: audio_only_media()),
        carol: spawn_synthetic_peer(ctx, carol, :carol, media: audio_only_media()),
        dave: spawn_synthetic_peer(ctx, dave, :dave, media: audio_only_media())
      }

      participants = await_joined_participants(Map.keys(peers))

      Enum.each(participants, fn {_name, participant_id} ->
        assert_participant_connected(participant_id)
      end)

      assert_remote_track_count(:alice, :audio, 3)
      assert_remote_track_count(:bob, :audio, 3)
      assert_remote_track_count(:carol, :audio, 3)
      assert_remote_track_count(:dave, :audio, 3)

      Enum.each(participants, fn {_name, participant_id} ->
        assert_eventually_server_stats_subscriber_count(ctx.token, participant_id, 3)
        assert_eventually_server_transceiver_shape(ctx.room.id, participant_id, 3)
      end)

      Enum.each(Map.values(peers), fn peer ->
        send(peer.pid, {:send_rtp, :audio, @audio_packet_burst})
      end)

      assert_eventually_active_track_counts(ctx.room.id, %{audio: 4, video: 0})
      drain_probe_rtp()

      Enum.each(Map.values(peers), fn peer ->
        send(peer.pid, {:send_rtp, :video, @video_packet_burst})
      end)

      assert_missing_local_track(:alice, :video)
      assert_missing_local_track(:bob, :video)
      assert_missing_local_track(:carol, :video)
      assert_missing_local_track(:dave, :video)
      refute_rtp_for([:alice, :bob, :carol, :dave], :video)
    after
      stop_all_synthetic_peers()
    end

    test "keeps video RTP flowing while replacing camera with screen share and back" do
      ctx = create_call_with_member("screensfu", "alice")
      bob = create_registered_nick(unique_nick("bob"))
      {:ok, _state} = Server.join(ctx.channel, bob.nickname, nil, identified: true)

      alice_client = start_synthetic_peer(ctx, ctx.nick, :alice)
      assert_participant_connected(alice_client.participant_id)

      bob_client = start_synthetic_peer(ctx, bob, :bob)
      assert_participant_connected(bob_client.participant_id)

      assert_remote_video_track(:alice)
      assert_remote_video_track(:bob)
      assert_eventually_server_stats_subscriber_count(ctx.token, alice_client.participant_id, 1)
      assert_eventually_server_stats_subscriber_count(ctx.token, bob_client.participant_id, 1)

      send(alice_client.pid, {:send_rtp, :video, @video_packet_burst})
      assert_video_rtp_counts([:bob])
      assert_eventually_active_track(ctx.room.id, alice_client.participant_id, "video", "camera")

      drain_probe_rtp()

      send(alice_client.pid, {:replace_local_video_track, :screen})

      assert_receive {:sfu_probe, :alice, :replaced_track, :video, :screen, screen_track_id},
                     5_000

      assert {:ok, %{active: true, track: %{source: "screen"}}} =
               GroupCall.set_screen_share_state(ctx.token, alice_client.participant_id, true, %{
                 "track_id" => to_string(screen_track_id),
                 "stream_id" => "synthetic-screen"
               })

      send(alice_client.pid, {:send_rtp, :video, @video_packet_burst})
      assert_video_rtp_counts([:bob])

      screen_track =
        assert_eventually_active_track(
          ctx.room.id,
          alice_client.participant_id,
          "video",
          "screen"
        )

      assert screen_track.metadata["screen_track_id"] == to_string(screen_track_id)
      assert_eventually_server_transceiver_shape(ctx.room.id, alice_client.participant_id, 1)
      assert_eventually_server_transceiver_shape(ctx.room.id, bob_client.participant_id, 1)

      drain_probe_rtp()

      send(alice_client.pid, {:replace_local_video_track, :camera})

      assert_receive {:sfu_probe, :alice, :replaced_track, :video, :camera, _camera_track_id},
                     5_000

      assert {:ok, %{active: false, track: %{source: "camera"}}} =
               GroupCall.set_screen_share_state(
                 ctx.token,
                 alice_client.participant_id,
                 false,
                 %{}
               )

      send(alice_client.pid, {:send_rtp, :video, @video_packet_burst})
      assert_video_rtp_counts([:bob])

      camera_track =
        assert_eventually_active_track(
          ctx.room.id,
          alice_client.participant_id,
          "video",
          "camera"
        )

      refute Map.has_key?(camera_track.metadata, "screen_track_id")
      assert_eventually_server_transceiver_shape(ctx.room.id, alice_client.participant_id, 1)
      assert_eventually_server_transceiver_shape(ctx.room.id, bob_client.participant_id, 1)
    after
      stop_all_synthetic_peers()
    end

    test "keeps media and transceivers coherent through join leave and rejoin churn" do
      ctx = create_call_with_member("churn", "alice")
      bob = create_registered_nick(unique_nick("bob"))
      carol = create_registered_nick(unique_nick("carol"))
      dave = create_registered_nick(unique_nick("dave"))
      {:ok, _state} = Server.join(ctx.channel, bob.nickname, nil, identified: true)
      {:ok, _state} = Server.join(ctx.channel, carol.nickname, nil, identified: true)
      {:ok, _state} = Server.join(ctx.channel, dave.nickname, nil, identified: true)

      alice_client = start_synthetic_peer(ctx, ctx.nick, :alice)
      assert_participant_connected(alice_client.participant_id)

      bob_client = start_synthetic_peer(ctx, bob, :bob)
      assert_participant_connected(bob_client.participant_id)

      carol_client = start_synthetic_peer(ctx, carol, :carol)
      assert_participant_connected(carol_client.participant_id)

      assert_remote_track_count(:alice, :video, 2)
      assert_remote_track_count(:bob, :video, 2)
      assert_remote_track_count(:carol, :video, 2)
      assert_live_sfu_shape(ctx, [alice_client, bob_client, carol_client])

      prime_video_track(ctx, alice_client)
      prime_video_track(ctx, bob_client)
      prime_video_track(ctx, carol_client)

      send(carol_client.pid, {:send_rtp, :video, @video_packet_burst})
      assert_video_rtp_counts([:alice, :bob])

      drain_probe_messages()

      :ok = GroupCall.leave_call(ctx.token, bob_client.participant_id, "left")
      stop_synthetic_peer(bob_client.pid)

      assert_receive {:sfu_probe, :alice, :answered_offer}, 10_000
      assert_receive {:sfu_probe, :carol, :answered_offer}, 10_000
      assert_peer_unregistered(ctx.room.id, bob_client.participant_id)
      assert_no_active_tracks_for(ctx.room.id, bob_client.participant_id)
      assert_live_sfu_shape(ctx, [alice_client, carol_client])

      drain_probe_rtp()

      send(alice_client.pid, {:send_rtp, :video, @video_packet_burst})
      assert_video_rtp_counts([:carol])

      drain_probe_messages()

      dave_client = start_synthetic_peer(ctx, dave, :dave)
      assert_participant_connected(dave_client.participant_id)

      assert_remote_track_count(:alice, :video, 1)
      assert_remote_track_count(:carol, :video, 1)
      assert_remote_track_count(:dave, :video, 2)
      assert_live_sfu_shape(ctx, [alice_client, carol_client, dave_client])

      prime_video_track(ctx, dave_client)

      send(dave_client.pid, {:send_rtp, :video, @video_packet_burst})
      assert_video_rtp_counts([:alice, :carol])

      drain_probe_messages()

      bob_rejoined = start_synthetic_peer(ctx, bob, :bob)
      assert bob_rejoined.participant_id != bob_client.participant_id
      assert_participant_connected(bob_rejoined.participant_id)

      assert_remote_track_count(:alice, :video, 1)
      assert_remote_track_count(:carol, :video, 1)
      assert_remote_track_count(:dave, :video, 1)
      assert_remote_track_count(:bob, :video, 3)
      assert_live_sfu_shape(ctx, [alice_client, carol_client, dave_client, bob_rejoined])

      prime_video_track(ctx, bob_rejoined)

      send(bob_rejoined.pid, {:send_rtp, :video, @video_packet_burst})
      assert_video_rtp_counts([:alice, :carol, :dave])

      drain_probe_messages()

      :ok = GroupCall.leave_call(ctx.token, carol_client.participant_id, "left")
      stop_synthetic_peer(carol_client.pid)

      assert_receive {:sfu_probe, :alice, :answered_offer}, 10_000
      assert_receive {:sfu_probe, :dave, :answered_offer}, 10_000
      assert_receive {:sfu_probe, :bob, :answered_offer}, 10_000
      assert_peer_unregistered(ctx.room.id, carol_client.participant_id)
      assert_no_active_tracks_for(ctx.room.id, carol_client.participant_id)
      assert_live_sfu_shape(ctx, [alice_client, dave_client, bob_rejoined])

      drain_probe_rtp()

      send(dave_client.pid, {:send_rtp, :video, @video_packet_burst})
      assert_video_rtp_counts([:alice, :bob])
    after
      stop_all_synthetic_peers()
    end

    test "keeps remaining media routes healthy after a participant leaves" do
      ctx = create_call_with_member("leave", "alice")
      bob = create_registered_nick(unique_nick("bob"))
      carol = create_registered_nick(unique_nick("carol"))
      {:ok, _state} = Server.join(ctx.channel, bob.nickname, nil, identified: true)
      {:ok, _state} = Server.join(ctx.channel, carol.nickname, nil, identified: true)

      alice_client = start_synthetic_peer(ctx, ctx.nick, :alice)
      assert_participant_connected(alice_client.participant_id)

      bob_client = start_synthetic_peer(ctx, bob, :bob)
      assert_participant_connected(bob_client.participant_id)

      carol_client = start_synthetic_peer(ctx, carol, :carol)
      assert_participant_connected(carol_client.participant_id)

      assert_remote_video_track(:alice)
      assert_remote_video_track(:bob)
      assert_remote_video_track(:carol)
      assert_live_sfu_shape(ctx, [alice_client, bob_client, carol_client])

      prime_video_track(ctx, alice_client)
      prime_video_track(ctx, bob_client)
      prime_video_track(ctx, carol_client)

      drain_probe_messages()

      :ok = GroupCall.leave_call(ctx.token, bob_client.participant_id, "left")
      stop_synthetic_peer(bob_client.pid)

      assert_receive {:sfu_probe, :alice, :answered_offer}, 10_000
      assert_receive {:sfu_probe, :carol, :answered_offer}, 10_000

      assert_peer_unregistered(ctx.room.id, bob_client.participant_id)
      assert_no_active_tracks_for(ctx.room.id, bob_client.participant_id)
      assert_live_sfu_shape(ctx, [alice_client, carol_client])

      drain_probe_rtp()

      send(carol_client.pid, {:send_rtp, :video, @video_packet_burst})
      assert_video_rtp_counts([:alice])

      drain_probe_rtp()

      send(alice_client.pid, {:send_rtp, :video, @video_packet_burst})
      assert_video_rtp_counts([:carol])
    after
      stop_all_synthetic_peers()
    end

    test "keeps media alive after an explicit offer request with ICE restart" do
      ctx = create_call_with_member("restart", "alice")
      bob = create_registered_nick(unique_nick("bob"))
      {:ok, _state} = Server.join(ctx.channel, bob.nickname, nil, identified: true)

      alice_client = start_synthetic_peer(ctx, ctx.nick, :alice)
      assert_participant_connected(alice_client.participant_id)

      bob_client = start_synthetic_peer(ctx, bob, :bob)
      assert_participant_connected(bob_client.participant_id)

      assert_remote_video_track(:alice)
      assert_remote_video_track(:bob)
      assert_eventually_server_stats_subscriber_count(ctx.token, alice_client.participant_id, 1)
      assert_eventually_server_stats_subscriber_count(ctx.token, bob_client.participant_id, 1)

      send(bob_client.pid, {:send_rtp, :video, @video_packet_burst})
      assert_video_rtp_counts([:alice])

      drain_probe_messages()

      :ok = GroupCall.request_offer(ctx.token, alice_client.participant_id)
      assert_receive {:sfu_probe, :alice, :answered_offer}, 10_000

      # The answer only completes signaling; the restarted ICE transport drops
      # packets until connectivity re-establishes, so wait for the peer to come
      # back before bursting a finite packet train through it.
      assert_receive {:sfu_probe, :alice, :connection_state, :connected}, 10_000

      drain_probe_rtp()

      send(bob_client.pid, {:send_rtp, :video, @video_packet_burst})
      assert_video_rtp_counts([:alice])

      drain_probe_rtp()

      send(alice_client.pid, {:send_rtp, :video, @video_packet_burst})
      assert_video_rtp_counts([:bob])
    after
      stop_all_synthetic_peers()
    end
  end

  defp restore_env(key, nil), do: Application.delete_env(:retro_hex_chat, key)
  defp restore_env(key, value), do: Application.put_env(:retro_hex_chat, key, value)

  defp uid, do: System.unique_integer([:positive])
  defp unique_nick(prefix), do: "#{prefix}#{uid()}" |> String.slice(0, 16)
  defp audio_only_media, do: %{audio: true, video: false}

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
        _other -> :ok
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
    channel = "#sfu#{channel_prefix}#{uid()}"
    nick = create_registered_nick(unique_nick(nick_prefix))
    {:ok, _pid} = start_channel(channel)
    {:ok, _state} = Server.join(channel, nick.nickname, nil, identified: true)

    {:ok, %{room: room, token: token}} =
      GroupCall.create_channel_call(channel, %{user_id: nick.id, nickname: nick.nickname})

    cleanup_room(token)

    %{channel: channel, nick: nick, room: room, token: token}
  end

  defp spawn_synthetic_peer(ctx, nick, name, opts \\ []) do
    parent = self()

    pid =
      spawn_link(fn ->
        __MODULE__.SyntheticPeer.run(parent, %{
          name: name,
          token: ctx.token,
          actor: %{user_id: nick.id, nickname: nick.nickname},
          media: Keyword.get(opts, :media, %{audio: true, video: true})
        })
      end)

    Process.put(:"#{name}_probe", pid)

    %{pid: pid}
  end

  defp start_synthetic_peer(ctx, nick, name, opts \\ []) do
    peer = spawn_synthetic_peer(ctx, nick, name, opts)

    assert_receive {:sfu_probe, ^name, :joined, participant_id}, 10_000

    Map.put(peer, :participant_id, participant_id)
  end

  defp await_joined_participants(names) do
    deadline = System.monotonic_time(:millisecond) + 10_000
    await_joined_participants(names, %{}, deadline)
  end

  defp await_joined_participants(names, participants, deadline) do
    if map_size(participants) == length(names) do
      participants
    else
      remaining = max(deadline - System.monotonic_time(:millisecond), 0)

      receive do
        {:sfu_probe, name, :joined, participant_id} ->
          if name in names do
            await_joined_participants(
              names,
              Map.put(participants, name, participant_id),
              deadline
            )
          else
            await_joined_participants(names, participants, deadline)
          end
      after
        remaining ->
          flunk("expected participants to join; joined=#{inspect(participants)}")
      end
    end
  end

  defp stop_synthetic_peer(nil), do: :ok

  defp stop_synthetic_peer(pid) when is_pid(pid) do
    if Process.alive?(pid), do: send(pid, :stop)
  end

  defp stop_all_synthetic_peers do
    [:alice_probe, :bob_probe, :carol_probe, :dave_probe]
    |> Enum.each(fn key -> stop_synthetic_peer(Process.get(key)) end)
  end

  defp assert_participant_connected(participant_id) do
    wait_until(fn ->
      case Queries.get_participant(participant_id) do
        %{status: "connected"} -> true
        _other -> false
      end
    end)
  end

  defp assert_remote_video_track(name) do
    assert_receive {:sfu_probe, ^name, :track, :video, _track_id}, 10_000
  end

  defp assert_remote_track_count(name, kind, count, timeout \\ 10_000) do
    deadline = System.monotonic_time(:millisecond) + timeout
    await_remote_track_count(name, kind, count, 0, deadline)
  end

  defp await_remote_track_count(_name, _kind, expected, current, _deadline)
       when current >= expected,
       do: :ok

  defp await_remote_track_count(name, kind, expected, current, deadline) do
    remaining = max(deadline - System.monotonic_time(:millisecond), 0)

    receive do
      {:sfu_probe, ^name, :track, ^kind, _track_id} ->
        await_remote_track_count(name, kind, expected, current + 1, deadline)
    after
      remaining ->
        flunk("expected #{name} to receive #{expected} #{kind} tracks; received=#{current}")
    end
  end

  defp assert_server_stats_route(token, publisher_id, subscriber_id) do
    {:ok, %{server_stats: %{peers: peers}}} = GroupCall.get_summary(token)

    publisher =
      Enum.find(peers, fn peer ->
        peer.participant_id == publisher_id and peer.subscriber_count >= 1
      end)

    assert publisher,
           "expected publisher #{publisher_id} to have subscriber #{subscriber_id}; peers=#{inspect(peers)}"
  end

  defp assert_server_stats_subscriber_count(token, publisher_id, count) do
    {:ok, %{server_stats: %{peers: peers}}} = GroupCall.get_summary(token)

    publisher =
      Enum.find(peers, fn peer ->
        peer.participant_id == publisher_id and peer.subscriber_count >= count
      end)

    assert publisher,
           "expected publisher #{publisher_id} to have at least #{count} subscribers; peers=#{inspect(peers)}"
  end

  defp assert_eventually_server_stats_subscriber_count(token, publisher_id, count) do
    wait_until(
      fn ->
        {:ok, %{server_stats: %{peers: peers}}} = GroupCall.get_summary(token)

        Enum.any?(peers, fn peer ->
          peer.participant_id == publisher_id and peer.subscriber_count >= count
        end)
      end,
      500
    )
  end

  defp server_rtp_snapshot(token, publisher_id, subscriber_id) do
    {:ok, %{server_stats: %{peers: peers, totals: totals}}} = GroupCall.get_summary(token)

    %{
      publisher: Enum.find(peers, &(&1.participant_id == publisher_id)),
      subscriber: Enum.find(peers, &(&1.participant_id == subscriber_id)),
      totals: totals
    }
  end

  defp assert_server_rtp_growth(token, publisher_id, subscriber_id, before) do
    wait_until(
      fn ->
        after_snapshot = server_rtp_snapshot(token, publisher_id, subscriber_id)

        after_snapshot.publisher &&
          after_snapshot.subscriber &&
          rtp_packets(after_snapshot.publisher, :inbound_rtp) >
            rtp_packets(before.publisher, :inbound_rtp) &&
          rtp_packets(after_snapshot.subscriber, :outbound_rtp) >
            rtp_packets(before.subscriber, :outbound_rtp) &&
          Map.get(after_snapshot.totals, :inbound_packets, 0) >
            Map.get(before.totals, :inbound_packets, 0) &&
          Map.get(after_snapshot.totals, :outbound_packets, 0) >
            Map.get(before.totals, :outbound_packets, 0)
      end,
      500
    )

    server_rtp_snapshot(token, publisher_id, subscriber_id)
  end

  defp rtp_packets(nil, _key), do: 0

  defp rtp_packets(peer, key) do
    peer
    |> Map.get(key, %{})
    |> Map.get(:packets, 0)
  end

  defp assert_eventually_server_transceiver_shape(room_id, participant_id, outbound_peer_count) do
    wait_until(
      fn ->
        with {:ok, peer_pid} <- Registry.lookup_peer({:peer, room_id, participant_id}),
             %{pc: pc} <- :sys.get_state(peer_pid) do
          transceivers = ExWebRTC.PeerConnection.get_transceivers(pc)

          transceiver_count(transceivers, :recvonly, :video) == 1 and
            transceiver_count(transceivers, :recvonly, :audio) == 1 and
            transceiver_count(transceivers, :sendonly, :video) == outbound_peer_count and
            transceiver_count(transceivers, :sendonly, :audio) == outbound_peer_count
        else
          _other -> false
        end
      end,
      500
    )
  end

  defp transceiver_count(transceivers, direction, kind) do
    Enum.count(transceivers, fn transceiver ->
      transceiver.direction == direction and transceiver.kind == kind
    end)
  end

  defp assert_eventually_active_track_counts(room_id, expected_counts) do
    wait_until(fn -> active_track_counts_match?(room_id, expected_counts) end, 500)
  rescue
    error in ExUnit.AssertionError ->
      active_tracks = Queries.list_active_tracks(room_id)
      counts = active_track_counts(active_tracks)

      reraise %ExUnit.AssertionError{
                error
                | message:
                    "#{error.message}; expected_counts=#{inspect(expected_counts)} actual_counts=#{inspect(counts)} tracks=#{inspect(active_tracks)}"
              },
              __STACKTRACE__
  end

  defp active_track_counts_match?(room_id, expected_counts) do
    room_id
    |> Queries.list_active_tracks()
    |> active_track_counts()
    |> then(fn counts ->
      Enum.all?(expected_counts, fn {kind, expected_count} ->
        Map.get(counts, Atom.to_string(kind), 0) == expected_count
      end)
    end)
  end

  defp active_track_counts(active_tracks) do
    Enum.frequencies_by(active_tracks, & &1.kind)
  end

  defp assert_eventually_active_track(room_id, participant_id, kind, source) do
    wait_until(
      fn ->
        !!Queries.get_active_track_by_source(room_id, participant_id, kind, source)
      end,
      500
    )

    Queries.get_active_track_by_source(room_id, participant_id, kind, source)
  end

  defp assert_live_sfu_shape(ctx, clients) do
    outbound_peer_count = length(clients) - 1

    Enum.each(clients, fn client ->
      assert_eventually_server_stats_subscriber_count(
        ctx.token,
        client.participant_id,
        outbound_peer_count
      )

      assert_eventually_server_transceiver_shape(
        ctx.room.id,
        client.participant_id,
        outbound_peer_count
      )
    end)
  end

  defp prime_video_track(ctx, client) do
    send(client.pid, {:send_rtp, :video, @video_packet_burst})
    assert_eventually_active_track(ctx.room.id, client.participant_id, "video", "camera")
    drain_probe_rtp()
  end

  defp assert_peer_unregistered(room_id, participant_id) do
    wait_until(
      fn ->
        Registry.lookup_peer({:peer, room_id, participant_id}) == {:error, :not_found}
      end,
      500
    )
  end

  defp assert_no_active_tracks_for(room_id, participant_id) do
    wait_until(
      fn ->
        room_id
        |> Queries.list_active_tracks()
        |> Enum.any?(&(&1.participant_id == participant_id))
        |> Kernel.not()
      end,
      500
    )
  end

  defp drain_probe_rtp do
    receive do
      {:sfu_probe, _name, :rtp, _kind, _track_id, _sequence} -> drain_probe_rtp()
    after
      0 -> :ok
    end
  end

  defp drain_probe_messages do
    receive do
      {:sfu_probe, _name, _event} -> drain_probe_messages()
      {:sfu_probe, _name, _event, _payload} -> drain_probe_messages()
      {:sfu_probe, _name, _event, _payload1, _payload2} -> drain_probe_messages()
      {:sfu_probe, _name, _event, _payload1, _payload2, _payload3} -> drain_probe_messages()
    after
      0 -> :ok
    end
  end

  defp drain_probe_rtcp do
    receive do
      {:sfu_probe, _name, :rtcp_pli, _track_id} -> drain_probe_rtcp()
    after
      0 -> :ok
    end
  end

  defp assert_missing_local_track(name, kind) do
    assert_receive {:sfu_probe, ^name, :missing_local_track, ^kind}, 1_000
  end

  defp assert_video_rtp_counts(names, min_count \\ @min_forwarded_packets, timeout \\ 5_000) do
    assert_rtp_counts(names, :video, min_count, timeout)
  end

  defp send_and_assert_audio_rtp_counts(client, names) do
    counts = Map.new(names, &{&1, 0})
    counts = send_and_collect_rtp_counts(client.pid, :audio, counts, @min_forwarded_packets, 5)

    assert Enum.all?(counts, fn {_name, count} -> count >= @min_forwarded_packets end),
           "expected at least #{@min_forwarded_packets} audio RTP packets per target; counts=#{inspect(counts)}"
  end

  defp send_and_collect_rtp_counts(pid, kind, counts, min_count, attempts) do
    cond do
      Enum.all?(counts, fn {_name, count} -> count >= min_count end) ->
        counts

      attempts <= 0 ->
        counts

      true ->
        send(pid, {:send_rtp, kind, packet_burst(kind)})

        counts =
          counts
          |> collect_rtp_counts(kind, 750)
          |> Map.new()

        send_and_collect_rtp_counts(pid, kind, counts, min_count, attempts - 1)
    end
  end

  defp packet_burst(:audio), do: @audio_packet_burst
  defp packet_burst(:video), do: @video_packet_burst

  defp collect_rtp_counts(counts, kind, timeout) do
    deadline = System.monotonic_time(:millisecond) + timeout
    collect_pending_rtp_counts(counts, kind, deadline)
  end

  defp collect_pending_rtp_counts(counts, kind, deadline) do
    remaining = max(deadline - System.monotonic_time(:millisecond), 0)

    receive do
      {:sfu_probe, name, :rtp, ^kind, _track_id, _sequence} ->
        counts =
          if Map.has_key?(counts, name) do
            Map.update!(counts, name, &(&1 + 1))
          else
            counts
          end

        collect_pending_rtp_counts(counts, kind, deadline)

      _other ->
        collect_pending_rtp_counts(counts, kind, deadline)
    after
      remaining ->
        counts
    end
  end

  defp assert_rtp_counts(names, kind, min_count, timeout) do
    deadline = System.monotonic_time(:millisecond) + timeout
    counts = Map.new(names, &{&1, 0})
    await_rtp_counts(counts, kind, min_count, deadline)
  end

  defp assert_rtp_packet_count(name, kind, expected_count, timeout \\ 5_000) do
    deadline = System.monotonic_time(:millisecond) + timeout
    await_rtp_sequences(name, kind, expected_count, [], deadline)
  end

  defp await_rtp_sequences(_name, _kind, expected_count, sequences, _deadline)
       when length(sequences) >= expected_count,
       do: Enum.reverse(sequences)

  defp await_rtp_sequences(name, kind, expected_count, sequences, deadline) do
    remaining = max(deadline - System.monotonic_time(:millisecond), 0)

    receive do
      {:sfu_probe, ^name, :rtp, ^kind, _track_id, sequence} ->
        await_rtp_sequences(name, kind, expected_count, [sequence | sequences], deadline)

      _other ->
        await_rtp_sequences(name, kind, expected_count, sequences, deadline)
    after
      remaining ->
        flunk(
          "expected #{name} to receive #{expected_count} #{kind} RTP packets; received=#{inspect(Enum.reverse(sequences))}"
        )
    end
  end

  defp await_rtp_counts(counts, kind, min_count, deadline) do
    if Enum.all?(counts, fn {_name, count} -> count >= min_count end) do
      :ok
    else
      await_pending_rtp_counts(counts, kind, min_count, deadline)
    end
  end

  defp await_pending_rtp_counts(counts, kind, min_count, deadline) do
    remaining = max(deadline - System.monotonic_time(:millisecond), 0)

    receive do
      {:sfu_probe, name, :rtp, ^kind, _track_id, _sequence} ->
        counts =
          if Map.has_key?(counts, name) do
            Map.update!(counts, name, &(&1 + 1))
          else
            counts
          end

        await_rtp_counts(counts, kind, min_count, deadline)

      _other ->
        await_pending_rtp_counts(counts, kind, min_count, deadline)
    after
      remaining ->
        flunk(
          "expected at least #{min_count} #{kind} RTP packets per target; counts=#{inspect(counts)}"
        )
    end
  end

  defp refute_rtp_for(names, kind, timeout \\ 500) do
    receive do
      {:sfu_probe, name, :rtp, ^kind, _track_id, sequence} ->
        if name in names do
          flunk("expected no #{kind} RTP for #{name}; received sequence=#{sequence}")
        else
          refute_rtp_for(names, kind, timeout)
        end

      _other ->
        refute_rtp_for(names, kind, timeout)
    after
      timeout -> :ok
    end
  end

  defp wait_until(fun, retries \\ 100) do
    case fun.() do
      true ->
        :ok

      _other when retries <= 0 ->
        flunk("condition was not met before timeout")

      _other ->
        Process.sleep(20)
        wait_until(fun, retries - 1)
    end
  end

  defmodule SyntheticPeer do
    alias ExRTP.Packet
    alias ExRTP.Packet.Extension.SourceDescription
    alias ExWebRTC.{ICECandidate, MediaStreamTrack, PeerConnection, SessionDescription}
    alias RetroHexChat.GroupCall

    @mid_uri "urn:ietf:params:rtp-hdrext:sdes:mid"

    def run(parent, config) do
      Process.flag(:trap_exit, true)

      {:ok, pc} =
        PeerConnection.start_link(
          controlling_process: self(),
          ice_servers: [],
          ice_port_range: [0],
          audio_codecs: [:opus],
          video_codecs: [:vp8],
          rtcp_feedbacks: [%{type: :video, feedback: :pli}]
        )

      stream_id = "synthetic-#{config.name}-#{System.unique_integer([:positive])}"
      media = Map.merge(%{audio: true, video: true}, Map.get(config, :media, %{}))

      state = %{
        parent: parent,
        name: config.name,
        token: config.token,
        actor: config.actor,
        pc: pc,
        participant_id: nil,
        local_tracks_added?: false,
        pending_remote_candidates: [],
        last_offer_sdp: nil,
        local_tracks: %{
          audio: maybe_new_track(:audio, stream_id, media.audio),
          video: maybe_new_track(:video, stream_id, media.video)
        },
        remote_tracks: %{audio: [], video: []},
        sequence: %{audio: 1, video: 1}
      }

      {:ok, payload} =
        GroupCall.join_call(config.token, config.actor, self(), %{"browser" => "synthetic"}, %{})

      participant_id = payload.participant.id
      send(parent, {:sfu_probe, config.name, :joined, participant_id})

      loop(%{state | participant_id: participant_id})
    end

    defp loop(state) do
      receive do
        {:"$gen_cast", {:group_call_push, "group_call_offer", payload}} ->
          payload |> handle_offer(state) |> loop()

        {:"$gen_cast", {:group_call_push, "group_call_ice_candidate", payload}} ->
          payload.candidate |> handle_server_candidate(state) |> loop()

        {:"$gen_cast", {:group_call_push, _event, _payload}} ->
          loop(state)

        {:ex_webrtc, pc, {:ice_candidate, candidate}} when pc == state.pc ->
          _ =
            GroupCall.add_ice_candidate(
              state.token,
              state.participant_id,
              ICECandidate.to_json(candidate)
            )

          loop(state)

        {:ex_webrtc, pc, {:connection_state_change, connection_state}} when pc == state.pc ->
          send(state.parent, {:sfu_probe, state.name, :connection_state, connection_state})
          loop(state)

        {:ex_webrtc, pc, {:track, track}} when pc == state.pc ->
          send(state.parent, {:sfu_probe, state.name, :track, track.kind, track.id})

          state =
            update_in(state.remote_tracks[track.kind], fn tracks -> [track.id | tracks] end)

          loop(state)

        {:ex_webrtc, pc, {:rtp, track_id, _rid, %Packet{} = packet}} when pc == state.pc ->
          send(
            state.parent,
            {:sfu_probe, state.name, :rtp, kind_for_track(state, track_id), track_id,
             packet.sequence_number}
          )

          loop(state)

        {:send_rtp, kind, count} when kind in [:audio, :video] ->
          state |> send_rtp(kind, count) |> loop()

        {:send_rtp_sequence, kind, sequences} when kind in [:audio, :video] ->
          state |> send_rtp_sequence(kind, sequences) |> loop()

        {:replace_local_video_track, source} when source in [:camera, :screen] ->
          state |> replace_local_video_track(source) |> loop()

        {:send_pli, kind} when kind in [:audio, :video] ->
          send_pli(state, kind)
          loop(state)

        {:ex_webrtc, pc, {:rtcp, packets}} when pc == state.pc ->
          Enum.each(packets, fn
            {track_id, %{__struct__: ExRTCP.Packet.PayloadFeedback.PLI}} ->
              send(state.parent, {:sfu_probe, state.name, :rtcp_pli, track_id})

            _other ->
              :ok
          end)

          loop(state)

        {:EXIT, pid, reason} when pid == state.pc ->
          send(state.parent, {:sfu_probe, state.name, :peer_connection_exit, reason})

        :stop ->
          PeerConnection.stop(state.pc)
          :ok
      after
        30_000 ->
          send(state.parent, {:sfu_probe, state.name, :idle_timeout})
          PeerConnection.stop(state.pc)
      end
    end

    defp handle_offer(%{sdp: sdp}, %{last_offer_sdp: sdp} = state), do: state

    defp handle_offer(%{sdp: sdp}, state) do
      offer = struct(SessionDescription, type: :offer, sdp: sdp)
      :ok = PeerConnection.set_remote_description(state.pc, offer)

      state = ensure_local_tracks(state)
      state = flush_pending_remote_candidates(state)

      {:ok, answer} = PeerConnection.create_answer(state.pc)
      :ok = PeerConnection.set_local_description(state.pc, answer)
      :ok = GroupCall.answer(state.token, state.participant_id, answer.sdp)

      send(state.parent, {:sfu_probe, state.name, :answered_offer})
      %{state | last_offer_sdp: sdp}
    end

    defp ensure_local_tracks(%{local_tracks_added?: true} = state), do: state

    defp ensure_local_tracks(state) do
      Enum.each([:audio, :video], fn kind ->
        if track = state.local_tracks[kind] do
          {:ok, _sender} = PeerConnection.add_track(state.pc, track)
        end
      end)

      %{state | local_tracks_added?: true}
    end

    defp handle_server_candidate(candidate_json, %{last_offer_sdp: nil} = state) do
      update_in(state.pending_remote_candidates, &[candidate_json | &1])
    end

    defp handle_server_candidate(candidate_json, state) do
      add_remote_candidate(state.pc, candidate_json)
      state
    end

    defp flush_pending_remote_candidates(state) do
      state.pending_remote_candidates
      |> Enum.reverse()
      |> Enum.each(&add_remote_candidate(state.pc, &1))

      %{state | pending_remote_candidates: []}
    end

    defp add_remote_candidate(pc, candidate_json) do
      candidate = ICECandidate.from_json(candidate_json)
      _ = PeerConnection.add_ice_candidate(pc, candidate)
      :ok
    end

    defp send_rtp(state, kind, count) do
      case state.local_tracks[kind] do
        nil ->
          send(state.parent, {:sfu_probe, state.name, :missing_local_track, kind})
          state

        _track ->
          do_send_rtp(state, kind, count)
      end
    end

    defp replace_local_video_track(state, source) do
      with %{id: _track_id} <- state.local_tracks.video,
           {:ok, sender_id} <- video_sender_id(state) do
        stream_id = "synthetic-#{state.name}-#{source}-#{System.unique_integer([:positive])}"
        track = MediaStreamTrack.new(:video, [stream_id])
        :ok = PeerConnection.replace_track(state.pc, sender_id, track)

        send(state.parent, {:sfu_probe, state.name, :replaced_track, :video, source, track.id})
        put_in(state.local_tracks.video, track)
      else
        _other ->
          send(state.parent, {:sfu_probe, state.name, :missing_local_track, :video})
          state
      end
    end

    defp video_sender_id(state) do
      track = state.local_tracks.video

      PeerConnection.get_transceivers(state.pc)
      |> Enum.find_value(:error, fn
        %{sender: %{id: sender_id, track: %{id: track_id}}}
        when track != nil and track_id == track.id ->
          {:ok, sender_id}

        _other ->
          false
      end)
    end

    defp do_send_rtp(state, kind, count) do
      start_sequence = state.sequence[kind]
      rtp_context = rtp_context_for_kind(state, kind)

      Enum.each(start_sequence..(start_sequence + count - 1), fn sequence ->
        PeerConnection.send_rtp(
          state.pc,
          state.local_tracks[kind].id,
          packet(kind, sequence, rtp_context)
        )
      end)

      put_in(state.sequence[kind], start_sequence + count)
    end

    defp send_rtp_sequence(state, kind, sequences) do
      case state.local_tracks[kind] do
        nil ->
          send(state.parent, {:sfu_probe, state.name, :missing_local_track, kind})
          state

        _track ->
          do_send_rtp_sequence(state, kind, sequences)
      end
    end

    defp do_send_rtp_sequence(state, _kind, []), do: state

    defp do_send_rtp_sequence(state, kind, sequences) do
      rtp_context = rtp_context_for_kind(state, kind)

      Enum.each(sequences, fn sequence ->
        PeerConnection.send_rtp(
          state.pc,
          state.local_tracks[kind].id,
          packet(kind, sequence, rtp_context)
        )
      end)

      put_in(state.sequence[kind], rem(Enum.max(sequences) + 1, 0x1_0000))
    end

    defp send_pli(state, kind) do
      case state.remote_tracks[kind] do
        [track_id | _rest] ->
          PeerConnection.send_pli(state.pc, track_id)

        [] ->
          send(state.parent, {:sfu_probe, state.name, :missing_remote_track, kind})
      end
    end

    defp packet(:audio, sequence, %{payload_type: payload_type} = rtp_context) do
      Packet.new(<<1, 2, rem(sequence, 255)>>,
        payload_type: payload_type,
        sequence_number: sequence,
        timestamp: sequence * 960,
        ssrc: 11_111
      )
      |> add_mid_extension(rtp_context)
    end

    defp packet(:video, sequence, %{payload_type: payload_type} = rtp_context) do
      Packet.new(<<0x10, 0, rem(sequence, 255), 0x80>>,
        payload_type: payload_type,
        sequence_number: sequence,
        timestamp: sequence * 3_000,
        ssrc: 22_222
      )
      |> add_mid_extension(rtp_context)
    end

    defp kind_for_track(state, track_id) do
      cond do
        local_track?(state, :audio, track_id) -> :audio
        local_track?(state, :video, track_id) -> :video
        track_id in state.remote_tracks.audio -> :audio
        track_id in state.remote_tracks.video -> :video
        true -> :unknown
      end
    end

    defp local_track?(state, kind, track_id) do
      case state.local_tracks[kind] do
        %{id: ^track_id} -> true
        _other -> false
      end
    end

    defp rtp_context_for_kind(state, kind) do
      track = state.local_tracks[kind]
      default_context = %{payload_type: default_payload_type(kind), mid: nil, mid_ext_id: nil}

      PeerConnection.get_transceivers(state.pc)
      |> Enum.find_value(default_context, fn
        %{sender: %{track: %{id: track_id}, codec: %{payload_type: payload_type}}}
        when track != nil and track_id == track.id ->
          %{
            payload_type: payload_type,
            mid: track_mid_for_kind(state, kind),
            mid_ext_id: mid_extension_id_for_kind(state, kind)
          }

        _other ->
          false
      end)
    end

    defp track_mid_for_kind(state, kind) do
      track = state.local_tracks[kind]

      PeerConnection.get_transceivers(state.pc)
      |> Enum.find_value(fn
        %{sender: %{track: %{id: track_id}}, mid: mid}
        when track != nil and track_id == track.id ->
          mid

        _other ->
          nil
      end)
    end

    defp mid_extension_id_for_kind(state, kind) do
      track = state.local_tracks[kind]

      PeerConnection.get_transceivers(state.pc)
      |> Enum.find_value(fn
        %{sender: %{track: %{id: track_id}}, header_extensions: header_extensions}
        when track != nil and track_id == track.id ->
          Enum.find_value(header_extensions, fn
            %{id: id, uri: @mid_uri} -> id
            _other -> nil
          end)

        _other ->
          nil
      end)
    end

    defp add_mid_extension(packet, %{mid: mid, mid_ext_id: id})
         when is_binary(mid) and is_integer(id) do
      Packet.add_extension(packet, SourceDescription.to_raw(SourceDescription.new(mid, :mid), id))
    end

    defp add_mid_extension(packet, _rtp_context), do: packet

    defp default_payload_type(:audio), do: 111
    defp default_payload_type(:video), do: 96

    defp maybe_new_track(_kind, _stream_id, false), do: nil
    defp maybe_new_track(kind, stream_id, _enabled?), do: MediaStreamTrack.new(kind, [stream_id])
  end
end
