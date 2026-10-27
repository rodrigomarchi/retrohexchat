import { describe, expect, it } from "vitest";
import { createRng } from "../../../../js/lib/games/core/rng.js";
import { LEVEL } from "../../../../js/lib/games/hex_mines/protocol.js";
import {
  CELL,
  chord,
  countAround,
  createBoard,
  flagsLeft,
  neighbours,
  open,
  toggleFlag,
  won,
} from "../../../../js/lib/games/hex_mines/rules.js";

const at = (board, x, y) => y * board.cols + x;
/** A board with mines where `rows` has `*`, nothing opened. */
function boardOf(rows) {
  const cols = rows[0].length;
  const board = createBoard({ cols, rows: rows.length, mines: 0 });
  const mine = rows
    .join("")
    .split("")
    .map((c) => c === "*");
  return { ...board, mines: mine.filter(Boolean).length, mine };
}

describe("the first square opened", () => {
  it("lays the mines away from it and its eight neighbours, as many as the level has", () => {
    for (const level of Object.values(LEVEL)) {
      const board = createBoard(level);
      const first = at(board, 0, 0);
      const { board: after } = open(board, first, createRng(7).next);
      expect(after.mine.filter(Boolean)).toHaveLength(level.mines);
      for (const i of [first, ...neighbours(after, first)]) expect(after.mine[i]).toBe(false);
    }
  });

  it("lays the same mines for the same seed and the same square", () => {
    const board = createBoard(LEVEL.hex_mines_expert);
    const lay = (seed) => open(board, 100, createRng(seed).next).board.mine;
    expect(lay(3)).toEqual(lay(3));
    expect(lay(3)).not.toEqual(lay(4));
  });
});

describe("opening", () => {
  it("shows how many mines are around, and floods out from a square with none", () => {
    const board = boardOf(["*....", ".....", "....."]);
    expect(countAround(board, at(board, 1, 1))).toBe(1);
    const { board: after, opened, boom } = open(board, at(board, 4, 2), null);
    expect(boom).toBe(false);
    expect(after.cell.filter((c) => c === CELL.OPEN)).toHaveLength(14);
    expect(after.cell[at(board, 0, 0)]).toBe(CELL.CLOSED);
    // In rings out from the square pressed: the wave the picture draws.
    expect(opened[0]).toEqual({ i: at(board, 4, 2), ring: 0 });
    expect(Math.max(...opened.map((o) => o.ring))).toBe(4);
  });

  it("floods the whole of an empty expert board without running out of stack", () => {
    const board = { ...createBoard(LEVEL.hex_mines_expert), mines: 0 };
    const empty = { ...board, mine: board.cell.map(() => false) };
    expect(open(empty, 0, null).board.cell.every((c) => c === CELL.OPEN)).toBe(true);
  });

  it("goes off on a mine, and leaves a flagged square shut", () => {
    const board = boardOf(["*.", ".."]);
    expect(open(board, 0, null)).toMatchObject({ boom: true, board: { boom: 0 } });
    const flagged = toggleFlag(board, 0);
    expect(open(flagged, 0, null).board).toBe(flagged);
  });
});

describe("flags", () => {
  it("go on and off a shut square only, and count down the mines left", () => {
    const board = boardOf(["*..", "..."]);
    const flagged = toggleFlag(board, 2);
    expect(flagged.cell[2]).toBe(CELL.FLAG);
    expect(flagsLeft(flagged)).toBe(0);
    expect(flagsLeft(toggleFlag(flagged, 0))).toBe(-1);
    expect(toggleFlag(flagged, 2).cell[2]).toBe(CELL.CLOSED);
    const opened = open(board, 5, null).board;
    expect(toggleFlag(opened, 5)).toBe(opened);
  });
});

describe("a chord on a number", () => {
  const board = boardOf(["*..", "...", "..."]);
  const one = at(board, 1, 1);
  const opened = open(board, one, null).board;

  it("opens every unflagged neighbour once its flags match the number", () => {
    const flagged = toggleFlag(opened, 0);
    const { board: after, boom } = chord(flagged, one);
    expect(boom).toBe(false);
    expect(after.cell.filter((c) => c === CELL.OPEN)).toHaveLength(8);
  });

  it("does nothing with fewer flags, and goes off with a flag on the wrong square", () => {
    expect(chord(opened, one).board).toBe(opened);
    const wrong = toggleFlag(opened, at(board, 2, 2));
    expect(chord(wrong, one)).toMatchObject({ boom: true, board: { boom: 0 } });
  });
});

describe("the end", () => {
  it("is a win once every square without a mine is open", () => {
    const board = boardOf(["*.", ".."]);
    let after = board;
    for (const i of [1, 2, 3]) after = open(after, i, null).board;
    expect(won(after)).toBe(true);
    expect(won(open(board, 1, null).board)).toBe(false);
  });
});
