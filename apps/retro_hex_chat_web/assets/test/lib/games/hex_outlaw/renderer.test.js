import { describe, it, expect, vi } from "vitest";
import {
  getColors,
  render,
  createHitParticles,
  updateParticles,
} from "../../../../js/lib/games/hex_outlaw/renderer.js";
import { createInitialState } from "../../../../js/lib/games/hex_outlaw/physics.js";
import { PHASE, GAME_MODE } from "../../../../js/lib/games/hex_outlaw/protocol.js";
import { itRendersEach } from "../../../support/games/renderer_tests.js";

function createMockCanvas() {
  vi.spyOn(window, "getComputedStyle").mockReturnValue({
    getPropertyValue: (prop) => {
      const map = {
        "--game-bg-color": "#1a0a1e",
        "--game-fg-color": "#39ff14",
        "--game-accent-color": "#00e5ff",
        "--game-muted-color": "#3d1f0a",
        "--game-glow-color": "rgba(255, 140, 0, 0.15)",
        "--game-warning-color": "#ff4444",
        "--game-rope-color": "#c4956a",
        "--game-ring-color": "#2a1508",
        "--game-hit-color": "#ffffff",
      };
      return map[prop] || "";
    },
  });
  return { width: 640, height: 480 };
}

/** The palette the renders draw with. */
const COLORS = Object.freeze({
  bg: "#1a0a1e",
  fg: "#39ff14",
  accent: "#00e5ff",
  muted: "#3d1f0a",
  glow: "rgba(255,140,0,0.15)",
  warning: "#ff4444",
  rope: "#c4956a",
  ring: "#2a1508",
  hit: "#ffffff",
});

describe("Hex Outlaw Renderer", () => {
  describe("getColors", () => {
    it("extracts CSS custom properties", () => {
      const canvas = createMockCanvas();
      const colors = getColors(canvas);
      expect(colors.bg).toBe("#1a0a1e");
      expect(colors.fg).toBe("#39ff14");
      expect(colors.accent).toBe("#00e5ff");
      expect(colors.muted).toBe("#3d1f0a");
      expect(colors.warning).toBe("#ff4444");
      expect(colors.rope).toBe("#c4956a");
      expect(colors.ring).toBe("#2a1508");
      expect(colors.hit).toBe("#ffffff");
    });
  });

  describe("render", () => {
    const at = (fields, mode = GAME_MODE.QUICK_DRAW) => ({
      ...createInitialState(mode),
      ...fields,
    });
    const bullet = { b1active: true, b1x: 200, b1y: 200, b1vx: 8, b1vy: 0 };

    itRendersEach(render, COLORS, [
      { name: "the waiting street", state: at() },
      { name: "the duel", state: at({ phase: PHASE.PLAYING }), frame: 30 },
      { name: "a bullet in flight", state: at({ phase: PHASE.PLAYING, ...bullet }), frame: 10 },
      {
        name: "the match over",
        state: at({ phase: PHASE.MATCH_OVER, roundWins1: 2, roundWins2: 1 }),
      },
      { name: "hit particles", state: at(), particles: createHitParticles(200, 200) },
      ...Object.entries(GAME_MODE).map(([mode, value]) => ({
        name: `the ${mode} street`,
        state: at({ phase: PHASE.PLAYING }, value),
        frame: 10,
      })),
      { name: "the countdown", state: at({ phase: PHASE.COUNTDOWN, countdown: 3 }) },
      { name: "the spawn", state: at({ phase: PHASE.SPAWNING }) },
      {
        name: "the freeze after a hit",
        state: at({ phase: PHASE.HIT_PAUSE, hitPauseTimer: 45, lastHitPlayer: 1 }),
      },
      { name: "a round over", state: at({ phase: PHASE.ROUND_OVER, roundWins1: 1 }) },
      { name: "a hit flash", state: at({ phase: PHASE.HIT_PAUSE, lastHitPlayer: 2 }) },
      {
        name: "the stagecoach on the move",
        state: at({ phase: PHASE.PLAYING, obsY: 100 }, GAME_MODE.STAGECOACH),
        frame: 20,
      },
    ]);
  });

  describe("particles", () => {
    it("createHitParticles generates particles with hat", () => {
      const particles = createHitParticles(100, 200);
      expect(particles.length).toBeGreaterThan(0);
      const hat = particles.find((p) => p.isHat);
      expect(hat).toBeDefined();
      expect(hat.vy).toBeLessThan(0); // Flying upward
    });

    it("updateParticles decrements life and removes dead", () => {
      const particles = [
        { x: 0, y: 0, vx: 1, vy: 1, life: 2, maxLife: 10 },
        { x: 0, y: 0, vx: 1, vy: 1, life: 1, maxLife: 10 },
      ];
      const updated = updateParticles(particles);
      expect(updated.length).toBe(1);
      expect(updated[0].life).toBe(1);
    });

    it("updateParticles applies gravity to hat particles", () => {
      const particles = [{ x: 0, y: 0, vx: 1, vy: -3, life: 10, maxLife: 30, isHat: true }];
      const updated = updateParticles(particles);
      expect(updated[0].vy).toBeGreaterThan(-3); // Gravity pulled it down
    });

    it("updateParticles returns empty array when all dead", () => {
      const particles = [
        { x: 0, y: 0, vx: 1, vy: 1, life: 1, maxLife: 10 },
        { x: 0, y: 0, vx: 1, vy: 1, life: 1, maxLife: 10 },
      ];
      const updated = updateParticles(particles);
      expect(updated.length).toBe(0);
    });

    it("updateParticles moves particles by velocity", () => {
      const particles = [{ x: 10, y: 20, vx: 3, vy: -2, life: 10, maxLife: 10 }];
      const updated = updateParticles(particles);
      expect(updated[0].x).toBe(13);
      expect(updated[0].y).toBe(18);
    });
  });
});
