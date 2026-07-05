/**
 * Camera that follows the local avatar and clamps to the map edges. Works in
 * world pixels (tile * tileSize * scale) and converts to screen space for the
 * renderer.
 * @module space/camera
 */

export class Camera {
  /**
   * @param {{tileSize:number, scale:number, mapWidth:number, mapHeight:number}} opts
   */
  constructor({ tileSize, scale, mapWidth, mapHeight }) {
    this.tileSize = tileSize;
    this.scale = scale;
    this.worldWidth = mapWidth * tileSize * scale;
    this.worldHeight = mapHeight * tileSize * scale;
    this.viewportWidth = 0;
    this.viewportHeight = 0;
    this.x = 0;
    this.y = 0;
  }

  setViewport(width, height) {
    this.viewportWidth = width;
    this.viewportHeight = height;
  }

  /** Center on a tile, clamped so the view never leaves the world. */
  follow(tileX, tileY) {
    const px = (tileX * this.tileSize + this.tileSize / 2) * this.scale;
    const py = (tileY * this.tileSize + this.tileSize / 2) * this.scale;
    this.x = clamp(px - this.viewportWidth / 2, this.worldWidth - this.viewportWidth);
    this.y = clamp(py - this.viewportHeight / 2, this.worldHeight - this.viewportHeight);
  }

  /** @returns {{x:number,y:number}} screen-space coordinate of a world point. */
  worldToScreen(worldX, worldY) {
    return { x: worldX - this.x, y: worldY - this.y };
  }
}

// Clamp to [0, max]; when max is negative (world smaller than viewport) pin to 0.
function clamp(value, max) {
  if (max <= 0) return 0;
  if (value < 0) return 0;
  if (value > max) return max;
  return value;
}
