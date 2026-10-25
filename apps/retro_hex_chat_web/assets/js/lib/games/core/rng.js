/**
 * A seeded random number generator: the same seed always gives the same
 * draws, so a match replays the same way. It is mulberry32 (bryc's
 * catalogue of small JS generators), the one the test harness seeds
 * `Math.random` with.
 *
 * `fork(label)` makes an independent stream — the simulation draws from
 * one, the screen's decoration from another — without moving the stream it
 * forked from.
 *
 * @module games/core/rng
 */

/** A new match's seed, from the page's own randomness. */
export function freshSeed() {
  return (Math.random() * 0x100000000) >>> 0;
}

/**
 * The AI's own stream of a match seed: the same whether the page creates
 * the AI before the engine or the engine creates it.
 * @param {number} seed
 * @returns {() => number}
 */
export function aiRandom(seed) {
  return createRng(seed).fork("ai").next;
}

/** FNV-1a: a label as a 32-bit number. */
function hashLabel(label) {
  let h = 0x811c9dc5;
  for (let i = 0; i < label.length; i++) {
    h ^= label.charCodeAt(i);
    h = Math.imul(h, 0x01000193);
  }
  return h >>> 0;
}

/**
 * @param {number} seed
 * @returns {{
 *   next: () => number,
 *   int: (min: number, max: number) => number,
 *   range: (min: number, max: number) => number,
 *   pick: <T>(list: T[]) => T,
 *   fork: (label: string) => ReturnType<typeof createRng>,
 * }}
 */
export function createRng(seed) {
  let state = seed >>> 0;

  /** A draw in [0, 1). */
  const next = () => {
    state = (state + 0x6d2b79f5) >>> 0;
    let t = state;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };

  return {
    next,
    /** An integer from min to max, both included. */
    int: (min, max) => min + Math.floor(next() * (max - min + 1)),
    /** A number in [min, max). */
    range: (min, max) => min + next() * (max - min),
    pick: (list) => list[Math.floor(next() * list.length)],
    fork: (label) => createRng(state ^ hashLabel(label)),
  };
}
