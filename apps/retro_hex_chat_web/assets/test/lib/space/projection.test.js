import { describe, it, expect } from "vitest";

import {
  createProjection,
  TopDownProjection,
  IsoProjection,
} from "../../../js/lib/space/projection.js";

describe("TopDownProjection (reproduces historical math)", () => {
  const p = new TopDownProjection({ tileSize: 16, scale: 2, mapWidth: 20, mapHeight: 15 });

  it("floorAnchor is tile*tilePx (top-left)", () => {
    expect(p.floorAnchor(2, 3)).toEqual({ x: 64, y: 96 });
  });

  it("footAnchor is the tile centre in scaled pixels (camera-follow point)", () => {
    expect(p.footAnchor(2, 3)).toEqual({ x: 80, y: 112 });
  });

  it("worldToTile inverts floorAnchor", () => {
    expect(p.worldToTile(64, 96)).toEqual({ x: 2, y: 3 });
  });

  it("depthKey sorts purely by the front row", () => {
    expect(p.depthKey(5, 7)).toBe(7);
  });

  it("worldBounds is mapDims*tilePx", () => {
    expect(p.worldBounds()).toEqual({ width: 640, height: 480 });
  });

  it("remapIntent is identity and footprint is the square tile", () => {
    expect(p.remapIntent({ dx: 1, dy: 0, dir: "right" })).toEqual({ dx: 1, dy: 0, dir: "right" });
    expect(p.tileFootprint).toEqual({ w: 32, h: 32 });
  });
});

describe("createProjection", () => {
  it("defaults to top-down when the map omits projection", () => {
    const p = createProjection({ tileSize: 16, scale: 2, mapWidth: 4, mapHeight: 4 });
    expect(p.kind).toBe("topdown");
  });

  it("builds an iso projection when the map asks for it", () => {
    const p = createProjection({
      map: { projection: "isometric", iso: { tile_w: 64, tile_h: 32, z_step: 16 } },
      scale: 2,
      mapWidth: 10,
      mapHeight: 8,
    });
    expect(p.kind).toBe("isometric");
  });
});

describe("IsoProjection (2:1 diamond)", () => {
  const p = new IsoProjection({
    scale: 2,
    mapWidth: 10,
    mapHeight: 8,
    tileW: 64,
    tileH: 32,
    zStep: 16,
    headroom: 6,
  });
  // hw=64 hh=32 zs=32 originX=8*64+64=576 originY=32+192=224

  it("footAnchor maps a tile to its diamond centre", () => {
    expect(p.footAnchor(0, 0)).toEqual({ x: 576, y: 224 });
    expect(p.footAnchor(2, 3)).toEqual({ x: 512, y: 384 });
  });

  it("elevation lifts the foot up-screen", () => {
    expect(p.footAnchor(2, 3, 1)).toEqual({ x: 512, y: 352 });
  });

  it("floorAnchor is the diamond bounding-box top-left", () => {
    expect(p.floorAnchor(2, 3)).toEqual({ x: 448, y: 352 });
  });

  it("worldToTile is the exact inverse of footAnchor on the floor plane", () => {
    for (const [tx, ty] of [
      [0, 0],
      [2, 3],
      [9, 7],
      [5, 1],
    ]) {
      const w = p.footAnchor(tx, ty);
      const t = p.worldToTile(w.x, w.y);
      expect(t.x).toBeCloseTo(tx, 9);
      expect(t.y).toBeCloseTo(ty, 9);
    }
  });

  it("depthKey orders by x+y with elevation only as a tie-break", () => {
    expect(p.depthKey(2, 3)).toBeCloseTo(5, 9);
    expect(p.depthKey(3, 3)).toBeCloseTo(6, 9);
    // a taller object on the same tile sorts just AFTER its flat neighbour but
    // still BEFORE the next diamond in front.
    expect(p.depthKey(2, 3, 1)).toBeGreaterThan(p.depthKey(2, 3, 0));
    expect(p.depthKey(2, 3, 1)).toBeLessThan(p.depthKey(3, 3, 0));
  });

  it("worldBounds spans the full projected diamond", () => {
    expect(p.worldBounds()).toEqual({ width: 1280, height: 992 });
  });
});
