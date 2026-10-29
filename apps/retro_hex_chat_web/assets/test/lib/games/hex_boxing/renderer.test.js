import { describe, it, expect, vi } from "vitest";
import {
  getColors,
  render,
  createHitParticles,
  updateParticles,
} from "../../../../js/lib/games/hex_boxing/renderer.js";
import { createInitialState } from "../../../../js/lib/games/hex_boxing/physics.js";
import { PHASE, PUNCH_STATE } from "../../../../js/lib/games/hex_boxing/protocol.js";
import { createMockCtx, itRendersEach } from "../../../support/games/renderer_tests.js";

function createMockCanvas() {
  return {
    width: 640,
    height: 480,
    getContext: () => createMockCtx(),
  };
}

/** The palette the renders draw with. */
const COLORS = Object.freeze({
  bg: "#0a0808",
  fg: "#39ff14",
  accent: "#00e5ff",
  muted: "#2a1a1a",
  glow: "rgba(57, 255, 20, 0.15)",
  warning: "#ff4444",
  rope: "#aaaaaa",
  ring: "#1a1208",
  hit: "#ffffff",
});

describe("Hex Boxing Renderer", () => {
  describe("getColors", () => {
    it.each([
      [
        "extracts CSS custom properties",
        { "--game-bg-color": " #0a0808 ", "--game-fg-color": " #39ff14 " },
      ],
      ["uses defaults when properties are empty", {}],
    ])("%s", (_case, properties) => {
      vi.spyOn(window, "getComputedStyle").mockReturnValue({
        getPropertyValue: (prop) => properties[prop] ?? "",
      });

      expect(getColors(createMockCanvas())).toMatchObject({ bg: "#0a0808", fg: "#39ff14" });
    });
  });

  describe("render", () => {
    const at = (fields) => ({ ...createInitialState(), ...fields });

    itRendersEach(render, COLORS, [
      { name: "the waiting ring", state: at() },
      { name: "the fight", state: at({ phase: PHASE.FIGHTING, roundTimer: 3600 }), frame: 100 },
      { name: "the countdown", state: at({ phase: PHASE.COUNTDOWN, countdown: 3 }) },
      { name: "hit particles", state: at(), particles: createHitParticles(300, 240, 3) },
      {
        name: "a round over",
        state: at({ phase: PHASE.ROUND_OVER, score1: 50, score2: 30, roundWins1: 1 }),
      },
      {
        name: "a round over by KO",
        state: at({ phase: PHASE.ROUND_OVER, score1: 100, score2: 47, roundWins1: 1, koPlayer: 2 }),
      },
      {
        name: "the match over",
        state: at({ phase: PHASE.MATCH_OVER, roundWins1: 2, roundWins2: 1 }),
      },
      { name: "the spawn", state: at({ phase: PHASE.SPAWNING }) },
      // The hit flash lands on player two, the defender.
      { name: "a hit flash", state: at({ lastHitPlayer: 1, lastHitPoints: 3 }) },
      {
        name: "a boxer winding up",
        state: at({ b1punchState: PUNCH_STATE.WINDUP, b1punchTimer: 6, b1arm: 0 }),
      },
      {
        name: "a punching boxer",
        state: at({ b1punchState: PUNCH_STATE.PUNCHING, b1punchTimer: 5, b1arm: 1 }),
      },
      // 5 seconds left — the warning zone.
      {
        name: "the low-timer warning",
        state: at({ phase: PHASE.FIGHTING, roundTimer: 300 }),
        frame: 15,
      },
    ]);
  });

  describe("wind-up", () => {
    const warningStrokes = (state) => {
      const ctx = createMockCtx();
      const strokes = [];
      ctx.stroke = vi.fn(() => strokes.push(ctx.strokeStyle));
      render(ctx, state, COLORS, 0, []);
      return strokes.filter((style) => style === COLORS.warning).length;
    };

    it("rings the cocked fist in the warning colour so the rival sees the punch coming", () => {
      const winding = {
        ...createInitialState(),
        b1punchState: PUNCH_STATE.WINDUP,
        b1punchTimer: 6,
      };

      expect(warningStrokes(winding)).toBe(1);
      expect(warningStrokes(createInitialState())).toBe(0);
    });
  });

  describe("particles", () => {
    it("createHitParticles creates particles with count proportional to points", () => {
      const p1 = createHitParticles(100, 100, 1);
      const p3 = createHitParticles(100, 100, 3);
      expect(p3.length).toBeGreaterThan(p1.length);
    });

    it("updateParticles decrements life", () => {
      const particles = [{ x: 100, y: 100, vx: 1, vy: 1, life: 10, maxLife: 20 }];
      const updated = updateParticles(particles);
      expect(updated[0].life).toBe(9);
    });

    it("updateParticles removes dead particles", () => {
      const particles = [{ x: 100, y: 100, vx: 1, vy: 1, life: 1, maxLife: 20 }];
      const updated = updateParticles(particles);
      expect(updated.length).toBe(0);
    });

    it("updateParticles applies velocity and drag", () => {
      const particles = [{ x: 100, y: 100, vx: 10, vy: 5, life: 20, maxLife: 20 }];
      const updated = updateParticles(particles);
      expect(updated[0].x).toBe(110);
      expect(updated[0].y).toBe(105);
      expect(updated[0].vx).toBeCloseTo(9.5); // 10 * 0.95
      expect(updated[0].vy).toBeCloseTo(4.75); // 5 * 0.95
    });

    it("updateParticles handles empty array", () => {
      const updated = updateParticles([]);
      expect(updated.length).toBe(0);
    });

    it("createHitParticles creates correct counts (3 per point)", () => {
      expect(createHitParticles(100, 100, 1).length).toBe(3);
      expect(createHitParticles(100, 100, 2).length).toBe(6);
      expect(createHitParticles(100, 100, 3).length).toBe(9);
    });

    it("createHitParticles sets position and valid life values", () => {
      const particles = createHitParticles(200, 300, 2);
      for (const p of particles) {
        expect(p.x).toBe(200);
        expect(p.y).toBe(300);
        expect(p.life).toBeGreaterThan(0);
        expect(p.life).toBeLessThanOrEqual(p.maxLife);
      }
    });
  });
});
