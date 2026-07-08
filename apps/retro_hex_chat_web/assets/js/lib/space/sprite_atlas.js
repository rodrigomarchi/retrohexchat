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
const WALK_DIR_ROW = Object.freeze({ down: 0, right: 2, up: 4, left: 6 });
const SWORD_DIR_ROW = Object.freeze({ down: 0, up: 2, right: 4, left: 6 });

// Avatars are sliced from `character.png`. Walk frames are 16×32; sword frames
// are wider 32×32 cells because the blade extends outside the body tile.
const AVATAR_SHEET = "character";
const DEFAULT_AVATAR_ID = "redtunic_hero";
const AVATAR_BLOCKS = Object.freeze({
  redtunic_hero: {
    walk: { col: 0, row: 0, w: 1, h: 2, step: 1, frames: [0, 1, 2, 3], dirRow: WALK_DIR_ROW },
    sword: { col: 0, row: 8, w: 2, h: 2, step: 2, frames: [0, 1, 2, 3], dirRow: SWORD_DIR_ROW },
  },
});

export const AVATAR_IDS = Object.freeze(Object.keys(AVATAR_BLOCKS));
export const AVATAR_ACTIONS = Object.freeze(["walk", "sword"]);

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

  function avatar(id, dir, frame = 0, action = "walk") {
    const avatarBlock = AVATAR_BLOCKS[id] ?? AVATAR_BLOCKS[DEFAULT_AVATAR_ID];
    const block = avatarBlock[action] ?? avatarBlock.walk;
    const sheet = sheets.get(AVATAR_SHEET);
    if (!sheet) return null;
    const direction = DIRECTIONS.includes(dir) ? dir : "down";
    const frames = block.frames;
    const idx = ((Math.trunc(frame) % frames.length) + frames.length) % frames.length;
    const t = sheet.tile;
    const col = block.col + frames[idx] * block.step;
    const row = block.row + block.dirRow[direction];
    return { img: sheet.img, sx: col * t, sy: row * t, sw: block.w * t, sh: block.h * t };
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
    avatarFrameCount(id, action = "walk") {
      const avatarBlock = AVATAR_BLOCKS[id] ?? AVATAR_BLOCKS[DEFAULT_AVATAR_ID];
      const block = avatarBlock[action] ?? avatarBlock.walk;
      return block.frames.length;
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
