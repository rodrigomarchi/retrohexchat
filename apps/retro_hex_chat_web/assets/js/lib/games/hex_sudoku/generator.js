/**
 * New grids for a level: a whole grid at random, then squares taken out one
 * by one, in an order drawn at random, for as long as the grid can still be
 * solved with the level's techniques. A grid a person can solve by technique
 * has one solution; the level is right when it needed the level's hardest
 * technique, and a grid that misses it is thrown away for another.
 *
 * A hard grid can take a few dozen tries, so the tries are handed out one at
 * a time (`createGeneration`): a game makes one a tick, never freezing the page.
 *
 * @module games/hex_sudoku/generator
 */

import { shuffle } from "../core/cards.js";
import { fullGrid, solveLogically } from "./solver.js";

const SQUARES = Object.freeze(Array.from({ length: 81 }, (_, i) => i));

/** `solution` with squares taken out while the level's techniques still see it through. */
function dig(solution, { level, givens: [fewest] }, random) {
  const puzzle = [...solution];
  let given = 81;
  for (const i of shuffle(SQUARES, random)) {
    if (given === fewest) break;
    puzzle[i] = 0;
    if (solveLogically(puzzle, level).solved) given--;
    else puzzle[i] = solution[i];
  }
  return { puzzle, given };
}

/**
 * The tries at a grid for a level (`protocol.js`'s `LEVEL`), drawn from
 * `random`: `next()` makes one, and gives the grid `{ puzzle, solution }` when
 * it is right, or null. The same draws make the same grid in as many tries.
 */
export function createGeneration(spec, random) {
  return {
    next() {
      const solution = fullGrid(random);
      const { puzzle, given } = dig(solution, spec, random);
      const right =
        given <= spec.givens[1] && solveLogically(puzzle, spec.level).level === spec.level;
      return right ? { puzzle, solution } : null;
    },
  };
}

/** A grid for a level, all its tries at once. */
export function generate(spec, random) {
  const generation = createGeneration(spec, random);
  for (;;) {
    const grid = generation.next();
    if (grid) return grid;
  }
}
