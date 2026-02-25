import { describe, it, expect, vi } from "vitest";
import {
  readColors,
  render,
  generateSnowParticles,
} from "../../../../js/lib/games/hex_skiing/renderer.js";
import { PHASE, GAME_MODE, SKIER_STATE } from "../../../../js/lib/games/hex_skiing/protocol.js";

function createMockCanvas() {
  const ctx = {
    fillStyle: "",
    strokeStyle: "",
    lineWidth: 0,
    font: "",
    textAlign: "",
    textBaseline: "",
    globalAlpha: 1,
    fillRect: vi.fn(),
    strokeRect: vi.fn(),
    fillText: vi.fn(),
    beginPath: vi.fn(),
    moveTo: vi.fn(),
    lineTo: vi.fn(),
    fill: vi.fn(),
    save: vi.fn(),
    restore: vi.fn(),
    translate: vi.fn(),
    scale: vi.fn(),
    createLinearGradient: vi.fn(() => ({ addColorStop: vi.fn() })),
    createRadialGradient: vi.fn(() => ({ addColorStop: vi.fn() })),
  };
  return { width: 640, height: 480, getContext: vi.fn(() => ctx), _ctx: ctx };
}

describe("Hex Skiing Renderer", () => {
  describe("readColors", () => {
    it("reads CSS custom properties from canvas", () => {
      const mockGetComputedStyle = vi.fn(() => ({
        getPropertyValue: vi.fn((name) => {
          const map = {
            "--game-bg-color": "#0a0a14",
            "--game-fg-color": "#39ff14",
            "--game-accent-color": "#00e5ff",
          };
          return map[name] || "";
        }),
      }));
      globalThis.getComputedStyle = mockGetComputedStyle;

      const canvas = createMockCanvas();
      const colors = readColors(canvas);

      expect(colors.bg).toBe("#0a0a14");
      expect(colors.fg).toBe("#39ff14");
      expect(colors.accent).toBe("#00e5ff");
    });

    it("uses defaults when CSS properties are missing", () => {
      globalThis.getComputedStyle = vi.fn(() => ({
        getPropertyValue: vi.fn(() => ""),
      }));

      const canvas = createMockCanvas();
      const colors = readColors(canvas);

      expect(colors.bg).toBe("#0a0a14");
      expect(colors.fg).toBe("#39ff14");
    });
  });

  describe("generateSnowParticles", () => {
    it("generates the requested number of particles", () => {
      const particles = generateSnowParticles(50);
      expect(particles.length).toBe(50);
    });

    it("each particle has x, y, size, speed, drift", () => {
      const particles = generateSnowParticles(1);
      const p = particles[0];
      expect(p).toHaveProperty("x");
      expect(p).toHaveProperty("y");
      expect(p).toHaveProperty("size");
      expect(p).toHaveProperty("speed");
      expect(p).toHaveProperty("drift");
    });
  });

  describe("render", () => {
    it("does not crash on null state", () => {
      const canvas = createMockCanvas();
      const colors = { bg: "#000", fg: "#0f0", accent: "#0ff", muted: "#333" };
      expect(() => render(canvas._ctx, null, colors, 0, [])).not.toThrow();
    });

    it("renders waiting screen", () => {
      const canvas = createMockCanvas();
      const ctx = canvas._ctx;
      const colors = {
        bg: "#0a0a14",
        fg: "#39ff14",
        accent: "#00e5ff",
        muted: "#1a1a2a",
        snow: "#1a1a2e",
      };
      const state = {
        phase: PHASE.WAITING,
        mode: GAME_MODE.ALPINE_RACE,
      };

      render(ctx, state, colors, 0, []);

      // Should have drawn background and text
      expect(ctx.fillRect).toHaveBeenCalled();
      expect(ctx.fillText).toHaveBeenCalled();
    });

    it("renders racing phase", () => {
      const canvas = createMockCanvas();
      const ctx = canvas._ctx;
      const colors = {
        bg: "#0a0a14",
        fg: "#39ff14",
        accent: "#00e5ff",
        muted: "#1a1a2a",
        snow: "#1a1a2e",
        tree: "#1a3a1a",
        rock: "#555",
        avalanche: "#2a2a3a",
        gateLeft: "#44f",
        gateRight: "#f44",
        boost: "#ff0",
        ice: "#0cf",
        trail: "rgba(57,255,20,0.3)",
        glow: "rgba(57,255,20,0.15)",
        warning: "#f44",
      };
      const state = {
        phase: PHASE.RACING,
        mode: GAME_MODE.ALPINE_RACE,
        round: 0,
        scrollY: 0,
        avalancheY: -100,
        avalancheSpeed: 0.5,
        blizzardActive: false,
        blizzardTimer: 0,
        p1: {
          x: 280,
          velX: 0,
          state: SKIER_STATE.SKIING,
          timer: 10.5,
          boostTimer: 0,
          iceTimer: 0,
          stunTimer: 0,
          distance: 500,
        },
        p2: {
          x: 360,
          velX: 0,
          state: SKIER_STATE.SKIING,
          timer: 11.2,
          boostTimer: 0,
          iceTimer: 0,
          stunTimer: 0,
          distance: 480,
        },
        p1RoundWins: 0,
        p2RoundWins: 0,
        obstacles: [],
        gates: [],
        items: [],
      };

      render(ctx, state, colors, 100, generateSnowParticles(10));

      expect(ctx.fillRect).toHaveBeenCalled();
      expect(ctx.fillText).toHaveBeenCalled();
    });
  });
});
