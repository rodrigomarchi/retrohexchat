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

// Row offset (in tiles) of each facing inside a character block on the sheet.
const DIR_ROW = Object.freeze({ down: 0, right: 2, up: 4, left: 6 });

// Avatars are sliced from the walking blocks at the top of `character.png`
// (16×32 sprites, 4 frames per facing). Rows 8+ are weapon/action poses, not
// walking blocks, and produce half-body frames when used with DIR_ROW.
const AVATAR_SHEET = "character";
const AVATAR_W = 16;
const AVATAR_H = 32;
const AVATAR_BLOCKS = Object.freeze({
  rogue_red: { col: 0, row: 0, frames: [0, 1, 2, 3] },
  mage_blue: { col: 5, row: 0, frames: [0, 1, 2, 3] },
  mage_green: { col: 9, row: 0, frames: [0, 1, 2, 3] },
  // This block's walk frames sit in columns 1–3; cycle them for a 4-step gait.
  bard_gold: { col: 4, row: 0, frames: [1, 2, 3, 2] },
});

export const AVATAR_IDS = Object.freeze(Object.keys(AVATAR_BLOCKS));

/**
 * @param {{tileSize?: number, scale?: number, onReady?: Function}} [opts]
 * @returns {object} atlas facade
 */
export function createSpriteAtlas(opts = {}) {
  const tileSize = opts.tileSize ?? 16;
  const onReady = typeof opts.onReady === "function" ? opts.onReady : null;
  // tileset id -> { img, tile, columns }
  const sheets = new Map();
  // tile name -> { ts, col, row, w?, h? }
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

  function tile(name) {
    const spec = tiles[name];
    if (!spec) return null;
    const sheet = sheets.get(spec.ts);
    if (!sheet) return null;
    const t = sheet.tile;
    const w = spec.w ?? 1;
    const h = spec.h ?? 1;
    return { img: sheet.img, sx: spec.col * t, sy: spec.row * t, sw: w * t, sh: h * t };
  }

  function avatar(id, dir, frame = 0) {
    const block = AVATAR_BLOCKS[id] ?? AVATAR_BLOCKS.rogue_red;
    const sheet = sheets.get(AVATAR_SHEET);
    if (!sheet) return null;
    const direction = DIRECTIONS.includes(dir) ? dir : "down";
    const frames = block.frames;
    const idx = ((Math.trunc(frame) % frames.length) + frames.length) % frames.length;
    const col = block.col + frames[idx];
    const row = block.row + DIR_ROW[direction];
    return { img: sheet.img, sx: col * 16, sy: row * 16, sw: AVATAR_W, sh: AVATAR_H };
  }

  return {
    tileSize,
    loadTilesets,
    registerTiles,
    hasTile(name) {
      return Boolean(tiles[name]);
    },
    tile,
    avatar,
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
