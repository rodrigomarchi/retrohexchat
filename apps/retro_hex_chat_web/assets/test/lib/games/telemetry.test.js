import { describe, it, expect, vi } from "vitest";
import { GameTelemetry, percentile } from "../../../js/lib/games/telemetry.js";

function collector(overrides = {}) {
  const samples = [];
  const telemetry = new GameTelemetry({
    gameId: "hex_pong",
    isHost: true,
    intervalMs: 1000,
    onSample: (sample) => samples.push(sample),
    ...overrides,
  });
  telemetry.start(0);
  return { telemetry, samples };
}

describe("GameTelemetry", () => {
  it("emits nothing before the window elapses", () => {
    const { telemetry, samples } = collector();
    telemetry.frameRendered();
    expect(telemetry.maybeFlush(500, "open")).toBeNull();
    expect(samples).toHaveLength(0);
  });

  it("reports rates per second over the window", () => {
    const { telemetry, samples } = collector();

    for (let i = 0; i < 60; i++) telemetry.frameRendered();
    telemetry.stepsRan(60);
    for (let i = 0; i < 30; i++) telemetry.stateSent(25);

    telemetry.maybeFlush(1000, "open");

    expect(samples).toHaveLength(1);
    expect(samples[0]).toMatchObject({
      game_id: "hex_pong",
      role: "host",
      channel_state: "open",
      render_fps: 60,
      step_hz: 60,
      state_out_hz: 30,
      bytes_out: 750,
    });
  });

  it("tags the guest role, because the two sides are what get compared", () => {
    const { telemetry, samples } = collector({ isHost: false });
    telemetry.maybeFlush(1000, "open");
    expect(samples[0].role).toBe("guest");
  });

  it("measures the gaps between arriving snapshots", () => {
    const { telemetry, samples } = collector({ isHost: false });

    let now = 0;
    for (const gap of [16, 16, 16, 400, 16]) {
      now += gap;
      telemetry.stateReceived(25, now);
    }

    telemetry.maybeFlush(1000, "open");

    expect(samples[0].state_gap_p50_ms).toBe(16);
    expect(samples[0].state_gap_max_ms).toBe(400);
  });

  it("counts snapshots dropped under backpressure", () => {
    const { telemetry, samples } = collector();
    telemetry.sendDropped(90_000);
    telemetry.maybeFlush(1000, "open");

    expect(samples[0].send_dropped).toBe(1);
    expect(samples[0].buffered_peak_bytes).toBe(90_000);
  });

  it("resets its counters between windows", () => {
    const { telemetry, samples } = collector();
    telemetry.frameRendered();
    telemetry.maybeFlush(1000, "open");
    telemetry.maybeFlush(2000, "open");

    expect(samples[1].render_fps).toBe(0);
  });

  it("emits nothing once stopped", () => {
    const onSample = vi.fn();
    const { telemetry } = collector({ onSample });
    telemetry.stop();
    expect(telemetry.maybeFlush(5000, "open")).toBeNull();
    expect(onSample).not.toHaveBeenCalled();
  });

  it("bounds retained gap samples in a long match", () => {
    const { telemetry, samples } = collector({ isHost: false });
    for (let i = 1; i <= 5000; i++) telemetry.stateReceived(25, i * 16);
    telemetry.maybeFlush(200_000, "open");
    expect(samples[0].state_gap_p50_ms).toBe(16);
  });
});

describe("percentile", () => {
  it("returns zero for an empty set", () => {
    expect(percentile([], 95)).toBe(0);
  });

  it("uses nearest rank", () => {
    expect(percentile([10, 20, 30, 40], 50)).toBe(20);
    expect(percentile([10, 20, 30, 40], 100)).toBe(40);
  });
});
