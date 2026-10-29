import { describe, it, expect } from "vitest";
import { drawNeonBall, drawNeonPaddle, neonColors } from "../../../../js/lib/games/core/neon.js";
import { createMockCtx } from "../../../support/games/renderer_tests.js";

describe("neonColors", () => {
  it("falls back to the neon palette when the canvas sets nothing", () => {
    const canvas = document.createElement("canvas");
    document.body.appendChild(canvas);

    const colors = neonColors(canvas);
    expect(colors.bg).toBe("#0a0a1a");
    expect(colors.fg).toBe("#00ffcc");
    expect(colors.accent).toBe("#ff0066");
    expect(colors.muted).toBe("#1a3a4a");
    expect(colors.warning).toBe("#ffaa00");

    document.body.removeChild(canvas);
  });
});

describe("drawNeonPaddle", () => {
  it("draws the body, the highlight inset by 2 and a frame one pixel out", () => {
    const ctx = createMockCtx();

    drawNeonPaddle(ctx, 30, 200, 12, 80, "#00ffcc");

    expect(ctx.fillRect.mock.calls).toEqual([
      [30, 200, 12, 80],
      [32, 202, 8, 76],
    ]);
    expect(ctx.strokeRect).toHaveBeenCalledWith(29, 199, 14, 82);
    expect(ctx.strokeStyle).toBe("#00ffcc");
    expect(ctx.shadowColor).toBe("transparent");
  });

  it("takes the size it is given, lying down as well as standing", () => {
    const ctx = createMockCtx();

    drawNeonPaddle(ctx, 280, 448, 80, 12, "#ff0066");

    expect(ctx.fillRect.mock.calls[0]).toEqual([280, 448, 80, 12]);
    expect(ctx.strokeRect).toHaveBeenCalledWith(279, 447, 82, 14);
  });
});

describe("drawNeonBall", () => {
  it("draws four trail copies back along the velocity, then the ball and its core", () => {
    const ctx = createMockCtx();
    const state = { ballX: 100, ballY: 50, ballVX: 3, ballVY: 2 };

    drawNeonBall(ctx, state, 10, "#00ffcc", 0);

    expect(ctx.fillRect.mock.calls).toEqual([
      [100 - 24 - 5, 50 - 16 - 5, 10, 10],
      [100 - 18 - 5, 50 - 12 - 5, 10, 10],
      [100 - 12 - 5, 50 - 8 - 5, 10, 10],
      [100 - 6 - 5, 50 - 4 - 5, 10, 10],
      [95, 45, 10, 10],
      [97, 47, 6, 6],
    ]);
    expect(ctx.globalAlpha).toBe(1.0);
    expect(ctx.shadowColor).toBe("transparent");
  });
});
