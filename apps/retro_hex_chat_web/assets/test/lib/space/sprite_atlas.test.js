import { describe, it, expect, vi } from "vitest";
import {
  createSpriteAtlas,
  AVATAR_ACTIONS,
  DIRECTIONS,
} from "../../../js/lib/space/sprite_atlas.js";

// The atlas creates its sheet images itself; recording them lets a test reach
// the UI kit's sheet, which `uiPiece` only hands out once it has decoded.
function recordImages() {
  const made = [];
  const Original = globalThis.Image;
  globalThis.Image = class extends Original {
    constructor(...args) {
      super(...args);
      made.push(this);
    }
  };
  return {
    sheet: (path) => made.find((img) => (img.getAttribute("src") ?? "").includes(path)),
    restore: () => {
      globalThis.Image = Original;
    },
  };
}

const TILESETS = [
  { id: "demo_sheet", src: "/images/space/demo_sheet.webp", tile: 16, columns: 40 },
];

const TILES = {
  grass: { ts: "demo_sheet", col: 5, row: 9 },
  tree: { ts: "demo_sheet", col: 5, row: 16, w: 2, h: 2 },
  mirrored_chair: { ts: "demo_sheet", col: 7, row: 9, flip_x: true },
};

const RECIPE = "c1.b-av.s-2.o-tun-0-3.h-lng-2.w-0.f-0";
const DEFAULT = "c1.b-av.s-0.o-bas-0-0.h-0.w-0.f-0";

// A stand-in for the character compositor: strips are made the first time
// they are asked for, like the real one, and every request is recorded.
function fakeCharacters({ ready = true } = {}) {
  const made = new Map();
  const asked = [];
  const settle = [];
  const frames = { walk: 4, idle: 4, attack: 6, hit: 6, ko: 7, getup: 5, sit: 3 };
  return {
    asked,
    settle: () => settle.splice(0).forEach((resolve) => resolve()),
    catalog: { dirs: DIRECTIONS, default: DEFAULT },
    frameSize: { w: 50, h: 100 },
    valid: (recipe) => typeof recipe === "string" && recipe.startsWith("c1."),
    strip(recipe, anim, dir) {
      const key = `${recipe}|${anim}|${dir}`;
      asked.push(key);
      if (!made.has(key) && ready) made.set(key, { width: 50 * frames[anim], height: 100, key });
      return made.get(key) ?? null;
    },
    stripOrNearest(recipe, anim, dir) {
      const strip = this.strip(recipe, anim, dir);
      if (strip) return { strip, anim };
      const near = made.get(`${recipe}|idle|south`);
      return near ? { strip: near, anim: "idle" } : null;
    },
    prefetch: (anims) => asked.push(`prefetch:${anims.join(",")}`),
    frames: (anim) => frames[anim] ?? 0,
    prepare: (recipe, anim, dir) => asked.push(`prepare:${recipe}|${anim}|${dir}`),
    prepareAll(recipe, anims) {
      asked.push(`prepareAll:${recipe}|${anims.join(",")}`);
      return new Promise((resolve) => settle.push(resolve));
    },
    bounds: () => ({ top: 6, foot: 96 }),
  };
}

function loadedAtlas() {
  const characters = fakeCharacters();
  const atlas = createSpriteAtlas({ tileSize: 16, scale: 2, characters });
  atlas.loadTilesets(TILESETS);
  atlas.registerTiles(TILES);
  return atlas;
}

describe("sprite atlas contract", () => {
  it("declares the actions a character can be drawn in, and the 8 iso facings", () => {
    expect(AVATAR_ACTIONS).toEqual([
      "walk",
      "idle",
      "idle2",
      "sword",
      "sleep",
      "sit",
      "hit",
      "ko",
      "getup",
      "wave",
      "dance",
    ]);
    expect(DIRECTIONS).toEqual([
      "south",
      "south-east",
      "east",
      "north-east",
      "north",
      "north-west",
      "west",
      "south-west",
    ]);
  });

  it("resolves a tile name into a source rectangle on its sheet", () => {
    const atlas = loadedAtlas();
    const grass = atlas.tile("grass");
    expect(grass).toMatchObject({ sx: 80, sy: 144, sw: 16, sh: 16 });
    expect(grass.flipX).toBe(false);
    expect(grass.img).toBeTruthy();
  });

  it("sizes a multi-tile prop from its w/h", () => {
    const atlas = loadedAtlas();
    expect(atlas.tile("tree")).toMatchObject({ sx: 80, sy: 256, sw: 32, sh: 32 });
  });

  it("preserves tile flip metadata for directional furniture", () => {
    const atlas = loadedAtlas();
    expect(atlas.tile("mirrored_chair")).toMatchObject({ sx: 112, sy: 144, flipX: true });
  });

  it("cycles an animated tile's frame on the clock, offset by the seed", () => {
    const atlas = loadedAtlas();
    atlas.registerTiles({
      ...TILES,
      water: { ts: "demo_sheet", col: 4, row: 2, w: 1, h: 1, frames: 4, period_ms: 800 },
    });
    // 4 frames over 800ms → 200ms each, packed horizontally from col 4.
    expect(atlas.tile("water", 0, 0)).toMatchObject({ sx: 64, sy: 32, sw: 16 });
    expect(atlas.tile("water", 250, 0)).toMatchObject({ sx: 80 });
    expect(atlas.tile("water", 650, 0)).toMatchObject({ sx: 112 });
    expect(atlas.tile("water", 850, 0)).toMatchObject({ sx: 64 }); // wraps

    // A per-position seed offsets the phase so repeated tiles desync.
    const cols = [0, 1, 2].map((s) => atlas.tile("water", 0, s).sx);
    expect(new Set(cols).size).toBeGreaterThan(1);

    // A static tile ignores now/seed entirely.
    expect(atlas.tile("grass", 999, 42)).toMatchObject({ sx: 80, sy: 144 });
  });

  it("shares one sheet image across every tile from it", () => {
    const atlas = loadedAtlas();
    expect(atlas.tile("grass").img).toBe(atlas.tile("tree").img);
  });

  it("returns null for an unknown tile or before its sheet loads", () => {
    const atlas = loadedAtlas();
    expect(atlas.tile("does_not_exist")).toBe(null);
    const bare = createSpriteAtlas();
    bare.registerTiles(TILES);
    expect(bare.tile("grass")).toBe(null);
  });

  it("reports whether a tile name is registered", () => {
    const atlas = loadedAtlas();
    expect(atlas.hasTile("grass")).toBe(true);
    expect(atlas.hasTile("nope")).toBe(false);
  });

  it("draws a character as one frame of its composed strip", () => {
    const atlas = loadedAtlas();
    expect(atlas.avatar(RECIPE, "south", 2, "walk")).toMatchObject({
      img: { key: `${RECIPE}|walk|south` },
      sx: 100,
      sy: 0,
      sw: 50,
      sh: 100,
      scale: 1,
    });
    // The game's sword swing is the catalog's attack clip; a seat is its sit.
    expect(atlas.avatar(RECIPE, "east", 0, "sword").img.key).toBe(`${RECIPE}|attack|east`);
    expect(atlas.avatar(RECIPE, "east", 0, "sleep").img.key).toBe(`${RECIPE}|sit|east`);
    // A frame past the clip's end wraps round.
    expect(atlas.avatar(RECIPE, "south", 9, "ko").sx).toBe(100);
    expect(atlas.avatarFrameCount(RECIPE, "ko")).toBe(7);
    expect(atlas.avatarMeta(RECIPE)).toMatchObject({
      hasIdle: true,
      hasSit: true,
      hasSleep: false,
    });
    expect(atlas.avatarBounds(RECIPE)).toEqual({ top: 6, foot: 96 });
  });

  it("draws a recipe the art cannot compose as the catalog's default", () => {
    const atlas = loadedAtlas();
    expect(atlas.avatar("knight", "south", 0).img.key).toBe(`${DEFAULT}|walk|south`);
  });

  it("draws nothing for a strip not composed yet", () => {
    const atlas = createSpriteAtlas({ characters: fakeCharacters({ ready: false }) });
    expect(atlas.avatar(RECIPE, "south", 0)).toBeNull();
  });

  it("draws nothing before the creator catalog has arrived", () => {
    const atlas = createSpriteAtlas();
    expect(atlas.avatar(RECIPE, "south", 0)).toBeNull();
    expect(atlas.avatarBounds(RECIPE)).toEqual({ top: 0, foot: 0 });
  });

  it("composes each character in the room standing and walking every way, once", () => {
    const characters = fakeCharacters();
    const atlas = createSpriteAtlas({ characters });
    atlas.ensureAvatars([RECIPE, "knight"]);
    atlas.ensureAvatars([RECIPE]);
    expect(characters.asked).toEqual([
      `prepareAll:${RECIPE}|idle,walk`,
      `prepareAll:${DEFAULT}|idle,walk`,
    ]);
  });

  it("holds the ready gate until the map and the player's own character can be drawn", async () => {
    const images = recordImages();
    const ready = vi.fn();
    const characters = fakeCharacters();
    const atlas = createSpriteAtlas({ onReady: ready, characters });
    atlas.ensureAvatars([RECIPE], { blocking: true });
    // A bystander's character must never hold up the first frame.
    atlas.ensureAvatars(["c1.b-av.s-1.o-bas-0-0.h-0.w-0.f-0"]);
    atlas.loadTilesets(TILESETS);
    atlas.registerTiles(TILES);

    const land = (img) => img.dispatchEvent(new Event("load"));
    land(atlas.fx("hit_spark", 0).img);
    land(images.sheet("ui/canvas"));
    land(atlas.tile("grass").img);
    expect(characters.asked).toContain(`prepareAll:${RECIPE}|walk,idle`);
    expect(ready).not.toHaveBeenCalled();

    characters.settle();
    await Promise.resolve();
    await Promise.resolve();
    expect(ready).toHaveBeenCalledTimes(1);
    images.restore();
  });

  it("keeps the gate shut while the map is still unknown", () => {
    const images = recordImages();
    const ready = vi.fn();
    const atlas = createSpriteAtlas({ onReady: ready });
    atlas.fx("hit_spark", 0).img.dispatchEvent(new Event("load"));
    images.sheet("ui/canvas").dispatchEvent(new Event("load"));
    images.restore();
    expect(ready).not.toHaveBeenCalled();
    atlas.registerTiles(TILES);
    expect(ready).toHaveBeenCalledTimes(1);
  });

  it("draws board modal art for a known asset id", () => {
    const atlas = createSpriteAtlas();
    const board = atlas.board("board_menu_v1");
    expect(board.canvas).toBeTruthy();
    expect(board.canvas.width).toBeGreaterThan(0);
  });
});

describe("combat fx sheet", () => {
  it("resolves impact effect frames on the fx strip and clamps the index", () => {
    const atlas = createSpriteAtlas();
    expect(atlas.fx("hit_spark", 0)).toMatchObject({ sx: 0, sy: 0, sw: 64, sh: 64 });
    expect(atlas.fx("hit_spark", 3)).toMatchObject({ sx: 192, sy: 0 });
    expect(atlas.fx("hit_spark", 99)).toMatchObject({ sx: 320 }); // clamps to last frame
    expect(atlas.fx("ko_burst", 1)).toMatchObject({ sx: 96, sy: 64, sw: 96, sh: 96 });
    expect(atlas.fxFrameCount("hit_spark")).toBe(6);
    expect(atlas.fx("nope", 0)).toBe(null);
  });
});

describe("ui kit pieces", () => {
  // jsdom never decodes an image; a sheet that has is one with a size.
  const decoded = (img) => {
    Object.defineProperty(img, "complete", { value: true });
    Object.defineProperty(img, "naturalWidth", { value: 400 });
  };

  it("resolves a canvas piece to the ui sheet, with its rect and slice", () => {
    const images = recordImages();
    const atlas = createSpriteAtlas({ sheetUrls: { ui_canvas: "/images/space/ui/canvas-1.webp" } });
    // Not until it has decoded: a broken sheet would throw on every draw.
    expect(atlas.uiPiece("bubble")).toBeNull();
    decoded(images.sheet("ui/canvas-1"));
    images.restore();
    const bubble = atlas.uiPiece("bubble");
    expect(bubble.img.getAttribute("src")).toBe("/images/space/ui/canvas-1.webp");
    expect(bubble).toMatchObject({ x: 0, y: 0, t: 8, r: 8, b: 8, l: 8 });
    expect(atlas.uiPiece("tail").t).toBeUndefined();
  });

  it("knows no piece the kit does not draw", () => {
    expect(createSpriteAtlas().uiPiece("dragon")).toBeNull();
  });
});
