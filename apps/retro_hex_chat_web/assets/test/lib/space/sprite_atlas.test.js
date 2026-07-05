import { describe, it, expect } from "vitest";

import {
  createSpriteAtlas,
  TILE_IDS,
  AVATAR_IDS,
  DIRECTIONS,
} from "../../../js/lib/space/sprite_atlas.js";

describe("sprite atlas contract", () => {
  it("declares the tavern tile ids and avatar ids", () => {
    expect(TILE_IDS).toContain("floor_stone");
    expect(TILE_IDS).toContain("floor_wood");
    expect(TILE_IDS).toContain("wall_stone");
    expect(TILE_IDS).toContain("counter_wood");
    expect(AVATAR_IDS.length).toBeGreaterThanOrEqual(4);
    expect(DIRECTIONS).toEqual(["down", "up", "left", "right"]);
  });

  it("has a sprite for every declared tile id", () => {
    const atlas = createSpriteAtlas({ tileSize: 16, scale: 3 });
    for (const id of TILE_IDS) {
      expect(atlas.hasTile(id)).toBe(true);
      const sprite = atlas.tile(id);
      expect(sprite.canvas).toBeTruthy();
      expect(sprite.canvas.width).toBe(16 * 3);
      expect(sprite.canvas.height).toBe(16 * 3);
    }
  });

  it("has an avatar sprite in each of the four directions", () => {
    const atlas = createSpriteAtlas({ tileSize: 16, scale: 3 });
    for (const id of AVATAR_IDS) {
      for (const dir of DIRECTIONS) {
        expect(atlas.hasAvatar(id, dir)).toBe(true);
        expect(atlas.avatar(id, dir).canvas).toBeTruthy();
      }
    }
  });

  it("falls back to a default avatar for an unknown id", () => {
    const atlas = createSpriteAtlas();
    expect(atlas.avatar("does_not_exist", "down").canvas).toBeTruthy();
  });

  it("caches sprites so repeated lookups return the same canvas", () => {
    const atlas = createSpriteAtlas();
    expect(atlas.tile("floor_stone")).toBe(atlas.tile("floor_stone"));
    expect(atlas.avatar("mage_blue", "up")).toBe(atlas.avatar("mage_blue", "up"));
  });

  it("draws board modal art for a known asset id", () => {
    const atlas = createSpriteAtlas();
    const board = atlas.board("board_menu_v1");
    expect(board.canvas).toBeTruthy();
    expect(board.canvas.width).toBeGreaterThan(0);
  });
});
