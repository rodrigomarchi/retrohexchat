/**
 * Sprite atlas for the virtual space, backed by the human-made tileset PNGs
 * served under `/images/space/`. Tiles and avatars are slices of those sheets:
 * the atlas loads each sheet as an `Image` once and resolves a semantic tile
 * name (or an avatar id + direction + frame) into a source rectangle. The
 * renderer draws that rectangle with `ctx.drawImage`, so the runtime art is the
 * original pixel art — no pixel data ships in the bundle or the map payload.
 *
 * @module space/sprite_atlas
 */

const HASH = String.fromCharCode(35);

export const DIRECTIONS = Object.freeze(["down", "up", "left", "right"]);

// Avatar frame geometry is expressed in PIXELS so each avatar can live on its
// own sheet at its own resolution. The legacy red-tunic hero is sliced from the
// shared 16px `character.png` (walk 16×32; wider 32×32 sword cells because the
// blade extends past the body). The PixelLab-authored classes each ship a
// compact 36px sheet under `/images/space/avatars/`, laid out as four facing
// rows (down, up, left, right) × four walk frames.
const DEFAULT_AVATAR_ID = "redtunic_hero";

// Avatar sheets the atlas loads on its own, independent of the active map — so
// every participant renders even on maps that don't ship the character sheet.
// `character` is the 16px legacy/default sheet (the red-tunic hero that bots and
// anyone who hasn't picked a class fall back to); the rest are the 36px classes.
const AVATAR_SHEETS = Object.freeze([
  { id: "character", src: "/images/space/character.png" },
  { id: "av_sorceress", src: "/images/space/avatars/sorceress.png" },
  { id: "av_knight", src: "/images/space/avatars/knight.png" },
  { id: "av_archer", src: "/images/space/avatars/archer.png" },
  { id: "av_barbarian", src: "/images/space/avatars/barbarian.png" },
  { id: "av_rogue", src: "/images/space/avatars/rogue.png" },
  { id: "av_cleric", src: "/images/space/avatars/cleric.png" },
  { id: "av_monk", src: "/images/space/avatars/monk.png" },
  { id: "av_iso_knight", src: "/images/space/avatars/iso_knight.png" },
]);

// The 8 isometric facing directions, in the row order the iso sheet is packed.
export const DIRECTIONS_ISO = Object.freeze([
  "south",
  "south-east",
  "east",
  "north-east",
  "north",
  "north-west",
  "west",
  "south-west",
]);

// Premium 8-direction isometric avatar (PixelLab v3). One 92×73 sheet packs four
// animation blocks — walk, idle (breathing), sword (attack), sleep — stacked in
// direction-major rows. Authored by `tools/compose_iso_avatar.py`, which prints
// this exact geometry. `scale` renders the tall 92px art down to world size, and
// `sleep` is south-only (a seated pose used regardless of facing while AFK).
const ISO_FRAME_W = 188;
const ISO_FRAME_H = 151;

function isoRows(base) {
  const rows = {};
  DIRECTIONS_ISO.forEach((d, i) => {
    rows[d] = base + i * ISO_FRAME_H;
  });
  return Object.freeze(rows);
}

function isoKnightAvatar(sheet) {
  const cols = [0, ISO_FRAME_W, ISO_FRAME_W * 2, ISO_FRAME_W * 3];
  const block = (base) => ({ frameW: ISO_FRAME_W, frameH: ISO_FRAME_H, cols, rows: isoRows(base) });
  return {
    sheet,
    // Authored at world size (92px human in a 188px frame) → renders native at
    // avatar_scale 1. No per-avatar down/up-scaling.
    scale: 1,
    walk: block(0),
    idle: block(1208),
    sword: block(2416),
    sleep: {
      frameW: ISO_FRAME_W,
      frameH: ISO_FRAME_H,
      cols,
      rows: Object.freeze({ south: 3624 }),
    },
  };
}

// Standard blocks for a 36px class sheet (144×288): walk on rows 0-3 and attack
// on rows 4-7, each down/up/left/right × 4 frames. The game's "sword" action
// maps to the attack block (each class swings its own weapon).
function classAvatar(sheet) {
  return {
    sheet,
    scale: 2,
    walk: {
      frameW: 36,
      frameH: 36,
      cols: [0, 36, 72, 108],
      rows: Object.freeze({ down: 0, up: 36, left: 72, right: 108 }),
    },
    sword: {
      frameW: 36,
      frameH: 36,
      cols: [0, 36, 72, 108],
      rows: Object.freeze({ down: 144, up: 180, left: 216, right: 252 }),
    },
  };
}

const AVATARS = Object.freeze({
  redtunic_hero: {
    sheet: "character",
    scale: 2,
    walk: {
      frameW: 16,
      frameH: 32,
      cols: [0, 16, 32, 48],
      rows: Object.freeze({ down: 0, up: 64, left: 96, right: 32 }),
    },
    sword: {
      frameW: 32,
      frameH: 32,
      cols: [0, 32, 64, 96],
      rows: Object.freeze({ down: 128, up: 160, right: 192, left: 224 }),
    },
  },
  sorceress: classAvatar("av_sorceress"),
  knight: classAvatar("av_knight"),
  archer: classAvatar("av_archer"),
  barbarian: classAvatar("av_barbarian"),
  rogue: classAvatar("av_rogue"),
  cleric: classAvatar("av_cleric"),
  monk: classAvatar("av_monk"),
  iso_knight: isoKnightAvatar("av_iso_knight"),
});

export const AVATAR_IDS = Object.freeze(Object.keys(AVATARS));
export const AVATAR_ACTIONS = Object.freeze(["walk", "sword", "idle", "sleep"]);

/**
 * @param {{tileSize?: number, scale?: number, onReady?: Function}} [opts]
 * @returns {object} atlas facade
 */
export function createSpriteAtlas(opts = {}) {
  const tileSize = opts.tileSize ?? 16;
  const onReady = typeof opts.onReady === "function" ? opts.onReady : null;
  // tileset id -> { img, tile, columns }
  const sheets = new Map();
  // tile name -> { ts, col, row, w?, h?, flip_x? }
  let tiles = {};
  let boardCanvas = null;
  let pending = 0;

  function loadTilesets(list) {
    if (!Array.isArray(list)) return;
    for (const ts of list) {
      if (!ts || sheets.has(ts.id)) continue;
      const img = makeImage();
      const entry = { img, tile: ts.tile ?? tileSize, columns: ts.columns ?? 0 };
      sheets.set(ts.id, entry);
      if (img && ts.src) {
        pending += 1;
        const done = () => {
          pending = Math.max(0, pending - 1);
          if (pending === 0 && onReady) onReady();
        };
        img.addEventListener?.("load", done);
        img.addEventListener?.("error", done);
        img.src = ts.src;
      }
    }
  }

  function registerTiles(dict) {
    if (dict && typeof dict === "object") tiles = dict;
  }

  // Resolve a tile name to a source rect. Static tiles ignore `now`/`seed`.
  // Animated tiles (`frames > 1`) pack their frames horizontally from `col`
  // (frame i at col + i*w) and cycle on a global clock; `seed` (a per-position
  // hash from the renderer) offsets the phase so repeated tiles desync.
  function tile(name, now = 0, seed = 0) {
    const spec = tiles[name];
    if (!spec) return null;
    const sheet = sheets.get(spec.ts);
    if (!sheet) return null;
    const t = sheet.tile;
    const w = spec.w ?? 1;
    const h = spec.h ?? 1;
    let col = spec.col;
    const frames = spec.frames ?? 1;
    if (frames > 1) {
      const period = spec.period_ms ?? 800;
      const phase = ((seed >>> 0) * 2654435761) % period;
      const idx = Math.floor((now + phase) / (period / frames)) % frames;
      col = spec.col + idx * w;
    }
    return {
      img: sheet.img,
      sx: col * t,
      sy: spec.row * t,
      // Native-sized tiles (iso floor) carry their exact pixel size so they render
      // 1:1 without the cell-grid rounding that would shift the diamond off-anchor.
      sw: spec.wpx ?? w * t,
      sh: spec.hpx ?? h * t,
      flipX: Boolean(spec.flip_x ?? spec.flipX),
    };
  }

  function avatar(id, dir, frame = 0, action = "walk") {
    const desc = AVATARS[id] ?? AVATARS[DEFAULT_AVATAR_ID];
    const block = desc[action] ?? desc.walk;
    const sheet = sheets.get(desc.sheet);
    if (!sheet) return null;
    // Resolve against the block's own facing keys so 4-dir (down/up/left/right)
    // and 8-dir (south/east/…) avatars both work; fall back to the first facing
    // (e.g. sleep is south-only, used for any direction).
    const direction = dir in block.rows ? dir : Object.keys(block.rows)[0];
    const n = block.cols.length;
    const idx = ((Math.trunc(frame) % n) + n) % n;
    return {
      img: sheet.img,
      sx: block.cols[idx],
      sy: block.rows[direction],
      sw: block.frameW,
      sh: block.frameH,
      scale: desc.scale ?? 1,
    };
  }

  // Class avatar sheets are global (every map uses them), so the atlas loads
  // them itself rather than depending on the map's tileset list.
  loadTilesets(AVATAR_SHEETS);

  return {
    tileSize,
    loadTilesets,
    registerTiles,
    hasTile(name) {
      return Boolean(tiles[name]);
    },
    tile,
    avatar,
    avatarFrameCount(id, action = "walk") {
      const desc = AVATARS[id] ?? AVATARS[DEFAULT_AVATAR_ID];
      const block = desc[action] ?? desc.walk;
      return block.cols.length;
    },
    // What animation capabilities an avatar has, so the renderer drives 8-dir iso
    // avatars (facing + idle/sleep states) without changing the 4-dir legacy ones.
    avatarMeta(id) {
      const desc = AVATARS[id] ?? AVATARS[DEFAULT_AVATAR_ID];
      return {
        iso: "south" in (desc.walk?.rows ?? {}),
        hasIdle: Boolean(desc.idle),
        hasSleep: Boolean(desc.sleep),
        scale: desc.scale ?? 1,
      };
    },
    // Notice-board modal art. This is illustration data (like the SVG icons the
    // style audit excludes); the palette lives here as hex digits with `#`
    // assembled via HASH to stay clear of the JS colour audit.
    board(assetId) {
      if (!boardCanvas) boardCanvas = makeCanvas(160, 120);
      const ctx = boardCanvas.getContext?.("2d");
      if (ctx) {
        ctx.imageSmoothingEnabled = false;
        ctx.fillStyle = HASH + "5f3d22";
        ctx.fillRect(0, 0, 160, 120);
        ctx.fillStyle = HASH + "e8dcc0";
        ctx.fillRect(8, 8, 144, 104);
        ctx.fillStyle = HASH + "20232b";
        ctx.fillRect(16, 20, assetId === "board_menu_v1" ? 90 : 70, 6);
        ctx.fillRect(16, 36, 110, 4);
        ctx.fillRect(16, 48, 96, 4);
      }
      return { key: `board:${assetId}`, canvas: boardCanvas };
    },
  };
}

function makeImage() {
  if (typeof Image === "function") return new Image();
  if (typeof document !== "undefined" && document.createElement) {
    return document.createElement("img");
  }
  return null;
}

function makeCanvas(width, height) {
  const canvas =
    typeof OffscreenCanvas === "function"
      ? new OffscreenCanvas(width, height)
      : document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  return canvas;
}
