import { describe, it, expect } from "vitest";
import { FrameClock, FIXED_STEP_MS, MAX_CATCHUP_STEPS } from "../../../js/lib/games/frame_clock.js";

describe("FrameClock", () => {
  it("produces no steps on the first reading", () => {
    const clock = new FrameClock();
    expect(clock.advance(1000)).toBe(0);
  });

  it("runs one step per elapsed step duration", () => {
    const clock = new FrameClock();
    clock.advance(0);
    expect(clock.advance(FIXED_STEP_MS)).toBe(1);
    expect(clock.advance(FIXED_STEP_MS * 2)).toBe(1);
  });

  it("runs the same number of steps whatever the display refresh rate", () => {
    const run = (frameMs, frames) => {
      const clock = new FrameClock();
      let steps = 0;
      for (let i = 0; i <= frames; i++) steps += clock.advance(i * frameMs);
      return steps;
    };

    // A second of wall time is a second of simulation on a 60Hz panel and on a
    // 120Hz one. Driving steps straight off rAF ran the match at double speed.
    const at60 = run(1000 / 60, 60);
    const at120 = run(1000 / 120, 120);

    // Within a step of each other — the old loop ran 120 steps against 60.
    expect(Math.abs(at60 - at120)).toBeLessThanOrEqual(1);
    expect(at60).toBeGreaterThanOrEqual(59);
    expect(at120).toBeLessThanOrEqual(60);
  });

  it("catches up a short backlog", () => {
    const clock = new FrameClock();
    clock.advance(0);
    expect(clock.advance(FIXED_STEP_MS * 3)).toBe(3);
  });

  it("discards a long backlog instead of fast-forwarding the match", () => {
    const clock = new FrameClock();
    clock.advance(0);

    // The tab was hidden for a minute.
    const steps = clock.advance(60_000);

    expect(steps).toBeLessThanOrEqual(MAX_CATCHUP_STEPS);
    expect(clock.droppedSteps).toBeGreaterThan(3000);
    expect(clock.stallCount).toBe(1);
  });

  it("drains stall counters once", () => {
    const clock = new FrameClock();
    clock.advance(0);
    clock.advance(10_000);

    const first = clock.drainStalls();
    expect(first.stallCount).toBe(1);
    expect(clock.drainStalls()).toEqual({ droppedSteps: 0, stallCount: 0 });
  });

  it("ignores time running backwards", () => {
    const clock = new FrameClock();
    clock.advance(1000);
    expect(clock.advance(500)).toBe(0);
  });
});
