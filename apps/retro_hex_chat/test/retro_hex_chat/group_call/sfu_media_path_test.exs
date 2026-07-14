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
  @min_forwarded_video_packets 12

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

      send(bob_client.pid, {:send_rtp, :video, @video_packet_burst})
      assert_video_rtp_counts([:alice])

      send(alice_client.pid, {:send_rtp, :video, @video_packet_burst})
      assert_video_rtp_counts([:bob])

      assert_server_stats_route(ctx.token, alice_client.participant_id, bob_client.participant_id)
      assert_server_stats_route(ctx.token, bob_client.participant_id, alice_client.participant_id)
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

      assert_remote_video_track(:alice)
      assert_remote_video_track(:bob)
      assert_remote_video_track(:carol)

      drain_probe_rtp()

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
  end

  defp restore_env(key, nil), do: Application.delete_env(:retro_hex_chat, key)
  defp restore_env(key, value), do: Application.put_env(:retro_hex_chat, key, value)

  defp uid, do: System.unique_integer([:positive])
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

  defp start_synthetic_peer(ctx, nick, name) do
    parent = self()

    pid =
      spawn_link(fn ->
        __MODULE__.SyntheticPeer.run(parent, %{
          name: name,
          token: ctx.token,
          actor: %{user_id: nick.id, nickname: nick.nickname}
        })
      end)

    Process.put(:"#{name}_probe", pid)

    assert_receive {:sfu_probe, ^name, :joined, participant_id}, 10_000

    %{pid: pid, participant_id: participant_id}
  end

  defp stop_synthetic_peer(nil), do: :ok

  defp stop_synthetic_peer(pid) when is_pid(pid) do
    if Process.alive?(pid), do: send(pid, :stop)
  end

  defp stop_all_synthetic_peers do
    [:alice_probe, :bob_probe, :carol_probe]
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

  defp drain_probe_rtp do
    receive do
      {:sfu_probe, _name, :rtp, _kind, _track_id, _sequence} -> drain_probe_rtp()
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

  defp assert_video_rtp_counts(names, min_count \\ @min_forwarded_video_packets, timeout \\ 5_000) do
    deadline = System.monotonic_time(:millisecond) + timeout
    counts = Map.new(names, &{&1, 0})
    await_video_rtp_counts(counts, min_count, deadline)
  end

  defp await_video_rtp_counts(counts, min_count, deadline) do
    if Enum.all?(counts, fn {_name, count} -> count >= min_count end) do
      :ok
    else
      await_pending_video_rtp_counts(counts, min_count, deadline)
    end
  end

  defp await_pending_video_rtp_counts(counts, min_count, deadline) do
    remaining = max(deadline - System.monotonic_time(:millisecond), 0)

    receive do
      {:sfu_probe, name, :rtp, :video, _track_id, _sequence} ->
        counts =
          if Map.has_key?(counts, name) do
            Map.update!(counts, name, &(&1 + 1))
          else
            counts
          end

        await_video_rtp_counts(counts, min_count, deadline)

      _other ->
        await_pending_video_rtp_counts(counts, min_count, deadline)
    after
      remaining ->
        flunk(
          "expected at least #{min_count} video RTP packets per target; counts=#{inspect(counts)}"
        )
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
    alias ExWebRTC.{ICECandidate, MediaStreamTrack, PeerConnection, SessionDescription}
    alias RetroHexChat.GroupCall

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
          audio: MediaStreamTrack.new(:audio, [stream_id]),
          video: MediaStreamTrack.new(:video, [stream_id])
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
          :ok =
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
      {:ok, _sender} = PeerConnection.add_track(state.pc, state.local_tracks.audio)
      {:ok, _sender} = PeerConnection.add_track(state.pc, state.local_tracks.video)
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
      start_sequence = state.sequence[kind]

      Enum.each(start_sequence..(start_sequence + count - 1), fn sequence ->
        PeerConnection.send_rtp(state.pc, state.local_tracks[kind].id, packet(kind, sequence))
      end)

      put_in(state.sequence[kind], start_sequence + count)
    end

    defp send_pli(state, kind) do
      case state.remote_tracks[kind] do
        [track_id | _rest] ->
          PeerConnection.send_pli(state.pc, track_id)

        [] ->
          send(state.parent, {:sfu_probe, state.name, :missing_remote_track, kind})
      end
    end

    defp packet(:audio, sequence) do
      Packet.new(<<1, 2, rem(sequence, 255)>>,
        payload_type: 111,
        sequence_number: sequence,
        timestamp: sequence * 960,
        ssrc: 11_111
      )
    end

    defp packet(:video, sequence) do
      Packet.new(<<0x10, 0, rem(sequence, 255), 0x80>>,
        payload_type: 96,
        sequence_number: sequence,
        timestamp: sequence * 3_000,
        ssrc: 22_222
      )
    end

    defp kind_for_track(state, track_id) do
      cond do
        track_id == state.local_tracks.audio.id -> :audio
        track_id == state.local_tracks.video.id -> :video
        true -> :video
      end
    end
  end
end
