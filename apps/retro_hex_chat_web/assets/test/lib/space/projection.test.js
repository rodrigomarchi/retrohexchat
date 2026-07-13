import { describe, it, expect } from "vitest";

import { createProjection, IsoProjection } from "../../../js/lib/space/projection.js";

describe("createProjection", () => {
  it("builds an iso projection from the map's iso params", () => {
    const p = createProjection({
      map: { projection: "isometric", iso: { tile_w: 64, tile_h: 32, z_step: 16 } },
      scale: 2,
      mapWidth: 10,
      mapHeight: 8,
    });
    expect(p.kind).toBe("isometric");
    expect(p.tileFootprint).toEqual({ w: 128, h: 64 });
  });

  it("falls back to default diamond params when the map omits iso", () => {
    const p = createProjection({ scale: 2, mapWidth: 4, mapHeight: 4 });
    expect(p.kind).toBe("isometric");
    // tile_w 64 / tile_h 32 defaults → footprint 128×64 at scale 2.
    expect(p.tileFootprint).toEqual({ w: 128, h: 64 });
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
