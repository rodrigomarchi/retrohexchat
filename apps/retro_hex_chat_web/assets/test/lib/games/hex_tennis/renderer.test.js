import { describe, it, expect, vi, beforeEach } from "vitest";
import { PHASE, ANNOUNCEMENT } from "../../../../js/lib/games/hex_tennis/protocol.js";
import { createInitialState } from "../../../../js/lib/games/hex_tennis/physics.js";
import { getColors, render, getPointText } from "../../../../js/lib/games/hex_tennis/renderer.js";

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
    ellipse: vi.fn(),
    setLineDash: vi.fn(),
    createRadialGradient: vi.fn(() => ({
      addColorStop: vi.fn(),
    })),
    save: vi.fn(),
    restore: vi.fn(),
  };
}

function createDefaultColors() {
  return {
    bg: "#0a0a14",
    fg: "#39ff14",
    accent: "#00e5ff",
    muted: "#1a1a2a",
    glow: "rgba(57,255,20,0.15)",
    warning: "#ffaa00",
    courtColor: "#0e1a0e",
    lineColor: "#39ff1480",
    netColor: "#ff006688",
    ballColor: "#ffee00",
  };
}

describe("tennis_renderer", () => {
  let ctx;
  let colors;

  beforeEach(() => {
    ctx = createMockCtx();
    colors = createDefaultColors();
  });

  describe("getColors", () => {
    it("reads CSS custom properties from canvas", () => {
      const canvas = document.createElement("canvas");
      canvas.style.setProperty("--game-bg-color", "#111111");
      document.body.appendChild(canvas);

      const result = getColors(canvas);
      expect(result.bg).toBeDefined();

      document.body.removeChild(canvas);
    });

    it("returns fallback colors when properties not set", () => {
      const canvas = document.createElement("canvas");
      document.body.appendChild(canvas);

      const result = getColors(canvas);
      expect(result.bg).toBe("#0a0a14");
      expect(result.fg).toBe("#39ff14");
      expect(result.accent).toBe("#00e5ff");
      expect(result.courtColor).toBe("#0e1a0e");
      expect(result.ballColor).toBe("#ffee00");

      document.body.removeChild(canvas);
    });
  });

  describe("getPointText", () => {
    it("returns LOVE for 0 points", () => {
      expect(getPointText(0, 0, false)).toBe("LOVE");
    });

    it("returns 15/30/40 for normal points", () => {
      expect(getPointText(1, 0, false)).toBe("15");
      expect(getPointText(2, 0, false)).toBe("30");
      expect(getPointText(3, 0, false)).toBe("40");
    });

    it("returns AD for advantage", () => {
      expect(getPointText(4, 3, false)).toBe("AD");
    });

    it("returns 40 when opponent has advantage", () => {
      expect(getPointText(3, 4, false)).toBe("40");
    });

    it("returns raw numbers during tiebreak", () => {
      expect(getPointText(0, 0, true)).toBe("0");
      expect(getPointText(5, 3, true)).toBe("5");
      expect(getPointText(12, 11, true)).toBe("12");
    });

    it("handles extended deuce (points > 4)", () => {
      // 5-4: P1 has advantage
      expect(getPointText(5, 4, false)).toBe("AD");
      // 5-5: back to deuce, both show 40
      expect(getPointText(5, 5, false)).toBe("40");
      // 6-5: advantage again
      expect(getPointText(6, 5, false)).toBe("AD");
      // 5-6: opponent has advantage, this player shows 40
      expect(getPointText(5, 6, false)).toBe("40");
    });
  });

  describe("render (full frame)", () => {
    it("renders all phases without throwing", () => {
      const phases = [
        PHASE.WAITING,
        PHASE.COUNTDOWN,
        PHASE.SERVING,
        PHASE.RALLY,
        PHASE.POINT,
        PHASE.CHANGEOVER,
        PHASE.GAME_OVER,
      ];

      for (const phase of phases) {
        const state = {
          ...createInitialState(0),
          phase,
          winner: 1,
          announcement: ANNOUNCEMENT.NONE,
          ball: { x: 320, y: 240, vx: 3, vy: -2, speed: 4, height: 0.3, heightVel: 0 },
        };
        expect(() => render(createMockCtx(), state, colors, 0)).not.toThrow();
      }
    });

    it("renders with announcement text without throwing", () => {
      const announcements = [
        ANNOUNCEMENT.DEUCE,
        ANNOUNCEMENT.ADV_P1,
        ANNOUNCEMENT.ADV_P2,
        ANNOUNCEMENT.GAME,
        ANNOUNCEMENT.TIEBREAK,
      ];

      for (const ann of announcements) {
        const state = {
          ...createInitialState(0),
          phase: PHASE.POINT,
          announcement: ann,
          ball: { x: 320, y: 240, vx: 0, vy: 0, speed: 0, height: 0, heightVel: 0 },
        };
        expect(() => render(createMockCtx(), state, colors, 0)).not.toThrow();
      }
    });

    it("renders countdown with number", () => {
      const state = {
        ...createInitialState(0),
        phase: PHASE.COUNTDOWN,
        countdown: 2,
        ball: { x: 320, y: 240, vx: 0, vy: 0, speed: 0, height: 0, heightVel: 0 },
      };
      render(ctx, state, colors, 0);
      const texts = ctx.fillText.mock.calls.map((c) => c[0]);
      expect(texts).toContain("2");
    });

    it("renders waiting message", () => {
      const state = {
        ...createInitialState(0),
        phase: PHASE.WAITING,
        ball: { x: 320, y: 240, vx: 0, vy: 0, speed: 0, height: 0, heightVel: 0 },
      };
      render(ctx, state, colors, 0);
      const texts = ctx.fillText.mock.calls.map((c) => c[0]);
      expect(texts.some((t) => t.includes("WAITING"))).toBe(true);
    });

    it("stacks multiple announcements at different y positions", () => {
      const state = {
        ...createInitialState(0),
        phase: PHASE.POINT,
        announcement: ANNOUNCEMENT.GAME,
        outOfBounds: true,
        outType: 1, // WIDE
        netFault: false,
        ball: { x: 320, y: 240, vx: 0, vy: 0, speed: 0, height: 0, heightVel: 0 },
      };
      render(ctx, state, colors, 0);
      // "GAME!" and "OUT!" should be rendered at different y positions
      const fillTextCalls = ctx.fillText.mock.calls;
      const gameYPositions = fillTextCalls.filter((c) => c[0] === "GAME!").map((c) => c[2]);
      const outYPositions = fillTextCalls.filter((c) => c[0] === "OUT!").map((c) => c[2]);
      // Both should be rendered (3 calls each: red glitch, blue glitch, main)
      expect(gameYPositions.length).toBe(3);
      expect(outYPositions.length).toBe(3);
      // They should be at different y positions
      expect(gameYPositions[0]).not.toBe(outYPositions[0]);
    });

    it("renders winner screen", () => {
      const state = {
        ...createInitialState(0),
        phase: PHASE.GAME_OVER,
        winner: 1,
        p1Games: 6,
        p2Games: 4,
        ball: { x: 320, y: 240, vx: 0, vy: 0, speed: 0, height: 0, heightVel: 0 },
      };
      render(ctx, state, colors, 0);
      const texts = ctx.fillText.mock.calls.map((c) => c[0]);
      expect(texts.some((t) => t.includes("PLAYER 1"))).toBe(true);
    });
  });
});
