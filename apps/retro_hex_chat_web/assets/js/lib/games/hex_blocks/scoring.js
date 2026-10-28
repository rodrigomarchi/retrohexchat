/**
 * Hex Blocks' points: the Marathon's for rows cleared, the Sprint's for its time.
 *
 * @module games/hex_blocks/scoring
 */

import { COMBO, LINE_POINTS, SPRINT } from "./protocol.js";

/**
 * Points of `lines` rows cleared by one piece at `level`, the clear `combo`
 * clears into a run of them (0 for the first).
 */
export const clearPoints = (lines, level, combo) =>
  lines === 0 ? 0 : LINE_POINTS[lines] * level + COMBO * Math.max(0, combo) * level;

/** A Sprint won in `ticks`: 10,000 for thirty seconds or less, fewer the longer. */
export const sprintPoints = (ticks) =>
  Math.floor(SPRINT.NUMERATOR / Math.max(ticks, SPRINT.MIN_TICKS));
