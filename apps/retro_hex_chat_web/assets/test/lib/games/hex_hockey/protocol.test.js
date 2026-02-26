import { describe, it, expect } from "vitest";
import {
  MSG_TYPE,
  PHASE,
  INPUT_KEY,
  GAME_MODE,
  EVENT,
  encodeGameState,
  decodeGameState,
  encodePlayerInput,
  decodePlayerInput,
  encodeGameEnd,
  decodeGameEnd,
  encodeGameReady,
  getMessageType,
} from "../../../../js/lib/games/hex_hockey/protocol.js";

function makeState(overrides = {}) {
  return {
    phase: PHASE.PLAYING,
    mode: GAME_MODE.CLASSIC,
    eventFlags: 0,
    p1x: 260,
    p1y: 265,
    p1facing: 0,
    p1hasPuck: false,
    p1stunned: false,
    p2x: 380,
    p2y: 265,
    p2facing: 4,
    p2hasPuck: false,
    p2stunned: false,
    stunTimerP1: 0,
    stunTimerP2: 0,
    g1y: 265,
    g2y: 265,
    puckX: 320,
    puckY: 265,
    puckVx: 0,
    puckVy: 0,
    puckPossessedBy: 0,
    scoreP1: 0,
    scoreP2: 0,
    period: 1,
    timerFrames: 7200,
    countdownValue: 0,
    sidesSwapped: false,
    ...overrides,
  };
}

describe("hex_hockey_protocol", () => {
  describe("getMessageType", () => {
    it("reads type byte from ArrayBuffer", () => {
      const buf = new ArrayBuffer(2);
      new DataView(buf).setUint8(0, MSG_TYPE.GAME_STATE);
      expect(getMessageType(buf)).toBe(MSG_TYPE.GAME_STATE);
    });

    it("returns null for empty buffer", () => {
      expect(getMessageType(new ArrayBuffer(0))).toBeNull();
    });

    it("returns null for null/undefined", () => {
      expect(getMessageType(null)).toBeNull();
      expect(getMessageType(undefined)).toBeNull();
    });
  });

  describe("GAME_STATE encode/decode", () => {
    it("roundtrips a full game state", () => {
      const state = makeState({
        p1x: 100,
        p1y: 200,
        p1facing: 3,
        p1hasPuck: true,
        p1stunned: false,
        p2x: 500,
        p2y: 300,
        p2facing: 7,
        p2hasPuck: false,
        p2stunned: true,
        stunTimerP1: 0,
        stunTimerP2: 12,
        g1y: 250,
        g2y: 270,
        puckX: 100,
        puckY: 200,
        puckVx: 3.45,
        puckVy: -2.1,
        puckPossessedBy: 1,
        scoreP1: 3,
        scoreP2: 2,
        period: 2,
        timerFrames: 3600,
        countdownValue: 0,
        sidesSwapped: true,
      });

      const buf = encodeGameState(state);
      expect(buf.byteLength).toBe(39);
      expect(getMessageType(buf)).toBe(MSG_TYPE.GAME_STATE);

      const decoded = decodeGameState(buf);
      expect(decoded.phase).toBe(PHASE.PLAYING);
      expect(decoded.mode).toBe(GAME_MODE.CLASSIC);
      expect(decoded.p1x).toBe(100);
      expect(decoded.p1y).toBe(200);
      expect(decoded.p1facing).toBe(3);
      expect(decoded.p1hasPuck).toBe(true);
      expect(decoded.p1stunned).toBe(false);
      expect(decoded.p2x).toBe(500);
      expect(decoded.p2y).toBe(300);
      expect(decoded.p2facing).toBe(7);
      expect(decoded.p2hasPuck).toBe(false);
      expect(decoded.p2stunned).toBe(true);
      expect(decoded.stunTimerP1).toBe(0);
      expect(decoded.stunTimerP2).toBe(12);
      expect(decoded.g1y).toBe(250);
      expect(decoded.g2y).toBe(270);
      expect(decoded.puckX).toBe(100);
      expect(decoded.puckY).toBe(200);
      expect(decoded.puckVx).toBeCloseTo(3.45, 1);
      expect(decoded.puckVy).toBeCloseTo(-2.1, 1);
      expect(decoded.puckPossessedBy).toBe(1);
      expect(decoded.scoreP1).toBe(3);
      expect(decoded.scoreP2).toBe(2);
      expect(decoded.period).toBe(2);
      expect(decoded.timerFrames).toBe(3600);
      expect(decoded.countdownValue).toBe(0);
      expect(decoded.sidesSwapped).toBe(true);
    });

    it("roundtrips event flags bitmask", () => {
      const flags = EVENT.GOAL_P1 | EVENT.SHOT | EVENT.WALL_BOUNCE;
      const state = makeState({ eventFlags: flags });
      const decoded = decodeGameState(encodeGameState(state));
      expect(decoded.eventFlags & EVENT.GOAL_P1).toBeTruthy();
      expect(decoded.eventFlags & EVENT.SHOT).toBeTruthy();
      expect(decoded.eventFlags & EVENT.WALL_BOUNCE).toBeTruthy();
      expect(decoded.eventFlags & EVENT.GOAL_P2).toBeFalsy();
    });

    it("roundtrips all event flags", () => {
      const allEvents =
        EVENT.GOAL_P1 |
        EVENT.GOAL_P2 |
        EVENT.TACKLE_SUCCESS |
        EVENT.TACKLE_FAIL |
        EVENT.PERIOD_END |
        EVENT.FACE_OFF |
        EVENT.SUDDEN_DEATH |
        EVENT.SHOT |
        EVENT.WALL_BOUNCE |
        EVENT.GOALIE_BLOCK |
        EVENT.CAPTURE |
        EVENT.WHISTLE;
      const state = makeState({ eventFlags: allEvents });
      const decoded = decodeGameState(encodeGameState(state));
      expect(decoded.eventFlags).toBe(allEvents);
    });

    it("roundtrips all game modes", () => {
      for (const mode of [GAME_MODE.CLASSIC, GAME_MODE.BLITZ, GAME_MODE.SHOWDOWN]) {
        const state = makeState({ mode });
        const decoded = decodeGameState(encodeGameState(state));
        expect(decoded.mode).toBe(mode);
      }
    });

    it("roundtrips all phases", () => {
      for (const phase of Object.values(PHASE)) {
        const state = makeState({ phase });
        const decoded = decodeGameState(encodeGameState(state));
        expect(decoded.phase).toBe(phase);
      }
    });

    it("encodes puck velocity with 0.01 precision", () => {
      const state = makeState({ puckVx: 7.89, puckVy: -4.56 });
      const decoded = decodeGameState(encodeGameState(state));
      expect(decoded.puckVx).toBeCloseTo(7.89, 1);
      expect(decoded.puckVy).toBeCloseTo(-4.56, 1);
    });

    it("handles zero velocity", () => {
      const state = makeState({ puckVx: 0, puckVy: 0 });
      const decoded = decodeGameState(encodeGameState(state));
      expect(decoded.puckVx).toBe(0);
      expect(decoded.puckVy).toBe(0);
    });

    it("handles max score values (uint8)", () => {
      const state = makeState({ scoreP1: 255, scoreP2: 255 });
      const decoded = decodeGameState(encodeGameState(state));
      expect(decoded.scoreP1).toBe(255);
      expect(decoded.scoreP2).toBe(255);
    });

    it("returns null for undersized buffer", () => {
      expect(decodeGameState(new ArrayBuffer(10))).toBeNull();
      expect(decodeGameState(new ArrayBuffer(0))).toBeNull();
    });

    it("returns null for null buffer", () => {
      expect(decodeGameState(null)).toBeNull();
    });
  });

  describe("PLAYER_INPUT encode/decode", () => {
    it("roundtrips all input keys", () => {
      for (const key of [
        INPUT_KEY.LEFT,
        INPUT_KEY.RIGHT,
        INPUT_KEY.UP,
        INPUT_KEY.DOWN,
        INPUT_KEY.ACTION,
      ]) {
        for (const pressed of [true, false]) {
          const buf = encodePlayerInput(key, pressed);
          expect(buf.byteLength).toBe(3);
          expect(getMessageType(buf)).toBe(MSG_TYPE.PLAYER_INPUT);
          const decoded = decodePlayerInput(buf);
          expect(decoded.key).toBe(key);
          expect(decoded.pressed).toBe(pressed);
        }
      }
    });

    it("returns null for undersized buffer", () => {
      expect(decodePlayerInput(new ArrayBuffer(1))).toBeNull();
      expect(decodePlayerInput(null)).toBeNull();
    });
  });

  describe("GAME_END encode/decode", () => {
    it("roundtrips p1 win", () => {
      const result = { winner: "p1", score_p1: 5, score_p2: 3 };
      const buf = encodeGameEnd(result);
      expect(buf.byteLength).toBe(4);
      expect(getMessageType(buf)).toBe(MSG_TYPE.GAME_END);
      const decoded = decodeGameEnd(buf);
      expect(decoded.winner).toBe("p1");
      expect(decoded.score_p1).toBe(5);
      expect(decoded.score_p2).toBe(3);
    });

    it("roundtrips p2 win", () => {
      const result = { winner: "p2", score_p1: 1, score_p2: 5 };
      const decoded = decodeGameEnd(encodeGameEnd(result));
      expect(decoded.winner).toBe("p2");
    });

    it("roundtrips draw", () => {
      const result = { winner: "draw", score_p1: 2, score_p2: 2 };
      const decoded = decodeGameEnd(encodeGameEnd(result));
      expect(decoded.winner).toBe("draw");
    });

    it("returns null for undersized buffer", () => {
      expect(decodeGameEnd(new ArrayBuffer(2))).toBeNull();
      expect(decodeGameEnd(null)).toBeNull();
    });
  });

  describe("GAME_READY", () => {
    it("encodes a 1-byte ready message", () => {
      const buf = encodeGameReady();
      expect(buf.byteLength).toBe(1);
      expect(getMessageType(buf)).toBe(MSG_TYPE.GAME_READY);
    });
  });

  describe("EVENT bitmask values", () => {
    it("all events are unique power-of-two values", () => {
      const values = Object.values(EVENT);
      for (const v of values) {
        expect(v & (v - 1)).toBe(0); // power of two check
        expect(v).toBeGreaterThan(0);
      }
      const uniqueSet = new Set(values);
      expect(uniqueSet.size).toBe(values.length);
    });

    it("all events fit in 16-bit bitmask", () => {
      const all = Object.values(EVENT).reduce((acc, v) => acc | v, 0);
      expect(all).toBeLessThanOrEqual(0xffff);
    });
  });
});
