/**
 * The classic scoring: what each move pays, what time costs, and the bonus
 * a fast win earns. Pure functions; the score never falls below zero.
 *
 * @module games/hex_solitaire/scoring
 */

import { POINTS } from "./protocol.js";

export { addPoints, startClock, tickClock, timeBonus } from "../core/card_table/clock.js";

/**
 * The points of a move (`rules.js`), and of the card it turned over.
 * @param {{ from: { pile: string }, to: { pile: string } }} move
 * @param {boolean} flipped
 * @returns {number}
 */
export function scoreMove(move, flipped) {
  const flip = flipped ? POINTS.FLIP : 0;
  if (move.to.pile === "foundation") return POINTS.TO_FOUNDATION + flip;
  if (move.from.pile === "waste") return POINTS.WASTE_TO_TABLEAU + flip;
  if (move.from.pile === "foundation") return POINTS.FOUNDATION_TO_TABLEAU + flip;
  return flip;
}

/** What turning the waste back into the stock costs. */
export const recyclePoints = (mode) => POINTS.RECYCLE[mode];
