/**
 * Keyboard input for the virtual space. Maps arrow keys and WASD to cardinal
 * step intents: the first keydown emits immediately, OS auto-repeat is ignored
 * (its delay/rate are OS-dependent), and continuous held movement is driven by
 * the engine polling `currentIntent()` each frame instead. Stays out of the way
 * while a text field is focused so chat typing never moves the avatar.
 * @module space/input
 */

const KEY_MAP = {
  ArrowUp: { dx: 0, dy: -1, dir: "up" },
  ArrowDown: { dx: 0, dy: 1, dir: "down" },
  ArrowLeft: { dx: -1, dy: 0, dir: "left" },
  ArrowRight: { dx: 1, dy: 0, dir: "right" },
  w: { dx: 0, dy: -1, dir: "up" },
  s: { dx: 0, dy: 1, dir: "down" },
  a: { dx: -1, dy: 0, dir: "left" },
  d: { dx: 1, dy: 0, dir: "right" },
};

// Non-movement action keys: interact with a board / sit on a chair / swing.
const ACTION_MAP = {
  " ": "attack",
  Space: "attack",
  Spacebar: "attack",
  e: "interact",
  f: "sit",
};

export class InputController {
  /**
   * @param {{onIntent: (intent: {dx:number,dy:number,dir:string}) => void, target?: EventTarget}} opts
   */
  constructor({ onIntent, onAction, target } = {}) {
    this._onIntent = onIntent ?? (() => {});
    this._onAction = onAction ?? (() => {});
    this._target = target ?? window;
    this._pressed = new Set();
    this._onKeyDown = this._onKeyDown.bind(this);
    this._onKeyUp = this._onKeyUp.bind(this);
    this._onBlur = this._onBlur.bind(this);
  }

  attach() {
    this._target.addEventListener("keydown", this._onKeyDown);
    this._target.addEventListener("keyup", this._onKeyUp);
    // A keyup can be missed when the window loses focus (Alt-Tab), which would
    // otherwise leave a key stuck in `_pressed` and permanently coalesced away.
    window.addEventListener("blur", this._onBlur);
  }

  detach() {
    this._target.removeEventListener("keydown", this._onKeyDown);
    this._target.removeEventListener("keyup", this._onKeyUp);
    window.removeEventListener("blur", this._onBlur);
    this._pressed.clear();
  }

  /** @returns {{dx:number,dy:number,dir:string}|null} the most recent held direction. */
  currentIntent() {
    const keys = [...this._pressed];
    for (let i = keys.length - 1; i >= 0; i -= 1) {
      const intent = KEY_MAP[keys[i]];
      if (intent) return intent;
    }
    return null;
  }

  _onKeyDown(event) {
    if (typingInField()) return;
    const key = normalizeKey(event.key);

    const action = ACTION_MAP[key];
    if (action) {
      event.preventDefault();
      if (!this._pressed.has(key)) {
        this._pressed.add(key);
        this._onAction(action);
      }
      return;
    }

    const intent = KEY_MAP[key];
    if (!intent) return;

    // Coalesce OS auto-repeat: only the first keydown for a key emits.
    if (this._pressed.has(key)) {
      event.preventDefault();
      return;
    }

    this._pressed.add(key);
    event.preventDefault();
    this._onIntent(intent);
  }

  _onKeyUp(event) {
    this._pressed.delete(normalizeKey(event.key));
  }

  _onBlur() {
    this._pressed.clear();
  }
}

function normalizeKey(key) {
  return key.length === 1 ? key.toLowerCase() : key;
}

function typingInField() {
  const el = document.activeElement;
  if (!el) return false;
  const tag = el.tagName;
  return tag === "INPUT" || tag === "TEXTAREA" || el.isContentEditable === true;
}
