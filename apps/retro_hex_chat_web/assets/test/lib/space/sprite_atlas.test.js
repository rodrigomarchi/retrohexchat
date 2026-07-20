import { describe, it, expect } from "vitest";

import {
  createSpriteAtlas,
  AVATAR_IDS,
  AVATAR_ACTIONS,
  DIRECTIONS,
} from "../../../js/lib/space/sprite_atlas.js";

const TILESETS = [{ id: "demo_sheet", src: "/images/space/demo_sheet.png", tile: 16, columns: 40 }];

const TILES = {
  grass: { ts: "demo_sheet", col: 5, row: 9 },
  tree: { ts: "demo_sheet", col: 5, row: 16, w: 2, h: 2 },
  mirrored_chair: { ts: "demo_sheet", col: 7, row: 9, flip_x: true },
};

function loadedAtlas() {
  const atlas = createSpriteAtlas({ tileSize: 16, scale: 2 });
  atlas.loadTilesets(TILESETS);
  atlas.registerTiles(TILES);
  return atlas;
}

describe("sprite atlas contract", () => {
  it("declares the premium iso roster, its actions, and the 8 iso facings", () => {
    expect(AVATAR_IDS).toEqual([
      "hero",
      "knight",
      "sorceress",
      "archer",
      "barbarian",
      "rogue",
      "cleric",
      "monk",
    ]);
    expect(AVATAR_ACTIONS).toEqual([
      "walk",
      "sword",
      "idle",
      "idle2",
      "sleep",
      "hit",
      "ko",
      "getup",
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

  it("slices a fully-animated iso avatar's walk/idle/attack/sleep blocks by 8-direction facing", () => {
    const atlas = loadedAtlas();
    // Hero: walk/idle/attack/sleep + hit/ko/getup, all 8-dir, 188×146 frames.
    expect(atlas.avatar("hero", "south", 0)).toMatchObject({ sx: 0, sy: 0, sw: 188, sh: 146 });
    expect(atlas.avatar("hero", "south-east", 1)).toMatchObject({ sx: 188, sy: 146 });
    // idle block starts at 8*146, sword(attack) at 16*146.
    expect(atlas.avatar("hero", "south-east", 1, "idle")).toMatchObject({ sx: 188, sy: 1314 });
    expect(atlas.avatar("hero", "south", 2, "sword")).toMatchObject({ sx: 376, sy: 2336 });
    // sleep faces the avatar's own direction: south row at 24*146, north at 28*146.
    expect(atlas.avatar("hero", "south", 0, "sleep")).toMatchObject({ sx: 0, sy: 3504 });
    expect(atlas.avatar("hero", "north", 0, "sleep")).toMatchObject({ sx: 0, sy: 4088 });
    // combat blocks: hit at 32*146, ko at 40*146, getup at 48*146.
    expect(atlas.avatar("hero", "south", 0, "hit")).toMatchObject({ sx: 0, sy: 4672 });
    expect(atlas.avatar("hero", "south", 3, "ko")).toMatchObject({ sx: 564, sy: 5840 });
    expect(atlas.avatar("hero", "south", 0, "getup")).toMatchObject({ sx: 0, sy: 7008 });
    expect(atlas.avatarFrameCount("hero", "walk")).toBe(4);
    // Hero has a single idle variant.
    expect(atlas.avatarMeta("hero")).toMatchObject({ hasIdle: true, hasIdle2: false });
  });

  it("slices the fully-animated knight across walk/idle/idle2/sword/sleep blocks", () => {
    const atlas = loadedAtlas();
    // 188×151 frames; walk 0.., idle 1208.., idle2 2416.., sword(attack) 3624..,
    // sleep 4832.., hit 6040.., ko 7248.., getup 8456.
    expect(atlas.avatar("knight", "south", 0)).toMatchObject({ sx: 0, sy: 0, sw: 188, sh: 151 });
    expect(atlas.avatar("knight", "east", 1, "idle")).toMatchObject({ sx: 188, sy: 1510 });
    // The knight carries a second idle stance (idle2) as a full 8-dir block.
    expect(atlas.avatar("knight", "east", 1, "idle2")).toMatchObject({ sx: 188, sy: 2718 });
    expect(atlas.avatar("knight", "south", 2, "sword")).toMatchObject({ sx: 376, sy: 3624 });
    // sleep faces the avatar's own direction.
    expect(atlas.avatar("knight", "south", 0, "sleep")).toMatchObject({ sx: 0, sy: 4832 });
    expect(atlas.avatar("knight", "north", 0, "sleep")).toMatchObject({ sx: 0, sy: 5436 });
    expect(atlas.avatar("knight", "east", 1, "hit")).toMatchObject({ sx: 188, sy: 6342 });
    expect(atlas.avatar("knight", "south", 3, "ko")).toMatchObject({ sx: 564, sy: 7248 });
    expect(atlas.avatar("knight", "north", 0, "getup")).toMatchObject({ sx: 0, sy: 9060 });
    expect(atlas.avatarFrameCount("knight", "sword")).toBe(4);
    expect(atlas.avatarMeta("knight")).toMatchObject({ hasIdle: true, hasIdle2: true });
  });

  it("falls back to the default hero block for an unknown avatar id", () => {
    const atlas = loadedAtlas();
    expect(atlas.avatar("who", "south", 0)).toMatchObject({ sx: 0, sy: 0, sw: 188, sh: 146 });
  });

  it("auto-loads the roster sheets so the default hero renders on any map", () => {
    // Every iso avatar sheet loads on creation, independent of the active map — so
    // bots and anyone on the default avatar always draw.
    const atlas = createSpriteAtlas();
    expect(atlas.avatar("hero", "south")).toMatchObject({ sx: 0, sy: 0, sw: 188, sh: 146 });
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
