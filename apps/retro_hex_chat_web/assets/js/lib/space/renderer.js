/**
 * Canvas 2D renderer for the virtual space. Draws the floor, then avatars
 * ordered by Y (so lower avatars overlap higher ones), then nickname labels.
 * Integer scaling with `imageSmoothingEnabled = false` keeps the 8-bit look.
 * @module space/renderer
 */
import { wrapBubbleText } from "./bubble_layout.js";
import { drawNineSlice, drawPiece } from "./nine_slice.js";
import { readUiTheme } from "./ui_theme.js";
import { createGlyphLoader } from "./ui_font.js";
import { isFocusedProp } from "./focus.js";

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
// The canvas's UI — nameplates, bubbles, the HP bar — is drawn from the
// space's pixel-art kit (`atlas.uiPiece`), in the kit's pixel font and colours
// (`ui_theme.js`). These colours only stand in when the page defines none.
const LABEL_BG = "1b1d24";
const LABEL_FG = "e8dcc0";
// Native heights of the kit's plates, tall enough for a 12px line inside the
// frame, and where that line's baseline sits in them.
const NAMEPLATE_H = 21;
const NAMEPLATE_BASELINE = 15;
const NAMEPLATE_PAD_X = 13;
// Combat HP bar under the nameplate: healthy green above half, amber below.
const HP_MAX = 100;
const HP_BAR_W = 34;
const HP_BAR_INSET = 3;
// Combat impact feedback, layered per hit: a white flash on the sprite, a
// PixelLab spark/burst at the point of impact, and a floating damage number.
// A knockout also nudges the *victim's own* camera briefly (skipped entirely
// under prefers-reduced-motion).
const FX_FLASH_MS = 120;
const FX_SPARK_MS = 280;
const FX_BURST_MS = 420;
const FX_NUMBER_MS = 700;
const FX_NUMBER_RISE_PX = 26;
const FX_SHAKE_MS = 150;
const FX_SHAKE_AMP_PX = 3;
const DMG_FG = "ffeca0";
const DMG_KO_FG = "ff6050";
const BUBBLE_FG = "421f22";
// A bubble's lines: 13px apart, the first baseline under the frame's top edge,
// the text kept clear of the side edges.
const BUBBLE_LINE_PX = 13;
const BUBBLE_FIRST_BASELINE = 18;
const BUBBLE_PAD_X = 11;
const BUBBLE_PAD_Y = 11;
// Holographic display (End of Time nameplate artifact): glowing cyan text with
// no frame of its own — reads as surviving tech on the artifact's own screen.
const HOLO_GLOW = "1f6f7d";
const HOLO_FG = "9ff6ff";
// Construct build markers: the ghost's diamond is green where the piece fits
// and red where it does not; a picked piece gets a gold outline.
const BUILD_OK = "4dd27a";
const BUILD_BAD = "e0533d";
const BUILD_PICK = "ffd23e";
const GHOST_ALPHA = 0.55;
// What the use button reaches: its art ringed in pulsing gold, a prompt over it.
const FOCUS_RING_PX = 2;
const FOCUS_PULSE_MS = 900;
const FOCUS_PROMPT_GAP = 4;
// A target with no art of its own (the seat under someone): prompt lift.
const FOCUS_PROMPT_LIFT = 40;
const FOCUS_KEYS = Object.freeze({ interact: "E", sit: "F" });
// A seated avatar rests on the seat, not on the floor beneath it: the sitting
// pose is drawn this many native pixels up, so the chair's legs show below.
const SEAT_LIFT_PX = 16;
// A seated avatar faces the way its chair does: a seat's cardinal facing →
// the 8-direction iso rotation it reads as on screen (see ISO_STEP_FACING).
const SEAT_FACING = Object.freeze({
  down: "south-west",
  right: "south-east",
  up: "north-east",
  left: "north-west",
});

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
// sleep (a seated doze; south dozes on a 4-frame cycle, other facings hold a
// static sitting rotation).
const ISO_SLEEP_MS = 12000;
// Avatars whose sheet carries a second idle variant (idle2) alternate between
// the two stances on this slow cycle, spending IDLE2_SHARE of it on the variant.
// The phase is offset per participant so a standing crowd never shifts in sync.
const ISO_IDLE_CYCLE_MS = 9000;
const ISO_IDLE2_SHARE = 1 / 3;
// Ephemeral actions the pose machine plays from the action stream. A KO'd
// participant (pose "down") holds the last ko frame between actions.
const ISO_COMBAT_ACTIONS = new Set(["sword", "wave", "hit", "ko", "getup"]);
// One beat of the dance loop.
const DANCE_BEAT_MS = 200;

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
    // Combat feedback state: which hit/ko action instances already spawned
    // their effects, the live effect list, and the local-player shake clock.
    this._fxSeen = new Map();
    this._fx = [];
    this._shakeAt = null;
    this._flashCanvas = null;
    // Gold silhouettes of focused art, by sheet slice; a handful at most.
    this._rings = new Map();
    this._reducedMotion =
      typeof window !== "undefined" &&
      window.matchMedia?.("(prefers-reduced-motion: reduce)")?.matches === true;
    this._theme = readUiTheme(canvas, {
      bubbleInk: HASH + BUBBLE_FG,
      labelInk: HASH + LABEL_FG,
      damage: HASH + DMG_FG,
      damageKo: HASH + DMG_KO_FG,
      damageOutline: HASH + LABEL_BG,
      hologramInk: HASH + HOLO_FG,
      focus: HASH + BUILD_PICK,
      family: "monospace",
    });
    this._glyphs = createGlyphLoader(
      typeof document !== "undefined" ? document.fonts : null,
      this._theme.font,
    );
  }

  // A sliced kit piece over a box, when the kit has it.
  _frame(ctx, name, x, y, w, h) {
    const piece = this.atlas?.uiPiece?.(name);
    if (piece) drawNineSlice(ctx, piece, x, y, w, h);
  }

  // Set the pixel font for `text`, asking for its glyphs if they are new.
  _uiFont(ctx, text) {
    ctx.font = this._theme.font;
    ctx.textAlign = "left";
    ctx.fontKerning = "none";
    this._glyphs.ensure(text);
  }

  // Draw `text` centred on `cx`, starting on a whole pixel: a centred line of
  // odd width would land on a half pixel and blur the pixel font.
  _centredText(ctx, text, cx, y, maxWidth) {
    const width = ctx.measureText(text).width;
    const drawn = maxWidth ? Math.min(width, maxWidth) : width;
    const x = Math.round(cx - drawn / 2);
    if (maxWidth) ctx.fillText(text, x, Math.round(y), maxWidth);
    else ctx.fillText(text, x, Math.round(y));
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

    this._trackCombatFx(state, now);
    const shake = this._shakeOffset(now);
    if (shake) {
      ctx.save();
      ctx.translate(shake.x, shake.y);
    }

    ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
    ctx.fillStyle = HASH + (this.map.backdrop ?? VOID_BG);
    ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
    // The cosmic sea abyss (deep-blue gradient + drifting horizontal ripple
    // bands) fills the void behind a floating platform.
    this._drawSea(ctx, now);
    // Flat decor is the distant STARFIELD in the void — drawn BEFORE the floor so
    // the solid platform/slab occludes any stars behind it (a solid island can't
    // have stars showing through it).
    this._drawDecorList(ctx, this._flatDecor(), now);
    this._drawFloor(ctx, now);
    // Soft contact shadows ground props and avatars before they are drawn over.
    this._drawShadows(ctx, state.participants, now);
    // A Construct's build markers lie on the floor, under every piece.
    this._drawBuildMarkers(ctx, state.construct);
    // Depth pass: standing props and avatars share one Y-sorted order so an
    // avatar passes behind a taller prop (walk-behind) and in front once past
    // its base.
    const focusTop = this._drawDepthSorted(
      ctx,
      state.participants,
      now,
      state.construct?.ghost ?? null,
      state.focus ?? null,
    );
    // Strictly-overhead decor (canopies, lamp tops) draws over everyone.
    this._drawDecorList(ctx, this._aboveDecor(), now);
    // Color-math atmosphere: a cozy ambient wash dims the lit world, then
    // additive light pools re-brighten it near each source (lamp, fire, portal).
    this._drawLighting(ctx);
    this._drawMapLabels(ctx);
    this._drawFocusPrompt(ctx, state.focus ?? null, focusTop, {
      showKeys: state.showKeys !== false,
      self: state.selfKey ? state.participants.get(state.selfKey) : null,
    });

    // Impact sparks glow over the lit world; damage numbers float over labels.
    this._drawCombatSparks(ctx, state.participants, now);

    const ordered = [...state.participants.values()].sort((a, b) => a.y - b.y);
    for (const participant of ordered) {
      this._drawLabel(ctx, participant);
      const text = bubbles.get(participant.key);
      if (text) this._drawBubble(ctx, participant, text);
    }
    this._drawDamageNumbers(ctx, state.participants, now);

    if (shake) ctx.restore();
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

  // Isometric floor: diamond tiles painted far→near (ascending x+y) so nearer
  // diamonds and slab faces occlude farther ones. Void cells (the ground/`f0000`
  // tile) are skipped so the platform reads as a slab floating in the abyss.
  _drawFloor(ctx, now = 0) {
    const ground = this.map.ground;
    const fp = this.projection.tileFootprint;
    // The slab undersides (each block tapering below its platform) draw before
    // the top tiles so every surface seats cleanly over its own rim.
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

  // The 3D undersides of every solid block (platforms and bridges), drawn
  // far→near by each hull's front corner so a nearer block's faces paint over a
  // farther block's.
  _drawSlabUnderside(ctx) {
    const slabs = this.map.slabs ?? [];
    if (slabs.length === 0) return;
    const byDepth = [...slabs].sort((a, b) => a.hull[1] + a.hull[3] - (b.hull[1] + b.hull[3]));
    for (const slab of byDepth) this._drawSlab(ctx, slab);
  }

  // One block's underside: the four hull corners projected, with the two
  // camera-facing front faces (front-left, front-right) extruded down and pulled
  // toward a centre apex by `taper` — so the block reads as a solid island that
  // narrows to a diamond point below (taper=1 → a sharp point; taper=0 → a
  // straight prism, the bridge look). `hull` is the [minX,maxX,minY,maxY] of the
  // block's solid cells.
  _drawSlab(ctx, slab) {
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
  //
  // The focused target's art is ringed as it is drawn; the screen point over
  // its top comes back for the prompt, or null when nothing was ringed.
  _drawDepthSorted(ctx, participants, now = 0, ghost = null, focus = null) {
    const items = [];
    let focusTop = null;
    for (const prop of this._standDecor()) {
      const sprite = this.atlas?.tile(prop.tile, now, seedAt(prop.x, prop.y));
      if (!sprite) continue;
      const ringed = isFocusedProp(focus, prop);
      // Foot = the base tile (depthKey folds elevation in as a tie-break); props
      // draw as upright billboards rising from their diamond foot.
      items.push({
        baseline: this.projection.depthKey(prop.x, prop.y, prop.h ?? 0),
        draw: () => {
          if (ringed) {
            const top = this._drawFocusRing(ctx, prop, sprite, now);
            if (top && (!focusTop || top.y < focusTop.y)) focusTop = top;
          }
          this._blitBillboard(ctx, prop, sprite);
        },
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
    // The piece about to be placed, translucent, in its true depth slot so it
    // already passes in front of and behind people the way it will.
    const ghostSprite = ghost?.tile ? this.atlas?.tile(ghost.tile) : null;
    if (ghostSprite) {
      items.push({
        baseline: this.projection.depthKey(ghost.x, ghost.y),
        draw: () => {
          ctx.save();
          ctx.globalAlpha = GHOST_ALPHA;
          this._blitBillboard(ctx, ghost, ghostSprite);
          ctx.restore();
        },
      });
    }
    items.sort((a, b) => a.baseline - b.baseline);
    for (const item of items) item.draw();
    return focusTop;
  }

  // A pulsing gold ring around a billboard's opaque pixels, drawn just before
  // the billboard so only the rim shows. Returns the point over its top.
  _drawFocusRing(ctx, prop, sprite, now) {
    const ring = this._ringOf(sprite);
    const scale = this.camera.scale;
    const f = this.projection.footAnchor(prop.x, prop.y, prop.h ?? 0);
    const { x, y } = this.camera.worldToScreen(f.x, f.y);
    const pad = FOCUS_RING_PX * scale;
    const dx = Math.round(x - (sprite.sw * scale) / 2) - pad;
    const dy = Math.round(y - sprite.sh * scale) - pad;
    if (ring) {
      const w = ring.width * scale;
      const h = ring.height * scale;
      const wave = (Math.sin((now / FOCUS_PULSE_MS) * Math.PI * 2) + 1) / 2;
      ctx.save();
      ctx.globalAlpha = this._reducedMotion ? 0.9 : 0.55 + 0.45 * wave;
      ctx.imageSmoothingEnabled = false;
      if (sprite.flipX) {
        ctx.scale(-1, 1);
        ctx.drawImage(ring, 0, 0, ring.width, ring.height, -dx - w, dy, w, h);
      } else {
        ctx.drawImage(ring, 0, 0, ring.width, ring.height, dx, dy, w, h);
      }
      ctx.restore();
    }
    return { x: Math.round(x), y: dy };
  }

  // The sprite's silhouette grown by FOCUS_RING_PX, in gold, once per sheet
  // slice; null before the sheet loads or without a 2D context.
  _ringOf(sprite) {
    if (!isDrawable(sprite.img) || typeof document === "undefined") return null;
    const key = `${sprite.sx},${sprite.sy},${sprite.sw},${sprite.sh}`;
    const cached = this._rings.get(key);
    if (cached?.img === sprite.img) return cached.canvas;
    const r = FOCUS_RING_PX;
    const canvas = document.createElement("canvas");
    canvas.width = sprite.sw + r * 2;
    canvas.height = sprite.sh + r * 2;
    const octx = canvas.getContext?.("2d");
    if (!octx) return null;
    for (let ox = -r; ox <= r; ox++) {
      for (let oy = -r; oy <= r; oy++) {
        if (Math.abs(ox) + Math.abs(oy) > r) continue;
        octx.drawImage(
          sprite.img,
          sprite.sx,
          sprite.sy,
          sprite.sw,
          sprite.sh,
          r + ox,
          r + oy,
          sprite.sw,
          sprite.sh,
        );
      }
    }
    octx.globalCompositeOperation = "source-in";
    octx.fillStyle = this._theme.focus;
    octx.fillRect(0, 0, canvas.width, canvas.height);
    if (this._rings.size >= 8) this._rings.delete(this._rings.keys().next().value);
    this._rings.set(key, { img: sprite.img, canvas });
    return canvas;
  }

  // The prompt over the focused target: the key that reaches it (on a
  // keyboard) in gold, then what pressing does, on the kit's nameplate. A
  // piece shorter than the character would put it on the character's own
  // nameplate, so there it rises above that nameplate instead.
  _drawFocusPrompt(ctx, focus, top, { showKeys = true, self = null } = {}) {
    if (!focus?.label) return;
    let anchor = top;
    if (!anchor) {
      const f = this.projection.footAnchor(focus.x, focus.y);
      const s = this.camera.worldToScreen(f.x, f.y);
      anchor = { x: Math.round(s.x), y: Math.round(s.y - FOCUS_PROMPT_LIFT * this.camera.scale) };
    }
    const key = showKeys ? FOCUS_KEYS[focus.key] : null;
    const keyText = key ? `${key} ` : "";
    this._uiFont(ctx, keyText + focus.label);
    const keyWidth = Math.round(ctx.measureText(keyText).width);
    const labelWidth = Math.round(ctx.measureText(focus.label).width);
    const width = keyWidth + labelWidth + NAMEPLATE_PAD_X * 2;
    const left = Math.round(anchor.x - width / 2);
    let plateTop = Math.round(anchor.y - NAMEPLATE_H - FOCUS_PROMPT_GAP);
    if (self?.nickname) {
      const { x: cx, headY } = this._avatarAnchor(self);
      const nameWidth = ctx.measureText(self.nickname).width + NAMEPLATE_PAD_X * 2;
      const nameTop = Math.round(headY - NAMEPLATE_H - 2);
      const across = left < cx + nameWidth / 2 && cx - nameWidth / 2 < left + width;
      const down = plateTop < nameTop + NAMEPLATE_H && nameTop < plateTop + NAMEPLATE_H;
      if (across && down) plateTop = nameTop - NAMEPLATE_H - FOCUS_PROMPT_GAP;
    }
    this._frame(ctx, "nameplate", left, plateTop, width, NAMEPLATE_H);
    const baseline = plateTop + NAMEPLATE_BASELINE;
    if (key) {
      ctx.fillStyle = this._theme.focus;
      ctx.fillText(keyText, left + NAMEPLATE_PAD_X, baseline);
    }
    ctx.fillStyle = this._theme.labelInk;
    ctx.fillText(focus.label, left + NAMEPLATE_PAD_X + keyWidth, baseline);
  }

  _drawBuildMarkers(ctx, construct) {
    if (!construct) return;
    if (construct.selected) {
      this._traceDiamond(ctx, construct.selected);
      ctx.save();
      ctx.lineWidth = 2;
      ctx.strokeStyle = HASH + BUILD_PICK;
      ctx.stroke();
      ctx.restore();
    }
    // A ghost covers one tile, or every tile of a floor being painted.
    const ghost = construct.ghost;
    if (ghost) {
      ctx.save();
      ctx.globalAlpha = 0.45;
      ctx.fillStyle = HASH + (ghost.valid ? BUILD_OK : BUILD_BAD);
      for (const tile of ghost.tiles ?? [ghost]) {
        this._traceDiamond(ctx, tile);
        ctx.fill();
      }
      ctx.restore();
    }
  }

  // The floor diamond of one tile, as the current path.
  _traceDiamond(ctx, { x, y }) {
    const f = this.projection.footAnchor(x, y);
    const c = this.camera.worldToScreen(f.x, f.y);
    const hw = this.projection.hw;
    const hh = this.projection.hh;
    ctx.beginPath();
    ctx.moveTo(Math.round(c.x), Math.round(c.y - hh));
    ctx.lineTo(Math.round(c.x + hw), Math.round(c.y));
    ctx.lineTo(Math.round(c.x), Math.round(c.y + hh));
    ctx.lineTo(Math.round(c.x - hw), Math.round(c.y));
    ctx.closePath();
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
  // they read as resting on the floor rather than floating — except a prop
  // that stands flush on it, a wall. Drawn once with a
  // shared alpha before the depth pass paints the sprites over them.
  _drawShadows(ctx, participants, now = 0) {
    const stand = this._standDecor();
    if (stand.length === 0 && participants.size === 0) return;
    const scale = this.camera.scale;
    ctx.save();
    ctx.globalAlpha = 0.26;
    ctx.fillStyle = HASH + SHADOW;
    // Props: a flat ellipse centred on the billboard's diamond foot (its base),
    // sized to the sprite width.
    for (const prop of stand) {
      // A wall stands flush on the floor (`shadow: false`).
      if (prop.shadow === false) continue;
      const sprite = this.atlas?.tile(prop.tile, now, seedAt(prop.x, prop.y));
      if (!sprite) continue;
      const f = this.projection.footAnchor(prop.x, prop.y);
      const { x, y } = this.camera.worldToScreen(f.x, f.y);
      this._ellipse(ctx, x, y, sprite.sw * scale * 0.3, this.tilePx * 0.16);
    }
    // Avatars: a contact ellipse under the feet (the diamond foot), so it sits
    // directly beneath the character whether standing or seated.
    for (const participant of participants.values()) {
      const { x, footY } = this._avatarAnchor(participant);
      this._ellipse(ctx, x, footY, this.tilePx * 0.3, this.tilePx * 0.15);
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

  // The map's floating labels: the End of Time's nameplate, a Construct
  // sign's line and a die's face, each a hologram over its piece.
  _drawMapLabels(ctx) {
    for (const label of this.map.labels ?? []) {
      if (label?.text && label.kind === "hologram") this._drawHologram(ctx, label);
    }
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

    this._uiFont(ctx, String(label.text));
    // A label can bring its own colours: a Construct sign is white on a dark
    // outline, readable over the white floor and the night sky alike.
    ctx.fillStyle = HASH + (label.glow ?? HOLO_GLOW);
    for (const [ox, oy] of [
      [-1, 0],
      [1, 0],
      [0, -1],
      [0, 1],
    ]) {
      this._centredText(ctx, String(label.text), cx + ox, ty + oy, maxWidth);
    }
    ctx.fillStyle = label.color ? HASH + label.color : this._theme.hologramInk;
    this._centredText(ctx, String(label.text), cx, ty, maxWidth);
  }

  _drawAvatar(ctx, participant, now) {
    const pose = this._avatarPose(participant, now);
    const sprite = this.atlas?.avatar(participant.avatar, pose.dir, pose.frame, pose.actionKind);
    if (!sprite) return;
    // Premium iso avatars ship oversized art; `sprite.scale` renders it to world size.
    const scale = this.avatarScale * (sprite.scale ?? 1);
    // Anchor the sprite's opaque FOOT row (not the padded frame bottom) on the
    // diamond, so the avatar stands on the ground instead of floating above it
    // by the frame's bottom padding (which varies 1–23px per avatar, and reads
    // worst on the seated sleep pose).
    const foot = this.atlas?.avatarBounds?.(participant.avatar)?.foot ?? sprite.sh;
    const f = this.projection.footAnchor(participant.x, participant.y);
    const s = this.camera.worldToScreen(f.x, f.y);
    const aw = sprite.sw * scale;
    const dx = Math.round(s.x - aw / 2);
    const lift = participant.pose === "sitting" ? SEAT_LIFT_PX * this.camera.scale : 0;
    const dy = Math.round(s.y - foot * scale - lift);
    this._blit(ctx, sprite, dx, dy, scale);

    // Flash of pain: the frame's silhouette blinks white for a beat on a hit.
    const action = participant.action;
    if (
      action &&
      (action.kind === "hit" || action.kind === "ko") &&
      now - action.startedAt < FX_FLASH_MS
    ) {
      this._blitFlash(ctx, sprite, dx, dy, scale);
    }
  }

  // Draw the sprite's opaque silhouette in white over the just-drawn frame.
  // The tint composes on a lazily-created offscreen canvas; environments
  // without a real 2D context (tests) skip the flash silently.
  _blitFlash(ctx, sprite, dx, dy, scale) {
    if (!sprite.img || typeof document === "undefined") return;
    if (!this._flashCanvas) {
      try {
        this._flashCanvas = document.createElement("canvas");
      } catch {
        return;
      }
    }
    const off = this._flashCanvas;
    const octx = off.getContext?.("2d");
    if (!octx) return;
    if (off.width < sprite.sw || off.height < sprite.sh) {
      off.width = sprite.sw;
      off.height = sprite.sh;
    }
    octx.clearRect(0, 0, off.width, off.height);
    octx.globalCompositeOperation = "source-over";
    octx.drawImage(
      sprite.img,
      sprite.sx,
      sprite.sy,
      sprite.sw,
      sprite.sh,
      0,
      0,
      sprite.sw,
      sprite.sh,
    );
    octx.globalCompositeOperation = "source-in";
    octx.fillStyle = HASH + LABEL_FG;
    octx.fillRect(0, 0, sprite.sw, sprite.sh);
    ctx.save();
    ctx.globalAlpha = 0.8;
    ctx.imageSmoothingEnabled = false;
    ctx.drawImage(off, 0, 0, sprite.sw, sprite.sh, dx, dy, sprite.sw * scale, sprite.sh * scale);
    ctx.restore();
  }

  // Screen anchor for a participant's avatar: the diamond foot (`footY`, where the
  // feet rest) and the head Y (`headY`, top of the opaque content) so shadows sit
  // under the feet and name/chat labels hang above the head — both scale-correct
  // regardless of the avatar's frame padding.
  _avatarAnchor(participant) {
    const spr = this.atlas?.avatar(participant.avatar, "south", 0, "idle");
    const scale = this.avatarScale * (spr?.scale ?? 1);
    const b = this.atlas?.avatarBounds?.(participant.avatar) ?? {
      top: 0,
      foot: spr?.sh ?? this.tilePx,
    };
    const f = this.projection.footAnchor(participant.x, participant.y);
    const s = this.camera.worldToScreen(f.x, f.y);
    return { x: s.x, footY: s.y, headY: s.y - (b.foot - b.top) * scale };
  }

  // Resolve a participant into an animation pose {actionKind, dir, frame}. Premium
  // 8-direction iso avatars face where they move and run a full state machine:
  // actions (ko/hit/getup/sword/wave) > down (KO'd, holds the fallen frame) >
  // sitting > dancing (loops) > walk (moving) > sleep (long idle) > idle (breathing).
  _avatarPose(participant, now) {
    const meta = this.atlas?.avatarMeta?.(participant.avatar) ?? {};
    const action = ISO_COMBAT_ACTIONS.has(participant.action?.kind) ? participant.action : null;
    const m = this._trackMotion(participant, now);
    if (action) {
      return {
        actionKind: action.kind,
        dir: m.dir8,
        frame: this._actionFrame(participant, action, now),
      };
    }
    if (participant.pose === "down") {
      const frames = this.atlas?.avatarFrameCount?.(participant.avatar, "ko") ?? 1;
      return { actionKind: "ko", dir: m.dir8, frame: frames - 1 };
    }
    const frames = (kind) => this.atlas?.avatarFrameCount?.(participant.avatar, kind) ?? 1;
    // Seated: settled in the chair (the clip's last frame), turned the way the
    // chair faces.
    if (participant.pose === "sitting") {
      const dir = SEAT_FACING[participant.dir] ?? m.dir8;
      if (meta.hasSit) return { actionKind: "sit", dir, frame: frames("sit") - 1 };
      if (meta.hasSleep) {
        return { actionKind: "sleep", dir, frame: Math.floor(now / 300) % frames("sleep") };
      }
      return { actionKind: meta.hasIdle ? "idle" : "walk", dir, frame: 0 };
    }
    if (participant.pose === "dancing" && meta.hasDance) {
      return {
        actionKind: "dance",
        dir: m.dir8,
        frame: Math.floor(now / DANCE_BEAT_MS) % frames("dance"),
      };
    }
    const still = now - m.t;
    if (still < 180) {
      return { actionKind: "walk", dir: m.dir8, frame: Math.floor(now / 120) % frames("walk") };
    }
    if (meta.hasSleep && still > ISO_SLEEP_MS) {
      return { actionKind: "sleep", dir: m.dir8, frame: Math.floor(now / 300) % frames("sleep") };
    }
    if (meta.hasIdle) {
      const kind = this._idleKind(participant, meta, now);
      return { actionKind: kind, dir: m.dir8, frame: Math.floor(now / 220) % frames(kind) };
    }
    return { actionKind: "walk", dir: m.dir8, frame: 0 };
  }

  // Register one set of layered effects per hit/ko action instance: a spark
  // (or knockout burst) plus a floating damage number — and, when the local
  // player is the one knocked out, a brief camera shake.
  _trackCombatFx(state, now) {
    for (const participant of state.participants.values()) {
      const action = participant.action;
      if (!action || (action.kind !== "hit" && action.kind !== "ko")) continue;
      const id = `${participant.key}:${action.startedAt}`;
      if (this._fxSeen.has(id)) continue;
      this._fxSeen.set(id, now);
      this._fx.push({
        key: participant.key,
        kind: action.kind,
        damage: action.damage ?? 0,
        startedAt: now,
      });
      if (action.kind === "ko" && participant.key === state.selfKey && !this._reducedMotion) {
        this._shakeAt = now;
      }
    }
    if (this._fxSeen.size > 64) {
      for (const [id, at] of this._fxSeen) {
        if (now - at > 5000) this._fxSeen.delete(id);
      }
    }
  }

  // The victim's own screen nudges once on a knockout: a small alternating
  // offset that decays over FX_SHAKE_MS. Spectators' cameras never move.
  _shakeOffset(now) {
    if (this._shakeAt === null) return null;
    const t = now - this._shakeAt;
    if (t >= FX_SHAKE_MS) {
      this._shakeAt = null;
      return null;
    }
    const falloff = 1 - t / FX_SHAKE_MS;
    const amp = FX_SHAKE_AMP_PX * falloff;
    const sign = Math.floor(t / 40) % 2 === 0 ? 1 : -1;
    return { x: Math.round(sign * amp), y: Math.round(-sign * amp * 0.5) };
  }

  _drawCombatSparks(ctx, participants, now) {
    this._fx = this._fx.filter((fx) => {
      const life = fx.kind === "ko" ? FX_BURST_MS : FX_SPARK_MS;
      const participant = participants.get(fx.key);
      if (!participant) return now - fx.startedAt < FX_NUMBER_MS;
      const elapsed = now - fx.startedAt;
      if (elapsed < life) {
        const name = fx.kind === "ko" ? "ko_burst" : "hit_spark";
        const frames = this.atlas?.fxFrameCount?.(name) ?? 0;
        const sprite = frames > 0 && this.atlas?.fx?.(name, (elapsed / life) * frames);
        if (sprite) {
          const anchor = this._avatarAnchor(participant);
          const cy = (anchor.footY + anchor.headY) / 2;
          const s = this.avatarScale;
          this._blit(
            ctx,
            sprite,
            Math.round(anchor.x - (sprite.sw * s) / 2),
            Math.round(cy - (sprite.sh * s) / 2),
            s,
          );
        }
      }
      return now - fx.startedAt < FX_NUMBER_MS;
    });
  }

  // Floating damage number: rises in an easing arc above the head and fades
  // out over its last stretch. KO numbers use the hotter tone.
  _drawDamageNumbers(ctx, participants, now) {
    for (const fx of this._fx) {
      if (fx.damage <= 0) continue;
      const participant = participants.get(fx.key);
      if (!participant) continue;
      const progress = Math.min((now - fx.startedAt) / FX_NUMBER_MS, 1);
      const anchor = this._avatarAnchor(participant);
      const rise = FX_NUMBER_RISE_PX * (1 - (1 - progress) * (1 - progress));
      const y = Math.round(anchor.headY - 18 - rise);
      ctx.save();
      this._uiFont(ctx, `-${fx.damage}`);
      ctx.globalAlpha = progress < 0.6 ? 1 : 1 - (progress - 0.6) / 0.4;
      ctx.fillStyle = this._theme.damageOutline;
      this._centredText(ctx, `-${fx.damage}`, anchor.x + 1, y + 1);
      ctx.fillStyle = fx.kind === "ko" ? this._theme.damageKo : this._theme.damage;
      this._centredText(ctx, `-${fx.damage}`, anchor.x, y);
      ctx.restore();
    }
  }

  // Which idle stance to show: avatars with a second idle block spend a slice
  // of each cycle on it, phase-offset by the participant key.
  _idleKind(participant, meta, now) {
    if (!meta.hasIdle2) return "idle";
    let seed = 0;
    const key = String(participant.key ?? "");
    for (let i = 0; i < key.length; i += 1) seed = (seed * 31 + key.charCodeAt(i)) >>> 0;
    const t = (now + (seed % ISO_IDLE_CYCLE_MS)) % ISO_IDLE_CYCLE_MS;
    return t < ISO_IDLE_CYCLE_MS * ISO_IDLE2_SHARE ? "idle2" : "idle";
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
    if (!isDrawable(img)) return;
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
    const { x: cx, headY } = this._avatarAnchor(participant);
    this._uiFont(ctx, participant.nickname);
    const width = Math.round(ctx.measureText(participant.nickname).width) + NAMEPLATE_PAD_X * 2;
    const top = Math.round(headY - NAMEPLATE_H - 2);

    this._frame(ctx, "nameplate", Math.round(cx - width / 2), top, width, NAMEPLATE_H);
    ctx.fillStyle = this._theme.labelInk;
    this._centredText(ctx, participant.nickname, cx, top + NAMEPLATE_BASELINE);
    this._drawHpBar(ctx, participant, cx, headY);
  }

  // A slim HP bar under the nameplate, only while the participant is hurt —
  // untouched avatars keep the clean social look.
  _drawHpBar(ctx, participant, cx, headY) {
    const hp = participant.hp ?? HP_MAX;
    if (hp >= HP_MAX) return;
    const frame = this.atlas?.uiPiece?.("hp");
    const fill = this.atlas?.uiPiece?.(hp > HP_MAX / 2 ? "hp_fill" : "hp_low_fill");
    if (!frame || !fill) return;
    const left = Math.round(cx - HP_BAR_W / 2);
    const top = Math.round(headY - 1);
    drawNineSlice(ctx, frame, left, top, HP_BAR_W, frame.h);
    const length = Math.round((HP_BAR_W - HP_BAR_INSET * 2) * (Math.max(hp, 0) / HP_MAX));
    // The fill is one column of pixels, repeated along the bar.
    drawNineSlice(
      ctx,
      { ...fill, t: 0, r: 0, b: 0, l: 0 },
      left + HP_BAR_INSET,
      top + HP_BAR_INSET,
      length,
      fill.h,
    );
  }

  // Speech bubble above the nickname label, wrapped to a few lines and growing
  // upwards so its bottom edge stays where a one-line bubble sits. The text is
  // drawn with fillText — canvas never interprets markup, so a message can
  // never inject HTML.
  _drawBubble(ctx, participant, text) {
    const { x: cx, headY } = this._avatarAnchor(participant);
    this._uiFont(ctx, text);
    const lines = wrapBubbleText(text, (s) => ctx.measureText(s).width);
    const widest = Math.max(...lines.map((line) => ctx.measureText(line).width));
    const width = Math.round(Math.min(widest + BUBBLE_PAD_X * 2, this.canvas.width - 4));
    const height = (lines.length - 1) * BUBBLE_LINE_PX + BUBBLE_FIRST_BASELINE + BUBBLE_PAD_Y;
    const tail = this.atlas?.uiPiece?.("tail");
    // The tail hangs from the frame's bottom outline, over the nameplate.
    const bottom = Math.round(headY - NAMEPLATE_H - 3 - (tail?.h ?? 0));
    const top = bottom - height;
    const left = Math.round(cx - width / 2);

    this._frame(ctx, "bubble", left, top, width, height);
    if (tail) drawPiece(ctx, tail, Math.round(cx - tail.w / 2), bottom - 1);
    ctx.fillStyle = this._theme.bubbleInk;
    lines.forEach((line, i) => {
      this._centredText(ctx, line, cx, top + BUBBLE_FIRST_BASELINE + i * BUBBLE_LINE_PX);
    });
  }
}

// Whether a sheet can be drawn yet: an <img> once it has decoded, a composed
// canvas or a decoded bitmap as soon as it exists.
export function isDrawable(img) {
  if (!img) return false;
  if ("complete" in img && "naturalWidth" in img) return Boolean(img.complete && img.naturalWidth);
  return (img.width ?? 0) > 0 && (img.height ?? 0) > 0;
}
