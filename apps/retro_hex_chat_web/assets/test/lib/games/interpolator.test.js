import { describe, it, expect } from "vitest";
import { SnapshotInterpolator } from "../../../js/lib/games/interpolator.js";

function ingest(interpolator, state, snapshot, now) {
  const captured = interpolator.capture(state);
  Object.assign(state, snapshot);
  interpolator.ingest(captured, state, now);
}

describe("SnapshotInterpolator", () => {
  it("is inert for a game that declared nothing to smooth", () => {
    const interpolator = new SnapshotInterpolator();
    const state = { ballX: 10 };

    ingest(interpolator, state, { ballX: 90 }, 0);

    expect(interpolator.enabled).toBe(false);
    expect(interpolator.apply(state, 8)).toBe(false);
    expect(state.ballX).toBe(90);
  });

  it("walks a value from where it was drawn to the authoritative one", () => {
    const interpolator = new SnapshotInterpolator({ keys: ["ballX"] });
    const state = { ballX: 0 };

    ingest(interpolator, state, { ballX: 0 }, 0);
    ingest(interpolator, state, { ballX: 30 }, 30);

    expect(interpolator.apply(state, 30)).toBe(true);
    expect(state.ballX).toBe(0);

    interpolator.apply(state, 45);
    expect(state.ballX).toBeGreaterThan(0);
    expect(state.ballX).toBeLessThan(30);

    // Once a full arrival interval has passed the guest is on the authoritative
    // value, and stops redrawing until the next snapshot.
    expect(interpolator.apply(state, 30 + interpolator.intervalMs)).toBe(false);
    expect(state.ballX).toBe(30);
  });

  it("never interpolates a value the game did not declare", () => {
    const interpolator = new SnapshotInterpolator({ keys: ["ballX"] });
    const state = { ballX: 0, score: 0 };

    ingest(interpolator, state, { ballX: 20, score: 3 }, 0);
    ingest(interpolator, state, { ballX: 40, score: 4 }, 33);
    interpolator.apply(state, 40);

    // A score has no meaningful value between 3 and 4.
    expect(state.score).toBe(4);
  });

  it("snaps a teleport rather than sliding through the field", () => {
    const interpolator = new SnapshotInterpolator({ keys: ["ballX"], snapDistance: 100 });
    const state = { ballX: 600 };

    ingest(interpolator, state, { ballX: 600 }, 0);
    ingest(interpolator, state, { ballX: 20 }, 33);

    interpolator.apply(state, 34);
    expect(state.ballX).toBe(20);
  });

  it("learns the arrival interval from the stream", () => {
    const interpolator = new SnapshotInterpolator({ keys: ["ballX"] });
    const state = { ballX: 0 };
    const initial = interpolator.intervalMs;

    for (let i = 0; i <= 40; i++) ingest(interpolator, state, { ballX: i }, i * 16);

    expect(interpolator.intervalMs).toBeLessThan(initial);
    expect(interpolator.intervalMs).toBeCloseTo(16, 0);
  });

  it("ignores an implausible gap when learning the interval", () => {
    const interpolator = new SnapshotInterpolator({ keys: ["ballX"] });
    const state = { ballX: 0 };

    ingest(interpolator, state, { ballX: 1 }, 0);
    ingest(interpolator, state, { ballX: 2 }, 30_000);

    expect(interpolator.intervalMs).toBeLessThan(100);
  });
});
