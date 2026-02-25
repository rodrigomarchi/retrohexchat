import { describe, it, expect, vi, beforeEach } from "vitest";
import { PHASE, GAME_MODE, WEATHER } from "../../../../js/lib/games/hex_enduro/protocol.js";
import { createInitialState } from "../../../../js/lib/games/hex_enduro/physics.js";
import { getColors, render } from "../../../../js/lib/games/hex_enduro/renderer.js";

function createMockCtx() {
  return {
    fillStyle: "",
    strokeStyle: "",
    lineWidth: 0,
    globalAlpha: 1.0,
    globalCompositeOperation: "source-over",
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
    closePath: vi.fn(),
    fill: vi.fn(),
    stroke: vi.fn(),
    setLineDash: vi.fn(),
    measureText: vi.fn(() => ({ width: 50 })),
    createLinearGradient: vi.fn(() => ({
      addColorStop: vi.fn(),
    })),
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
    p1: "#39ff14",
    p2: "#00e5ff",
    muted: "#1a1a2a",
    glow: "rgba(57,255,20,0.15)",
    warning: "#ff4444",
    road1: "#2a2a3a",
    road2: "#1a1a2a",
    lane: "#555566",
    mountain: "#151525",
    carAi: "#ff8c00",
    fuel: "#ffee00",
  };
}

describe("Hex Enduro Renderer", () => {
  let ctx;
  let colors;

  beforeEach(() => {
    ctx = createMockCtx();
    colors = createDefaultColors();
  });

  describe("getColors", () => {
    it("returns fallback colors when properties not set", () => {
      const canvas = document.createElement("canvas");
      document.body.appendChild(canvas);

      const result = getColors(canvas);
      expect(result.bg).toBe("#0a0a1a");
      expect(result.p1).toBe("#39ff14");
      expect(result.p2).toBe("#00e5ff");
      expect(result.road1).toBe("#2a2a3a");
      expect(result.carAi).toBe("#ff8c00");
      expect(result.fuel).toBe("#ffee00");

      document.body.removeChild(canvas);
    });

    it("returns all expected color keys", () => {
      const canvas = document.createElement("canvas");
      document.body.appendChild(canvas);

      const result = getColors(canvas);
      const expectedKeys = [
        "bg",
        "p1",
        "p2",
        "muted",
        "glow",
        "warning",
        "road1",
        "road2",
        "lane",
        "mountain",
        "carAi",
        "fuel",
      ];
      for (const key of expectedKeys) {
        expect(result[key]).toBeDefined();
      }

      document.body.removeChild(canvas);
    });
  });

  describe("render (full frame)", () => {
    it("renders all phases without throwing (host)", () => {
      const phases = [PHASE.WAITING, PHASE.COUNTDOWN, PHASE.RACING, PHASE.DAY_END, PHASE.FINISHED];

      for (const phase of phases) {
        const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 42);
        state.phase = phase;
        state.aiCars = [{ lane: 1, zPos: 500, speed: 30, type: 0 }];
        state.fuelStations = [{ lane: 1, zPos: 800 }];
        expect(() => render(createMockCtx(), state, colors, 0, true)).not.toThrow();
      }
    });

    it("renders all phases without throwing (peer)", () => {
      const phases = [PHASE.WAITING, PHASE.COUNTDOWN, PHASE.RACING, PHASE.FINISHED];

      for (const phase of phases) {
        const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 42);
        state.phase = phase;
        expect(() => render(createMockCtx(), state, colors, 0, false)).not.toThrow();
      }
    });

    it("renders all weather conditions", () => {
      for (const [, weather] of Object.entries(WEATHER)) {
        const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 42);
        state.phase = PHASE.RACING;
        state.weather = weather;
        expect(() => render(createMockCtx(), state, colors, 0, true)).not.toThrow();
      }
    });

    it("renders all game modes", () => {
      for (const [, mode] of Object.entries(GAME_MODE)) {
        const state = createInitialState(mode, 42);
        state.phase = PHASE.RACING;
        expect(() => render(createMockCtx(), state, colors, 0, true)).not.toThrow();
      }
    });

    it("renders with boost active", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 42);
      state.phase = PHASE.RACING;
      state.p1.boost = 100;
      expect(() => render(ctx, state, colors, 0, true)).not.toThrow();
    });

    it("renders with slipstream active", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 42);
      state.phase = PHASE.RACING;
      state.p1.slipstream = 100;
      state.p2.zOffset = 150;
      expect(() => render(ctx, state, colors, 0, true)).not.toThrow();
    });

    it("renders with low fuel warning", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 42);
      state.phase = PHASE.RACING;
      state.p1.fuel = 50;
      expect(() => render(ctx, state, colors, 200, true)).not.toThrow();
    });

    it("renders finished state with P1 winning", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 42);
      state.phase = PHASE.FINISHED;
      state.p1.score = 100;
      state.p2.score = 80;
      expect(() => render(ctx, state, colors, 0, true)).not.toThrow();
    });

    it("renders finished state as draw", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 42);
      state.phase = PHASE.FINISHED;
      state.p1.score = 100;
      state.p2.score = 100;
      expect(() => render(ctx, state, colors, 0, true)).not.toThrow();
    });
  });
});
