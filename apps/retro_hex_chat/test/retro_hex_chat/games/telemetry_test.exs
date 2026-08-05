defmodule RetroHexChat.Games.TelemetryTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.Games.Telemetry

  @moduletag :unit

  describe "normalize/2" do
    test "accepts a well-formed sample from the browser" do
      assert {:ok, sample} =
               Telemetry.normalize(%{
                 "game_id" => "hex_pong",
                 "role" => "guest",
                 "channel_state" => "open",
                 "render_fps" => 59.4,
                 "state_in_hz" => 60.0,
                 "state_gap_p95_ms" => 20
               })

      assert sample.game_id == "hex_pong"
      assert sample.role == "guest"
      assert sample.channel_state == "open"
      assert sample.measurements.render_fps == 59.4
      assert sample.measurements.state_in_hz == 60.0
    end

    test "refuses a game id that is not in the catalog" do
      # A label straight off the wire is unbounded metric cardinality.
      assert :error = Telemetry.normalize(%{"game_id" => "../etc/passwd", "role" => "host"})
      assert :error = Telemetry.normalize(%{"game_id" => "not_a_game", "role" => "host"})
    end

    test "refuses a role outside the two that exist" do
      assert :error = Telemetry.normalize(%{"game_id" => "hex_pong", "role" => "spectator"})
      assert :error = Telemetry.normalize(%{"game_id" => "hex_pong"})
    end

    test "falls back to unknown for an unrecognised channel state" do
      assert {:ok, sample} =
               Telemetry.normalize(%{
                 "game_id" => "hex_pong",
                 "role" => "host",
                 "channel_state" => "on fire"
               })

      assert sample.channel_state == "unknown"
    end

    test "clamps measurements a hostile or broken client could report" do
      assert {:ok, sample} =
               Telemetry.normalize(%{
                 "game_id" => "hex_pong",
                 "role" => "host",
                 "render_fps" => 1_000_000,
                 "state_gap_p95_ms" => -50,
                 "send_dropped" => "not a number"
               })

      assert sample.measurements.render_fps == 500
      assert sample.measurements.state_gap_p95_ms == 0
      assert sample.measurements.send_dropped == 0
    end

    test "fills every measurement even when the client omitted it" do
      assert {:ok, sample} = Telemetry.normalize(%{"game_id" => "hex_pong", "role" => "host"})

      for key <- [:render_fps, :step_hz, :state_in_hz, :state_out_hz, :rtt_ms, :stall_count] do
        assert Map.has_key?(sample.measurements, key)
      end
    end

    test "grafts on the RTT the connection stats already knew" do
      assert {:ok, sample} =
               Telemetry.normalize(%{"game_id" => "hex_pong", "role" => "host"}, %{rtt_ms: 42})

      assert sample.measurements.rtt_ms == 42
    end

    test "accepts atom keys as readily as the string keys the wire uses" do
      assert {:ok, sample} =
               Telemetry.normalize(%{game_id: "hex_pong", role: "host", render_fps: 60})

      assert sample.measurements.render_fps == 60
    end
  end

  describe "health/1" do
    defp measurements(overrides) do
      base = %{render_fps: 60, state_gap_p95_ms: 20, stall_count: 0, send_dropped: 0}
      Map.merge(base, overrides)
    end

    test "a smooth match is ok" do
      assert Telemetry.health(measurements(%{})) == "ok"
    end

    test "a frame rate a player would notice is bad" do
      assert Telemetry.health(measurements(%{render_fps: 12})) == "bad"
    end

    test "snapshots arriving in clumps rather than a stream is bad" do
      assert Telemetry.health(measurements(%{state_gap_p95_ms: 400})) == "bad"
    end

    test "a loop that fell behind is degraded" do
      assert Telemetry.health(measurements(%{stall_count: 3})) == "degraded"
    end

    test "state dropped under backpressure is degraded" do
      assert Telemetry.health(measurements(%{send_dropped: 5})) == "degraded"
    end

    test "an idle sample is not judged on a frame rate of zero" do
      # A game that has not started drawing yet is not a broken game.
      assert Telemetry.health(measurements(%{render_fps: 0})) == "ok"
    end
  end

  describe "report/2" do
    test "emits a telemetry event for a valid sample" do
      event = Telemetry.session_sample_event()
      :telemetry.attach(__MODULE__, event, &__MODULE__.forward/4, self())
      on_exit(fn -> :telemetry.detach(__MODULE__) end)

      Telemetry.report(%{"game_id" => "hex_pong", "role" => "host", "render_fps" => 60})

      assert_receive {:sample, measurements, metadata}
      assert measurements.render_fps == 60
      assert metadata.game_id == "hex_pong"
      assert metadata.role == "host"
      assert metadata.health == "ok"
    end

    test "drops an invalid sample rather than emitting it" do
      event = Telemetry.session_sample_event()
      :telemetry.attach(__MODULE__, event, &__MODULE__.forward/4, self())
      on_exit(fn -> :telemetry.detach(__MODULE__) end)

      assert :ok = Telemetry.report(%{"game_id" => "nope", "role" => "host"})

      refute_receive {:sample, _measurements, _metadata}, 50
    end
  end

  @doc false
  def forward(_event, measurements, metadata, pid) do
    send(pid, {:sample, measurements, metadata})
  end
end
