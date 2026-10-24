import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import fc from "fast-check";
import { createFlow } from "../../../../js/lib/games/core/flow.js";

const PHASE = { WAITING: 0, COUNTDOWN: 1, SERVING: 2, PLAYING: 3, SCORED: 4, FINISHED: 5 };

/** A match whose phase lives in its state, as every game's does. */
function match(states, initial = "WAITING") {
  const state = { phase: PHASE[initial] };
  const log = [];
  const steps = { on: false };
  const flow = createFlow(
    { phases: PHASE, initial, states },
    {
      readPhase: () => state.phase,
      writePhase: (value) => {
        state.phase = value;
      },
      startSteps: () => {
        steps.on = true;
        log.push("startSteps");
      },
      stopSteps: () => {
        steps.on = false;
        log.push("stopSteps");
      },
      target: "the game",
    },
  );
  return { state, log, steps, flow };
}

describe("flow", () => {
  beforeEach(() => vi.useFakeTimers());
  afterEach(() => vi.useRealTimers());

  it("starts in its initial phase and does nothing until told", () => {
    const { flow, state, log } = match({});
    expect(flow.name).toBe("WAITING");
    expect(state.phase).toBe(PHASE.WAITING);
    vi.advanceTimersByTime(10_000);
    expect(log).toEqual([]);
  });

  it("go: writes the phase into the state, then runs its enter with the target", () => {
    const seen = [];
    const { flow, state } = match({
      SERVING: { enter: (target) => seen.push([target, state.phase]) },
    });
    flow.go("SERVING");
    expect(state.phase).toBe(PHASE.SERVING);
    expect(seen).toEqual([["the game", PHASE.SERVING]]);
  });

  it("after ms: runs `then` and moves to `next` when the time is up", () => {
    const then = vi.fn();
    const { flow } = match({ SERVING: { after: { ms: 800 }, then, next: "PLAYING" }, PLAYING: {} });
    flow.go("SERVING");
    vi.advanceTimersByTime(799);
    expect(flow.name).toBe("SERVING");
    vi.advanceTimersByTime(1);
    expect(then).toHaveBeenCalledOnce();
    expect(flow.name).toBe("PLAYING");
  });

  it("every ms: fires `count` times with what remains, then moves on", () => {
    const fired = [];
    const { flow } = match({
      COUNTDOWN: {
        every: { ms: 1000, count: 3 },
        onEvery: (_ctx, left) => fired.push(left),
        next: "SERVING",
      },
      SERVING: {},
    });
    flow.go("COUNTDOWN");
    vi.advanceTimersByTime(2000);
    expect(fired).toEqual([2, 1]);
    expect(flow.name).toBe("COUNTDOWN");
    vi.advanceTimersByTime(1000);
    expect(fired).toEqual([2, 1, 0]);
    expect(flow.name).toBe("SERVING");
  });

  it("steps: a phase that steps starts the simulation, one that does not stops it", () => {
    const { flow, log, steps } = match({ PLAYING: { steps: true }, SCORED: {} });
    flow.go("PLAYING");
    expect(steps.on).toBe(true);
    flow.go("SCORED");
    expect(steps.on).toBe(false);
    expect(log).toEqual(["startSteps", "stopSteps"]);
  });

  it("step: runs the phase's tick, then follows a phase the simulation moved to", () => {
    const enterScored = vi.fn();
    const { flow, state } = match({
      PLAYING: {
        steps: true,
        tick: () => {
          state.phase = PHASE.SCORED;
        },
      },
      SCORED: { enter: enterScored, after: { ms: 1500 }, next: "SERVING" },
      SERVING: {},
    });
    flow.go("PLAYING");
    flow.step();
    expect(flow.name).toBe("SCORED");
    expect(enterScored).toHaveBeenCalledOnce();
    vi.advanceTimersByTime(1500);
    expect(flow.name).toBe("SERVING");
  });

  it("step: follows a phase changed outside the flow before running any tick", () => {
    const ticked = [];
    const { flow, state } = match({
      PLAYING: { steps: true, tick: () => ticked.push("PLAYING") },
      SCORED: { steps: true, tick: () => ticked.push("SCORED") },
    });
    flow.go("PLAYING");
    state.phase = PHASE.SCORED;
    flow.step();
    expect(flow.name).toBe("SCORED");
    expect(ticked).toEqual(["SCORED"]);
  });

  it("after and every count ticks when given ticks, only while stepping", () => {
    const fired = [];
    const { flow } = match({
      COUNTDOWN: {
        steps: true,
        every: { ticks: 2, count: 2 },
        onEvery: (_ctx, left) => fired.push(left),
        next: "PLAYING",
      },
      PLAYING: { steps: true },
    });
    flow.go("COUNTDOWN");
    vi.advanceTimersByTime(10_000);
    expect(fired).toEqual([]);
    flow.step();
    flow.step();
    expect(fired).toEqual([1]);
    flow.step();
    flow.step();
    expect(fired).toEqual([1, 0]);
    expect(flow.name).toBe("PLAYING");
  });

  it("previous: a phase knows which one it came from, by a move or by the simulation", () => {
    const seen = [];
    const { flow, state } = match({
      COUNTDOWN: { steps: true, enter: () => seen.push(flow.previous) },
      PLAYING: {
        steps: true,
        tick: () => {
          state.phase = PHASE.COUNTDOWN;
        },
      },
    });
    flow.go("COUNTDOWN");
    flow.go("PLAYING");
    flow.step();
    expect(seen).toEqual(["WAITING", "PLAYING"]);
  });

  it("as: a state can show another phase on the wire, and the state is not rewritten", () => {
    const writes = [];
    const { flow, state } = match({
      COUNTDOWN: { every: { ms: 100, count: 1 }, next: "SERVE" },
      SERVE: { as: "COUNTDOWN", after: { ms: 50 }, next: "PLAYING" },
      PLAYING: {},
    });
    flow.go("COUNTDOWN");
    vi.advanceTimersByTime(100);
    expect(flow.name).toBe("SERVE");
    expect(state.phase).toBe(PHASE.COUNTDOWN);
    vi.advanceTimersByTime(50);
    expect(flow.name).toBe("PLAYING");
    expect(writes).toEqual([]);
  });

  it("next may be chosen when the time is up", () => {
    const { flow, state } = match({
      SCORED: {
        after: { ms: 10 },
        then: () => {
          state.over = true;
        },
        next: () => (state.over ? "FINISHED" : "SERVING"),
      },
      SERVING: {},
      FINISHED: { final: true },
    });
    flow.go("SCORED");
    vi.advanceTimersByTime(10);
    expect(flow.name).toBe("FINISHED");
  });

  it("a final phase is never left", () => {
    const { flow } = match({ FINISHED: { final: true }, SERVING: {} });
    flow.go("FINISHED");
    flow.go("SERVING");
    expect(flow.name).toBe("FINISHED");
  });

  it("stop: cancels whatever was pending", () => {
    const then = vi.fn();
    const { flow } = match({ SERVING: { after: { ms: 800 }, then, next: "PLAYING" }, PLAYING: {} });
    flow.go("SERVING");
    flow.stop();
    vi.advanceTimersByTime(5000);
    expect(then).not.toHaveBeenCalled();
    expect(vi.getTimerCount()).toBe(0);
  });

  it("going to a new phase cancels the old one's timer", () => {
    const then = vi.fn();
    const { flow } = match({
      SERVING: { after: { ms: 800 }, then, next: "PLAYING" },
      PLAYING: {},
      SCORED: {},
    });
    flow.go("SERVING");
    flow.go("SCORED");
    vi.advanceTimersByTime(5000);
    expect(then).not.toHaveBeenCalled();
  });

  it("refuses a phase it does not know", () => {
    const { flow } = match({});
    expect(() => flow.go("NOPE")).toThrow(/unknown phase NOPE/);
  });

  it("whatever happens, the phase is always one of the declared ones, and a final one holds", () => {
    const states = {
      COUNTDOWN: { every: { ms: 100, count: 2 }, next: "SERVING" },
      SERVING: { after: { ms: 50 }, next: "PLAYING" },
      PLAYING: { steps: true },
      SCORED: { after: { ms: 70 }, next: "SERVING" },
      FINISHED: { final: true },
    };
    const action = fc.oneof(
      fc.constantFrom(...Object.keys(states)).map((name) => ({ go: name })),
      fc.integer({ min: 0, max: 300 }).map((ms) => ({ wait: ms })),
      fc.constant({ step: true }),
    );
    fc.assert(
      fc.property(fc.array(action, { maxLength: 40 }), (actions) => {
        const { flow, state } = match(states);
        let finished = false;
        for (const a of actions) {
          if (a.go) flow.go(a.go);
          if (a.wait) vi.advanceTimersByTime(a.wait);
          if (a.step) flow.step();
          expect(Object.values(PHASE)).toContain(state.phase);
          if (finished) expect(flow.name).toBe("FINISHED");
          if (flow.name === "FINISHED") finished = true;
        }
        flow.stop();
      }),
    );
  });
});
