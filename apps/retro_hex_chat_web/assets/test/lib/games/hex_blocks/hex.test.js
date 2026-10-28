import { describe, expect, it } from "vitest";
import {
  NEIGHBOURS,
  add,
  sideStep,
  toAxial,
  toOffset,
  turn,
} from "../../../../js/lib/games/hex_blocks/hex.js";

const key = ([a, b]) => `${a},${b}`;

describe("the honeycomb's coordinates", () => {
  it("goes from a square of the well to its axial hexagon and back", () => {
    for (let c = -3; c < 12; c++) {
      for (let r = -3; r < 22; r++) expect(toOffset(toAxial([c, r]))).toEqual([c, r]);
    }
  });

  it("keeps a column straight: one row down is the hexagon below", () => {
    for (const c of [0, 1, 4, 7]) {
      const below = toOffset(add(toAxial([c, 5]), [0, 1]));
      expect(below).toEqual([c, 6]);
    }
  });

  it("names six neighbours, each one step away", () => {
    expect(NEIGHBOURS).toHaveLength(6);
    expect(new Set(NEIGHBOURS.map(key)).size).toBe(6);
  });

  it("turns a hexagon a sixth of the way round, back home after six", () => {
    const start = [2, -1];
    let at = start;
    const seen = new Set();
    for (let i = 0; i < 6; i++) {
      seen.add(key(at));
      at = turn(at, 1);
    }
    expect(at).toEqual(start);
    expect(seen.size).toBe(6);
    expect(turn(turn([2, -1], 1), -1)).toEqual([2, -1]);
    // A neighbour turned is a neighbour.
    for (const n of NEIGHBOURS) expect(NEIGHBOURS.map(key)).toContain(key(turn(n, 1)));
  });

  it("steps sideways to the next column on the same zigzag row, from either kind of column", () => {
    for (const c of [2, 3]) {
      for (const dir of [-1, 1]) {
        const step = sideStep(c, dir);
        expect(toOffset(add(toAxial([c, 8]), step))).toEqual([c + dir, 8]);
      }
    }
  });
});
