/**
 * A match's phases as a table.
 *
 * The phase lives in the game's state — it travels in every snapshot — so the
 * flow reads and writes it there rather than keeping its own copy. The
 * simulation may move it too (a point scored, the match won): after each step
 * the flow follows whatever phase the state is in.
 *
 * ```js
 * const flow = createFlow({
 *   phases: PHASE,                     // name → the value on the wire
 *   initial: "WAITING",
 *   states: {
 *     COUNTDOWN: { enter, every: { ms: 1000, count: 3 }, onEvery, next: "SERVING" },
 *     SERVING:   { enter, after: { ms: 800 }, then, next: "PLAYING" },
 *     PLAYING:   { steps: true, tick },   // the simulation runs; it may move the phase
 *     SCORED:    { after: { ms: 1500 }, next: "SERVING" },
 *     FINISHED:  { final: true, enter },
 *   },
 * }, { readPhase, writePhase, startSteps, stopSteps, target });
 * ```
 *
 * A phase's hooks receive `target` (the game). Timed phases count either
 * milliseconds (`ms`, on the page's timers) or simulation steps (`ticks`,
 * counted only while the phase steps).
 *
 * @module games/core/flow
 */

/**
 * @typedef {object} Timing
 * @property {number} [ms]
 * @property {number} [ticks]
 * @property {number} [count] - for `every`: how many times it fires
 */

/**
 * @typedef {object} PhaseSpec
 * @property {(target: unknown) => void} [enter]
 * @property {boolean} [steps] - the simulation runs during this phase
 * @property {(target: unknown) => void} [tick] - one simulation step
 * @property {Timing} [after] - leave for `next` once, after this long
 * @property {(target: unknown) => void} [then] - runs just before leaving
 * @property {Timing} [every] - fire `count` times, then leave for `next`
 * @property {(target: unknown, remaining: number) => void} [onEvery] - each
 *   firing, with how many remain (0 on the last)
 * @property {string|((target: unknown) => string)} [next] - where to go when
 *   the time is up, or a function that chooses it then
 * @property {string} [as] - the phase this state shows on the wire, for a
 *   stretch of the match that has no phase of its own (a serve that waits
 *   while the countdown still shows)
 * @property {boolean} [final] - a match that reaches it never leaves it
 */

/**
 * @param {{ phases: Record<string, number>, initial: string, states: Record<string, PhaseSpec> }} table
 * @param {{
 *   readPhase: () => number,
 *   writePhase: (value: number) => void,
 *   startSteps: () => void,
 *   stopSteps: () => void,
 *   target?: unknown,
 *   setTimer?: (fn: () => void, ms: number) => unknown,
 *   clearTimer?: (handle: unknown) => void,
 * }} ctx
 */
export function createFlow(table, ctx) {
  const { phases, states } = table;
  const nameOf = new Map(Object.entries(phases).map(([name, value]) => [value, name]));
  const setTimer = ctx.setTimer ?? ((fn, ms) => setTimeout(fn, ms));
  const clearTimer = ctx.clearTimer ?? ((handle) => clearTimeout(handle));

  let current = table.initial;
  let previous = null;
  let timer = null;
  let ticks = 0;
  let remaining = 0;

  const spec = (name) => states[name] ?? {};
  const valueOf = (name) => phases[spec(name).as ?? name];

  const cancel = () => {
    if (timer !== null) clearTimer(timer);
    timer = null;
  };

  // `after` and `every` share one countdown: every firing but the last
  // reschedules, and the last (or the only, for `after`) leaves the phase.
  const timing = (s) => s.after ?? s.every ?? null;

  const fire = () => {
    const s = spec(current);
    if (s.every) {
      remaining -= 1;
      s.onEvery?.(ctx.target, remaining);
      if (remaining > 0) {
        arm(s);
        return;
      }
    } else {
      s.then?.(ctx.target);
    }
    if (s.next && spec(current) === s) {
      go(typeof s.next === "function" ? s.next(ctx.target) : s.next);
    }
  };

  const arm = (s) => {
    const t = timing(s);
    if (!t) return;
    ticks = 0;
    if (t.ms !== undefined) timer = setTimer(fire, t.ms);
  };

  function enter(name) {
    cancel();
    previous = current;
    current = name;
    const s = spec(name);
    s.enter?.(ctx.target);
    if (current !== name) return;
    if (s.steps) ctx.startSteps();
    else ctx.stopSteps();
    remaining = s.every?.count ?? 0;
    arm(s);
  }

  // Enter the phase the state is in, if something other than the flow moved
  // it there; returns whether it did.
  function follow() {
    const value = ctx.readPhase();
    const moved = nameOf.get(value);
    if (moved === undefined || value === valueOf(current) || spec(current).final) return false;
    enter(moved);
    return true;
  }

  function go(name) {
    if (valueOf(name) === undefined) throw new Error(`unknown phase ${name}`);
    if (spec(current).final) return;
    ctx.writePhase(valueOf(name));
    enter(name);
  }

  return {
    get name() {
      return current;
    },

    /** The phase this one was entered from. */
    get previous() {
      return previous;
    },

    go,

    /**
     * One simulation step: follow a phase the state was moved to from outside,
     * run the phase's tick, follow a phase the tick moved to, else count it.
     */
    step() {
      follow();
      const s = spec(current);
      s.tick?.(ctx.target);
      if (follow()) return;

      const t = timing(s);
      if (t?.ticks !== undefined && spec(current) === s) {
        ticks += 1;
        if (ticks >= t.ticks) {
          ticks = 0;
          fire();
        }
      }
    },

    /** Cancel whatever was pending. */
    stop: cancel,
  };
}
