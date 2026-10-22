defmodule RetroHexChatWeb.App.MediaStats do
  @moduledoc """
  The parts of a browser `getStats()` sample a P2P session and a group call
  both report: the connection's quality, and the audio and video streams.

  Each section comes back complete, defaults filled in, so a stats panel
  renders before the first sample arrives and never guards a missing key. The
  sample arrives from a hook with string keys; a test or the server may hand
  over atom keys, and either reads the same.
  """

  @spec connection(term()) :: map()
  def connection(conn) do
    %{
      level: value(conn, "level", "excellent"),
      label: value(conn, "label", ""),
      mos: value(conn, "mos", 0),
      rtt_ms: value(conn, "rtt_ms", 0),
      jitter_ms: value(conn, "jitter_ms", 0),
      loss_pct: value(conn, "loss_pct", 0),
      available_kbps: value(conn, "available_kbps", 0)
    }
  end

  @spec audio(term()) :: map()
  def audio(audio) do
    %{
      active: value(audio, "active", false),
      in_kbps: value(audio, "in_kbps", 0),
      out_kbps: value(audio, "out_kbps", 0),
      loss_pct: value(audio, "loss_pct", 0),
      jitter_ms: value(audio, "jitter_ms", 0)
    }
  end

  @spec video(term()) :: map()
  def video(video) do
    %{
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
    }
  end

  @doc """
  The value under `key` (a string) or under the atom of the same name, else
  `default`. Anything that is not a map has no values. Only atoms that already
  exist are tried, so a payload cannot create new ones.
  """
  @spec value(term(), String.t(), term()) :: term()
  def value(map, key, default) when is_map(map) do
    case Map.fetch(map, key) do
      {:ok, found} -> found
      :error -> Map.get(map, existing_atom(key), default)
    end
  end

  def value(_map, _key, default), do: default

  defp existing_atom(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> nil
  end
end
