import { describe, it, expect } from "vitest";
import {
  MSG_TYPE,
  PHASE,
  TOTAL_BLOCKS,
  encodeGameReady,
  getMessageType,
  SNAPSHOT,
  GAME_END,
} from "../../../../js/lib/games/breakout/protocol.js";

describe("breakout_protocol", () => {
  describe("encodeGameState / decodeGameState", () => {
    function makeState() {
      return {
        ballX: 320.5,
        ballY: 240.25,
        ballVX: 3.5,
        ballVY: -4.0,
        paddle1X: 280,
        paddle2X: 300,
        score: 150,
        lives: 2,
        phase: PHASE.PLAYING,
        countdown: 0,
        blocksRemaining: 35,
        blocks: Array.from({ length: TOTAL_BLOCKS }, (_, i) => ({
          alive: i < 35,
        })),
      };
    }

    it("round-trips game state correctly", () => {
      const state = makeState();
      const buf = SNAPSHOT.encode(state);
      const decoded = SNAPSHOT.decode(buf);

      expect(decoded.ballX).toBeCloseTo(state.ballX, 1);
      expect(decoded.ballY).toBeCloseTo(state.ballY, 1);
      expect(decoded.ballVX).toBeCloseTo(state.ballVX, 1);
      expect(decoded.ballVY).toBeCloseTo(state.ballVY, 1);
      expect(decoded.paddle1X).toBe(state.paddle1X);
      expect(decoded.paddle2X).toBe(state.paddle2X);
      expect(decoded.score).toBe(state.score);
      expect(decoded.lives).toBe(state.lives);
      expect(decoded.phase).toBe(state.phase);
      expect(decoded.countdown).toBe(state.countdown);
      expect(decoded.blocksRemaining).toBe(state.blocksRemaining);
    });

    it("round-trips block bitmap", () => {
      const state = makeState();
      const buf = SNAPSHOT.encode(state);
      const decoded = SNAPSHOT.decode(buf);

      for (let i = 0; i < TOTAL_BLOCKS; i++) {
        expect(decoded.blocksAlive[i]).toBe(state.blocks[i].alive);
      }
    });

    it("has correct message type byte", () => {
      const state = makeState();
      const buf = SNAPSHOT.encode(state);
      expect(getMessageType(buf)).toBe(MSG_TYPE.GAME_STATE);
    });

    it("returns null for buffer too small", () => {
      const buf = new ArrayBuffer(5);
      expect(SNAPSHOT.decode(buf)).toBeNull();
    });

    it("returns null for wrong message type", () => {
      const buf = new ArrayBuffer(34);
      const view = new DataView(buf);
      view.setUint8(0, 0x81);
      expect(SNAPSHOT.decode(buf)).toBeNull();
    });

    it("round-trips zero score and max lives accurately", () => {
      const state = {
        ballX: 0,
        ballY: 0,
        ballVX: 0,
        ballVY: 0,
        paddle1X: 0,
        paddle2X: 0,
        score: 0,
        lives: 3,
        phase: PHASE.WAITING,
        countdown: 3,
        blocksRemaining: TOTAL_BLOCKS,
        blocks: Array.from({ length: TOTAL_BLOCKS }, () => ({ alive: true })),
      };
      const buf = SNAPSHOT.encode(state);
      const decoded = SNAPSHOT.decode(buf);
      expect(decoded.score).toBe(0);
      expect(decoded.lives).toBe(3);
      expect(decoded.countdown).toBe(3);
      expect(decoded.blocksRemaining).toBe(TOTAL_BLOCKS);
      expect(decoded.blocksAlive.every((v) => v === true)).toBe(true);
    });
  });

  describe("encodeGameEnd / decodeGameEnd", () => {
    it("round-trips win", () => {
      const buf = GAME_END.encode({ score: 2500, won: true });
      const decoded = GAME_END.decode(buf);
      expect(decoded.score).toBe(2500);
      expect(decoded.won).toBe(true);
    });

    it("round-trips loss", () => {
      const buf = GAME_END.encode({ score: 800, won: false });
      const decoded = GAME_END.decode(buf);
      expect(decoded.score).toBe(800);
      expect(decoded.won).toBe(false);
    });

    it("has correct message type", () => {
      const buf = GAME_END.encode({ score: 100, won: true });
      expect(getMessageType(buf)).toBe(MSG_TYPE.GAME_END);
    });

    it("returns null for buffer too small", () => {
      const buf = new ArrayBuffer(2);
      expect(GAME_END.decode(buf)).toBeNull();
    });

    it("returns null for wrong message type", () => {
      const buf = new ArrayBuffer(4);
      const view = new DataView(buf);
      view.setUint8(0, 0x81);
      expect(GAME_END.decode(buf)).toBeNull();
    });
  });

  describe("encodeGameReady", () => {
    it("encodes single byte with correct type", () => {
      const buf = encodeGameReady();
      expect(buf.byteLength).toBe(1);
      expect(getMessageType(buf)).toBe(MSG_TYPE.GAME_READY);
    });
  });

  describe("getMessageType", () => {
    it("returns null for empty buffer", () => {
      const buf = new ArrayBuffer(0);
      expect(getMessageType(buf)).toBeNull();
    });

    it("returns type byte from buffer", () => {
      const buf = new ArrayBuffer(1);
      new DataView(buf).setUint8(0, 0x83);
      expect(getMessageType(buf)).toBe(0x83);
    });
  });

  describe("constants", () => {
    it("has 50 total blocks", () => {
      expect(TOTAL_BLOCKS).toBe(50);
    });

    it("has 6 phases", () => {
      expect(Object.keys(PHASE)).toHaveLength(6);
    });
  });
});
