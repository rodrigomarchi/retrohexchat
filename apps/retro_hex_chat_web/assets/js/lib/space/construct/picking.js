/**
 * Which floor tile, and which placed piece, a point on the canvas is over —
 * pure geometry over the camera and its isometric projection.
 *
 * A tile's foot anchor is the centre of its diamond, and the projection's
 * inverse maps the diamond's two axes back onto the grid's, so rounding each
 * axis picks exactly the diamond the point is inside. A piece is found by its
 * sprite instead of its tile: a tree's canopy rises well above the diamond it
 * stands on, and clicking the canopy is clicking the tree.
 *
 * A piece covers its kind's footprint (`catalog[kind].size`, `[w, h]` tiles)
 * from its back corner, and its art stands on the kind's `foot` point inside
 * it — the same rules `Construct.Layout` applies on the server. Turning a
 * piece mirrors it, which swaps the floor's axes.
 * @module space/construct/picking
 */

const MIRRORED = new Set(["right", "left"]);

function sizeOf(map, kind, dir) {
  const [w, h] = map.catalog?.[kind]?.size ?? [1, 1];
  return MIRRORED.has(dir) ? [h, w] : [w, h];
}

/**
 * The tiles a piece of `kind` facing `dir` covers with its back corner on x, y.
 * @returns {{x:number, y:number}[]}
 */
export function footprintOf(map, kind, x, y, dir = "down") {
  const [w, h] = sizeOf(map, kind, dir);
  const tiles = [];
  for (let dy = 0; dy < h; dy += 1) {
    for (let dx = 0; dx < w; dx += 1) tiles.push({ x: x + dx, y: y + dy });
  }
  return tiles;
}

/**
 * The floor point a piece's art stands on: its kind's `foot`, by default the
 * centre of the footprint, brought forward for a piece wider than a tile that
 * nobody sits on, or for a pane on one edge of its tile the point
 * its `feet` name for the facing, taken as it is.
 * @returns {{x:number, y:number}}
 */
export function footPointOf(map, kind, x, y, dir = "down") {
  const edge = map.catalog?.[kind]?.feet?.[dir];
  if (edge) return { x: x + edge[0], y: y + edge[1] };
  const [w, h] = map.catalog?.[kind]?.size ?? [1, 1];
  // A piece wider than a tile stands brought forward of its centre, where its
  // art meets the floor, unless people sit on it (`Construct.Layout`).
  const seated = (map.catalog?.[kind]?.seats ?? []).length > 0;
  const forward = w * h === 1 || seated ? 0 : (w + h) / 4 - 0.15;
  const [fx, fy] = map.catalog?.[kind]?.foot ?? [(w - 1) / 2 + forward, (h - 1) / 2 + forward];
  return MIRRORED.has(dir) ? { x: x + fy, y: y + fx } : { x: x + fx, y: y + fy };
}

/**
 * Where a piece falls among the people around it: its footprint's, not its
 * art's (`Construct.Layout` sends the same `depth` with its decor). A long
 * piece's art stands forward of its centre and a pane on an edge, so each
 * sorts by its footprint's centre, a pane just behind its edge.
 * @returns {number}
 */
export function depthOf(map, kind, x, y, dir = "down") {
  const entry = map.catalog?.[kind];
  const edge = entry?.feet?.[dir];
  if (edge) return x + edge[0] + y + edge[1] - 0.01;
  if (entry?.foot) {
    const foot = footPointOf(map, kind, x, y, dir);
    return foot.x + foot.y;
  }
  const [w, h] = entry?.size ?? [1, 1];
  return x + y + (w - 1) / 2 + (h - 1) / 2;
}

/** The placed piece whose footprint covers a tile. */
export function itemCovering(map, tile) {
  return (
    map.items.find((item) =>
      footprintOf(map, item.kind, item.x, item.y, item.dir).some(
        (t) => t.x === tile.x && t.y === tile.y,
      ),
    ) ?? null
  );
}

/**
 * @param {{screenToWorld: Function, projection: {worldToTile: Function}}} camera
 * @param {number} canvasX
 * @param {number} canvasY
 * @returns {{x:number, y:number}}
 */
export function tileAtCanvasPoint(camera, canvasX, canvasY) {
  const world = camera.screenToWorld(canvasX, canvasY);
  const tile = camera.projection.worldToTile(world.x, world.y);
  return { x: Math.round(tile.x), y: Math.round(tile.y) };
}

/**
 * The nearest placed piece whose sprite covers the point, else the one on the
 * tile under it. A piece the room comes with (`fixed`) is never picked up: a
 * point on it picks nothing, not whatever stands behind it.
 * @param {import("../map.js").SpaceMap} map
 * @param {object} camera
 * @param {{tile: Function}|null} atlas
 * @param {number} canvasX
 * @param {number} canvasY
 * @returns {object|null}
 */
export function itemAtCanvasPoint(map, camera, atlas, canvasX, canvasY) {
  const point = (item) => footPointOf(map, item.kind, item.x, item.y, item.dir);
  const depth = (item) => depthOf(map, item.kind, item.x, item.y, item.dir);
  const nearestFirst = [...map.items].sort((a, b) => {
    return depth(b) - depth(a);
  });
  const scale = camera.scale ?? 1;

  for (const item of nearestFirst) {
    const sprite = atlas?.tile?.(map.kindTile(item.kind, item.dir));
    if (!sprite) continue;
    const at = point(item);
    const foot = camera.projection.footAnchor(at.x, at.y);
    const { x, y } = camera.worldToScreen(foot.x, foot.y);
    const w = sprite.sw * scale;
    const h = sprite.sh * scale;
    if (canvasX >= x - w / 2 && canvasX <= x + w / 2 && canvasY >= y - h && canvasY <= y) {
      return item.fixed ? null : item;
    }
  }

  const under = itemCovering(map, tileAtCanvasPoint(camera, canvasX, canvasY));
  return under?.fixed ? null : under;
}

/**
 * Whether a piece could go with its back corner on a tile, as far as this
 * client can tell: the server decides, this only colours the ghost green or
 * red. Every tile of the footprint must be free.
 * @param {import("../map.js").SpaceMap} map
 * @param {Iterable<{x:number,y:number}>} participants
 * @param {{x:number,y:number}} tile
 * @param {string|null} [movingId] a piece being moved may land on its own tiles
 * @param {string} [kind]
 * @param {string} [dir]
 * @returns {boolean}
 */
export function canPlaceAt(map, participants, tile, movingId = null, kind = null, dir = "down") {
  const people = [...participants].map((p) => `${Math.round(p.x)},${Math.round(p.y)}`);
  const tiles = kind ? footprintOf(map, kind, tile.x, tile.y, dir) : [tile];

  return tiles.every(({ x, y }) => {
    if (!map.inBounds(x, y) || map.isReserved(x, y)) return false;
    const here = itemCovering(map, { x, y });
    if (here) return here.id === movingId;
    if (map.isBlocked(x, y)) return false;
    return !people.includes(`${x},${y}`);
  });
}
