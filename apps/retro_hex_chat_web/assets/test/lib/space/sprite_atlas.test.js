import { describe, it, expect } from "vitest";

import { createSpriteAtlas, AVATAR_IDS, DIRECTIONS } from "../../../js/lib/space/sprite_atlas.js";

const TILESETS = [
  { id: "overworld", src: "/images/space/overworld.png", tile: 16, columns: 40 },
  { id: "character", src: "/images/space/character.png", tile: 16, columns: 17 },
];

const TILES = {
  grass: { ts: "overworld", col: 5, row: 9 },
  tree: { ts: "overworld", col: 5, row: 16, w: 2, h: 2 },
};

function loadedAtlas() {
  const atlas = createSpriteAtlas({ tileSize: 16, scale: 2 });
  atlas.loadTilesets(TILESETS);
  atlas.registerTiles(TILES);
  return atlas;
}

describe("sprite atlas contract", () => {
  it("declares four avatar ids and the four facings", () => {
    expect(AVATAR_IDS.length).toBe(4);
    expect(AVATAR_IDS).toContain("rogue_red");
    expect(DIRECTIONS).toEqual(["down", "up", "left", "right"]);
  });

  it("resolves a tile name into a source rectangle on its sheet", () => {
    const atlas = loadedAtlas();
    const grass = atlas.tile("grass");
    expect(grass).toMatchObject({ sx: 80, sy: 144, sw: 16, sh: 16 });
    expect(grass.img).toBeTruthy();
  });

  it("sizes a multi-tile prop from its w/h", () => {
    const atlas = loadedAtlas();
    expect(atlas.tile("tree")).toMatchObject({ sx: 80, sy: 256, sw: 32, sh: 32 });
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

  it("slices the character sheet per avatar, facing and frame", () => {
    const atlas = loadedAtlas();
    // rogue_red block is at (0,0); down = row 0, frame 0 = col 0.
    expect(atlas.avatar("rogue_red", "down", 0)).toMatchObject({ sx: 0, sy: 0, sw: 16, sh: 32 });
    // up = row offset 4, frame 1 = col 1.
    expect(atlas.avatar("rogue_red", "up", 1)).toMatchObject({ sx: 16, sy: 64 });
    // mage_green block is at (4,8); left = row offset 6.
    expect(atlas.avatar("mage_green", "left", 0)).toMatchObject({ sx: 64, sy: 224 });
  });

  it("falls back to the default block for an unknown avatar id", () => {
    const atlas = loadedAtlas();
    expect(atlas.avatar("who", "down", 0)).toMatchObject({ sx: 0, sy: 0, sw: 16, sh: 32 });
  });

  it("returns null for an avatar before the character sheet loads", () => {
    const atlas = createSpriteAtlas();
    expect(atlas.avatar("rogue_red", "down")).toBe(null);
  });

  it("draws board modal art for a known asset id", () => {
    const atlas = createSpriteAtlas();
    const board = atlas.board("board_menu_v1");
    expect(board.canvas).toBeTruthy();
    expect(board.canvas.width).toBeGreaterThan(0);
  });
});
