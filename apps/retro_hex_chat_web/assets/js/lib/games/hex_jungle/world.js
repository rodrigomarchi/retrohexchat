/**
 * Hex Jungle's world: 255 screens in a ring, each one described whole by a
 * byte. The neighbouring screen's byte comes from an 8-bit linear feedback
 * shift register that steps both ways, so only the current byte is kept;
 * underground a screen is three of the surface's.
 *
 * @module games/hex_jungle/world
 */

import { LADDER_HOLE, SCENE, SIDE_HOLES, TREASURE } from "./protocol.js";

const bit = (r, n) => (r >> n) & 1;

/**
 * The screen to the right.
 * @param {number} r - this screen's byte, 1–255
 * @returns {number}
 */
export function stepRight(r) {
  return ((r << 1) | (bit(r, 3) ^ bit(r, 4) ^ bit(r, 5) ^ bit(r, 7))) & 0xff;
}

/**
 * The screen to the left: the step right, undone.
 * @param {number} r
 * @returns {number}
 */
export function stepLeft(r) {
  return (r >> 1) | ((bit(r, 4) ^ bit(r, 5) ^ bit(r, 6) ^ bit(r, 0)) << 7);
}

/**
 * `count` screens along, to the right (1) or the left (-1).
 * @param {number} r
 * @param {number} count
 * @param {1|-1} direction
 * @returns {number}
 */
export function stepScreens(r, count, direction) {
  const step = direction > 0 ? stepRight : stepLeft;
  let screen = r;
  for (let i = 0; i < count; i++) screen = step(screen);
  return screen;
}

const PITS = {
  [SCENE.TAR]: { kind: "tar", shifting: false, crocodiles: false },
  [SCENE.SWAMP]: { kind: "swamp", shifting: false, crocodiles: false },
  [SCENE.CROCODILES]: { kind: "swamp", shifting: false, crocodiles: true },
  [SCENE.TREASURE_TAR]: { kind: "tar", shifting: true, crocodiles: false },
  [SCENE.SHIFTING_TAR]: { kind: "tar", shifting: true, crocodiles: false },
  [SCENE.QUICKSAND]: { kind: "quicksand", shifting: true, crocodiles: false },
};

const VINES = new Set([SCENE.TAR, SCENE.SWAMP, SCENE.SHIFTING_TAR]);

const HAZARDS = [
  { kind: "log", count: 1, rolling: true, spread: "close" },
  { kind: "log", count: 2, rolling: true, spread: "close" },
  { kind: "log", count: 2, rolling: true, spread: "wide" },
  { kind: "log", count: 3, rolling: true, spread: "close" },
  { kind: "log", count: 1, rolling: false, spread: "close" },
  { kind: "log", count: 3, rolling: false, spread: "close" },
  { kind: "fire" },
  { kind: "snake" },
];

const TREASURES = [TREASURE.MONEY, TREASURE.SILVER, TREASURE.GOLD, TREASURE.RING];

/**
 * Everything a screen holds, read from its byte.
 * @param {number} byte
 * @returns {{
 *   scene: number, trees: number, ladder: boolean, holes: number[][],
 *   pit: { kind: string, shifting: boolean, crocodiles: boolean } | null,
 *   vine: boolean, hazard: object | null, treasure: object | null,
 *   underground: { wall: "left" | "right" | null, scorpion: boolean },
 * }}
 */
export function decodeScene(byte) {
  const scene = (byte >> 3) & 7;
  const object = byte & 7;
  const ladder = scene === SCENE.LADDER || scene === SCENE.LADDER_HOLES;
  const holes = !ladder
    ? []
    : scene === SCENE.LADDER
      ? [[...LADDER_HOLE]]
      : [[...SIDE_HOLES[0]], [...LADDER_HOLE], [...SIDE_HOLES[1]]];
  const crocodiles = scene === SCENE.CROCODILES;
  const treasureScene = scene === SCENE.TREASURE_TAR;

  return {
    scene,
    trees: (byte >> 6) & 3,
    ladder,
    holes,
    pit: PITS[scene] ? { ...PITS[scene] } : null,
    vine: VINES.has(scene) || (crocodiles && bit(object, 1) === 1),
    hazard: crocodiles || treasureScene ? null : { ...HAZARDS[object] },
    treasure: treasureScene ? TREASURES[object & 3] : null,
    underground: ladder
      ? { wall: bit(byte, 7) ? "right" : "left", scorpion: false }
      : { wall: null, scorpion: true },
  };
}

/**
 * Where a treasure screen's treasure is kept in the record of those taken:
 * bits 6–7 pick one of four bytes, bits 0–2 a bit in it.
 * @param {number} byte - a treasure screen's byte
 * @returns {number} 0–31
 */
export function treasureSlot(byte) {
  return ((byte >> 6) & 3) * 8 + (byte & 7);
}
