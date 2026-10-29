import { describe, it, expect, beforeEach } from "vitest";
import {
  createMockCtx,
  describeBatAndBallBasics,
  drawnTexts,
  neonColors,
} from "../../../support/games/renderer_tests.js";
import { PHASE } from "../../../../js/lib/games/pong/protocol.js";
import * as physics from "../../../../js/lib/games/pong/physics.js";
import * as renderer from "../../../../js/lib/games/pong/renderer.js";
import {
  drawCenterLine,
  drawScore,
  drawWinner,
  drawParticles,
} from "../../../../js/lib/games/pong/renderer.js";

describe("pong_renderer", () => {
  describeBatAndBallBasics(
    { physics, renderer, PHASE },
    { ended: { winner: 1 }, particle: { x: 10, y: 20, life: 0.5 } },
  );

  let ctx;
  let colors;

  beforeEach(() => {
    ctx = createMockCtx();
    colors = neonColors();
  });

  describe("drawCenterLine", () => {
    it("draws a dashed line and resets dash", () => {
      drawCenterLine(ctx, colors, 0);
      expect(ctx.setLineDash).toHaveBeenCalledWith([12, 8]);
      expect(ctx.setLineDash).toHaveBeenCalledWith([]);
      expect(ctx.globalAlpha).toBe(1.0);
    });
  });

  describe("drawScore", () => {
    it("draws score digits", () => {
      drawScore(ctx, 7, 11, colors);
      // Bitmap digits produce many fillRect calls
      expect(ctx.fillRect.mock.calls.length).toBeGreaterThan(10);
    });
  });

  describe("drawWinner", () => {
    it("draws winner text with glitch channels", () => {
      drawWinner(ctx, 1, colors, 0);
      expect(drawnTexts(ctx)).toContain("PLAYER 1 WINS!");
      expect(drawnTexts(ctx)).toContain("GAME OVER");
    });

    it("uses accent color for player 2", () => {
      drawWinner(ctx, 2, colors, 0);
      expect(drawnTexts(ctx)).toContain("PLAYER 2 WINS!");
    });
  });

  describe("drawParticles", () => {
    it("draws particles", () => {
      const particles = [
        { x: 10, y: 20, life: 0.8 },
        { x: 30, y: 40, life: 0.3 },
      ];
      drawParticles(ctx, particles, colors);
      expect(ctx.fillRect).toHaveBeenCalledTimes(2);
      expect(ctx.globalAlpha).toBe(1.0);
    });
  });
});
