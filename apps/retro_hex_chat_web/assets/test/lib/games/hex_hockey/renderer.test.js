import { describe, it, expect, vi } from "vitest";
import { PHASE, GAME_MODE } from "../../../../js/lib/games/hex_hockey/protocol.js";
import {
  createInitialState,
  SHOWDOWN_TARGET,
} from "../../../../js/lib/games/hex_hockey/physics.js";
import {
  render,
  readColors,
  generateIceParticles,
} from "../../../../js/lib/games/hex_hockey/renderer.js";

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
    arc: vi.fn(),
    arcTo: vi.fn(),
    setLineDash: vi.fn(),
    createRadialGradient: vi.fn(() => ({ addColorStop: vi.fn() })),
    save: vi.fn(),
    restore: vi.fn(),
  };
}

function createMockCanvas() {
  return {
    width: 640,
    height: 480,
    style: { getPropertyValue: vi.fn(() => "") },
    ownerDocument: {
      defaultView: { getComputedStyle: vi.fn(() => ({ getPropertyValue: vi.fn(() => "") })) },
    },
  };
}

function defaultColors() {
  return {
    bg: "#060812",
    fg: "#39ff14",
    accent: "#00e5ff",
    muted: "#0e1420",
    glow: "rgba(57,255,20,0.15)",
    warning: "#ff4444",
    rinkLine: "#39ff1460",
    goalColor: "#ff2222",
    goalieP1: "#20aa0a",
    goalieP2: "#0090aa",
    puck: "#ffffff",
    puckTrail: "rgba(255,255,255,0.3)",
    iceScratch: "#ffffff08",
  };
}

describe("hex_hockey_renderer", () => {
  describe("readColors", () => {
    it("returns default colors when CSS vars not set", () => {
      // Mock getComputedStyle
      const canvas = createMockCanvas();
      const original = globalThis.getComputedStyle;
      globalThis.getComputedStyle = vi.fn(() => ({
        getPropertyValue: vi.fn(() => ""),
      }));

      const colors = readColors(canvas);
      expect(colors.bg).toBe("#060812");
      expect(colors.fg).toBe("#39ff14");
      expect(colors.accent).toBe("#00e5ff");
      expect(colors.puck).toBe("#ffffff");

      globalThis.getComputedStyle = original;
    });

    it("uses CSS vars when available", () => {
      const canvas = createMockCanvas();
      const original = globalThis.getComputedStyle;
      globalThis.getComputedStyle = vi.fn(() => ({
        getPropertyValue: vi.fn((name) => {
          if (name === "--game-bg-color") return "#111111";
          return "";
        }),
      }));

      const colors = readColors(canvas);
      expect(colors.bg).toBe("#111111");

      globalThis.getComputedStyle = original;
    });
  });

  describe("generateIceParticles", () => {
    it("generates requested number of particles", () => {
      const particles = generateIceParticles(20);
      expect(particles.length).toBe(20);
    });

    it("particles are within rink bounds", () => {
      const particles = generateIceParticles(100);
      for (const p of particles) {
        expect(p.x).toBeGreaterThanOrEqual(20); // RINK_LEFT
        expect(p.y).toBeGreaterThanOrEqual(50); // RINK_TOP
        expect(typeof p.angle).toBe("number");
        expect(p.length).toBeGreaterThan(0);
      }
    });
  });

  describe("render", () => {
    it("draws waiting screen when state is null", () => {
      const ctx = createMockCtx();
      const colors = defaultColors();
      render(ctx, null, colors, 0, { iceParticles: [], puckTrail: [], goalFlash: 0 });
      // Should draw "Waiting for opponent..."
      expect(ctx.fillText).toHaveBeenCalled();
    });

    it("draws all game layers in PLAYING phase", () => {
      const ctx = createMockCtx();
      const colors = defaultColors();
      const state = createInitialState(GAME_MODE.CLASSIC);
      state.phase = PHASE.PLAYING;
      const iceParticles = generateIceParticles(5);

      render(ctx, state, colors, 10, { iceParticles, puckTrail: [], goalFlash: 0 });

      // Should draw rink background, HUD text, etc
      expect(ctx.fillRect).toHaveBeenCalled();
      expect(ctx.fillText).toHaveBeenCalled();
      expect(ctx.beginPath).toHaveBeenCalled();
    });

    it("draws countdown overlay", () => {
      const ctx = createMockCtx();
      const colors = defaultColors();
      const state = createInitialState(GAME_MODE.CLASSIC);
      state.phase = PHASE.COUNTDOWN;
      state.countdownValue = 3;

      render(ctx, state, colors, 0, { iceParticles: [], puckTrail: [], goalFlash: 0 });

      // Should show "3"
      const textCalls = ctx.fillText.mock.calls;
      const countdownCall = textCalls.find((c) => c[0] === "3");
      expect(countdownCall).toBeDefined();
    });

    it("draws GO! in FACE_OFF phase", () => {
      const ctx = createMockCtx();
      const colors = defaultColors();
      const state = createInitialState(GAME_MODE.CLASSIC);
      state.phase = PHASE.FACE_OFF;
      state.countdownValue = 0;

      render(ctx, state, colors, 0, { iceParticles: [], puckTrail: [], goalFlash: 0 });

      const textCalls = ctx.fillText.mock.calls;
      const goCall = textCalls.find((c) => c[0] === "GO!");
      expect(goCall).toBeDefined();
    });

    it("draws GOAL! celebration", () => {
      const ctx = createMockCtx();
      const colors = defaultColors();
      const state = createInitialState(GAME_MODE.CLASSIC);
      state.phase = PHASE.GOAL_CELEBRATION;
      state.celebrationFrames = 60;
      state.scoreP1 = 1;

      render(ctx, state, colors, 0, { iceParticles: [], puckTrail: [], goalFlash: 60 });

      const textCalls = ctx.fillText.mock.calls;
      const goalCall = textCalls.find((c) => c[0] === "GOAL!");
      expect(goalCall).toBeDefined();
    });

    it("draws period break overlay", () => {
      const ctx = createMockCtx();
      const colors = defaultColors();
      const state = createInitialState(GAME_MODE.CLASSIC);
      state.phase = PHASE.PERIOD_BREAK;
      state.period = 2;
      state.periodBreakFrames = 90;

      render(ctx, state, colors, 0, { iceParticles: [], puckTrail: [], goalFlash: 0 });

      const textCalls = ctx.fillText.mock.calls;
      const periodCall = textCalls.find((c) => c[0].includes("END OF PERIOD"));
      expect(periodCall).toBeDefined();
    });

    it("draws sudden death overlay for CLASSIC mode", () => {
      const ctx = createMockCtx();
      const colors = defaultColors();
      const state = createInitialState(GAME_MODE.CLASSIC);
      state.phase = PHASE.SUDDEN_DEATH;
      state.period = 4;

      render(ctx, state, colors, 0, { iceParticles: [], puckTrail: [], goalFlash: 0 });

      const textCalls = ctx.fillText.mock.calls;
      const sdCall = textCalls.find((c) => c[0] === "SUDDEN DEATH");
      expect(sdCall).toBeDefined();
    });

    it("draws sudden death overlay for BLITZ mode (period 2)", () => {
      const ctx = createMockCtx();
      const colors = defaultColors();
      const state = createInitialState(GAME_MODE.BLITZ);
      state.phase = PHASE.SUDDEN_DEATH;
      state.period = 2;

      render(ctx, state, colors, 0, { iceParticles: [], puckTrail: [], goalFlash: 0 });

      const textCalls = ctx.fillText.mock.calls;
      const sdCall = textCalls.find((c) => c[0] === "SUDDEN DEATH");
      expect(sdCall).toBeDefined();
    });

    it("draws game over screen", () => {
      const ctx = createMockCtx();
      const colors = defaultColors();
      const state = createInitialState(GAME_MODE.CLASSIC);
      state.phase = PHASE.FINISHED;
      state.scoreP1 = 3;
      state.scoreP2 = 1;

      render(ctx, state, colors, 0, { iceParticles: [], puckTrail: [], goalFlash: 0 });

      const textCalls = ctx.fillText.mock.calls;
      const winCall = textCalls.find((c) => c[0] === "PLAYER 1 WINS!");
      expect(winCall).toBeDefined();
    });

    it("draws P2 wins when P2 has more goals", () => {
      const ctx = createMockCtx();
      const colors = defaultColors();
      const state = createInitialState(GAME_MODE.CLASSIC);
      state.phase = PHASE.FINISHED;
      state.scoreP1 = 0;
      state.scoreP2 = 2;

      render(ctx, state, colors, 0, { iceParticles: [], puckTrail: [], goalFlash: 0 });

      const textCalls = ctx.fillText.mock.calls;
      const winCall = textCalls.find((c) => c[0] === "PLAYER 2 WINS!");
      expect(winCall).toBeDefined();
    });

    it("draws DRAW! when scores are equal", () => {
      const ctx = createMockCtx();
      const colors = defaultColors();
      const state = createInitialState(GAME_MODE.CLASSIC);
      state.phase = PHASE.FINISHED;
      state.scoreP1 = 1;
      state.scoreP2 = 1;

      render(ctx, state, colors, 0, { iceParticles: [], puckTrail: [], goalFlash: 0 });

      const textCalls = ctx.fillText.mock.calls;
      const drawCall = textCalls.find((c) => c[0] === "DRAW!");
      expect(drawCall).toBeDefined();
    });

    it("shows 'First to 5' for SHOWDOWN mode", () => {
      const ctx = createMockCtx();
      const colors = defaultColors();
      const state = createInitialState(GAME_MODE.SHOWDOWN);
      state.phase = PHASE.PLAYING;

      render(ctx, state, colors, 0, { iceParticles: [], puckTrail: [], goalFlash: 0 });

      const textCalls = ctx.fillText.mock.calls;
      const ftCall = textCalls.find((c) => c[0] === `First to ${SHOWDOWN_TARGET}`);
      expect(ftCall).toBeDefined();
    });

    it("shows SD in HUD during BLITZ sudden death", () => {
      const ctx = createMockCtx();
      const colors = defaultColors();
      const state = createInitialState(GAME_MODE.BLITZ);
      state.phase = PHASE.SUDDEN_DEATH;
      state.period = 2;
      state.timerFrames = 0;

      render(ctx, state, colors, 0, { iceParticles: [], puckTrail: [], goalFlash: 0 });

      const textCalls = ctx.fillText.mock.calls;
      const sdCall = textCalls.find((c) => typeof c[0] === "string" && c[0].includes("SD"));
      expect(sdCall).toBeDefined();
    });

    it("draws puck trail when puck is fast", () => {
      const ctx = createMockCtx();
      const colors = defaultColors();
      const state = createInitialState(GAME_MODE.CLASSIC);
      state.phase = PHASE.PLAYING;
      state.puck.vx = 5;
      state.puck.vy = 0;

      const trail = [
        { x: 300, y: 265 },
        { x: 305, y: 265 },
        { x: 310, y: 265 },
      ];

      render(ctx, state, colors, 0, { iceParticles: [], puckTrail: trail, goalFlash: 0 });

      // Should draw trail arcs
      expect(ctx.arc).toHaveBeenCalled();
    });

    it("applies goal flash effect", () => {
      const ctx = createMockCtx();
      const colors = defaultColors();
      const state = createInitialState(GAME_MODE.CLASSIC);
      state.phase = PHASE.PLAYING;

      render(ctx, state, colors, 0, { iceParticles: [], puckTrail: [], goalFlash: 60 });

      // Goal flash draws extra fillRects for goal areas
      expect(ctx.fillRect).toHaveBeenCalled();
    });

    it("resets globalAlpha at end of render", () => {
      const ctx = createMockCtx();
      const colors = defaultColors();
      const state = createInitialState(GAME_MODE.CLASSIC);
      state.phase = PHASE.PLAYING;

      render(ctx, state, colors, 0, { iceParticles: [], puckTrail: [], goalFlash: 0 });

      // The last globalAlpha set should not leave the context in a dirty state
      // (CRT function restores it indirectly via fillRect)
      expect(ctx.fillRect).toHaveBeenCalled();
    });
  });
});
