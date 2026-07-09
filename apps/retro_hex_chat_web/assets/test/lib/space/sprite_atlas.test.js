import { describe, it, expect } from "vitest";

import {
  createSpriteAtlas,
  AVATAR_IDS,
  AVATAR_ACTIONS,
  DIRECTIONS,
} from "../../../js/lib/space/sprite_atlas.js";

const TILESETS = [
  { id: "overworld", src: "/images/space/overworld.png", tile: 16, columns: 40 },
  { id: "character", src: "/images/space/character.png", tile: 16, columns: 17 },
  { id: "av_knight", src: "/images/space/avatars/knight.png" },
];

const TILES = {
  grass: { ts: "overworld", col: 5, row: 9 },
  tree: { ts: "overworld", col: 5, row: 16, w: 2, h: 2 },
  mirrored_chair: { ts: "overworld", col: 7, row: 9, flip_x: true },
};

function loadedAtlas() {
  const atlas = createSpriteAtlas({ tileSize: 16, scale: 2 });
  atlas.loadTilesets(TILESETS);
  atlas.registerTiles(TILES);
  return atlas;
}

describe("sprite atlas contract", () => {
  it("declares the hero plus the seven class avatars, their actions, and the four facings", () => {
    expect(AVATAR_IDS).toEqual([
      "redtunic_hero",
      "sorceress",
      "knight",
      "archer",
      "barbarian",
      "rogue",
      "cleric",
      "monk",
    ]);
    expect(AVATAR_ACTIONS).toEqual(["walk", "sword"]);
    expect(DIRECTIONS).toEqual(["down", "up", "left", "right"]);
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

  it("slices the red-tunic hero walk and sword frames by facing", () => {
    const atlas = loadedAtlas();
    // Walk block is at (0,0); down = row 0, frame 0 = col 0.
    expect(atlas.avatar("redtunic_hero", "down", 0)).toMatchObject({
      sx: 0,
      sy: 0,
      sw: 16,
      sh: 32,
    });
    // up = row offset 4, frame 1 = col 1.
    expect(atlas.avatar("redtunic_hero", "up", 1)).toMatchObject({ sx: 16, sy: 64 });
    // Sword block starts at row 8 and uses its own row order: down/up/right/left.
    expect(atlas.avatar("redtunic_hero", "down", 2, "sword")).toMatchObject({
      sx: 64,
      sy: 128,
      sw: 32,
      sh: 32,
    });
    expect(atlas.avatar("redtunic_hero", "right", 3, "sword")).toMatchObject({
      sx: 96,
      sy: 192,
      sw: 32,
      sh: 32,
    });
    expect(atlas.avatar("redtunic_hero", "up", 1, "sword")).toMatchObject({
      sx: 32,
      sy: 160,
      sw: 32,
      sh: 32,
    });
    expect(atlas.avatar("redtunic_hero", "left", 3, "sword")).toMatchObject({
      sx: 96,
      sy: 224,
      sw: 32,
      sh: 32,
    });
    expect(atlas.avatarFrameCount("redtunic_hero", "walk")).toBe(4);
    expect(atlas.avatarFrameCount("redtunic_hero", "sword")).toBe(4);
  });

  it("slices a 36px class avatar from its own sheet by facing and frame", () => {
    const atlas = loadedAtlas();
    // Class sheets are a 4x4 grid of 36px cells: rows down/up/left/right.
    expect(atlas.avatar("knight", "down", 0)).toMatchObject({
      sx: 0,
      sy: 0,
      sw: 36,
      sh: 36,
    });
    expect(atlas.avatar("knight", "up", 1)).toMatchObject({ sx: 36, sy: 36 });
    expect(atlas.avatar("knight", "left", 2)).toMatchObject({ sx: 72, sy: 72 });
    expect(atlas.avatar("knight", "right", 3)).toMatchObject({ sx: 108, sy: 108 });
    // Attack block lives on rows 4-7 (y 144..252) of the same 36px sheet.
    expect(atlas.avatar("knight", "down", 0, "sword")).toMatchObject({
      sx: 0,
      sy: 144,
      sw: 36,
      sh: 36,
    });
    expect(atlas.avatar("knight", "right", 2, "sword")).toMatchObject({ sx: 72, sy: 252 });
    expect(atlas.avatarFrameCount("knight", "walk")).toBe(4);
    expect(atlas.avatarFrameCount("knight", "sword")).toBe(4);
  });

  it("falls back to the default block for an unknown avatar id", () => {
    const atlas = loadedAtlas();
    expect(atlas.avatar("who", "down", 0)).toMatchObject({ sx: 0, sy: 0, sw: 16, sh: 32 });
  });

  it("returns null for an avatar before the character sheet loads", () => {
    const atlas = createSpriteAtlas();
    expect(atlas.avatar("redtunic_hero", "down")).toBe(null);
  });

  it("draws board modal art for a known asset id", () => {
    const atlas = createSpriteAtlas();
    const board = atlas.board("board_menu_v1");
    expect(board.canvas).toBeTruthy();
    expect(board.canvas.width).toBeGreaterThan(0);
  });
});
