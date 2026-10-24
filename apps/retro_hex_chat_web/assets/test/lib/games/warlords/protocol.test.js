import { describe, it, expect } from "vitest";
import {
  PHASE,
  MSG_TYPE,
  BRICKS_PER_CASTLE,
  INITIAL_LIVES,
  encodeGameReady,
  getMessageType,
  SNAPSHOT,
  GAME_END,
} from "../../../../js/lib/games/warlords/protocol.js";

describe("Warlords Protocol", () => {
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

      const buf = SNAPSHOT.encode(state);
      expect(buf.byteLength).toBe(33);

      const decoded = SNAPSHOT.decode(buf);
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
      expect(SNAPSHOT.decode(buf)).toBeNull();
    });

    it("returns null for wrong message type", () => {
      const buf = new ArrayBuffer(33);
      new DataView(buf).setUint8(0, 0x81);
      expect(SNAPSHOT.decode(buf)).toBeNull();
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

      const buf = SNAPSHOT.encode(state);
      const decoded = SNAPSHOT.decode(buf);
      expect(decoded.caughtBy).toBe(1);
    });
  });

  describe("game end encode/decode", () => {
    it("roundtrips P1 wins", () => {
      const buf = GAME_END.encode({ p1Lives: 2, p2Lives: 0, winner: 1 });
      expect(buf.byteLength).toBe(4);
      const decoded = GAME_END.decode(buf);
      expect(decoded.p1Lives).toBe(2);
      expect(decoded.p2Lives).toBe(0);
      expect(decoded.winner).toBe(1);
    });

    it("roundtrips P2 wins", () => {
      const buf = GAME_END.encode({ p1Lives: 0, p2Lives: 1, winner: 2 });
      const decoded = GAME_END.decode(buf);
      expect(decoded.p1Lives).toBe(0);
      expect(decoded.p2Lives).toBe(1);
      expect(decoded.winner).toBe(2);
    });

    it("returns null for too-small buffer", () => {
      expect(GAME_END.decode(new ArrayBuffer(2))).toBeNull();
    });

    it("returns null for wrong message type", () => {
      const buf = new ArrayBuffer(4);
      new DataView(buf).setUint8(0, MSG_TYPE.GAME_STATE);
      expect(GAME_END.decode(buf)).toBeNull();
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
  });
});
