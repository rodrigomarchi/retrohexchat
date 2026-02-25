import { describe, it, expect } from "vitest";
import {
  MSG_TYPE,
  PHASE,
  INPUT_KEY,
  GAME_MODE,
  ALIEN_TYPE,
  encodeGameState,
  decodeGameState,
  encodePlayerInput,
  decodePlayerInput,
  encodeGameEnd,
  decodeGameEnd,
  encodeGameReady,
  getMessageType,
} from "../../../../js/lib/games/hex_invaders/protocol.js";

function createTestState() {
  const aliens1 = [];
  for (let i = 0; i < 30; i++) {
    aliens1.push({
      type: i < 6 ? ALIEN_TYPE.TOP : i < 12 ? ALIEN_TYPE.MID : ALIEN_TYPE.BASE,
      x: 20 + (i % 6) * 40,
      y: 40 + Math.floor(i / 6) * 30,
    });
  }
  const aliens2 = [];
  for (let i = 0; i < 28; i++) {
    aliens2.push({
      type: i < 6 ? ALIEN_TYPE.TOP : i < 12 ? ALIEN_TYPE.MID : ALIEN_TYPE.BASE,
      x: 340 + (i % 6) * 40,
      y: 40 + Math.floor(i / 6) * 30,
    });
  }

  return {
    phase: PHASE.PLAYING,
    wave: 3,
    countdown: 0,
    mode: GAME_MODE.INVASION_WAR,
    seed: 123456789,
    score1: 1240,
    score2: 980,
    lives1: 3,
    lives2: 2,
    combo1Count: 3,
    combo2Count: 0,
    cannon1X: 150,
    cannon2X: 470,
    m1X: 150,
    m1Y: 200,
    m1Active: true,
    m2X: 0,
    m2Y: 0,
    m2Active: false,
    aliens1,
    alien1Count: 30,
    aliens2,
    alien2Count: 28,
    alien1DirRight: true,
    alien2DirRight: false,
    bombs: [
      { side: 1, x: 100, y: 300 },
      { side: 2, x: 400, y: 250 },
    ],
    bombCount: 2,
    shields: [4, 3, 4, 2],
    ufoX: 200,
    ufoActive: true,
    ufoDir: 1,
    drops: [
      { type: ALIEN_TYPE.REINFORCEMENT, targetSide: 2, timer: 80 },
      { type: ALIEN_TYPE.ARMORED, targetSide: 1, timer: 120 },
    ],
  };
}

describe("Hex Invaders Protocol", () => {
  describe("GAME_STATE encode/decode round-trip", () => {
    it("preserves all header fields", () => {
      const state = createTestState();
      const buf = encodeGameState(state);
      const decoded = decodeGameState(buf);

      expect(decoded.phase).toBe(PHASE.PLAYING);
      expect(decoded.wave).toBe(3);
      expect(decoded.countdown).toBe(0);
      expect(decoded.mode).toBe(GAME_MODE.INVASION_WAR);
      expect(decoded.seed).toBe(123456789);
    });

    it("preserves scores and player state", () => {
      const state = createTestState();
      const buf = encodeGameState(state);
      const decoded = decodeGameState(buf);

      expect(decoded.score1).toBe(1240);
      expect(decoded.score2).toBe(980);
      expect(decoded.lives1).toBe(3);
      expect(decoded.lives2).toBe(2);
      expect(decoded.combo1Count).toBe(3);
      expect(decoded.combo2Count).toBe(0);
    });

    it("preserves cannon positions", () => {
      const state = createTestState();
      const buf = encodeGameState(state);
      const decoded = decodeGameState(buf);

      expect(decoded.cannon1X).toBe(150);
      expect(decoded.cannon2X).toBe(470);
    });

    it("preserves missile state", () => {
      const state = createTestState();
      const buf = encodeGameState(state);
      const decoded = decodeGameState(buf);

      expect(decoded.m1X).toBe(150);
      expect(decoded.m1Y).toBe(200);
      expect(decoded.m1Active).toBe(true);
      expect(decoded.m2Active).toBe(false);
    });

    it("preserves alien grids with correct counts", () => {
      const state = createTestState();
      const buf = encodeGameState(state);
      const decoded = decodeGameState(buf);

      expect(decoded.alien1Count).toBe(30);
      expect(decoded.alien2Count).toBe(28);
      expect(decoded.aliens1[0].type).toBe(ALIEN_TYPE.TOP);
      expect(decoded.aliens1[0].x).toBe(20);
      expect(decoded.aliens1[0].y).toBe(40);
      expect(decoded.aliens1[6].type).toBe(ALIEN_TYPE.MID);
      expect(decoded.aliens1[12].type).toBe(ALIEN_TYPE.BASE);
    });

    it("preserves alien grid directions", () => {
      const state = createTestState();
      const buf = encodeGameState(state);
      const decoded = decodeGameState(buf);

      expect(decoded.alien1DirRight).toBe(true);
      expect(decoded.alien2DirRight).toBe(false);
    });

    it("preserves bombs with correct count", () => {
      const state = createTestState();
      const buf = encodeGameState(state);
      const decoded = decodeGameState(buf);

      expect(decoded.bombCount).toBe(2);
      expect(decoded.bombs[0].side).toBe(1);
      expect(decoded.bombs[0].x).toBe(100);
      expect(decoded.bombs[0].y).toBe(300);
      expect(decoded.bombs[1].side).toBe(2);
    });

    it("preserves shield HP values", () => {
      const state = createTestState();
      const buf = encodeGameState(state);
      const decoded = decodeGameState(buf);

      expect(decoded.shields).toEqual([4, 3, 4, 2]);
    });

    it("preserves UFO state", () => {
      const state = createTestState();
      const buf = encodeGameState(state);
      const decoded = decodeGameState(buf);

      expect(decoded.ufoX).toBe(200);
      expect(decoded.ufoActive).toBe(true);
      expect(decoded.ufoDir).toBe(1);
    });

    it("preserves drop queue", () => {
      const state = createTestState();
      const buf = encodeGameState(state);
      const decoded = decodeGameState(buf);

      expect(decoded.dropCount).toBe(2);
      expect(decoded.drops).toHaveLength(2);
      expect(decoded.drops[0].type).toBe(ALIEN_TYPE.REINFORCEMENT);
      expect(decoded.drops[0].targetSide).toBe(2);
      expect(decoded.drops[0].timer).toBe(80);
      expect(decoded.drops[1].type).toBe(ALIEN_TYPE.ARMORED);
      expect(decoded.drops[1].targetSide).toBe(1);
      expect(decoded.drops[1].timer).toBe(120);
    });

    it("has correct message type byte", () => {
      const state = createTestState();
      const buf = encodeGameState(state);
      const view = new DataView(buf);
      expect(view.getUint8(0)).toBe(0x80);
    });

    it("produces correct buffer size", () => {
      const state = createTestState();
      const buf = encodeGameState(state);
      expect(buf.byteLength).toBe(463);
    });
  });

  describe("GAME_STATE edge cases", () => {
    it("handles zero aliens", () => {
      const state = createTestState();
      state.aliens1 = [];
      state.alien1Count = 0;
      state.aliens2 = [];
      state.alien2Count = 0;

      const decoded = decodeGameState(encodeGameState(state));
      expect(decoded.alien1Count).toBe(0);
      expect(decoded.alien2Count).toBe(0);
    });

    it("handles max score (65535)", () => {
      const state = createTestState();
      state.score1 = 65535;
      state.score2 = 65535;

      const decoded = decodeGameState(encodeGameState(state));
      expect(decoded.score1).toBe(65535);
      expect(decoded.score2).toBe(65535);
    });

    it("handles all shields destroyed", () => {
      const state = createTestState();
      state.shields = [0, 0, 0, 0];

      const decoded = decodeGameState(encodeGameState(state));
      expect(decoded.shields).toEqual([0, 0, 0, 0]);
    });

    it("handles inactive UFO", () => {
      const state = createTestState();
      state.ufoActive = false;
      state.ufoX = 0;

      const decoded = decodeGameState(encodeGameState(state));
      expect(decoded.ufoActive).toBe(false);
    });

    it("handles empty drop queue", () => {
      const state = createTestState();
      state.drops = [];

      const decoded = decodeGameState(encodeGameState(state));
      expect(decoded.dropCount).toBe(0);
      expect(decoded.drops).toHaveLength(0);
    });

    it("returns null for too-small buffer", () => {
      const buf = new ArrayBuffer(10);
      expect(decodeGameState(buf)).toBeNull();
    });

    it("returns null for wrong message type", () => {
      const state = createTestState();
      const buf = encodeGameState(state);
      const view = new DataView(buf);
      view.setUint8(0, 0x81); // wrong type
      expect(decodeGameState(buf)).toBeNull();
    });
  });

  describe("PLAYER_INPUT encode/decode", () => {
    it("round-trips LEFT key press", () => {
      const buf = encodePlayerInput(INPUT_KEY.LEFT, true);
      const decoded = decodePlayerInput(buf);
      expect(decoded.keyCode).toBe(INPUT_KEY.LEFT);
      expect(decoded.pressed).toBe(true);
    });

    it("round-trips RIGHT key release", () => {
      const buf = encodePlayerInput(INPUT_KEY.RIGHT, false);
      const decoded = decodePlayerInput(buf);
      expect(decoded.keyCode).toBe(INPUT_KEY.RIGHT);
      expect(decoded.pressed).toBe(false);
    });

    it("round-trips FIRE key press", () => {
      const buf = encodePlayerInput(INPUT_KEY.FIRE, true);
      const decoded = decodePlayerInput(buf);
      expect(decoded.keyCode).toBe(INPUT_KEY.FIRE);
      expect(decoded.pressed).toBe(true);
    });

    it("has correct size (3 bytes)", () => {
      const buf = encodePlayerInput(INPUT_KEY.LEFT, true);
      expect(buf.byteLength).toBe(3);
    });

    it("returns null for too-small buffer", () => {
      const buf = new ArrayBuffer(1);
      expect(decodePlayerInput(buf)).toBeNull();
    });

    it("returns null for wrong message type", () => {
      const buf = encodePlayerInput(INPUT_KEY.LEFT, true);
      const view = new DataView(buf);
      view.setUint8(0, 0x80); // wrong type
      expect(decodePlayerInput(buf)).toBeNull();
    });
  });

  describe("GAME_END encode/decode", () => {
    it("round-trips normal scores", () => {
      const buf = encodeGameEnd({ score1: 1240, score2: 980, winner: 1 });
      const decoded = decodeGameEnd(buf);
      expect(decoded.score1).toBe(1240);
      expect(decoded.score2).toBe(980);
      expect(decoded.winner).toBe(1);
    });

    it("round-trips max scores", () => {
      const buf = encodeGameEnd({ score1: 65535, score2: 65535, winner: 2 });
      const decoded = decodeGameEnd(buf);
      expect(decoded.score1).toBe(65535);
      expect(decoded.score2).toBe(65535);
      expect(decoded.winner).toBe(2);
    });

    it("round-trips zero scores", () => {
      const buf = encodeGameEnd({ score1: 0, score2: 0, winner: 1 });
      const decoded = decodeGameEnd(buf);
      expect(decoded.score1).toBe(0);
      expect(decoded.score2).toBe(0);
    });

    it("has correct size (6 bytes)", () => {
      const buf = encodeGameEnd({ score1: 100, score2: 200, winner: 1 });
      expect(buf.byteLength).toBe(6);
    });

    it("returns null for too-small buffer", () => {
      expect(decodeGameEnd(new ArrayBuffer(3))).toBeNull();
    });

    it("returns null for wrong message type", () => {
      const buf = encodeGameEnd({ score1: 100, score2: 200, winner: 1 });
      new DataView(buf).setUint8(0, 0x80);
      expect(decodeGameEnd(buf)).toBeNull();
    });
  });

  describe("GAME_READY", () => {
    it("encodes as 1 byte with correct type", () => {
      const buf = encodeGameReady();
      expect(buf.byteLength).toBe(1);
      expect(new DataView(buf).getUint8(0)).toBe(0x84);
    });
  });

  describe("getMessageType", () => {
    it("returns GAME_STATE type", () => {
      const buf = encodeGameState(createTestState());
      expect(getMessageType(buf)).toBe(MSG_TYPE.GAME_STATE);
    });

    it("returns PLAYER_INPUT type", () => {
      const buf = encodePlayerInput(INPUT_KEY.FIRE, true);
      expect(getMessageType(buf)).toBe(MSG_TYPE.PLAYER_INPUT);
    });

    it("returns GAME_END type", () => {
      const buf = encodeGameEnd({ score1: 100, score2: 200, winner: 1 });
      expect(getMessageType(buf)).toBe(MSG_TYPE.GAME_END);
    });

    it("returns GAME_READY type", () => {
      const buf = encodeGameReady();
      expect(getMessageType(buf)).toBe(MSG_TYPE.GAME_READY);
    });

    it("returns null for empty buffer", () => {
      expect(getMessageType(new ArrayBuffer(0))).toBeNull();
    });
  });

  describe("GAME_STATE decode slicing", () => {
    it("slices aliens1 to alien1Count", () => {
      const state = createTestState();
      state.alien1Count = 5;
      state.aliens1 = state.aliens1.slice(0, 5);
      const decoded = decodeGameState(encodeGameState(state));

      expect(decoded.aliens1).toHaveLength(5);
      expect(decoded.aliens1.every((a) => a.type !== 0)).toBe(true);
    });

    it("slices aliens2 to alien2Count", () => {
      const state = createTestState();
      state.alien2Count = 3;
      state.aliens2 = state.aliens2.slice(0, 3);
      const decoded = decodeGameState(encodeGameState(state));

      expect(decoded.aliens2).toHaveLength(3);
    });

    it("slices bombs to bombCount", () => {
      const state = createTestState();
      const decoded = decodeGameState(encodeGameState(state));

      // bombCount is 2, so bombs should have exactly 2 entries
      expect(decoded.bombs).toHaveLength(2);
      expect(decoded.bombs[0].side).toBe(1);
      expect(decoded.bombs[1].side).toBe(2);
    });

    it("returns empty arrays when counts are zero", () => {
      const state = createTestState();
      state.alien1Count = 0;
      state.aliens1 = [];
      state.alien2Count = 0;
      state.aliens2 = [];
      state.bombCount = 0;
      state.bombs = [];
      state.drops = [];

      const decoded = decodeGameState(encodeGameState(state));
      expect(decoded.aliens1).toHaveLength(0);
      expect(decoded.aliens2).toHaveLength(0);
      expect(decoded.bombs).toHaveLength(0);
      expect(decoded.drops).toHaveLength(0);
    });
  });

  describe("GAME_STATE all phases round-trip", () => {
    it("preserves each PHASE value", () => {
      for (const [, val] of Object.entries(PHASE)) {
        const state = createTestState();
        state.phase = val;
        const decoded = decodeGameState(encodeGameState(state));
        expect(decoded.phase).toBe(val);
      }
    });

    it("preserves each GAME_MODE value", () => {
      for (const [, val] of Object.entries(GAME_MODE)) {
        const state = createTestState();
        state.mode = val;
        const decoded = decodeGameState(encodeGameState(state));
        expect(decoded.mode).toBe(val);
      }
    });
  });

  describe("GAME_END encoding consistency", () => {
    it("round-trips score 256 (boundary of high/low byte)", () => {
      const buf = encodeGameEnd({ score1: 256, score2: 255, winner: 1 });
      const decoded = decodeGameEnd(buf);
      expect(decoded.score1).toBe(256);
      expect(decoded.score2).toBe(255);
    });

    it("round-trips winner=0 (draw/no winner)", () => {
      const buf = encodeGameEnd({ score1: 100, score2: 100, winner: 0 });
      const decoded = decodeGameEnd(buf);
      expect(decoded.winner).toBe(0);
    });
  });

  describe("enum values", () => {
    it("PHASE has all expected values", () => {
      expect(PHASE.WAITING).toBe(0);
      expect(PHASE.COUNTDOWN).toBe(1);
      expect(PHASE.PLAYING).toBe(2);
      expect(PHASE.WAVE_CLEAR).toBe(3);
      expect(PHASE.WAVE_START).toBe(4);
      expect(PHASE.FINISHED).toBe(5);
    });

    it("GAME_MODE has all expected values", () => {
      expect(GAME_MODE.INVASION_WAR).toBe(0);
      expect(GAME_MODE.COOP).toBe(1);
      expect(GAME_MODE.BLITZ).toBe(2);
    });

    it("ALIEN_TYPE has all expected values", () => {
      expect(ALIEN_TYPE.NONE).toBe(0);
      expect(ALIEN_TYPE.BASE).toBe(1);
      expect(ALIEN_TYPE.MID).toBe(2);
      expect(ALIEN_TYPE.TOP).toBe(3);
      expect(ALIEN_TYPE.REINFORCEMENT).toBe(4);
      expect(ALIEN_TYPE.ARMORED).toBe(5);
    });
  });
});
