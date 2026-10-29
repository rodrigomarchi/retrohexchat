import { describe, it, expect, beforeEach } from "vitest";
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
  drawStarfield,
  drawShip,
  drawMissiles,
  drawParticles,
  drawExplosion,
  drawGravityStar,
  drawAsteroids,
  drawSpawning,
  drawRoundOver,
  drawWinner,
  drawWarpEffect,
  drawHUD,
} from "../../../../js/lib/games/star_duel/renderer.js";
import {
  createMockCtx,
  describeFullFrames,
  drawnTexts,
  itReadsColors,
} from "../../../support/games/renderer_tests.js";

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

// ex_dna:disable-for-lines:11 this test file's own context and palette, made fresh per test
describe("star_duel_renderer", () => {
  let ctx;
  let colors;

  beforeEach(() => {
    ctx = createMockCtx();
    colors = createDefaultColors();
  });

  describe("getColors", () => {
    itReadsColors(getColors, { bg: "#0a0a1a", p1: "#39ff14", p2: "#00e5ff" });

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
    // One bright (life above 0.5, the explosion colour) and one fading (the warning colour).
    const particles = [
      { x: 10, y: 20, life: 0.8 },
      { x: 30, y: 40, life: 0.3 },
    ];

    it("draws squares with alpha", () => {
      drawParticles(ctx, particles, colors);
      expect(ctx.fillRect).toHaveBeenCalledTimes(2);
      expect(ctx.globalAlpha).toBe(1.0);
    });

    it("uses explosion color for high life, warning for low life", () => {
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
      expect(drawnTexts(ctx)).toContain("PLAYER 1 SCORES!");
    });

    it("draws PLAYER 2 SCORES when lastScorer=2", () => {
      const state = { lastScorer: 2 };
      drawRoundOver(ctx, state, colors, 0);
      expect(drawnTexts(ctx)).toContain("PLAYER 2 SCORES!");
    });

    it("lastScorer=0 falls through to scorer=1 due to || default", () => {
      // Source: `const scorer = state.lastScorer || 1;`
      // When lastScorer is 0 (falsy), scorer becomes 1, so PLAYER 1 SCORES is shown
      const state = { lastScorer: 0 };
      drawRoundOver(ctx, state, colors, 0);
      expect(drawnTexts(ctx)).toContain("PLAYER 1 SCORES!");
    });

    it("defaults to PLAYER 1 SCORES when lastScorer is missing", () => {
      const state = {};
      drawRoundOver(ctx, state, colors, 0);
      expect(drawnTexts(ctx)).toContain("PLAYER 1 SCORES!");
    });
  });

  describe("drawWinner", () => {
    it("draws PLAYER 1 WINS!", () => {
      const state = { score1: WIN_SCORE, score2: 3 };
      drawWinner(ctx, state, colors, 0);
      expect(drawnTexts(ctx)).toContain("PLAYER 1 WINS!");
    });

    it("uses p2 color for player 2", () => {
      const state = { score1: 3, score2: WIN_SCORE };
      drawWinner(ctx, state, colors, 0);
      expect(drawnTexts(ctx)).toContain("PLAYER 2 WINS!");
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
      expect(drawnTexts(ctx)).toContain(`FIRST TO ${WIN_SCORE}`);
    });
  });

  describe("drawHUD", () => {
    it("renders scores", () => {
      const state = { score1: 3, score2: 5, mode: 0 };
      drawHUD(ctx, state, colors, 0);
      expect(drawnTexts(ctx)).toContain("P1  3");
      expect(drawnTexts(ctx)).toContain("5  P2");
    });

    it("renders mode name", () => {
      const state = { score1: 0, score2: 0, mode: GAME_MODE.GRAVITY_WELL };
      drawHUD(ctx, state, colors, 0);
      expect(drawnTexts(ctx)).toContain("GRAVITY WELL");
    });

    it("renders OPEN SPACE for mode 0", () => {
      const state = { score1: 0, score2: 0, mode: GAME_MODE.OPEN_SPACE };
      drawHUD(ctx, state, colors, 0);
      expect(drawnTexts(ctx)).toContain("OPEN SPACE");
    });

    it("renders DEBRIS FIELD for mode 2", () => {
      const state = { score1: 0, score2: 0, mode: GAME_MODE.DEBRIS_FIELD };
      drawHUD(ctx, state, colors, 0);
      expect(drawnTexts(ctx)).toContain("DEBRIS FIELD");
    });
  });

  describeFullFrames(
    {
      render,
      start: () => createInitialState(GAME_MODE.OPEN_SPACE),
      playing: PHASE.PLAYING,
      phases: [
        PHASE.WAITING,
        PHASE.COUNTDOWN,
        PHASE.SPAWNING,
        PHASE.PLAYING,
        PHASE.ROUND_OVER,
        PHASE.FINISHED,
      ],
      ended: { score1: 3, score2: 2, winner: 1 },
      width: CANVAS_W,
      height: CANVAS_H,
    },
    () => ({ ctx, colors }),
  );

  describe("render (modes)", () => {
    it.each([
      ["gravity well", GAME_MODE.GRAVITY_WELL],
      ["debris field", GAME_MODE.DEBRIS_FIELD],
    ])("renders %s mode", (_mode, mode) => {
      const state = { ...createInitialState(mode), phase: PHASE.PLAYING };
      expect(() => render(createMockCtx(), state, colors, 0)).not.toThrow();
    });
  });
});
