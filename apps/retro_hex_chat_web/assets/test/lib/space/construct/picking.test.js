import { describe, it, expect } from "vitest";

import {
  canPlaceAt,
  footPointOf,
  footprintOf,
  itemAtCanvasPoint,
  itemCovering,
  tileAtCanvasPoint,
} from "../../../../js/lib/space/construct/picking.js";
import { constructCamera, constructMap } from "./fixtures.js";

function screenOf(camera, x, y) {
  const foot = camera.projection.footAnchor(x, y);
  return camera.worldToScreen(foot.x, foot.y);
}

describe("tileAtCanvasPoint", () => {
  it("finds every tile from the centre of its diamond, wherever the camera is", () => {
    const map = constructMap();
    const camera = constructCamera(map);

    for (const follow of [
      [0, 0],
      [5, 5],
      [9, 9],
    ]) {
      camera.follow(...follow);
      for (let y = 0; y < map.height; y += 1) {
        for (let x = 0; x < map.width; x += 1) {
          const p = screenOf(camera, x, y);
          expect(tileAtCanvasPoint(camera, p.x, p.y)).toEqual({ x, y });
        }
      }
    }
  });

  it("stays on a tile anywhere inside its diamond, and leaves it past the edge", () => {
    const map = constructMap();
    const camera = constructCamera(map);
    const { hw, hh } = camera.projection;
    const c = screenOf(camera, 4, 4);

    expect(tileAtCanvasPoint(camera, c.x + hw * 0.9, c.y)).toEqual({ x: 4, y: 4 });
    expect(tileAtCanvasPoint(camera, c.x, c.y - hh * 0.9)).toEqual({ x: 4, y: 4 });
    // Past the right tip is the tile to the east on screen: +x, -y.
    expect(tileAtCanvasPoint(camera, c.x + hw * 1.1, c.y)).toEqual({ x: 5, y: 3 });
  });
});

describe("itemAtCanvasPoint", () => {
  it("finds a tall piece by its sprite, above the tile it stands on", () => {
    const tree = { id: "t", kind: "tree", x: 5, y: 5, dir: "down" };
    const map = constructMap({ items: [tree] });
    const camera = constructCamera(map);
    const atlas = { tile: () => ({ sw: 40, sh: 90 }) };
    const foot = screenOf(camera, 5, 5);

    expect(itemAtCanvasPoint(map, camera, atlas, foot.x, foot.y - 80)).toBe(tree);
    expect(itemAtCanvasPoint(map, camera, atlas, foot.x + 60, foot.y - 80)).toBe(null);
  });

  it("falls back to the tile when the art is not loaded", () => {
    const chair = { id: "c", kind: "chair", x: 3, y: 6, dir: "down" };
    const map = constructMap({ items: [chair] });
    const camera = constructCamera(map);
    const foot = screenOf(camera, 3, 6);

    expect(itemAtCanvasPoint(map, camera, null, foot.x, foot.y)).toBe(chair);
  });

  it("never picks up a piece the room comes with, nor what stands behind it", () => {
    const desk = { id: "fixed:3", kind: "tree", x: 5, y: 5, dir: "down", fixed: true };
    const behind = { id: "b", kind: "tree", x: 4, y: 4, dir: "down" };
    const map = constructMap({ items: [behind, desk] });
    const camera = constructCamera(map);
    const atlas = { tile: () => ({ sw: 40, sh: 90 }) };
    const foot = screenOf(camera, 5, 5);

    expect(itemAtCanvasPoint(map, camera, atlas, foot.x, foot.y - 10)).toBe(null);
    expect(itemAtCanvasPoint(map, camera, null, foot.x, foot.y)).toBe(null);
  });
});

describe("canPlaceAt", () => {
  it("says what the server will: free floor yes; gate, pieces and people no", () => {
    const chair = { id: "c", kind: "chair", x: 6, y: 6, dir: "down" };
    const map = constructMap({
      items: [chair],
      collision: [
        { x: 1, y: 1, w: 1, h: 1, kind: "prop" },
        { x: 6, y: 6, w: 1, h: 1, kind: "item" },
      ],
    });
    const people = [{ x: 4, y: 4 }];

    expect(canPlaceAt(map, people, { x: 5, y: 5 })).toBe(true);
    expect(canPlaceAt(map, people, { x: 2, y: 2 })).toBe(false);
    expect(canPlaceAt(map, people, { x: 1, y: 1 })).toBe(false);
    expect(canPlaceAt(map, people, { x: 6, y: 6 })).toBe(false);
    expect(canPlaceAt(map, people, { x: 4, y: 4 })).toBe(false);
    expect(canPlaceAt(map, people, { x: -1, y: 0 })).toBe(false);
    // A piece being moved may be dropped back where it stands.
    expect(canPlaceAt(map, people, { x: 6, y: 6 }, "c")).toBe(true);
  });
});

describe("pieces bigger than a tile", () => {
  it("cover their footprint, and turning swaps the axes, as on the server", () => {
    const map = constructMap();
    expect(footprintOf(map, "sofa", 3, 3, "down")).toEqual([
      { x: 3, y: 3 },
      { x: 3, y: 4 },
    ]);
    expect(footprintOf(map, "sofa", 3, 3, "right")).toEqual([
      { x: 3, y: 3 },
      { x: 4, y: 3 },
    ]);
    expect(footprintOf(map, "chair", 3, 3)).toEqual([{ x: 3, y: 3 }]);
  });

  it("stand their art on the footprint's centre, or the kind's own foot", () => {
    const map = constructMap();
    expect(footPointOf(map, "sofa", 3, 3, "down")).toEqual({ x: 3, y: 3.5 });
    expect(footPointOf(map, "sofa", 3, 3, "right")).toEqual({ x: 3.5, y: 3 });
    expect(footPointOf(map, "statue", 3, 3, "down")).toEqual({ x: 4, y: 4 });
  });

  it("are found from any tile they cover", () => {
    const sofa = { id: "s", kind: "sofa", x: 5, y: 5, dir: "down" };
    const map = constructMap({ items: [sofa] });
    expect(itemCovering(map, { x: 5, y: 6 })).toBe(sofa);
    expect(itemCovering(map, { x: 6, y: 5 })).toBe(null);
  });

  it("fit only where every tile of the footprint is free", () => {
    const tree = { id: "t", kind: "tree", x: 5, y: 6, dir: "down" };
    const sofa = { id: "s", kind: "sofa", x: 7, y: 3, dir: "down" };
    const map = constructMap({ items: [tree, sofa] });

    expect(canPlaceAt(map, [], { x: 5, y: 5 }, null, "sofa", "down")).toBe(false);
    expect(canPlaceAt(map, [], { x: 5, y: 5 }, null, "sofa", "right")).toBe(true);
    expect(canPlaceAt(map, [], { x: 5, y: 9 }, null, "sofa", "down")).toBe(false);
    expect(canPlaceAt(map, [{ x: 6, y: 5 }], { x: 5, y: 5 }, null, "sofa", "right")).toBe(false);
    // Moving the sofa one tile down overlaps only itself.
    expect(canPlaceAt(map, [], { x: 7, y: 4 }, "s", "sofa", "down")).toBe(true);
  });
});
