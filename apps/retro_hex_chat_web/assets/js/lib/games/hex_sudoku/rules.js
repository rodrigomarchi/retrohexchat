/**
 * Sudoku's rules, as pure functions of the board.
 *
 * The board is `{ solution, given, values, notes, hinted }`, each an array of
 * the 81 squares (`grid.js`): the solution's digits; whether the puzzle gave a
 * square; the digit a square shows (0 for none); its notes, a mask of the
 * digits pencilled in; whether a hint revealed it. A given or hinted square
 * never changes. Nothing here changes the board it is given.
 *
 * @module games/hex_sudoku/rules
 */

import { PEERS, UNITS, UNITS_OF, bit } from "./grid.js";

/** A board for a grid (`generator.js`'s `{ puzzle, solution }`): nothing noted, nothing hinted. */
export const createBoard = ({ puzzle, solution }) => ({
  solution,
  given: puzzle.map(Boolean),
  values: [...puzzle],
  notes: puzzle.map(() => 0),
  hinted: puzzle.map(() => false),
});

/** Whether square `i` is the player's to change. */
const free = (board, i) => !board.given[i] && !board.hinted[i];

/** Whether square `i` shows a digit the solution does not have there. */
export const isWrong = (board, i) => board.values[i] !== 0 && board.values[i] !== board.solution[i];

/** `d` put on square `i`, its notes gone, and gone from its peers' notes when it is right. */
function put(board, i, d) {
  const values = [...board.values];
  const notes = [...board.notes];
  values[i] = d;
  notes[i] = 0;
  if (d === board.solution[i]) for (const p of PEERS[i]) notes[p] &= ~bit(d);
  return { ...board, values, notes };
}

/**
 * The board with digit `d` on square `i`; a given or hinted square, or one
 * already showing `d`, stays as it is.
 * @returns {{ board: object, wrong: boolean }} - `wrong`, whether the digit put is wrong
 */
export function place(board, i, d) {
  if (!free(board, i) || board.values[i] === d) return { board, wrong: false };
  return { board: put(board, i, d), wrong: d !== board.solution[i] };
}

/** The board with note `d` on, or off, empty square `i`; a filled square stays as it is. */
export function toggleNote(board, i, d) {
  if (board.values[i]) return board;
  const notes = [...board.notes];
  notes[i] ^= bit(d);
  return { ...board, notes };
}

/** The board with square `i`'s digit or notes taken off; a given, hinted or empty one stays as it is. */
export function erase(board, i) {
  if (!free(board, i) || (!board.values[i] && !board.notes[i])) return board;
  const values = [...board.values];
  const notes = [...board.notes];
  values[i] = 0;
  notes[i] = 0;
  return { ...board, values, notes };
}

/** The board with square `i`'s digit revealed for good. */
export function reveal(board, i) {
  const shown = put(board, i, board.solution[i]);
  const hinted = [...board.hinted];
  hinted[i] = true;
  return { ...shown, hinted };
}

/**
 * The square a hint reveals: the chosen one (`selected`) when it is empty or
 * wrong, else one of those still to fill drawn by `random`; null when none is.
 */
export function hintSquare(board, selected, random) {
  const open = (i) => board.values[i] !== board.solution[i];
  if (selected !== null && free(board, selected) && open(selected)) return selected;
  const squares = board.values.map((_, i) => i).filter(open);
  return squares.length ? squares[Math.floor(random() * squares.length)] : null;
}

/** An earlier board (`before`, an undo's) with every square revealed since (on `now`) revealed again. */
export const keepHints = (before, now) =>
  now.hinted.reduce(
    (board, hinted, i) => (hinted && !board.hinted[i] ? reveal(board, i) : board),
    before,
  );

/** Whether every square shows the solution's digit. */
export const won = (board) => board.values.every((v, i) => v === board.solution[i]);

/** The units (`grid.js`'s numbers) square `i` is in that show their solution whole. */
export const completedUnits = (board, i) =>
  UNITS_OF[i].filter((u) => UNITS[u].every((s) => board.values[s] === board.solution[s]));

/** How many squares whose digit is `d` are still to fill rightly. */
export const left = (board, d) =>
  board.solution.filter((s, i) => s === d && board.values[i] !== d).length;
