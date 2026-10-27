/**
 * Hex FreeCell — the game's constants. A one-player game never goes on the
 * wire, so this holds no schema: only the table's rules and numbers, by name.
 *
 * Time is 60 Hz ticks; positions are the canvas's pixels.
 *
 * @module games/hex_freecell/protocol
 */

import { BONUS_MIN_SECONDS, BONUS_NUMERATOR, TIME_PENALTY } from "../core/card_table/clock.js";

/** The table: eight columns, four free cells, four foundations. */
export const COLUMNS = 8;
export const CELLS = 4;

/** The points, by what earns or costs them. */
export const POINTS = Object.freeze({
  TO_FOUNDATION: 10,
  FOUNDATION_BACK: -15,
  TIME_PENALTY,
});

/**
 * The most a game can score: all 52 cards up (10 each) and the bonus of a
 * win in thirty seconds. The server refuses more.
 */
export const CEILING = 52 * POINTS.TO_FOUNDATION + Math.floor(BONUS_NUMERATOR / BONUS_MIN_SECONDS);
