/**
 * Hex Sudoku — the game's constants. A one-player game never goes on the
 * wire, so this holds no schema: only the levels and the numbers, by name.
 *
 * Time is 60 Hz ticks; positions are the canvas's pixels.
 *
 * @module games/hex_sudoku/protocol
 */

/**
 * Each catalogue id's grid: the level of the hardest technique it needs
 * (`solver.js`), and how many squares it gives, at least and at most. The
 * level is the technique's; the counts only keep the grids in the range a
 * level's grids fall in, so a hard grid is found in a few dozen tries at most.
 */
export const LEVEL = Object.freeze({
  hex_sudoku: Object.freeze({ level: 1, givens: Object.freeze([36, 42]) }),
  hex_sudoku_medium: Object.freeze({ level: 2, givens: Object.freeze([26, 35]) }),
  hex_sudoku_hard: Object.freeze({ level: 3, givens: Object.freeze([22, 29]) }),
});

/**
 * A win's points: `NUMERATOR` / its ticks, never counting fewer than
 * `MIN_TICKS` (a minute): 1 min is 10,000, 10 min is 1,000. Giving up scores
 * nothing.
 */
export const POINTS = Object.freeze({ NUMERATOR: 36_000_000, MIN_TICKS: 3_600 });

/** The most a game can score, a win in a minute. The server refuses more. */
export const CEILING = POINTS.NUMERATOR / POINTS.MIN_TICKS;

/** What the clock adds, in ticks: half a minute for a wrong digit, a minute for a hint. */
export const PENALTY = Object.freeze({ MISTAKE: 1_800, HINT: 3_600 });

/** Three hours on the clock: a game still open then ends, with nothing scored. */
export const SAFETY_TICKS = 3 * 60 * 60 * 60;

/**
 * Where the game's pictures are served, with the version of their description
 * (`assets/art/sudoku/build_tiles.py` writes it), so a new atlas is never read
 * from an old cache.
 */
export const TILES_URL = "/images/games/sudoku/tiles.json?vsn=0784a1139ed8";
