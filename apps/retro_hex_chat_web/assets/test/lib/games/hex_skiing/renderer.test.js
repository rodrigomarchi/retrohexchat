import { describe, it, expect, vi } from "vitest";
import {
  readColors,
  render,
  generateSnowParticles,
} from "../../../../js/lib/games/hex_skiing/renderer.js";
import { PHASE, GAME_MODE, SKIER_STATE } from "../../../../js/lib/games/hex_skiing/protocol.js";
import { createInitialState } from "../../../../js/lib/games/hex_skiing/physics.js";
import { createMockCtx } from "../../../support/games/renderer_tests.js";

function createMockCanvas() {
  const ctx = createMockCtx();
  return { width: 640, height: 480, getContext: vi.fn(() => ctx), _ctx: ctx };
}

/** Every colour the renderer draws with. */
const PALETTE = Object.freeze({
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
});

/** The colours read from a canvas whose CSS custom properties are `values`. */
function readColorsFrom(values) {
  globalThis.getComputedStyle = vi.fn(() => ({
    getPropertyValue: vi.fn((name) => values[name] || ""),
  }));
  return readColors(createMockCanvas());
}

describe("Hex Skiing Renderer", () => {
  describe("readColors", () => {
    it("reads CSS custom properties from canvas", () => {
      const colors = readColorsFrom({
        "--game-bg-color": "#0a0a14",
        "--game-fg-color": "#39ff14",
        "--game-accent-color": "#00e5ff",
      });

      expect(colors.bg).toBe("#0a0a14");
      expect(colors.fg).toBe("#39ff14");
      expect(colors.accent).toBe("#00e5ff");
    });

    it("uses defaults when CSS properties are missing", () => {
      const colors = readColorsFrom({});

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
      const ctx = createMockCanvas()._ctx;
      const state = {
        phase: PHASE.WAITING,
        mode: GAME_MODE.ALPINE_RACE,
      };

      render(ctx, state, PALETTE, 0, []);

      // Should have drawn background and text
      expect(ctx.fillRect).toHaveBeenCalled();
      expect(ctx.fillText).toHaveBeenCalled();
    });

    it("renders racing phase", () => {
      const ctx = createMockCanvas()._ctx;
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

      render(ctx, state, PALETTE, 100, generateSnowParticles(10));

      expect(ctx.fillRect).toHaveBeenCalled();
      expect(ctx.fillText).toHaveBeenCalled();
    });
  });

  // The avalanche comes down from the top of the screen. Painted over the
  // whole view while it was still above it, it hid the slope, the skiers
  // and the gates for almost all of every descent.
  describe("the avalanche", () => {
    /** The rectangles filled in the avalanche's colour that cover the whole view. */
    function coversTheView(avalancheScreenY) {
      const state = {
        ...createInitialState(GAME_MODE.ALPINE_RACE, 7),
        phase: PHASE.RACING,
        scrollY: 1000,
      };
      state.avalancheY = state.scrollY + avalancheScreenY;
      const ctx = createMockCtx();
      const covers = [];
      const fillRect = ctx.fillRect;
      ctx.fillRect = (x, y, w, h) => {
        if (ctx.fillStyle === PALETTE.avalanche && x === 0 && y === 0 && w === 640 && h === 480) {
          covers.push(true);
        }
        return fillRect(x, y, w, h);
      };
      render(ctx, state, PALETTE, 0, []);
      return covers.length > 0;
    }

    it("is not drawn over the slope while it is still above the view", () => {
      expect(coversTheView(-200)).toBe(false);
      expect(coversTheView(0)).toBe(false);
    });

    it("covers the view once it has rolled past the bottom", () => {
      expect(coversTheView(520)).toBe(true);
    });
  });

  // A tree drawn in a green barely lighter than the slope could not be seen,
  // nor a rock in a grey close to it.
  it("draws the trees and the rocks in colours that stand out from the slope", () => {
    const colors = readColorsFrom({});
    const luminance = (css) => {
      const hex = css.replace("#", "");
      const [r, g, b] = [0, 2, 4].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255);
      const lin = (c) => (c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4);
      return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b);
    };
    const contrast = (a, b) => {
      const [hi, lo] = [luminance(a), luminance(b)].sort((x, y) => y - x);
      return (hi + 0.05) / (lo + 0.05);
    };
    expect(contrast(colors.tree, colors.bg)).toBeGreaterThanOrEqual(3);
    expect(contrast(colors.rock, colors.bg)).toBeGreaterThanOrEqual(3);
    // The avalanche too: the wall coming down has to be seen coming.
    expect(contrast(colors.avalanche, colors.bg)).toBeGreaterThanOrEqual(3);
  });

  // "AVL" and "12%" were written in 8px over their own bars, unreadable.
  it("labels the bottom bars above them, saying what each measures", () => {
    const state = { ...createInitialState(GAME_MODE.ALPINE_RACE, 7), phase: PHASE.RACING };
    state.p1.distance = 2160;
    const ctx = createMockCtx();
    const written = [];
    const fillText = ctx.fillText;
    ctx.fillText = (text, x, y) => {
      written.push({ text, y, baseline: ctx.textBaseline, font: ctx.font });
      return fillText(text, x, y);
    };
    render(ctx, state, PALETTE, 0, []);
    for (const label of ["AVALANCHE", "COURSE 12%"]) {
      const drawn = written.find(({ text }) => text === label);
      expect(drawn).toBeDefined();
      // The bars span y 464 to 474: the label's foot sits above them.
      expect(drawn.baseline).toBe("bottom");
      expect(drawn.y).toBeLessThanOrEqual(464);
      expect(parseInt(drawn.font.match(/(\d+)px/)[1], 10)).toBeGreaterThanOrEqual(10);
    }
  });

  // The bar filled only once the avalanche was on screen, a few seconds
  // before it caught anybody: it warned of nothing. It fills as the
  // avalanche gains, from well above the view.
  it("fills the avalanche bar as it gains, before it comes into view", () => {
    const widthAt = (screenY) => {
      const state = { ...createInitialState(GAME_MODE.AVALANCHE_ESCAPE, 7), phase: PHASE.RACING };
      state.scrollY = 5000;
      state.avalancheY = state.scrollY + screenY;
      const ctx = createMockCtx();
      const bars = [];
      const fillRect = ctx.fillRect;
      ctx.fillRect = (x, y, w, h) => {
        // The bar's fill: from x 5, at the bar's row, in the fill's colours.
        if (x === 5 && y === 480 - 15 && h === 8 && ctx.fillStyle !== PALETTE.muted) bars.push(w);
        return fillRect(x, y, w, h);
      };
      render(ctx, state, PALETTE, 0, []);
      return bars.at(-1) ?? 0;
    };
    expect(widthAt(-2000)).toBe(0);
    expect(widthAt(-600)).toBeGreaterThan(0);
    expect(widthAt(-600)).toBeLessThan(widthAt(-100));
    expect(widthAt(-100)).toBeLessThan(widthAt(300));
  });
});
