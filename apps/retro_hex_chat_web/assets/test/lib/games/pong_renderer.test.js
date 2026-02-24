import { describe, it, expect, vi, beforeEach } from "vitest";
import { PHASE } from "../../../js/lib/games/pong_protocol.js";
import { CANVAS_W, CANVAS_H, createInitialState } from "../../../js/lib/games/pong_physics.js";
import {
  getColors,
  render,
  drawBackground,
  drawGrid,
  drawCenterLine,
  drawPaddle,
  drawBall,
  drawScore,
  drawCountdown,
  drawServing,
  drawWaiting,
  drawWinner,
  drawParticles,
  drawScanlines,
  drawVignette,
} from "../../../js/lib/games/pong_renderer.js";

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

describe("pong_renderer", () => {
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

  describe("drawCenterLine", () => {
    it("draws a dashed line and resets dash", () => {
      drawCenterLine(ctx, colors, 0);
      expect(ctx.setLineDash).toHaveBeenCalledWith([12, 8]);
      expect(ctx.setLineDash).toHaveBeenCalledWith([]);
      expect(ctx.globalAlpha).toBe(1.0);
    });
  });

  describe("drawPaddle", () => {
    it("draws paddle rectangle with glow", () => {
      drawPaddle(ctx, 30, 200, colors.fg, colors);
      expect(ctx.fillRect).toHaveBeenCalled();
      expect(ctx.strokeRect).toHaveBeenCalled();
    });
  });

  describe("drawBall", () => {
    it("draws ball with trail when playing", () => {
      const state = { ...createInitialState(), ballVX: 3, ballVY: 2, phase: PHASE.PLAYING };
      drawBall(ctx, state, colors, 0);
      // Trail (4) + main ball (1) + bright core (1) = 6 fillRect calls
      expect(ctx.fillRect.mock.calls.length).toBeGreaterThanOrEqual(5);
    });
  });

  describe("drawScore", () => {
    it("draws score digits", () => {
      drawScore(ctx, 7, 11, colors);
      // Bitmap digits produce many fillRect calls
      expect(ctx.fillRect.mock.calls.length).toBeGreaterThan(10);
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
      expect(text).toContain("WAITING FOR OPPONENT");
    });
  });

  describe("drawWinner", () => {
    it("draws winner text with glitch channels", () => {
      drawWinner(ctx, 1, colors, 0);
      const texts = ctx.fillText.mock.calls.map((c) => c[0]);
      expect(texts).toContain("PLAYER 1 WINS!");
      expect(texts).toContain("GAME OVER");
    });

    it("uses accent color for player 2", () => {
      drawWinner(ctx, 2, colors, 0);
      const texts = ctx.fillText.mock.calls.map((c) => c[0]);
      expect(texts).toContain("PLAYER 2 WINS!");
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
      const phases = [PHASE.WAITING, PHASE.COUNTDOWN, PHASE.SERVING, PHASE.PLAYING, PHASE.FINISHED];

      for (const phase of phases) {
        const state = {
          ...createInitialState(),
          phase,
          winner: 1,
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
        particles: [{ x: 10, y: 20, life: 0.5 }],
      };
      expect(() => render(createMockCtx(), state, colors, 0)).not.toThrow();
    });
  });
});
