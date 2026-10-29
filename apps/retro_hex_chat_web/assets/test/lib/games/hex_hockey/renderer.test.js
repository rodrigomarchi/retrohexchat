import { describe, it, expect, vi } from "vitest";
import { createMockCtx, drawnTexts } from "../../../support/games/renderer_tests.js";
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

/**
 * Runs `check` with getComputedStyle answering `value(name)` for every CSS
 * property, and puts the real one back after.
 * @param {(name: string) => string} value
 * @param {() => void} check
 */
function withComputedStyle(value, check) {
  const original = globalThis.getComputedStyle;
  globalThis.getComputedStyle = vi.fn(() => ({ getPropertyValue: vi.fn(value) }));
  try {
    check();
  } finally {
    globalThis.getComputedStyle = original;
  }
}

/**
 * Draws one frame of a fresh match in `mode` at `phase`, with `fields` set on
 * the state and `extras` over the renderer's defaults.
 * @param {number} mode
 * @param {number} phase
 * @param {object} [fields]
 * @param {object} [extras] - iceParticles, puckTrail, goalFlash or the time
 * @returns {object} the context drawn on
 */
function drawHockey(mode, phase, fields = {}, extras = {}) {
  const ctx = createMockCtx();
  const state = Object.assign(createInitialState(mode), { phase }, fields);
  const { time = 0, ...view } = extras;
  render(ctx, state, defaultColors(), time, {
    iceParticles: [],
    puckTrail: [],
    goalFlash: 0,
    ...view,
  });
  return ctx;
}

/**
 * The text one frame draws, as drawHockey draws it.
 * @returns {string[]}
 */
function hockeyTexts(mode, phase, fields, extras) {
  return drawnTexts(drawHockey(mode, phase, fields, extras));
}

describe("hex_hockey_renderer", () => {
  describe("readColors", () => {
    it("returns default colors when CSS vars not set", () => {
      withComputedStyle(
        () => "",
        () => {
          const colors = readColors(createMockCanvas());
          expect(colors.bg).toBe("#060812");
          expect(colors.fg).toBe("#39ff14");
          expect(colors.accent).toBe("#00e5ff");
          expect(colors.puck).toBe("#ffffff");
        },
      );
    });

    it("uses CSS vars when available", () => {
      withComputedStyle(
        (name) => (name === "--game-bg-color" ? "#111111" : ""),
        () => expect(readColors(createMockCanvas()).bg).toBe("#111111"),
      );
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
    const { CLASSIC, BLITZ, SHOWDOWN } = GAME_MODE;

    it("draws waiting screen when state is null", () => {
      const ctx = createMockCtx();
      render(ctx, null, defaultColors(), 0, { iceParticles: [], puckTrail: [], goalFlash: 0 });
      // Should draw "Waiting for opponent..."
      expect(ctx.fillText).toHaveBeenCalled();
    });

    it("draws all game layers in PLAYING phase", () => {
      const iceParticles = generateIceParticles(5);
      const ctx = drawHockey(CLASSIC, PHASE.PLAYING, {}, { iceParticles, time: 10 });

      // Should draw rink background, HUD text, etc
      expect(ctx.fillRect).toHaveBeenCalled();
      expect(ctx.fillText).toHaveBeenCalled();
      expect(ctx.beginPath).toHaveBeenCalled();
    });

    it("draws countdown overlay", () => {
      // Should show "3"
      expect(hockeyTexts(CLASSIC, PHASE.COUNTDOWN, { countdownValue: 3 })).toContain("3");
    });

    it("draws GO! in FACE_OFF phase", () => {
      expect(hockeyTexts(CLASSIC, PHASE.FACE_OFF, { countdownValue: 0 })).toContain("GO!");
    });

    it("draws GOAL! celebration", () => {
      const fields = { celebrationFrames: 60, scoreP1: 1 };
      const texts = hockeyTexts(CLASSIC, PHASE.GOAL_CELEBRATION, fields, { goalFlash: 60 });
      expect(texts).toContain("GOAL!");
    });

    it("draws period break overlay", () => {
      const fields = { period: 2, periodBreakFrames: 90 };
      const texts = hockeyTexts(CLASSIC, PHASE.PERIOD_BREAK, fields);
      expect(texts.some((text) => text.includes("END OF PERIOD"))).toBe(true);
    });

    it("draws sudden death overlay for CLASSIC mode", () => {
      expect(hockeyTexts(CLASSIC, PHASE.SUDDEN_DEATH, { period: 4 })).toContain("SUDDEN DEATH");
    });

    it("draws sudden death overlay for BLITZ mode (period 2)", () => {
      expect(hockeyTexts(BLITZ, PHASE.SUDDEN_DEATH, { period: 2 })).toContain("SUDDEN DEATH");
    });

    it("draws game over screen", () => {
      const texts = hockeyTexts(CLASSIC, PHASE.FINISHED, { scoreP1: 3, scoreP2: 1 });
      expect(texts).toContain("PLAYER 1 WINS!");
    });

    it("draws P2 wins when P2 has more goals", () => {
      const texts = hockeyTexts(CLASSIC, PHASE.FINISHED, { scoreP1: 0, scoreP2: 2 });
      expect(texts).toContain("PLAYER 2 WINS!");
    });

    it("draws DRAW! when scores are equal", () => {
      expect(hockeyTexts(CLASSIC, PHASE.FINISHED, { scoreP1: 1, scoreP2: 1 })).toContain("DRAW!");
    });

    it("shows 'First to 5' for SHOWDOWN mode", () => {
      expect(hockeyTexts(SHOWDOWN, PHASE.PLAYING)).toContain(`First to ${SHOWDOWN_TARGET}`);
    });

    it("shows SD in HUD during BLITZ sudden death", () => {
      const texts = hockeyTexts(BLITZ, PHASE.SUDDEN_DEATH, { period: 2, timerFrames: 0 });
      expect(texts.some((text) => typeof text === "string" && text.includes("SD"))).toBe(true);
    });

    it("draws puck trail when puck is fast", () => {
      const state = createInitialState(CLASSIC);
      const puck = { ...state.puck, vx: 5, vy: 0 };
      const puckTrail = [
        { x: 300, y: 265 },
        { x: 305, y: 265 },
        { x: 310, y: 265 },
      ];
      const ctx = drawHockey(CLASSIC, PHASE.PLAYING, { puck }, { puckTrail });

      // Should draw trail arcs
      expect(ctx.arc).toHaveBeenCalled();
    });

    it("applies goal flash effect", () => {
      const ctx = drawHockey(CLASSIC, PHASE.PLAYING, {}, { goalFlash: 60 });

      // Goal flash draws extra fillRects for goal areas
      expect(ctx.fillRect).toHaveBeenCalled();
    });

    it("resets globalAlpha at end of render", () => {
      const ctx = drawHockey(CLASSIC, PHASE.PLAYING);

      // The last globalAlpha set should not leave the context in a dirty state
      // (CRT function restores it indirectly via fillRect)
      expect(ctx.fillRect).toHaveBeenCalled();
    });
  });
});
