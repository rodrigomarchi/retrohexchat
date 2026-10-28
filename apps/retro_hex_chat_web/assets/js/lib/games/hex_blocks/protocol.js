/**
 * Hex Blocks — the game's constants. A one-player game never goes on the
 * wire, so this holds no schema: only the well's rules and numbers, by name.
 *
 * Time is 60 Hz ticks.
 *
 * @module games/hex_blocks/protocol
 */

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
