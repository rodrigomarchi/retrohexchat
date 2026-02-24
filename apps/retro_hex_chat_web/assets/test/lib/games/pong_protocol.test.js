import { describe, it, expect } from "vitest";
import {
  MSG_TYPE,
  PHASE,
  INPUT_KEY,
  encodeGameState,
  decodeGameState,
  encodePlayerInput,
  decodePlayerInput,
  encodeGameEnd,
  decodeGameEnd,
  encodeGameReady,
  getMessageType,
} from "../../../js/lib/games/pong_protocol.js";

describe("pong_protocol", () => {
  describe("GAME_STATE encode/decode", () => {
    it("roundtrips a full game state", () => {
      const state = {
        ballX: 320.5,
        ballY: 240.25,
        ballVX: 4.5,
        ballVY: -2.75,
        paddle1Y: 200,
        paddle2Y: 180,
        score1: 7,
        score2: 11,
        phase: PHASE.PLAYING,
        countdown: 0,
      };

      const buf = encodeGameState(state);
      expect(buf.byteLength).toBe(25);

      const decoded = decodeGameState(buf);
      expect(decoded.ballX).toBeCloseTo(320.5, 1);
      expect(decoded.ballY).toBeCloseTo(240.25, 1);
      expect(decoded.ballVX).toBeCloseTo(4.5, 1);
      expect(decoded.ballVY).toBeCloseTo(-2.75, 1);
      expect(decoded.paddle1Y).toBe(200);
      expect(decoded.paddle2Y).toBe(180);
      expect(decoded.score1).toBe(7);
      expect(decoded.score2).toBe(11);
      expect(decoded.phase).toBe(PHASE.PLAYING);
      expect(decoded.countdown).toBe(0);
    });

    it("produces exactly 25 bytes", () => {
      const state = {
        ballX: 0,
        ballY: 0,
        ballVX: 0,
        ballVY: 0,
        paddle1Y: 0,
        paddle2Y: 0,
        score1: 0,
        score2: 0,
        phase: PHASE.WAITING,
        countdown: 0,
      };
      expect(encodeGameState(state).byteLength).toBe(25);
    });

    it("sets type byte to GAME_STATE (0x80)", () => {
      const state = {
        ballX: 0,
        ballY: 0,
        ballVX: 0,
        ballVY: 0,
        paddle1Y: 0,
        paddle2Y: 0,
        score1: 0,
        score2: 0,
        phase: 0,
        countdown: 0,
      };
      const buf = encodeGameState(state);
      expect(new DataView(buf).getUint8(0)).toBe(0x80);
    });

    it("rounds paddle positions to nearest integer", () => {
      const state = {
        ballX: 0,
        ballY: 0,
        ballVX: 0,
        ballVY: 0,
        paddle1Y: 199.7,
        paddle2Y: 300.3,
        score1: 0,
        score2: 0,
        phase: 0,
        countdown: 0,
      };
      const decoded = decodeGameState(encodeGameState(state));
      expect(decoded.paddle1Y).toBe(200);
      expect(decoded.paddle2Y).toBe(300);
    });

    it("handles max paddle Y (480)", () => {
      const state = {
        ballX: 0,
        ballY: 0,
        ballVX: 0,
        ballVY: 0,
        paddle1Y: 480,
        paddle2Y: 0,
        score1: 0,
        score2: 0,
        phase: 0,
        countdown: 0,
      };
      const decoded = decodeGameState(encodeGameState(state));
      expect(decoded.paddle1Y).toBe(480);
    });

    it("handles all phase values", () => {
      for (const [, value] of Object.entries(PHASE)) {
        const state = {
          ballX: 0,
          ballY: 0,
          ballVX: 0,
          ballVY: 0,
          paddle1Y: 0,
          paddle2Y: 0,
          score1: 0,
          score2: 0,
          phase: value,
          countdown: 0,
        };
        const decoded = decodeGameState(encodeGameState(state));
        expect(decoded.phase).toBe(value);
      }
    });

    it("handles countdown values 0-3", () => {
      for (let cd = 0; cd <= 3; cd++) {
        const state = {
          ballX: 0,
          ballY: 0,
          ballVX: 0,
          ballVY: 0,
          paddle1Y: 0,
          paddle2Y: 0,
          score1: 0,
          score2: 0,
          phase: PHASE.COUNTDOWN,
          countdown: cd,
        };
        const decoded = decodeGameState(encodeGameState(state));
        expect(decoded.countdown).toBe(cd);
      }
    });

    it("handles negative ball velocities", () => {
      const state = {
        ballX: 100,
        ballY: 200,
        ballVX: -5.5,
        ballVY: -3.25,
        paddle1Y: 0,
        paddle2Y: 0,
        score1: 0,
        score2: 0,
        phase: 0,
        countdown: 0,
      };
      const decoded = decodeGameState(encodeGameState(state));
      expect(decoded.ballVX).toBeCloseTo(-5.5, 1);
      expect(decoded.ballVY).toBeCloseTo(-3.25, 1);
    });

    it("returns null for buffer too small", () => {
      expect(decodeGameState(new ArrayBuffer(24))).toBeNull();
      expect(decodeGameState(new ArrayBuffer(0))).toBeNull();
    });

    it("returns null for wrong message type", () => {
      const buf = new ArrayBuffer(25);
      new DataView(buf).setUint8(0, 0x81);
      expect(decodeGameState(buf)).toBeNull();
    });
  });

  describe("PLAYER_INPUT encode/decode", () => {
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

    it("sets type byte to PLAYER_INPUT (0x81)", () => {
      const buf = encodePlayerInput(INPUT_KEY.UP, true);
      expect(new DataView(buf).getUint8(0)).toBe(0x81);
    });

    it("returns null for buffer too small", () => {
      expect(decodePlayerInput(new ArrayBuffer(2))).toBeNull();
    });

    it("returns null for wrong message type", () => {
      const buf = new ArrayBuffer(3);
      new DataView(buf).setUint8(0, 0x80);
      expect(decodePlayerInput(buf)).toBeNull();
    });
  });

  describe("GAME_END encode/decode", () => {
    it("roundtrips a game end", () => {
      const buf = encodeGameEnd(11, 7, 1);
      expect(buf.byteLength).toBe(4);
      const decoded = decodeGameEnd(buf);
      expect(decoded.score1).toBe(11);
      expect(decoded.score2).toBe(7);
      expect(decoded.winner).toBe(1);
    });

    it("roundtrips player 2 win", () => {
      const decoded = decodeGameEnd(encodeGameEnd(9, 11, 2));
      expect(decoded.score1).toBe(9);
      expect(decoded.score2).toBe(11);
      expect(decoded.winner).toBe(2);
    });

    it("sets type byte to GAME_END (0x83)", () => {
      const buf = encodeGameEnd(0, 0, 1);
      expect(new DataView(buf).getUint8(0)).toBe(0x83);
    });

    it("returns null for buffer too small", () => {
      expect(decodeGameEnd(new ArrayBuffer(3))).toBeNull();
    });

    it("returns null for wrong message type", () => {
      const buf = new ArrayBuffer(4);
      new DataView(buf).setUint8(0, 0x80);
      expect(decodeGameEnd(buf)).toBeNull();
    });
  });

  describe("GAME_READY encode", () => {
    it("produces 1 byte with type GAME_READY", () => {
      const buf = encodeGameReady();
      expect(buf.byteLength).toBe(1);
      expect(new DataView(buf).getUint8(0)).toBe(0x84);
    });
  });

  describe("getMessageType", () => {
    it("returns type byte from any buffer", () => {
      expect(getMessageType(encodeGameReady())).toBe(MSG_TYPE.GAME_READY);
      expect(getMessageType(encodePlayerInput(0, true))).toBe(MSG_TYPE.PLAYER_INPUT);
      expect(
        getMessageType(
          encodeGameState({
            ballX: 0,
            ballY: 0,
            ballVX: 0,
            ballVY: 0,
            paddle1Y: 0,
            paddle2Y: 0,
            score1: 0,
            score2: 0,
            phase: 0,
            countdown: 0,
          }),
        ),
      ).toBe(MSG_TYPE.GAME_STATE);
      expect(getMessageType(encodeGameEnd(0, 0, 1))).toBe(MSG_TYPE.GAME_END);
    });

    it("returns null for empty buffer", () => {
      expect(getMessageType(new ArrayBuffer(0))).toBeNull();
    });
  });

  describe("protocol constants", () => {
    it("all message types are >= 0x80 (game message range)", () => {
      for (const type of Object.values(MSG_TYPE)) {
        expect(type).toBeGreaterThanOrEqual(0x80);
      }
    });

    it("phase enum has 6 values (0-5)", () => {
      expect(Object.keys(PHASE)).toHaveLength(6);
      expect(PHASE.WAITING).toBe(0);
      expect(PHASE.FINISHED).toBe(5);
    });

    it("input key enum has 2 values", () => {
      expect(Object.keys(INPUT_KEY)).toHaveLength(2);
      expect(INPUT_KEY.UP).toBe(0);
      expect(INPUT_KEY.DOWN).toBe(1);
    });
  });
});
