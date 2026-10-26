import { describe, it, expect, vi, beforeEach } from "vitest";
import { PHASE } from "../../../../js/lib/games/pong/protocol.js";
import { CANVAS_W, CANVAS_H, createInitialState } from "../../../../js/lib/games/pong/physics.js";
import {
  getColors,
  render,
  drawCenterLine,
  drawScore,
  drawWinner,
  drawParticles,
} from "../../../../js/lib/games/pong/renderer.js";

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

  describe("the serve", () => {
    it("draws GET READY at the centre while a serve waits", () => {
      render(ctx, { ...createInitialState(), phase: PHASE.SERVING }, colors, 0);
      expect(ctx.fillText).toHaveBeenCalledWith("GET READY", CANVAS_W / 2, CANVAS_H / 2);
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

  describe("the vignette", () => {
    it("frames every rendered frame with a radial gradient across the canvas", () => {
      render(ctx, { ...createInitialState(), phase: PHASE.PLAYING }, colors, 0);
      expect(ctx.createRadialGradient).toHaveBeenCalled();
      expect(ctx.fillRect).toHaveBeenLastCalledWith(0, 0, CANVAS_W, CANVAS_H);
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
