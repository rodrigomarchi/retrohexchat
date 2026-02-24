import { describe, it, expect } from "vitest";
import {
  MSG_TYPE,
  PHASE,
  INPUT_KEY,
  PUNCH_STATE,
  encodeGameState,
  decodeGameState,
  encodePlayerInput,
  decodePlayerInput,
  encodeGameEnd,
  decodeGameEnd,
  encodeGameReady,
  getMessageType,
} from "../../../../js/lib/games/hex_boxing/protocol.js";

describe("Hex Boxing Protocol", () => {
  function makeState(overrides) {
    return {
      b1x: 200,
      b1y: 240,
      b1dir: 0,
      b1punchState: PUNCH_STATE.IDLE,
      b1arm: 0,
      b1punchTimer: 0,
      b2x: 440,
      b2y: 240,
      b2dir: 4,
      b2punchState: PUNCH_STATE.IDLE,
      b2arm: 0,
      b2punchTimer: 0,
      score1: 0,
      score2: 0,
      phase: PHASE.WAITING,
      countdown: 0,
      round: 1,
      roundWins1: 0,
      roundWins2: 0,
      roundTimer: 7200,
      lastHitPlayer: 0,
      lastHitPoints: 0,
      ...overrides,
    };
  }

  describe("game state encode/decode", () => {
    it("roundtrips a full state", () => {
      const state = makeState({
        b1x: 200,
        b1y: 240,
        b1dir: 0,
        b1punchState: PUNCH_STATE.PUNCHING,
        b1arm: 1,
        b1punchTimer: 5,
        b2x: 440,
        b2y: 200,
        b2dir: 4,
        b2punchState: PUNCH_STATE.COOLDOWN,
        b2arm: 0,
        b2punchTimer: 3,
        score1: 47,
        score2: 32,
        phase: PHASE.FIGHTING,
        countdown: 0,
        round: 2,
        roundWins1: 1,
        roundWins2: 0,
        roundTimer: 3600,
        lastHitPlayer: 1,
        lastHitPoints: 3,
      });

      const buf = encodeGameState(state);
      expect(buf.byteLength).toBe(26);

      const decoded = decodeGameState(buf);
      expect(decoded).not.toBeNull();
      expect(decoded.b1x).toBe(200);
      expect(decoded.b1y).toBe(240);
      expect(decoded.b1dir).toBe(0);
      expect(decoded.b1punchState).toBe(PUNCH_STATE.PUNCHING);
      expect(decoded.b1arm).toBe(1);
      expect(decoded.b1punchTimer).toBe(5);
      expect(decoded.b2x).toBe(440);
      expect(decoded.b2y).toBe(200);
      expect(decoded.b2dir).toBe(4);
      expect(decoded.b2punchState).toBe(PUNCH_STATE.COOLDOWN);
      expect(decoded.b2arm).toBe(0);
      expect(decoded.b2punchTimer).toBe(3);
      expect(decoded.score1).toBe(47);
      expect(decoded.score2).toBe(32);
      expect(decoded.phase).toBe(PHASE.FIGHTING);
      expect(decoded.countdown).toBe(0);
      expect(decoded.round).toBe(2);
      expect(decoded.roundWins1).toBe(1);
      expect(decoded.roundWins2).toBe(0);
      expect(decoded.roundTimer).toBe(3600);
      expect(decoded.lastHitPlayer).toBe(1);
      expect(decoded.lastHitPoints).toBe(3);
    });

    it("encodes message type 0x80", () => {
      const buf = encodeGameState(makeState());
      expect(getMessageType(buf)).toBe(MSG_TYPE.GAME_STATE);
    });

    it("returns null for buffer too small", () => {
      const buf = new ArrayBuffer(10);
      expect(decodeGameState(buf)).toBeNull();
    });

    it("returns null for wrong message type", () => {
      const buf = new ArrayBuffer(26);
      const view = new DataView(buf);
      view.setUint8(0, MSG_TYPE.PLAYER_INPUT);
      expect(decodeGameState(buf)).toBeNull();
    });

    it("encodes all boxer flag combinations", () => {
      for (const ps of [PUNCH_STATE.IDLE, PUNCH_STATE.PUNCHING, PUNCH_STATE.COOLDOWN]) {
        for (const arm of [0, 1]) {
          const decoded = decodeGameState(
            encodeGameState(makeState({ b1punchState: ps, b1arm: arm })),
          );
          expect(decoded.b1punchState).toBe(ps);
          expect(decoded.b1arm).toBe(arm);
        }
      }
    });

    it("handles max scores (100 = KO)", () => {
      const decoded = decodeGameState(encodeGameState(makeState({ score1: 100, score2: 99 })));
      expect(decoded.score1).toBe(100);
      expect(decoded.score2).toBe(99);
    });

    it("handles all 8 directions", () => {
      for (let dir = 0; dir < 8; dir++) {
        const decoded = decodeGameState(encodeGameState(makeState({ b1dir: dir })));
        expect(decoded.b1dir).toBe(dir);
      }
    });

    it("handles all PHASE values", () => {
      for (const [, value] of Object.entries(PHASE)) {
        const decoded = decodeGameState(encodeGameState(makeState({ phase: value })));
        expect(decoded.phase).toBe(value);
      }
    });

    it("handles max roundTimer value", () => {
      const decoded = decodeGameState(encodeGameState(makeState({ roundTimer: 65535 })));
      expect(decoded.roundTimer).toBe(65535);
    });

    it("handles max Uint8 punchTimer", () => {
      const decoded = decodeGameState(encodeGameState(makeState({ b1punchTimer: 255 })));
      expect(decoded.b1punchTimer).toBe(255);
    });

    it("handles event flags", () => {
      const decoded = decodeGameState(
        encodeGameState(makeState({ lastHitPlayer: 2, lastHitPoints: 3 })),
      );
      expect(decoded.lastHitPlayer).toBe(2);
      expect(decoded.lastHitPoints).toBe(3);
    });

    it("handles zero event flags (no hit)", () => {
      const decoded = decodeGameState(
        encodeGameState(makeState({ lastHitPlayer: 0, lastHitPoints: 0 })),
      );
      expect(decoded.lastHitPlayer).toBe(0);
      expect(decoded.lastHitPoints).toBe(0);
    });

    it("handles position at canvas boundaries", () => {
      const decoded = decodeGameState(
        encodeGameState(makeState({ b1x: 0, b1y: 0, b2x: 640, b2y: 480 })),
      );
      expect(decoded.b1x).toBe(0);
      expect(decoded.b1y).toBe(0);
      expect(decoded.b2x).toBe(640);
      expect(decoded.b2y).toBe(480);
    });

    it("rounds float positions to nearest integer", () => {
      const decoded = decodeGameState(encodeGameState(makeState({ b1x: 200.7, b1y: 240.3 })));
      expect(decoded.b1x).toBe(201);
      expect(decoded.b1y).toBe(240);
    });

    it("does not transmit cooldownTimer (internal-only field)", () => {
      const decoded = decodeGameState(encodeGameState(makeState()));
      // cooldownTimer is not in the decoded object — physics uses it internally
      expect(decoded.b1cooldownTimer).toBeUndefined();
      expect(decoded.b2cooldownTimer).toBeUndefined();
    });
  });

  describe("player input encode/decode", () => {
    it("roundtrips all key codes", () => {
      for (const [, value] of Object.entries(INPUT_KEY)) {
        for (const pressed of [true, false]) {
          const buf = encodePlayerInput(value, pressed);
          expect(buf.byteLength).toBe(3);
          const decoded = decodePlayerInput(buf);
          expect(decoded).not.toBeNull();
          expect(decoded.keyCode).toBe(value);
          expect(decoded.pressed).toBe(pressed);
        }
      }
    });

    it("encodes message type 0x81", () => {
      const buf = encodePlayerInput(INPUT_KEY.PUNCH, true);
      expect(getMessageType(buf)).toBe(MSG_TYPE.PLAYER_INPUT);
    });

    it("returns null for buffer too small", () => {
      const buf = new ArrayBuffer(1);
      expect(decodePlayerInput(buf)).toBeNull();
    });

    it("returns null for wrong message type", () => {
      const buf = new ArrayBuffer(3);
      const view = new DataView(buf);
      view.setUint8(0, MSG_TYPE.GAME_STATE);
      expect(decodePlayerInput(buf)).toBeNull();
    });
  });

  describe("game end encode/decode", () => {
    it("roundtrips a result", () => {
      const result = {
        score1: 100,
        score2: 47,
        winner: 1,
        roundWins1: 2,
        roundWins2: 1,
      };
      const buf = encodeGameEnd(result);
      expect(buf.byteLength).toBe(6);
      const decoded = decodeGameEnd(buf);
      expect(decoded).not.toBeNull();
      expect(decoded.score1).toBe(100);
      expect(decoded.score2).toBe(47);
      expect(decoded.winner).toBe(1);
      expect(decoded.roundWins1).toBe(2);
      expect(decoded.roundWins2).toBe(1);
    });

    it("encodes message type 0x83", () => {
      const buf = encodeGameEnd({
        score1: 0,
        score2: 0,
        winner: 1,
        roundWins1: 0,
        roundWins2: 0,
      });
      expect(getMessageType(buf)).toBe(MSG_TYPE.GAME_END);
    });

    it("returns null for buffer too small", () => {
      const buf = new ArrayBuffer(2);
      expect(decodeGameEnd(buf)).toBeNull();
    });

    it("returns null for wrong message type", () => {
      const buf = new ArrayBuffer(6);
      const view = new DataView(buf);
      view.setUint8(0, MSG_TYPE.GAME_STATE);
      expect(decodeGameEnd(buf)).toBeNull();
    });
  });

  describe("game ready", () => {
    it("encodes 1-byte ready signal", () => {
      const buf = encodeGameReady();
      expect(buf.byteLength).toBe(1);
      expect(getMessageType(buf)).toBe(MSG_TYPE.GAME_READY);
    });
  });

  describe("getMessageType", () => {
    it("returns null for empty buffer", () => {
      expect(getMessageType(new ArrayBuffer(0))).toBeNull();
    });

    it("reads first byte as type", () => {
      const buf = new ArrayBuffer(1);
      new DataView(buf).setUint8(0, 0x83);
      expect(getMessageType(buf)).toBe(0x83);
    });
  });
});
