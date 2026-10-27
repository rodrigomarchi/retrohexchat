/**
 * Minesweeper's rules, as pure functions of the board.
 *
 * The board is `{ cols, rows, mines, mine, cell, boom }`: squares numbered
 * row by row (`y * cols + x`); `mine[i]` says whether a mine lies there —
 * null until the first square is opened, when the mines are laid away from
 * it; `cell[i]` is `CELL.CLOSED`, `CELL.OPEN` or `CELL.FLAG`; `boom` is the
 * square of the mine that went off, or null. Nothing here changes the board
 * it is given.
 *
 * @module games/hex_mines/rules
 */

import { shuffle } from "../core/cards.js";

/** What a square shows. */
export const CELL = Object.freeze({ CLOSED: 0, OPEN: 1, FLAG: 2 });

/** A board of a level (`{ cols, rows, mines }`), every square shut, no mine laid yet. */
export function createBoard({ cols, rows, mines }) {
  return {
    cols,
    rows,
    mines,
    mine: null,
    cell: Array.from({ length: cols * rows }, () => CELL.CLOSED),
    boom: null,
  };
}

/** The squares around square `i`, up to eight. */
export function neighbours(board, i) {
  const x = i % board.cols;
  const y = Math.floor(i / board.cols);
  const around = [];
  for (let dy = -1; dy <= 1; dy++) {
    for (let dx = -1; dx <= 1; dx++) {
      const nx = x + dx;
      const ny = y + dy;
      if ((dx || dy) && nx >= 0 && ny >= 0 && nx < board.cols && ny < board.rows) {
        around.push(ny * board.cols + nx);
      }
    }
  }
  return around;
}

/** How many mines lie around square `i`. */
export const countAround = (board, i) => neighbours(board, i).filter((n) => board.mine[n]).length;

/** The mines laid at random, none on square `safe` nor around it. */
function layMines(board, random, safe) {
  const kept = new Set([safe, ...neighbours(board, safe)]);
  const free = board.cell.map((_, i) => i).filter((i) => !kept.has(i));
  const mined = new Set(shuffle(free, random).slice(0, board.mines));
  return board.cell.map((_, i) => mined.has(i));
}

/**
 * The board after opening the shut squares `start` (one, or several at once
 * for a chord): each shows its count, a square with none opens the ones
 * around it in turn. `opened` lists the squares opened with the ring each
 * was reached in, for the wave the picture draws; `boom` says a mine went off.
 */
function openFrom(board, start) {
  const cell = [...board.cell];
  const opened = [];
  let boom = null;
  const queue = start.map((i) => ({ i, ring: 0 }));
  for (let head = 0; head < queue.length; head++) {
    const { i, ring } = queue[head];
    if (cell[i] !== CELL.CLOSED) continue;
    if (board.mine[i]) {
      boom ??= i;
      continue;
    }
    cell[i] = CELL.OPEN;
    opened.push({ i, ring });
    if (countAround(board, i) === 0) {
      for (const n of neighbours(board, i)) {
        if (cell[n] === CELL.CLOSED) queue.push({ i: n, ring: ring + 1 });
      }
    }
  }
  return { board: { ...board, cell, boom }, opened, boom: boom !== null };
}

/**
 * The board after opening square `i`: the mines are laid first if none is
 * yet (from `random`, away from `i`). A flagged or open square stays as it is.
 * @returns {{ board: object, opened: Array<{ i: number, ring: number }>, boom: boolean }}
 */
export function open(board, i, random) {
  if (board.cell[i] !== CELL.CLOSED) return { board, opened: [], boom: false };
  const laid = board.mine ? board : { ...board, mine: layMines(board, random, i) };
  return openFrom(laid, [i]);
}

/** The board with a flag put on, or taken off, shut square `i`; an open one stays as it is. */
export function toggleFlag(board, i) {
  if (board.cell[i] === CELL.OPEN) return board;
  const cell = [...board.cell];
  cell[i] = cell[i] === CELL.FLAG ? CELL.CLOSED : CELL.FLAG;
  return { ...board, cell };
}

/**
 * A chord on open square `i`: once as many flags lie around it as its number,
 * every other shut square around it opens. Fewer flags, nothing happens.
 * @returns {{ board: object, opened: Array<{ i: number, ring: number }>, boom: boolean }}
 */
export function chord(board, i) {
  const unchanged = { board, opened: [], boom: false };
  if (board.cell[i] !== CELL.OPEN) return unchanged;
  const around = neighbours(board, i);
  const flags = around.filter((n) => board.cell[n] === CELL.FLAG).length;
  if (flags === 0 || flags !== countAround(board, i)) return unchanged;
  const shut = around.filter((n) => board.cell[n] === CELL.CLOSED);
  return shut.length ? openFrom(board, shut) : unchanged;
}

/** How many mines are left to flag: may fall below zero, as on Windows. */
export const flagsLeft = (board) => board.mines - board.cell.filter((c) => c === CELL.FLAG).length;

/** Whether every square without a mine is open. */
export const won = (board) =>
  board.mine !== null && board.cell.every((c, i) => board.mine[i] || c === CELL.OPEN);

/** The board as a win leaves it: a flag on every mine. */
export const flagAll = (board) => ({
  ...board,
  cell: board.cell.map((c, i) => (board.mine[i] ? CELL.FLAG : c)),
});
