import { describe, it, expect } from "vitest";
import {
  MSG_TYPE,
  PHASE,
  INPUT_KEY,
  GAME_MODE,
  encodeGameState,
  decodeGameState,
  encodePlayerInput,
  decodePlayerInput,
  encodeGameEnd,
  decodeGameEnd,
  encodeGameReady,
  getMessageType,
} from "../../../../js/lib/games/pixel_tanks/protocol.js";

describe("Pixel Tanks Protocol", () => {
  describe("game state encode/decode", () => {
    it("roundtrips a full state", () => {
      const state = {
        tank1X: 48.5,
        tank1Y: 240.25,
        tank1Rot: 1.5708,
        tank1Alive: true,
        tank1Invuln: false,
        tank2X: 592.0,
        tank2Y: 240.0,
        tank2Rot: 3.1416,
        tank2Alive: true,
        tank2Invuln: true,
        m1X: 100.0,
        m1Y: 200.0,
        m1VX: 5.0,
        m1VY: 0.0,
        m1Active: true,
        m1Bounced: false,
        m2X: 400.0,
        m2Y: 300.0,
        m2VX: -3.0,
        m2VY: 4.0,
        m2Active: true,
        m2Bounced: true,
        score1: 3,
        score2: 5,
        phase: PHASE.PLAYING,
        countdown: 0,
        mode: GAME_MODE.MAZE_BATTLE,
        mazeIndex: 2,
        round: 2,
        roundWins1: 1,
        roundWins2: 0,
        roundTimer: 3600,
      };

      const buf = encodeGameState(state);
      expect(buf.byteLength).toBe(68);

      const decoded = decodeGameState(buf);
      expect(decoded).not.toBeNull();
      expect(decoded.tank1X).toBeCloseTo(48.5, 1);
      expect(decoded.tank1Y).toBeCloseTo(240.25, 1);
      // Rotation is encoded as Uint16 * 10000, some precision loss
      expect(decoded.tank1Rot).toBeCloseTo(1.5708, 2);
      expect(decoded.tank1Alive).toBe(true);
      expect(decoded.tank1Invuln).toBe(false);
      expect(decoded.tank2X).toBeCloseTo(592.0, 1);
      expect(decoded.tank2Alive).toBe(true);
      expect(decoded.tank2Invuln).toBe(true);
      expect(decoded.m1Active).toBe(true);
      expect(decoded.m1Bounced).toBe(false);
      expect(decoded.m2Active).toBe(true);
      expect(decoded.m2Bounced).toBe(true);
      expect(decoded.score1).toBe(3);
      expect(decoded.score2).toBe(5);
      expect(decoded.phase).toBe(PHASE.PLAYING);
      expect(decoded.countdown).toBe(0);
      expect(decoded.mode).toBe(GAME_MODE.MAZE_BATTLE);
      expect(decoded.mazeIndex).toBe(2);
      expect(decoded.round).toBe(2);
      expect(decoded.roundWins1).toBe(1);
      expect(decoded.roundWins2).toBe(0);
      expect(decoded.roundTimer).toBe(3600);
    });

    it("encodes message type 0x80", () => {
      const state = {
        tank1X: 0,
        tank1Y: 0,
        tank1Rot: 0,
        tank1Alive: false,
        tank1Invuln: false,
        tank2X: 0,
        tank2Y: 0,
        tank2Rot: 0,
        tank2Alive: false,
        tank2Invuln: false,
        m1X: 0,
        m1Y: 0,
        m1VX: 0,
        m1VY: 0,
        m1Active: false,
        m1Bounced: false,
        m2X: 0,
        m2Y: 0,
        m2VX: 0,
        m2VY: 0,
        m2Active: false,
        m2Bounced: false,
        score1: 0,
        score2: 0,
        phase: PHASE.WAITING,
        countdown: 0,
        mode: GAME_MODE.CLASSIC,
        mazeIndex: 0,
        round: 1,
        roundWins1: 0,
        roundWins2: 0,
        roundTimer: 7200,
      };

      const buf = encodeGameState(state);
      expect(getMessageType(buf)).toBe(MSG_TYPE.GAME_STATE);
    });

    it("returns null for buffer too small", () => {
      const buf = new ArrayBuffer(10);
      expect(decodeGameState(buf)).toBeNull();
    });

    it("returns null for wrong message type", () => {
      const buf = new ArrayBuffer(68);
      const view = new DataView(buf);
      view.setUint8(0, MSG_TYPE.PLAYER_INPUT);
      expect(decodeGameState(buf)).toBeNull();
    });

    it("encodes tank flags correctly", () => {
      const state = {
        tank1X: 0,
        tank1Y: 0,
        tank1Rot: 0,
        tank1Alive: true,
        tank1Invuln: true,
        tank2X: 0,
        tank2Y: 0,
        tank2Rot: 0,
        tank2Alive: false,
        tank2Invuln: false,
        m1X: 0,
        m1Y: 0,
        m1VX: 0,
        m1VY: 0,
        m1Active: false,
        m1Bounced: false,
        m2X: 0,
        m2Y: 0,
        m2VX: 0,
        m2VY: 0,
        m2Active: false,
        m2Bounced: false,
        score1: 0,
        score2: 0,
        phase: 0,
        countdown: 0,
        mode: 0,
        mazeIndex: 0,
        round: 1,
        roundWins1: 0,
        roundWins2: 0,
        roundTimer: 0,
      };

      const decoded = decodeGameState(encodeGameState(state));
      expect(decoded.tank1Alive).toBe(true);
      expect(decoded.tank1Invuln).toBe(true);
      expect(decoded.tank2Alive).toBe(false);
      expect(decoded.tank2Invuln).toBe(false);
    });

    it("encodes missile flags correctly", () => {
      const state = {
        tank1X: 0,
        tank1Y: 0,
        tank1Rot: 0,
        tank1Alive: true,
        tank1Invuln: false,
        tank2X: 0,
        tank2Y: 0,
        tank2Rot: 0,
        tank2Alive: true,
        tank2Invuln: false,
        m1X: 0,
        m1Y: 0,
        m1VX: 0,
        m1VY: 0,
        m1Active: true,
        m1Bounced: true,
        m2X: 0,
        m2Y: 0,
        m2VX: 0,
        m2VY: 0,
        m2Active: false,
        m2Bounced: false,
        score1: 0,
        score2: 0,
        phase: 0,
        countdown: 0,
        mode: 0,
        mazeIndex: 0,
        round: 1,
        roundWins1: 0,
        roundWins2: 0,
        roundTimer: 0,
      };

      const decoded = decodeGameState(encodeGameState(state));
      expect(decoded.m1Active).toBe(true);
      expect(decoded.m1Bounced).toBe(true);
      expect(decoded.m2Active).toBe(false);
      expect(decoded.m2Bounced).toBe(false);
    });

    it("handles max roundTimer value", () => {
      const state = {
        tank1X: 0,
        tank1Y: 0,
        tank1Rot: 0,
        tank1Alive: true,
        tank1Invuln: false,
        tank2X: 0,
        tank2Y: 0,
        tank2Rot: 0,
        tank2Alive: true,
        tank2Invuln: false,
        m1X: 0,
        m1Y: 0,
        m1VX: 0,
        m1VY: 0,
        m1Active: false,
        m1Bounced: false,
        m2X: 0,
        m2Y: 0,
        m2VX: 0,
        m2VY: 0,
        m2Active: false,
        m2Bounced: false,
        score1: 0,
        score2: 0,
        phase: 0,
        countdown: 0,
        mode: 0,
        mazeIndex: 0,
        round: 1,
        roundWins1: 0,
        roundWins2: 0,
        roundTimer: 7200,
      };

      const decoded = decodeGameState(encodeGameState(state));
      expect(decoded.roundTimer).toBe(7200);
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
      const buf = encodePlayerInput(INPUT_KEY.FIRE, true);
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
        score1: 7,
        score2: 3,
        winner: 1,
        roundWins1: 2,
        roundWins2: 1,
      };
      const buf = encodeGameEnd(result);
      expect(buf.byteLength).toBe(6);
      const decoded = decodeGameEnd(buf);
      expect(decoded).not.toBeNull();
      expect(decoded.score1).toBe(7);
      expect(decoded.score2).toBe(3);
      expect(decoded.winner).toBe(1);
      expect(decoded.roundWins1).toBe(2);
      expect(decoded.roundWins2).toBe(1);
    });

    it("encodes message type 0x83", () => {
      const buf = encodeGameEnd({ score1: 0, score2: 0, winner: 1, roundWins1: 0, roundWins2: 0 });
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

  describe("boundary values", () => {
    function makeState(overrides) {
      return {
        tank1X: 0,
        tank1Y: 0,
        tank1Rot: 0,
        tank1Alive: false,
        tank1Invuln: false,
        tank2X: 0,
        tank2Y: 0,
        tank2Rot: 0,
        tank2Alive: false,
        tank2Invuln: false,
        m1X: 0,
        m1Y: 0,
        m1VX: 0,
        m1VY: 0,
        m1Active: false,
        m1Bounced: false,
        m2X: 0,
        m2Y: 0,
        m2VX: 0,
        m2VY: 0,
        m2Active: false,
        m2Bounced: false,
        score1: 0,
        score2: 0,
        phase: 0,
        countdown: 0,
        mode: 0,
        mazeIndex: 0,
        round: 1,
        roundWins1: 0,
        roundWins2: 0,
        roundTimer: 0,
        ...overrides,
      };
    }

    it("handles rotation at 0", () => {
      const decoded = decodeGameState(encodeGameState(makeState({ tank1Rot: 0 })));
      expect(decoded.tank1Rot).toBeCloseTo(0, 2);
    });

    it("handles rotation near 2*PI", () => {
      const decoded = decodeGameState(encodeGameState(makeState({ tank1Rot: 6.2831 })));
      expect(decoded.tank1Rot).toBeCloseTo(6.2831, 1);
    });

    it("handles max Uint8 scores", () => {
      const decoded = decodeGameState(encodeGameState(makeState({ score1: 255, score2: 255 })));
      expect(decoded.score1).toBe(255);
      expect(decoded.score2).toBe(255);
    });

    it("handles max Uint16 roundTimer", () => {
      const decoded = decodeGameState(encodeGameState(makeState({ roundTimer: 65535 })));
      expect(decoded.roundTimer).toBe(65535);
    });

    it("handles negative coordinates", () => {
      const decoded = decodeGameState(
        encodeGameState(makeState({ tank1X: -50.5, tank1Y: -100.25 })),
      );
      expect(decoded.tank1X).toBeCloseTo(-50.5, 1);
      expect(decoded.tank1Y).toBeCloseTo(-100.25, 1);
    });

    it("handles all flag combinations for tank1", () => {
      for (const alive of [true, false]) {
        for (const invuln of [true, false]) {
          const decoded = decodeGameState(
            encodeGameState(makeState({ tank1Alive: alive, tank1Invuln: invuln })),
          );
          expect(decoded.tank1Alive).toBe(alive);
          expect(decoded.tank1Invuln).toBe(invuln);
        }
      }
    });

    it("handles all flag combinations for missiles", () => {
      for (const active of [true, false]) {
        for (const bounced of [true, false]) {
          const decoded = decodeGameState(
            encodeGameState(makeState({ m1Active: active, m1Bounced: bounced })),
          );
          expect(decoded.m1Active).toBe(active);
          expect(decoded.m1Bounced).toBe(bounced);
        }
      }
    });

    it("handles all PHASE values", () => {
      for (const [, value] of Object.entries(PHASE)) {
        const decoded = decodeGameState(encodeGameState(makeState({ phase: value })));
        expect(decoded.phase).toBe(value);
      }
    });

    it("handles all GAME_MODE values", () => {
      for (const [, value] of Object.entries(GAME_MODE)) {
        const decoded = decodeGameState(encodeGameState(makeState({ mode: value })));
        expect(decoded.mode).toBe(value);
      }
    });
  });
});
