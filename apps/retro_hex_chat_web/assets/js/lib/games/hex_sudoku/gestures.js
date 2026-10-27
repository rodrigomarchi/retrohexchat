/**
 * What a tap or a key means, as an action for the match to play: a tap on a
 * square chooses it, on a key puts its digit, on a tool uses it; on a
 * keyboard, the digits put theirs, the arrows move the choice, Delete or
 * Backspace erases, and N, H and Z are the pencil, the hint and undo. Pure
 * functions of the layout and the gesture (`core/pointer.js`) or the key.
 *
 * @module games/hex_sudoku/gestures
 */

import { hitAt } from "./layout.js";

/**
 * The action a gesture makes, or null.
 * @param {object} laid - `layout.js`'s
 * @param {{ type: string, x?: number, y?: number }} gesture
 * @returns {object | null}
 */
export function interpret(laid, gesture) {
  if (gesture.type !== "tap") return null;
  const hit = hitAt(laid, gesture.x, gesture.y);
  if (!hit) return null;
  if (hit.type === "square") return { type: "select", i: hit.i };
  if (hit.type === "key") return { type: "digit", d: hit.d };
  return { type: hit.name };
}

const ARROWS = Object.freeze({
  ArrowLeft: [-1, 0],
  ArrowRight: [1, 0],
  ArrowUp: [0, -1],
  ArrowDown: [0, 1],
});

const LETTERS = Object.freeze({ n: "pencil", h: "hint", z: "undo" });

/** The keys the game takes from the page while it has the keyboard. */
export const KEYS = Object.freeze([
  ..."123456789",
  ...Object.keys(ARROWS),
  "Backspace",
  "Delete",
  ...Object.keys(LETTERS).flatMap((k) => [k, k.toUpperCase()]),
]);

/** The action a key makes, or null. */
export function keyAction(key) {
  if (/^[1-9]$/.test(key)) return { type: "digit", d: Number(key) };
  if (ARROWS[key]) return { type: "move", dx: ARROWS[key][0], dy: ARROWS[key][1] };
  if (key === "Backspace" || key === "Delete") return { type: "erase" };
  const tool = LETTERS[key.toLowerCase()];
  return tool ? { type: tool } : null;
}
