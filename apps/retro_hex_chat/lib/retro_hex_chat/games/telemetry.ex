defmodule RetroHexChat.Games.Telemetry do
  @moduledoc """
  Telemetry for live P2P game sessions, reported by the browsers playing them.

  Game state never touches the server — the two peers exchange it directly over
  a DataChannel — so a match that played badly used to leave no trace anywhere.
  This is the equivalent of the call's quality reporting: each side samples its
  own frame rate, snapshot cadence and channel pressure, and the server turns
  those samples into metrics.

  The signal that matters most is the *asymmetry* between the two peers. The
  host simulates and the guest draws what it is sent, so a host stepping at
  60 Hz beside a guest rendering at 12 fps is the shape of a real problem, and
  every sample carries the role that produced it.

  Samples arrive from the browser and are therefore untrusted: `normalize/2`
  clamps every measurement into a sane range and refuses any game id that is not
  in the catalog, because a label straight off the wire is unbounded metric
  cardinality.
  """

  alias RetroHexChat.Games.Catalog

  @session_sample [:retro_hex_chat, :games, :session, :sample]

  @typedoc "A validated sample, ready to emit."
  @type sample :: %{
          game_id: String.t(),
          role: String.t(),
          channel_state: String.t(),
          health: String.t(),
          measurements: %{atom() => number()}
        }

  # Ceilings exist to bound what a hostile or broken client can report, not to
  # describe what is normal. A 240 Hz display is a real thing; 100_000 fps is not.
  @measurements %{
    window_ms: {0, 120_000},
    render_fps: {0, 500},
    step_hz: {0, 500},
    state_in_hz: {0, 500},
    state_out_hz: {0, 500},
    bytes_in: {0, 100_000_000},
    bytes_out: {0, 100_000_000},
    state_gap_p50_ms: {0, 60_000},
    state_gap_p95_ms: {0, 60_000},
    state_gap_max_ms: {0, 60_000},
    send_dropped: {0, 100_000},
    buffered_peak_bytes: {0, 100_000_000},
    dropped_steps: {0, 100_000},
    stall_count: {0, 100_000}
  }

  @roles ~w(host guest)
  @channel_states ~w(connecting open closing closed unknown)

  @doc """
  Validate a browser-reported sample.

  `extra` carries measurements the server already knows and the game does not —
  today the connection RTT the call's own stats collector reports.
  """
  @spec normalize(map(), map()) :: {:ok, sample()} | :error
  def normalize(payload, extra \\ %{}) when is_map(payload) do
    with {:ok, game_id} <- validate_game_id(fetch(payload, :game_id)),
         {:ok, role} <- validate_enum(fetch(payload, :role), @roles) do
      measurements =
        @measurements
        |> Enum.reduce(%{}, fn {key, {min, max}}, acc ->
          Map.put(acc, key, clamp(fetch(payload, key), min, max))
        end)
        |> put_rtt(extra)

      {:ok,
       %{
         game_id: game_id,
         role: role,
         channel_state: normalize_enum(fetch(payload, :channel_state), @channel_states),
         health: health(measurements),
         measurements: measurements
       }}
    end
  end

  @doc """
  Emit a validated sample as a telemetry event.
  """
  @spec emit_sample(sample()) :: :ok
  def emit_sample(%{measurements: measurements} = sample) do
    :telemetry.execute(@session_sample, measurements, %{
      game_id: sample.game_id,
      role: sample.role,
      channel_state: sample.channel_state,
      health: sample.health
    })
  end

  @doc """
  Validate and emit in one step, ignoring samples that fail validation.
  """
  @spec report(map(), map()) :: :ok
  def report(payload, extra \\ %{}) do
    case normalize(payload, extra) do
      {:ok, sample} -> emit_sample(sample)
      :error -> :ok
    end
  end

  @spec session_sample_event() :: :telemetry.event_name()
  def session_sample_event, do: @session_sample

  @doc """
  Classify a sample so a dashboard can alert without re-deriving the rules.

  A game is judged on what a player would actually notice: a frame rate that has
  fallen out of the smooth range, snapshots arriving in clumps rather than a
  stream, or a channel dropping state because it is already behind.
  """
  @spec health(map()) :: String.t()
  def health(measurements) do
    cond do
      unplayable?(measurements) -> "bad"
      rough?(measurements) -> "degraded"
      true -> "ok"
    end
  end

  # A frame rate of zero is a game that has not started drawing rather than a
  # broken one, so every frame-rate rule below ignores it.
  defp unplayable?(m) do
    (m.render_fps > 0 and m.render_fps < 20) or m.state_gap_p95_ms > 250
  end

  defp rough?(m) do
    m.stall_count > 0 or m.send_dropped > 0 or
      (m.render_fps > 0 and m.render_fps < 45) or m.state_gap_p95_ms > 120
  end

  defp put_rtt(measurements, extra) do
    Map.put(measurements, :rtt_ms, clamp(fetch(extra, :rtt_ms), 0, 60_000))
  end

  defp validate_game_id(value) when is_binary(value) do
    if Catalog.valid_game_id?(value), do: {:ok, value}, else: :error
  end

  defp validate_game_id(_value), do: :error

  defp validate_enum(value, allowed) when is_binary(value) do
    if value in allowed, do: {:ok, value}, else: :error
  end

  defp validate_enum(_value, _allowed), do: :error

  defp normalize_enum(value, allowed) when is_binary(value) do
    if value in allowed, do: value, else: "unknown"
  end

  defp normalize_enum(_value, _allowed), do: "unknown"

  defp clamp(value, min, max) when is_number(value) do
    value |> max(min) |> min(max) |> round_to_tenth()
  end

  defp clamp(value, min, max) when is_binary(value) do
    case Float.parse(value) do
      {number, _rest} -> clamp(number, min, max)
      :error -> min
    end
  end

  defp clamp(_value, min, _max), do: min

  defp round_to_tenth(value) when is_integer(value), do: value
  defp round_to_tenth(value), do: Float.round(value * 1.0, 1)

  defp fetch(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp fetch(_map, _key), do: nil
end
