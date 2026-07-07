import { describe, it, expect } from "vitest";

import { SpaceMap } from "../../../js/lib/space/map.js";

function tavernDefinition() {
  return {
    id: "tavern_cafe_v1",
    version: 1,
    width: 8,
    height: 6,
    tile_size: 16,
    ground: "grass",
    spawn: [{ x: 1, y: 1, dir: "down" }],
    collision: [
      { x: 0, y: 0, w: 8, h: 1, kind: "wall" },
      { x: 3, y: 3, w: 2, h: 1, kind: "counter" },
    ],
    zones: [{ id: "main", kind: "common", x: 1, y: 1, w: 4, h: 3 }],
    seats: [{ id: "seat_a", x: 2, y: 2, dir: "up" }],
    interactables: [{ id: "board", kind: "board", x: 5, y: 2, title: "Menu" }],
    layers: {
      floor: [
        ["wall_stone", "wall_stone", "wall_stone", "wall_stone"],
        ["wall_stone", "floor_wood", "floor_grass", "wall_stone"],
      ],
      decor: [],
      above: [],
    },
  };
}

describe("SpaceMap.from", () => {
  it("exposes dimensions and tile size", () => {
    const map = SpaceMap.from(tavernDefinition());
    expect(map.id).toBe("tavern_cafe_v1");
    expect(map.width).toBe(8);
    expect(map.height).toBe(6);
    expect(map.tileSize).toBe(16);
  });

  it("indexes collision rects into a queryable set", () => {
    const map = SpaceMap.from(tavernDefinition());
    expect(map.isBlocked(0, 0)).toBe(true);
    expect(map.isBlocked(7, 0)).toBe(true);
    expect(map.isBlocked(3, 3)).toBe(true);
    expect(map.isBlocked(4, 3)).toBe(true);
    expect(map.isBlocked(1, 1)).toBe(false);
  });

  it("reports out-of-bounds tiles as blocked", () => {
    const map = SpaceMap.from(tavernDefinition());
    expect(map.inBounds(0, 0)).toBe(true);
    expect(map.inBounds(-1, 0)).toBe(false);
    expect(map.inBounds(8, 0)).toBe(false);
    expect(map.isBlocked(-1, 0)).toBe(true);
    expect(map.isBlocked(8, 6)).toBe(true);
  });

  it("looks up a zone by tile", () => {
    const map = SpaceMap.from(tavernDefinition());
    expect(map.zoneAt(2, 2)?.id).toBe("main");
    expect(map.zoneAt(7, 5)).toBe(null);
  });

  it("looks up seats and interactables by id", () => {
    const map = SpaceMap.from(tavernDefinition());
    expect(map.seat("seat_a")?.x).toBe(2);
    expect(map.seat("missing")).toBe(null);
    expect(map.interactable("board")?.title).toBe("Menu");
    expect(map.interactable("nope")).toBe(null);
  });

  it("returns the first spawn as the default", () => {
    const map = SpaceMap.from(tavernDefinition());
    expect(map.defaultSpawn()).toEqual({ x: 1, y: 1, dir: "down" });
  });

  it("reads the floor tile id from the layer matrix, falling back to ground", () => {
    const map = SpaceMap.from(tavernDefinition());
    expect(map.floorTile(2, 1)).toBe("floor_grass");
    expect(map.floorTile(1, 1)).toBe("floor_wood");
    // Cells the matrix does not cover fall back to the opaque ground tile.
    expect(map.floorTile(1, 5)).toBe("grass");
    expect(map.floorTile(3, 3)).toBe("grass");
  });

  it("tolerates a definition missing optional collections", () => {
    const map = SpaceMap.from({ id: "bare", width: 4, height: 4, tile_size: 16 });
    expect(map.isBlocked(1, 1)).toBe(false);
    expect(map.zoneAt(1, 1)).toBe(null);
    expect(map.seat("x")).toBe(null);
    expect(map.defaultSpawn()).toEqual({ x: 0, y: 0, dir: "down" });
    // With no ground tile an uncovered cell is null (renderer skips it).
    expect(map.floorTile(1, 1)).toBe(null);
  });
});
