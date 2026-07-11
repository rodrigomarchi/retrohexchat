/**
 * Virtual-space client engine: owns local world state (participants, self,
 * camera), applies authoritative snapshots/deltas from the server, and drives
 * the render loop.
 *
 * The server is authoritative. The local avatar is *predicted* — a step moves
 * it immediately and is queued as pending until the server acks the seq; on ack
 * the confirmed prediction is dropped and any still-pending steps are re-applied
 * over the authoritative base, rolling back cleanly when the server rejects a
 * move. Remote avatars are interpolated between tiles so their movement glides.
 * @module space/engine
 */

import {
  normalizeParticipant,
  normalizeSnapshot,
  normalizeDelta,
  normalizeAction,
} from "./protocol.js";
import { SpaceMap } from "./map.js";
import { Camera } from "./camera.js";
import { Renderer } from "./renderer.js";
import { Interpolator } from "./interpolation.js";
import { ChatState } from "./chat.js";

const ACTION_DURATION_MS = 420;

export class SpaceEngine {
  /**
   * @param {object} opts
   * @param {HTMLCanvasElement} opts.canvas
   * @param {object} [opts.atlas] sprite atlas (required for the default renderer)
   * @param {object} [opts.renderer] injected renderer (tests)
   * @param {Function} [opts.requestFrame] frame scheduler
   * @param {Function} [opts.cancelFrame]
   * @param {Function} [opts.onFrameRendered] called after each draw completes
   */
  constructor({ canvas, atlas, renderer, requestFrame, cancelFrame, onFrameRendered } = {}) {
    this.canvas = canvas;
    this.atlas = atlas;
    this._injectedRenderer = renderer ?? null;
    this._requestFrame = requestFrame ?? ((cb) => window.requestAnimationFrame(cb));
    this._cancelFrame = cancelFrame ?? ((id) => window.cancelAnimationFrame(id));
    this._onFrameRendered = typeof onFrameRendered === "function" ? onFrameRendered : null;

    this.selfKey = null;
    this.map = null;
    this.camera = null;
    this.renderer = null;
    this.participants = new Map();

    // Local prediction state for the self avatar.
    this._selfSeq = 0;
    this._pending = [];
    // Authoritative base position of the self avatar (server truth).
    this._selfBase = null;
    // Remote interpolation.
    this._interp = new Interpolator();
    // Ephemeral speech bubbles derived from public channel messages.
    this._chat = new ChatState();
    // Ephemeral visual-only actions such as sword swings.
    this._actions = new Map();
    this._clock = () => (typeof performance !== "undefined" ? performance.now() : Date.now());

    this.running = false;
    this._rafId = null;
    this._frame = this._frame.bind(this);
    this._onResize = this._onResize.bind(this);
  }

  /** Override the monotonic clock (tests). */
  setClock(fn) {
    this._clock = fn;
  }

  /**
   * Boot the world from a normalized `space_init`.
   * @param {object} init
   */
  start(init) {
    this.selfKey = init.selfKey ?? null;
    this.map = SpaceMap.from(init.map);
    this.atlas?.loadTilesets?.(init.map?.tilesets);
    this.atlas?.registerTiles?.(init.map?.tiles);
    const scale = init.config?.scale ?? 2;
    // Avatars keep a constant on-screen size across maps of different tile
    // resolutions; the world scale varies with tile size, so avatars carry their
    // own scale (defaults to the world scale when the server omits it).
    this._avatarScale = init.config?.avatar_scale ?? scale;
    this.camera = new Camera({
      tileSize: this.map.tileSize,
      scale,
      mapWidth: this.map.width,
      mapHeight: this.map.height,
      // The map picks the projection (square vs isometric); top-down maps get
      // the historical square projection with identical numbers.
      map: init.map,
    });
    this.camera.setViewport(this.canvas?.width ?? 0, this.canvas?.height ?? 0);

    this.renderer =
      this._injectedRenderer ??
      new Renderer({
        canvas: this.canvas,
        atlas: this.atlas,
        map: this.map,
        camera: this.camera,
        avatarScale: this._avatarScale,
      });

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
    this._pending = [];
    this._interp = new Interpolator();
    this._actions.clear();

    for (const [key, participant] of Object.entries(normalized.participants)) {
      this.participants.set(key, participant);
      if (key === this.selfKey) {
        this._selfBase = { x: participant.x, y: participant.y };
      } else {
        this._interp.reset(key, participant.x, participant.y);
      }
    }
    this._recenter();
  }

  /**
   * Apply an incremental delta (moves, joins, leaves). The self entry is
   * reconciled against pending predictions; remotes feed the interpolator.
   * @param {object} delta
   */
  applyDelta(delta) {
    const normalized = normalizeDelta(delta);
    const now = this._clock();

    for (const key of normalized.left) {
      this.participants.delete(key);
      this._interp.remove(key);
      this._actions.delete(key);
    }

    for (const [key, participant] of Object.entries(normalized.joined)) {
      this.participants.set(key, participant);
      if (key !== this.selfKey) this._interp.reset(key, participant.x, participant.y);
    }

    for (const [key, update] of Object.entries(normalized.updates)) {
      if (key === this.selfKey) {
        this._reconcileSelf(normalized.seqAck[key], update);
      } else {
        this._applyRemoteUpdate(key, update, now);
      }
    }

    this._recenter();
  }

  /**
   * Predict a local step: move the self avatar immediately if the target tile
   * is free locally (same map as the server), queue it as pending, and return
   * the wire payload for the caller to push. A locally-blocked step is dropped.
   * @param {{dx:number,dy:number,dir:string}} intent
   * @returns {{moved:boolean, seq?:number, dx?:number, dy?:number, dir?:string}}
   */
  predict(intent) {
    const self = this.selfKey ? this.participants.get(this.selfKey) : null;
    if (!self) return { moved: false };

    // The projection may remap which key drives which grid axis (iso rotates the
    // D-pad); prediction/reconciliation stay grid-blind after this.
    intent = this.camera?.projection?.remapIntent?.(intent) ?? intent;
    const nx = self.x + intent.dx;
    const ny = self.y + intent.dy;
    if (this.map?.isBlocked(nx, ny)) return { moved: false };

    const seq = (this._selfSeq += 1);
    this._pending.push({ seq, dx: intent.dx, dy: intent.dy });
    this.participants.set(this.selfKey, { ...self, x: nx, y: ny, dir: intent.dir, moving: true });
    this._recenter();

    return { moved: true, seq, dx: intent.dx, dy: intent.dy, dir: intent.dir };
  }

  /** @returns {number} unacknowledged local predictions still in flight. */
  pendingCount() {
    return this._pending.length;
  }

  /** Record an incoming `space_message` as a speech bubble. */
  receiveMessage(message) {
    this._chat.receive(message, this._clock());
  }

  /**
   * Trigger a local visual action for the current participant.
   * @param {string} kind
   * @returns {{acted:boolean, kind?:string, dir?:string}}
   */
  performAction(kind) {
    const self = this.self();
    if (!self || self.pose !== "standing") return { acted: false };
    if (kind !== "sword") return { acted: false };
    if (this._activeAction(self.key, this._clock())) return { acted: false };

    this.triggerAction({ key: self.key, kind, dir: self.dir });
    return { acted: true, kind, dir: self.dir };
  }

  /** Record an incoming `space_action` as a visual animation. */
  receiveAction(action) {
    const normalized = normalizeAction(action);
    if (normalized.key === this.selfKey && this._activeAction(normalized.key, this._clock())) {
      return false;
    }
    return this.triggerAction(normalized);
  }

  /**
   * Start an ephemeral action animation for any known participant.
   * @param {{key:string,kind:string,dir:string}} action
   * @returns {boolean}
   */
  triggerAction(action) {
    const normalized = normalizeAction(action);
    const participant = normalized.key ? this.participants.get(normalized.key) : null;
    if (!participant || participant.pose !== "standing") return false;
    if (this._activeAction(normalized.key, this._clock())) return false;

    this._actions.set(normalized.key, {
      kind: normalized.kind,
      dir: normalized.dir,
      startedAt: this._clock(),
      duration: ACTION_DURATION_MS,
    });
    return true;
  }

  /** @returns {Array} recent bubble events for diagnostics/tests. */
  chatLog() {
    return this._chat.log();
  }

  /**
   * Render-space tile position at `now`: predicted for self, interpolated for
   * remotes, falling back to the last known tile.
   * @returns {{x:number,y:number}|null}
   */
  renderPosition(key, now) {
    const participant = this.participants.get(key);
    if (!participant) return null;
    if (key === this.selfKey) return { x: participant.x, y: participant.y };
    return this._interp.position(key, now) ?? { x: participant.x, y: participant.y };
  }

  /** @returns {object|null} participant by key. */
  participant(key) {
    return this.participants.get(key) ?? null;
  }

  /** @returns {object|null} the local participant. */
  self() {
    return this.selfKey ? (this.participants.get(this.selfKey) ?? null) : null;
  }

  /**
   * Find the topmost rendered participant under a canvas point.
   * @param {number} canvasX
   * @param {number} canvasY
   * @returns {object|null}
   */
  participantAtCanvasPoint(canvasX, canvasY) {
    if (!this.camera || !this.map) return null;

    const now = this._clock();
    const rendered = [];

    for (const [key, participant] of this.participants) {
      const pos = this.renderPosition(key, now);
      if (!pos) continue;

      rendered.push({
        ...participant,
        key,
        x: pos.x,
        y: pos.y,
        action: this._activeAction(key, now),
      });
    }

    rendered.sort((a, b) => b.y - a.y);

    for (const participant of rendered) {
      if (this._participantHitBox(participant).contains(canvasX, canvasY)) {
        return participant;
      }
    }

    return null;
  }

  /** @returns {number} live participant count. */
  participantCount() {
    return this.participants.size;
  }

  /**
   * Re-read the canvas backing-store size into the camera viewport and recenter.
   * Call after the canvas element is resized (e.g. a window maximize) so a
   * bigger canvas reveals more map instead of upscaling the same view.
   */
  resize() {
    this._onResize();
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
    this._actions.clear();
  }

  // ── Internals ────────────────────────────────────────────────────

  // Drop predictions the server has acknowledged, then rebase the self avatar
  // on the authoritative position and re-apply any still-pending steps. This
  // rolls back cleanly when the server rejected a move (it acks the seq but
  // reports the old tile).
  _reconcileSelf(ackSeq, serverPos) {
    if (ackSeq !== null && ackSeq !== undefined) {
      this._pending = this._pending.filter((p) => p.seq > ackSeq);
    }

    let x = serverPos.x ?? this._selfBase?.x ?? 0;
    let y = serverPos.y ?? this._selfBase?.y ?? 0;
    this._selfBase = { x, y };

    for (const step of this._pending) {
      const nx = x + step.dx;
      const ny = y + step.dy;
      if (!this.map?.isBlocked(nx, ny)) {
        x = nx;
        y = ny;
      }
    }

    const self = this.participants.get(this.selfKey) ?? {};
    this.participants.set(this.selfKey, {
      ...self,
      x,
      y,
      dir: serverPos.dir ?? self.dir,
      // A self delta can also carry an avatar swap (the player picked a
      // character); keep it rather than dropping every non-position field.
      avatar: serverPos.avatar ?? self.avatar,
    });
  }

  _applyRemoteUpdate(key, update, now) {
    const current = this.participants.get(key);
    if (!current) return;
    const merged = { ...current, ...update };
    this.participants.set(key, merged);
    this._interp.moveTo(key, merged.x, merged.y, now);
  }

  _participantHitBox(participant) {
    const tilePx = this.map.tileSize * this.camera.scale;
    const avatarScale = this._avatarScale ?? this.camera.scale;
    const proj = this.camera.projection;
    const iso = proj.kind === "isometric";
    const anchor = iso
      ? proj.footAnchor(participant.x, participant.y)
      : proj.floorAnchor(participant.x, participant.y);
    const { x, y } = this.camera.worldToScreen(anchor.x, anchor.y);
    const action = participant.action?.kind ? participant.action : null;
    const sprite = this.atlas?.avatar?.(
      participant.avatar,
      action?.dir ?? participant.dir,
      0,
      action?.kind ?? "walk",
    );
    const width = (sprite?.sw ?? this.map.tileSize) * avatarScale;
    const height = (sprite?.sh ?? this.map.tileSize * 2) * avatarScale;
    // Iso avatars billboard bottom-centre on the foot; top-down centre on the tile.
    const left = iso ? x - width / 2 : x - (width - tilePx) / 2;
    const top = iso ? y - height : y - (height - tilePx);
    const right = left + width;
    const bottom = top + height;
    const labelWidth = Math.max(width, (participant.nickname?.length ?? 0) * 6 + 6);
    const labelLeft = x + tilePx / 2 - labelWidth / 2;
    const labelRight = labelLeft + labelWidth;
    const labelTop = y - tilePx - 12;
    const labelBottom = labelTop + 11;

    return {
      contains(px, py) {
        return (
          px >= Math.min(left, labelLeft) &&
          px <= Math.max(right, labelRight) &&
          py >= Math.min(top, labelTop) &&
          py <= Math.max(bottom, labelBottom)
        );
      },
    };
  }

  _frame() {
    if (!this.running) return;
    this._draw();
    this._rafId = this._requestFrame(this._frame);
  }

  _draw() {
    const now = this._clock();
    const rendered = new Map();
    const bubbles = new Map();
    for (const [key, participant] of this.participants) {
      const pos = this.renderPosition(key, now);
      rendered.set(key, {
        ...participant,
        x: pos.x,
        y: pos.y,
        action: this._activeAction(key, now),
      });
      const bubble = this._chat.bubble(key, now);
      if (bubble) bubbles.set(key, bubble.text);
    }
    this.renderer?.draw?.({ participants: rendered, selfKey: this.selfKey, bubbles, now });
    this._onFrameRendered?.();
  }

  _activeAction(key, now) {
    const action = this._actions.get(key);
    if (!action) return null;
    if (now - action.startedAt >= action.duration) {
      this._actions.delete(key);
      return null;
    }
    return action;
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
