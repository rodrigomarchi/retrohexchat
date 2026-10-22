defmodule RetroHexChatWeb.App.GroupCallStats do
  @moduledoc """
  Normalizes browser `getStats()` samples from the group-call SFU connection.

  The panel renders from a complete map at all times, including before the first
  browser sample arrives.
  """

  import RetroHexChatWeb.App.MediaStats, only: [value: 3]

  alias RetroHexChatWeb.App.MediaStats

  @spec normalize(map()) :: map()
  def normalize(payload) when is_map(payload) do
    summary = value(payload, "summary", %{})

    %{
      updated_at_ms: value(payload, "updated_at_ms", 0),
      connection: MediaStats.connection(value(payload, "connection", %{})),
      audio: MediaStats.audio(value(payload, "audio", %{})),
      video: MediaStats.video(value(payload, "video", %{})),
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
  def empty, do: normalize(%{})

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
end
