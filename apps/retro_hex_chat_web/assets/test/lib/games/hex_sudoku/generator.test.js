import { describe, expect, it } from "vitest";
import { createRng } from "../../../../js/lib/games/core/rng.js";
import { createGeneration, generate } from "../../../../js/lib/games/hex_sudoku/generator.js";
import { solved } from "../../../../js/lib/games/hex_sudoku/grid.js";
import { LEVEL } from "../../../../js/lib/games/hex_sudoku/protocol.js";
import { countSolutions, solveLogically } from "../../../../js/lib/games/hex_sudoku/solver.js";

const SEEDS = Array.from({ length: 40 }, (_, n) => n + 1);

/** A level's grid from `seed`, with how many tries it took. */
function grown(spec, seed) {
  const generation = createGeneration(spec, createRng(seed).next);
  for (let tries = 1; ; tries++) {
    const grid = generation.next();
    if (grid) return { ...grid, tries };
  }
}

describe.each(Object.entries(LEVEL))("a %s grid", (_id, spec) => {
  const grids = SEEDS.map((seed) => grown(spec, seed));

  it("has one solution, the one it keeps, and agrees with it square by square", () => {
    for (const { puzzle, solution } of grids) {
      expect(countSolutions(puzzle)).toBe(1);
      expect(solved(solution)).toBe(true);
      puzzle.forEach((v, i) => v && expect(v).toBe(solution[i]));
    }
  });

  it("gives as many squares as its level does", () => {
    for (const { puzzle } of grids) {
      const given = puzzle.filter(Boolean).length;
      expect(given).toBeGreaterThanOrEqual(spec.givens[0]);
      expect(given).toBeLessThanOrEqual(spec.givens[1]);
    }
  });

  it("needs its level's hardest technique, and no harder", () => {
    for (const { puzzle } of grids) {
      const result = solveLogically(puzzle, spec.level);
      expect(result.solved).toBe(true);
      expect(result.level).toBe(spec.level);
      if (spec.level > 1) expect(solveLogically(puzzle, spec.level - 1).solved).toBe(false);
    }
  });

  it("is found in a few dozen tries at most, one a tick", () => {
    expect(Math.max(...grids.map((g) => g.tries))).toBeLessThanOrEqual(60);
  });
});

describe("the same draws", () => {
  it("make the same grid, and other draws another", () => {
    const grid = (seed) => generate(LEVEL.hex_sudoku_medium, createRng(seed).next).puzzle;
    expect(grid(9)).toEqual(grid(9));
    expect(grid(9)).not.toEqual(grid(10));
  });
});
