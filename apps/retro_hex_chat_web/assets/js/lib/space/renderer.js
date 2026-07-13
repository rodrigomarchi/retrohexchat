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
// Soft contact shadow pooled under props and avatars (semi-transparent).
const SHADOW = "05060c";
// Isometric slab side faces (the platform's 3D thickness). The screen-left face
// is darker than the screen-right for a faked directional light.
const SLAB_FACE_L = "191b26";
const SLAB_FACE_R = "23262f";
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
// Holographic display (End of Time nameplate artifact): glowing cyan text with
// no frame of its own — reads as surviving tech on the artifact's own screen.
const HOLO_GLOW = "1f6f7d";
const HOLO_FG = "9ff6ff";
const HOLO_FONT = "10px monospace";

// Deterministic per-tile phase seed so repeated animated tiles (stars, water)
// don't cycle in lockstep — the atlas offsets an animated tile's clock by it.
function seedAt(x, y) {
  return (Math.trunc(x) * 73856093) ^ (Math.trunc(y) * 19349663);
}

// A tile-space step (sign of dx,dy) → the 8-direction iso facing it reads as on
// screen (footAnchor: +x = down-right, +y = down-left), so a walking avatar faces
// where it visibly moves. Used only by 8-direction iso avatars.
const ISO_STEP_FACING = Object.freeze({
  "1,1": "south",
  "1,0": "south-east",
  "1,-1": "east",
  "0,-1": "north-east",
  "-1,-1": "north",
  "-1,0": "north-west",
  "-1,1": "west",
  "0,1": "south-west",
});
// After this long without moving, an iso avatar drops from idle (breathing) to
// sleep (a seated doze).
const ISO_SLEEP_MS = 12000;

export class Renderer {
  /**
   * @param {object} opts
   * @param {HTMLCanvasElement} opts.canvas
   * @param {object} opts.atlas
   * @param {object} opts.map SpaceMap instance
   * @param {object} opts.camera Camera instance
   */
  constructor({ canvas, atlas, map, camera, avatarScale }) {
    this.canvas = canvas;
    this.atlas = atlas;
    this.map = map;
    this.camera = camera;
    this.ctx = canvas?.getContext?.("2d") ?? null;
    if (this.ctx) this.ctx.imageSmoothingEnabled = false;
    // The tile→world mapping (square or diamond) lives in the camera's projection.
    this.projection = camera.projection;
    this.tilePx = map.tileSize * camera.scale;
    // Avatars carry their own scale; premium iso art is authored at world size so
    // it composes 1:1. Defaults to the world scale when a caller omits it.
    this.avatarScale = avatarScale ?? camera.scale;
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
    // The cosmic sea abyss (deep-blue gradient + drifting horizontal ripple
    // bands) fills the void behind a floating platform.
    this._drawSea(ctx, now);
    // Cosmic parallax layers drift behind the floor for depth.
    this._drawParallax(ctx, now);
    // Flat decor is the distant STARFIELD in the void — drawn BEFORE the floor so
    // the solid platform/slab occludes any stars behind it (a solid island can't
    // have stars showing through it).
    this._drawDecorList(ctx, this._flatDecor(), now);
    this._drawFloor(ctx, now);
    // Soft contact shadows ground props and avatars before they are drawn over.
    this._drawShadows(ctx, state.participants, now);
    // Depth pass: standing props and avatars share one Y-sorted order so an
    // avatar passes behind a taller prop (walk-behind) and in front once past
    // its base.
    this._drawDepthSorted(ctx, state.participants, now);
    // Strictly-overhead decor (canopies, lamp tops) draws over everyone.
    this._drawDecorList(ctx, this._aboveDecor(), now);
    // Color-math atmosphere: a cozy ambient wash dims the lit world, then
    // additive light pools re-brighten it near each source (lamp, fire, portal).
    this._drawLighting(ctx);
    this._drawMapLabels(ctx);

    const ordered = [...state.participants.values()].sort((a, b) => a.y - b.y);
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

  // The cosmic sea: a deep-blue vertical gradient overlaid with slowly drifting,
  // gently rippling horizontal bands — the Chrono-Trigger End-of-Time abyss the
  // platform floats in. Absent `sea` → skipped (the void stays flat).
  _drawSea(ctx, now = 0) {
    const sea = this.map.sea;
    if (!sea) return;
    const W = this.canvas.width;
    const H = this.canvas.height;
    const grad = ctx.createLinearGradient(0, 0, 0, H);
    grad.addColorStop(0, HASH + (sea.top ?? "0b1a3a"));
    grad.addColorStop(1, HASH + (sea.bottom ?? "05060f"));
    ctx.save();
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, W, H);
    const n = sea.bands ?? 8;
    const spacing = H / n;
    const drift = (now * 0.006) % spacing;
    const amp = sea.amp ?? 6;
    ctx.fillStyle = HASH + (sea.band ?? "18376f");
    ctx.globalAlpha = sea.alpha ?? 0.24;
    for (let i = -1; i <= n; i += 1) {
      const y0 = i * spacing + drift;
      const phase = now * 0.001 + i;
      const bandH = spacing * 0.5;
      ctx.beginPath();
      ctx.moveTo(0, y0);
      for (let x = 0; x <= W; x += 24) ctx.lineTo(x, y0 + Math.sin(x / 70 + phase) * amp);
      for (let x = W; x >= 0; x -= 24) {
        ctx.lineTo(x, y0 + bandH + Math.sin(x / 70 + phase + 0.6) * amp);
      }
      ctx.closePath();
      ctx.fill();
    }
    ctx.restore();
  }

  // Cosmic parallax: repeat each layer's tile across the viewport, offset by the
  // camera times a slow scroll factor so the void drifts behind the platform.
  // Maps without a `parallax` list skip this entirely.
  _drawParallax(ctx, now = 0) {
    for (const layer of this.map.parallax ?? []) {
      const sprite = this.atlas?.tile(layer.tile, now, 0);
      if (!sprite?.img?.complete || !sprite.img.naturalWidth) continue;
      const scroll = layer.scroll ?? 0.3;
      const step = Math.max((layer.step ?? 6) * this.tilePx, 1);
      const ox = -(((this.camera.x * scroll) % step) + step);
      const oy = -(((this.camera.y * scroll) % step) + step);
      ctx.save();
      ctx.globalAlpha = layer.alpha ?? 0.5;
      for (let y = oy; y < this.canvas.height + step; y += step) {
        for (let x = ox; x < this.canvas.width + step; x += step) {
          this._blit(ctx, sprite, Math.round(x), Math.round(y));
        }
      }
      ctx.restore();
    }
  }

  // Isometric floor: diamond tiles painted far→near (ascending x+y) so nearer
  // diamonds and slab faces occlude farther ones. Void cells (the ground/`f0000`
  // tile) are skipped so the platform reads as a slab floating in the abyss.
  _drawFloor(ctx, now = 0) {
    const ground = this.map.ground;
    const fp = this.projection.tileFootprint;
    // The slab underside (the block tapering to a diamond below) is one shape,
    // drawn before the top tiles so the surface seats cleanly over its rim.
    this._drawSlabUnderside(ctx);
    for (const { x: tx, y: ty } of this._isoTileOrder()) {
      const tileId = this.map.floorTile(tx, ty);
      if (!tileId || tileId === ground) continue;
      const a = this.projection.floorAnchor(tx, ty);
      const s = this.camera.worldToScreen(a.x, a.y);
      if (s.x + fp.w < 0 || s.x > this.canvas.width || s.y + fp.h < 0 || s.y > this.canvas.height) {
        continue;
      }
      this._blit(
        ctx,
        this.atlas?.tile(tileId, now, seedAt(tx, ty)),
        Math.round(s.x),
        Math.round(s.y),
      );
    }
  }

  // The platform's 3D underside: the four hull corners projected, with the two
  // camera-facing front faces (front-left, front-right) extruded down and pulled
  // toward a centre apex by `taper` — so the block reads as a solid island that
  // narrows to a diamond point below (taper=1 → a sharp point). `slab.hull` is the
  // [minX,maxX,minY,maxY] of solid cells.
  _drawSlabUnderside(ctx) {
    const slab = this.map.slab;
    if (!slab?.hull) return;
    const [sx0, sx1, sy0, sy1] = slab.hull;
    const depth = (slab.thickness ?? 0) * (this.projection.zs ?? 0);
    const taper = slab.taper ?? 0;
    const fp = this.projection.tileFootprint;
    const hw = fp.w / 2;
    const hh = fp.h / 2;
    const vert = (tx, ty, dx, dy) => {
      const f = this.projection.footAnchor(tx, ty);
      const s = this.camera.worldToScreen(f.x, f.y);
      return { x: s.x + dx, y: s.y + dy };
    };
    // Only the two camera-facing front faces are visible (top/back are hidden).
    const right = vert(sx1, sy0, hw, 0);
    const bottom = vert(sx1, sy1, 0, hh);
    const left = vert(sx0, sy1, -hw, 0);
    const apex = { x: (left.x + right.x) / 2, y: bottom.y + depth };
    const dn = (p) => ({
      x: p.x + (apex.x - p.x) * taper,
      y: p.y + depth + (apex.y - (p.y + depth)) * taper,
    });
    this._fillPoly(ctx, SLAB_FACE_L, [left, bottom, dn(bottom), dn(left)]);
    this._fillPoly(ctx, SLAB_FACE_R, [bottom, right, dn(right), dn(bottom)]);
  }

  _fillPoly(ctx, color, pts) {
    ctx.fillStyle = HASH + color;
    ctx.beginPath();
    ctx.moveTo(Math.round(pts[0].x), Math.round(pts[0].y));
    for (let i = 1; i < pts.length; i += 1) ctx.lineTo(Math.round(pts[i].x), Math.round(pts[i].y));
    ctx.closePath();
    ctx.fill();
  }

  // Tile coordinates ordered by isometric depth (x+y), cached per map.
  _isoTileOrder() {
    if (this._isoOrder) return this._isoOrder;
    const order = [];
    for (let y = 0; y < this.map.height; y += 1) {
      for (let x = 0; x < this.map.width; x += 1) order.push({ x, y });
    }
    order.sort((a, b) => a.x + a.y - (b.x + b.y));
    this._isoOrder = order;
    return order;
  }

  // Ground-flat decor (stars, shadows, floor marks): drawn under everyone.
  // A decor entry is flat unless it opts into the depth pass with sort:"stand".
  _flatDecor() {
    return (this.map.decor ?? []).filter((p) => p.sort !== "stand");
  }

  // Standing props (lamp, pillars, portal): Y-sorted against avatars.
  _standDecor() {
    return (this.map.decor ?? []).filter((p) => p.sort === "stand");
  }

  // The `above` layer — decor that always draws over avatars (overhead canopy).
  _aboveDecor() {
    return this.map.layers?.above ?? [];
  }

  // Multi-tile props anchored at their top-left tile, drawn at native sprite
  // size over the floor.
  _drawDecorList(ctx, list, now = 0) {
    for (const prop of list) {
      const sprite = this.atlas?.tile(prop.tile, now, seedAt(prop.x, prop.y));
      if (sprite) this._blitProp(ctx, prop, sprite);
    }
  }

  _blitProp(ctx, prop, sprite) {
    const a = this.projection.floorAnchor(prop.x, prop.y);
    const { x, y } = this.camera.worldToScreen(a.x, a.y);
    this._blit(ctx, sprite, Math.round(x), Math.round(y));
  }

  // Interleave standing props and avatars by their base (feet) row so an avatar
  // renders behind a prop while above its base, and in front once past it. A
  // prop's base row is its top row plus its sprite height in tiles; an avatar's
  // is its tile row plus one (feet at the bottom of the tile it stands on).
  _drawDepthSorted(ctx, participants, now = 0) {
    const items = [];
    for (const prop of this._standDecor()) {
      const sprite = this.atlas?.tile(prop.tile, now, seedAt(prop.x, prop.y));
      if (!sprite) continue;
      // Foot = the base tile (depthKey folds elevation in as a tie-break); props
      // draw as upright billboards rising from their diamond foot.
      items.push({
        baseline: this.projection.depthKey(prop.x, prop.y, prop.h ?? 0),
        draw: () => this._blitBillboard(ctx, prop, sprite),
      });
    }
    for (const participant of participants.values()) {
      items.push({
        baseline: this.projection.depthKey(participant.x, participant.y) + 0.5,
        draw: () => this._drawAvatar(ctx, participant, now),
      });
    }
    // Iso railing: one sheared wall tile per platform edge cell, blitted on the
    // cell's shared diamond edge with its void neighbour — the tiles abut into
    // ONE seam-free wrought-iron fence wrapping the four sides, depth-sorted so
    // back edges (tr/tl) draw behind avatars and front edges (bl/br) in front.
    for (const r of this.map.railings ?? []) {
      const front = r.edge === "bl" || r.edge === "br";
      items.push({
        baseline: this.projection.depthKey(r.x, r.y) + (front ? 0.75 : 0.25),
        draw: () => this._drawRailingTile(ctx, r),
      });
    }
    for (const p of this.map.railingPosts ?? []) {
      items.push({
        baseline: this.projection.depthKey(p.x, p.y) + 0.3,
        draw: () => this._drawRailingPost(ctx, p),
      });
    }
    items.sort((a, b) => a.baseline - b.baseline);
    for (const item of items) item.draw();
  }

  // Blit a cell's sheared iso wall tile onto its shared diamond edge. The tile's
  // base line was pre-sheared to the 2:1 slope in the author, so its base-left
  // pixel lands on the edge's near vertex and adjacent cells abut seam-free:
  //   tr/bl use the down-right tile, tl/br its down-left mirror; tr/tl touch the
  //   cell Top, bl/br the Left/Bottom vertex. `drop` is the base's screen descent
  //   over the tile (scale-invariant ratio), so `base` is the native rows down to
  //   the anchored vertex.
  _drawRailingTile(ctx, r) {
    const dr = r.edge === "tr" || r.edge === "bl";
    const sprite = this.atlas?.tile(dr ? "iso_rail_dr" : "iso_rail_dl");
    if (!sprite) return;
    const scale = this.camera.scale;
    const hw = this.projection.hw;
    const hh = this.projection.hh;
    const f = this.projection.footAnchor(r.x, r.y);
    const s = this.camera.worldToScreen(f.x, f.y);
    const drop = Math.round((sprite.sw - 1) * (hh / hw));
    const base = (dr ? sprite.sh - drop - 1 : sprite.sh - 1) * scale;
    let dx = s.x;
    let dy = s.y - base;
    if (r.edge === "tr") dy -= hh;
    else if (r.edge === "tl") ((dx -= hw), (dy -= hh));
    else if (r.edge === "bl") dx -= hw;
    else dy += hh; // br
    this._blit(ctx, sprite, Math.round(dx), Math.round(dy), scale);
  }

  // An ornate golden corner post billboarded on a platform-corner vertex (the
  // diamond's N/E/S/W tip), bridging the two edge slopes that meet there.
  _drawRailingPost(ctx, p) {
    const sprite = this.atlas?.tile("iso_rail_post");
    if (!sprite) return;
    const scale = this.camera.scale;
    const hw = this.projection.hw;
    const hh = this.projection.hh;
    const f = this.projection.footAnchor(p.x, p.y);
    const s = this.camera.worldToScreen(f.x, f.y);
    const off = { n: [0, -hh], e: [hw, 0], s: [0, hh], w: [-hw, 0] }[p.corner] ?? [0, 0];
    const vx = s.x + off[0];
    const vy = s.y + off[1];
    this._blit(
      ctx,
      sprite,
      Math.round(vx - (sprite.sw * scale) / 2),
      Math.round(vy - sprite.sh * scale),
      scale,
    );
  }

  // Isometric standing prop: a billboard whose bottom-centre sits on the tile's
  // diamond foot and rises upward, so tall props tower while depth-sorting by
  // their foot tile.
  _blitBillboard(ctx, prop, sprite) {
    const scale = this.camera.scale;
    const f = this.projection.footAnchor(prop.x, prop.y, prop.h ?? 0);
    const { x, y } = this.camera.worldToScreen(f.x, f.y);
    const w = sprite.sw * scale;
    const h = sprite.sh * scale;
    this._blit(ctx, sprite, Math.round(x - w / 2), Math.round(y - h), scale);
  }

  // Soft elliptical contact shadows under every standing prop and avatar, so
  // they read as resting on the floor rather than floating. Drawn once with a
  // shared alpha before the depth pass paints the sprites over them.
  _drawShadows(ctx, participants, now = 0) {
    const stand = this._standDecor();
    if (stand.length === 0 && participants.size === 0) return;
    const scale = this.camera.scale;
    ctx.save();
    ctx.globalAlpha = 0.26;
    ctx.fillStyle = HASH + SHADOW;
    for (const prop of stand) {
      const sprite = this.atlas?.tile(prop.tile, now, seedAt(prop.x, prop.y));
      if (!sprite) continue;
      const ap = this.projection.floorAnchor(prop.x, prop.y);
      const { x, y } = this.camera.worldToScreen(ap.x, ap.y);
      const wpx = sprite.sw * scale;
      const hpx = sprite.sh * scale;
      this._ellipse(ctx, x + wpx / 2, y + hpx - this.tilePx * 0.15, wpx * 0.32, this.tilePx * 0.24);
    }
    for (const participant of participants.values()) {
      const av = this.projection.floorAnchor(participant.x, participant.y);
      const { x, y } = this.camera.worldToScreen(av.x, av.y);
      this._ellipse(
        ctx,
        x + this.tilePx / 2,
        y + this.tilePx * 0.9,
        this.tilePx * 0.34,
        this.tilePx * 0.2,
      );
    }
    ctx.restore();
  }

  // A filled ellipse via a squashed arc (canvas has no primitive our mock ctx
  // shares); the caller owns fillStyle/globalAlpha.
  _ellipse(ctx, cx, cy, rx, ry) {
    ctx.save();
    ctx.translate(cx, cy);
    ctx.scale(1, ry / rx);
    ctx.beginPath();
    ctx.arc(0, 0, rx, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }

  // Color-math lighting: a multiply ambient wash dims the whole lit scene into a
  // cozy dusk, then additive radial pools re-brighten it around each source. A
  // map without `ambient`/`lights` renders unchanged (full bright).
  _drawLighting(ctx) {
    const ambient = this.map.ambient;
    if (ambient) {
      ctx.save();
      ctx.globalCompositeOperation = "multiply";
      ctx.globalAlpha = ambient.alpha ?? 0.4;
      ctx.fillStyle = HASH + (ambient.color ?? "000000");
      ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
      ctx.restore();
    }
    for (const light of this.map.lights ?? []) {
      // Anchor the pool at the tile's ground centre (foot), not the sprite-box
      // top-left — otherwise the glow lands half a tile up-left of the lamp that
      // casts it.
      // `lift` raises the glow centre up the screen (px) so a source can sit at an
      // elevated emitter — e.g. the halo at a lamppost's head, not its base.
      const a = this.projection.footAnchor(light.x, light.y);
      const s = this.camera.worldToScreen(a.x, a.y);
      const x = s.x;
      const y = s.y - (light.lift ?? 0) * this.camera.scale;
      const radius = Math.max((light.radius ?? 3) * this.tilePx, 1);
      const color = light.color ?? "ffffff";
      const grad = ctx.createRadialGradient(x, y, 0, x, y, radius);
      grad.addColorStop(0, HASH + color + "b3");
      grad.addColorStop(0.5, HASH + color + "40");
      grad.addColorStop(1, HASH + color + "00");
      ctx.save();
      ctx.globalCompositeOperation = light.blend === "multiply" ? "multiply" : "lighter";
      ctx.fillStyle = grad;
      ctx.fillRect(x - radius, y - radius, radius * 2, radius * 2);
      ctx.restore();
    }
    this._drawVignette(ctx);
  }

  // A screen-space radial multiply that darkens the canvas edges, framing the lit
  // platform against the void. Absent `vignette` → skipped.
  _drawVignette(ctx) {
    const vig = this.map.vignette;
    if (!vig) return;
    const cx = this.canvas.width / 2;
    const cy = this.canvas.height / 2;
    const outer = Math.hypot(cx, cy);
    const color = vig.color ?? "000000";
    const alpha = Math.round((vig.alpha ?? 0.5) * 255)
      .toString(16)
      .padStart(2, "0");
    const grad = ctx.createRadialGradient(cx, cy, outer * (vig.inner ?? 0.45), cx, cy, outer);
    grad.addColorStop(0, HASH + color + "00");
    grad.addColorStop(1, HASH + color + alpha);
    ctx.save();
    ctx.globalCompositeOperation = "multiply";
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
    ctx.restore();
  }

  _drawMapLabels(ctx) {
    for (const label of this.map.labels ?? []) {
      if (!label?.text) continue;
      if (label.kind === "table_nameplate") {
        this._drawTableNameplate(ctx, label);
        continue;
      }
      if (label.kind === "hologram") {
        this._drawHologram(ctx, label);
        continue;
      }

      const width = Math.max((label.w ?? 1) * this.tilePx, this.tilePx);
      const height = Math.max((label.h ?? 1) * this.tilePx, this.tilePx);
      const la = this.projection.floorAnchor(label.x ?? 0, label.y ?? 0);
      const { x, y } = this.camera.worldToScreen(la.x, la.y);
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
    const la = this.projection.floorAnchor(label.x ?? 0, label.y ?? 0);
    const { x, y } = this.camera.worldToScreen(la.x, la.y);
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

  // Glowing holographic name display, drawn over the End of Time artifact's own
  // display panel: cyan text with a 1px glow (four offset copies under a bright
  // core). No panel or frame of its own — the names float on the stone screen,
  // shrunk to fit the label box so they never spill past the artifact.
  _drawHologram(ctx, label) {
    const width = Math.max((label.w ?? 1) * this.tilePx, this.tilePx);
    const maxWidth = Math.max(Math.round(width) - 8, 1);
    // The nameplate centres over its tile (the lamppost) and is raised by `lift`
    // px so it floats above the lamp, over its light.
    const a = this.projection.footAnchor(label.x ?? 0, label.y ?? 0);
    const lift = (label.lift ?? 0) * (this.projection.scale ?? 1);
    const sp = this.camera.worldToScreen(a.x, a.y - lift);
    const cx = Math.round(sp.x);
    const ty = Math.round(sp.y);

    ctx.font = HOLO_FONT;
    ctx.textAlign = "center";
    ctx.fillStyle = HASH + HOLO_GLOW;
    for (const [ox, oy] of [
      [-1, 0],
      [1, 0],
      [0, -1],
      [0, 1],
    ]) {
      ctx.fillText(String(label.text), cx + ox, ty + oy, maxWidth);
    }
    ctx.fillStyle = HASH + HOLO_FG;
    ctx.fillText(String(label.text), cx, ty, maxWidth);
  }

  _drawAvatar(ctx, participant, now) {
    const pose = this._avatarPose(participant, now);
    const sprite = this.atlas?.avatar(participant.avatar, pose.dir, pose.frame, pose.actionKind);
    if (!sprite) return;
    // Premium iso avatars ship oversized art; `sprite.scale` renders it to world size.
    const scale = this.avatarScale * (sprite.scale ?? 1);
    // Billboard the avatar with its feet on the diamond foot.
    const f = this.projection.footAnchor(participant.x, participant.y);
    const s = this.camera.worldToScreen(f.x, f.y);
    const aw = sprite.sw * scale;
    const ah = sprite.sh * scale;
    this._blit(ctx, sprite, Math.round(s.x - aw / 2), Math.round(s.y - ah), scale);
  }

  // Resolve a participant into an animation pose {actionKind, dir, frame}. Premium
  // 8-direction iso avatars face where they move and run a full state machine:
  // attack (sword) > walk (moving) > sleep (long idle) > idle (breathing).
  _avatarPose(participant, now) {
    const meta = this.atlas?.avatarMeta?.(participant.avatar) ?? {};
    const action = participant.action?.kind === "sword" ? participant.action : null;
    const m = this._trackMotion(participant, now);
    if (action) {
      return {
        actionKind: "sword",
        dir: m.dir8,
        frame: this._actionFrame(participant, action, now),
      };
    }
    const still = now - m.t;
    if (still < 180) {
      return { actionKind: "walk", dir: m.dir8, frame: Math.floor(now / 120) % 4 };
    }
    if (meta.hasSleep && still > ISO_SLEEP_MS) {
      return { actionKind: "sleep", dir: m.dir8, frame: Math.floor(now / 300) % 4 };
    }
    if (meta.hasIdle) {
      return { actionKind: "idle", dir: m.dir8, frame: Math.floor(now / 220) % 4 };
    }
    return { actionKind: "walk", dir: m.dir8, frame: 0 };
  }

  // Track a participant's last tile, the time it last changed, and the 8-direction
  // facing implied by its most recent step (kept while it stands still).
  _trackMotion(participant, now) {
    const key = participant.key;
    // A just-seen participant starts idle (breathing), not walking and not asleep:
    // seed `t` just inside the idle band so it only drifts to sleep after a real
    // stretch of standing still (ISO_SLEEP_MS from now), never on spawn.
    const m = this._motion.get(key) ?? {
      x: participant.x,
      y: participant.y,
      t: now - 1000,
      dir8: "south",
    };
    if (participant.x !== m.x || participant.y !== m.y) {
      const step = `${Math.sign(participant.x - m.x)},${Math.sign(participant.y - m.y)}`;
      if (ISO_STEP_FACING[step]) m.dir8 = ISO_STEP_FACING[step];
      m.x = participant.x;
      m.y = participant.y;
      m.t = now;
    }
    this._motion.set(key, m);
    return m;
  }

  // Draw a sheet slice `{ img, sx, sy, sw, sh }` scaled by the camera at the
  // destination pixel. Skips images that have not finished loading so a slow
  // fetch never throws mid-frame.
  _blit(ctx, sprite, dx, dy, scale = this.camera.scale) {
    if (!sprite) return;
    const img = sprite.img;
    if (!img || !img.complete || !img.naturalWidth) return;
    const s = scale;
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
    const a = this.projection.floorAnchor(participant.x, participant.y);
    return this.camera.worldToScreen(a.x, a.y);
  }
}
