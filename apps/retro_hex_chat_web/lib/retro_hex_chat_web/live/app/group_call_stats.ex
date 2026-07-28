defmodule RetroHexChatWeb.App.GroupCallStats do
  @moduledoc """
  Normalizes browser `getStats()` samples from the group-call SFU connection.

  The panel renders from a complete map at all times, including before the first
  browser sample arrives.
  """

  @spec normalize(map()) :: map()
  def normalize(payload) when is_map(payload) do
    conn = value(payload, "connection", %{})
    audio = value(payload, "audio", %{})
    video = value(payload, "video", %{})
    summary = value(payload, "summary", %{})

    %{
      updated_at_ms: value(payload, "updated_at_ms", 0),
      connection: %{
        level: value(conn, "level", "excellent"),
        label: value(conn, "label", ""),
        mos: value(conn, "mos", 0),
        rtt_ms: value(conn, "rtt_ms", 0),
        jitter_ms: value(conn, "jitter_ms", 0),
        loss_pct: value(conn, "loss_pct", 0),
        available_kbps: value(conn, "available_kbps", 0)
      },
      audio: %{
        active: value(audio, "active", false),
        in_kbps: value(audio, "in_kbps", 0),
        out_kbps: value(audio, "out_kbps", 0),
        loss_pct: value(audio, "loss_pct", 0),
        jitter_ms: value(audio, "jitter_ms", 0)
      },
      video: %{
        active: value(video, "active", false),
        in_kbps: value(video, "in_kbps", 0),
        out_kbps: value(video, "out_kbps", 0),
        loss_pct: value(video, "loss_pct", 0),
        jitter_ms: value(video, "jitter_ms", 0),
        fps: value(video, "fps", 0),
        width: value(video, "width", 0),
        height: value(video, "height", 0),
        freeze_count: value(video, "freeze_count", 0),
        limitation: value(video, "limitation", "none")
      },
      summary: %{
        connection_state:
          value(summary, "connection_state", value(payload, "connection_state", "")),
        participant_count: value(summary, "participant_count", 0),
        remote_stream_count: value(summary, "remote_stream_count", 0),
        track_count: value(summary, "track_count", 0),
        offer_id: value(summary, "offer_id", ""),
        rejoin_epoch: value(summary, "rejoin_epoch", 0)
      }
    }
  end

  def normalize(_payload), do: empty()

  @spec normalize_server(map()) :: map()
  def normalize_server(payload) when is_map(payload) do
    room = value(payload, "room", %{})
    totals = value(payload, "totals", %{})
    peers = value(payload, "peers", [])

    %{
      updated_at_ms: value(payload, "updated_at_ms", 0),
      room: %{
        status: value(room, "status", "unknown"),
        max_participants: value(room, "max_participants", 0),
        participant_count: value(room, "participant_count", 0),
        pending_count: value(room, "pending_count", 0),
        track_count: value(room, "track_count", 0),
        audio_track_count: value(room, "audio_track_count", 0),
        video_track_count: value(room, "video_track_count", 0),
        screen_track_count: value(room, "screen_track_count", 0)
      },
      peers: normalize_server_peers(peers),
      totals: %{
        peer_count: value(totals, "peer_count", 0),
        connected_peer_count: value(totals, "connected_peer_count", 0),
        connecting_peer_count: value(totals, "connecting_peer_count", 0),
        failed_peer_count: value(totals, "failed_peer_count", 0),
        inbound_track_count: value(totals, "inbound_track_count", 0),
        outbound_peer_count: value(totals, "outbound_peer_count", 0),
        subscriber_count: value(totals, "subscriber_count", 0),
        inbound_packets: value(totals, "inbound_packets", 0),
        inbound_bytes: value(totals, "inbound_bytes", 0),
        outbound_packets: value(totals, "outbound_packets", 0),
        outbound_bytes: value(totals, "outbound_bytes", 0),
        nack_count: value(totals, "nack_count", 0),
        pli_count: value(totals, "pli_count", 0),
        candidate_pair_count: value(totals, "candidate_pair_count", 0),
        nominated_pair_count: value(totals, "nominated_pair_count", 0),
        valid_pair_count: value(totals, "valid_pair_count", 0),
        ice_packets_sent: value(totals, "ice_packets_sent", 0),
        ice_packets_received: value(totals, "ice_packets_received", 0),
        ice_bytes_sent: value(totals, "ice_bytes_sent", 0),
        ice_bytes_received: value(totals, "ice_bytes_received", 0)
      }
    }
  end

  def normalize_server(_payload), do: empty_server()

  @spec empty() :: map()
  def empty do
    %{
      updated_at_ms: 0,
      connection: %{
        level: "excellent",
        label: "",
        mos: 0,
        rtt_ms: 0,
        jitter_ms: 0,
        loss_pct: 0,
        available_kbps: 0
      },
      audio: %{active: false, in_kbps: 0, out_kbps: 0, loss_pct: 0, jitter_ms: 0},
      video: %{
        active: false,
        in_kbps: 0,
        out_kbps: 0,
        loss_pct: 0,
        jitter_ms: 0,
        fps: 0,
        width: 0,
        height: 0,
        freeze_count: 0,
        limitation: "none"
      },
      summary: %{
        connection_state: "",
        participant_count: 0,
        remote_stream_count: 0,
        track_count: 0,
        offer_id: "",
        rejoin_epoch: 0
      }
    }
  end

  @spec empty_server() :: map()
  def empty_server do
    normalize_server(%{})
  end

  defp normalize_server_peers(peers) when is_list(peers) do
    Enum.map(peers, fn peer ->
      inbound = value(peer, "inbound_rtp", %{})
      outbound = value(peer, "outbound_rtp", %{})
      candidate_pairs = value(peer, "candidate_pairs", %{})

      %{
        participant_id: value(peer, "participant_id", nil),
        nickname: value(peer, "nickname", ""),
        connection_state: value(peer, "connection_state", "unknown"),
        ice_connection_state: value(peer, "ice_connection_state", "unknown"),
        signaling_state: value(peer, "signaling_state", "unknown"),
        inbound_track_count: value(peer, "inbound_track_count", 0),
        outbound_peer_count: value(peer, "outbound_peer_count", 0),
        subscriber_count: value(peer, "subscriber_count", 0),
        inbound_rtp: normalize_rtp_summary(inbound),
        outbound_rtp: normalize_rtp_summary(outbound),
        candidate_pairs: %{
          total: value(candidate_pairs, "total", 0),
          nominated: value(candidate_pairs, "nominated", 0),
          valid: value(candidate_pairs, "valid", 0),
          packets_sent: value(candidate_pairs, "packets_sent", 0),
          packets_received: value(candidate_pairs, "packets_received", 0),
          bytes_sent: value(candidate_pairs, "bytes_sent", 0),
          bytes_received: value(candidate_pairs, "bytes_received", 0)
        }
      }
    end)
  end

  defp normalize_server_peers(_peers), do: []

  defp normalize_rtp_summary(summary) do
    %{
      track_count: value(summary, "track_count", 0),
      packets: value(summary, "packets", 0),
      bytes: value(summary, "bytes", 0),
      nack_count: value(summary, "nack_count", 0),
      pli_count: value(summary, "pli_count", 0)
    }
  end

  defp value(map, key, default) when is_map(map) do
    case atom_key(key) do
      nil -> Map.get(map, key, default)
      atom -> Map.get(map, key, Map.get(map, atom, default))
    end
  end

  defp value(_map, _key, default), do: default

  defp atom_key("active"), do: :active
  defp atom_key("audio"), do: :audio
  defp atom_key("audio_track_count"), do: :audio_track_count
  defp atom_key("available_kbps"), do: :available_kbps
  defp atom_key("bytes"), do: :bytes
  defp atom_key("bytes_received"), do: :bytes_received
  defp atom_key("bytes_sent"), do: :bytes_sent
  defp atom_key("candidate_pair_count"), do: :candidate_pair_count
  defp atom_key("candidate_pairs"), do: :candidate_pairs
  defp atom_key("connection"), do: :connection
  defp atom_key("connection_state"), do: :connection_state
  defp atom_key("connected_peer_count"), do: :connected_peer_count
  defp atom_key("connecting_peer_count"), do: :connecting_peer_count
  defp atom_key("failed_peer_count"), do: :failed_peer_count
  defp atom_key("fps"), do: :fps
  defp atom_key("freeze_count"), do: :freeze_count
  defp atom_key("height"), do: :height
  defp atom_key("ice_bytes_received"), do: :ice_bytes_received
  defp atom_key("ice_bytes_sent"), do: :ice_bytes_sent
  defp atom_key("ice_connection_state"), do: :ice_connection_state
  defp atom_key("ice_packets_received"), do: :ice_packets_received
  defp atom_key("ice_packets_sent"), do: :ice_packets_sent
  defp atom_key("in_kbps"), do: :in_kbps
  defp atom_key("inbound_bytes"), do: :inbound_bytes
  defp atom_key("inbound_packets"), do: :inbound_packets
  defp atom_key("inbound_rtp"), do: :inbound_rtp
  defp atom_key("inbound_track_count"), do: :inbound_track_count
  defp atom_key("jitter_ms"), do: :jitter_ms
  defp atom_key("label"), do: :label
  defp atom_key("level"), do: :level
  defp atom_key("limitation"), do: :limitation
  defp atom_key("loss_pct"), do: :loss_pct
  defp atom_key("max_participants"), do: :max_participants
  defp atom_key("mos"), do: :mos
  defp atom_key("nack_count"), do: :nack_count
  defp atom_key("nickname"), do: :nickname
  defp atom_key("nominated"), do: :nominated
  defp atom_key("nominated_pair_count"), do: :nominated_pair_count
  defp atom_key("out_kbps"), do: :out_kbps
  defp atom_key("outbound_bytes"), do: :outbound_bytes
  defp atom_key("outbound_packets"), do: :outbound_packets
  defp atom_key("outbound_peer_count"), do: :outbound_peer_count
  defp atom_key("outbound_rtp"), do: :outbound_rtp
  defp atom_key("offer_id"), do: :offer_id
  defp atom_key("packets"), do: :packets
  defp atom_key("packets_received"), do: :packets_received
  defp atom_key("packets_sent"), do: :packets_sent
  defp atom_key("participant_id"), do: :participant_id
  defp atom_key("participant_count"), do: :participant_count
  defp atom_key("peer_count"), do: :peer_count
  defp atom_key("peers"), do: :peers
  defp atom_key("pending_count"), do: :pending_count
  defp atom_key("pli_count"), do: :pli_count
  defp atom_key("remote_stream_count"), do: :remote_stream_count
  defp atom_key("rejoin_epoch"), do: :rejoin_epoch
  defp atom_key("room"), do: :room
  defp atom_key("rtt_ms"), do: :rtt_ms
  defp atom_key("signaling_state"), do: :signaling_state
  defp atom_key("screen_track_count"), do: :screen_track_count
  defp atom_key("status"), do: :status
  defp atom_key("subscriber_count"), do: :subscriber_count
  defp atom_key("summary"), do: :summary
  defp atom_key("total"), do: :total
  defp atom_key("track_count"), do: :track_count
  defp atom_key("totals"), do: :totals
  defp atom_key("updated_at_ms"), do: :updated_at_ms
  defp atom_key("valid"), do: :valid
  defp atom_key("valid_pair_count"), do: :valid_pair_count
  defp atom_key("video"), do: :video
  defp atom_key("video_track_count"), do: :video_track_count
  defp atom_key("width"), do: :width
  defp atom_key(_key), do: nil
end
