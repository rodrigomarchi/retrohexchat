/**
 * Client-side index over the authoritative map definition received in
 * `space_init`. The client keeps no map of its own — it only builds fast
 * lookups (collision Set, zone/seat/interactable maps) over the exact
 * structure the server sent, so visual collision can never diverge from the
 * server's movement rules.
 * @module space/map
 */

export class SpaceMap {
  /**
   * @param {object} definition serialized map from `space_init.map`
   * @returns {SpaceMap}
   */
  static from(definition) {
    return new SpaceMap(definition ?? {});
  }

  constructor(definition) {
    this.id = definition.id ?? null;
    this.version = definition.version ?? 1;
    this.width = definition.width ?? 0;
    this.height = definition.height ?? 0;
    this.tileSize = definition.tile_size ?? definition.tileSize ?? 16;
    // Opaque base tile drawn under every floor cell so props with transparent
    // pixels (bushes, flowers) composite over ground instead of the backdrop.
    this.ground = definition.ground ?? null;
    this.layers = definition.layers ?? { floor: [], decor: [], above: [] };
    // Multi-tile props (houses, big trees) drawn as whole sprites over the floor.
    this.decor = Array.isArray(this.layers.decor) ? this.layers.decor : [];
    this.spawns = Array.isArray(definition.spawn) ? definition.spawn : [];
    this.labels = Array.isArray(definition.labels) ? definition.labels : [];

    this._blocked = buildCollisionSet(definition.collision);
    this._zones = Array.isArray(definition.zones) ? definition.zones : [];
    this._seats = indexById(definition.seats);
    this._interactables = indexById(definition.interactables);
  }

  /** @returns {boolean} whether the tile lies within the map bounds. */
  inBounds(x, y) {
    return x >= 0 && y >= 0 && x < this.width && y < this.height;
  }

  /** @returns {boolean} whether movement onto the tile is blocked. */
  isBlocked(x, y) {
    if (!this.inBounds(x, y)) return true;
    return this._blocked.has(tileKey(x, y));
  }

  /** @returns {object|null} the zone containing the tile, if any. */
  zoneAt(x, y) {
    for (const zone of this._zones) {
      if (x >= zone.x && x < zone.x + zone.w && y >= zone.y && y < zone.y + zone.h) {
        return zone;
      }
    }
    return null;
  }

  /** @returns {object|null} seat by id. */
  seat(id) {
    return this._seats.get(id) ?? null;
  }

  /** @returns {object|null} interactable by id. */
  interactable(id) {
    return this._interactables.get(id) ?? null;
  }

  /** @returns {object[]} all interactables. */
  interactables() {
    return [...this._interactables.values()];
  }

  /** @returns {object[]} all seats. */
  seats() {
    return [...this._seats.values()];
  }

  /**
   * Floor tile id at a tile, from the `layers.floor` matrix. Cells the matrix
   * does not cover fall back to the opaque ground tile.
   * @returns {string|null}
   */
  floorTile(x, y) {
    const row = this.layers?.floor?.[y];
    const id = row?.[x];
    return typeof id === "string" ? id : this.ground;
  }

  /** @returns {{x:number,y:number,dir:string}} first spawn, or origin. */
  defaultSpawn() {
    const spawn = this.spawns[0];
    if (!spawn) return { x: 0, y: 0, dir: "down" };
    return { x: spawn.x, y: spawn.y, dir: spawn.dir ?? "down" };
  }
}

function buildCollisionSet(rects) {
  const set = new Set();
  if (!Array.isArray(rects)) return set;

  for (const rect of rects) {
    const w = rect.w ?? 1;
    const h = rect.h ?? 1;
    for (let dx = 0; dx < w; dx += 1) {
      for (let dy = 0; dy < h; dy += 1) {
        set.add(tileKey(rect.x + dx, rect.y + dy));
      }
    }
  }
  return set;
}

function indexById(items) {
  const map = new Map();
  if (Array.isArray(items)) {
    for (const item of items) {
      if (item && item.id !== undefined && item.id !== null) map.set(item.id, item);
    }
  }
  return map;
}

function tileKey(x, y) {
  return `${x},${y}`;
}
