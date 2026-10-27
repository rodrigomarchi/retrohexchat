/**
 * What a press on the board means, as an action for the match to play: a tap
 * opens a square (or flags it, on a phone switched to flags), a right click
 * or a long press flags it, a tap on an open number chords, and a tap on the
 * switch changes what a tap does. Pure functions of the board, the layout and
 * the gesture (`core/pointer.js`).
 *
 * @module games/hex_mines/gestures
 */

import { cellAt, on } from "./layout.js";
import { CELL } from "./rules.js";

/**
 * The action a gesture makes, or null.
 * @param {object} state - the match
 * @param {object} laid - `layout.js`'s
 * @param {{ type: string, x?: number, y?: number, button?: string }} gesture
 * @returns {object | null}
 */
export function interpret(state, laid, gesture) {
  if (gesture.type !== "tap" && gesture.type !== "hold") return null;
  if (gesture.type === "tap" && on(laid.mode, gesture.x, gesture.y)) return { type: "mode" };
  const i = cellAt(laid, gesture.x, gesture.y);
  if (i === null) return null;
  const flagging = gesture.type === "hold" || gesture.button === "secondary";
  if (state.board.cell[i] === CELL.OPEN) return flagging ? null : { type: "chord", i };
  if (flagging || state.mode === "flag") return { type: "flag", i };
  return { type: "open", i };
}
