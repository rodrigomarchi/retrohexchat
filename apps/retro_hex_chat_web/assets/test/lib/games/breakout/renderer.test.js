import { describe, it, expect, beforeEach } from "vitest";
import {
  createMockCtx,
  describeBatAndBallBasics,
  drawnTexts,
  neonColors,
} from "../../../support/games/renderer_tests.js";
import { PHASE } from "../../../../js/lib/games/breakout/protocol.js";
import * as physics from "../../../../js/lib/games/breakout/physics.js";
import * as renderer from "../../../../js/lib/games/breakout/renderer.js";
import {
  drawBlocks,
  drawScore,
  drawLives,
  drawFinished,
} from "../../../../js/lib/games/breakout/renderer.js";

describe("breakout_renderer", () => {
  describeBatAndBallBasics(
    { physics, renderer, PHASE },
    {
      morePhases: [PHASE.LIFE_LOST],
      ended: { won: true },
      particle: { x: 10, y: 20, life: 0.5, color: "#ff0066" },
    },
  );

  let ctx;
  let colors;

  beforeEach(() => {
    ctx = createMockCtx();
    colors = neonColors();
  });

  describe("drawBlocks", () => {
    it("draws alive blocks", () => {
      const state = physics.createInitialState();
      drawBlocks(ctx, state.blocks, colors, 0);
      // Each alive block = fillRect (main) + fillRect (highlight) + strokeRect (border)
      expect(ctx.fillRect.mock.calls.length).toBeGreaterThan(50);
    });

    it("skips dead blocks", () => {
      const state = physics.createInitialState();
      state.blocks = state.blocks.map((b) => ({ ...b, alive: false }));
      drawBlocks(ctx, state.blocks, colors, 0);
      expect(ctx.fillRect).not.toHaveBeenCalled();
    });
  });

  describe("drawScore", () => {
    it("draws score digits", () => {
      drawScore(ctx, 150, colors);
      // Bitmap digits produce many fillRect calls
      expect(ctx.fillRect.mock.calls.length).toBeGreaterThan(10);
    });
  });

  describe("drawLives", () => {
    it("draws life indicators", () => {
      drawLives(ctx, 3, colors);
      expect(ctx.fillRect).toHaveBeenCalledTimes(3);
    });

    it("draws fewer when lives lost", () => {
      drawLives(ctx, 1, colors);
      expect(ctx.fillRect).toHaveBeenCalledTimes(1);
    });
  });

  describe("drawFinished", () => {
    it("draws victory text when won", () => {
      drawFinished(ctx, true, colors, 0);
      expect(drawnTexts(ctx)).toContain("VICTORY!");
      expect(drawnTexts(ctx)).toContain("ALL BLOCKS CLEARED");
    });

    it("draws game over text when lost", () => {
      drawFinished(ctx, false, colors, 0);
      expect(drawnTexts(ctx)).toContain("GAME OVER");
      expect(drawnTexts(ctx)).toContain("NO LIVES REMAINING");
    });
  });
});
