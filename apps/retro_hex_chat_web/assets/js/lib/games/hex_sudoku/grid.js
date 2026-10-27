/**
 * The Sudoku grid, as the solver and the generator read it: 81 squares
 * numbered row by row (`row * 9 + col`), each holding a digit 1–9 or 0 for
 * empty; a square's candidates are a mask of nine bits, bit `d - 1` for `d`.
 *
 * @module games/hex_sudoku/grid
 */

/** The squares, 0 to 80. */
export const SQUARES = Object.freeze(Array.from({ length: 81 }, (_, i) => i));

/** Every digit allowed. */
export const ALL = 0x1ff;

const rowOf = (i) => Math.floor(i / 9);
const colOf = (i) => i % 9;
const boxOf = (i) => Math.floor(rowOf(i) / 3) * 3 + Math.floor(colOf(i) / 3);

/** The 27 units: the nine rows, then the nine columns, then the nine boxes. */
export const UNITS = Object.freeze(
  [rowOf, colOf, boxOf].flatMap((unitOf) =>
    Array.from({ length: 9 }, (_, u) => Object.freeze(SQUARES.filter((i) => unitOf(i) === u))),
  ),
);

/** The three units each square is in: its row, its column and its box. */
export const UNITS_OF = Object.freeze(
  SQUARES.map((i) => Object.freeze([rowOf(i), 9 + colOf(i), 18 + boxOf(i)])),
);

/** The twenty squares that share a unit with each square. */
export const PEERS = Object.freeze(
  SQUARES.map((i) =>
    Object.freeze([...new Set(UNITS_OF[i].flatMap((u) => UNITS[u]))].filter((p) => p !== i)),
  ),
);

/** Whether squares `a` and `b` share a unit. */
export const sees = (a, b) =>
  a !== b && (rowOf(a) === rowOf(b) || colOf(a) === colOf(b) || boxOf(a) === boxOf(b));

/** The bit of digit `d`. */
export const bit = (d) => 1 << (d - 1);

/** How many digits a mask holds. */
export function count(mask) {
  let n = 0;
  for (let m = mask; m; m &= m - 1) n++;
  return n;
}

/** The digits a mask holds, smallest first. */
export function digitsOf(mask) {
  const digits = [];
  for (let d = 1; d <= 9; d++) if (mask & bit(d)) digits.push(d);
  return digits;
}

/** A grid from 81 characters, `0` or `.` for an empty square. */
export const parseGrid = (text) => [...text].map((c) => (c === "." ? 0 : Number(c)));

/** What each square could hold: nothing on a filled one, the digits no peer has on an empty one. */
export const candidates = (values) =>
  values.map((v, i) =>
    v ? 0 : PEERS[i].reduce((mask, p) => (values[p] ? mask & ~bit(values[p]) : mask), ALL),
  );

/** Whether no digit stands twice in a unit. */
export const valid = (values) =>
  UNITS.every((unit) => {
    const digits = unit.map((i) => values[i]).filter(Boolean);
    return new Set(digits).size === digits.length;
  });

/** Whether every square is filled and no digit stands twice in a unit. */
export const solved = (values) => values.every(Boolean) && valid(values);
