import { describe, it, expect, vi } from "vitest";
import {
  getColors,
  render,
  createHitParticles,
  updateParticles,
} from "../../../../js/lib/games/hex_outlaw/renderer.js";
import { createInitialState } from "../../../../js/lib/games/hex_outlaw/physics.js";
import { PHASE, GAME_MODE } from "../../../../js/lib/games/hex_outlaw/protocol.js";

function createMockCtx() {
  return {
    fillRect: vi.fn(),
    strokeRect: vi.fn(),
    fillText: vi.fn(),
    beginPath: vi.fn(),
    arc: vi.fn(),
    fill: vi.fn(),
    stroke: vi.fn(),
    moveTo: vi.fn(),
    lineTo: vi.fn(),
    clearRect: vi.fn(),
    save: vi.fn(),
    restore: vi.fn(),
    createLinearGradient: vi.fn(() => ({
      addColorStop: vi.fn(),
    })),
    fillStyle: "",
    strokeStyle: "",
    lineWidth: 1,
    lineCap: "butt",
    font: "",
    textAlign: "start",
    textBaseline: "alphabetic",
  };
}

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
    it("renders WAITING phase without error", () => {
      const ctx = createMockCtx();
      const state = createInitialState(GAME_MODE.QUICK_DRAW);
      const colors = {
        bg: "#1a0a1e",
        fg: "#39ff14",
        accent: "#00e5ff",
        muted: "#3d1f0a",
        glow: "rgba(255,140,0,0.15)",
        warning: "#ff4444",
        rope: "#c4956a",
        ring: "#2a1508",
        hit: "#ffffff",
      };
      expect(() => render(ctx, state, colors, 0, [])).not.toThrow();
    });

    it("renders PLAYING phase without error", () => {
      const ctx = createMockCtx();
      const state = { ...createInitialState(GAME_MODE.QUICK_DRAW), phase: PHASE.PLAYING };
      const colors = {
        bg: "#1a0a1e",
        fg: "#39ff14",
        accent: "#00e5ff",
        muted: "#3d1f0a",
        glow: "rgba(255,140,0,0.15)",
        warning: "#ff4444",
        rope: "#c4956a",
        ring: "#2a1508",
        hit: "#ffffff",
      };
      expect(() => render(ctx, state, colors, 30, [])).not.toThrow();
    });

    it("renders with active bullets without error", () => {
      const ctx = createMockCtx();
      const state = {
        ...createInitialState(GAME_MODE.QUICK_DRAW),
        phase: PHASE.PLAYING,
        b1active: true,
        b1x: 200,
        b1y: 200,
        b1vx: 8,
        b1vy: 0,
      };
      const colors = {
        bg: "#1a0a1e",
        fg: "#39ff14",
        accent: "#00e5ff",
        muted: "#3d1f0a",
        glow: "rgba(255,140,0,0.15)",
        warning: "#ff4444",
        rope: "#c4956a",
        ring: "#2a1508",
        hit: "#ffffff",
      };
      expect(() => render(ctx, state, colors, 10, [])).not.toThrow();
    });

    it("renders MATCH_OVER phase without error", () => {
      const ctx = createMockCtx();
      const state = {
        ...createInitialState(GAME_MODE.QUICK_DRAW),
        phase: PHASE.MATCH_OVER,
        roundWins1: 2,
        roundWins2: 1,
      };
      const colors = {
        bg: "#1a0a1e",
        fg: "#39ff14",
        accent: "#00e5ff",
        muted: "#3d1f0a",
        glow: "rgba(255,140,0,0.15)",
        warning: "#ff4444",
        rope: "#c4956a",
        ring: "#2a1508",
        hit: "#ffffff",
      };
      expect(() => render(ctx, state, colors, 0, [])).not.toThrow();
    });

    it("renders with particles without error", () => {
      const ctx = createMockCtx();
      const state = createInitialState(GAME_MODE.QUICK_DRAW);
      const colors = {
        bg: "#1a0a1e",
        fg: "#39ff14",
        accent: "#00e5ff",
        muted: "#3d1f0a",
        glow: "rgba(255,140,0,0.15)",
        warning: "#ff4444",
        rope: "#c4956a",
        ring: "#2a1508",
        hit: "#ffffff",
      };
      const particles = createHitParticles(200, 200);
      expect(() => render(ctx, state, colors, 0, particles)).not.toThrow();
    });

    it("renders all game modes without error", () => {
      const ctx = createMockCtx();
      const colors = {
        bg: "#1a0a1e",
        fg: "#39ff14",
        accent: "#00e5ff",
        muted: "#3d1f0a",
        glow: "rgba(255,140,0,0.15)",
        warning: "#ff4444",
        rope: "#c4956a",
        ring: "#2a1508",
        hit: "#ffffff",
      };
      for (const mode of [
        GAME_MODE.QUICK_DRAW,
        GAME_MODE.RICOCHET,
        GAME_MODE.STAGECOACH,
        GAME_MODE.NO_MANS_LAND,
      ]) {
        const state = { ...createInitialState(mode), phase: PHASE.PLAYING };
        expect(() => render(ctx, state, colors, 10, [])).not.toThrow();
      }
    });
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

  describe("render edge cases", () => {
    const colors = {
      bg: "#1a0a1e",
      fg: "#39ff14",
      accent: "#00e5ff",
      muted: "#3d1f0a",
      glow: "rgba(255,140,0,0.15)",
      warning: "#ff4444",
      rope: "#c4956a",
      ring: "#2a1508",
      hit: "#ffffff",
    };

    it("renders COUNTDOWN phase without error", () => {
      const ctx = createMockCtx();
      const state = {
        ...createInitialState(GAME_MODE.QUICK_DRAW),
        phase: PHASE.COUNTDOWN,
        countdown: 3,
      };
      expect(() => render(ctx, state, colors, 0, [])).not.toThrow();
    });

    it("renders SPAWNING phase without error", () => {
      const ctx = createMockCtx();
      const state = {
        ...createInitialState(GAME_MODE.QUICK_DRAW),
        phase: PHASE.SPAWNING,
      };
      expect(() => render(ctx, state, colors, 0, [])).not.toThrow();
    });

    it("renders HIT_PAUSE phase without error", () => {
      const ctx = createMockCtx();
      const state = {
        ...createInitialState(GAME_MODE.QUICK_DRAW),
        phase: PHASE.HIT_PAUSE,
        hitPauseTimer: 45,
        lastHitPlayer: 1,
      };
      expect(() => render(ctx, state, colors, 0, [])).not.toThrow();
    });

    it("renders ROUND_OVER phase without error", () => {
      const ctx = createMockCtx();
      const state = {
        ...createInitialState(GAME_MODE.QUICK_DRAW),
        phase: PHASE.ROUND_OVER,
        roundWins1: 1,
        roundWins2: 0,
      };
      expect(() => render(ctx, state, colors, 0, [])).not.toThrow();
    });

    it("renders with lastHitPlayer flag for hit flash", () => {
      const ctx = createMockCtx();
      const state = {
        ...createInitialState(GAME_MODE.QUICK_DRAW),
        phase: PHASE.HIT_PAUSE,
        lastHitPlayer: 2,
      };
      expect(() => render(ctx, state, colors, 0, [])).not.toThrow();
    });

    it("renders stagecoach mode with moving obstacle", () => {
      const ctx = createMockCtx();
      const state = {
        ...createInitialState(GAME_MODE.STAGECOACH),
        phase: PHASE.PLAYING,
        obsY: 100,
      };
      expect(() => render(ctx, state, colors, 20, [])).not.toThrow();
    });
  });
});
