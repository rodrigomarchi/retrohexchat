import { describe, it, expect, vi, beforeEach } from "vitest";
import { PHASE } from "../../../../js/lib/games/surround/protocol.js";
import {
  CANVAS_W,
  CANVAS_H,
  createInitialState,
} from "../../../../js/lib/games/surround/physics.js";
import {
  getColors,
  render,
  drawBackground,
  drawArena,
  drawGrid,
  drawTrails,
  drawHeads,
  drawParticles,
  drawHUD,
  drawCountdown,
  drawRoundOver,
  drawMatchOver,
  drawWaiting,
  drawScanlines,
  drawVignette,
} from "../../../../js/lib/games/surround/renderer.js";

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
    fill: vi.fn(),
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
    bg: "#050510",
    fg: "#00ff41",
    accent: "#00d4ff",
    muted: "#0a1628",
    glow: "rgba(0,255,65,0.2)",
    warning: "#ffaa00",
  };
}

describe("surround_renderer", () => {
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
      expect(result.bg).toBe("#050510");
      expect(result.fg).toBe("#00ff41");
      expect(result.accent).toBe("#00d4ff");

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

  describe("drawArena", () => {
    it("draws arena border with stroke", () => {
      drawArena(ctx, colors);
      expect(ctx.strokeRect).toHaveBeenCalled();
    });
  });

  describe("drawGrid", () => {
    it("draws grid lines and restores alpha", () => {
      drawGrid(ctx, colors);
      expect(ctx.beginPath).toHaveBeenCalled();
      expect(ctx.stroke).toHaveBeenCalled();
      expect(ctx.globalAlpha).toBe(1.0);
    });
  });

  describe("drawTrails", () => {
    it("draws trail cells", () => {
      const state = createInitialState(0);
      state.phase = PHASE.PLAYING;
      // Place some extra trail cells
      state.grid[10][10] = 1; // P1_TRAIL
      state.grid[10][11] = 2; // P2_TRAIL
      drawTrails(ctx, state, colors, 0);
      // At minimum: initial positions + extra trails (minus heads skipped)
      expect(ctx.fillRect.mock.calls.length).toBeGreaterThanOrEqual(2);
    });

    it("skips empty cells", () => {
      const state = createInitialState(0);
      // Clear all grid cells
      for (let y = 0; y < state.grid.length; y++) {
        state.grid[y].fill(0);
      }
      drawTrails(ctx, state, colors, 0);
      expect(ctx.fillRect).not.toHaveBeenCalled();
    });
  });

  describe("drawHeads", () => {
    it("draws both player heads", () => {
      const state = createInitialState(0);
      drawHeads(ctx, state, colors, 0);
      // Each head: fillRect (body) + fillRect (core) + beginPath (chevron) + fill
      expect(ctx.fillRect).toHaveBeenCalled();
      expect(ctx.fill).toHaveBeenCalled();
    });
  });

  describe("drawParticles", () => {
    it("draws particles", () => {
      const particles = [
        { x: 10, y: 20, life: 0.8, color: "#00ff41" },
        { x: 30, y: 40, life: 0.3, color: "#00d4ff" },
      ];
      drawParticles(ctx, particles);
      expect(ctx.fillRect).toHaveBeenCalledTimes(2);
      expect(ctx.globalAlpha).toBe(1.0);
    });
  });

  describe("drawHUD", () => {
    it("draws scores and round text", () => {
      const state = createInitialState(0);
      state.score1 = 2;
      state.score2 = 1;
      drawHUD(ctx, state, colors);
      // Bitmap digits + round text
      expect(ctx.fillRect).toHaveBeenCalled();
      expect(ctx.fillText).toHaveBeenCalled();
      const texts = ctx.fillText.mock.calls.map((c) => c[0]);
      expect(texts).toContain("ROUND 1");
    });
  });

  describe("drawCountdown", () => {
    it("draws countdown number", () => {
      drawCountdown(ctx, 3, colors, 0);
      expect(ctx.fillText).toHaveBeenCalledWith("3", CANVAS_W / 2, CANVAS_H / 2);
    });
  });

  describe("drawRoundOver", () => {
    it("draws round over text for P1 win", () => {
      const state = { p1Dead: false, p2Dead: true, score1: 1, score2: 0 };
      drawRoundOver(ctx, state, colors, 0);
      const texts = ctx.fillText.mock.calls.map((c) => c[0]);
      expect(texts).toContain("P1 WINS ROUND");
    });

    it("draws DRAW when both die", () => {
      const state = { p1Dead: true, p2Dead: true, score1: 0, score2: 0 };
      drawRoundOver(ctx, state, colors, 0);
      const texts = ctx.fillText.mock.calls.map((c) => c[0]);
      expect(texts).toContain("DRAW");
    });
  });

  describe("drawMatchOver", () => {
    it("draws P1 VICTORY when P1 has more wins", () => {
      const state = { score1: 3, score2: 1 };
      drawMatchOver(ctx, state, colors, 0);
      const texts = ctx.fillText.mock.calls.map((c) => c[0]);
      expect(texts).toContain("P1 VICTORY!");
    });

    it("draws P2 VICTORY when P2 has more wins", () => {
      const state = { score1: 1, score2: 3 };
      drawMatchOver(ctx, state, colors, 0);
      const texts = ctx.fillText.mock.calls.map((c) => c[0]);
      expect(texts).toContain("P2 VICTORY!");
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
        PHASE.PLAYING,
        PHASE.ROUND_OVER,
        PHASE.MATCH_OVER,
      ];

      for (const phase of phases) {
        const state = {
          ...createInitialState(0),
          phase,
          p1Dead: false,
          p2Dead: true,
        };
        expect(() => render(createMockCtx(), state, colors, 0)).not.toThrow();
      }
    });

    it("renders particles when present", () => {
      const state = {
        ...createInitialState(0),
        phase: PHASE.PLAYING,
        particles: [{ x: 10, y: 20, life: 0.5, color: "#00ff41" }],
      };
      expect(() => render(createMockCtx(), state, colors, 0)).not.toThrow();
    });
  });
});
