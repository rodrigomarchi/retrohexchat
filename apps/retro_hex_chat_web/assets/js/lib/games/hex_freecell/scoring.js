/**
 * Hex FreeCell's points: what a move earns or costs. The clock, what time
 * costs and the bonus of a win are every card table's (`core/card_table/clock.js`).
 *
 * @module games/hex_freecell/scoring
 */

import { POINTS } from "./protocol.js";

/**
 * The points of a move (`rules.js`).
 * @param {{ from: { pile: string }, to: { pile: string } }} move
 * @returns {number}
 */
export function scoreMove({ from, to }) {
  if (to.pile === "foundation") return POINTS.TO_FOUNDATION;
  if (from.pile === "foundation") return POINTS.FOUNDATION_BACK;
  return 0;
}
