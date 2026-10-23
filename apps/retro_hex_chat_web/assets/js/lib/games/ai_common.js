/**
 * The small pieces every game's AI shares.
 * @module games/ai_common
 */

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
