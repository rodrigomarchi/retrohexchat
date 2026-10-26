/**
 * The pieces the games' AIs share: difficulty names, where a bouncing ball
 * will cross a line, steering toward a target, moving on part of the frames,
 * reacting only every few frames, and their random draws.
 * @module games/core/ai
 */

import { createRng } from "./rng.js";

const STANDARD_DIFFICULTIES = ["easy", "normal", "hard"];

/**
 * A difficulty the AI knows, case-insensitively, or "normal".
 * @param {unknown} difficulty
 * @param {string[]|Record<string, unknown>} [known] - the difficulty names,
 *   or the AI's table keyed by them; easy, normal and hard by default.
 * @returns {string}
 */
export function normalizeDifficulty(difficulty, known = STANDARD_DIFFICULTIES) {
  if (typeof difficulty !== "string") return "normal";

  const key = difficulty.toLowerCase();
  const isKnown = Array.isArray(known) ? known.includes(key) : Object.hasOwn(known, key);
  return isKnown ? key : "normal";
}

/**
 * @param {number} value
 * @param {number} min
 * @param {number} max
 * @returns {number}
 */
export function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

/**
 * For an AI that moves across a field `width` wide and keeps `margin` from
 * either side: the spot moved inside the margins, how risky a spot is for
 * being near a side, and the occasional slip that moves its target sideways
 * by `config.mistakePixels`, `config.mistakeOdds` of the time.
 * @param {number} width
 * @param {number} margin
 */
export function edgeAware(width, margin) {
  const clampX = (x) => Math.max(margin, Math.min(width - margin, x));

  return {
    clampX,
    edgeRisk(x) {
      const left = Math.max(0, margin * 2 - x);
      const right = Math.max(0, x - (width - margin * 2));
      return (left + right) / 8;
    },
    maybeApplyMistake(target, config, rng) {
      if (!target || rng() >= config.mistakeOdds) return target;
      const direction = rng() < 0.5 ? -1 : 1;
      return {
        ...target,
        x: clampX(target.x + direction * config.mistakePixels),
        reason: "mistake",
      };
    },
  };
}

/**
 * Whether a moving thing's position and velocity — `${prefix}X`, `Y`, `VX`
 * and `VY` on the state — are all numbers an AI can project from.
 * @param {object | null | undefined} state
 * @param {string} prefix - e.g. "ball", "fireball"
 * @returns {boolean}
 */
export function finiteMotion(state, prefix) {
  return Boolean(
    state &&
    Number.isFinite(state[`${prefix}X`]) &&
    Number.isFinite(state[`${prefix}Y`]) &&
    Number.isFinite(state[`${prefix}VX`]) &&
    Number.isFinite(state[`${prefix}VY`]),
  );
}

/**
 * A coordinate folded back between two walls, as a ball bouncing off them
 * would be: where a straight-line projection lands once the bounces are in.
 * @param {number} value
 * @param {number} min
 * @param {number} max
 * @param {number} [fallback] - for a value that is not a number
 * @returns {number}
 */
export function reflect(value, min, max, fallback = (min + max) / 2) {
  if (!Number.isFinite(value)) return fallback;
  const span = max - min;
  const cycle = span * 2;
  let offset = (value - min) % cycle;
  if (offset < 0) offset += cycle;
  return offset <= span ? min + offset : max - (offset - span);
}

/**
 * Where a ball crosses the line `target` on its travel axis: it moves from
 * `position` by `velocity` a frame, and across by `crossVelocity` from
 * `cross`, bouncing between `min` and `max`. Null when it never gets there
 * or has already passed. Whether it is coming at all is the caller's to ask.
 * @returns {number|null}
 */
export function interceptAt(position, velocity, target, cross, crossVelocity, min, max, fallback) {
  const frames = (target - position) / velocity;
  if (!Number.isFinite(frames) || frames < 0) return null;
  return reflect(cross + crossVelocity * frames, min, max, fallback);
}

/**
 * The keys to press to get from `from` to `to` on one axis: [less, more],
 * neither inside the dead zone.
 * @param {number} from
 * @param {number} to
 * @param {number} deadzone
 * @returns {[boolean, boolean]}
 */
export function toward(from, to, deadzone) {
  const delta = to - from;
  return [delta < -deadzone, delta > deadzone];
}

/**
 * Whether the AI moves this frame, moving on `duty` of every ten.
 * @param {number} frame
 * @param {number} duty - 0 to 1
 * @returns {boolean}
 */
export function dutyFrame(frame, duty) {
  if (duty >= 1) return true;
  return (frame % 10) / 10 < duty;
}

/**
 * A draw in [0, 1) from `rng`, and 0 for one that is not a number.
 * @param {() => number} rng
 * @returns {number}
 */
export function randomUnit(rng) {
  const value = Number(rng());
  if (!Number.isFinite(value)) return 0;
  return Math.max(0, Math.min(value, 0.999999999));
}

/**
 * An AI's slow reaction: it takes a new look only once every so many
 * frames, and acts on the old one in between.
 * @returns {{ sample: <T>(every: number, look: () => T) => T, reset: () => void }}
 */
export function createReaction() {
  let age = Number.POSITIVE_INFINITY;
  let value;
  return {
    sample(every, look) {
      if (age >= every) {
        value = look();
        age = 0;
      }
      age++;
      return value;
    },
    /** Look again on the next frame. */
    reset() {
      age = Number.POSITIVE_INFINITY;
    },
  };
}

/**
 * The random function an AI draws from: the one it was handed, or — for an
 * AI with a seed of its own — the core's generator from `options.seed` or
 * that seed, else Math.random.
 * @param {{ rng?: () => number, seed?: number }} options
 * @param {number} [seed]
 * @returns {() => number}
 */
export function aiRng(options, seed) {
  if (typeof options.rng === "function") return options.rng;
  if (seed === undefined) return Math.random;
  return createRng(options.seed || seed).next;
}

const TWO_PI = Math.PI * 2;

/**
 * An angle brought into [0, 2π); 0 for one that is not a number.
 * @param {number} angle
 * @returns {number}
 */
export function normalizeAngle(angle) {
  if (!Number.isFinite(angle)) return 0;
  let normalized = angle % TWO_PI;
  if (normalized < 0) normalized += TWO_PI;
  return normalized;
}

/**
 * The shortest signed turn from one heading to another: positive turns
 * right, negative left.
 * @param {number} current
 * @param {number} target
 * @returns {number}
 */
export function rotationDelta(current, target) {
  let delta = normalizeAngle(target) - normalizeAngle(current);
  if (delta > Math.PI) delta -= TWO_PI;
  if (delta < -Math.PI) delta += TWO_PI;
  return delta;
}
