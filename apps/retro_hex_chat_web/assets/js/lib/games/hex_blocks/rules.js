/**
 * Hex Blocks' rules, as pure functions of the well and the piece falling.
 * A piece is `{ kind, turn, c, r }`: its kind, how many sixths it is turned,
 * and the square of the well its own hexagon is on. A sideways step moves
 * that square to the next column on the same zigzag row; a fall, one row down
 * its column. The well is `{ cells }`, a row after row of colours, 0 empty.
 *
 * @module games/hex_blocks/rules
 */

import { add, toAxial, toOffset } from "./hex.js";
import { shape } from "./pieces.js";
import { COLS, HIDDEN, KICKS, ROWS } from "./protocol.js";

/** An empty well. */
export const createWell = () => ({ cells: Array(COLS * ROWS).fill(0) });

/** The squares of the well a piece covers. */
export function cellsOf(piece) {
  const pivot = toAxial([piece.c, piece.r]);
  return shape(piece.kind, piece.turn).map((cell) => toOffset(add(pivot, cell)));
}

/**
 * Whether a piece is between the walls, above the floor and on empty squares
 * only. Above the top is open: a step sideways lifts some hexagons of a piece
 * half a row, and one that comes in on the top row must still move.
 */
export const fits = (well, piece) =>
  cellsOf(piece).every(
    ([c, r]) => c >= 0 && c < COLS && r < ROWS && (r < 0 || well.cells[r * COLS + c] === 0),
  );

/** A piece of `kind` coming in: in the middle column, its top on the well's top row. */
export function spawn(kind) {
  const piece = { kind, turn: 0, c: Math.floor(COLS / 2), r: 0 };
  const top = Math.min(...cellsOf(piece).map(([, r]) => r));
  return { ...piece, r: -top };
}

/** The piece moved, or null when it does not fit there. */
const tried = (well, piece) => (fits(well, piece) ? piece : null);

/** The piece a column `dir` (-1 or 1) aside on its zigzag row, or null against a wall or the stack. */
export const shift = (well, piece, dir) => tried(well, { ...piece, c: piece.c + dir });

/** The piece a row down, or null when it rests on the floor or the stack. */
export const fall = (well, piece) => tried(well, { ...piece, r: piece.r + 1 });

/**
 * The piece turned a sixth (`dir` 1 clockwise, -1 the other way), kicked
 * aside or up when the turn does not fit where it is; null when nothing near
 * takes it.
 */
export function rotate(well, piece, dir) {
  const turned = { ...piece, turn: (piece.turn + dir + 6) % 6 };
  for (const [dc, dr] of KICKS) {
    const kicked = tried(well, { ...turned, c: turned.c + dc, r: turned.r + dr });
    if (kicked) return kicked;
  }
  return null;
}

/** Where the piece comes to rest falling straight down: the shadow, and a hard drop. */
export function landing(well, piece) {
  let at = piece;
  for (let next = fall(well, at); next; next = fall(well, at)) at = next;
  return at;
}

/** The well with the piece set in it, in its colour (its kind + 1). */
export function lock(well, piece) {
  const cells = [...well.cells];
  for (const [c, r] of cellsOf(piece)) if (r >= 0) cells[r * COLS + c] = piece.kind + 1;
  return { ...well, cells };
}

/** How many squares of the well are filled. */
export const filled = (well) => well.cells.filter((v) => v !== 0).length;

const row = (cells, r) => cells.slice(r * COLS, (r + 1) * COLS);

/**
 * The well with its full zigzag rows taken out, each column above coming
 * down a square for every row cleared below it, and the rows cleared, top
 * to bottom.
 */
export function clearLines(well) {
  const lines = [];
  const kept = [];
  for (let r = 0; r < ROWS; r++) {
    const squares = row(well.cells, r);
    if (squares.every((v) => v !== 0)) lines.push(r);
    else kept.push(squares);
  }
  if (lines.length === 0) return { well, lines };
  const empty = Array.from({ length: lines.length }, () => Array(COLS).fill(0));
  return { well: { ...well, cells: [...empty, ...kept].flat() }, lines };
}

/**
 * Whether a piece that locked is over the top: wholly in the hidden rows, or
 * with a hexagon above the well.
 */
export const toppedOut = (piece) => {
  const rows = cellsOf(piece).map(([, r]) => r);
  return rows.every((r) => r < HIDDEN) || rows.some((r) => r < 0);
};

/**
 * The piece falling put aside, once a piece: the one held before comes in
 * fresh from the top, or the next in the queue when none was.
 * @param {{ piece: object, held: number | null, canHold: boolean, queue: number[] }} deal
 */
export function hold(deal) {
  if (!deal.canHold) return deal;
  const taking = deal.held ?? deal.queue[0];
  return {
    ...deal,
    piece: spawn(taking),
    held: deal.piece.kind,
    canHold: false,
    queue: deal.held === null ? deal.queue.slice(1) : deal.queue,
  };
}
