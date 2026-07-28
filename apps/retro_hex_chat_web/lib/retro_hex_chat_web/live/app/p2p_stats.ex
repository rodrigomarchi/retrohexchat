defmodule RetroHexChatWeb.App.P2PStats do
  @moduledoc """
  Normalization of the always-on telemetry sample pushed by `LobbyWebRTCHook`
  (`lobby_stats`, every 2.5s) into a fully-populated stats struct, so the
  P2P Stats section never guards against missing keys.
  """

  @doc "Normalizes the per-feature payload from LobbyWebRTCHook."
  @spec normalize(map()) :: map()
  def normalize(payload) do
    conn = value(payload, "connection", %{})
    audio = value(payload, "audio", %{})
    video = value(payload, "video", %{})
    game = value(payload, "game", %{})
    file = value(payload, "file", %{})
    summary = value(payload, "summary", %{})

    %{
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
        source: normalize_video_source(value(video, "source", nil)),
        freeze_count: value(video, "freeze_count", 0),
        limitation: value(video, "limitation", "none")
      },
      game: normalize_channel(game),
      file: normalize_channel(file),
      summary: %{
        connection_state: value(summary, "connection_state", ""),
        ice_connection_state: value(summary, "ice_connection_state", ""),
        signaling_epoch: value(summary, "signaling_epoch", 0),
        offer_id: value(summary, "offer_id", "")
      }
    }
  end

  @doc """
  A zeroed statistics struct so the panel renders complete before the first
  sample (and whenever there is no connection yet).
  """
  @spec empty() :: map()
  def empty do
    %{
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
        source: "camera",
        freeze_count: 0,
        limitation: "none"
      },
      game: %{active: false, state: "closed", sent_kbps: 0, recv_kbps: 0, messages: 0},
      file: %{active: false, state: "closed", sent_kbps: 0, recv_kbps: 0, messages: 0},
      summary: %{
        connection_state: "",
        ice_connection_state: "",
        signaling_epoch: 0,
        offer_id: ""
      }
    }
  end

  @spec normalize_channel(map()) :: map()
  defp normalize_channel(channel) do
    %{
      active: value(channel, "active", false),
      state: value(channel, "state", "closed"),
      sent_kbps: value(channel, "sent_kbps", 0),
      recv_kbps: value(channel, "recv_kbps", 0),
      messages: value(channel, "messages", 0)
    }
  end

  defp value(map, key, default) when is_map(map) do
    Map.get(map, key, Map.get(map, String.to_existing_atom(key), default))
  rescue
    ArgumentError -> Map.get(map, key, default)
  end

  defp value(_map, _key, default), do: default

  @spec normalize_video_source(term()) :: String.t()
  defp normalize_video_source("screen"), do: "screen"
  defp normalize_video_source(_source), do: "camera"
end
