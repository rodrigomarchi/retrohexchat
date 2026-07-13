/**
 * Projection: the single seam between a logical tile grid and world pixels.
 *
 * The engine renders in two stages — `tile → worldPixel` (this module) and
 * `worldPixel → screen` (`Camera.worldToScreen`, a bare camera-offset subtraction
 * that is projection-agnostic). Isometric is the only projection: anchors, depth
 * order, the inverse (screen→tile) and the input remap all live here.
 *
 * All outputs are in **scaled world pixels** (the render scale folded in) so the
 * camera stays a pure translation.
 *
 * @module space/projection
 */

const EPS = 1e-3;

/**
 * @param {{map?: object, scale:number, mapWidth:number, mapHeight:number}} opts
 * @returns {IsoProjection}
 */
export function createProjection(opts) {
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
   * Movement stays on the logical square grid, so a key intent maps straight to
   * a grid step — the diagonal screen direction falls out of the diamond mapping.
   */
  remapIntent(intent) {
    return intent;
  }
}
