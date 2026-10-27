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
