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
    labels: [{ id: "nameplate", kind: "nameplate", x: 1, y: 1, w: 4, h: 1, text: "Alice + Bob" }],
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

  it("keeps static map labels from the server definition", () => {
    const map = SpaceMap.from(tavernDefinition());
    expect(map.labels).toEqual([
      { id: "nameplate", kind: "nameplate", x: 1, y: 1, w: 4, h: 1, text: "Alice + Bob" },
    ]);
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

describe("SpaceMap as a Construct", () => {
  const construct = () =>
    SpaceMap.from({
      width: 10,
      height: 10,
      backdrop: "eef0f4",
      reserved: [{ x: 1, y: 1 }],
      catalog: { tree: { tiles: { down: "cst_tree", right: "cst_tree_r" } } },
      max_items: 150,
      revision: 2,
      items: [{ id: "a", kind: "tree", x: 4, y: 4, dir: "right" }],
      collision: [{ x: 4, y: 4, w: 1, h: 1, kind: "item" }],
      layers: { floor: [], decor: [{ x: 4, y: 4, tile: "cst_tree_r", sort: "stand" }], above: [] },
    });

  it("knows its building rules and what is placed", () => {
    const map = construct();
    expect(map.buildable()).toBe(true);
    expect(map.backdrop).toBe("eef0f4");
    expect(map.isReserved(1, 1)).toBe(true);
    expect(map.isReserved(2, 2)).toBe(false);
    expect(map.itemAt(4, 4).id).toBe("a");
    expect(map.item("a").dir).toBe("right");
    expect(map.kindTile("tree", "right")).toBe("cst_tree_r");
    expect(map.kindTile("tree", "sideways")).toBe("cst_tree");
    expect(SpaceMap.from({}).buildable()).toBe(false);
  });

  it("applies a newer layout patch and drops one it already has", () => {
    const map = construct();
    const patch = {
      revision: 3,
      items: [{ id: "b", kind: "tree", x: 6, y: 6, dir: "down" }],
      decor: [{ x: 6, y: 6, tile: "cst_tree", sort: "stand" }],
      collision: [{ x: 6, y: 6, w: 1, h: 1, kind: "item" }],
      seats: [{ id: "seat:b", x: 6, y: 6, dir: "down" }],
      lights: [],
      labels: [{ kind: "hologram", text: "Hi", x: 6, y: 6 }],
      interactables: [{ id: "item:b", kind: "item", use: "sign", x: 6, y: 6 }],
    };

    expect(map.applyPatch(patch)).toBe(true);
    expect(map.labels).toEqual(patch.labels);
    expect(map.interactable("item:b").use).toBe("sign");
    expect(map.isBlocked(4, 4)).toBe(false);
    expect(map.isBlocked(6, 6)).toBe(true);
    expect(map.decor).toEqual(patch.decor);
    expect(map.seat("seat:b")).not.toBe(null);

    expect(map.applyPatch({ ...patch, revision: 3, items: [] })).toBe(false);
    expect(map.applyPatch({ ...patch, revision: 1, items: [] })).toBe(false);
    expect(map.items).toHaveLength(1);
  });
});
