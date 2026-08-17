const DEFAULT_DIFFICULTY = "normal";
const DIFFICULTY_NAMES = new Set(["easy", "normal", "hard"]);

/**
 * @param {unknown} difficulty
 * @returns {"easy"|"normal"|"hard"}
 */
export function normalizeFrostAIDifficulty(difficulty) {
  if (typeof difficulty !== "string") return DEFAULT_DIFFICULTY;

  const key = difficulty.toLowerCase();
  return DIFFICULTY_NAMES.has(key) ? key : DEFAULT_DIFFICULTY;
}
