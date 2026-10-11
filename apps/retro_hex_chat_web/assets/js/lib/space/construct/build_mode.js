/**
 * The Construct's build mode, as a pure state machine: what a click, a drag, a
 * key or a palette press means, and which edit it asks the server for.
 *
 * States:
 *   - `idle` — nothing armed, nothing picked;
 *   - `placing` — a kind is armed (and a facing); every click on the floor asks
 *     to place one, and the kind stays armed so a row of chairs is a row of
 *     clicks;
 *   - `selected` — a placed piece is picked; Delete removes it, R turns it;
 *   - `dragging` — a picked piece is held down; releasing it elsewhere asks to
 *     move it there.
 *
 * Every input returns `{command}` — the edit to send, or null — and the machine
 * keeps the rest. It never applies an edit itself: the room changes when the
 * server's layout arrives, for the builder exactly as for everyone else.
 * @module space/construct/build_mode
 */

const DIRS = ["down", "right"];

export class BuildMode {
  constructor() {
    this._state = { mode: "idle" };
    this._hover = null;
  }

  /** @returns {object} the current state (read-only by convention). */
  state() {
    return this._state;
  }

  /** @returns {{x:number,y:number}|null} the tile under the pointer. */
  hover() {
    return this._hover;
  }

  /** Arm a kind from the palette; pressing the armed kind again disarms it. */
  choose(kind) {
    const s = this._state;
    this._state =
      s.mode === "placing" && s.kind === kind
        ? { mode: "idle" }
        : { mode: "placing", kind, dir: "down" };
    return none();
  }

  /**
   * @param {{tile:{x:number,y:number}, item:object|null, button:number}} input
   */
  pointerDown({ tile, item, button }) {
    const s = this._state;
    this._hover = tile;

    if (button === 2) {
      if (s.mode === "placing") return this._reset();
      if (item) {
        this._state = { mode: "idle" };
        return { command: { op: "remove", item_id: item.id } };
      }
      return none();
    }

    if (button !== 0) return none();
    if (s.mode === "placing") {
      return { command: { op: "place", kind: s.kind, x: tile.x, y: tile.y, dir: s.dir } };
    }
    if (item) {
      this._state = { mode: "dragging", itemId: item.id, from: { x: item.x, y: item.y } };
      return none();
    }
    return this._reset();
  }

  pointerMove({ tile }) {
    this._hover = tile;
    return none();
  }

  pointerUp({ tile }) {
    const s = this._state;
    if (s.mode !== "dragging") return none();
    this._state = { mode: "selected", itemId: s.itemId };
    if (!tile || (tile.x === s.from.x && tile.y === s.from.y)) return none();
    return { command: { op: "move", item_id: s.itemId, x: tile.x, y: tile.y } };
  }

  /** The pointer left the canvas: no tile is hovered, and a drag lets go. */
  pointerLeave() {
    this._hover = null;
    if (this._state.mode === "dragging") {
      this._state = { mode: "selected", itemId: this._state.itemId };
    }
    return none();
  }

  /**
   * A key while the map has the keyboard.
   * @returns {{command: object|null, handled: boolean}}
   */
  key(key) {
    const s = this._state;
    if (key === "Escape" && s.mode !== "idle") return { ...this._reset(), handled: true };
    if ((key === "Delete" || key === "Backspace") && s.mode === "selected") {
      return { ...this.remove(), handled: true };
    }
    if (key === "r" || key === "R") {
      const result = this.rotate();
      return { ...result, handled: s.mode === "placing" || s.mode === "selected" };
    }
    return { command: null, handled: false };
  }

  /** The palette's remove: the picked piece goes. */
  remove() {
    const s = this._state;
    if (s.mode !== "selected") return none();
    this._state = { mode: "idle" };
    return { command: { op: "remove", item_id: s.itemId } };
  }

  /** The palette's turn: the armed kind's facing, or the picked piece's. */
  rotate() {
    const s = this._state;
    if (s.mode === "placing") {
      this._state = { ...s, dir: DIRS[(DIRS.indexOf(s.dir) + 1) % DIRS.length] };
      return none();
    }
    if (s.mode === "selected") return { command: { op: "rotate", item_id: s.itemId } };
    return none();
  }

  /** A picked piece that is gone from the room is no longer picked. */
  forget(itemExists) {
    const s = this._state;
    if ((s.mode === "selected" || s.mode === "dragging") && !itemExists(s.itemId)) {
      this._state = { mode: "idle" };
    }
  }

  _reset() {
    this._state = { mode: "idle" };
    return none();
  }
}

function none() {
  return { command: null };
}
