defmodule RetroHexChatWeb.App.P2PStats do
  @moduledoc """
  Normalization of the always-on telemetry sample pushed by `LobbyWebRTCHook`
  (`lobby_stats`, every 2.5s) into a fully-populated stats struct, so the
  P2P Stats section never guards against missing keys.
  """

  import RetroHexChatWeb.App.MediaStats, only: [value: 3]

  alias RetroHexChatWeb.App.MediaStats

  @doc "Normalizes the per-feature payload from LobbyWebRTCHook."
  @spec normalize(term()) :: map()
  def normalize(payload) do
    video = value(payload, "video", %{})
    summary = value(payload, "summary", %{})

    %{
      connection: MediaStats.connection(value(payload, "connection", %{})),
      audio: MediaStats.audio(value(payload, "audio", %{})),
      video:
        video
        |> MediaStats.video()
        |> Map.put(:source, normalize_video_source(value(video, "source", nil))),
      game: normalize_channel(value(payload, "game", %{})),
      file: normalize_channel(value(payload, "file", %{})),
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
  def empty, do: normalize(%{})

  @spec normalize_channel(term()) :: map()
  defp normalize_channel(channel) do
    %{
      active: value(channel, "active", false),
      state: value(channel, "state", "closed"),
      sent_kbps: value(channel, "sent_kbps", 0),
      recv_kbps: value(channel, "recv_kbps", 0),
      messages: value(channel, "messages", 0)
    }
  end

  @spec normalize_video_source(term()) :: String.t()
  defp normalize_video_source("screen"), do: "screen"
  defp normalize_video_source(_source), do: "camera"
end
