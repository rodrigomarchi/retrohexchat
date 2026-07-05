/**
 * Resolving what an avatar is trying to interact with. Interactions target the
 * tile the avatar faces first, then fall back to any adjacent tile — matching
 * the server, which accepts a target the participant is next to.
 * @module space/interactions
 */

const DELTAS = {
  up: { x: 0, y: -1 },
  down: { x: 0, y: 1 },
  left: { x: -1, y: 0 },
  right: { x: 1, y: 0 },
};

/** @returns {{x:number,y:number}} the tile directly ahead of the avatar. */
export function frontTile({ x, y, dir }) {
  const d = DELTAS[dir] ?? DELTAS.down;
  return { x: x + d.x, y: y + d.y };
}

/**
 * Resolve an interactable to `use`: prefer the faced tile, else the nearest
 * adjacent one.
 * @param {import("./map.js").SpaceMap} map
 * @param {{x:number,y:number,dir:string}} participant
 * @returns {{id:string, kind:string, title:string}|null}
 */
export function interactTarget(map, participant) {
  const items = map.interactables ? map.interactables() : [];
  if (!items.length) return null;

  const front = frontTile(participant);
  const faced = items.find((item) => item.x === front.x && item.y === front.y);
  const chosen = faced ?? items.find((item) => isAdjacent(participant, item));
  if (!chosen) return null;

  return { id: chosen.id, kind: chosen.kind, title: chosen.title };
}

export function isAdjacent(a, b) {
  return Math.abs(a.x - b.x) <= 1 && Math.abs(a.y - b.y) <= 1;
}
