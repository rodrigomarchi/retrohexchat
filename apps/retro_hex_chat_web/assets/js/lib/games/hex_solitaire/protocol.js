/**
 * Hex Solitaire — the game's constants. A one-player game never goes on the
 * wire, so this holds no schema: only the table's rules and numbers, by name.
 *
 * Time is 60 Hz ticks; positions are the canvas's 640×480 pixels.
 *
 * @module games/hex_solitaire/protocol
 */

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
  TIME_PENALTY: -2,
});

/** Ten seconds of play, each costing `POINTS.TIME_PENALTY`. */
export const PENALTY_TICKS = 600;

/** A win in `BONUS_MIN_SECONDS` or more pays `BONUS_NUMERATOR` / seconds. */
export const BONUS_NUMERATOR = 700_000;
export const BONUS_MIN_SECONDS = 30;

/** An hour: a game still open then ends with the points it has. */
export const SAFETY_TICKS = 60 * 60 * 60;

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

/** The match's phases. */
export const PHASE = Object.freeze({ WAITING: 0, PLAYING: 1, AUTO_FINISH: 2, FINISHED: 3 });

/** What happened in a tick, one bit each: the sounds and the effects read them. */
export const EVENT = Object.freeze({
  DEAL: 1,
  DRAW: 2,
  FLIP: 4,
  PLACE: 8,
  FOUNDATION: 16,
  REFUSE: 32,
  RECYCLE: 64,
  RETURN: 128,
  WIN: 256,
});

/** The finish with nothing left hidden: a card goes up every this many ticks. */
export const AUTO_TICKS = 6;

/** How far a press may move and still be a tap. */
export const TAP_SLOP = 6;

/** How long each effect lasts, in ticks (drawing only; the match never waits). */
export const FX = Object.freeze({
  dealStagger: 3,
  dealFlight: 12,
  flight: 10,
  drop: 6,
  return: 8,
  draw: 8,
  shake: 12,
  flip: 8,
  sparks: 20,
  cascadeStagger: 8,
});
