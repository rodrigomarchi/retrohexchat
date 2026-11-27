/**
 * Hex Jungle's map, as the player's legs know it: which screen and which
 * floor can be reached from which, and about how long each takes. The
 * computer player asks it the way to the nearest treasure still lying.
 *
 * A place is a screen on the jungle's floor, or in the tunnel under it
 * heading one way. Underground a step is three of the surface's screens; a
 * ladder screen's tunnel has a wall on one side, which turns back whoever
 * walks into it, so the tunnel there leads only away from it.
 *
 * @module games/hex_jungle/route
 */

import { decodeScene, stepScreens, treasureSlot } from "./world.js";

/** Ticks to walk a screen's width, at a pixel every two ticks. */
const WALK = 280;
/** About how long each thing on a screen holds a walker up, in ticks. */
const DELAY = { vine: 160, shifting: 140, crocodiles: 140, log: 30, fire: 10, snake: 10 };
const LADDER_TRIP = 220;
const SCORPION = 40;

/** A place's key: the screen, the floor, and underground the way it heads. */
export const placeKey = (screen, underground, heading = 0) =>
  `${screen}|${underground ? 1 : 0}|${underground ? heading : 0}`;

function surfaceDelay(scene) {
  if (scene.pit?.crocodiles) return DELAY.crocodiles;
  if (scene.pit?.shifting) return DELAY.shifting;
  if (scene.pit) return DELAY.vine;
  return DELAY[scene.hazard?.kind] ?? 0;
}

/**
 * The places one move from `place`, each with what it takes.
 * @param {{ screen: number, underground: boolean, heading: number }} place
 * @returns {{ place: object, ticks: number, move: object }[]}
 */
export function neighbours({ screen, underground, heading }) {
  const scene = decodeScene(screen);
  const moves = [];
  if (!underground) {
    for (const dir of [1, -1]) {
      moves.push({
        place: { screen: stepScreens(screen, 1, dir), underground: false, heading: 0 },
        ticks: WALK + surfaceDelay(scene),
        move: { kind: "exit", dir },
      });
    }
    if (scene.ladder) {
      // Down the ladder, then away from the wall.
      const away = scene.underground.wall === "left" ? 1 : -1;
      moves.push({
        place: { screen, underground: true, heading: away },
        ticks: LADDER_TRIP,
        move: { kind: "descend" },
      });
    }
    return moves;
  }

  const wall = scene.underground.wall === "left" ? -1 : scene.underground.wall === "right" ? 1 : 0;
  if (scene.ladder) {
    moves.push({
      place: { screen, underground: false, heading: 0 },
      ticks: LADDER_TRIP,
      move: { kind: "climb" },
    });
  }
  if (wall !== heading) {
    const next = stepScreens(screen, 3, heading);
    const nextScene = decodeScene(next);
    const nextWall =
      nextScene.underground.wall === "left" ? -1 : nextScene.underground.wall === "right" ? 1 : 0;
    // A wall by the edge one comes in at turns them straight back.
    if (!(nextScene.ladder && nextWall === -heading)) {
      moves.push({
        place: { screen: next, underground: true, heading },
        ticks: WALK + (scene.underground.scorpion ? SCORPION : 0),
        move: { kind: "exit", dir: heading },
      });
    }
  }
  if (wall !== -heading) {
    moves.push({
      place: { screen, underground: true, heading: -heading },
      ticks: WALK / 2,
      move: { kind: "turn" },
    });
  }
  return moves;
}

/**
 * The way from `from` to the nearest screen whose treasure still lies, as the
 * first move to make and the screen it leads to; null when none can be reached.
 * @param {{ screen: number, underground: boolean, heading: number }} from
 * @param {number} taken - the record of treasures taken, a bit each
 * @returns {{ move: object, next: object, target: number, ticks: number } | null}
 */
export function wayToTreasure(from, taken) {
  const lies = (screen) =>
    !!decodeScene(screen).treasure && ((taken >>> treasureSlot(screen)) & 1) === 0;
  if (!from.underground && lies(from.screen)) {
    return { move: { kind: "treasure" }, next: from, target: from.screen, ticks: 0 };
  }
  const start = placeKey(from.screen, from.underground, from.heading);
  const best = new Map([[start, 0]]);
  const first = new Map();
  const frontier = [{ place: from, ticks: 0, key: start }];
  while (frontier.length > 0) {
    frontier.sort((a, b) => a.ticks - b.ticks);
    const { place, ticks, key } = frontier.shift();
    if (ticks > best.get(key)) continue;
    if (key !== start && !place.underground && lies(place.screen)) {
      return { ...first.get(key), target: place.screen, ticks };
    }
    for (const step of neighbours(place)) {
      const nextKey = placeKey(step.place.screen, step.place.underground, step.place.heading);
      const total = ticks + step.ticks;
      if (total >= (best.get(nextKey) ?? Infinity)) continue;
      best.set(nextKey, total);
      first.set(nextKey, key === start ? { move: step.move, next: step.place } : first.get(key));
      frontier.push({ place: step.place, ticks: total, key: nextKey });
    }
  }
  return null;
}
