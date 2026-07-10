defmodule RetroHexChat.GroupCall.PeerServer do
  @moduledoc """
  Per-participant WebRTC endpoint for a group call.

  This process owns one `ExWebRTC.PeerConnection`. It emits SDP offers and ICE
  candidates through the Phoenix Channel process and forwards inbound RTP to
  subscriber peer connections.
  """

  use GenServer, restart: :temporary

  require Logger

  alias ExWebRTC.{
    ICECandidate,
    MediaStreamTrack,
    PeerConnection,
    SessionDescription
  }

  alias RetroHexChat.GroupCall.Registry
  alias RetroHexChat.GroupCall.RoomServer
  alias RetroHexChat.GroupCall.RTPForwarder
  alias RetroHexChat.GroupCall.Schema.Participant
  alias RetroHexChat.P2P

  @type state :: %{
          room_pid: pid(),
          room_id: integer(),
          room_token: String.t(),
          participant: Participant.t(),
          signal_pid: pid(),
          pc: pid(),
          inbound_tracks: %{audio: String.t() | nil, video: String.t() | nil},
          inbound_video_ready?: boolean(),
          outbound_tracks: %{integer() => map()},
          peer_tracks: %{integer() => map()},
          pending_peers: MapSet.t(integer() | {:removed, integer()}),
          pending_remote_candidates: [map()],
          last_answer_sdp: String.t() | nil,
          config: map()
        }

  @audio_codecs [:opus]
  @video_codecs [:vp8]

  @spec start_link(map()) :: GenServer.on_start()
  def start_link(args) do
    participant = Map.fetch!(args, :participant)
    name = Registry.peer_via_tuple({:peer, args.room_id, participant.id})
    GenServer.start_link(__MODULE__, args, name: name)
  end

  @spec child_spec(map()) :: Supervisor.child_spec()
  def child_spec(args) do
    %{
      id: {__MODULE__, args.room_id, args.participant.id},
      start: {__MODULE__, :start_link, [args]},
      restart: :temporary
    }
  end

  @spec apply_sdp_answer(integer(), integer(), String.t()) :: :ok | {:error, term()}
  def apply_sdp_answer(room_id, participant_id, answer_sdp) do
    with {:ok, pid} <- Registry.lookup_peer({:peer, room_id, participant_id}) do
      GenServer.cast(pid, {:apply_sdp_answer, answer_sdp})
    end
  end

  @spec add_ice_candidate(integer(), integer(), map()) :: :ok | {:error, term()}
  def add_ice_candidate(room_id, participant_id, candidate) do
    with {:ok, pid} <- Registry.lookup_peer({:peer, room_id, participant_id}) do
      GenServer.cast(pid, {:add_ice_candidate, candidate})
    end
  end

  @spec notify(pid(), term()) :: :ok
  def notify(pid, message) when is_pid(pid), do: GenServer.cast(pid, message)

  @spec add_subscriber(pid(), integer(), map()) :: :ok
  def add_subscriber(pid, participant_id, peer_tracks_spec) when is_pid(pid) do
    GenServer.cast(pid, {:add_subscriber, participant_id, peer_tracks_spec})
  end

  @impl true
  def init(args) do
    participant = Map.fetch!(args, :participant)

    pc_opts = [
      controlling_process: self(),
      # Browser peers receive P2P.ice_servers/1 in the offer payload. The SFU
      # endpoint itself gathers host/public-mapped candidates from SFU config.
      ice_servers: [],
      ice_port_range: args.config.ice_port_range,
      ice_transport_policy: args.config.ice_transport_policy,
      host_to_srflx_ip_mapper: args.config.host_to_srflx_ip_mapper,
      audio_codecs: @audio_codecs,
      video_codecs: @video_codecs,
      rtcp_feedbacks: [%{type: :video, feedback: :pli}]
    ]

    {:ok, pc} = PeerConnection.start_link(pc_opts)
    Process.monitor(pc)
    Process.link(args.signal_pid)

    state = %{
      room_pid: args.room_pid,
      room_id: args.room_id,
      room_token: args.room_token,
      participant: participant,
      signal_pid: args.signal_pid,
      pc: pc,
      inbound_tracks: %{video: nil, audio: nil},
      inbound_video_ready?: false,
      outbound_tracks: %{},
      peer_tracks: %{},
      pending_peers: MapSet.new(),
      pending_remote_candidates: [],
      last_answer_sdp: nil,
      config: args.config
    }

    {:ok, state, {:continue, {:initial_offer, Map.fetch!(args, :peer_ids)}}}
  end

  @impl true
  def handle_continue({:initial_offer, peer_ids}, state) do
    outbound_tracks = setup_transceivers(state.pc, peer_ids)
    {:noreply, %{send_offer(state) | outbound_tracks: outbound_tracks}}
  end

  @impl true
  def handle_cast({:apply_sdp_answer, answer_sdp}, state) do
    answer = struct(SessionDescription, type: :answer, sdp: answer_sdp)

    state =
      if duplicate_answer?(state, answer_sdp) do
        state
      else
        case PeerConnection.set_remote_description(state.pc, answer) do
          :ok ->
            state
            |> Map.put(:last_answer_sdp, answer_sdp)
            |> flush_pending_remote_candidates()
            |> subscribe_to_new_tracks()
            |> handle_pending_peers()

          {:error, reason} ->
            Logger.warning("Unable to apply group-call SDP answer",
              room_token: state.room_token,
              participant_id: state.participant.id,
              reason: inspect(reason)
            )

            state
        end
      end

    {:noreply, state}
  end

  def handle_cast({:add_ice_candidate, candidate_json}, state) do
    if PeerConnection.get_signaling_state(state.pc) == :have_local_offer do
      {:noreply,
       %{state | pending_remote_candidates: [candidate_json | state.pending_remote_candidates]}}
    else
      {:noreply, add_remote_candidate(state, candidate_json)}
    end
  end

  def handle_cast({:add_subscriber, participant_id, spec}, state) do
    {:noreply, put_in(state.peer_tracks[participant_id], RTPForwarder.prepare(spec))}
  end

  def handle_cast({:peer_added, participant_id}, %{participant: %{id: participant_id}} = state) do
    {:noreply, state}
  end

  def handle_cast({:peer_added, participant_id}, state) do
    if PeerConnection.get_signaling_state(state.pc) == :have_local_offer do
      {:noreply, %{state | pending_peers: MapSet.put(state.pending_peers, participant_id)}}
    else
      {:noreply, state |> add_peer(participant_id) |> send_offer(ice_restart?: true)}
    end
  end

  def handle_cast({:peer_removed, participant_id}, state) do
    if PeerConnection.get_signaling_state(state.pc) == :have_local_offer do
      pending_peers =
        if MapSet.member?(state.pending_peers, participant_id) do
          MapSet.delete(state.pending_peers, participant_id)
        else
          MapSet.put(state.pending_peers, {:removed, participant_id})
        end

      {:noreply, %{state | pending_peers: pending_peers}}
    else
      {:noreply, state |> remove_peer(participant_id) |> send_offer(ice_restart?: true)}
    end
  end

  @impl true
  def handle_info({:ex_webrtc, pc, {:ice_candidate, candidate}}, %{pc: pc} = state) do
    send_channel_event(state.signal_pid, "group_call_ice_candidate", %{
      candidate: ICECandidate.to_json(candidate)
    })

    {:noreply, state}
  end

  def handle_info({:ex_webrtc, pc, {:connection_state_change, :connected}}, %{pc: pc} = state) do
    :ok = RoomServer.mark_ready(state.room_pid, state.participant.id)
    {:noreply, state}
  end

  def handle_info({:ex_webrtc, pc, {:connection_state_change, :failed}}, %{pc: pc} = state) do
    {:stop, {:shutdown, :ice_connection_failed}, state}
  end

  def handle_info({:ex_webrtc, pc, {:track, track}}, %{pc: pc} = state) do
    kind = track.kind

    state =
      state
      |> put_in([:inbound_tracks, kind], track.id)
      |> update_peer_track_mungers(kind)

    state =
      if kind == :video do
        %{state | inbound_video_ready?: false}
      else
        state
      end

    :ok =
      RoomServer.track_added(state.room_pid, state.participant.id, %{
        kind: kind,
        webrtc_track_id: track.id,
        stream_id: List.first(track.streams || []),
        codec: nil
      })

    {:noreply, state}
  end

  def handle_info({:ex_webrtc, pc, {:rtp, track_id, _rid, packet}}, %{pc: pc} = state) do
    state =
      case state.inbound_tracks do
        %{video: ^track_id} ->
          %{
            state
            | peer_tracks: broadcast_packet(state.peer_tracks, :video, packet),
              inbound_video_ready?: true
          }

        %{audio: ^track_id} ->
          %{state | peer_tracks: broadcast_packet(state.peer_tracks, :audio, packet)}

        _other ->
          state
      end

    {:noreply, state}
  end

  def handle_info({:ex_webrtc, pc, {:rtcp, packets}}, %{pc: pc} = state) do
    Enum.each(packets, fn packet ->
      if pli_feedback_packet?(packet) do
        request_keyframe_for_source(state)
      else
        :ok
      end
    end)

    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, pc, reason}, %{pc: pc} = state) do
    Logger.warning("Group-call peer connection stopped",
      room_token: state.room_token,
      participant_id: state.participant.id,
      reason: inspect(reason)
    )

    {:stop, {:shutdown, :peer_connection_closed}, state}
  end

  def handle_info(_message, state) do
    {:noreply, state}
  end

  defp setup_transceivers(pc, peer_ids) do
    {:ok, _video_tr} = PeerConnection.add_transceiver(pc, :video, direction: :recvonly)
    {:ok, _audio_tr} = PeerConnection.add_transceiver(pc, :audio, direction: :recvonly)

    Map.new(peer_ids, fn id ->
      {id, add_outbound_track_pair(pc)}
    end)
  end

  defp add_outbound_track_pair(pc) do
    stream_id = MediaStreamTrack.generate_stream_id()
    video_track = MediaStreamTrack.new(:video, [stream_id])
    audio_track = MediaStreamTrack.new(:audio, [stream_id])

    {:ok, video_tr} = PeerConnection.add_transceiver(pc, :video, direction: :sendonly)
    :ok = PeerConnection.replace_track(pc, video_tr.sender.id, video_track)

    {:ok, audio_tr} = PeerConnection.add_transceiver(pc, :audio, direction: :sendonly)
    :ok = PeerConnection.replace_track(pc, audio_tr.sender.id, audio_track)

    %{
      stream: stream_id,
      video: video_track.id,
      audio: audio_track.id,
      transceivers: %{video: video_tr.id, audio: audio_tr.id},
      subscribed?: false
    }
  end

  defp add_peer(state, participant_id) do
    put_in(state.outbound_tracks[participant_id], add_outbound_track_pair(state.pc))
  end

  defp remove_peer(state, participant_id) do
    {_peer_tracks, state} = pop_in(state.peer_tracks[participant_id])
    {spec, state} = pop_in(state.outbound_tracks[participant_id])

    if spec do
      :ok = PeerConnection.stop_transceiver(state.pc, spec.transceivers.video)
      :ok = PeerConnection.stop_transceiver(state.pc, spec.transceivers.audio)
    end

    state
  end

  defp subscribe_to_new_tracks(state) do
    outbound_tracks =
      Map.new(state.outbound_tracks, fn {participant_id, spec} ->
        unless spec.subscribed? do
          spec
          |> Map.delete(:subscribed?)
          |> Map.put(:pc, state.pc)
          |> then(&subscribe_to_peer(state.room_id, participant_id, state.participant.id, &1))
        end

        {participant_id, %{spec | subscribed?: true}}
      end)

    %{state | outbound_tracks: outbound_tracks}
  end

  defp subscribe_to_peer(room_id, publisher_participant_id, subscriber_participant_id, spec) do
    case Registry.lookup_peer({:peer, room_id, publisher_participant_id}) do
      {:ok, pid} -> add_subscriber(pid, subscriber_participant_id, spec)
      {:error, :not_found} -> :ok
    end
  end

  defp handle_pending_peers(state) do
    if Enum.empty?(state.pending_peers) do
      state
    else
      state.pending_peers
      |> Enum.reduce(state, fn
        {:removed, participant_id}, acc -> remove_peer(acc, participant_id)
        participant_id, acc -> add_peer(acc, participant_id)
      end)
      |> send_offer(ice_restart?: true)
      |> Map.put(:pending_peers, MapSet.new())
    end
  end

  defp send_offer(state, opts \\ []) do
    {:ok, offer} = PeerConnection.create_offer(state.pc, ice_restart: opts[:ice_restart?] == true)
    :ok = PeerConnection.set_local_description(state.pc, offer)

    send_channel_event(state.signal_pid, "group_call_offer", %{
      sdp: offer.sdp,
      participant_id: state.participant.id,
      ice_servers: P2P.ice_servers(to_string(state.participant.id))
    })

    %{state | last_answer_sdp: nil}
  end

  defp flush_pending_remote_candidates(state) do
    state.pending_remote_candidates
    |> Enum.reverse()
    |> Enum.reduce(%{state | pending_remote_candidates: []}, &add_remote_candidate(&2, &1))
  end

  defp add_remote_candidate(state, candidate_json) do
    candidate = ICECandidate.from_json(candidate_json)
    _ = PeerConnection.add_ice_candidate(state.pc, candidate)
    state
  end

  defp broadcast_packet(peer_tracks, kind, packet) do
    Map.new(peer_tracks, fn {participant_id, tracks} ->
      tracks =
        RTPForwarder.forward(tracks, kind, packet, fn track_id, forwarded_packet ->
          PeerConnection.send_rtp(tracks.pc, track_id, forwarded_packet)
        end)

      {participant_id, tracks}
    end)
  end

  defp pli_feedback_packet?({_track_id, %{__struct__: ExRTCP.Packet.PayloadFeedback.PLI}}),
    do: true

  defp pli_feedback_packet?(_packet), do: false

  defp request_keyframe_for_source(state) do
    if state.inbound_video_ready? and state.inbound_tracks.video do
      PeerConnection.send_pli(state.pc, state.inbound_tracks.video)
    end
  end

  defp duplicate_answer?(state, answer_sdp) do
    state.last_answer_sdp == answer_sdp and
      PeerConnection.get_signaling_state(state.pc) == :stable
  end

  defp update_peer_track_mungers(state, kind) do
    peer_tracks =
      Map.new(state.peer_tracks, fn {participant_id, tracks} ->
        {participant_id, RTPForwarder.reset_kind(tracks, kind)}
      end)

    %{state | peer_tracks: peer_tracks}
  end

  defp send_channel_event(channel_pid, event, payload) do
    if Process.alive?(channel_pid) do
      GenServer.cast(channel_pid, {:group_call_push, event, payload})
    end
  end
end
