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
 *     move it there;
 *   - `painting` — a floor material is armed (`none` erases); pressing on the
 *     floor anchors a corner, and releasing paints the rectangle between the
 *     two.
 *
 * Every input returns `{command}` — the edit to send, or null — and the machine
 * keeps the rest. It never applies an edit itself: the room changes when the
 * server's layout arrives, for the builder exactly as for everyone else.
 * @module space/construct/build_mode
 */

const DIRS = ["down", "right"];

export class BuildMode {
  /**
   * @param {{dirsOf?: (kind: string) => string[]|undefined}} [opts] - the
   *   facings a kind turns through (a corner has four); two by default
   */
  constructor({ dirsOf } = {}) {
    this._state = { mode: "idle" };
    this._hover = null;
    this._dirsOf = (kind) => {
      const dirs = dirsOf?.(kind);
      return Array.isArray(dirs) && dirs.length > 0 ? dirs : DIRS;
    };
  }

  /** @returns {object} the current state (read-only by convention). */
  state() {
    return this._state;
  }

  /** @returns {{x:number,y:number}|null} the tile under the pointer. */
  hover() {
    return this._hover;
  }

  /**
   * Where the dragged piece's corner would land now, keeping the offset it was
   * grabbed at; else the tile under the pointer.
   * @returns {{x:number,y:number}|null}
   */
  landing() {
    const s = this._state;
    if (!this._hover) return null;
    return s.mode === "dragging" ? this._corner(this._hover, s.grab) : this._hover;
  }

  _corner(tile, grab) {
    return grab ? { x: tile.x - grab.dx, y: tile.y - grab.dy } : tile;
  }

  /** Arm a kind from the palette; pressing the armed kind again disarms it. */
  choose(kind) {
    const s = this._state;
    this._state =
      s.mode === "placing" && s.kind === kind
        ? { mode: "idle" }
        : { mode: "placing", kind, dir: this._dirsOf(kind)[0] };
    return none();
  }

  /** Arm a floor material from the palette; pressing it again disarms it. */
  choosePaint(material) {
    const s = this._state;
    this._state =
      s.mode === "painting" && s.material === material
        ? { mode: "idle" }
        : { mode: "painting", material, anchor: null };
    return none();
  }

  /**
   * The tiles a paint stroke covers now: from its anchor to the pointer, or
   * the one tile under the pointer before the press.
   * @returns {{x0:number,y0:number,x1:number,y1:number}|null}
   */
  paintArea() {
    const s = this._state;
    if (s.mode !== "painting" || !this._hover) return null;
    const from = s.anchor ?? this._hover;
    return {
      x0: Math.min(from.x, this._hover.x),
      y0: Math.min(from.y, this._hover.y),
      x1: Math.max(from.x, this._hover.x),
      y1: Math.max(from.y, this._hover.y),
    };
  }

  /**
   * @param {{tile:{x:number,y:number}, item:object|null, button:number}} input
   */
  pointerDown({ tile, item, button }) {
    const s = this._state;
    this._hover = tile;

    if (s.mode === "painting") {
      if (button === 2) return this._reset();
      if (button === 0) this._state = { ...s, anchor: tile };
      return none();
    }

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
      // A long piece is held where it was grabbed: its corner keeps the same
      // offset from the pointer all the way to where it is let go.
      const grab = { dx: tile.x - item.x, dy: tile.y - item.y };
      this._state = { mode: "dragging", itemId: item.id, from: { x: item.x, y: item.y }, grab };
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
    if (s.mode === "painting") {
      if (!s.anchor || !tile) return none();
      this._hover = tile;
      const area = this.paintArea();
      this._state = { ...s, anchor: null };
      return { command: { op: "paint", ...area, material: s.material } };
    }
    if (s.mode !== "dragging") return none();
    this._state = { mode: "selected", itemId: s.itemId };
    const to = tile && this._corner(tile, s.grab);
    if (!to || (to.x === s.from.x && to.y === s.from.y)) return none();
    return { command: { op: "move", item_id: s.itemId, x: to.x, y: to.y } };
  }

  /** The pointer left the canvas: no tile is hovered, and a drag lets go. */
  pointerLeave() {
    this._hover = null;
    if (this._state.mode === "painting") this._state = { ...this._state, anchor: null };
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
      const dirs = this._dirsOf(s.kind);
      this._state = { ...s, dir: dirs[(dirs.indexOf(s.dir) + 1) % dirs.length] };
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
