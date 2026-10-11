/**
 * Which floor tile, and which placed piece, a point on the canvas is over —
 * pure geometry over the camera and its isometric projection.
 *
 * A tile's foot anchor is the centre of its diamond, and the projection's
 * inverse maps the diamond's two axes back onto the grid's, so rounding each
 * axis picks exactly the diamond the point is inside. A piece is found by its
 * sprite instead of its tile: a tree's canopy rises well above the diamond it
 * stands on, and clicking the canopy is clicking the tree.
 * @module space/construct/picking
 */

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
 * tile under it.
 * @param {import("../map.js").SpaceMap} map
 * @param {object} camera
 * @param {{tile: Function}|null} atlas
 * @param {number} canvasX
 * @param {number} canvasY
 * @returns {object|null}
 */
export function itemAtCanvasPoint(map, camera, atlas, canvasX, canvasY) {
  const nearestFirst = [...map.items].sort((a, b) => b.x + b.y - (a.x + a.y));
  const scale = camera.scale ?? 1;

  for (const item of nearestFirst) {
    const sprite = atlas?.tile?.(map.kindTile(item.kind, item.dir));
    if (!sprite) continue;
    const foot = camera.projection.footAnchor(item.x, item.y);
    const { x, y } = camera.worldToScreen(foot.x, foot.y);
    const w = sprite.sw * scale;
    const h = sprite.sh * scale;
    if (canvasX >= x - w / 2 && canvasX <= x + w / 2 && canvasY >= y - h && canvasY <= y) {
      return item;
    }
  }

  const tile = tileAtCanvasPoint(camera, canvasX, canvasY);
  return map.itemAt(tile.x, tile.y);
}

/**
 * Whether a piece could go on a tile, as far as this client can tell: the
 * server decides, this only colours the ghost green or red.
 * @param {import("../map.js").SpaceMap} map
 * @param {Iterable<{x:number,y:number}>} participants
 * @param {{x:number,y:number}} tile
 * @param {string|null} [movingId] a piece being moved may land on its own tile
 * @returns {boolean}
 */
export function canPlaceAt(map, participants, tile, movingId = null) {
  const { x, y } = tile;
  if (!map.inBounds(x, y) || map.isReserved(x, y)) return false;
  const here = map.itemAt(x, y);
  if (here) return here.id === movingId;
  if (map.isBlocked(x, y)) return false;
  for (const p of participants) {
    if (Math.round(p.x) === x && Math.round(p.y) === y) return false;
  }
  return true;
}
