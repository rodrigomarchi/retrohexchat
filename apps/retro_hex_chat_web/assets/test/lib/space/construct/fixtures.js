import { Camera } from "../../../../js/lib/space/camera.js";
import { SpaceMap } from "../../../../js/lib/space/map.js";

// A small Construct: a 10x10 floor, the gate at (1,1) with its apron kept
// clear, and the four kinds' tiles.
export function constructMap(overrides = {}) {
  return SpaceMap.from({
    id: "construct",
    width: 10,
    height: 10,
    tile_size: 32,
    iso: { tile_w: 48, tile_h: 20, z_step: 16, headroom: 8 },
    collision: [{ x: 1, y: 1, w: 1, h: 1, kind: "prop" }],
    reserved: [
      { x: 1, y: 1 },
      { x: 2, y: 2 },
    ],
    catalog: {
      chair: { tiles: { down: "cst_chair", right: "cst_chair_r" }, seat: true },
      tree: { tiles: { down: "cst_tree", right: "cst_tree_r" } },
      sofa: { tiles: { down: "cst_sofa", right: "cst_sofa_r" }, size: [1, 2] },
      statue: { tiles: { down: "cst_statue", right: "cst_statue_r" }, size: [2, 2], foot: [1, 1] },
    },
    max_items: 150,
    items: [],
    layers: { floor: [], decor: [], above: [] },
    ...overrides,
  });
}

export function constructCamera(map, viewport = [640, 480]) {
  const camera = new Camera({
    tileSize: 32,
    scale: 1,
    mapWidth: map.width,
    mapHeight: map.height,
    map: { iso: { tile_w: 48, tile_h: 20, z_step: 16, headroom: 8 } },
  });
  camera.setViewport(viewport[0], viewport[1]);
  return camera;
}
