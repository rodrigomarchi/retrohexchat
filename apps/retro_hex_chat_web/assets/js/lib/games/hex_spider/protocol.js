/**
 * Hex Spider — the game's constants. A one-player game never goes on the
 * wire, so this holds no schema: only the table's rules and numbers, by name.
 *
 * Time is 60 Hz ticks; positions are the canvas's pixels.
 *
 * @module games/hex_spider/protocol
 */

import { FULL_CARD, MINI_CARD } from "../core/cards.js";
/** How many suits each catalogue id deals. */
export const SUITS_BY_GAME = Object.freeze({
  hex_spider: 1,
  hex_spider_2suits: 2,
  hex_spider_4suits: 4,
});

/** The table: ten columns, the first four dealt six cards, the rest five. */
export const COLUMNS = 10;
export const DEALT = Object.freeze([6, 6, 6, 6, 5, 5, 5, 5, 5, 5]);

/** A whole suit, king to ace: what goes up to a foundation. */
export const SUIT_LENGTH = 13;
export const FOUNDATIONS = 8;

/** The points, as Windows kept them: a start, a cost per move, a prize per suit. */
export const POINTS = Object.freeze({ START: 500, MOVE: -1, COMPLETE: 100 });

/** The most a game can score: the start and every suit up. The server refuses more. */
export const CEILING = POINTS.START + FOUNDATIONS * POINTS.COMPLETE;

/** What happened in a tick: every card table's events (`core/card_table/phases.js`). */
export { EVENT } from "../core/card_table/phases.js";

/**
 * The two tables the game is laid out on: lying down on a desktop's window,
 * wider than the others (ten columns of full cards), and standing up for a
 * phone held upright, with the minis. The columns hang from the top; the
 * suits completed and the stock wait along the bottom, as on Windows.
 */
export const GEOMETRY = Object.freeze({
  LANDSCAPE: Object.freeze({
    view: Object.freeze({ width: 720, height: 540 }),
    size: "full",
    card: FULL_CARD,
    left: 13,
    gap: 6,
    columnsTop: 30,
    downOffset: 6,
    upOffset: 18,
    minOffset: 4,
    bottom: 8,
    stackOffset: 8,
  }),
  PORTRAIT: Object.freeze({
    view: Object.freeze({ width: 464, height: 760 }),
    size: "mini",
    card: MINI_CARD,
    left: 3,
    gap: 2,
    columnsTop: 30,
    downOffset: 6,
    upOffset: 17,
    minOffset: 4,
    bottom: 8,
    stackOffset: 6,
  }),
});
