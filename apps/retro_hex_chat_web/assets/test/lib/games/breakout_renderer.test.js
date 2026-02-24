import { describe, it, expect, vi, beforeEach } from "vitest";
import { PHASE } from "../../../js/lib/games/breakout_protocol.js";
import { CANVAS_W, CANVAS_H, createInitialState } from "../../../js/lib/games/breakout_physics.js";
import {
  getColors,
  render,
  drawBackground,
  drawGrid,
  drawBlocks,
  drawPaddle,
  drawBall,
  drawScore,
  drawLives,
  drawCountdown,
  drawServing,
  drawWaiting,
  drawFinished,
  drawParticles,
  drawScanlines,
  drawVignette,
} from "../../../js/lib/games/breakout_renderer.js";

function createMockCtx() {
  return {
    fillStyle: "",
    strokeStyle: "",
    lineWidth: 0,
    globalAlpha: 1.0,
    font: "",
    textAlign: "",
    textBaseline: "",
    shadowColor: "transparent",
    shadowBlur: 0,
    fillRect: vi.fn(),
    strokeRect: vi.fn(),
    fillText: vi.fn(),
    beginPath: vi.fn(),
    moveTo: vi.fn(),
    lineTo: vi.fn(),
    stroke: vi.fn(),
    setLineDash: vi.fn(),
    createRadialGradient: vi.fn(() => ({
      addColorStop: vi.fn(),
    })),
    save: vi.fn(),
    restore: vi.fn(),
  };
}

function createDefaultColors() {
  return {
    bg: "#0a0a1a",
    fg: "#00ffcc",
    accent: "#ff0066",
    muted: "#1a3a4a",
    glow: "rgba(0,255,204,0.2)",
    warning: "#ffaa00",
  };
}

describe("breakout_renderer", () => {
  let ctx;
  let colors;

  beforeEach(() => {
    ctx = createMockCtx();
    colors = createDefaultColors();
  });

  describe("getColors", () => {
    it("reads CSS custom properties from canvas", () => {
      const canvas = document.createElement("canvas");
      canvas.style.setProperty("--game-bg-color", "#111111");
      document.body.appendChild(canvas);

      const result = getColors(canvas);
      expect(result.bg).toBeDefined();

      document.body.removeChild(canvas);
    });

    it("returns fallback colors when properties not set", () => {
      const canvas = document.createElement("canvas");
      document.body.appendChild(canvas);

      const result = getColors(canvas);
      expect(result.bg).toBe("#0a0a1a");
      expect(result.fg).toBe("#00ffcc");
      expect(result.accent).toBe("#ff0066");

      document.body.removeChild(canvas);
    });
  });

  describe("drawBackground", () => {
    it("fills the entire canvas", () => {
      drawBackground(ctx, colors);
      expect(ctx.fillRect).toHaveBeenCalledWith(0, 0, CANVAS_W, CANVAS_H);
      expect(ctx.fillStyle).toBe(colors.bg);
    });
  });

  describe("drawGrid", () => {
    it("draws grid lines", () => {
      drawGrid(ctx, colors);
      expect(ctx.beginPath).toHaveBeenCalled();
      expect(ctx.stroke).toHaveBeenCalled();
      expect(ctx.globalAlpha).toBe(1.0);
    });
  });

  describe("drawBlocks", () => {
    it("draws alive blocks", () => {
      const state = createInitialState();
      drawBlocks(ctx, state.blocks, colors, 0);
      // Each alive block = fillRect (main) + fillRect (highlight) + strokeRect (border)
      expect(ctx.fillRect.mock.calls.length).toBeGreaterThan(50);
    });

    it("skips dead blocks", () => {
      const state = createInitialState();
      state.blocks = state.blocks.map((b) => ({ ...b, alive: false }));
      drawBlocks(ctx, state.blocks, colors, 0);
      expect(ctx.fillRect).not.toHaveBeenCalled();
    });
  });

  describe("drawPaddle", () => {
    it("draws paddle rectangle with glow", () => {
      drawPaddle(ctx, 280, 448, colors.fg);
      expect(ctx.fillRect).toHaveBeenCalled();
      expect(ctx.strokeRect).toHaveBeenCalled();
    });
  });

  describe("drawBall", () => {
    it("draws ball with trail", () => {
      const state = { ...createInitialState(), ballVX: 3, ballVY: 2, phase: PHASE.PLAYING };
      drawBall(ctx, state, colors, 0);
      // Trail (4) + main ball (1) + bright core (1) = 6 fillRect calls
      expect(ctx.fillRect.mock.calls.length).toBeGreaterThanOrEqual(5);
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

  describe("drawCountdown", () => {
    it("draws countdown number", () => {
      drawCountdown(ctx, 3, colors, 0);
      expect(ctx.fillText).toHaveBeenCalledWith("3", CANVAS_W / 2, CANVAS_H / 2);
    });
  });

  describe("drawServing", () => {
    it("draws GET READY text", () => {
      drawServing(ctx, colors, 0);
      expect(ctx.fillText).toHaveBeenCalledWith("GET READY", CANVAS_W / 2, CANVAS_H / 2);
    });
  });

  describe("drawWaiting", () => {
    it("draws waiting message", () => {
      drawWaiting(ctx, colors, 0);
      expect(ctx.fillText).toHaveBeenCalled();
      const text = ctx.fillText.mock.calls[0][0];
      expect(text).toContain("WAITING FOR PARTNER");
    });
  });

  describe("drawFinished", () => {
    it("draws victory text when won", () => {
      drawFinished(ctx, true, colors, 0);
      const texts = ctx.fillText.mock.calls.map((c) => c[0]);
      expect(texts).toContain("VICTORY!");
      expect(texts).toContain("ALL BLOCKS CLEARED");
    });

    it("draws game over text when lost", () => {
      drawFinished(ctx, false, colors, 0);
      const texts = ctx.fillText.mock.calls.map((c) => c[0]);
      expect(texts).toContain("GAME OVER");
      expect(texts).toContain("NO LIVES REMAINING");
    });
  });

  describe("drawParticles", () => {
    it("draws particles", () => {
      const particles = [
        { x: 10, y: 20, life: 0.8, color: "#ff0066" },
        { x: 30, y: 40, life: 0.3, color: "#00ff66" },
      ];
      drawParticles(ctx, particles, colors);
      expect(ctx.fillRect).toHaveBeenCalledTimes(2);
      expect(ctx.globalAlpha).toBe(1.0);
    });
  });

  describe("drawScanlines", () => {
    it("draws horizontal lines across canvas", () => {
      drawScanlines(ctx);
      expect(ctx.fillRect).toHaveBeenCalled();
      expect(ctx.fillRect.mock.calls.length).toBe(CANVAS_H / 2);
    });
  });

  describe("drawVignette", () => {
    it("creates radial gradient", () => {
      drawVignette(ctx);
      expect(ctx.createRadialGradient).toHaveBeenCalled();
      expect(ctx.fillRect).toHaveBeenCalledWith(0, 0, CANVAS_W, CANVAS_H);
    });
  });

  describe("render (full frame)", () => {
    it("renders all phases without throwing", () => {
      const phases = [
        PHASE.WAITING,
        PHASE.COUNTDOWN,
        PHASE.SERVING,
        PHASE.PLAYING,
        PHASE.LIFE_LOST,
        PHASE.FINISHED,
      ];

      for (const phase of phases) {
        const state = {
          ...createInitialState(),
          phase,
          won: true,
          ballVX: 3,
          ballVY: 2,
        };
        expect(() => render(createMockCtx(), state, colors, 0)).not.toThrow();
      }
    });

    it("renders particles when present", () => {
      const state = {
        ...createInitialState(),
        phase: PHASE.PLAYING,
        ballVX: 3,
        ballVY: 2,
        particles: [{ x: 10, y: 20, life: 0.5, color: "#ff0066" }],
      };
      expect(() => render(createMockCtx(), state, colors, 0)).not.toThrow();
    });
  });
});
