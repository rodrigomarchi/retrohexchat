/**
 * Motion between two places over a number of ticks: how far along a movement
 * is (`progress`), the curve it follows (`easeOutCubic`, `easeOutBack`,
 * `bounce`), and where that puts a thing (`tweenPoint`), always on a whole
 * pixel so pixel art is never drawn between two.
 *
 * A curve takes the share of the movement done, 0 to 1, and answers the share
 * of the distance covered. Durations are ticks: a movement freezes with the
 * simulation and replays the same. A module of its own, so the games that
 * never animate do not load it.
 *
 * @module games/core/tween
 */

/** @param {number} from @param {number} to @param {number} t @returns {number} */
export const lerp = (from, to, t) => from + (to - from) * t;

/** Fast at first, landing softly: a card flying to its place. */
export const easeOutCubic = (t) => 1 - (1 - t) ** 3;

const BACK = 1.70158;

/** A little past the end and back: a card settling on a pile. */
export const easeOutBack = (t) => 1 + (BACK + 1) * (t - 1) ** 3 + BACK * (t - 1) ** 2;

/** Falling and bouncing, each bounce lower, until it rests: 0 to 1. */
export function bounce(t) {
  const n = 7.5625;
  const d = 2.75;
  if (t < 1 / d) return n * t * t;
  if (t < 2 / d) return n * (t - 1.5 / d) ** 2 + 0.75;
  if (t < 2.5 / d) return n * (t - 2.25 / d) ** 2 + 0.9375;
  return n * (t - 2.625 / d) ** 2 + 0.984375;
}

/**
 * How far along a movement that began at tick `start` and lasts `ticks` is at
 * tick `now`: 0 before it starts, 1 once it is over.
 * @param {number} start @param {number} ticks @param {number} now
 * @returns {number}
 */
export function progress(start, ticks, now) {
  if (ticks <= 0) return 1;
  return Math.min(1, Math.max(0, (now - start) / ticks));
}

/**
 * Where a thing moving from `from` to `to` is, `t` of the way along a curve,
 * rounded to whole pixels.
 * @param {{ x: number, y: number }} from
 * @param {{ x: number, y: number }} to
 * @param {number} t
 * @param {(t: number) => number} [ease]
 * @returns {{ x: number, y: number }}
 */
export function tweenPoint(from, to, t, ease = (share) => share) {
  const share = ease(t);
  return { x: Math.round(lerp(from.x, to.x, share)), y: Math.round(lerp(from.y, to.y, share)) };
}
