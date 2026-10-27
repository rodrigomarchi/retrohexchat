/**
 * Hex Mines' points: only a win scores, more the faster it was.
 *
 * @module games/hex_mines/scoring
 */

import { POINTS } from "./protocol.js";

/** A win's points after `ticks` of play: `NUMERATOR` / ticks, a second at least. */
export const winPoints = (ticks) =>
  Math.floor(POINTS.NUMERATOR / Math.max(ticks, POINTS.MIN_TICKS));
