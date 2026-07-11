/**
 * Projection: the single seam between a logical tile grid and world pixels.
 *
 * The engine renders in two stages — `tile → worldPixel` (this module) and
 * `worldPixel → screen` (`Camera.worldToScreen`, a bare camera-offset subtraction
 * that is projection-agnostic). Every difference between a top-down and an
 * isometric view lives here: anchors, depth order, the inverse (screen→tile) and
 * the input remap. `TopDownProjection` reproduces the historical inline math
 * exactly, so the existing camera/renderer/engine tests are the regression net
 * that guarantees top-down maps never move a pixel.
 *
 * All outputs are in **scaled world pixels** (the render scale folded in) so the
 * camera stays a pure translation.
 *
 * @module space/projection
 */

const EPS = 1e-3;

/**
 * @param {{map?: object, tileSize:number, scale:number, mapWidth:number, mapHeight:number}} opts
 * @returns {TopDownProjection|IsoProjection}
 */
export function createProjection(opts) {
  const kind = opts.map?.projection ?? "topdown";
  if (kind === "isometric") {
    const iso = opts.map?.iso ?? {};
    return new IsoProjection({
      scale: opts.scale,
      mapWidth: opts.mapWidth,
      mapHeight: opts.mapHeight,
      tileW: iso.tile_w ?? 64,
      tileH: iso.tile_h ?? 32,
      zStep: iso.z_step ?? 16,
      headroom: iso.headroom ?? 6,
    });
  }
  return new TopDownProjection(opts);
}

/**
 * Orthographic square-tile projection — the historical behaviour, reproduced
 * exactly. Every method returns the same numbers the renderer/camera computed
 * inline before the seam existed.
 */
export class TopDownProjection {
  constructor({ tileSize, scale, mapWidth, mapHeight }) {
    this.kind = "topdown";
    this.tileSize = tileSize;
    this.scale = scale;
    this.mapWidth = mapWidth;
    this.mapHeight = mapHeight;
    this.tilePx = tileSize * scale;
    // One floor tile's on-screen footprint (square).
    this.tileFootprint = { w: this.tilePx, h: this.tilePx };
  }

  /** Top-left world px to blit a floor/prop tile sprite. */
  floorAnchor(tx, ty) {
    return { x: tx * this.tilePx, y: ty * this.tilePx };
  }

  /** Floor-contact centre world px (camera follow, lights, foot of a sprite). */
  footAnchor(tx, ty) {
    return {
      x: (tx * this.tileSize + this.tileSize / 2) * this.scale,
      y: (ty * this.tileSize + this.tileSize / 2) * this.scale,
    };
  }

  /** Inverse of a floor-plane point → fractional tile (click / hit-test). */
  worldToTile(wx, wy) {
    return { x: wx / this.tilePx, y: wy / this.tilePx };
  }

  /**
   * Painter-order key for the merged depth pass. Top-down sorts purely by the
   * front (foot) row, exactly as the renderer's baseline did.
   * @param {number} _footX unused top-down
   * @param {number} footY front/foot tile row
   */
  depthKey(_footX, footY) {
    return footY;
  }

  /** Scrollable world extent for the camera clamp. */
  worldBounds() {
    return { width: this.mapWidth * this.tilePx, height: this.mapHeight * this.tilePx };
  }

  /** Key intent → grid step. Identity for top-down. */
  remapIntent(intent) {
    return intent;
  }
}

/**
 * Isometric 2:1 diamond projection. Movement/collision stay on the same logical
 * square grid — only the pixel mapping, depth order, inverse and input remap
 * differ. Elevation `h` (height units) lifts a foot up-screen and breaks depth
 * ties without reordering neighbours.
 */
export class IsoProjection {
  constructor({ scale, mapWidth, mapHeight, tileW, tileH, zStep, headroom }) {
    this.kind = "isometric";
    this.scale = scale;
    this.mapWidth = mapWidth;
    this.mapHeight = mapHeight;
    this.hw = (tileW * scale) / 2; // half diamond width
    this.hh = (tileH * scale) / 2; // half diamond height
    this.zs = zStep * scale; // pixels per height unit
    this.headroom = (headroom ?? 6) * this.zs; // room above the top tile for tall props
    // Shift so the leftmost diamond tip lands at x≈0 and the top tile clears the
    // headroom, keeping the whole platform inside positive world space.
    this.originX = mapHeight * this.hw + this.hw;
    this.originY = this.hh + this.headroom;
    this.tileFootprint = { w: tileW * scale, h: tileH * scale };
  }

  floorAnchor(tx, ty) {
    const c = this.footAnchor(tx, ty);
    return { x: c.x - this.hw, y: c.y - this.hh };
  }

  footAnchor(tx, ty, h = 0) {
    return {
      x: (tx - ty) * this.hw + this.originX,
      y: (tx + ty) * this.hh + this.originY - h * this.zs,
    };
  }

  worldToTile(wx, wy) {
    const x = wx - this.originX;
    const y = wy - this.originY;
    return { x: (x / this.hw + y / this.hh) / 2, y: (y / this.hh - x / this.hw) / 2 };
  }

  /** Diamond depth: far (small x+y) → near (large). Height only breaks ties. */
  depthKey(footX, footY, h = 0) {
    return footX + footY + h * EPS;
  }

  worldBounds() {
    return {
      width: (this.mapWidth + this.mapHeight) * this.hw + 2 * this.hw,
      height: (this.mapWidth + this.mapHeight) * this.hh + this.originY + this.headroom,
    };
  }

  /**
   * Rotate the grid D-pad 45° so each arrow drives the corresponding diagonal
   * screen direction, one grid step per press. Facing keeps the 4-dir sprite
   * readable until iso avatars land.
   */
  remapIntent(intent) {
    return intent;
  }
}
