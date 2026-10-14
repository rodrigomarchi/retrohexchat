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
    // Color-math lighting: additive radial pools + an optional ambient multiply
    // wash. Empty/absent on maps that don't opt in (they render at full bright).
    this.lights = Array.isArray(definition.lights) ? definition.lights : [];
    this.ambient = definition.ambient ?? null;
    // Isometric slabs: one 3D underside {hull, thickness, taper} per solid
    // block (platforms, bridges). A legacy single `slab` wraps into the list;
    // empty when a map defines none → no side faces. Vignette is screen-space.
    this.slabs = normalizeSlabs(definition);
    this.vignette = definition.vignette ?? null;
    // The cosmic sea abyss behind a floating platform (deep-blue rippling void).
    this.sea = definition.sea ?? null;
    // Iso railing: edge cells [{x,y,edge}] the renderer draws by blitting the
    // matching sheared wall tile so they abut into one seam-free wrought-iron
    // fence, plus corner posts [{x,y,corner}] capping the four diamond vertices.
    this.railings = Array.isArray(definition.railings) ? definition.railings : [];
    this.railingPosts = Array.isArray(definition.railing_posts) ? definition.railing_posts : [];
    this.spawns = Array.isArray(definition.spawn) ? definition.spawn : [];
    this.labels = Array.isArray(definition.labels) ? definition.labels : [];
    // The colour painted behind everything; absent → the renderer's dark void.
    this.backdrop = typeof definition.backdrop === "string" ? definition.backdrop : null;
    // A Construct's building rules: what can be placed (kind → tiles per
    // facing), the tiles nobody may build on, and how many pieces it holds.
    this.catalog = isObject(definition.catalog) ? definition.catalog : null;
    this.maxItems = Number.isInteger(definition.max_items) ? definition.max_items : 0;
    this._reserved = new Set(
      (Array.isArray(definition.reserved) ? definition.reserved : []).map((r) => tileKey(r.x, r.y)),
    );
    this.items = Array.isArray(definition.items) ? definition.items : [];
    // The edit the definition already includes; only a newer patch applies.
    this.revision = Number.isInteger(definition.revision) ? definition.revision : 0;

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

  /** @returns {boolean} whether the map is a Construct people can build in. */
  buildable() {
    return this.catalog !== null;
  }

  /** @returns {boolean} whether the tile is kept clear (the gate, the spawns). */
  isReserved(x, y) {
    return this._reserved.has(tileKey(x, y));
  }

  /** @returns {object|null} the placed piece standing on a tile. */
  itemAt(x, y) {
    return this.items.find((item) => item.x === x && item.y === y) ?? null;
  }

  /** @returns {object|null} a placed piece by id. */
  item(id) {
    return this.items.find((item) => item.id === id) ?? null;
  }

  /** @returns {string|null} the tile a kind is drawn with in a facing. */
  kindTile(kind, dir = "down") {
    const tiles = this.catalog?.[kind]?.tiles;
    return tiles?.[dir] ?? tiles?.down ?? null;
  }

  /**
   * Redraw a Construct from a `construct_layout` patch: the pieces and every
   * part of the map they change. A patch no newer than the one already shown
   * is dropped, so a late broadcast can never roll the room back.
   * @param {{revision:number, items:object[], decor:object[], collision:object[], seats:object[], lights:object[], labels:object[], interactables:object[]}} patch
   * @returns {boolean} whether the patch was applied
   */
  applyPatch(patch) {
    if (!patch || !(patch.revision > this.revision)) return false;
    this.revision = patch.revision;
    this.items = patch.items;
    this.layers = { ...this.layers, decor: patch.decor, floor: patch.floor ?? this.layers.floor };
    this.decor = patch.decor;
    this.lights = patch.lights;
    this._blocked = buildCollisionSet(patch.collision);
    this._seats = indexById(patch.seats);
    this.labels = patch.labels;
    this._interactables = indexById(patch.interactables);
    return true;
  }

  /** @returns {{x:number,y:number,dir:string}} first spawn, or origin. */
  defaultSpawn() {
    const spawn = this.spawns[0];
    if (!spawn) return { x: 0, y: 0, dir: "down" };
    return { x: spawn.x, y: spawn.y, dir: spawn.dir ?? "down" };
  }
}

function normalizeSlabs(definition) {
  if (Array.isArray(definition.slabs)) return definition.slabs.filter((s) => s?.hull);
  return definition.slab?.hull ? [definition.slab] : [];
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

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function tileKey(x, y) {
  return `${x},${y}`;
}
