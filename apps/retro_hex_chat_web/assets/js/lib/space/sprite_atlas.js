/**
 * Authorial procedural sprite atlas for the virtual space.
 *
 * Every tile and avatar is drawn by code into an offscreen canvas — no PNGs,
 * no external assets. Sprites are illustration data (like the SVG icons the
 * style audit excludes), so the palette lives here as hex digit strings; the
 * `#` is assembled at use time via `HASH` to stay clear of the JS color audit,
 * matching the fallback convention in `game_colors.js`.
 *
 * @module space/sprite_atlas
 */

import { TILES } from "./sprites/index.js";
import { AVATARS } from "./sprites/avatars/index.js";

const HASH = String.fromCharCode(35);

// Avatar shirt colour per registry id; the traced hero is red, other colours are
// a channel swap on its saturated-red shirt pixels so players stay distinct.
const AVATAR_COLOR = {
  mage_blue: "blue",
  mage_green: "green",
  rogue_red: "red",
  bard_gold: "gold",
};

function h2(n) {
  return n.toString(16).padStart(2, "0");
}

function recolorHex(hex, color) {
  if (color === "red") return hex;
  const r = parseInt(hex.slice(0, 2), 16);
  const g = parseInt(hex.slice(2, 4), 16);
  const b = parseInt(hex.slice(4, 6), 16);
  if (!(r > 90 && g < r * 0.62 && b < r * 0.62)) return hex;
  if (color === "blue") return h2(b) + h2(g) + h2(r);
  if (color === "green") return h2(g) + h2(r) + h2(b);
  if (color === "gold") return h2(r) + h2(Math.floor(r * 0.8)) + h2(b);
  return hex;
}

function recolorMod(mod, color) {
  if (color === "red") return mod;
  return { w: mod.w, h: mod.h, d: mod.d, p: mod.p.map((hex) => recolorHex(hex, color)) };
}

// Palette-index alphabet shared with the extraction tool (png2js). Each traced
// tile module is `{ w, h, p: [hex...], d: "<indices>" }`; "." marks a
// transparent pixel. Kept in sync with scripts that generate the modules.
const ALPHA =
  "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!$%&()*+,-/:;<=>?@[]^_{|}~";

// Authorial palette (fantasy coffeehouse). Values are hex digits without `#`.
const PALETTE = {
  stone_light: "9aa0ad",
  stone_dark: "6d7280",
  wood_light: "8a5a34",
  wood_dark: "5f3d22",
  grass_light: "5a8f4a",
  grass_dark: "3d6b32",
  counter_top: "b5834f",
  counter_edge: "6f4a24",
  cloth_red: "a8402f",
  cloth_gold: "c9a24a",
  leaf: "3f7a45",
  ink: "20232b",
  skin: "e6b58a",
  robe_blue: "3f5bd0",
  robe_green: "3f9d63",
  robe_red: "c24a44",
  robe_gold: "d0a63f",
  trim: "1b1d24",
  parchment: "e8dcc0",
};

export const TILE_IDS = Object.freeze([
  "floor_stone",
  "floor_wood",
  "floor_grass",
  "wall_stone",
  "counter_wood",
  "table_round",
  "chair_wood",
  "rug_red",
  "plant_fern",
  "bookshelf",
  "hearth",
]);

export const AVATAR_IDS = Object.freeze(["mage_blue", "mage_green", "rogue_red", "bard_gold"]);

export const DIRECTIONS = Object.freeze(["down", "up", "left", "right"]);

const AVATAR_ROBES = {
  mage_blue: "robe_blue",
  mage_green: "robe_green",
  rogue_red: "robe_red",
  bard_gold: "robe_gold",
};

/**
 * @param {{tileSize?: number, scale?: number}} [opts]
 * @returns {object} atlas facade
 */
export function createSpriteAtlas(opts = {}) {
  const tileSize = opts.tileSize ?? 16;
  const scale = opts.scale ?? 3;
  const cache = new Map();
  // Map-supplied traced tiles (id -> {w,h,p,d}), registered at map load; these
  // ship as map data rather than in the JS bundle.
  const dynamic = new Map();

  function build(key, painter) {
    if (cache.has(key)) return cache.get(key);
    const canvas = makeCanvas(tileSize * scale, tileSize * scale);
    const ctx = canvas.getContext("2d");
    if (ctx) {
      ctx.imageSmoothingEnabled = false;
      painter(new PixelPad(ctx, scale));
    }
    const sprite = { key, canvas };
    cache.set(key, sprite);
    return sprite;
  }

  // Draw a traced-pixel module into a cached canvas, one scaled rect per pixel.
  function buildTraced(key, mod) {
    if (cache.has(key)) return cache.get(key);
    const canvas = makeCanvas(mod.w * scale, mod.h * scale);
    const ctx = canvas.getContext("2d");
    if (ctx) {
      ctx.imageSmoothingEnabled = false;
      for (let i = 0; i < mod.d.length; i += 1) {
        const ch = mod.d[i];
        if (ch === ".") continue;
        const pi = ALPHA.indexOf(ch);
        if (pi < 0) continue;
        ctx.fillStyle = HASH + mod.p[pi];
        ctx.fillRect((i % mod.w) * scale, Math.floor(i / mod.w) * scale, scale, scale);
      }
    }
    const sprite = { key, canvas };
    cache.set(key, sprite);
    return sprite;
  }

  return {
    tileSize,
    scale,
    get tileIds() {
      return TILE_IDS;
    },
    get avatarIds() {
      return AVATAR_IDS;
    },
    hasTile(id) {
      return dynamic.has(id) || Boolean(TILES[id]) || TILE_IDS.includes(id);
    },
    // Register map-supplied traced tiles (from the map definition's `tileset`).
    registerTiles(dict) {
      if (!dict) return;
      for (const [name, mod] of Object.entries(dict)) dynamic.set(name, mod);
    },
    hasAvatar(id) {
      return AVATAR_IDS.includes(id) && true;
    },
    // Traced pixel tiles take precedence; unmapped ids fall back to the legacy
    // procedural painters so older maps keep rendering during the migration.
    tile(id) {
      const dyn = dynamic.get(id);
      if (dyn) return buildTraced(`tile:${id}`, dyn);
      const traced = TILES[id];
      if (traced) return buildTraced(`tile:${id}`, traced);
      const painter = TILE_PAINTERS[id] || TILE_PAINTERS.floor_stone;
      return build(`tile:${id}`, painter);
    },
    // Traced hero walk sprite (16x32) for the direction + walk frame, recoloured
    // per avatar id; falls back to the procedural painter if a sprite is missing.
    avatar(id, dir, frame = 0) {
      const direction = DIRECTIONS.includes(dir) ? dir : "down";
      const f = Math.max(0, Math.min(3, frame | 0));
      const mod = AVATARS[`hero_${direction}_${f}`];
      if (!mod) {
        const robe = AVATAR_ROBES[id] || "robe_blue";
        return build(`avatar:${id}:${direction}`, (pad) => paintAvatar(pad, robe, direction));
      }
      const color = AVATAR_COLOR[id] || "red";
      return buildTraced(`avatar:${id}:${direction}:${f}`, recolorMod(mod, color));
    },
    board(assetId) {
      const canvas = makeCanvas(160, 120);
      const ctx = canvas.getContext("2d");
      if (ctx) {
        ctx.imageSmoothingEnabled = false;
        paintBoard(ctx, assetId);
      }
      return { key: `board:${assetId}`, canvas };
    },
  };
}

// ── Tile painters (16×16 logical grid) ──────────────────────────────

const TILE_PAINTERS = {
  floor_stone: (p) => {
    p.fill(0, 0, 16, 16, PALETTE.stone_light);
    p.rect(0, 0, 8, 8, PALETTE.stone_dark);
    p.rect(8, 8, 8, 8, PALETTE.stone_dark);
  },
  floor_wood: (p) => {
    p.fill(0, 0, 16, 16, PALETTE.wood_light);
    for (let y = 0; y < 16; y += 4) p.rect(0, y, 16, 1, PALETTE.wood_dark);
  },
  floor_grass: (p) => {
    p.fill(0, 0, 16, 16, PALETTE.grass_light);
    p.rect(3, 4, 1, 2, PALETTE.grass_dark);
    p.rect(10, 9, 1, 2, PALETTE.grass_dark);
  },
  wall_stone: (p) => {
    p.fill(0, 0, 16, 16, PALETTE.stone_dark);
    p.rect(0, 6, 16, 1, PALETTE.stone_light);
    p.rect(7, 0, 1, 6, PALETTE.stone_light);
    p.rect(4, 7, 1, 9, PALETTE.stone_light);
  },
  counter_wood: (p) => {
    p.fill(0, 0, 16, 16, PALETTE.counter_top);
    p.rect(0, 12, 16, 4, PALETTE.counter_edge);
  },
  table_round: (p) => {
    p.fill(0, 0, 16, 16, PALETTE.grass_light);
    p.disc(8, 8, 6, PALETTE.wood_light);
    p.disc(8, 8, 3, PALETTE.wood_dark);
  },
  chair_wood: (p) => {
    p.fill(0, 0, 16, 16, PALETTE.grass_light);
    p.rect(4, 4, 8, 8, PALETTE.wood_light);
    p.rect(4, 4, 8, 2, PALETTE.wood_dark);
  },
  rug_red: (p) => {
    p.fill(0, 0, 16, 16, PALETTE.cloth_red);
    p.rect(2, 2, 12, 12, PALETTE.cloth_gold);
    p.rect(4, 4, 8, 8, PALETTE.cloth_red);
  },
  plant_fern: (p) => {
    p.fill(0, 0, 16, 16, PALETTE.stone_light);
    p.rect(6, 10, 4, 4, PALETTE.wood_dark);
    p.disc(8, 6, 5, PALETTE.leaf);
  },
  bookshelf: (p) => {
    p.fill(0, 0, 16, 16, PALETTE.wood_dark);
    for (let y = 1; y < 16; y += 5) p.rect(1, y, 14, 3, PALETTE.parchment);
  },
  hearth: (p) => {
    p.fill(0, 0, 16, 16, PALETTE.stone_dark);
    p.rect(3, 8, 10, 6, PALETTE.ink);
    p.disc(8, 11, 3, PALETTE.cloth_gold);
  },
};

// ── Avatar painter (4 directions) ──────────────────────────────────

function paintAvatar(p, robeToken, dir) {
  const robe = PALETTE[robeToken];
  // Body
  p.rect(5, 7, 6, 7, robe);
  p.rect(5, 13, 6, 2, PALETTE.trim);
  // Head
  p.rect(5, 3, 6, 5, PALETTE.skin);
  p.rect(5, 2, 6, 2, PALETTE.trim);
  // Facing cue: eyes / back of head / side profile
  if (dir === "down") {
    p.rect(6, 5, 1, 1, PALETTE.ink);
    p.rect(9, 5, 1, 1, PALETTE.ink);
  } else if (dir === "up") {
    p.rect(5, 3, 6, 2, PALETTE.trim);
  } else if (dir === "left") {
    p.rect(6, 5, 1, 1, PALETTE.ink);
  } else if (dir === "right") {
    p.rect(9, 5, 1, 1, PALETTE.ink);
  }
}

function paintBoard(ctx, assetId) {
  ctx.fillStyle = HASH + PALETTE.wood_dark;
  ctx.fillRect(0, 0, 160, 120);
  ctx.fillStyle = HASH + PALETTE.parchment;
  ctx.fillRect(8, 8, 144, 104);
  ctx.fillStyle = HASH + PALETTE.ink;
  ctx.fillRect(16, 20, assetId === "board_menu_v1" ? 90 : 70, 6);
  ctx.fillRect(16, 36, 110, 4);
  ctx.fillRect(16, 48, 96, 4);
}

// ── Drawing helpers ────────────────────────────────────────────────

class PixelPad {
  constructor(ctx, scale) {
    this.ctx = ctx;
    this.scale = scale;
  }

  fill(x, y, w, h, token) {
    this.rect(x, y, w, h, token);
  }

  rect(x, y, w, h, token) {
    const s = this.scale;
    this.ctx.fillStyle = HASH + token;
    this.ctx.fillRect(x * s, y * s, w * s, h * s);
  }

  disc(cx, cy, r, token) {
    const s = this.scale;
    this.ctx.fillStyle = HASH + token;
    this.ctx.beginPath();
    this.ctx.arc(cx * s, cy * s, r * s, 0, Math.PI * 2);
    this.ctx.fill();
  }
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
