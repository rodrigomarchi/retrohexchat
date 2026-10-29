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
      idle: (target) => log.push(`idle ${target}`),
      target: "the game",
    },
  );
  return { state, log, steps, flow };
}

/** `n` simulation steps. */
/** A match that serves for 48 steps, then plays; `then` is the serve's end. */
function servingThenPlaying() {
  const then = vi.fn();
  const { flow } = match({
    SERVING: { after: { ticks: 48 }, then, next: "PLAYING" },
    PLAYING: {},
  });
  return { flow, then };
}

function stepTimes(flow, n) {
  for (let i = 0; i < n; i++) flow.step();
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

  it("after: runs `then` and moves to `next` once its steps are counted", () => {
    const { flow, then } = servingThenPlaying();
    flow.go("SERVING");
    stepTimes(flow, 47);
    expect(flow.name).toBe("SERVING");
    flow.step();
    expect(then).toHaveBeenCalledOnce();
    expect(flow.name).toBe("PLAYING");
  });

  it("every: fires `count` times with what remains, then moves on", () => {
    const fired = [];
    const { flow } = match({
      COUNTDOWN: {
        every: { ticks: 60, count: 3 },
        onEvery: (_ctx, left) => fired.push(left),
        next: "SERVING",
      },
      SERVING: {},
    });
    flow.go("COUNTDOWN");
    stepTimes(flow, 120);
    expect(fired).toEqual([2, 1]);
    expect(flow.name).toBe("COUNTDOWN");
    stepTimes(flow, 60);
    expect(fired).toEqual([2, 1, 0]);
    expect(flow.name).toBe("SERVING");
  });

  it("the game steps in every phase once the match begins, and stops in the final one", () => {
    const { flow, log, steps } = match({ PLAYING: {}, SCORED: {}, FINISHED: { final: true } });
    flow.go("PLAYING");
    flow.go("SCORED");
    expect(steps.on).toBe(true);
    flow.go("FINISHED");
    expect(steps.on).toBe(false);
    expect(log).toEqual(["startSteps", "startSteps", "stopSteps"]);
  });

  it("a phase with no tick runs the game's idle each step", () => {
    const { flow, log } = match({ SCORED: {} });
    flow.go("SCORED");
    stepTimes(flow, 2);
    expect(log).toEqual(["startSteps", "idle the game", "idle the game"]);
  });

  it("step: runs the phase's tick, then follows a phase the simulation moved to", () => {
    const enterScored = vi.fn();
    const { flow, state } = match({
      PLAYING: {
        tick: () => {
          state.phase = PHASE.SCORED;
        },
      },
      SCORED: { enter: enterScored, after: { ticks: 90 }, next: "SERVING" },
      SERVING: {},
    });
    flow.go("PLAYING");
    flow.step();
    expect(flow.name).toBe("SCORED");
    expect(enterScored).toHaveBeenCalledOnce();
    stepTimes(flow, 90);
    expect(flow.name).toBe("SERVING");
  });

  it("step: follows a phase changed outside the flow before running any tick", () => {
    const ticked = [];
    const { flow, state } = match({
      PLAYING: { tick: () => ticked.push("PLAYING") },
      SCORED: { tick: () => ticked.push("SCORED") },
    });
    flow.go("PLAYING");
    state.phase = PHASE.SCORED;
    flow.step();
    expect(flow.name).toBe("SCORED");
    expect(ticked).toEqual(["SCORED"]);
  });

  it("steps a game whose state is not built yet: no phase to read is no move to follow", () => {
    const ticks = [];
    const flow = createFlow(
      {
        phases: PHASE,
        initial: "WAITING",
        states: { WAITING: { tick: (game) => ticks.push(game) } },
      },
      {
        readPhase: () => undefined,
        writePhase: () => {},
        startSteps: () => {},
        stopSteps: () => {},
        idle: () => {},
        target: "the game",
      },
    );
    expect(() => stepTimes(flow, 3)).not.toThrow();
    expect(ticks).toEqual(["the game", "the game", "the game"]);
    expect(flow.name).toBe("WAITING");
  });

  it("counts time in steps only, never on the page's timers", () => {
    const fired = [];
    const { flow } = match({
      COUNTDOWN: {
        every: { ticks: 2, count: 2 },
        onEvery: (_ctx, left) => fired.push(left),
        next: "PLAYING",
      },
      PLAYING: {},
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
      COUNTDOWN: { enter: () => seen.push(flow.previous) },
      PLAYING: {
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
      COUNTDOWN: { every: { ticks: 6, count: 1 }, next: "SERVE" },
      SERVE: { as: "COUNTDOWN", after: { ticks: 3 }, next: "PLAYING" },
      PLAYING: {},
    });
    flow.go("COUNTDOWN");
    stepTimes(flow, 6);
    expect(flow.name).toBe("SERVE");
    expect(state.phase).toBe(PHASE.COUNTDOWN);
    stepTimes(flow, 3);
    expect(flow.name).toBe("PLAYING");
    expect(writes).toEqual([]);
  });

  it("next may be chosen when the time is up", () => {
    const { flow, state } = match({
      SCORED: {
        after: { ticks: 1 },
        then: () => {
          state.over = true;
        },
        next: () => (state.over ? "FINISHED" : "SERVING"),
      },
      SERVING: {},
      FINISHED: { final: true },
    });
    flow.go("SCORED");
    flow.step();
    expect(flow.name).toBe("FINISHED");
  });

  it("a final phase is never left", () => {
    const { flow } = match({ FINISHED: { final: true }, SERVING: {} });
    flow.go("FINISHED");
    flow.go("SERVING");
    expect(flow.name).toBe("FINISHED");
  });

  it("stop: nothing pending fires until a phase is entered again", () => {
    const { flow, then } = servingThenPlaying();
    flow.go("SERVING");
    flow.stop();
    stepTimes(flow, 100);
    expect(then).not.toHaveBeenCalled();
    expect(vi.getTimerCount()).toBe(0);
    flow.go("SERVING");
    stepTimes(flow, 48);
    expect(then).toHaveBeenCalledOnce();
  });

  it("going to a new phase drops the old one's count, and a phase entered again counts afresh", () => {
    const then = vi.fn();
    const { flow } = match({
      SERVING: { after: { ticks: 10 }, then, next: "PLAYING" },
      PLAYING: {},
      SCORED: {},
    });
    flow.go("SERVING");
    stepTimes(flow, 9);
    flow.go("SCORED");
    flow.go("SERVING");
    stepTimes(flow, 9);
    expect(then).not.toHaveBeenCalled();
    flow.step();
    expect(then).toHaveBeenCalledOnce();
  });

  it("refuses a table that counts a phase's time other than in ticks", () => {
    expect(() => match({ SERVING: { after: { ms: 800 }, next: "PLAYING" }, PLAYING: {} })).toThrow(
      /SERVING must count its time in ticks/,
    );
  });

  it("refuses a phase it does not know", () => {
    const { flow } = match({});
    expect(() => flow.go("NOPE")).toThrow(/unknown phase NOPE/);
  });

  it("whatever happens, the phase is always one of the declared ones, and a final one holds", () => {
    const states = {
      COUNTDOWN: { every: { ticks: 6, count: 2 }, next: "SERVING" },
      SERVING: { after: { ticks: 3 }, next: "PLAYING" },
      PLAYING: {},
      SCORED: { after: { ticks: 4 }, next: "SERVING" },
      FINISHED: { final: true },
    };
    const action = fc.oneof(
      fc.constantFrom(...Object.keys(states)).map((name) => ({ go: name })),
      fc.integer({ min: 0, max: 20 }).map((n) => ({ wait: n })),
      fc.constant({ step: true }),
    );
    fc.assert(
      fc.property(fc.array(action, { maxLength: 40 }), (actions) => {
        const { flow, state } = match(states);
        let finished = false;
        for (const a of actions) {
          if (a.go) flow.go(a.go);
          if (a.wait) stepTimes(flow, a.wait);
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
