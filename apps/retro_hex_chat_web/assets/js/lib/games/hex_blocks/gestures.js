/**
 * What a key or a finger on a button means, as an action for the match to
 * play. The moves (left, right, down) are held: pressed when the key goes
 * down or a finger lands on the button, released when it comes up or the
 * finger lifts or slides off; the game repeats them itself, so the
 * keyboard's own repeat is ignored. A turn, the drop and holding a piece act
 * once, on the press. Every finger is followed on its own, so a thumb can
 * hold left while the other turns. Pure functions of the layout and the
 * event.
 *
 * @module games/hex_blocks/gestures
 */

import { buttonAt } from "./layout.js";

const HELD = Object.freeze({ left: "left", right: "right", down: "down" });

/** What each button does on a press. */
const BUTTON_ACTIONS = Object.freeze({
  left: { type: "press", input: "left" },
  right: { type: "press", input: "right" },
  down: { type: "press", input: "down" },
  drop: { type: "drop" },
  turn_cw: { type: "turn", dir: 1 },
  turn_ccw: { type: "turn", dir: -1 },
  hold: { type: "hold" },
});

/** What each key does on a press. */
const KEY_ACTIONS = Object.freeze({
  ArrowLeft: BUTTON_ACTIONS.left,
  ArrowRight: BUTTON_ACTIONS.right,
  ArrowDown: BUTTON_ACTIONS.down,
  ArrowUp: BUTTON_ACTIONS.turn_cw,
  x: BUTTON_ACTIONS.turn_cw,
  z: BUTTON_ACTIONS.turn_ccw,
  " ": BUTTON_ACTIONS.drop,
  c: BUTTON_ACTIONS.hold,
  Shift: BUTTON_ACTIONS.hold,
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

/** The buttons each finger holds down: finger → button. */
export const createPad = () => new Map();

/** A held move let go, unless another finger is still on its button. */
const released = (pad, button) =>
  HELD[button] && ![...pad.values()].includes(button)
    ? [{ type: "release", input: HELD[button] }]
    : [];

/**
 * A pointer event (`{ type, finger, x, y }`, the core's) on the pad: the pad
 * it leaves, and the actions it makes.
 * @param {Map<number, string>} pad
 * @param {object} laid - `layout.js`'s
 * @param {{ type: string, finger: number, x?: number, y?: number }} event
 * @returns {{ pad: Map<number, string>, actions: object[] }}
 */
export function padEvent(pad, laid, event) {
  const held = pad.get(event.finger);
  const without = () => {
    const next = new Map(pad);
    next.delete(event.finger);
    return next;
  };
  if (event.type === "down") {
    const button = buttonAt(laid, event.x, event.y);
    if (!button) return { pad, actions: [] };
    return { pad: new Map(pad).set(event.finger, button), actions: [BUTTON_ACTIONS[button]] };
  }
  if (held === undefined) return { pad, actions: [] };
  if (event.type === "move") {
    if (buttonAt(laid, event.x, event.y) === held) return { pad, actions: [] };
    const rest = without();
    return { pad: rest, actions: released(rest, held) };
  }
  // Up or cancel: the finger is gone.
  const rest = without();
  return { pad: rest, actions: released(rest, held) };
}
