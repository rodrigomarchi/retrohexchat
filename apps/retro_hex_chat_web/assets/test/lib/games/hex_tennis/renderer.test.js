import { describe, it, expect, beforeEach } from "vitest";
import {
  createMockCtx,
  drawnTexts,
  expectRendersWithoutThrowing,
  itReadsColors,
} from "../../../support/games/renderer_tests.js";
import { PHASE, ANNOUNCEMENT } from "../../../../js/lib/games/hex_tennis/protocol.js";
import { createInitialState } from "../../../../js/lib/games/hex_tennis/physics.js";
import { getColors, render, getPointText } from "../../../../js/lib/games/hex_tennis/renderer.js";

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

// ex_dna:disable-for-lines:12 this test file's own context and palette, made fresh per test
describe("tennis_renderer", () => {
  let ctx;
  let colors;

  beforeEach(() => {
    ctx = createMockCtx();
    colors = createDefaultColors();
  });

  describe("getColors", () => {
    itReadsColors(getColors, {
      bg: "#0a0a14",
      fg: "#39ff14",
      accent: "#00e5ff",
      courtColor: "#0e1a0e",
      ballColor: "#ffee00",
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
    const still = { x: 320, y: 240, vx: 0, vy: 0, speed: 0, height: 0, heightVel: 0 };
    /** A match state in `phase` with the ball at rest at the centre, and `fields` over it. */
    const tennisState = (phase, fields = {}) => ({
      ...createInitialState(0),
      phase,
      ball: still,
      ...fields,
    });
    /** The text one frame of `state` draws. */
    const textsOf = (state) => {
      render(ctx, state, colors, 0);
      return drawnTexts(ctx);
    };

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
      const ball = { x: 320, y: 240, vx: 3, vy: -2, speed: 4, height: 0.3, heightVel: 0 };
      const states = phases.map((phase) =>
        tennisState(phase, { winner: 1, announcement: ANNOUNCEMENT.NONE, ball }),
      );
      expectRendersWithoutThrowing(render, states, colors);
    });

    it("renders with announcement text without throwing", () => {
      const announcements = [
        ANNOUNCEMENT.DEUCE,
        ANNOUNCEMENT.ADV_P1,
        ANNOUNCEMENT.ADV_P2,
        ANNOUNCEMENT.GAME,
        ANNOUNCEMENT.TIEBREAK,
      ];
      const states = announcements.map((announcement) =>
        tennisState(PHASE.POINT, { announcement }),
      );
      expectRendersWithoutThrowing(render, states, colors);
    });

    it("renders countdown with number", () => {
      expect(textsOf(tennisState(PHASE.COUNTDOWN, { countdown: 2 }))).toContain("2");
    });

    it("renders waiting message", () => {
      const texts = textsOf(tennisState(PHASE.WAITING));
      expect(texts.some((t) => t.includes("WAITING"))).toBe(true);
    });

    it("stacks multiple announcements at different y positions", () => {
      const state = tennisState(PHASE.POINT, {
        announcement: ANNOUNCEMENT.GAME,
        outOfBounds: true,
        outType: 1, // WIDE
        netFault: false,
      });
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
      const texts = textsOf(tennisState(PHASE.GAME_OVER, { winner: 1, p1Games: 6, p2Games: 4 }));
      expect(texts.some((t) => t.includes("PLAYER 1"))).toBe(true);
    });
  });
});
