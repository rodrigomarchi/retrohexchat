/**
 * Hex Mines — the game's constants. A one-player game never goes on the wire,
 * so this holds no schema: only the board's rules and numbers, by name.
 *
 * Time is 60 Hz ticks; positions are the canvas's pixels.
 *
 * @module games/hex_mines/protocol
 */

import { WIN_EVENT } from "../core/solo/phases.js";

/** Each catalogue id's board: its columns, rows and mines. */
export const LEVEL = Object.freeze({
  hex_mines: Object.freeze({ cols: 9, rows: 9, mines: 10 }),
  hex_mines_intermediate: Object.freeze({ cols: 16, rows: 16, mines: 40 }),
  hex_mines_expert: Object.freeze({ cols: 30, rows: 16, mines: 99 }),
});

/**
 * A win's points: `NUMERATOR` / its ticks, never counting fewer than
 * `MIN_TICKS` (a second): 1 s is 10,000, 10 s is 1,000. A loss scores nothing.
 */
export const POINTS = Object.freeze({ NUMERATOR: 600_000, MIN_TICKS: 60 });

/** The most a game can score, a win in a second. The server refuses more. */
export const CEILING = POINTS.NUMERATOR / POINTS.MIN_TICKS;

/** An hour: a game still open then ends, with nothing scored. */
export { SAFETY_TICKS } from "../core/solo/clock.js";

/** How long a finger stays still on a square for a flag: 0.4 s. */
export const HOLD_TICKS = 24;

/** What happened in a tick, one bit each: the sounds (by name) and the effects read them. */
export const EVENT = Object.freeze({
  OPEN: 1,
  FLOOD: 2,
  FLAG: 4,
  UNFLAG: 8,
  BOOM: 16,
  WIN: WIN_EVENT,
});

/**
 * Where the game's pictures are served, with the version of their description
 * (`assets/art/mines/build_tiles.py` writes it), so a new atlas is never read
 * from an old cache.
 */
export const TILES_URL = "/images/games/mines/tiles.json?vsn=932d7119f361";
