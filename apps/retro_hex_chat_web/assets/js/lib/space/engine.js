/**
 * Virtual-space client engine: owns local world state (participants, self,
 * camera), applies authoritative snapshots/deltas from the server, and drives
 * the render loop. Server-authoritative — the engine never invents positions;
 * it only mirrors what the channel reports (local prediction arrives in a
 * later phase).
 * @module space/engine
 */

import { normalizeParticipant, normalizeSnapshot, normalizeDelta } from "./protocol.js";
import { SpaceMap } from "./map.js";
import { Camera } from "./camera.js";
import { Renderer } from "./renderer.js";

export class SpaceEngine {
  /**
   * @param {object} opts
   * @param {HTMLCanvasElement} opts.canvas
   * @param {object} [opts.atlas] sprite atlas (required for the default renderer)
   * @param {object} [opts.renderer] injected renderer (tests)
   * @param {Function} [opts.requestFrame] frame scheduler
   * @param {Function} [opts.cancelFrame]
   */
  constructor({ canvas, atlas, renderer, requestFrame, cancelFrame } = {}) {
    this.canvas = canvas;
    this.atlas = atlas;
    this._injectedRenderer = renderer ?? null;
    this._requestFrame = requestFrame ?? ((cb) => window.requestAnimationFrame(cb));
    this._cancelFrame = cancelFrame ?? ((id) => window.cancelAnimationFrame(id));

    this.selfKey = null;
    this.map = null;
    this.camera = null;
    this.renderer = null;
    this.participants = new Map();

    this.running = false;
    this._rafId = null;
    this._frame = this._frame.bind(this);
    this._onResize = this._onResize.bind(this);
  }

  /**
   * Boot the world from a normalized `space_init`.
   * @param {object} init
   */
  start(init) {
    this.selfKey = init.selfKey ?? null;
    this.map = SpaceMap.from(init.map);
    this.camera = new Camera({
      tileSize: this.map.tileSize,
      scale: init.config?.scale ?? 3,
      mapWidth: this.map.width,
      mapHeight: this.map.height,
    });
    this.camera.setViewport(this.canvas?.width ?? 0, this.canvas?.height ?? 0);

    this.renderer =
      this._injectedRenderer ??
      new Renderer({ canvas: this.canvas, atlas: this.atlas, map: this.map, camera: this.camera });

    this.applySnapshot(init.snapshot);

    window.addEventListener("resize", this._onResize);
    this.running = true;
    this._rafId = this._requestFrame(this._frame);
  }

  /**
   * Replace the whole participant set (init, reconnect, drift correction).
   * @param {object} snapshot
   */
  applySnapshot(snapshot) {
    const normalized = normalizeSnapshot(snapshot);
    this.participants = new Map();
    for (const [key, participant] of Object.entries(normalized.participants)) {
      this.participants.set(key, participant);
    }
    this._recenter();
  }

  /**
   * Apply an incremental delta (moves, joins, leaves).
   * @param {object} delta
   */
  applyDelta(delta) {
    const normalized = normalizeDelta(delta);

    for (const key of normalized.left) {
      this.participants.delete(key);
    }

    for (const [key, participant] of Object.entries(normalized.joined)) {
      this.participants.set(key, participant);
    }

    for (const [key, update] of Object.entries(normalized.updates)) {
      const current = this.participants.get(key);
      if (current) {
        this.participants.set(key, { ...current, ...update });
      }
    }

    this._recenter();
  }

  /** @returns {object|null} participant by key. */
  participant(key) {
    return this.participants.get(key) ?? null;
  }

  /** @returns {number} live participant count. */
  participantCount() {
    return this.participants.size;
  }

  /** Tear down: stop the loop, drop listeners, release the renderer. */
  destroy() {
    this.running = false;
    if (this._rafId !== null) {
      this._cancelFrame(this._rafId);
      this._rafId = null;
    }
    window.removeEventListener("resize", this._onResize);
    this.renderer?.destroy?.();
    this.participants.clear();
  }

  // ── Internals ────────────────────────────────────────────────────

  _frame() {
    if (!this.running) return;
    this._draw();
    this._rafId = this._requestFrame(this._frame);
  }

  _draw() {
    this.renderer?.draw?.({
      participants: this.participants,
      selfKey: this.selfKey,
    });
  }

  _recenter() {
    const self = this.selfKey ? this.participants.get(this.selfKey) : null;
    if (self && this.camera) {
      this.camera.follow(self.x, self.y);
    }
  }

  _onResize() {
    if (!this.canvas || !this.camera) return;
    this.camera.setViewport(this.canvas.width, this.canvas.height);
    this.renderer?.resize?.(this.canvas.width, this.canvas.height);
    this._recenter();
  }
}

// Re-exported so callers can seed participants without importing protocol.
export { normalizeParticipant };
