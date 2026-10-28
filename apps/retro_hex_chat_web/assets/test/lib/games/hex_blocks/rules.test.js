import { describe, expect, it } from "vitest";
import { COLS, HIDDEN, ROWS } from "../../../../js/lib/games/hex_blocks/protocol.js";
import { PIECES } from "../../../../js/lib/games/hex_blocks/pieces.js";
import {
  cellsOf,
  clearLines,
  createWell,
  fall,
  filled,
  fits,
  hold,
  landing,
  lock,
  rotate,
  shift,
  spawn,
  toppedOut,
} from "../../../../js/lib/games/hex_blocks/rules.js";

const kindOf = (name) => PIECES.findIndex((p) => p.name === name);
const BAR = kindOf("bar");
const key = ([a, b]) => `${a},${b}`;
const sorted = (cells) => cells.map(key).sort();

/** A well with the squares given filled with colour 1. */
function wellWith(squares) {
  let well = createWell();
  for (const [c, r] of squares) well = { ...well, cells: well.cells.with(r * COLS + c, 1) };
  return well;
}
/** The squares of a whole zigzag row but the columns given. */
const rowBut = (r, gaps = []) =>
  Array.from({ length: COLS }, (_, c) => [c, r]).filter(([c]) => !gaps.includes(c));

describe("a new piece", () => {
  it("comes in at the top of the middle, wholly inside the hidden rows' reach", () => {
    for (let kind = 0; kind < PIECES.length; kind++) {
      const piece = spawn(kind);
      const cells = cellsOf(piece);
      expect(Math.min(...cells.map(([, r]) => r))).toBe(0);
      expect(fits(createWell(), piece)).toBe(true);
      const cols = cells.map(([c]) => c);
      expect(Math.min(...cols) + Math.max(...cols)).toBeGreaterThanOrEqual(COLS - 3);
      expect(Math.min(...cols) + Math.max(...cols)).toBeLessThanOrEqual(COLS + 1);
    }
  });
});

describe("moving a piece", () => {
  it("steps sideways keeping its shape, and stops at a wall", () => {
    const well = createWell();
    let piece = spawn(BAR);
    let steps = 0;
    for (let next = shift(well, piece, -1); next; next = shift(well, piece, -1)) {
      expect(cellsOf(next)).toHaveLength(4);
      piece = next;
      steps++;
    }
    expect(steps).toBeGreaterThan(0);
    expect(Math.min(...cellsOf(piece).map(([c]) => c))).toBe(0);
    expect(shift(well, piece, -1)).toBeNull();
    // Back and forth, the same squares.
    const there = shift(well, piece, 1);
    expect(sorted(cellsOf(shift(well, there, -1)))).toEqual(sorted(cellsOf(piece)));
  });

  it("stops against the stack beside it", () => {
    const piece = { ...spawn(BAR), r: 10 };
    const right = Math.max(...cellsOf(piece).map(([c]) => c));
    const wall = Array.from({ length: ROWS }, (_, r) => [right + 1, r]);
    expect(shift(wellWith(wall), piece, 1)).toBeNull();
    expect(shift(wellWith(wall), piece, -1)).not.toBeNull();
  });

  it("falls a row at a time down its columns, and stops on the floor", () => {
    const well = createWell();
    let piece = spawn(BAR);
    const before = cellsOf(piece);
    const down = fall(well, piece);
    expect(sorted(cellsOf(down))).toEqual(sorted(before.map(([c, r]) => [c, r + 1])));
    while (fall(well, piece)) piece = fall(well, piece);
    expect(Math.max(...cellsOf(piece).map(([, r]) => r))).toBe(ROWS - 1);
    expect(landing(well, spawn(BAR))).toEqual(piece);
  });

  it("lands on the stack: the shadow is where it would stop", () => {
    const well = wellWith(rowBut(ROWS - 1));
    const landed = landing(well, spawn(BAR));
    expect(fits(well, landed)).toBe(true);
    expect(fall(well, landed)).toBeNull();
    expect(Math.max(...cellsOf(landed).map(([, r]) => r))).toBe(ROWS - 2);
  });
});

describe("turning a piece", () => {
  it("turns a sixth of the way round, six turns back home", () => {
    const well = createWell();
    for (let kind = 0; kind < PIECES.length; kind++) {
      let piece = landing(well, spawn(kind));
      piece = { ...piece, r: piece.r - 4 };
      const home = sorted(cellsOf(piece));
      for (let i = 0; i < 6; i++) piece = rotate(well, piece, 1);
      expect(sorted(cellsOf(piece))).toEqual(home);
      expect(sorted(cellsOf(rotate(well, rotate(well, piece, 1), -1)))).toEqual(home);
    }
  });

  it("kicks off a wall when the turn would put it through", () => {
    const well = createWell();
    let piece = spawn(BAR);
    piece = { ...piece, r: piece.r + 8 };
    while (shift(well, piece, -1)) piece = shift(well, piece, -1);
    // Some turn about the wall pushes a square off the well: it is kicked back in.
    let turned = piece;
    for (let i = 0; i < 6; i++) {
      turned = rotate(well, turned, 1);
      expect(turned).not.toBeNull();
      expect(fits(well, turned)).toBe(true);
    }
  });

  it("does not turn when nothing near takes it", () => {
    const piece = { ...spawn(BAR), r: 10 };
    const own = new Set(cellsOf(piece).map(key));
    const all = [];
    for (let c = 0; c < COLS; c++) for (let r = 0; r < ROWS; r++) all.push([c, r]);
    const well = wellWith(all.filter((sq) => !own.has(key(sq))));
    expect(rotate(well, piece, 1)).toBeNull();
  });
});

describe("locking and clearing", () => {
  it("locks a piece into the well in its colour", () => {
    const piece = landing(createWell(), spawn(BAR));
    const well = lock(createWell(), piece);
    for (const [c, r] of cellsOf(piece)) expect(well.cells[r * COLS + c]).toBe(BAR + 1);
    expect(filled(well)).toBe(4);
  });

  it("clears a full zigzag row, the columns above coming down one", () => {
    const above = [3, ROWS - 2];
    const well = wellWith([...rowBut(ROWS - 1), above]);
    const { well: after, lines } = clearLines(well);
    expect(lines).toEqual([ROWS - 1]);
    expect(filled(after)).toBe(1);
    expect(after.cells[(ROWS - 1) * COLS + 3]).toBe(1);
  });

  it("clears four rows at once with the bar standing in their gap", () => {
    const rows = [ROWS - 4, ROWS - 3, ROWS - 2, ROWS - 1];
    let piece = spawn(BAR);
    // The bar turned until it stands in one column.
    for (let i = 0; i < 6 && new Set(cellsOf(piece).map(([c]) => c)).size > 1; i++) {
      piece = rotate(createWell(), piece, 1);
    }
    const col = cellsOf(piece)[0][0];
    const well = wellWith(rows.flatMap((r) => rowBut(r, [col])));
    const landed = landing(well, piece);
    const { well: after, lines } = clearLines(lock(well, landed));
    expect(lines).toEqual(rows);
    expect(filled(after)).toBe(0);
  });

  it("clears rows that are not side by side, keeping the one between", () => {
    const well = wellWith([...rowBut(ROWS - 1), ...rowBut(ROWS - 2, [0]), ...rowBut(ROWS - 3)]);
    const { well: after, lines } = clearLines(well);
    expect(lines).toEqual([ROWS - 3, ROWS - 1]);
    expect(filled(after)).toBe(COLS - 1);
    expect(after.cells[(ROWS - 1) * COLS]).toBe(0);
    expect(after.cells[(ROWS - 1) * COLS + 1]).toBe(1);
  });
});

describe("the top", () => {
  it("is out when a piece locks wholly in the hidden rows", () => {
    const piece = spawn(BAR);
    const high = cellsOf(piece).every(([, r]) => r < HIDDEN);
    expect(toppedOut(piece)).toBe(high);
    expect(toppedOut(landing(createWell(), piece))).toBe(false);
    // The bar standing in a column, its top hexagon one above the well and its foot in sight.
    let standing = spawn(BAR);
    while (new Set(cellsOf(standing).map(([c]) => c)).size > 1) {
      standing = { ...standing, turn: standing.turn + 1 };
    }
    const top = Math.min(...cellsOf(standing).map(([, r]) => r));
    const poking = { ...standing, r: standing.r - top - 1 };
    expect(Math.max(...cellsOf(poking).map(([, r]) => r))).toBeGreaterThanOrEqual(HIDDEN);
    expect(toppedOut(poking)).toBe(true);
  });

  it("does not fit a new piece on a stack up to the top", () => {
    const cells = [];
    for (let r = 0; r < ROWS; r++) cells.push([Math.floor(COLS / 2), r]);
    expect(fits(wellWith(cells), spawn(BAR))).toBe(false);
  });
});

describe("holding a piece", () => {
  const deal = { piece: spawn(1), held: null, canHold: true, queue: [4, 5, 6, 7] };

  it("puts the piece aside and takes the next, once a piece", () => {
    const after = hold(deal);
    expect(after.held).toBe(1);
    expect(after.piece.kind).toBe(4);
    expect(after.queue).toEqual([5, 6, 7]);
    expect(after.canHold).toBe(false);
    expect(hold(after)).toBe(after);
  });

  it("swaps with the piece held, which comes in fresh from the top", () => {
    const later = { ...hold(deal), canHold: true };
    const moved = { ...later, piece: { ...later.piece, r: 9 } };
    const swapped = hold(moved);
    expect(swapped.held).toBe(4);
    expect(swapped.piece).toEqual(spawn(1));
    expect(swapped.queue).toEqual([5, 6, 7]);
  });
});
