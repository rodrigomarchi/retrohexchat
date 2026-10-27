/**
 * Hex Solitaire — the game's constants. A one-player game never goes on the
 * wire, so this holds no schema: only the table's rules and numbers, by name.
 *
 * Time is 60 Hz ticks; positions are the canvas's 640×480 pixels.
 *
 * @module games/hex_solitaire/protocol
 */

import { TIME_PENALTY } from "../core/solo/clock.js";

/** How many cards the stock turns at a time, by the variant played. */
export const MODE = Object.freeze({ DRAW1: 1, DRAW3: 3 });

/** The variant each catalogue id plays. */
export const MODE_BY_GAME = Object.freeze({
  hex_solitaire: MODE.DRAW1,
  hex_solitaire_draw3: MODE.DRAW3,
});

/** The table's columns, and how many cards the deal lays in the last. */
export const COLUMNS = 7;

/** The classic scoring's points, by what earns or costs them. */
export const POINTS = Object.freeze({
  WASTE_TO_TABLEAU: 5,
  TO_FOUNDATION: 10,
  FLIP: 5,
  FOUNDATION_TO_TABLEAU: -15,
  RECYCLE: Object.freeze({ [MODE.DRAW1]: -100, [MODE.DRAW3]: -20 }),
  TIME_PENALTY,
});

/** The clock every card table keeps: what ten seconds cost, the hour's limit, the bonus. */
export {
  BONUS_MIN_SECONDS,
  BONUS_NUMERATOR,
  PENALTY_TICKS,
  SAFETY_TICKS,
} from "../core/solo/clock.js";

/**
 * The most a game can score: all 52 cards up (10 each), the 21 cards dealt
 * face down turned (5 each), the 24 of the stock played onto the table
 * (5 each), and the bonus of a win in thirty seconds. The server refuses more.
 */
export const CEILING = 24_078;

/** The picture the game draws, whatever size the page shows it at. */
export const VIEW = Object.freeze({ width: 640, height: 480 });

/** A card, and the table's measures around it. */
export const CARD = Object.freeze({ width: 64, height: 88 });
export const TABLE = Object.freeze({
  left: 48, // the first column's x
  gap: 16, // between two columns
  top: 28, // the stock, the waste and the foundations
  columnsTop: 132, // the seven columns
  bottom: 8, // the felt kept below the longest column
  downOffset: 6, // how much of a face-down card shows under the next
  upOffset: 18, // how much of a face-up card shows under the next
  minOffset: 4, // the least a squeezed column shows of a card
  fanOffset: 14, // the waste's showing cards, drawing three
});

/** Which column each pile at the top stands over. */
export const TOP_ROW = Object.freeze({ stock: 0, waste: 1, foundations: [3, 4, 5, 6] });

/**
 * The two tables the game is laid out on: lying down, as on a desktop's
 * window, and standing up, for a phone held upright — the seven columns
 * across its whole width, so the cards are as big as a phone allows, and
 * the height the columns grow into. The cards are the same; only the table
 * around them changes.
 */
export const GEOMETRY = Object.freeze({
  LANDSCAPE: Object.freeze({
    view: VIEW,
    left: TABLE.left,
    gap: TABLE.gap,
    top: TABLE.top,
    columnsTop: TABLE.columnsTop,
  }),
  PORTRAIT: Object.freeze({
    view: Object.freeze({ width: 464, height: 720 }),
    left: 2,
    gap: 2,
    top: 30,
    columnsTop: 128,
    // The height a phone gives: more of each card shows in a column, easier
    // to read and to press.
    downOffset: 8,
    upOffset: 24,
  }),
});

/** The match's phases, its events and the celebration's length: every card table's. */
export { CELEBRATION_TICKS, PHASE, TAP_SLOP } from "../core/solo/phases.js";
export { EVENT } from "../core/card_table/events.js";

/** How long each effect lasts: every card table's. */
export { FX } from "../core/card_table/effects.js";

/** The finish with nothing left hidden: a card goes up every this many ticks. */
export const AUTO_TICKS = 6;
