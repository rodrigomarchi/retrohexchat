import { describe, it, expect } from "vitest";
import {
  PHASE,
  MSG_TYPE,
  INPUT_KEY,
  BRICKS_PER_CASTLE,
  INITIAL_LIVES,
  encodeBrickBitmap,
  decodeBrickBitmap,
  encodeGameState,
  decodeGameState,
  encodePlayerInput,
  decodePlayerInput,
  encodeGameEnd,
  decodeGameEnd,
  encodeGameReady,
  getMessageType,
} from "../../../../js/lib/games/warlords/protocol.js";

describe("Warlords Protocol", () => {
  describe("brick bitmap", () => {
    it("encodes all alive bricks", () => {
      const bricks = Array.from({ length: BRICKS_PER_CASTLE }, () => ({ alive: true }));
      const bytes = encodeBrickBitmap(bricks);
      expect(bytes.length).toBe(3);
      // 24 bits all set: 0xFF, 0xFF, 0xFF
      expect(bytes[0]).toBe(0xff);
      expect(bytes[1]).toBe(0xff);
      expect(bytes[2]).toBe(0xff);
    });

    it("encodes all dead bricks", () => {
      const bricks = Array.from({ length: BRICKS_PER_CASTLE }, () => ({ alive: false }));
      const bytes = encodeBrickBitmap(bricks);
      expect(bytes[0]).toBe(0);
      expect(bytes[1]).toBe(0);
      expect(bytes[2]).toBe(0);
    });

    it("roundtrips mixed alive/dead", () => {
      const bricks = Array.from({ length: BRICKS_PER_CASTLE }, (_, i) => ({
        alive: i % 3 === 0,
      }));
      const bytes = encodeBrickBitmap(bricks);
      const decoded = decodeBrickBitmap(bytes);
      for (let i = 0; i < BRICKS_PER_CASTLE; i++) {
        expect(decoded[i]).toBe(bricks[i].alive);
      }
    });

    it("roundtrips single brick alive", () => {
      for (let target = 0; target < BRICKS_PER_CASTLE; target++) {
        const bricks = Array.from({ length: BRICKS_PER_CASTLE }, (_, i) => ({
          alive: i === target,
        }));
        const bytes = encodeBrickBitmap(bricks);
        const decoded = decodeBrickBitmap(bytes);
        for (let i = 0; i < BRICKS_PER_CASTLE; i++) {
          expect(decoded[i]).toBe(i === target);
        }
      }
    });
  });

  describe("game state encode/decode", () => {
    it("roundtrips a full state", () => {
      const state = {
        fireballX: 320.5,
        fireballY: 240.25,
        fireballVX: 3.0,
        fireballVY: -2.5,
        shield1Y: 180,
        shield2Y: 220,
        p1Bricks: Array.from({ length: BRICKS_PER_CASTLE }, () => ({ alive: true })),
        p2Bricks: Array.from({ length: BRICKS_PER_CASTLE }, (_, i) => ({
          alive: i < 12,
        })),
        p1Lives: 3,
        p2Lives: 1,
        phase: PHASE.PLAYING,
        countdown: 0,
        round: 2,
        caughtBy: 0,
      };

      const buf = encodeGameState(state);
      expect(buf.byteLength).toBe(33);

      const decoded = decodeGameState(buf);
      expect(decoded).not.toBeNull();
      expect(decoded.fireballX).toBeCloseTo(320.5, 1);
      expect(decoded.fireballY).toBeCloseTo(240.25, 1);
      expect(decoded.fireballVX).toBeCloseTo(3.0, 1);
      expect(decoded.fireballVY).toBeCloseTo(-2.5, 1);
      expect(decoded.shield1Y).toBe(180);
      expect(decoded.shield2Y).toBe(220);
      expect(decoded.p1Lives).toBe(3);
      expect(decoded.p2Lives).toBe(1);
      expect(decoded.phase).toBe(PHASE.PLAYING);
      expect(decoded.countdown).toBe(0);
      expect(decoded.round).toBe(2);
      expect(decoded.caughtBy).toBe(0);

      // P1 all alive
      expect(decoded.p1BricksAlive.every((b) => b)).toBe(true);
      // P2 first 12 alive, rest dead
      for (let i = 0; i < BRICKS_PER_CASTLE; i++) {
        expect(decoded.p2BricksAlive[i]).toBe(i < 12);
      }
    });

    it("returns null for too-small buffer", () => {
      const buf = new ArrayBuffer(10);
      expect(decodeGameState(buf)).toBeNull();
    });

    it("returns null for wrong message type", () => {
      const buf = new ArrayBuffer(33);
      new DataView(buf).setUint8(0, MSG_TYPE.PLAYER_INPUT);
      expect(decodeGameState(buf)).toBeNull();
    });

    it("encodes caught state", () => {
      const state = {
        fireballX: 100,
        fireballY: 200,
        fireballVX: 0,
        fireballVY: 0,
        shield1Y: 200,
        shield2Y: 200,
        p1Bricks: Array.from({ length: BRICKS_PER_CASTLE }, () => ({ alive: true })),
        p2Bricks: Array.from({ length: BRICKS_PER_CASTLE }, () => ({ alive: true })),
        p1Lives: 3,
        p2Lives: 3,
        phase: PHASE.PLAYING,
        countdown: 0,
        round: 1,
        caughtBy: 1,
      };

      const buf = encodeGameState(state);
      const decoded = decodeGameState(buf);
      expect(decoded.caughtBy).toBe(1);
    });
  });

  describe("player input encode/decode", () => {
    it("roundtrips UP pressed", () => {
      const buf = encodePlayerInput(INPUT_KEY.UP, true);
      expect(buf.byteLength).toBe(3);
      const decoded = decodePlayerInput(buf);
      expect(decoded.keyCode).toBe(INPUT_KEY.UP);
      expect(decoded.pressed).toBe(true);
    });

    it("roundtrips DOWN released", () => {
      const buf = encodePlayerInput(INPUT_KEY.DOWN, false);
      const decoded = decodePlayerInput(buf);
      expect(decoded.keyCode).toBe(INPUT_KEY.DOWN);
      expect(decoded.pressed).toBe(false);
    });

    it("roundtrips SPACE pressed", () => {
      const buf = encodePlayerInput(INPUT_KEY.SPACE, true);
      const decoded = decodePlayerInput(buf);
      expect(decoded.keyCode).toBe(INPUT_KEY.SPACE);
      expect(decoded.pressed).toBe(true);
    });

    it("returns null for too-small buffer", () => {
      expect(decodePlayerInput(new ArrayBuffer(1))).toBeNull();
    });

    it("returns null for wrong message type", () => {
      const buf = new ArrayBuffer(3);
      new DataView(buf).setUint8(0, MSG_TYPE.GAME_STATE);
      expect(decodePlayerInput(buf)).toBeNull();
    });
  });

  describe("game end encode/decode", () => {
    it("roundtrips P1 wins", () => {
      const buf = encodeGameEnd(2, 0, 1);
      expect(buf.byteLength).toBe(4);
      const decoded = decodeGameEnd(buf);
      expect(decoded.p1Lives).toBe(2);
      expect(decoded.p2Lives).toBe(0);
      expect(decoded.winner).toBe(1);
    });

    it("roundtrips P2 wins", () => {
      const buf = encodeGameEnd(0, 1, 2);
      const decoded = decodeGameEnd(buf);
      expect(decoded.p1Lives).toBe(0);
      expect(decoded.p2Lives).toBe(1);
      expect(decoded.winner).toBe(2);
    });

    it("returns null for too-small buffer", () => {
      expect(decodeGameEnd(new ArrayBuffer(2))).toBeNull();
    });

    it("returns null for wrong message type", () => {
      const buf = new ArrayBuffer(4);
      new DataView(buf).setUint8(0, MSG_TYPE.GAME_STATE);
      expect(decodeGameEnd(buf)).toBeNull();
    });
  });

  describe("game ready", () => {
    it("encodes single byte with correct type", () => {
      const buf = encodeGameReady();
      expect(buf.byteLength).toBe(1);
      expect(new DataView(buf).getUint8(0)).toBe(MSG_TYPE.GAME_READY);
    });
  });

  describe("getMessageType", () => {
    it("returns type from valid buffer", () => {
      const buf = new ArrayBuffer(1);
      new DataView(buf).setUint8(0, MSG_TYPE.GAME_STATE);
      expect(getMessageType(buf)).toBe(MSG_TYPE.GAME_STATE);
    });

    it("returns null for empty buffer", () => {
      expect(getMessageType(new ArrayBuffer(0))).toBeNull();
    });
  });

  describe("constants", () => {
    it("has correct brick count", () => {
      expect(BRICKS_PER_CASTLE).toBe(24);
    });

    it("has correct initial lives", () => {
      expect(INITIAL_LIVES).toBe(3);
    });

    it("has all phases", () => {
      expect(PHASE.WAITING).toBe(0);
      expect(PHASE.COUNTDOWN).toBe(1);
      expect(PHASE.PLAYING).toBe(2);
      expect(PHASE.KING_HIT).toBe(3);
      expect(PHASE.FINISHED).toBe(4);
    });

    it("has all input keys", () => {
      expect(INPUT_KEY.UP).toBe(0);
      expect(INPUT_KEY.DOWN).toBe(1);
      expect(INPUT_KEY.SPACE).toBe(2);
    });
  });
});
