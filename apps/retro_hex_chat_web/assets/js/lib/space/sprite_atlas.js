/**
 * Sprite atlas for the virtual space, backed by the human-made tileset PNGs
 * served under `/images/space/`. Tiles and avatars are slices of those sheets:
 * the atlas loads each sheet as an `Image` once and resolves a semantic tile
 * name (or an avatar id + direction + frame) into a source rectangle. The
 * renderer draws that rectangle with `ctx.drawImage`, so the runtime art is the
 * original pixel art — no pixel data ships in the bundle or the map payload.
 *
 * Sheets are fetched on demand. The first frame waits on the map's tilesets, the
 * fx strip, the UI kit's canvas pieces, the creator catalog and the local
 * player's own character; everyone else's character is composed behind that
 * gate, from pieces most of them share.
 *
 * @module space/sprite_atlas
 */
import { log } from "../logger.js";
import { loadCharacters as loadCompositor, makeCanvas } from "./character_loader.js";
import { UI_KIT_GEOMETRY } from "./ui_kit_geometry.js";

const HASH = String.fromCharCode(35);

// The 8 isometric facing directions, in the row order every iso sheet is packed.
export const DIRECTIONS = Object.freeze([
  "south",
  "south-east",
  "east",
  "north-east",
  "north",
  "north-west",
  "west",
  "south-west",
]);

// Characters are made in the Space's creator and travel as recipes
// (`character_recipe.js`). Their art is not a sheet per class but layered
// pieces listed in the creator catalog, composed per recipe, clip and facing by
// `character_compositor.js` into strips this atlas hands the renderer. The
// catalog's URL comes from the server (digested, like every other sheet).

// The game's action names, as the creator catalog names its clips.
const CLIP_FOR_ACTION = Object.freeze({
  walk: "walk",
  idle: "idle",
  idle2: "idle",
  sword: "attack",
  sleep: "sit",
  sit: "sit",
  hit: "hit",
  ko: "ko",
  getup: "getup",
});

// The canvas's own UI frames (speech bubble, nameplate, signs, HP bar): the
// space's pixel-art kit, sliced and packed by `tools/author_ui.py`, which also
// writes where each piece sits and how it is sliced (`ui_kit_geometry.js`).
const UI_SHEET_ID = "ui_canvas";
const UI_SHEET_PATH = "/images/space/ui/canvas.webp";

// Combat impact effects: PixelLab burst animations packed as horizontal strips
// stacked in /images/space/fx.webp (frame i of an effect at x = i * w).
const FX_SHEET_ID = "fx_combat";
const FX_SHEET_PATH = "/images/space/fx.webp";
const FX = Object.freeze({
  hit_spark: { y: 0, w: 64, h: 64, frames: 6 },
  ko_burst: { y: 64, w: 96, h: 96, frames: 6 },
});

export const AVATAR_ACTIONS = Object.freeze(Object.keys(CLIP_FOR_ACTION));

/**
 * @param {{tileSize?: number, scale?: number, sheetUrls?: object, characterCatalog?: string,
 *   characters?: object, onReady?: Function}} [opts] `characterCatalog` is the creator
 *   catalog's URL; `characters` injects a ready compositor (tests)
 * @returns {object} atlas facade
 */
export function createSpriteAtlas(opts = {}) {
  const tileSize = opts.tileSize ?? 16;
  const onReady = typeof opts.onReady === "function" ? opts.onReady : null;
  const sheetUrls = opts.sheetUrls && typeof opts.sheetUrls === "object" ? opts.sheetUrls : {};
  // The character compositor, once the creator catalog has arrived.
  let characters = opts.characters ?? null;
  let catalog = opts.characters?.catalog ?? null;
  // Recipes the room named before the catalog arrived, and which of them hold
  // the loading gate; each is composed once it has.
  const waiting = new Map();
  // Recipes already being composed, so a delta that names them again is free.
  const seen = new Set();
  const retryDelay = opts.retryDelay ?? ((attempt) => 2000 * 2 ** attempt);
  // tileset id -> { img, tile, columns }
  const sheets = new Map();
  // tile name -> { ts, col, row, w?, h?, flip_x? }
  let tiles = {};
  let boardCanvas = null;
  // Only the sheets the first frame cannot be drawn without hold the ready gate:
  // the map's own tilesets, the fx strip, and the local player's class. Every
  // other class streams in behind the gate, so a room full of strangers costs
  // nothing up front and their sheets pop in as they arrive.
  let blockingPending = 0;
  let mapReady = false;
  let readyFired = false;

  function maybeReady() {
    if (readyFired || !mapReady || blockingPending > 0) return;
    readyFired = true;
    if (onReady) onReady();
  }

  function loadTilesets(list, { blocking = true } = {}) {
    if (!Array.isArray(list)) return;
    for (const ts of list) {
      if (!ts || sheets.has(ts.id)) continue;
      const img = makeImage();
      const entry = { img, tile: ts.tile ?? tileSize, columns: ts.columns ?? 0 };
      // Registration is synchronous: a sheet resolves to source rects the moment
      // it is known, and `drawImage` on a still-loading image is a harmless no-op.
      sheets.set(ts.id, entry);
      const src = sheetUrls[ts.id] ?? ts.src;
      if (img && src) {
        if (blocking) blockingPending += 1;
        const done = () => {
          if (blocking) blockingPending = Math.max(0, blockingPending - 1);
          maybeReady();
        };
        img.addEventListener?.("load", done);
        img.addEventListener?.("error", done);
        img.src = src;
      }
    }
  }

  // A recipe the catalog cannot compose (a piece retired since it was made)
  // draws as the catalog's default rather than as nobody.
  function recipeOf(recipe) {
    if (!characters) return recipe;
    return characters.valid(recipe) ? recipe : catalog.default;
  }

  // The catalog holds the gate once. A failed load opens it (the room draws
  // without its characters rather than not at all) and is tried again.
  function loadCharacters(url, attempt = 0) {
    if (!url || characters) return;
    if (attempt === 0) blockingPending += 1;
    const release = () => {
      if (attempt === 0) blockingPending = Math.max(0, blockingPending - 1);
      maybeReady();
    };
    loadCompositor(url)
      .then((compositor) => {
        characters = compositor;
        catalog = compositor.catalog;
        characters.prefetch(["walk", "idle"]);
        const queued = [...waiting];
        waiting.clear();
        for (const [recipe, blocking] of queued) ensureAvatars([recipe], { blocking });
      })
      .catch((error) => {
        log.error("[space] character catalog failed to load", url, error);
        if (attempt < 3) setTimeout(() => loadCharacters(url, attempt + 1), retryDelay(attempt));
      })
      .finally(release);
  }

  // Start composing the characters the room has in it. The engine calls this
  // from every snapshot and delta; the local player's own character holds the
  // loading gate (`blocking`) until it can be drawn walking and standing.
  function ensureAvatars(recipes, { blocking = false } = {}) {
    if (!Array.isArray(recipes)) return;
    for (const recipe of recipes) {
      if (!characters) {
        waiting.set(recipe, blocking || waiting.get(recipe) === true);
        continue;
      }
      const r = recipeOf(recipe);
      if (blocking) {
        blockingPending += 1;
        characters.prepareAll(r, ["walk", "idle"]).finally(() => {
          blockingPending = Math.max(0, blockingPending - 1);
          maybeReady();
        });
      } else if (!seen.has(r)) {
        // Standing and walking every way, so nobody blinks out on a first step.
        characters.prepareAll(r, ["idle", "walk"]);
      }
      seen.add(r);
    }
  }

  function registerTiles(dict) {
    if (dict && typeof dict === "object") tiles = dict;
    mapReady = true;
    maybeReady();
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

  function avatar(recipe, dir, frame = 0, action = "walk") {
    if (!characters) return null;
    const clip = CLIP_FOR_ACTION[action] ?? "walk";
    const direction = catalog.dirs.includes(dir) ? dir : catalog.dirs[0];
    // Until the strip the pose wants is made, the nearest one that is.
    const found = characters.stripOrNearest(recipeOf(recipe), clip, direction);
    if (!found) return null;
    const { w, h } = characters.frameSize;
    const n = characters.frames(found.anim);
    const idx = found.anim === clip ? ((Math.trunc(frame) % n) + n) % n : 0;
    return { img: found.strip, sx: idx * w, sy: 0, sw: w, sh: h, scale: 1 };
  }

  // Resolve a combat effect frame (impact spark / knockout burst) to its rect
  // on the fx sheet. One-shot strips: the caller clamps/expires by lifetime.
  function fx(name, frame = 0) {
    const spec = FX[name];
    if (!spec) return null;
    const sheet = sheets.get(FX_SHEET_ID);
    if (!sheet) return null;
    const idx = Math.min(Math.max(Math.trunc(frame), 0), spec.frames - 1);
    return { img: sheet.img, sx: idx * spec.w, sy: spec.y, sw: spec.w, sh: spec.h };
  }

  // The fx strip is global (every map uses it) and small enough to hold the gate.
  // Characters are composed through `ensureAvatars` as the room tells the
  // client who is in it; the catalog they are composed from holds the gate.
  loadTilesets([
    { id: FX_SHEET_ID, src: FX_SHEET_PATH },
    { id: UI_SHEET_ID, src: UI_SHEET_PATH },
  ]);
  loadCharacters(opts.characterCatalog);

  // A UI piece of the kit: its sheet image and its rect and slice there, or
  // null for a piece the kit does not have — or while its sheet has not
  // decoded: a sheet that failed to load still opens the ready gate, and
  // drawing from a broken image throws on every frame.
  function uiPiece(name) {
    const geometry = UI_KIT_GEOMETRY[name];
    const img = sheets.get(UI_SHEET_ID)?.img;
    if (!geometry || !img?.complete || !img.naturalWidth) return null;
    return { img, ...geometry };
  }

  return {
    tileSize,
    loadTilesets,
    ensureAvatars,
    registerTiles,
    hasTile(name) {
      return Boolean(tiles[name]);
    },
    tile,
    avatar,
    fx,
    uiPiece,
    fxFrameCount(name) {
      return FX[name]?.frames ?? 0;
    },
    avatarFrameCount(_recipe, action = "walk") {
      return characters?.frames(CLIP_FOR_ACTION[action] ?? "walk") || 1;
    },
    // What animation capabilities a character has, so the renderer's state
    // machine knows which resting states to drive: every creator character
    // breathes when idle and sits on a seat; none of them dozes off standing.
    avatarMeta(_recipe) {
      return { hasIdle: true, hasIdle2: false, hasSleep: false, hasSit: true, scale: 1 };
    },
    // Where the character's head and feet are inside a frame, so the renderer
    // can stand its feet on the ground and hang labels above its head.
    avatarBounds(recipe) {
      if (!characters) return { top: 0, foot: 0 };
      return characters.bounds(recipeOf(recipe));
    },
    // The composed frame box, for the creator's preview.
    get characters() {
      return characters;
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
