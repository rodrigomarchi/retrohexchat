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

/** What happened in a tick, one bit each: the sounds (by name) and the effects read them. */
export const EVENT = Object.freeze({
  DEAL: 1,
  PLACE: 2,
  FOUNDATION: 4,
  REFUSE: 8,
  RETURN: 16,
  WIN: 32,
});

/** Cards going up by themselves — the safe ones in play, all of them at the end: one every this many ticks. */
export const AUTO_TICKS = 6;

/**
 * The two tables the game is laid out on: lying down on a desktop's window,
 * with the full cards, and standing up for a phone held upright, with the
 * minis, so the eight columns read on a phone's width.
 */
export const GEOMETRY = Object.freeze({
  LANDSCAPE: Object.freeze({
    view: Object.freeze({ width: 640, height: 480 }),
    size: "full",
    card: Object.freeze({ width: 64, height: 88 }),
    left: 29,
    gap: 10,
    top: 30,
    columnsTop: 132,
    upOffset: 18,
    minOffset: 6,
    bottom: 8,
  }),
  PORTRAIT: Object.freeze({
    view: Object.freeze({ width: 464, height: 760 }),
    size: "mini",
    card: Object.freeze({ width: 44, height: 62 }),
    left: 14,
    gap: 12,
    top: 30,
    columnsTop: 104,
    // The phone's height: more of each card shows, easier to read and to press.
    upOffset: 24,
    minOffset: 6,
    bottom: 8,
  }),
});
