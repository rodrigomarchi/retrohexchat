import { describe, expect, it } from "vitest";
import { NEIGHBOURS, add, turn } from "../../../../js/lib/games/hex_blocks/hex.js";
import { PIECES, fillQueue, shape } from "../../../../js/lib/games/hex_blocks/pieces.js";
import { createRng } from "../../../../js/lib/games/core/rng.js";

const key = ([a, b]) => `${a},${b}`;
/** A shape put where its corner is at the origin, its hexagons in order: two the same are one. */
function normal(cells) {
  const q0 = Math.min(...cells.map(([q]) => q));
  const r0 = Math.min(...cells.map(([, r]) => r));
  return cells
    .map(([q, r]) => [q - q0, r - r0])
    .map(key)
    .sort()
    .join(" ");
}
const turnings = (cells) => {
  const out = [];
  let at = cells;
  for (let i = 0; i < 6; i++) {
    out.push(normal(at));
    at = at.map((c) => turn(c, 1));
  }
  return out;
};

/** Every shape of four hexagons that touch, told apart only by turning. */
function everyTetrahex() {
  let shapes = [[[0, 0]]];
  for (let n = 1; n < 4; n++) {
    const next = new Map();
    for (const s of shapes) {
      for (const cell of s) {
        for (const d of NEIGHBOURS) {
          const c = add(cell, d);
          if (s.some((x) => key(x) === key(c))) continue;
          const grown = [...s, c];
          next.set(turnings(grown).sort()[0], grown);
        }
      }
    }
    shapes = [...next.values()];
  }
  return new Set(shapes.map((s) => turnings(s).sort()[0]));
}

describe("the pieces", () => {
  it("are every shape of four hexagons that touch, the mirrored ones too: ten", () => {
    expect(PIECES).toHaveLength(10);
    const ours = new Set(PIECES.map((p) => turnings(p.cells).sort()[0]));
    expect(ours).toEqual(everyTetrahex());
  });

  it("each turn about a hexagon of their own, in six orientations", () => {
    for (let kind = 0; kind < PIECES.length; kind++) {
      expect(shape(kind, 0).map(key)).toContain("0,0");
      expect(shape(kind, 6)).toEqual(shape(kind, 0));
      expect(shape(kind, -1)).toEqual(shape(kind, 5));
      expect(shape(kind, 1)).toEqual(shape(kind, 0).map((c) => turn(c, 1)));
    }
  });

  it("have a name and a colour each, none twice", () => {
    expect(new Set(PIECES.map((p) => p.name)).size).toBe(10);
    expect(new Set(PIECES.map((p) => p.colour)).size).toBe(10);
  });
});

describe("the queue of pieces", () => {
  it("deals every piece once in each ten, from a shuffled bag", () => {
    const random = createRng(7).fork("bag").next;
    const queue = fillQueue([], random, 30);
    expect(queue.length).toBeGreaterThanOrEqual(30);
    for (let i = 0; i + 10 <= 30; i += 10) {
      expect([...queue.slice(i, i + 10)].sort((a, b) => a - b)).toEqual([...Array(10).keys()]);
    }
  });

  it("deals the same for the same seed, another for another", () => {
    const deal = (seed) => fillQueue([], createRng(seed).fork("bag").next, 20);
    expect(deal(7)).toEqual(deal(7));
    expect(deal(7)).not.toEqual(deal(8));
  });

  it("draws nothing while it holds enough", () => {
    let draws = 0;
    const random = () => {
      draws++;
      return 0.5;
    };
    const queue = fillQueue([1, 2, 3, 4], random, 4);
    expect(queue).toEqual([1, 2, 3, 4]);
    expect(draws).toBe(0);
  });
});
