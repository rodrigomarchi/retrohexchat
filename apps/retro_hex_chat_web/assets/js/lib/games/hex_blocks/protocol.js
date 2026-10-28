/**
 * Hex Blocks — the game's constants. A one-player game never goes on the
 * wire, so this holds no schema: only the well's rules and numbers, by name.
 *
 * Time is 60 Hz ticks.
 *
 * @module games/hex_blocks/protocol
 */

import { WIN_EVENT } from "../core/solo/phases.js";

/** Each catalogue id's mode: the Marathon runs until the stack tops out; the Sprint ends at `goal` rows. */
export const MODE = Object.freeze({
  hex_blocks: Object.freeze({ sprint: false, goal: null }),
  hex_blocks_sprint: Object.freeze({ sprint: true, goal: 40 }),
});

/** The well's columns of hexagons. */
export const COLS = 11;

/** The well's zigzag rows, the hidden ones on top included. */
export const ROWS = 21;

/** The rows on top, out of sight, where a piece comes in. */
export const HIDDEN = 2;

/**
 * Where a turn that does not fit is tried next, in order, as `[columns, rows]`
 * the piece moves: beside it, two beside it, a row up.
 */
export const KICKS = Object.freeze([
  [0, 0],
  [-1, 0],
  [1, 0],
  [-2, 0],
  [2, 0],
  [0, -1],
]);

/** The atlas's description, versioned (`assets/art/blocks/build_tiles.py` rewrites it). */
export const TILES_URL = "/images/games/blocks/tiles.json?vsn=47e0ee8c8e46";

/** The pieces shown coming next. */
export const PREVIEW = 3;

/** The count before the first piece: 3, 2, 1, a second each. */
export const COUNTDOWN_TICKS = 180;

/** A move held down repeats after `DELAY` ticks, then every `EVERY`. */
export const REPEAT = Object.freeze({ DELAY: 10, EVERY: 2 });

/** How long a piece rests on the stack before it locks, and how many moves may put that off. */
export const LOCK = Object.freeze({ TICKS: 30, RESETS: 15 });

/** The levels: one more every `LINES_PER` rows cleared, up to `MAX`. */
export const LEVELS = Object.freeze({ LINES_PER: 10, MAX: 20 });

/** Holding down falls this many times faster than the level. */
export const SOFT_FACTOR = 20;

/**
 * Ticks a piece takes to fall a row at `level`: a second at level 1, a
 * twentieth at level 20, the same ratio from each level to the next.
 */
export const fallTicks = (level) => Math.max(3, Math.round(60 * (3 / 60) ** ((level - 1) / 19)));

/** Points of rows cleared at once (by their count), before the level multiplies them. */
export const LINE_POINTS = Object.freeze([0, 100, 300, 600, 1000]);

/** A clear right after a clear: `COMBO` × the run × the level. */
export const COMBO = 50;

/** Points for each row a piece is brought down: held down, or dropped. */
export const DROP_POINTS = Object.freeze({ SOFT: 1, HARD: 2 });

/** A Sprint's win: `NUMERATOR` / its ticks, never fewer than `MIN_TICKS` (30 s): 30 s is 10,000. */
export const SPRINT = Object.freeze({ NUMERATOR: 18_000_000, MIN_TICKS: 1_800 });

/** Three hours: a match still open then ends as it stands. */
export const SAFETY_TICKS = 3 * 60 * 60 * 60;

/** What happened in a tick, one bit each: the sounds (by name) and the effects read them. */
export const EVENT = Object.freeze({
  MOVE: 1,
  TURN: 2,
  LOCK: 4,
  DROP: 8,
  LINE: 16,
  QUAD: 32,
  LEVEL: 64,
  HOLD: 128,
  WIN: WIN_EVENT,
  OVER: 512,
  COUNT: 1024,
  GO: 2048,
});
