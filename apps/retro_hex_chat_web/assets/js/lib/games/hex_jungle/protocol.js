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

/** The floors: the jungle's ground, and the tunnel's below it. */
export const GROUND_Y = 32;
export const UNDER_Y = 86;

/** Where a player can stand before the screen changes, and where they start. */
export const EDGE_MIN = 8;
export const EDGE_MAX = 148;
export const START_X = 20;

/** A pixel of running every this many ticks: 30 pixels a second. */
export const WALK_EVERY = 2;

/**
 * A jump, as lines moved each tick (up positive): it rises 10 lines over 16
 * ticks and comes down over 16 more, after a line of lift as it leaves.
 */
export const JUMP_LIFT = 1;
export const JUMP_TABLE = Object.freeze([
  1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 0, 1, 0, 0, 0, 1, -1, 0, 0, 0, -1, 0, 0, -1, 0, -1, -1, -1, -1, -1,
  -1, -1,
]);
/** The jump's direction is still the player's to choose for this many ticks. */
export const JUMP_STEER_TICKS = 2;

export const START_SCORE = 2000;
export const START_LIVES = 3;
/** Twenty minutes. */
export const TIME_TICKS = 20 * 60 * 60;

/** The phases of an expedition. */
export const PHASE = Object.freeze({
  WAITING: 0,
  PLAYING: 1,
  DYING: 2,
  RESPAWN: 3,
  FINISHED: 4,
});

/** The screen's width, which rolling logs come back round across. */
export const SCREEN_W = 160;

/** A pit's span, and how far into it the player sinks before it is over. */
export const PIT = Object.freeze([44, 107]);
export const PIT_DEATH_Y = 54;
export const HOLE_POINTS = 100;

/**
 * A shifting pit's cycle, counted on the expedition's clock: it narrows in
 * five stages of four ticks, stays shut, opens back the same way, and stays
 * open. Each stage moves both edges in by its inset.
 */
export const SHIFT_CYCLE = 256;
export const SHIFT_STAGE_TICKS = 4;
export const SHIFT_INSETS = Object.freeze([0, 4, 8, 16, 28]);
export const SHIFT_SHUT_FROM = 20;
export const SHIFT_OPENING_FROM = 172;
export const SHIFT_OPEN_FROM = 192;

/**
 * Crocodiles: jaws shut for the first half of every 256 ticks, open for the
 * second. Shut, their heads are firm ground; open, only their eyes are.
 */
export const CROC_CYCLE = 256;
export const CROC_SHUT_TICKS = 128;
export const CROC_HEADS_SHUT = Object.freeze([
  Object.freeze([56, 63]),
  Object.freeze([72, 79]),
  Object.freeze([88, 95]),
]);
export const CROC_HEADS_OPEN = Object.freeze([
  Object.freeze([62, 63]),
  Object.freeze([78, 79]),
  Object.freeze([94, 95]),
]);

/**
 * What lies on the ground stands at x 124: logs, fire, a snake, a treasure.
 * Logs lie 16 pixels apart, or 32 when spread wide, and roll a pixel left
 * every second tick.
 */
export const OBJECT_X = 124;
export const LOG_SPACING = Object.freeze({ close: 16, wide: 32 });
export const LOG_ROLL_EVERY = 2;

/**
 * What touches what: the player's body is a column 4 pixels wide and 22
 * lines tall standing on its feet; a log lies 8 wide and 4 tall, fire and a
 * snake stand 8 wide and 6 tall.
 */
export const BODY = Object.freeze({ w: 4, h: 22 });
export const LOG_BOX = Object.freeze({ w: 8, h: 4 });
export const OBJECT_BOX = Object.freeze({ w: 8, h: 6 });
