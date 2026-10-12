import { describe, it, expect, vi } from "vitest";

import { drawNineSlice, drawPiece } from "../../../js/lib/space/nine_slice.js";

const PIECE = { img: {}, x: 10, y: 20, w: 30, h: 20, t: 5, r: 6, b: 5, l: 6 };

function calls(fn) {
  const ctx = { drawImage: vi.fn() };
  fn(ctx);
  return ctx.drawImage.mock.calls.map(([, sx, sy, sw, sh, dx, dy, dw, dh]) => ({
    sx,
    sy,
    sw,
    sh,
    dx,
    dy,
    dw,
    dh,
  }));
}

describe("drawNineSlice", () => {
  it("never scales: every source rect lands at its own size", () => {
    for (const c of calls((ctx) => drawNineSlice(ctx, PIECE, 3.4, 7.6, 101, 47))) {
      expect(c.dw).toBe(c.sw);
      expect(c.dh).toBe(c.sh);
    }
  });

  it("draws on whole pixels", () => {
    for (const c of calls((ctx) => drawNineSlice(ctx, PIECE, 3.4, 7.6, 101, 47))) {
      expect(Number.isInteger(c.dx)).toBe(true);
      expect(Number.isInteger(c.dy)).toBe(true);
    }
  });

  it("puts the corners at the box's corners, unchanged", () => {
    const drawn = calls((ctx) => drawNineSlice(ctx, PIECE, 0, 0, 100, 40));
    expect(drawn).toContainEqual({ sx: 10, sy: 20, sw: 6, sh: 5, dx: 0, dy: 0, dw: 6, dh: 5 });
    expect(drawn).toContainEqual({ sx: 34, sy: 35, sw: 6, sh: 5, dx: 94, dy: 35, dw: 6, dh: 5 });
  });

  it("tiles the edges and cuts the last tile short to fill the box exactly", () => {
    const top = calls((ctx) => drawNineSlice(ctx, PIECE, 0, 0, 100, 40)).filter(
      (c) => c.dy === 0 && c.dx >= 6 && c.dx < 94,
    );
    const covered = top.reduce((sum, c) => sum + c.dw, 0);
    expect(covered).toBe(100 - 6 - 6);
    expect(top.at(-1).dw).toBeLessThan(PIECE.w - PIECE.l - PIECE.r);
  });

  it("never draws a box smaller than its corners", () => {
    const drawn = calls((ctx) => drawNineSlice(ctx, PIECE, 0, 0, 4, 4));
    const right = Math.max(...drawn.map((c) => c.dx + c.dw));
    expect(right).toBe(PIECE.l + PIECE.r);
  });
});

describe("drawPiece", () => {
  it("draws a whole sprite, or a cut of it, never stretched", () => {
    const fill = { img: {}, x: 1, y: 2, w: 8, h: 3 };
    expect(calls((ctx) => drawPiece(ctx, fill, 5, 6))).toEqual([
      { sx: 1, sy: 2, sw: 8, sh: 3, dx: 5, dy: 6, dw: 8, dh: 3 },
    ]);
    expect(calls((ctx) => drawPiece(ctx, fill, 5, 6, 3))[0]).toMatchObject({ sw: 3, dw: 3 });
    expect(calls((ctx) => drawPiece(ctx, fill, 5, 6, 0))).toEqual([]);
  });
});
