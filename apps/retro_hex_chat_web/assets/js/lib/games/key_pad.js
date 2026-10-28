/**
 * The Retro Games' on-screen pad, as keys: each button presses the key the
 * game already reads — an arrow for a direction, the action's own key (" ",
 * "Shift", "x"…) for an action — held down until the button comes up. The
 * events go where the game engine listens (the window), so no game knows
 * whether a key came from a keyboard or a thumb.
 *
 * @module games/key_pad
 */

const ARROWS = Object.freeze({
  up: "ArrowUp",
  down: "ArrowDown",
  left: "ArrowLeft",
  right: "ArrowRight",
});

/**
 * An input for `VirtualPadController` that types keys into `target`.
 * @param {EventTarget} [target] - where the game engine reads the keyboard
 */
export function keyPadInput(target = window) {
  const send = (type, key) =>
    target.dispatchEvent(new KeyboardEvent(type, { key, bubbles: true, cancelable: true }));
  return {
    pressDirection: (dir) => send("keydown", ARROWS[dir]),
    releaseDirection: (dir) => send("keyup", ARROWS[dir]),
    triggerAction: (key) => send("keydown", key),
    releaseAction: (key) => send("keyup", key),
  };
}
