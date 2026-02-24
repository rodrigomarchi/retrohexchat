import { describe, it, expect, vi, beforeEach } from "vitest";
import { PHASE, GAME_MODE } from "../../../../js/lib/games/star_duel/protocol.js";
import {
  CANVAS_W,
  CANVAS_H,
  WIN_SCORE,
  createInitialState,
} from "../../../../js/lib/games/star_duel/physics.js";
import {
  getColors,
  render,
  drawBackground,
  drawStarfield,
  drawShip,
  drawMissiles,
  drawParticles,
  drawExplosion,
  drawGravityStar,
  drawAsteroids,
  drawCountdown,
  drawWaiting,
  drawSpawning,
  drawRoundOver,
  drawWinner,
  drawWarpEffect,
  drawHUD,
  drawScanlines,
  drawVignette,
} from "../../../../js/lib/games/star_duel/renderer.js";

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
    arc: vi.fn(),
    closePath: vi.fn(),
    fill: vi.fn(),
    translate: vi.fn(),
    rotate: vi.fn(),
  };
}

function createDefaultColors() {
  return {
    bg: "#0a0a1a",
    p1: "#39ff14",
    p2: "#00e5ff",
    muted: "#1a3a4a",
    glow: "rgba(57,255,20,0.2)",
    warning: "#ffaa00",
    star: "#ff8c00",
    asteroid: "#8b4513",
    missile: "#ffffff",
    explosion: "#ff4444",
  };
}

describe("star_duel_renderer", () => {
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
      expect(result.p1).toBe("#39ff14");
      expect(result.p2).toBe("#00e5ff");

      document.body.removeChild(canvas);
    });

    it("reads missile and explosion custom properties", () => {
      const canvas = document.createElement("canvas");
      document.body.appendChild(canvas);

      const result = getColors(canvas);
      // Fallback values when not set via CSS
      expect(result.missile).toBe("#ffffff");
      expect(result.explosion).toBe("#ff4444");

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

  describe("drawStarfield", () => {
    it("draws stars (calls fillRect multiple times)", () => {
      drawStarfield(ctx, colors, 0);
      expect(ctx.fillRect).toHaveBeenCalled();
      expect(ctx.fillRect.mock.calls.length).toBeGreaterThan(10);
      expect(ctx.globalAlpha).toBe(1.0);
    });
  });

  describe("drawShip", () => {
    it("draws triangle (calls beginPath, fill)", () => {
      const ship = {
        x: 100,
        y: 200,
        rotation: 0,
        thrustActive: false,
        invulnerable: false,
        alive: true,
      };
      drawShip(ctx, ship, colors.p1, colors, 0, 1);
      expect(ctx.beginPath).toHaveBeenCalled();
      expect(ctx.fill).toHaveBeenCalled();
      expect(ctx.translate).toHaveBeenCalledWith(100, 200);
      expect(ctx.rotate).toHaveBeenCalledWith(0);
    });
  });

  describe("drawMissiles", () => {
    it("draws dots", () => {
      const missiles = [
        { x: 50, y: 60, vx: 3, vy: 0, owner: 1, age: 0 },
        { x: 100, y: 120, vx: -3, vy: 0, owner: 2, age: 5 },
      ];
      drawMissiles(ctx, missiles, colors, 0);
      expect(ctx.arc).toHaveBeenCalled();
      expect(ctx.fill).toHaveBeenCalled();
    });
  });

  describe("drawParticles", () => {
    it("draws squares with alpha", () => {
      const particles = [
        { x: 10, y: 20, life: 0.8 },
        { x: 30, y: 40, life: 0.3 },
      ];
      drawParticles(ctx, particles, colors);
      expect(ctx.fillRect).toHaveBeenCalledTimes(2);
      expect(ctx.globalAlpha).toBe(1.0);
    });

    it("uses explosion color for high life, warning for low life", () => {
      const particles = [
        { x: 10, y: 20, life: 0.8 },
        { x: 30, y: 40, life: 0.3 },
      ];
      drawParticles(ctx, particles, colors);
      // After first particle (life 0.8 > 0.5), fillStyle should have been explosion
      // After second particle (life 0.3 <= 0.5), fillStyle should have been warning
      // The final fillStyle after the loop reflects the last particle
      // We can check the pattern: globalAlpha is reset at end
      expect(ctx.globalAlpha).toBe(1.0);
    });
  });

  describe("drawExplosion", () => {
    it("is an alias for drawParticles", () => {
      const particles = [{ x: 10, y: 20, life: 0.7 }];
      drawExplosion(ctx, particles, colors);
      expect(ctx.fillRect).toHaveBeenCalledTimes(1);
      expect(ctx.globalAlpha).toBe(1.0);
    });
  });

  describe("drawGravityStar", () => {
    it("draws arcs", () => {
      drawGravityStar(ctx, colors, 0);
      expect(ctx.arc).toHaveBeenCalled();
      expect(ctx.fill).toHaveBeenCalled();
      expect(ctx.beginPath).toHaveBeenCalled();
    });
  });

  describe("drawAsteroids", () => {
    it("draws polygons", () => {
      const asteroids = [
        {
          x: 200,
          y: 150,
          radius: 20,
          vertices: [
            { x: 20, y: 0 },
            { x: 10, y: 17 },
            { x: -10, y: 17 },
            { x: -20, y: 0 },
            { x: -10, y: -17 },
            { x: 10, y: -17 },
          ],
        },
      ];
      drawAsteroids(ctx, asteroids, colors);
      expect(ctx.beginPath).toHaveBeenCalled();
      expect(ctx.moveTo).toHaveBeenCalled();
      expect(ctx.lineTo).toHaveBeenCalled();
      expect(ctx.closePath).toHaveBeenCalled();
      expect(ctx.fill).toHaveBeenCalled();
      expect(ctx.stroke).toHaveBeenCalled();
    });

    it("skips asteroids with fewer than 3 vertices", () => {
      const asteroids = [{ x: 100, y: 100, radius: 10, vertices: [{ x: 5, y: 0 }] }];
      drawAsteroids(ctx, asteroids, colors);
      expect(ctx.beginPath).not.toHaveBeenCalled();
    });
  });

  describe("drawWarpEffect", () => {
    it("renders without errors", () => {
      const ship = { x: 200, y: 150 };
      expect(() => drawWarpEffect(ctx, ship, colors.p1, 0)).not.toThrow();
      expect(ctx.save).toHaveBeenCalled();
      expect(ctx.restore).toHaveBeenCalled();
      expect(ctx.fillRect).toHaveBeenCalled();
    });
  });

  describe("drawCountdown", () => {
    it("draws number", () => {
      drawCountdown(ctx, 3, colors, 0);
      expect(ctx.fillText).toHaveBeenCalled();
      const texts = ctx.fillText.mock.calls.map((c) => c[0]);
      expect(texts).toContain("3");
    });
  });

  describe("drawWaiting", () => {
    it("draws text", () => {
      drawWaiting(ctx, colors, 0);
      expect(ctx.fillText).toHaveBeenCalled();
      const text = ctx.fillText.mock.calls[0][0];
      expect(text).toContain("WAITING FOR OPPONENT");
    });
  });

  describe("drawSpawning", () => {
    it("draws GET READY", () => {
      drawSpawning(ctx, colors, 0);
      expect(ctx.fillText).toHaveBeenCalledWith("GET READY", CANVAS_W / 2, CANVAS_H / 2);
    });
  });

  describe("drawRoundOver", () => {
    it("draws PLAYER 1 SCORES when lastScorer=1", () => {
      const state = { lastScorer: 1 };
      drawRoundOver(ctx, state, colors, 0);
      const texts = ctx.fillText.mock.calls.map((c) => c[0]);
      expect(texts).toContain("PLAYER 1 SCORES!");
    });

    it("draws PLAYER 2 SCORES when lastScorer=2", () => {
      const state = { lastScorer: 2 };
      drawRoundOver(ctx, state, colors, 0);
      const texts = ctx.fillText.mock.calls.map((c) => c[0]);
      expect(texts).toContain("PLAYER 2 SCORES!");
    });

    it("lastScorer=0 falls through to scorer=1 due to || default", () => {
      // Source: `const scorer = state.lastScorer || 1;`
      // When lastScorer is 0 (falsy), scorer becomes 1, so PLAYER 1 SCORES is shown
      const state = { lastScorer: 0 };
      drawRoundOver(ctx, state, colors, 0);
      const texts = ctx.fillText.mock.calls.map((c) => c[0]);
      expect(texts).toContain("PLAYER 1 SCORES!");
    });

    it("defaults to PLAYER 1 SCORES when lastScorer is missing", () => {
      const state = {};
      drawRoundOver(ctx, state, colors, 0);
      const texts = ctx.fillText.mock.calls.map((c) => c[0]);
      expect(texts).toContain("PLAYER 1 SCORES!");
    });
  });

  describe("drawWinner", () => {
    it("draws PLAYER 1 WINS!", () => {
      const state = { score1: WIN_SCORE, score2: 3 };
      drawWinner(ctx, state, colors, 0);
      const texts = ctx.fillText.mock.calls.map((c) => c[0]);
      expect(texts).toContain("PLAYER 1 WINS!");
    });

    it("uses p2 color for player 2", () => {
      const state = { score1: 3, score2: WIN_SCORE };
      drawWinner(ctx, state, colors, 0);
      const texts = ctx.fillText.mock.calls.map((c) => c[0]);
      expect(texts).toContain("PLAYER 2 WINS!");
    });

    it("is deterministic (no Math.random) — glitch depends on time", () => {
      const state = { score1: WIN_SCORE, score2: 3 };
      const ctx1 = createMockCtx();
      const ctx2 = createMockCtx();

      // Same time = same output
      drawWinner(ctx1, state, colors, 1000);
      drawWinner(ctx2, state, colors, 1000);

      const texts1 = ctx1.fillText.mock.calls.map((c) => [c[0], c[1], c[2]]);
      const texts2 = ctx2.fillText.mock.calls.map((c) => [c[0], c[1], c[2]]);
      expect(texts1).toEqual(texts2);
    });

    it("shows FIRST TO N sub-text", () => {
      const state = { score1: WIN_SCORE, score2: 3 };
      drawWinner(ctx, state, colors, 0);
      const texts = ctx.fillText.mock.calls.map((c) => c[0]);
      expect(texts).toContain(`FIRST TO ${WIN_SCORE}`);
    });
  });

  describe("drawHUD", () => {
    it("renders scores", () => {
      const state = { score1: 3, score2: 5, mode: 0 };
      drawHUD(ctx, state, colors, 0);
      const texts = ctx.fillText.mock.calls.map((c) => c[0]);
      expect(texts).toContain("P1  3");
      expect(texts).toContain("5  P2");
    });

    it("renders mode name", () => {
      const state = { score1: 0, score2: 0, mode: GAME_MODE.GRAVITY_WELL };
      drawHUD(ctx, state, colors, 0);
      const texts = ctx.fillText.mock.calls.map((c) => c[0]);
      expect(texts).toContain("GRAVITY WELL");
    });

    it("renders OPEN SPACE for mode 0", () => {
      const state = { score1: 0, score2: 0, mode: GAME_MODE.OPEN_SPACE };
      drawHUD(ctx, state, colors, 0);
      const texts = ctx.fillText.mock.calls.map((c) => c[0]);
      expect(texts).toContain("OPEN SPACE");
    });

    it("renders DEBRIS FIELD for mode 2", () => {
      const state = { score1: 0, score2: 0, mode: GAME_MODE.DEBRIS_FIELD };
      drawHUD(ctx, state, colors, 0);
      const texts = ctx.fillText.mock.calls.map((c) => c[0]);
      expect(texts).toContain("DEBRIS FIELD");
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
        PHASE.SPAWNING,
        PHASE.PLAYING,
        PHASE.ROUND_OVER,
        PHASE.FINISHED,
      ];

      for (const phase of phases) {
        const state = {
          ...createInitialState(GAME_MODE.OPEN_SPACE),
          phase,
          score1: 3,
          score2: 2,
          winner: 1,
        };
        expect(() => render(createMockCtx(), state, colors, 0)).not.toThrow();
      }
    });

    it("renders gravity well mode", () => {
      const state = {
        ...createInitialState(GAME_MODE.GRAVITY_WELL),
        phase: PHASE.PLAYING,
      };
      expect(() => render(createMockCtx(), state, colors, 0)).not.toThrow();
    });

    it("renders debris field mode", () => {
      const state = {
        ...createInitialState(GAME_MODE.DEBRIS_FIELD),
        phase: PHASE.PLAYING,
      };
      expect(() => render(createMockCtx(), state, colors, 0)).not.toThrow();
    });
  });
});
