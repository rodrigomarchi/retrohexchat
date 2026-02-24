import { describe, it, expect, vi } from "vitest";
import {
  getColors,
  render,
  createHitParticles,
  updateParticles,
} from "../../../../js/lib/games/hex_boxing/renderer.js";
import { createInitialState } from "../../../../js/lib/games/hex_boxing/physics.js";
import { PHASE } from "../../../../js/lib/games/hex_boxing/protocol.js";

function createMockCanvas() {
  return {
    width: 640,
    height: 480,
    getContext: () => createMockCtx(),
  };
}

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
    fillStyle: "",
    strokeStyle: "",
    lineWidth: 1,
    lineCap: "butt",
    font: "",
    textAlign: "start",
    textBaseline: "alphabetic",
  };
}

describe("Hex Boxing Renderer", () => {
  describe("getColors", () => {
    it("extracts CSS custom properties", () => {
      vi.spyOn(window, "getComputedStyle").mockReturnValue({
        getPropertyValue: (prop) => {
          if (prop === "--game-bg-color") return " #0a0808 ";
          if (prop === "--game-fg-color") return " #39ff14 ";
          return "";
        },
      });

      const canvas = createMockCanvas();
      const colors = getColors(canvas);
      expect(colors.bg).toBe("#0a0808");
      expect(colors.fg).toBe("#39ff14");
    });

    it("uses defaults when properties are empty", () => {
      vi.spyOn(window, "getComputedStyle").mockReturnValue({
        getPropertyValue: () => "",
      });

      const canvas = createMockCanvas();
      const colors = getColors(canvas);
      expect(colors.bg).toBe("#0a0808");
      expect(colors.fg).toBe("#39ff14");
    });
  });

  describe("render", () => {
    it("renders without throwing", () => {
      const ctx = createMockCtx();
      const state = createInitialState();
      const colors = {
        bg: "#0a0808",
        fg: "#39ff14",
        accent: "#00e5ff",
        muted: "#2a1a1a",
        glow: "rgba(57, 255, 20, 0.15)",
        warning: "#ff4444",
        rope: "#aaaaaa",
        ring: "#1a1208",
        hit: "#ffffff",
      };

      expect(() => render(ctx, state, colors, 0, [])).not.toThrow();
    });

    it("renders FIGHTING phase without throwing", () => {
      const ctx = createMockCtx();
      const state = { ...createInitialState(), phase: PHASE.FIGHTING, roundTimer: 3600 };
      const colors = {
        bg: "#0a0808",
        fg: "#39ff14",
        accent: "#00e5ff",
        muted: "#2a1a1a",
        glow: "rgba(57, 255, 20, 0.15)",
        warning: "#ff4444",
        rope: "#aaaaaa",
        ring: "#1a1208",
        hit: "#ffffff",
      };

      expect(() => render(ctx, state, colors, 100, [])).not.toThrow();
    });

    it("renders COUNTDOWN phase without throwing", () => {
      const ctx = createMockCtx();
      const state = { ...createInitialState(), phase: PHASE.COUNTDOWN, countdown: 3 };
      const colors = {
        bg: "#0a0808",
        fg: "#39ff14",
        accent: "#00e5ff",
        muted: "#2a1a1a",
        glow: "rgba(57, 255, 20, 0.15)",
        warning: "#ff4444",
        rope: "#aaaaaa",
        ring: "#1a1208",
        hit: "#ffffff",
      };

      expect(() => render(ctx, state, colors, 0, [])).not.toThrow();
    });

    it("renders with particles without throwing", () => {
      const ctx = createMockCtx();
      const state = createInitialState();
      const colors = {
        bg: "#0a0808",
        fg: "#39ff14",
        accent: "#00e5ff",
        muted: "#2a1a1a",
        glow: "rgba(57, 255, 20, 0.15)",
        warning: "#ff4444",
        rope: "#aaaaaa",
        ring: "#1a1208",
        hit: "#ffffff",
      };
      const particles = createHitParticles(300, 240, 3);

      expect(() => render(ctx, state, colors, 0, particles)).not.toThrow();
    });

    it("renders ROUND_OVER phase without throwing", () => {
      const ctx = createMockCtx();
      const state = {
        ...createInitialState(),
        phase: PHASE.ROUND_OVER,
        score1: 50,
        score2: 30,
        roundWins1: 1,
        roundWins2: 0,
      };
      const colors = {
        bg: "#0a0808",
        fg: "#39ff14",
        accent: "#00e5ff",
        muted: "#2a1a1a",
        glow: "rgba(57, 255, 20, 0.15)",
        warning: "#ff4444",
        rope: "#aaaaaa",
        ring: "#1a1208",
        hit: "#ffffff",
      };

      expect(() => render(ctx, state, colors, 0, [])).not.toThrow();
    });

    it("renders ROUND_OVER with KO without throwing", () => {
      const ctx = createMockCtx();
      const state = {
        ...createInitialState(),
        phase: PHASE.ROUND_OVER,
        score1: 100,
        score2: 47,
        roundWins1: 1,
        roundWins2: 0,
        koPlayer: 2,
      };
      const colors = {
        bg: "#0a0808",
        fg: "#39ff14",
        accent: "#00e5ff",
        muted: "#2a1a1a",
        glow: "rgba(57, 255, 20, 0.15)",
        warning: "#ff4444",
        rope: "#aaaaaa",
        ring: "#1a1208",
        hit: "#ffffff",
      };

      expect(() => render(ctx, state, colors, 0, [])).not.toThrow();
    });

    it("renders MATCH_OVER phase without throwing", () => {
      const ctx = createMockCtx();
      const state = {
        ...createInitialState(),
        phase: PHASE.MATCH_OVER,
        roundWins1: 2,
        roundWins2: 1,
      };
      const colors = {
        bg: "#0a0808",
        fg: "#39ff14",
        accent: "#00e5ff",
        muted: "#2a1a1a",
        glow: "rgba(57, 255, 20, 0.15)",
        warning: "#ff4444",
        rope: "#aaaaaa",
        ring: "#1a1208",
        hit: "#ffffff",
      };

      expect(() => render(ctx, state, colors, 0, [])).not.toThrow();
    });

    it("renders SPAWNING phase without throwing", () => {
      const ctx = createMockCtx();
      const state = { ...createInitialState(), phase: PHASE.SPAWNING };
      const colors = {
        bg: "#0a0808",
        fg: "#39ff14",
        accent: "#00e5ff",
        muted: "#2a1a1a",
        glow: "rgba(57, 255, 20, 0.15)",
        warning: "#ff4444",
        rope: "#aaaaaa",
        ring: "#1a1208",
        hit: "#ffffff",
      };

      expect(() => render(ctx, state, colors, 0, [])).not.toThrow();
    });

    it("renders hit flash on defender (lastHitPlayer set)", () => {
      const ctx = createMockCtx();
      const state = { ...createInitialState(), lastHitPlayer: 1, lastHitPoints: 3 };
      const colors = {
        bg: "#0a0808",
        fg: "#39ff14",
        accent: "#00e5ff",
        muted: "#2a1a1a",
        glow: "rgba(57, 255, 20, 0.15)",
        warning: "#ff4444",
        rope: "#aaaaaa",
        ring: "#1a1208",
        hit: "#ffffff",
      };

      // Should not throw — hit flash applied to P2 (defender)
      expect(() => render(ctx, state, colors, 0, [])).not.toThrow();
    });

    it("renders punching boxer without throwing", () => {
      const ctx = createMockCtx();
      const state = {
        ...createInitialState(),
        b1punchState: 1, // PUNCHING
        b1punchTimer: 5,
        b1arm: 1,
      };
      const colors = {
        bg: "#0a0808",
        fg: "#39ff14",
        accent: "#00e5ff",
        muted: "#2a1a1a",
        glow: "rgba(57, 255, 20, 0.15)",
        warning: "#ff4444",
        rope: "#aaaaaa",
        ring: "#1a1208",
        hit: "#ffffff",
      };

      expect(() => render(ctx, state, colors, 0, [])).not.toThrow();
    });

    it("renders low timer warning without throwing", () => {
      const ctx = createMockCtx();
      const state = {
        ...createInitialState(),
        phase: PHASE.FIGHTING,
        roundTimer: 300, // 5 seconds left — warning zone
      };
      const colors = {
        bg: "#0a0808",
        fg: "#39ff14",
        accent: "#00e5ff",
        muted: "#2a1a1a",
        glow: "rgba(57, 255, 20, 0.15)",
        warning: "#ff4444",
        rope: "#aaaaaa",
        ring: "#1a1208",
        hit: "#ffffff",
      };

      expect(() => render(ctx, state, colors, 15, [])).not.toThrow();
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
