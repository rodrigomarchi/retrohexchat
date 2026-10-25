defmodule RetroHexChat.GroupCall.RoomPayload do
  @moduledoc """
  What a group-call room tells its members, built from the room process's
  state: the room, its participants and tracks, and the server-side media
  stats. Pure functions of that state, apart from asking each live peer for
  its stats.
  """

  alias RetroHexChat.GroupCall.{PeerServer, RoomFanout, RoomServer}
  alias RetroHexChat.GroupCall.Schema.{Participant, Room, Track}

  @doc "`summary/1` for the member who just joined, with that member named."
  @spec join(RoomServer.state(), Participant.t()) :: map()
  def join(state, participant) do
    state |> summary() |> Map.put(:participant, participant(participant))
  end

  @doc "The room as every member sees it: who is in, who is waiting, which tracks flow, and the server-side stats."
  @spec summary(RoomServer.state()) :: map()
  def summary(state) do
    %{
      room: room(state.room),
      participants:
        state.participants
        |> Map.values()
        |> Enum.map(&participant(&1.participant)),
      pending_participants:
        state.pending_participants
        |> Map.values()
        |> Enum.map(&participant(&1.participant)),
      tracks: state.tracks |> Map.values() |> Enum.map(&track/1),
      server_stats: server_stats_payload(state)
    }
  end

  defp server_stats_payload(state) do
    peers =
      state
      |> RoomFanout.peer_states()
      |> Enum.map(fn {_participant_id, data} -> peer_stats_payload(data) end)

    %{
      updated_at_ms: System.os_time(:millisecond),
      room: %{
        status: state.room.status,
        max_participants: state.room.max_participants,
        participant_count: map_size(state.participants),
        pending_count: map_size(state.pending_participants),
        track_count: map_size(state.tracks),
        audio_track_count: track_count(state, "audio"),
        video_track_count: track_count(state, "video"),
        screen_track_count: screen_track_count(state)
      },
      peers: peers,
      totals: server_totals(peers)
    }
  end

  defp peer_stats_payload(%{participant: participant, peer_pid: peer_pid}) do
    base = peer_stats_base(participant)

    if is_pid(peer_pid) and Process.alive?(peer_pid) do
      safe_peer_stats(base, peer_pid)
    else
      base
    end
  end

  defp safe_peer_stats(base, peer_pid) do
    Map.merge(base, PeerServer.stats(peer_pid))
  catch
    :exit, _reason -> base
  end

  defp peer_stats_base(participant) do
    %{
      participant_id: participant.id,
      nickname: participant.nickname,
      connection_state: "unknown",
      ice_connection_state: "unknown",
      signaling_state: "unknown",
      inbound_track_count: 0,
      outbound_peer_count: 0,
      subscriber_count: 0,
      inbound_rtp: empty_rtp_summary(),
      outbound_rtp: empty_rtp_summary(),
      candidate_pairs: empty_candidate_pair_summary()
    }
  end

  defp server_totals(peers) do
    %{
      peer_count: length(peers),
      connected_peer_count: count_connection_state(peers, "connected"),
      connecting_peer_count: count_connection_state(peers, "connecting"),
      failed_peer_count: count_connection_state(peers, "failed"),
      inbound_track_count: sum(peers, :inbound_track_count),
      outbound_peer_count: sum(peers, :outbound_peer_count),
      subscriber_count: sum(peers, :subscriber_count),
      inbound_packets: sum_nested(peers, [:inbound_rtp, :packets]),
      inbound_bytes: sum_nested(peers, [:inbound_rtp, :bytes]),
      outbound_packets: sum_nested(peers, [:outbound_rtp, :packets]),
      outbound_bytes: sum_nested(peers, [:outbound_rtp, :bytes]),
      nack_count:
        sum_nested(peers, [:inbound_rtp, :nack_count]) +
          sum_nested(peers, [:outbound_rtp, :nack_count]),
      pli_count:
        sum_nested(peers, [:inbound_rtp, :pli_count]) +
          sum_nested(peers, [:outbound_rtp, :pli_count]),
      candidate_pair_count: sum_nested(peers, [:candidate_pairs, :total]),
      nominated_pair_count: sum_nested(peers, [:candidate_pairs, :nominated]),
      valid_pair_count: sum_nested(peers, [:candidate_pairs, :valid]),
      ice_packets_sent: sum_nested(peers, [:candidate_pairs, :packets_sent]),
      ice_packets_received: sum_nested(peers, [:candidate_pairs, :packets_received]),
      ice_bytes_sent: sum_nested(peers, [:candidate_pairs, :bytes_sent]),
      ice_bytes_received: sum_nested(peers, [:candidate_pairs, :bytes_received])
    }
  end

  defp track_count(state, kind) do
    state.tracks
    |> Map.values()
    |> Enum.count(&(&1.kind == kind))
  end

  defp screen_track_count(state) do
    state.tracks
    |> Map.values()
    |> Enum.count(&(&1.kind == "video" and &1.source == "screen"))
  end

  defp count_connection_state(peers, state) do
    Enum.count(peers, &(Map.get(&1, :connection_state) == state))
  end

  defp sum(peers, key) do
    Enum.reduce(peers, 0, &(&2 + integer(Map.get(&1, key))))
  end

  defp sum_nested(peers, path) do
    Enum.reduce(peers, 0, &(&2 + integer(get_in(&1, path))))
  end

  defp integer(value) when is_integer(value), do: value

  defp integer(value) when is_float(value), do: trunc(value)

  defp integer(_value), do: 0

  defp empty_rtp_summary do
    %{track_count: 0, packets: 0, bytes: 0, nack_count: 0, pli_count: 0}
  end

  defp empty_candidate_pair_summary do
    %{
      total: 0,
      nominated: 0,
      valid: 0,
      packets_sent: 0,
      packets_received: 0,
      bytes_sent: 0,
      bytes_received: 0
    }
  end

  @doc "The room's own fields, as members are told them."
  @spec room(Room.t()) :: map()
  def room(room) do
    %{
      id: room.id,
      token: room.token,
      channel_name: room.channel_name,
      status: room.status,
      max_participants: room.max_participants,
      metadata: room.metadata,
      inserted_at: room.inserted_at,
      opened_at: room.opened_at,
      activated_at: room.activated_at
    }
  end

  @doc "A participant as the other members are told it."
  @spec participant(Participant.t()) :: map()
  def participant(participant) do
    %{
      id: participant.id,
      nickname: participant.nickname,
      status: participant.status,
      media_state: participant.media_state,
      channel_role_snapshot: participant.channel_role_snapshot
    }
  end

  @doc "A published track as its subscribers are told it."
  @spec track(Track.t()) :: map()
  def track(track) do
    %{
      id: track.id,
      participant_id: track.participant_id,
      kind: track.kind,
      source: track.source,
      status: track.status,
      webrtc_track_id: track.webrtc_track_id,
      stream_id: track.stream_id,
      metadata: metadata(track)
    }
  end

  @doc "`track/1`, or nil for no track."
  @spec maybe_track(Track.t() | nil) :: map() | nil
  def maybe_track(nil), do: nil

  def maybe_track(track), do: track(track)

  defp metadata(%{metadata: metadata}) when is_map(metadata), do: metadata
  defp metadata(_track), do: %{}
end
