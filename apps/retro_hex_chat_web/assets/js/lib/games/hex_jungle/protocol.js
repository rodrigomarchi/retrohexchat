/**
 * Hex Jungle — the game's constants. A one-player game never goes on the
 * wire, so this holds no schema: only the world's numbers, by name.
 *
 * Units are the original cartridge's: x in its pixels (0–159), y in lines
 * growing downwards, time in 60 Hz ticks. The renderer scales them.
 *
 * @module games/hex_jungle/protocol
 */

/** The screen the expedition starts on, and how many the ring holds. */
export const SEED = 0xc4;
export const SCREENS = 255;

/** What a screen's ground holds, from bits 3–5 of its byte. */
export const SCENE = Object.freeze({
  LADDER: 0,
  LADDER_HOLES: 1,
  TAR: 2,
  SWAMP: 3,
  CROCODILES: 4,
  TREASURE_TAR: 5,
  SHIFTING_TAR: 6,
  QUICKSAND: 7,
});

/** The four treasures; eight of each lie in the jungle. */
export const TREASURE = Object.freeze({
  MONEY: Object.freeze({ kind: "money", points: 2000 }),
  SILVER: Object.freeze({ kind: "silver", points: 3000 }),
  GOLD: Object.freeze({ kind: "gold", points: 4000 }),
  RING: Object.freeze({ kind: "ring", points: 5000 }),
});

/** Where the holes in the ground are, inclusive. */
export const LADDER_HOLE = Object.freeze([72, 79]);
export const SIDE_HOLES = Object.freeze([Object.freeze([44, 55]), Object.freeze([96, 107])]);
