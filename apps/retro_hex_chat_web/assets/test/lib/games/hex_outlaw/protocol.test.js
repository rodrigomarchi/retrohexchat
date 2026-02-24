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
} from "../../../../js/lib/games/hex_outlaw/protocol.js";

const BULLET_SPEED_X = 8; // Must match physics.js

describe("Hex Outlaw Protocol", () => {
  function makeState(overrides) {
    return {
      p1x: 80,
      p1y: 240,
      p1shooting: false,
      p2x: 560,
      p2y: 240,
      p2shooting: false,
      b1x: 0,
      b1y: 0,
      b1vx: 0,
      b1vy: 0,
      b1active: false,
      b1bounced: false,
      b2x: 0,
      b2y: 0,
      b2vx: 0,
      b2vy: 0,
      b2active: false,
      b2bounced: false,
      obsY: 240,
      obsDir: 1,
      score1: 0,
      score2: 0,
      phase: PHASE.WAITING,
      countdown: 0,
      round: 1,
      roundWins1: 0,
      roundWins2: 0,
      gameMode: GAME_MODE.QUICK_DRAW,
      hitPauseTimer: 0,
      lastHitPlayer: 0,
      ...overrides,
    };
  }

  describe("game state encode/decode", () => {
    it("roundtrips a full state", () => {
      const state = makeState({
        p1x: 80,
        p1y: 150,
        p1shooting: true,
        p2x: 560,
        p2y: 300,
        p2shooting: false,
        score1: 5,
        score2: 3,
        phase: PHASE.PLAYING,
        round: 2,
        roundWins1: 1,
        gameMode: GAME_MODE.QUICK_DRAW,
      });
      const buf = encodeGameState(state, BULLET_SPEED_X);
      const decoded = decodeGameState(buf, BULLET_SPEED_X);
      expect(decoded).not.toBeNull();
      expect(decoded.p1x).toBe(80);
      expect(decoded.p1y).toBe(150);
      expect(decoded.p1shooting).toBe(true);
      expect(decoded.p2x).toBe(560);
      expect(decoded.p2y).toBe(300);
      expect(decoded.p2shooting).toBe(false);
      expect(decoded.score1).toBe(5);
      expect(decoded.score2).toBe(3);
      expect(decoded.phase).toBe(PHASE.PLAYING);
      expect(decoded.round).toBe(2);
      expect(decoded.roundWins1).toBe(1);
    });

    it("roundtrips bullet state when active", () => {
      const state = makeState({
        b1x: 200,
        b1y: 150,
        b1vx: BULLET_SPEED_X,
        b1vy: 0,
        b1active: true,
        b1bounced: false,
      });
      const buf = encodeGameState(state, BULLET_SPEED_X);
      const decoded = decodeGameState(buf, BULLET_SPEED_X);
      expect(decoded.b1active).toBe(true);
      expect(decoded.b1x).toBe(200);
      expect(decoded.b1y).toBe(150);
      expect(decoded.b1vx).toBe(BULLET_SPEED_X);
      expect(decoded.b1vy).toBe(0);
      expect(decoded.b1bounced).toBe(false);
    });

    it("roundtrips bullet with negative vx", () => {
      const state = makeState({
        b2x: 400,
        b2y: 200,
        b2vx: -BULLET_SPEED_X,
        b2vy: 0,
        b2active: true,
        b2bounced: false,
      });
      const buf = encodeGameState(state, BULLET_SPEED_X);
      const decoded = decodeGameState(buf, BULLET_SPEED_X);
      expect(decoded.b2vx).toBe(-BULLET_SPEED_X);
      expect(decoded.b2active).toBe(true);
    });

    it("roundtrips bullet with vy (ricochet)", () => {
      const vy = BULLET_SPEED_X * Math.sin(Math.PI / 6);
      const state = makeState({
        b1x: 200,
        b1y: 200,
        b1vx: BULLET_SPEED_X,
        b1vy: vy,
        b1active: true,
        b1bounced: false,
      });
      const buf = encodeGameState(state, BULLET_SPEED_X);
      const decoded = decodeGameState(buf, BULLET_SPEED_X);
      expect(decoded.b1vy).toBeCloseTo(vy, 1);
      expect(decoded.b1bounced).toBe(false);
    });

    it("roundtrips bounced flag", () => {
      const state = makeState({
        b1x: 200,
        b1y: 200,
        b1vx: BULLET_SPEED_X,
        b1vy: -4,
        b1active: true,
        b1bounced: true,
      });
      const buf = encodeGameState(state, BULLET_SPEED_X);
      const decoded = decodeGameState(buf, BULLET_SPEED_X);
      expect(decoded.b1bounced).toBe(true);
    });

    it("roundtrips all game modes", () => {
      for (const mode of [
        GAME_MODE.QUICK_DRAW,
        GAME_MODE.RICOCHET,
        GAME_MODE.STAGECOACH,
        GAME_MODE.NO_MANS_LAND,
      ]) {
        const state = makeState({ gameMode: mode });
        const buf = encodeGameState(state, BULLET_SPEED_X);
        const decoded = decodeGameState(buf, BULLET_SPEED_X);
        expect(decoded.gameMode).toBe(mode);
      }
    });

    it("roundtrips obstacle position", () => {
      const state = makeState({ obsY: 300, obsDir: 255 });
      const buf = encodeGameState(state, BULLET_SPEED_X);
      const decoded = decodeGameState(buf, BULLET_SPEED_X);
      expect(decoded.obsY).toBe(300);
      expect(decoded.obsDir).toBe(255);
    });

    it("roundtrips hit pause state", () => {
      const state = makeState({
        phase: PHASE.HIT_PAUSE,
        hitPauseTimer: 45,
        lastHitPlayer: 1,
      });
      const buf = encodeGameState(state, BULLET_SPEED_X);
      const decoded = decodeGameState(buf, BULLET_SPEED_X);
      expect(decoded.phase).toBe(PHASE.HIT_PAUSE);
      expect(decoded.hitPauseTimer).toBe(45);
      expect(decoded.lastHitPlayer).toBe(1);
    });

    it("returns null for too-small buffer", () => {
      const buf = new ArrayBuffer(5);
      expect(decodeGameState(buf, BULLET_SPEED_X)).toBeNull();
    });

    it("returns null for wrong message type", () => {
      const buf = new ArrayBuffer(38);
      new DataView(buf).setUint8(0, MSG_TYPE.PLAYER_INPUT);
      expect(decodeGameState(buf, BULLET_SPEED_X)).toBeNull();
    });

    it("inactive bullets decode correctly", () => {
      const state = makeState({ b1active: false, b2active: false });
      const buf = encodeGameState(state, BULLET_SPEED_X);
      const decoded = decodeGameState(buf, BULLET_SPEED_X);
      expect(decoded.b1active).toBe(false);
      expect(decoded.b2active).toBe(false);
    });
  });

  describe("player input encode/decode", () => {
    it("roundtrips all input keys", () => {
      for (const key of [
        INPUT_KEY.UP,
        INPUT_KEY.DOWN,
        INPUT_KEY.LEFT,
        INPUT_KEY.RIGHT,
        INPUT_KEY.FIRE,
      ]) {
        for (const pressed of [true, false]) {
          const buf = encodePlayerInput(key, pressed);
          const decoded = decodePlayerInput(buf);
          expect(decoded.keyCode).toBe(key);
          expect(decoded.pressed).toBe(pressed);
        }
      }
    });

    it("returns null for too-small buffer", () => {
      const buf = new ArrayBuffer(1);
      expect(decodePlayerInput(buf)).toBeNull();
    });

    it("returns null for wrong message type", () => {
      const buf = new ArrayBuffer(3);
      new DataView(buf).setUint8(0, MSG_TYPE.GAME_STATE);
      expect(decodePlayerInput(buf)).toBeNull();
    });
  });

  describe("game end encode/decode", () => {
    it("roundtrips game end", () => {
      const result = {
        score1: 10,
        score2: 7,
        winner: 1,
        roundWins1: 2,
        roundWins2: 1,
      };
      const buf = encodeGameEnd(result);
      const decoded = decodeGameEnd(buf);
      expect(decoded.score1).toBe(10);
      expect(decoded.score2).toBe(7);
      expect(decoded.winner).toBe(1);
      expect(decoded.roundWins1).toBe(2);
      expect(decoded.roundWins2).toBe(1);
    });

    it("returns null for too-small buffer", () => {
      const buf = new ArrayBuffer(2);
      expect(decodeGameEnd(buf)).toBeNull();
    });

    it("returns null for wrong message type", () => {
      const buf = new ArrayBuffer(6);
      new DataView(buf).setUint8(0, MSG_TYPE.GAME_STATE);
      expect(decodeGameEnd(buf)).toBeNull();
    });
  });

  describe("game ready", () => {
    it("encodes a single byte", () => {
      const buf = encodeGameReady();
      expect(buf.byteLength).toBe(1);
      expect(new DataView(buf).getUint8(0)).toBe(MSG_TYPE.GAME_READY);
    });
  });

  describe("getMessageType", () => {
    it("returns message type from buffer", () => {
      const buf = encodeGameReady();
      expect(getMessageType(buf)).toBe(MSG_TYPE.GAME_READY);
    });

    it("returns null for empty buffer", () => {
      expect(getMessageType(new ArrayBuffer(0))).toBeNull();
    });

    it("identifies game state", () => {
      const buf = encodeGameState(makeState(), BULLET_SPEED_X);
      expect(getMessageType(buf)).toBe(MSG_TYPE.GAME_STATE);
    });

    it("identifies player input", () => {
      const buf = encodePlayerInput(INPUT_KEY.FIRE, true);
      expect(getMessageType(buf)).toBe(MSG_TYPE.PLAYER_INPUT);
    });
  });
});
