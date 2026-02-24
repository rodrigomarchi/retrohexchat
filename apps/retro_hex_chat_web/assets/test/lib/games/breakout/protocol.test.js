import { describe, it, expect } from "vitest";
import {
  MSG_TYPE,
  PHASE,
  INPUT_KEY,
  TOTAL_BLOCKS,
  encodeBlockBitmap,
  decodeBlockBitmap,
  encodeGameState,
  decodeGameState,
  encodePlayerInput,
  decodePlayerInput,
  encodeGameEnd,
  decodeGameEnd,
  encodeGameReady,
  getMessageType,
} from "../../../../js/lib/games/breakout/protocol.js";

describe("breakout_protocol", () => {
  describe("block bitmap", () => {
    it("encodes all blocks alive", () => {
      const blocks = Array.from({ length: TOTAL_BLOCKS }, () => ({ alive: true }));
      const bitmap = encodeBlockBitmap(blocks);
      const decoded = decodeBlockBitmap(bitmap);
      expect(decoded.every((v) => v === true)).toBe(true);
    });

    it("encodes all blocks dead", () => {
      const blocks = Array.from({ length: TOTAL_BLOCKS }, () => ({ alive: false }));
      const bitmap = encodeBlockBitmap(blocks);
      const decoded = decodeBlockBitmap(bitmap);
      expect(decoded.every((v) => v === false)).toBe(true);
    });

    it("encodes specific pattern correctly", () => {
      const blocks = Array.from({ length: TOTAL_BLOCKS }, (_, i) => ({
        alive: i % 3 === 0,
      }));
      const bitmap = encodeBlockBitmap(blocks);
      const decoded = decodeBlockBitmap(bitmap);
      for (let i = 0; i < TOTAL_BLOCKS; i++) {
        expect(decoded[i]).toBe(i % 3 === 0);
      }
    });

    it("returns exactly 50 entries", () => {
      const blocks = Array.from({ length: TOTAL_BLOCKS }, () => ({ alive: true }));
      const bitmap = encodeBlockBitmap(blocks);
      const decoded = decodeBlockBitmap(bitmap);
      expect(decoded).toHaveLength(TOTAL_BLOCKS);
    });
  });

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
      const buf = encodeGameState(state);
      const decoded = decodeGameState(buf);

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
      const buf = encodeGameState(state);
      const decoded = decodeGameState(buf);

      for (let i = 0; i < TOTAL_BLOCKS; i++) {
        expect(decoded.blocksAlive[i]).toBe(state.blocks[i].alive);
      }
    });

    it("has correct message type byte", () => {
      const state = makeState();
      const buf = encodeGameState(state);
      expect(getMessageType(buf)).toBe(MSG_TYPE.GAME_STATE);
    });

    it("returns null for buffer too small", () => {
      const buf = new ArrayBuffer(5);
      expect(decodeGameState(buf)).toBeNull();
    });

    it("returns null for wrong message type", () => {
      const buf = new ArrayBuffer(34);
      const view = new DataView(buf);
      view.setUint8(0, MSG_TYPE.PLAYER_INPUT);
      expect(decodeGameState(buf)).toBeNull();
    });
  });

  describe("encodePlayerInput / decodePlayerInput", () => {
    it("round-trips LEFT pressed", () => {
      const buf = encodePlayerInput(INPUT_KEY.LEFT, true);
      const decoded = decodePlayerInput(buf);
      expect(decoded.keyCode).toBe(INPUT_KEY.LEFT);
      expect(decoded.pressed).toBe(true);
    });

    it("round-trips RIGHT released", () => {
      const buf = encodePlayerInput(INPUT_KEY.RIGHT, false);
      const decoded = decodePlayerInput(buf);
      expect(decoded.keyCode).toBe(INPUT_KEY.RIGHT);
      expect(decoded.pressed).toBe(false);
    });

    it("has correct message type", () => {
      const buf = encodePlayerInput(INPUT_KEY.LEFT, true);
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

  describe("encodeGameEnd / decodeGameEnd", () => {
    it("round-trips win", () => {
      const buf = encodeGameEnd(2500, true);
      const decoded = decodeGameEnd(buf);
      expect(decoded.score).toBe(2500);
      expect(decoded.won).toBe(true);
    });

    it("round-trips loss", () => {
      const buf = encodeGameEnd(800, false);
      const decoded = decodeGameEnd(buf);
      expect(decoded.score).toBe(800);
      expect(decoded.won).toBe(false);
    });

    it("has correct message type", () => {
      const buf = encodeGameEnd(100, true);
      expect(getMessageType(buf)).toBe(MSG_TYPE.GAME_END);
    });

    it("returns null for buffer too small", () => {
      const buf = new ArrayBuffer(2);
      expect(decodeGameEnd(buf)).toBeNull();
    });

    it("returns null for wrong message type", () => {
      const buf = new ArrayBuffer(4);
      const view = new DataView(buf);
      view.setUint8(0, MSG_TYPE.PLAYER_INPUT);
      expect(decodeGameEnd(buf)).toBeNull();
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

    it("has 2 input keys", () => {
      expect(Object.keys(INPUT_KEY)).toHaveLength(2);
    });
  });
});
