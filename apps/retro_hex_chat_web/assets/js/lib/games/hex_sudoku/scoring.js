/**
 * Hex Sudoku's points: only a win scores, more the faster it was — the clock
 * with what the mistakes and the hints added to it.
 *
 * @module games/hex_sudoku/scoring
 */

import { POINTS } from "./protocol.js";

/** A win's points after `ticks` on the clock: `NUMERATOR` / ticks, a minute at least. */
export const winPoints = (ticks) =>
  Math.floor(POINTS.NUMERATOR / Math.max(ticks, POINTS.MIN_TICKS));
