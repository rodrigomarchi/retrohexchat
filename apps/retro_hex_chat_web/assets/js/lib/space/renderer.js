/**
 * Canvas 2D renderer for the virtual space. Draws the floor, then avatars
 * ordered by Y (so lower avatars overlap higher ones), then nickname labels.
 * Integer scaling with `imageSmoothingEnabled = false` keeps the 8-bit look.
 * @module space/renderer
 */

const LABEL_FONT = "10px monospace";
const HASH = String.fromCharCode(35);
// Solid backdrop painted before the floor so any tile without a sprite (map
// edges / gaps) reads as a dark void instead of transparent canvas.
const VOID_BG = "14161c";
const LABEL_BG = "1b1d24";
const LABEL_FG = "e8dcc0";
const BUBBLE_BG = "e8dcc0";
const BUBBLE_FG = "20232b";
const SIGN_BG = "5a442e";
const SIGN_BORDER = "2f241a";
const SIGN_FG = "f7e6b6";
const SIGN_FONT = "12px monospace";
const TABLE_SIGN_BG = "6b4f2f";
const TABLE_SIGN_BORDER = "3a2919";
const TABLE_SIGN_FG = "f4e4b8";
const TABLE_SIGN_FONT = "10px monospace";

export class Renderer {
  /**
   * @param {object} opts
   * @param {HTMLCanvasElement} opts.canvas
   * @param {object} opts.atlas
   * @param {object} opts.map SpaceMap instance
   * @param {object} opts.camera Camera instance
   */
  constructor({ canvas, atlas, map, camera }) {
    this.canvas = canvas;
    this.atlas = atlas;
    this.map = map;
    this.camera = camera;
    this.ctx = canvas?.getContext?.("2d") ?? null;
    if (this.ctx) this.ctx.imageSmoothingEnabled = false;
    this.tilePx = map.tileSize * camera.scale;
    // Per-avatar last render position + time, to drive the walk animation.
    this._motion = new Map();
  }

  resize() {
    if (this.ctx) this.ctx.imageSmoothingEnabled = false;
  }

  /**
   * @param {{participants: Map<string, object>, selfKey: string|null, bubbles?: Map<string,string>}} state
   */
  draw(state) {
    const ctx = this.ctx;
    if (!ctx) return;

    const bubbles = state.bubbles ?? new Map();
    const now = state.now ?? (typeof performance !== "undefined" ? performance.now() : 0);

    ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
    ctx.fillStyle = HASH + VOID_BG;
    ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
    this._drawFloor(ctx);
    this._drawDecor(ctx);
    this._drawMapLabels(ctx);

    const ordered = [...state.participants.values()].sort((a, b) => a.y - b.y);
    for (const participant of ordered) {
      this._drawAvatar(ctx, participant, now);
    }
    for (const participant of ordered) {
      this._drawLabel(ctx, participant);
      const text = bubbles.get(participant.key);
      if (text) this._drawBubble(ctx, participant, text);
    }
  }

  destroy() {
    this.ctx = null;
  }

  // ── Layers ───────────────────────────────────────────────────────

  _drawFloor(ctx) {
    const startX = Math.floor(this.camera.x / this.tilePx);
    const startY = Math.floor(this.camera.y / this.tilePx);
    const cols = Math.ceil(this.canvas.width / this.tilePx) + 1;
    const rows = Math.ceil(this.canvas.height / this.tilePx) + 1;

    const ground = this.map.ground ? this.atlas?.tile(this.map.ground) : null;

    for (let ty = startY; ty < startY + rows; ty += 1) {
      for (let tx = startX; tx < startX + cols; tx += 1) {
        if (!this.map.inBounds(tx, ty)) continue;
        const { x, y } = this.camera.worldToScreen(tx * this.tilePx, ty * this.tilePx);
        const dx = Math.round(x);
        const dy = Math.round(y);
        const tileId = this.map.floorTile(tx, ty);
        // Lay the opaque ground first so transparent props read over it.
        if (ground && tileId !== this.map.ground) this._blit(ctx, ground, dx, dy);
        this._blit(ctx, this.atlas?.tile(tileId), dx, dy);
      }
    }
  }

  // Multi-tile props anchored at their top-left tile, drawn at their native
  // sprite size over the floor.
  _drawDecor(ctx) {
    for (const prop of this.map.decor ?? []) {
      const sprite = this.atlas?.tile(prop.tile);
      if (!sprite) continue;
      const { x, y } = this.camera.worldToScreen(prop.x * this.tilePx, prop.y * this.tilePx);
      this._blit(ctx, sprite, Math.round(x), Math.round(y));
    }
  }

  _drawMapLabels(ctx) {
    for (const label of this.map.labels ?? []) {
      if (!label?.text) continue;
      if (label.kind === "table_nameplate") {
        this._drawTableNameplate(ctx, label);
        continue;
      }

      const width = Math.max((label.w ?? 1) * this.tilePx, this.tilePx);
      const height = Math.max((label.h ?? 1) * this.tilePx, this.tilePx);
      const { x, y } = this.camera.worldToScreen(
        (label.x ?? 0) * this.tilePx,
        (label.y ?? 0) * this.tilePx,
      );
      const dx = Math.round(x);
      const dy = Math.round(y);

      ctx.fillStyle = HASH + SIGN_BORDER;
      ctx.fillRect(dx, dy, Math.round(width), Math.round(height));
      ctx.fillStyle = HASH + SIGN_BG;
      ctx.fillRect(
        dx + 3,
        dy + 3,
        Math.max(Math.round(width) - 6, 1),
        Math.max(Math.round(height) - 6, 1),
      );
      ctx.font = SIGN_FONT;
      ctx.textAlign = "center";
      ctx.fillStyle = HASH + SIGN_FG;
      ctx.fillText(
        String(label.text),
        Math.round(dx + width / 2),
        Math.round(dy + height / 2 + 4),
        Math.max(Math.round(width) - 12, 1),
      );
    }
  }

  _drawTableNameplate(ctx, label) {
    const width = Math.max((label.w ?? 1) * this.tilePx, this.tilePx);
    const height = Math.max((label.h ?? 1) * this.tilePx, this.tilePx);
    const { x, y } = this.camera.worldToScreen(
      (label.x ?? 0) * this.tilePx,
      (label.y ?? 0) * this.tilePx,
    );
    const dx = Math.round(x);
    const dy = Math.round(y);
    const plaqueWidth = Math.max(Math.round(width) - 20, this.tilePx * 2);
    const plaqueHeight = Math.min(18, Math.max(Math.round(height) - 8, 12));
    const px = Math.round(dx + (width - plaqueWidth) / 2);
    const py = Math.round(dy + (height - plaqueHeight) / 2);

    ctx.fillStyle = HASH + TABLE_SIGN_BORDER;
    ctx.fillRect(px, py, plaqueWidth, plaqueHeight);
    ctx.fillStyle = HASH + TABLE_SIGN_BG;
    ctx.fillRect(px + 2, py + 2, Math.max(plaqueWidth - 4, 1), Math.max(plaqueHeight - 4, 1));
    ctx.font = TABLE_SIGN_FONT;
    ctx.textAlign = "center";
    ctx.fillStyle = HASH + TABLE_SIGN_FG;
    ctx.fillText(
      String(label.text),
      Math.round(px + plaqueWidth / 2),
      Math.round(py + plaqueHeight / 2 + 4),
      Math.max(plaqueWidth - 8, 1),
    );
  }

  _drawAvatar(ctx, participant, now) {
    const action = participant.action?.kind === "sword" ? participant.action : null;
    const actionKind = action ? "sword" : "walk";
    const dir = action?.dir ?? participant.dir;
    const frame = action
      ? this._actionFrame(participant, action, now)
      : this._walkFrame(participant, now);
    const sprite = this.atlas?.avatar(participant.avatar, dir, frame, actionKind);
    if (!sprite) return;
    const { x, y } = this._avatarScreenPos(participant);
    const dw = sprite.sw * this.camera.scale;
    const dh = sprite.sh * this.camera.scale;
    const dx = x - (dw - this.tilePx) / 2;
    // Tall sprites sit with their feet on the tile; wider action sprites stay
    // centered on the avatar tile so the body does not jump during a swing.
    const dy = dh - this.tilePx;
    this._blit(ctx, sprite, Math.round(dx), Math.round(y - dy));
  }

  // Draw a sheet slice `{ img, sx, sy, sw, sh }` scaled by the camera at the
  // destination pixel. Skips images that have not finished loading so a slow
  // fetch never throws mid-frame.
  _blit(ctx, sprite, dx, dy) {
    if (!sprite) return;
    const img = sprite.img;
    if (!img || !img.complete || !img.naturalWidth) return;
    const s = this.camera.scale;
    if (sprite.flipX) {
      ctx.save();
      ctx.scale(-1, 1);
      ctx.drawImage(
        img,
        sprite.sx,
        sprite.sy,
        sprite.sw,
        sprite.sh,
        -dx - sprite.sw * s,
        dy,
        sprite.sw * s,
        sprite.sh * s,
      );
      ctx.restore();
      return;
    }

    ctx.drawImage(
      img,
      sprite.sx,
      sprite.sy,
      sprite.sw,
      sprite.sh,
      dx,
      dy,
      sprite.sw * s,
      sprite.sh * s,
    );
  }

  // Walk frame from recent movement: cycle 0-3 while the render position keeps
  // changing, settle on the idle frame 0 shortly after it stops.
  _walkFrame(participant, now) {
    const key = participant.key;
    const m = this._motion.get(key) ?? { x: participant.x, y: participant.y, t: -1e9 };
    if (participant.x !== m.x || participant.y !== m.y) {
      m.x = participant.x;
      m.y = participant.y;
      m.t = now;
    }
    this._motion.set(key, m);
    return now - m.t < 180 ? Math.floor(now / 130) % 4 : 0;
  }

  _actionFrame(participant, action, now) {
    const frames = this.atlas?.avatarFrameCount?.(participant.avatar, action.kind) ?? 1;
    const duration = Math.max(action.duration ?? 1, 1);
    const elapsed = Math.max(now - action.startedAt, 0);
    return Math.min(frames - 1, Math.floor((elapsed / duration) * frames));
  }

  _drawLabel(ctx, participant) {
    if (!participant.nickname) return;
    const { x, y } = this._avatarScreenPos(participant);
    ctx.font = LABEL_FONT;
    ctx.textAlign = "center";
    const cx = x + this.tilePx / 2;
    const headY = y - this.tilePx;
    const width = ctx.measureText(participant.nickname).width + 6;

    ctx.fillStyle = HASH + LABEL_BG;
    ctx.fillRect(Math.round(cx - width / 2), Math.round(headY - 12), Math.round(width), 11);
    ctx.fillStyle = HASH + LABEL_FG;
    ctx.fillText(participant.nickname, Math.round(cx), Math.round(headY - 3));
  }

  // Speech bubble above the nickname label. The text is drawn with fillText —
  // canvas never interprets markup, so a message can never inject HTML.
  _drawBubble(ctx, participant, text) {
    const { x, y } = this._avatarScreenPos(participant);
    ctx.font = LABEL_FONT;
    ctx.textAlign = "center";
    const cx = x + this.tilePx / 2;
    const width = Math.min(ctx.measureText(text).width + 8, this.canvas.width - 4);
    const top = y - this.tilePx - 26;

    ctx.fillStyle = HASH + BUBBLE_BG;
    ctx.fillRect(Math.round(cx - width / 2), Math.round(top), Math.round(width), 13);
    ctx.fillStyle = HASH + BUBBLE_FG;
    ctx.fillText(text, Math.round(cx), Math.round(top + 10));
  }

  _avatarScreenPos(participant) {
    return this.camera.worldToScreen(participant.x * this.tilePx, participant.y * this.tilePx);
  }
}
