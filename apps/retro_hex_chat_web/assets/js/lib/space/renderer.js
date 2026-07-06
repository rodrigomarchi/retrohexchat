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

    ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
    ctx.fillStyle = HASH + VOID_BG;
    ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
    this._drawFloor(ctx);

    const ordered = [...state.participants.values()].sort((a, b) => a.y - b.y);
    for (const participant of ordered) {
      this._drawAvatar(ctx, participant);
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

    for (let ty = startY; ty < startY + rows; ty += 1) {
      for (let tx = startX; tx < startX + cols; tx += 1) {
        if (!this.map.inBounds(tx, ty)) continue;
        const sprite = this.atlas?.tile(this.map.floorTile(tx, ty));
        if (!sprite) continue;
        const { x, y } = this.camera.worldToScreen(tx * this.tilePx, ty * this.tilePx);
        ctx.drawImage(sprite.canvas, Math.round(x), Math.round(y));
      }
    }
  }

  _drawAvatar(ctx, participant) {
    const sprite = this.atlas?.avatar(participant.avatar, participant.dir);
    if (!sprite) return;
    const { x, y } = this._avatarScreenPos(participant);
    ctx.drawImage(sprite.canvas, Math.round(x), Math.round(y));
  }

  _drawLabel(ctx, participant) {
    if (!participant.nickname) return;
    const { x, y } = this._avatarScreenPos(participant);
    ctx.font = LABEL_FONT;
    ctx.textAlign = "center";
    const cx = x + this.tilePx / 2;
    const width = ctx.measureText(participant.nickname).width + 6;

    ctx.fillStyle = HASH + LABEL_BG;
    ctx.fillRect(Math.round(cx - width / 2), Math.round(y - 12), Math.round(width), 11);
    ctx.fillStyle = HASH + LABEL_FG;
    ctx.fillText(participant.nickname, Math.round(cx), Math.round(y - 3));
  }

  // Speech bubble above the nickname label. The text is drawn with fillText —
  // canvas never interprets markup, so a message can never inject HTML.
  _drawBubble(ctx, participant, text) {
    const { x, y } = this._avatarScreenPos(participant);
    ctx.font = LABEL_FONT;
    ctx.textAlign = "center";
    const cx = x + this.tilePx / 2;
    const width = Math.min(ctx.measureText(text).width + 8, this.canvas.width - 4);
    const top = y - 26;

    ctx.fillStyle = HASH + BUBBLE_BG;
    ctx.fillRect(Math.round(cx - width / 2), Math.round(top), Math.round(width), 13);
    ctx.fillStyle = HASH + BUBBLE_FG;
    ctx.fillText(text, Math.round(cx), Math.round(top + 10));
  }

  _avatarScreenPos(participant) {
    return this.camera.worldToScreen(participant.x * this.tilePx, participant.y * this.tilePx);
  }
}
