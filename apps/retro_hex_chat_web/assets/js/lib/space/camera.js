/**
 * Camera that follows the local avatar and clamps to the map edges. Works in
 * world pixels and converts to screen space for the renderer. The tile→world
 * mapping (the isometric diamond) is delegated to an injected `Projection`; the
 * camera itself is projection-agnostic — `worldToScreen` is a bare offset.
 * @module space/camera
 */

import { createProjection } from "./projection.js";

export class Camera {
  /**
   * @param {{tileSize:number, scale:number, mapWidth:number, mapHeight:number, projection?:object, map?:object}} opts
   */
  constructor({ tileSize, scale, mapWidth, mapHeight, projection, map }) {
    this.tileSize = tileSize;
    this.scale = scale;
    // Isometric is the only projection; build one from the map's iso params when
    // a caller doesn't inject its own.
    this.projection = projection ?? createProjection({ map, tileSize, scale, mapWidth, mapHeight });
    const bounds = this.projection.worldBounds();
    this.worldWidth = bounds.width;
    this.worldHeight = bounds.height;
    this.viewportWidth = 0;
    this.viewportHeight = 0;
    this.x = 0;
    this.y = 0;
  }

  setViewport(width, height) {
    this.viewportWidth = width;
    this.viewportHeight = height;
  }

  /** Center on a tile's foot point, clamped so the view never leaves the world. */
  follow(tileX, tileY) {
    const { x: px, y: py } = this.projection.footAnchor(tileX, tileY);
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
