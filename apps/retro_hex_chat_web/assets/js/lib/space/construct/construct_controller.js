/**
 * Building in a Construct: the canvas pointer and keys, the palette and the
 * build mode, wired to the engine and to the space's channel.
 *
 * The pointer picks a tile and a piece (`picking.js`), the build mode turns it
 * into an edit (`build_mode.js`), and the edit goes to the server through the
 * injected `send` port. Nothing is drawn as placed until the server's layout
 * comes back through `applyLayout`, the same broadcast every other builder in
 * the room receives; in between, the engine only draws a ghost.
 *
 * A right-click over a person is theirs: it opens the nick menu, and a piece
 * standing behind them is left alone.
 * @module space/construct/construct_controller
 */

import { canvasPointFromEvent } from "../canvas_point.js";
import { normalizeLayout } from "../protocol.js";
import { BuildMode } from "./build_mode.js";
import {
  canPlaceAt,
  footPointOf,
  footprintOf,
  itemAtCanvasPoint,
  tileAtCanvasPoint,
} from "./picking.js";
import { createBuildPalette } from "./palette.js";
import { renderPanel } from "./panels.js";

export class ConstructController {
  /**
   * @param {object} opts
   * @param {HTMLCanvasElement} opts.canvas
   * @param {HTMLElement} opts.palette - the `[data-construct-palette]` root
   * @param {() => object|null} opts.engine - the running engine, once started
   * @param {object} opts.atlas
   * @param {(payload: object, handlers: {ok: Function, error: (reason: string) => void}) => void} opts.send
   * @param {HTMLElement} [opts.root] - the space shell, holding the panel template
   * @param {() => void} [opts.closeModal] - close the panel a piece opened
   * @param {EventTarget} [opts.keyTarget]
   */
  constructor({ canvas, palette, engine, atlas, send, root, closeModal, keyTarget }) {
    this._canvas = canvas;
    this._root = root ?? palette;
    this._closeModal = closeModal ?? (() => {});
    this._engine = engine;
    this._atlas = atlas;
    this._send = send;
    this._keyTarget = keyTarget ?? window;
    this._mode = new BuildMode({ dirsOf: (kind) => this._map()?.catalog?.[kind]?.dirs });
    this._palette = createBuildPalette(palette, {
      onChoose: (kind) => this._apply(this._mode.choose(kind)),
      onPaint: (material) => this._apply(this._mode.choosePaint(material)),
      onRotate: () => this._apply(this._mode.rotate()),
      onRemove: () => this._apply(this._mode.remove()),
    });
    this._onPointerDown = this._onPointerDown.bind(this);
    this._onPointerMove = this._onPointerMove.bind(this);
    this._onPointerUp = this._onPointerUp.bind(this);
    this._onPointerLeave = () => this._apply(this._mode.pointerLeave());
    this._onContextMenu = this._onContextMenu.bind(this);
    this._onKeyDown = this._onKeyDown.bind(this);
  }

  attach() {
    this._palette.attach();
    this._canvas.addEventListener("pointerdown", this._onPointerDown);
    this._canvas.addEventListener("pointermove", this._onPointerMove);
    this._canvas.addEventListener("pointerup", this._onPointerUp);
    this._canvas.addEventListener("pointerleave", this._onPointerLeave);
    this._canvas.addEventListener("contextmenu", this._onContextMenu);
    this._keyTarget.addEventListener("keydown", this._onKeyDown);
    this._palette.render(this._mode.state());
  }

  detach() {
    this._palette.detach();
    this._canvas.removeEventListener("pointerdown", this._onPointerDown);
    this._canvas.removeEventListener("pointermove", this._onPointerMove);
    this._canvas.removeEventListener("pointerup", this._onPointerUp);
    this._canvas.removeEventListener("pointerleave", this._onPointerLeave);
    this._canvas.removeEventListener("contextmenu", this._onContextMenu);
    this._keyTarget.removeEventListener("keydown", this._onKeyDown);
  }

  /** The room's art is loaded: draw each kind into its palette key. */
  ready() {
    const map = this._map();
    if (!map) return;
    this._palette.drawThumbnails((kind) => this._atlas?.tile?.(map.kindTile(kind, "down")));
    this._palette.drawMaterials((tile) => this._atlas?.tile?.(tile));
  }

  /**
   * Draw the panel a piece opened (a sign, a board, a screen, an arcade
   * cabinet) into the modal host.
   * @returns {boolean} whether the modal was such a panel
   */
  renderPanel(host, modal) {
    return renderPanel(this._root, host, modal, {
      save: (text, done) => this._send({ op: "label", item_id: modal.item_id, text }, done),
      close: () => this._closeModal(),
      refusal: (reason) => this._palette.sentence(reason),
    });
  }

  /** A `construct_layout` broadcast: redraw the room, and drop a vanished pick. */
  applyLayout(raw) {
    const engine = this._engine();
    if (!engine?.applyConstructLayout?.(normalizeLayout(raw))) return;
    this._mode.forget((id) => this._map()?.item(id) !== null);
    this._refresh();
  }

  _map() {
    const map = this._engine()?.map;
    return map?.buildable?.() ? map : null;
  }

  _point(event) {
    return canvasPointFromEvent(
      event,
      this._canvas.getBoundingClientRect(),
      this._canvas.width,
      this._canvas.height,
    );
  }

  // Tile and piece under a pointer event, or null when the room is not up yet.
  _target(event) {
    const engine = this._engine();
    const map = this._map();
    const point = map && engine?.camera ? this._point(event) : null;
    if (!point) return null;
    return {
      point,
      tile: tileAtCanvasPoint(engine.camera, point.x, point.y),
      item: itemAtCanvasPoint(map, engine.camera, this._atlas, point.x, point.y),
    };
  }

  _personAt(point) {
    return this._engine()?.participantAtCanvasPoint?.(point.x, point.y) ?? null;
  }

  _onPointerDown(event) {
    const target = this._target(event);
    if (!target) return;
    if (event.button === 2 && this._personAt(target.point)) return;
    this._canvas.focus?.({ preventScroll: true });
    this._apply(this._mode.pointerDown({ ...target, button: event.button }));
    if (this._mode.state().mode === "dragging") {
      this._canvas.setPointerCapture?.(event.pointerId);
    }
  }

  _onPointerMove(event) {
    const target = this._target(event);
    if (target) this._apply(this._mode.pointerMove(target));
  }

  _onPointerUp(event) {
    const target = this._target(event);
    this._apply(this._mode.pointerUp({ tile: target?.tile ?? null }));
  }

  // The browser's own menu never opens over the floor of a Construct; over a
  // person, the nick menu is the canvas hook's to open.
  _onContextMenu(event) {
    const target = this._target(event);
    if (target && !this._personAt(target.point)) event.preventDefault();
  }

  _onKeyDown(event) {
    if (typingInField() || !this._map()) return;
    const result = this._mode.key(event.key);
    if (result.handled) event.preventDefault();
    this._apply(result);
  }

  _apply({ command }) {
    if (command) {
      this._send(command, {
        ok: () => this._palette.clear(),
        error: (reason) => this._palette.refuse(reason),
      });
    }
    this._refresh();
  }

  // What the engine draws for the build mode: a ghost where a piece would go
  // (green where this client thinks it fits, red where it does not), and a
  // marker under the picked piece.
  _refresh() {
    const state = this._mode.state();
    this._palette.render(state);
    const engine = this._engine();
    const map = this._map();
    if (!engine || !map) return;

    const hover = this._mode.hover();
    const people = [...(engine.participants?.values?.() ?? [])];
    const picked = state.itemId ? map.item(state.itemId) : null;
    let ghost = null;

    const area = this._mode.paintArea();
    if (area) {
      const tiles = [];
      for (let y = area.y0; y <= area.y1; y += 1) {
        for (let x = area.x0; x <= area.x1; x += 1) tiles.push({ x, y });
      }
      ghost = { x: hover.x, y: hover.y, tile: null, tiles, valid: true };
    } else if (state.mode === "placing" && hover) {
      ghost = this._ghost(
        map,
        state.kind,
        state.dir,
        hover,
        canPlaceAt(map, people, hover, null, state.kind, state.dir),
      );
    } else if (state.mode === "dragging" && picked && hover) {
      const to = this._mode.landing();
      const moved = to.x !== picked.x || to.y !== picked.y;
      ghost = moved
        ? this._ghost(
            map,
            picked.kind,
            picked.dir,
            to,
            canPlaceAt(map, people, to, picked.id, picked.kind, picked.dir),
          )
        : null;
    }

    engine.setConstructOverlay?.({
      ghost,
      selected: picked ? { x: picked.x, y: picked.y } : null,
    });
  }

  // A piece about to land: its art on its foot point, a diamond on every tile
  // of its footprint.
  _ghost(map, kind, dir, at, valid) {
    const foot = footPointOf(map, kind, at.x, at.y, dir);
    return {
      x: foot.x,
      y: foot.y,
      tile: map.kindTile(kind, dir),
      tiles: footprintOf(map, kind, at.x, at.y, dir),
      valid,
    };
  }
}

function typingInField() {
  const el = document.activeElement;
  if (!el) return false;
  const tag = el.tagName;
  return tag === "INPUT" || tag === "TEXTAREA" || el.isContentEditable === true;
}
