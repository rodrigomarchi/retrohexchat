/**
 * What a key means, as an action for the match to play — a key pressed on
 * the keyboard, or by the pad under the game on a phone. The moves (left,
 * right, down) are held: pressed when the key goes down, released when it
 * comes up; the game repeats them itself, so the keyboard's own repeat is
 * ignored. A turn, the drop and holding a piece act once, on the press.
 *
 * @module games/hex_blocks/gestures
 */

/** What each key does on a press, by the move it makes. */
const MOVES = Object.freeze({
  left: { type: "press", input: "left" },
  right: { type: "press", input: "right" },
  down: { type: "press", input: "down" },
  drop: { type: "drop" },
  turn_cw: { type: "turn", dir: 1 },
  turn_ccw: { type: "turn", dir: -1 },
  hold: { type: "hold" },
});

/** The keys, and the move each makes. */
const KEY_ACTIONS = Object.freeze({
  ArrowLeft: MOVES.left,
  ArrowRight: MOVES.right,
  ArrowDown: MOVES.down,
  ArrowUp: MOVES.turn_cw,
  x: MOVES.turn_cw,
  z: MOVES.turn_ccw,
  " ": MOVES.drop,
  c: MOVES.hold,
  Shift: MOVES.hold,
});

/** The keys the game takes from the page while it has the keyboard. */
export const KEYS = Object.freeze([
  ...Object.keys(KEY_ACTIONS),
  ...["x", "z", "c"].map((k) => k.toUpperCase()),
]);

const actionOfKey = (key) => KEY_ACTIONS[key] ?? KEY_ACTIONS[key.toLowerCase()] ?? null;

/** The action a key going down makes, or null; the keyboard's own repeat makes none. */
export const keyDown = (event) => (event.repeat ? null : actionOfKey(event.key));

/** The action a key coming up makes: a held move released, or null. */
export function keyUp(event) {
  const action = actionOfKey(event.key);
  return action?.type === "press" ? { type: "release", input: action.input } : null;
}
