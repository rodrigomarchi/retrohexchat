import { describe, it, expect } from "vitest";
import {
  MSG_TYPE,
  PHASE,
  DIR,
  INPUT_KEY,
  GRID_W,
  GRID_H,
  WINS_NEEDED,
  encodeGameReady,
  getMessageType,
  SNAPSHOT,
  GAME_END,
} from "../../../../js/lib/games/surround/protocol.js";

describe("surround_protocol", () => {
  describe("encodeGameState / decodeGameState", () => {
    function makeState() {
      return {
        p1: { x: 5, y: 20, dir: DIR.RIGHT },
        p2: { x: 54, y: 20, dir: DIR.LEFT },
        score1: 2,
        score2: 1,
        phase: PHASE.PLAYING,
        countdown: 0,
        round: 2,
      };
    }

    it("round-trips game state correctly", () => {
      const state = makeState();
      const buf = SNAPSHOT.encode(state);
      const decoded = SNAPSHOT.decode(buf);

      expect(decoded.p1x).toBe(state.p1.x);
      expect(decoded.p1y).toBe(state.p1.y);
      expect(decoded.p1dir).toBe(state.p1.dir);
      expect(decoded.p2x).toBe(state.p2.x);
      expect(decoded.p2y).toBe(state.p2.y);
      expect(decoded.p2dir).toBe(state.p2.dir);
      expect(decoded.score1).toBe(state.score1);
      expect(decoded.score2).toBe(state.score2);
      expect(decoded.phase).toBe(state.phase);
      expect(decoded.countdown).toBe(state.countdown);
      expect(decoded.round).toBe(state.round);
    });

    it("has correct message type byte", () => {
      const buf = SNAPSHOT.encode(makeState());
      expect(getMessageType(buf)).toBe(MSG_TYPE.GAME_STATE);
    });

    it("produces exactly 12 bytes", () => {
      const buf = SNAPSHOT.encode(makeState());
      expect(buf.byteLength).toBe(12);
    });

    it("returns null for buffer too small", () => {
      const buf = new ArrayBuffer(5);
      expect(SNAPSHOT.decode(buf)).toBeNull();
    });

    it("returns null for wrong message type", () => {
      const buf = new ArrayBuffer(12);
      const view = new DataView(buf);
      view.setUint8(0, 0x81);
      expect(SNAPSHOT.decode(buf)).toBeNull();
    });

    it("round-trips zero values and max positions", () => {
      const state = {
        p1: { x: 0, y: 0, dir: DIR.UP },
        p2: { x: GRID_W - 1, y: GRID_H - 1, dir: DIR.DOWN },
        score1: 0,
        score2: 0,
        phase: PHASE.WAITING,
        countdown: 3,
        round: 0,
      };
      const buf = SNAPSHOT.encode(state);
      const decoded = SNAPSHOT.decode(buf);
      expect(decoded.p1x).toBe(0);
      expect(decoded.p1y).toBe(0);
      expect(decoded.p2x).toBe(GRID_W - 1);
      expect(decoded.p2y).toBe(GRID_H - 1);
      expect(decoded.countdown).toBe(3);
    });

    it("round-trips all direction values", () => {
      for (const dir of [DIR.UP, DIR.DOWN, DIR.LEFT, DIR.RIGHT]) {
        const state = {
          p1: { x: 10, y: 10, dir },
          p2: { x: 20, y: 20, dir },
          score1: 0,
          score2: 0,
          phase: PHASE.PLAYING,
          countdown: 0,
          round: 0,
        };
        const decoded = SNAPSHOT.decode(SNAPSHOT.encode(state));
        expect(decoded.p1dir).toBe(dir);
        expect(decoded.p2dir).toBe(dir);
      }
    });

    it("round-trips all phase values", () => {
      for (const phase of Object.values(PHASE)) {
        const state = {
          p1: { x: 5, y: 5, dir: DIR.RIGHT },
          p2: { x: 50, y: 35, dir: DIR.LEFT },
          score1: 1,
          score2: 2,
          phase,
          countdown: 0,
          round: 3,
        };
        const decoded = SNAPSHOT.decode(SNAPSHOT.encode(state));
        expect(decoded.phase).toBe(phase);
      }
    });
  });

  describe("encodeGameEnd / decodeGameEnd", () => {
    it("round-trips P1 wins", () => {
      const buf = GAME_END.encode({ score1: 3, score2: 1, winner: 1 });
      const decoded = GAME_END.decode(buf);
      expect(decoded.score1).toBe(3);
      expect(decoded.score2).toBe(1);
      expect(decoded.winner).toBe(1);
    });

    it("round-trips P2 wins", () => {
      const buf = GAME_END.encode({ score1: 2, score2: 3, winner: 2 });
      const decoded = GAME_END.decode(buf);
      expect(decoded.score1).toBe(2);
      expect(decoded.score2).toBe(3);
      expect(decoded.winner).toBe(2);
    });

    it("round-trips draw", () => {
      const buf = GAME_END.encode({ score1: 0, score2: 0, winner: 0 });
      const decoded = GAME_END.decode(buf);
      expect(decoded.winner).toBe(0);
    });

    it("has correct message type", () => {
      const buf = GAME_END.encode({ score1: 3, score2: 2, winner: 1 });
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

  describe("round overflow", () => {
    it("clamps round > 255 to uint8 range", () => {
      const state = {
        p1: { x: 5, y: 20, dir: DIR.RIGHT },
        p2: { x: 54, y: 20, dir: DIR.LEFT },
        score1: 0,
        score2: 0,
        phase: PHASE.PLAYING,
        countdown: 0,
        round: 256,
      };
      const buf = SNAPSHOT.encode(state);
      const decoded = SNAPSHOT.decode(buf);
      expect(decoded.round).toBe(0);
    });

    it("encodes round 257 as 1", () => {
      const state = {
        p1: { x: 5, y: 20, dir: DIR.RIGHT },
        p2: { x: 54, y: 20, dir: DIR.LEFT },
        score1: 0,
        score2: 0,
        phase: PHASE.PLAYING,
        countdown: 0,
        round: 257,
      };
      const buf = SNAPSHOT.encode(state);
      const decoded = SNAPSHOT.decode(buf);
      expect(decoded.round).toBe(1);
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
    it("has 60x40 grid", () => {
      expect(GRID_W).toBe(60);
      expect(GRID_H).toBe(40);
    });

    it("needs 3 wins", () => {
      expect(WINS_NEEDED).toBe(3);
    });

    it("has 5 phases", () => {
      expect(Object.keys(PHASE)).toHaveLength(5);
    });

    it("has 4 directions", () => {
      expect(Object.keys(DIR)).toHaveLength(4);
    });

    it("has 4 input keys", () => {
      expect(Object.keys(INPUT_KEY)).toHaveLength(4);
    });
  });
});
