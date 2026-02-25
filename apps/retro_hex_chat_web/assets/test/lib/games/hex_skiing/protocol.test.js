import { describe, it, expect } from "vitest";
import {
  MSG_TYPE,
  PHASE,
  GAME_MODE,
  SKIER_STATE,
  INPUT_KEY,
  getMessageType,
  encodeGameState,
  decodeGameState,
  encodePlayerInput,
  decodePlayerInput,
  encodeGameEnd,
  decodeGameEnd,
  encodeGameReady,
} from "../../../../js/lib/games/hex_skiing/protocol.js";

describe("Hex Skiing Protocol", () => {
  describe("getMessageType", () => {
    it("returns null for null or empty buffer", () => {
      expect(getMessageType(null)).toBeNull();
      expect(getMessageType(new ArrayBuffer(0))).toBeNull();
    });

    it("reads the first byte as message type", () => {
      const buf = new ArrayBuffer(1);
      new DataView(buf).setUint8(0, MSG_TYPE.GAME_STATE);
      expect(getMessageType(buf)).toBe(MSG_TYPE.GAME_STATE);
    });
  });

  describe("GAME_STATE encode/decode", () => {
    function makeState(overrides = {}) {
      return {
        phase: PHASE.RACING,
        mode: GAME_MODE.ALPINE_RACE,
        round: 1,
        countdown: 0,
        seed: 12345,
        scrollY: 1500.5,
        avalancheY: 800.25,
        avalancheSpeed: 1.25,
        blizzardActive: false,
        blizzardTimer: 0,
        p1X: 280,
        p1VelX: -2.5,
        p1State: SKIER_STATE.SKIING,
        p1Timer: 42.3,
        p1BoostTimer: 0,
        p1IceTimer: 0,
        p1StunTimer: 0,
        p1Distance: 4500.75,
        p2X: 360,
        p2VelX: 1.8,
        p2State: SKIER_STATE.BOOSTED,
        p2Timer: 41.1,
        p2BoostTimer: 120,
        p2IceTimer: 0,
        p2StunTimer: 0,
        p2Distance: 4600.5,
        events: 0,
        p1RoundWins: 1,
        p2RoundWins: 0,
        gateCount: 2,
        gates: [
          { x: 200, y: 600, width: 60, clearedP1: true, clearedP2: false },
          { x: 350, y: 1200, width: 50, clearedP1: false, clearedP2: false },
        ],
        itemCount: 1,
        items: [{ type: 0, x: 400, y: 5000.5, collected: 0 }],
        ...overrides,
      };
    }

    it("roundtrips game state", () => {
      const original = makeState();
      const buf = encodeGameState(original);
      const decoded = decodeGameState(buf);

      expect(decoded).not.toBeNull();
      expect(decoded.phase).toBe(original.phase);
      expect(decoded.mode).toBe(original.mode);
      expect(decoded.round).toBe(original.round);
      expect(decoded.seed).toBe(original.seed);
      expect(decoded.scrollY).toBeCloseTo(original.scrollY, 1);
      expect(decoded.avalancheY).toBeCloseTo(original.avalancheY, 1);
      expect(decoded.avalancheSpeed).toBeCloseTo(original.avalancheSpeed, 1);
      expect(decoded.blizzardActive).toBe(original.blizzardActive);
      expect(decoded.p1X).toBe(original.p1X);
      expect(decoded.p1VelX).toBeCloseTo(original.p1VelX, 1);
      expect(decoded.p1State).toBe(original.p1State);
      expect(decoded.p1Timer).toBeCloseTo(original.p1Timer, 1);
      expect(decoded.p1Distance).toBeCloseTo(original.p1Distance, 0);
      expect(decoded.p2X).toBe(original.p2X);
      expect(decoded.p2State).toBe(original.p2State);
      expect(decoded.p2BoostTimer).toBe(original.p2BoostTimer);
      expect(decoded.p1RoundWins).toBe(original.p1RoundWins);
      expect(decoded.p2RoundWins).toBe(original.p2RoundWins);
    });

    it("roundtrips gates including y position", () => {
      const original = makeState();
      const buf = encodeGameState(original);
      const decoded = decodeGameState(buf);

      expect(decoded.gateCount).toBe(2);
      expect(decoded.gates[0].x).toBe(200);
      expect(decoded.gates[0].y).toBeCloseTo(600, 0);
      expect(decoded.gates[0].width).toBe(60);
      expect(decoded.gates[0].clearedP1).toBe(true);
      expect(decoded.gates[0].clearedP2).toBe(false);
      expect(decoded.gates[1].x).toBe(350);
      expect(decoded.gates[1].y).toBeCloseTo(1200, 0);
    });

    it("roundtrips items", () => {
      const original = makeState();
      const buf = encodeGameState(original);
      const decoded = decodeGameState(buf);

      expect(decoded.itemCount).toBe(1);
      expect(decoded.items[0].type).toBe(0);
      expect(decoded.items[0].x).toBe(400);
      expect(decoded.items[0].y).toBeCloseTo(5000.5, 0);
      expect(decoded.items[0].collected).toBe(0);
    });

    it("handles empty gates and items", () => {
      const original = makeState({ gateCount: 0, gates: [], itemCount: 0, items: [] });
      const buf = encodeGameState(original);
      const decoded = decodeGameState(buf);

      expect(decoded.gateCount).toBe(0);
      expect(decoded.gates).toEqual([]);
      expect(decoded.itemCount).toBe(0);
      expect(decoded.items).toEqual([]);
    });

    it("handles blizzard active state", () => {
      const original = makeState({ blizzardActive: true, blizzardTimer: 300 });
      const buf = encodeGameState(original);
      const decoded = decodeGameState(buf);

      expect(decoded.blizzardActive).toBe(true);
      expect(decoded.blizzardTimer).toBe(300);
    });

    it("returns null for invalid buffer", () => {
      expect(decodeGameState(new ArrayBuffer(5))).toBeNull();
    });

    it("returns null for wrong message type", () => {
      const buf = new ArrayBuffer(100);
      new DataView(buf).setUint8(0, MSG_TYPE.PLAYER_INPUT);
      expect(decodeGameState(buf)).toBeNull();
    });

    it("returns null when gateCount exceeds MAX_GATES", () => {
      const original = makeState({ gateCount: 0, gates: [], itemCount: 0, items: [] });
      const buf = encodeGameState(original);
      const v = new DataView(buf);
      // Tamper with gateCount byte (at HEADER_SIZE offset)
      v.setUint8(57, 255); // Set gateCount to 255
      expect(decodeGameState(buf)).toBeNull();
    });

    it("returns null when buffer is truncated mid-gates", () => {
      const original = makeState();
      const buf = encodeGameState(original);
      // Truncate the buffer to cut off gate data
      const truncated = buf.slice(0, 60);
      expect(decodeGameState(truncated)).toBeNull();
    });

    it("clamps gate count to MAX_GATES on encode", () => {
      const state = makeState({
        gateCount: 20,
        gates: Array.from({ length: 20 }, (_, i) => ({
          x: 100 + i * 10,
          y: 600 + i * 600,
          width: 60,
          clearedP1: false,
          clearedP2: false,
        })),
      });
      const buf = encodeGameState(state);
      const decoded = decodeGameState(buf);
      expect(decoded).not.toBeNull();
      expect(decoded.gateCount).toBeLessThanOrEqual(8);
    });

    it("roundtrips events bitmask", () => {
      const original = makeState({ events: 0xff });
      const buf = encodeGameState(original);
      const decoded = decodeGameState(buf);
      expect(decoded.events).toBe(0xff);
    });
  });

  describe("PLAYER_INPUT encode/decode", () => {
    it("roundtrips left key press", () => {
      const buf = encodePlayerInput(INPUT_KEY.LEFT, true);
      const decoded = decodePlayerInput(buf);

      expect(decoded).not.toBeNull();
      expect(decoded.keyCode).toBe(INPUT_KEY.LEFT);
      expect(decoded.pressed).toBe(true);
    });

    it("roundtrips right key release", () => {
      const buf = encodePlayerInput(INPUT_KEY.RIGHT, false);
      const decoded = decodePlayerInput(buf);

      expect(decoded.keyCode).toBe(INPUT_KEY.RIGHT);
      expect(decoded.pressed).toBe(false);
    });

    it("returns null for too-small buffer", () => {
      expect(decodePlayerInput(new ArrayBuffer(2))).toBeNull();
    });

    it("returns null for wrong message type", () => {
      const buf = new ArrayBuffer(3);
      new DataView(buf).setUint8(0, MSG_TYPE.GAME_STATE);
      expect(decodePlayerInput(buf)).toBeNull();
    });
  });

  describe("GAME_END encode/decode", () => {
    it("roundtrips game result", () => {
      const result = { score1: 2, score2: 1, winner: 1 };
      const buf = encodeGameEnd(result);
      const decoded = decodeGameEnd(buf);

      expect(decoded).not.toBeNull();
      expect(decoded.score1).toBe(2);
      expect(decoded.score2).toBe(1);
      expect(decoded.winner).toBe(1);
    });

    it("handles draw", () => {
      const result = { score1: 1, score2: 1, winner: 0 };
      const buf = encodeGameEnd(result);
      const decoded = decodeGameEnd(buf);

      expect(decoded.winner).toBe(0);
    });

    it("returns null for too-small buffer", () => {
      expect(decodeGameEnd(new ArrayBuffer(5))).toBeNull();
    });
  });

  describe("GAME_READY", () => {
    it("encodes a 1-byte message", () => {
      const buf = encodeGameReady();
      expect(buf.byteLength).toBe(1);
      expect(getMessageType(buf)).toBe(MSG_TYPE.GAME_READY);
    });
  });
});
