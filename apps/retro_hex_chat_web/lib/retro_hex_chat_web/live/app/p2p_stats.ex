defmodule RetroHexChatWeb.App.P2PStats do
  @moduledoc """
  Normalization of the always-on telemetry sample pushed by `LobbyWebRTCHook`
  (`lobby_stats`, every 2.5s) into a fully-populated stats struct, so the
  P2P Statistics panel never guards against missing keys.
  """

  @doc "Normalizes the per-feature payload from LobbyWebRTCHook."
  @spec normalize(map()) :: map()
  def normalize(payload) do
    conn = Map.get(payload, "connection", %{})
    audio = Map.get(payload, "audio", %{})
    video = Map.get(payload, "video", %{})
    game = Map.get(payload, "game", %{})
    file = Map.get(payload, "file", %{})

    %{
      connection: %{
        level: Map.get(conn, "level", "excellent"),
        label: Map.get(conn, "label", ""),
        mos: Map.get(conn, "mos", 0),
        rtt_ms: Map.get(conn, "rtt_ms", 0),
        jitter_ms: Map.get(conn, "jitter_ms", 0),
        loss_pct: Map.get(conn, "loss_pct", 0),
        available_kbps: Map.get(conn, "available_kbps", 0)
      },
      audio: %{
        active: Map.get(audio, "active", false),
        in_kbps: Map.get(audio, "in_kbps", 0),
        out_kbps: Map.get(audio, "out_kbps", 0),
        loss_pct: Map.get(audio, "loss_pct", 0),
        jitter_ms: Map.get(audio, "jitter_ms", 0)
      },
      video: %{
        active: Map.get(video, "active", false),
        in_kbps: Map.get(video, "in_kbps", 0),
        out_kbps: Map.get(video, "out_kbps", 0),
        loss_pct: Map.get(video, "loss_pct", 0),
        jitter_ms: Map.get(video, "jitter_ms", 0),
        fps: Map.get(video, "fps", 0),
        width: Map.get(video, "width", 0),
        height: Map.get(video, "height", 0),
        source: normalize_video_source(Map.get(video, "source")),
        freeze_count: Map.get(video, "freeze_count", 0),
        limitation: Map.get(video, "limitation", "none")
      },
      game: normalize_channel(game),
      file: normalize_channel(file)
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
      file: %{active: false, state: "closed", sent_kbps: 0, recv_kbps: 0, messages: 0}
    }
  end

  @spec normalize_channel(map()) :: map()
  defp normalize_channel(channel) do
    %{
      active: Map.get(channel, "active", false),
      state: Map.get(channel, "state", "closed"),
      sent_kbps: Map.get(channel, "sent_kbps", 0),
      recv_kbps: Map.get(channel, "recv_kbps", 0),
      messages: Map.get(channel, "messages", 0)
    }
  end

  @spec normalize_video_source(term()) :: String.t()
  defp normalize_video_source("screen"), do: "screen"
  defp normalize_video_source(_source), do: "camera"
end
