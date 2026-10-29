import { describe, it, expect } from "vitest";
import {
  PHASE,
  GAME_MODE,
  ALIEN_TYPE,
  SNAPSHOT,
} from "../../../../js/lib/games/hex_invaders/protocol.js";
import * as protocol from "../../../../js/lib/games/hex_invaders/protocol.js";
import {
  describeModeMatchMessages,
  itFramesMessages,
} from "../../../support/games/protocol_tests.js";

/** `count` aliens in rows of six from `left`: a row of TOP, one of MID, then BASE. */
function alienGrid(count, left) {
  return Array.from({ length: count }, (_, i) => ({
    type: i < 6 ? ALIEN_TYPE.TOP : i < 12 ? ALIEN_TYPE.MID : ALIEN_TYPE.BASE,
    x: left + (i % 6) * 40,
    y: 40 + Math.floor(i / 6) * 30,
  }));
}

function createTestState() {
  const aliens1 = alienGrid(30, 20);
  const aliens2 = alienGrid(28, 340);

  return {
    phase: PHASE.PLAYING,
    wave: 3,
    countdown: 0,
    mode: GAME_MODE.INVASION_WAR,
    seed: 123456789,
    score1: 1240,
    score2: 980,
    lives1: 3,
    lives2: 2,
    combo1Count: 3,
    combo2Count: 0,
    cannon1X: 150,
    cannon2X: 470,
    m1X: 150,
    m1Y: 200,
    m1Active: true,
    m2X: 0,
    m2Y: 0,
    m2Active: false,
    aliens1,
    alien1Count: 30,
    aliens2,
    alien2Count: 28,
    alien1DirRight: true,
    alien2DirRight: false,
    bombs: [
      { side: 1, x: 100, y: 300 },
      { side: 2, x: 400, y: 250 },
    ],
    bombCount: 2,
    shields: [4, 3, 4, 2],
    ufoX: 200,
    ufoActive: true,
    ufoDir: 1,
    drops: [
      { type: ALIEN_TYPE.REINFORCEMENT, targetSide: 2, timer: 80 },
      { type: ALIEN_TYPE.ARMORED, targetSide: 1, timer: 120 },
    ],
  };
}

/** A state — the test state unless told — written and read back. */
const roundTrip = (state = createTestState()) => SNAPSHOT.decode(SNAPSHOT.encode(state));

describe("Hex Invaders Protocol", () => {
  describe("GAME_STATE encode/decode round-trip", () => {
    it("preserves all header fields", () => {
      const decoded = roundTrip();

      expect(decoded.phase).toBe(PHASE.PLAYING);
      expect(decoded.wave).toBe(3);
      expect(decoded.countdown).toBe(0);
      expect(decoded.mode).toBe(GAME_MODE.INVASION_WAR);
      expect(decoded.seed).toBe(123456789);
    });

    it("preserves scores and player state", () => {
      const decoded = roundTrip();

      expect(decoded.score1).toBe(1240);
      expect(decoded.score2).toBe(980);
      expect(decoded.lives1).toBe(3);
      expect(decoded.lives2).toBe(2);
      expect(decoded.combo1Count).toBe(3);
      expect(decoded.combo2Count).toBe(0);
    });

    it("preserves cannon positions", () => {
      const decoded = roundTrip();

      expect(decoded.cannon1X).toBe(150);
      expect(decoded.cannon2X).toBe(470);
    });

    it("preserves missile state", () => {
      const decoded = roundTrip();

      expect(decoded.m1X).toBe(150);
      expect(decoded.m1Y).toBe(200);
      expect(decoded.m1Active).toBe(true);
      expect(decoded.m2Active).toBe(false);
    });

    it("preserves alien grids with correct counts", () => {
      const decoded = roundTrip();

      expect(decoded.alien1Count).toBe(30);
      expect(decoded.alien2Count).toBe(28);
      expect(decoded.aliens1[0].type).toBe(ALIEN_TYPE.TOP);
      expect(decoded.aliens1[0].x).toBe(20);
      expect(decoded.aliens1[0].y).toBe(40);
      expect(decoded.aliens1[6].type).toBe(ALIEN_TYPE.MID);
      expect(decoded.aliens1[12].type).toBe(ALIEN_TYPE.BASE);
    });

    it("preserves alien grid directions", () => {
      const decoded = roundTrip();

      expect(decoded.alien1DirRight).toBe(true);
      expect(decoded.alien2DirRight).toBe(false);
    });

    it("preserves bombs with correct count", () => {
      const decoded = roundTrip();

      expect(decoded.bombCount).toBe(2);
      expect(decoded.bombs[0].side).toBe(1);
      expect(decoded.bombs[0].x).toBe(100);
      expect(decoded.bombs[0].y).toBe(300);
      expect(decoded.bombs[1].side).toBe(2);
    });

    it("preserves shield HP values", () => {
      const decoded = roundTrip();

      expect(decoded.shields).toEqual([4, 3, 4, 2]);
    });

    it("preserves UFO state", () => {
      const decoded = roundTrip();

      expect(decoded.ufoX).toBe(200);
      expect(decoded.ufoActive).toBe(true);
      expect(decoded.ufoDir).toBe(1);
    });

    it("preserves drop queue", () => {
      const decoded = roundTrip();

      expect(decoded.dropCount).toBe(2);
      expect(decoded.drops).toHaveLength(2);
      expect(decoded.drops[0].type).toBe(ALIEN_TYPE.REINFORCEMENT);
      expect(decoded.drops[0].targetSide).toBe(2);
      expect(decoded.drops[0].timer).toBe(80);
      expect(decoded.drops[1].type).toBe(ALIEN_TYPE.ARMORED);
      expect(decoded.drops[1].targetSide).toBe(1);
      expect(decoded.drops[1].timer).toBe(120);
    });

    it("has correct message type byte", () => {
      const state = createTestState();
      const buf = SNAPSHOT.encode(state);
      const view = new DataView(buf);
      expect(view.getUint8(0)).toBe(0x80);
    });

    it("produces correct buffer size", () => {
      const state = createTestState();
      const buf = SNAPSHOT.encode(state);
      expect(buf.byteLength).toBe(463);
    });
  });

  describe("GAME_STATE edge cases", () => {
    it("handles zero aliens", () => {
      const state = createTestState();
      state.aliens1 = [];
      state.alien1Count = 0;
      state.aliens2 = [];
      state.alien2Count = 0;

      const decoded = roundTrip(state);
      expect(decoded.alien1Count).toBe(0);
      expect(decoded.alien2Count).toBe(0);
    });

    it("handles max score (65535)", () => {
      const state = createTestState();
      state.score1 = 65535;
      state.score2 = 65535;

      const decoded = roundTrip(state);
      expect(decoded.score1).toBe(65535);
      expect(decoded.score2).toBe(65535);
    });

    it("handles all shields destroyed", () => {
      const state = createTestState();
      state.shields = [0, 0, 0, 0];

      const decoded = roundTrip(state);
      expect(decoded.shields).toEqual([0, 0, 0, 0]);
    });

    it("handles inactive UFO", () => {
      const state = createTestState();
      state.ufoActive = false;
      state.ufoX = 0;

      const decoded = roundTrip(state);
      expect(decoded.ufoActive).toBe(false);
    });

    it("handles empty drop queue", () => {
      const state = createTestState();
      state.drops = [];

      const decoded = roundTrip(state);
      expect(decoded.dropCount).toBe(0);
      expect(decoded.drops).toHaveLength(0);
    });

    itFramesMessages(SNAPSHOT, { short: [10], length: 463, wrongType: 0x81 });
  });

  describeModeMatchMessages(protocol, (overrides) => ({ ...createTestState(), ...overrides }));

  describe("GAME_STATE decode slicing", () => {
    it("slices aliens1 to alien1Count", () => {
      const state = createTestState();
      state.alien1Count = 5;
      state.aliens1 = state.aliens1.slice(0, 5);
      const decoded = roundTrip(state);

      expect(decoded.aliens1).toHaveLength(5);
      expect(decoded.aliens1.every((a) => a.type !== 0)).toBe(true);
    });

    it("slices aliens2 to alien2Count", () => {
      const state = createTestState();
      state.alien2Count = 3;
      state.aliens2 = state.aliens2.slice(0, 3);
      const decoded = roundTrip(state);

      expect(decoded.aliens2).toHaveLength(3);
    });

    it("slices bombs to bombCount", () => {
      const state = createTestState();
      const decoded = roundTrip(state);

      // bombCount is 2, so bombs should have exactly 2 entries
      expect(decoded.bombs).toHaveLength(2);
      expect(decoded.bombs[0].side).toBe(1);
      expect(decoded.bombs[1].side).toBe(2);
    });

    it("returns empty arrays when counts are zero", () => {
      const state = createTestState();
      state.alien1Count = 0;
      state.aliens1 = [];
      state.alien2Count = 0;
      state.aliens2 = [];
      state.bombCount = 0;
      state.bombs = [];
      state.drops = [];

      const decoded = roundTrip(state);
      expect(decoded.aliens1).toHaveLength(0);
      expect(decoded.aliens2).toHaveLength(0);
      expect(decoded.bombs).toHaveLength(0);
      expect(decoded.drops).toHaveLength(0);
    });
  });

  describe("enum values", () => {
    it("PHASE has all expected values", () => {
      expect(PHASE).toMatchObject({
        WAITING: 0,
        COUNTDOWN: 1,
        PLAYING: 2,
        WAVE_CLEAR: 3,
        WAVE_START: 4,
        FINISHED: 5,
      });
    });

    it("GAME_MODE has all expected values", () => {
      expect(GAME_MODE).toMatchObject({ INVASION_WAR: 0, COOP: 1, BLITZ: 2 });
    });

    it("ALIEN_TYPE has all expected values", () => {
      expect(ALIEN_TYPE).toMatchObject({
        NONE: 0,
        BASE: 1,
        MID: 2,
        TOP: 3,
        REINFORCEMENT: 4,
        ARMORED: 5,
      });
    });
  });
});
