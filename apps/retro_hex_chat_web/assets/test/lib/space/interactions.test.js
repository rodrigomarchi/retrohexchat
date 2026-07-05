import { describe, it, expect } from "vitest";

import { frontTile, interactTarget } from "../../../js/lib/space/interactions.js";
import { SpaceMap } from "../../../js/lib/space/map.js";

function map() {
  return SpaceMap.from({
    id: "t",
    width: 10,
    height: 10,
    tile_size: 16,
    spawn: [],
    collision: [],
    zones: [],
    seats: [],
    interactables: [{ id: "board", kind: "board", x: 5, y: 3, title: "Menu" }],
  });
}

describe("frontTile", () => {
  it("returns the tile the avatar faces", () => {
    expect(frontTile({ x: 5, y: 5, dir: "up" })).toEqual({ x: 5, y: 4 });
    expect(frontTile({ x: 5, y: 5, dir: "down" })).toEqual({ x: 5, y: 6 });
    expect(frontTile({ x: 5, y: 5, dir: "left" })).toEqual({ x: 4, y: 5 });
    expect(frontTile({ x: 5, y: 5, dir: "right" })).toEqual({ x: 6, y: 5 });
  });
});

describe("interactTarget", () => {
  it("resolves an interactable on the tile the avatar faces", () => {
    // Standing at (5,4) facing up → front tile (5,3) has the board.
    const target = interactTarget(map(), { x: 5, y: 4, dir: "up" });
    expect(target).toEqual({ id: "board", kind: "board", title: "Menu" });
  });

  it("resolves an adjacent interactable when not directly faced", () => {
    // Standing at (6,3) facing right; the board is adjacent to the left.
    const target = interactTarget(map(), { x: 6, y: 3, dir: "right" });
    expect(target?.id).toBe("board");
  });

  it("returns null when nothing is within reach", () => {
    expect(interactTarget(map(), { x: 0, y: 9, dir: "down" })).toBe(null);
  });
});
