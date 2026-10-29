import { describe, expect, it } from "vitest";
import {
  bit,
  candidates,
  digitsOf,
  parseGrid,
  PEERS,
  solved,
  UNITS,
  valid,
} from "../../../../js/lib/games/hex_sudoku/grid.js";
import {
  LEVEL_OF,
  boxLine,
  countSolutions,
  fish,
  hiddenSubsets,
  nakedSubsets,
  pointing,
  solveLogically,
  xyWing,
} from "../../../../js/lib/games/hex_sudoku/solver.js";

// Project Euler 96, grid 01: singles see it through.
const EASY = "003020600900305001001806400008102900700000008006708200002609500800203009005010300";
// Arto Inkala's 2012 grid: one solution, but no technique here reaches it.
const INKALA = "800000000003600000070090200050007000000045700000100030001000068008500010090000400";

/** Candidates with every digit everywhere, then `keep(i)` (a mask) where it says. */
const allowing = (keep) => Array.from({ length: 81 }, (_, i) => keep(i) ?? 0x1ff);
const at = (row, col) => row * 9 + col;

describe("the grid", () => {
  it("knows each square's twenty peers and the twenty-seven units", () => {
    expect(UNITS).toHaveLength(27);
    for (const unit of UNITS) expect(new Set(unit).size).toBe(9);
    for (const peers of PEERS) expect(peers).toHaveLength(20);
    expect(PEERS[0]).toContain(at(0, 8));
    expect(PEERS[0]).toContain(at(8, 0));
    expect(PEERS[0]).toContain(at(2, 2));
    expect(PEERS[0]).not.toContain(at(3, 3));
  });

  it("reads a grid and the candidates each empty square has", () => {
    const values = parseGrid(EASY);
    expect(values).toHaveLength(81);
    expect(values[2]).toBe(3);
    const cand = candidates(values);
    expect(cand[2]).toBe(0);
    // Row 0 has 3, 2, 6; column 0 has 9, 7, 8; the first box has 3, 9, 1.
    expect(digitsOf(cand[0])).toEqual([4, 5]);
    expect(bit(5)).toBe(16);
  });

  it("tells a grid with a digit twice in a unit from a sound one", () => {
    expect(valid(parseGrid(EASY))).toBe(true);
    expect(valid(parseGrid(`33${EASY.slice(2)}`))).toBe(false);
    expect(valid(parseGrid(`${EASY.slice(0, 9)}3${EASY.slice(10)}`))).toBe(false);
  });
});

describe("counting solutions", () => {
  it("finds one for a sound grid, and stops at two", () => {
    expect(countSolutions(parseGrid(EASY))).toBe(1);
    expect(countSolutions(parseGrid(INKALA))).toBe(1);
    expect(countSolutions(Array(81).fill(0))).toBe(2);
  });

  it("finds none for a grid that breaks the rules or leads nowhere", () => {
    expect(countSolutions(parseGrid(`33${EASY.slice(2)}`))).toBe(0);
    // Row 0 leaves square 0 only a 9, and column 0 already has one.
    expect(countSolutions(parseGrid(`012345678${"9".padEnd(72, "0")}`))).toBe(0);
  });
});

describe("solving by technique", () => {
  it("sees an easy grid through with singles, the easiest level", () => {
    const result = solveLogically(parseGrid(EASY));
    expect(result.solved).toBe(true);
    expect(solved(result.values)).toBe(true);
    expect(result.level).toBe(1);
  });

  it("gives up on a grid that needs guessing, and on one held below its level", () => {
    expect(solveLogically(parseGrid(INKALA)).solved).toBe(false);
    expect(solveLogically(parseGrid(INKALA), 1).solved).toBe(false);
  });

  it("names the level of every technique", () => {
    // ex_dna:disable-for-lines:10 the expected table written out, apart from the code
    expect(LEVEL_OF).toEqual({
      nakedSingle: 1,
      hiddenSingle: 1,
      nakedSubsets: 2,
      hiddenSubsets: 2,
      pointing: 2,
      boxLine: 2,
      fish: 3,
      xyWing: 3,
    });
  });
});

describe("the techniques", () => {
  it("a naked pair: two squares of a row holding only 1 and 2 take them from the row", () => {
    const cand = allowing((i) => (i === at(0, 0) || i === at(0, 1) ? bit(1) | bit(2) : null));
    expect(nakedSubsets(cand)).toBe(true);
    expect(cand[at(0, 5)] & (bit(1) | bit(2))).toBe(0);
    expect(cand[at(0, 0)]).toBe(bit(1) | bit(2));
  });

  it("a hidden pair: 1 and 2 fitting only two squares of a row leave those squares nothing else", () => {
    const pair = new Set([at(0, 0), at(0, 1)]);
    const cand = allowing((i) => (i < 9 && !pair.has(i) ? 0x1ff & ~(bit(1) | bit(2)) : null));
    expect(hiddenSubsets(cand)).toBe(true);
    expect(cand[at(0, 0)]).toBe(bit(1) | bit(2));
    expect(cand[at(0, 1)]).toBe(bit(1) | bit(2));
  });

  it("pointing: a 5 kept to one row of a box leaves the rest of that row", () => {
    const box = UNITS[18];
    const cand = allowing((i) => (box.includes(i) && i >= 9 ? 0x1ff & ~bit(5) : null));
    expect(pointing(cand)).toBe(true);
    expect(cand[at(0, 5)] & bit(5)).toBe(0);
    expect(cand[at(0, 1)] & bit(5)).toBe(bit(5));
  });

  it("box-line: a 5 kept to one box in a row leaves the rest of that box", () => {
    const cand = allowing((i) => (i < 9 && i > 2 ? 0x1ff & ~bit(5) : null));
    expect(boxLine(cand)).toBe(true);
    expect(cand[at(1, 1)] & bit(5)).toBe(0);
    expect(cand[at(0, 1)] & bit(5)).toBe(bit(5));
  });

  it("an X-Wing: a 5 kept to two columns in two rows leaves the rest of those columns", () => {
    const corners = new Set([at(0, 2), at(0, 6), at(4, 2), at(4, 6)]);
    const cand = allowing((i) =>
      (Math.floor(i / 9) === 0 || Math.floor(i / 9) === 4) && !corners.has(i)
        ? 0x1ff & ~bit(5)
        : null,
    );
    expect(fish(cand)).toBe(true);
    expect(cand[at(7, 2)] & bit(5)).toBe(0);
    expect(cand[at(7, 6)] & bit(5)).toBe(0);
    expect(cand[at(7, 3)] & bit(5)).toBe(bit(5));
  });

  it("an XY-Wing: a pivot 12 seeing pincers 13 and 23 takes 3 from what both pincers see", () => {
    const set = {
      [at(0, 0)]: bit(1) | bit(2),
      [at(0, 5)]: bit(1) | bit(3),
      [at(4, 0)]: bit(2) | bit(3),
    };
    const cand = allowing((i) => set[i] ?? null);
    expect(xyWing(cand)).toBe(true);
    expect(cand[at(4, 5)] & bit(3)).toBe(0);
    expect(cand[at(4, 4)] & bit(3)).toBe(bit(3));
  });

  it("does nothing, and says so, where a technique finds nothing", () => {
    const cand = allowing(() => null);
    for (const technique of [nakedSubsets, hiddenSubsets, pointing, boxLine, fish, xyWing]) {
      expect(technique(cand)).toBe(false);
    }
    expect(cand.every((c) => c === 0x1ff)).toBe(true);
  });
});
