import { describe, expect, it } from "vitest";
import { GEOMETRY, hitAt, layout } from "../../../../js/lib/games/hex_sudoku/layout.js";
import { CEILING, PENALTY, SAFETY_TICKS } from "../../../../js/lib/games/hex_sudoku/protocol.js";
import { winPoints } from "../../../../js/lib/games/hex_sudoku/scoring.js";

describe("a win's points", () => {
  it("are more the faster it was, a minute at least", () => {
    expect(winPoints(3_600)).toBe(10_000);
    expect(winPoints(600)).toBe(10_000);
    expect(winPoints(36_000)).toBe(1_000);
    expect(winPoints(360_000)).toBe(100);
    expect(winPoints(36_001)).toBe(999);
    expect(CEILING).toBe(10_000);
  });

  it("count a mistake as half a minute and a hint as a minute, and three hours call time", () => {
    expect(PENALTY).toEqual({ MISTAKE: 1_800, HINT: 3_600 });
    expect(SAFETY_TICKS).toBe(3 * 60 * 60 * 60);
  });
});

const within = (r, view) =>
  r.x >= 0 && r.y >= 0 && r.x + r.w <= view.width && r.y + r.h <= view.height;
const apart = (a, b) =>
  a.x + a.w <= b.x || b.x + b.w <= a.x || a.y + a.h <= b.y || b.y + b.h <= a.y;
const centre = (r) => [r.x + r.w / 2, r.y + r.h / 2];

describe.each(["LANDSCAPE", "PORTRAIT"])("the table lying %s", (side) => {
  const laid = layout(GEOMETRY[side]);
  const { view, grid } = laid;
  const places = [grid, laid.bar, ...laid.keys, ...Object.values(laid.tools)];

  it("fits the grid, the keys and the tools in the view, none over another", () => {
    for (const r of places) expect(within(r, view)).toBe(true);
    places.forEach((a, n) => {
      for (const b of places.slice(n + 1)) expect(apart(a, b)).toBe(true);
    });
  });

  it("draws the art on whole half pixels: a square of 16, a key and a tool of 24", () => {
    expect(grid.w).toBe(9 * laid.cell);
    expect(((laid.cell / 16) * 2) % 1).toBe(0);
    for (const r of [...laid.keys, ...Object.values(laid.tools)]) {
      expect(((r.w / 24) * 2) % 1).toBe(0);
    }
  });

  it("finds the square, the key or the tool under a point, and nothing between them", () => {
    const square = (i) => ({
      x: grid.x + (i % 9) * laid.cell + 1,
      y: grid.y + Math.floor(i / 9) * laid.cell + 1,
    });
    for (const i of [0, 8, 40, 72, 80]) {
      expect(hitAt(laid, square(i).x, square(i).y)).toEqual({ type: "square", i });
    }
    expect(hitAt(laid, grid.x + grid.w - 0.5, grid.y + grid.h - 0.5)).toEqual({
      type: "square",
      i: 80,
    });
    laid.keys.forEach((key, n) => {
      expect(hitAt(laid, ...centre(key))).toEqual({ type: "key", d: n + 1 });
    });
    for (const [name, r] of Object.entries(laid.tools)) {
      expect(hitAt(laid, ...centre(r))).toEqual({ type: "tool", name });
    }
    expect(hitAt(laid, grid.x - 1, grid.y)).toBe(null);
    expect(hitAt(laid, grid.x + grid.w, grid.y + grid.h)).toBe(null);
  });
});

describe("standing on a phone 390 pixels wide", () => {
  const laid = layout(GEOMETRY.PORTRAIT);
  const css = (px) => (px * 390) / laid.view.width;

  it("keeps squares and keys big enough for a finger", () => {
    expect(css(laid.cell)).toBeGreaterThanOrEqual(36);
    for (const key of laid.keys) expect(css(key.w)).toBeGreaterThanOrEqual(40);
    for (const tool of Object.values(laid.tools)) expect(css(tool.w)).toBeGreaterThanOrEqual(44);
  });

  it("lays the nine keys in one row under the grid, the tools under them", () => {
    const rows = new Set(laid.keys.map((k) => k.y));
    expect(rows.size).toBe(1);
    expect(laid.keys[0].y).toBeGreaterThan(laid.grid.y + laid.grid.h);
    expect(laid.tools.undo.y).toBeGreaterThan(laid.keys[0].y + laid.keys[0].h);
  });
});

describe("lying on a desktop", () => {
  it("puts the keys in three rows of three beside the grid", () => {
    const laid = layout(GEOMETRY.LANDSCAPE);
    expect(new Set(laid.keys.map((k) => k.y)).size).toBe(3);
    expect(laid.keys[0].x).toBeGreaterThan(laid.grid.x + laid.grid.w);
  });
});
