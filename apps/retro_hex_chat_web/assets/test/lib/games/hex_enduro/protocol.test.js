import { describe, it, expect } from "vitest";
import {
  MSG_TYPE,
  PHASE,
  INPUT_KEY,
  GAME_MODE,
  WEATHER,
  CAR_TYPE,
  EVENT,
  MAX_AI_CARS,
  encodeGameState,
  decodeGameState,
  encodePlayerInput,
  decodePlayerInput,
  encodeGameEnd,
  decodeGameEnd,
  encodeGameReady,
  getMessageType,
} from "../../../../js/lib/games/hex_enduro/protocol.js";

function createTestState() {
  const aiCars = [];
  for (let i = 0; i < 8; i++) {
    aiCars.push({
      lane: i % 3,
      type: i % 4,
      zPos: 200 + i * 150,
      speed: 40 + i * 5,
    });
  }

  const fuelStations = [
    { lane: 1, zPos: 800 },
    { lane: 0, zPos: 1500 },
  ];

  return {
    phase: PHASE.RACING,
    mode: GAME_MODE.CLASSIC_DUEL,
    weather: WEATHER.DAY,
    weatherTimer: 3000,
    dayNumber: 1,
    countdown: 0,
    seed: 987654321,
    gameTimer: 0,
    p1Lane: 1,
    p1Speed: 500,
    p1Fuel: 800,
    p1Overtakes: 47,
    p1Score: 62,
    p1Boost: 0,
    p1ZOffset: 1000,
    p1LaneTransition: 0,
    p1CollisionTimer: 0,
    p2Lane: 2,
    p2Speed: 480,
    p2Fuel: 650,
    p2Overtakes: 39,
    p2Score: 54,
    p2Boost: 120,
    p2ZOffset: 950,
    p2LaneTransition: 128,
    p2CollisionTimer: 30,
    aiCarCount: 8,
    aiCars,
    fuelStationCount: 2,
    fuelStations,
    dayOvertakeTarget: 200,
    events: EVENT.OVERTAKE_AI | EVENT.SLIPSTREAM,
    p1Slipstream: 60,
    p2Slipstream: 0,
  };
}

describe("Hex Enduro Protocol", () => {
  describe("GAME_STATE encode/decode round-trip", () => {
    it("preserves header fields", () => {
      const state = createTestState();
      const buf = encodeGameState(state);
      const decoded = decodeGameState(buf);

      expect(decoded.phase).toBe(PHASE.RACING);
      expect(decoded.mode).toBe(GAME_MODE.CLASSIC_DUEL);
      expect(decoded.weather).toBe(WEATHER.DAY);
      expect(decoded.weatherTimer).toBe(3000);
      expect(decoded.dayNumber).toBe(1);
      expect(decoded.countdown).toBe(0);
      expect(decoded.seed).toBe(987654321);
      expect(decoded.gameTimer).toBe(0);
    });

    it("preserves player 1 state", () => {
      const state = createTestState();
      const decoded = decodeGameState(encodeGameState(state));

      expect(decoded.p1Lane).toBe(1);
      expect(decoded.p1Speed).toBe(500);
      expect(decoded.p1Fuel).toBe(800);
      expect(decoded.p1Overtakes).toBe(47);
      expect(decoded.p1Score).toBe(62);
      expect(decoded.p1Boost).toBe(0);
      expect(decoded.p1ZOffset).toBe(1000);
      expect(decoded.p1LaneTransition).toBe(0);
      expect(decoded.p1CollisionTimer).toBe(0);
    });

    it("preserves player 2 state", () => {
      const state = createTestState();
      const decoded = decodeGameState(encodeGameState(state));

      expect(decoded.p2Lane).toBe(2);
      expect(decoded.p2Speed).toBe(480);
      expect(decoded.p2Fuel).toBe(650);
      expect(decoded.p2Overtakes).toBe(39);
      expect(decoded.p2Score).toBe(54);
      expect(decoded.p2Boost).toBe(120);
      expect(decoded.p2ZOffset).toBe(950);
      expect(decoded.p2LaneTransition).toBe(128);
      expect(decoded.p2CollisionTimer).toBe(30);
    });

    it("preserves AI cars with packed lane+type", () => {
      const state = createTestState();
      const decoded = decodeGameState(encodeGameState(state));

      expect(decoded.aiCarCount).toBe(8);
      expect(decoded.aiCars).toHaveLength(8);
      expect(decoded.aiCars[0].lane).toBe(0);
      expect(decoded.aiCars[0].type).toBe(0);
      expect(decoded.aiCars[0].zPos).toBe(200);
      expect(decoded.aiCars[0].speed).toBe(40);
      expect(decoded.aiCars[3].lane).toBe(0);
      expect(decoded.aiCars[3].type).toBe(3);
      expect(decoded.aiCars[3].zPos).toBe(650);
    });

    it("preserves fuel stations", () => {
      const state = createTestState();
      const decoded = decodeGameState(encodeGameState(state));

      expect(decoded.fuelStationCount).toBe(2);
      expect(decoded.fuelStations).toHaveLength(2);
      expect(decoded.fuelStations[0].lane).toBe(1);
      expect(decoded.fuelStations[0].zPos).toBe(800);
      expect(decoded.fuelStations[1].lane).toBe(0);
      expect(decoded.fuelStations[1].zPos).toBe(1500);
    });

    it("preserves day progress and events", () => {
      const state = createTestState();
      const decoded = decodeGameState(encodeGameState(state));

      expect(decoded.dayOvertakeTarget).toBe(200);
      expect(decoded.events).toBe(EVENT.OVERTAKE_AI | EVENT.SLIPSTREAM);
    });

    it("preserves slipstream state", () => {
      const state = createTestState();
      const decoded = decodeGameState(encodeGameState(state));

      expect(decoded.p1Slipstream).toBe(60);
      expect(decoded.p2Slipstream).toBe(0);
    });

    it("has correct message type byte", () => {
      const buf = encodeGameState(createTestState());
      expect(new DataView(buf).getUint8(0)).toBe(0x80);
    });

    it("produces correct buffer size (141 bytes)", () => {
      const buf = encodeGameState(createTestState());
      expect(buf.byteLength).toBe(141);
    });
  });

  describe("GAME_STATE edge cases", () => {
    it("handles zero AI cars", () => {
      const state = createTestState();
      state.aiCars = [];
      state.aiCarCount = 0;
      const decoded = decodeGameState(encodeGameState(state));
      expect(decoded.aiCarCount).toBe(0);
      expect(decoded.aiCars).toHaveLength(0);
    });

    it("handles max AI cars (20)", () => {
      const state = createTestState();
      state.aiCars = [];
      for (let i = 0; i < MAX_AI_CARS; i++) {
        state.aiCars.push({ lane: i % 3, type: i % 4, zPos: i * 100, speed: 50 });
      }
      state.aiCarCount = MAX_AI_CARS;
      const decoded = decodeGameState(encodeGameState(state));
      expect(decoded.aiCarCount).toBe(20);
      expect(decoded.aiCars).toHaveLength(20);
    });

    it("handles zero fuel stations", () => {
      const state = createTestState();
      state.fuelStations = [];
      state.fuelStationCount = 0;
      const decoded = decodeGameState(encodeGameState(state));
      expect(decoded.fuelStationCount).toBe(0);
      expect(decoded.fuelStations).toHaveLength(0);
    });

    it("handles max scores (65535)", () => {
      const state = createTestState();
      state.p1Score = 65535;
      state.p2Score = 65535;
      const decoded = decodeGameState(encodeGameState(state));
      expect(decoded.p1Score).toBe(65535);
      expect(decoded.p2Score).toBe(65535);
    });

    it("handles max fuel (65535)", () => {
      const state = createTestState();
      state.p1Fuel = 65535;
      const decoded = decodeGameState(encodeGameState(state));
      expect(decoded.p1Fuel).toBe(65535);
    });

    it("handles all weather conditions", () => {
      for (const [, val] of Object.entries(WEATHER)) {
        const state = createTestState();
        state.weather = val;
        const decoded = decodeGameState(encodeGameState(state));
        expect(decoded.weather).toBe(val);
      }
    });

    it("handles all event flags", () => {
      const state = createTestState();
      state.events = 0xff;
      const decoded = decodeGameState(encodeGameState(state));
      expect(decoded.events).toBe(0xff);
    });

    it("handles zero events", () => {
      const state = createTestState();
      state.events = 0;
      const decoded = decodeGameState(encodeGameState(state));
      expect(decoded.events).toBe(0);
    });

    it("returns null for too-small buffer", () => {
      expect(decodeGameState(new ArrayBuffer(10))).toBeNull();
    });

    it("returns null for wrong message type", () => {
      const buf = encodeGameState(createTestState());
      new DataView(buf).setUint8(0, 0x81);
      expect(decodeGameState(buf)).toBeNull();
    });
  });

  describe("GAME_STATE AI car lane+type packing", () => {
    it("correctly packs and unpacks all lane/type combinations", () => {
      const state = createTestState();
      state.aiCars = [];
      // Test all 3 lanes × 4 types = 12 combos
      for (let lane = 0; lane <= 2; lane++) {
        for (let type = 0; type <= 3; type++) {
          state.aiCars.push({ lane, type, zPos: 500, speed: 50 });
        }
      }
      state.aiCarCount = 12;

      const decoded = decodeGameState(encodeGameState(state));
      let idx = 0;
      for (let lane = 0; lane <= 2; lane++) {
        for (let type = 0; type <= 3; type++) {
          expect(decoded.aiCars[idx].lane).toBe(lane);
          expect(decoded.aiCars[idx].type).toBe(type);
          idx++;
        }
      }
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

    it("round-trips ACCEL key press", () => {
      const buf = encodePlayerInput(INPUT_KEY.ACCEL, true);
      const decoded = decodePlayerInput(buf);
      expect(decoded.keyCode).toBe(INPUT_KEY.ACCEL);
      expect(decoded.pressed).toBe(true);
    });

    it("round-trips BRAKE key press", () => {
      const buf = encodePlayerInput(INPUT_KEY.BRAKE, true);
      const decoded = decodePlayerInput(buf);
      expect(decoded.keyCode).toBe(INPUT_KEY.BRAKE);
    });

    it("round-trips TURBO key press", () => {
      const buf = encodePlayerInput(INPUT_KEY.TURBO, true);
      const decoded = decodePlayerInput(buf);
      expect(decoded.keyCode).toBe(INPUT_KEY.TURBO);
    });

    it("has correct size (3 bytes)", () => {
      const buf = encodePlayerInput(INPUT_KEY.LEFT, true);
      expect(buf.byteLength).toBe(3);
    });

    it("returns null for too-small buffer", () => {
      expect(decodePlayerInput(new ArrayBuffer(1))).toBeNull();
    });

    it("returns null for wrong message type", () => {
      const buf = encodePlayerInput(INPUT_KEY.LEFT, true);
      new DataView(buf).setUint8(0, 0x80);
      expect(decodePlayerInput(buf)).toBeNull();
    });
  });

  describe("GAME_END encode/decode", () => {
    it("round-trips normal scores", () => {
      const buf = encodeGameEnd({ score1: 247, score2: 189, winner: 1 });
      const decoded = decodeGameEnd(buf);
      expect(decoded.score1).toBe(247);
      expect(decoded.score2).toBe(189);
      expect(decoded.winner).toBe(1);
    });

    it("round-trips max scores", () => {
      const buf = encodeGameEnd({ score1: 65535, score2: 65535, winner: 2 });
      const decoded = decodeGameEnd(buf);
      expect(decoded.score1).toBe(65535);
      expect(decoded.score2).toBe(65535);
    });

    it("round-trips zero scores", () => {
      const buf = encodeGameEnd({ score1: 0, score2: 0, winner: 1 });
      const decoded = decodeGameEnd(buf);
      expect(decoded.score1).toBe(0);
      expect(decoded.score2).toBe(0);
    });

    it("round-trips score 256 (byte boundary)", () => {
      const buf = encodeGameEnd({ score1: 256, score2: 255, winner: 1 });
      const decoded = decodeGameEnd(buf);
      expect(decoded.score1).toBe(256);
      expect(decoded.score2).toBe(255);
    });

    it("round-trips winner=0 (draw)", () => {
      const buf = encodeGameEnd({ score1: 100, score2: 100, winner: 0 });
      const decoded = decodeGameEnd(buf);
      expect(decoded.winner).toBe(0);
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
      expect(getMessageType(encodeGameState(createTestState()))).toBe(MSG_TYPE.GAME_STATE);
    });

    it("returns PLAYER_INPUT type", () => {
      expect(getMessageType(encodePlayerInput(INPUT_KEY.ACCEL, true))).toBe(MSG_TYPE.PLAYER_INPUT);
    });

    it("returns GAME_END type", () => {
      expect(getMessageType(encodeGameEnd({ score1: 1, score2: 2, winner: 1 }))).toBe(
        MSG_TYPE.GAME_END,
      );
    });

    it("returns GAME_READY type", () => {
      expect(getMessageType(encodeGameReady())).toBe(MSG_TYPE.GAME_READY);
    });

    it("returns null for empty buffer", () => {
      expect(getMessageType(new ArrayBuffer(0))).toBeNull();
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

  describe("enum values", () => {
    it("PHASE has all expected values", () => {
      expect(PHASE.WAITING).toBe(0);
      expect(PHASE.COUNTDOWN).toBe(1);
      expect(PHASE.RACING).toBe(2);
      expect(PHASE.DAY_END).toBe(3);
      expect(PHASE.FINISHED).toBe(4);
    });

    it("GAME_MODE has all expected values", () => {
      expect(GAME_MODE.CLASSIC_DUEL).toBe(0);
      expect(GAME_MODE.NIGHT_RACE).toBe(1);
      expect(GAME_MODE.SPRINT).toBe(2);
    });

    it("WEATHER has all expected values", () => {
      expect(WEATHER.DAY).toBe(0);
      expect(WEATHER.SNOW).toBe(1);
      expect(WEATHER.FOG).toBe(2);
      expect(WEATHER.NIGHT).toBe(3);
      expect(WEATHER.DAWN).toBe(4);
    });

    it("CAR_TYPE has all expected values", () => {
      expect(CAR_TYPE.SEDAN).toBe(0);
      expect(CAR_TYPE.TRUCK).toBe(1);
      expect(CAR_TYPE.SPORTS).toBe(2);
      expect(CAR_TYPE.VAN).toBe(3);
    });

    it("EVENT flags are distinct powers of 2", () => {
      const values = Object.values(EVENT);
      const unique = new Set(values);
      expect(unique.size).toBe(values.length);
      for (const v of values) {
        expect(v & (v - 1)).toBe(0); // power of 2
      }
    });

    it("INPUT_KEY has all expected values", () => {
      expect(INPUT_KEY.LEFT).toBe(0);
      expect(INPUT_KEY.RIGHT).toBe(1);
      expect(INPUT_KEY.ACCEL).toBe(2);
      expect(INPUT_KEY.BRAKE).toBe(3);
      expect(INPUT_KEY.TURBO).toBe(4);
    });
  });

  describe("GAME_STATE decode slicing", () => {
    it("slices aiCars to aiCarCount", () => {
      const state = createTestState();
      state.aiCarCount = 3;
      state.aiCars = state.aiCars.slice(0, 3);
      const decoded = decodeGameState(encodeGameState(state));
      expect(decoded.aiCars).toHaveLength(3);
    });

    it("slices fuelStations to fuelStationCount", () => {
      const state = createTestState();
      state.fuelStationCount = 1;
      state.fuelStations = state.fuelStations.slice(0, 1);
      const decoded = decodeGameState(encodeGameState(state));
      expect(decoded.fuelStations).toHaveLength(1);
    });

    it("returns empty arrays when counts are zero", () => {
      const state = createTestState();
      state.aiCarCount = 0;
      state.aiCars = [];
      state.fuelStationCount = 0;
      state.fuelStations = [];
      const decoded = decodeGameState(encodeGameState(state));
      expect(decoded.aiCars).toHaveLength(0);
      expect(decoded.fuelStations).toHaveLength(0);
    });
  });

  describe("GAME_STATE decode safety", () => {
    it("clamps aiCarCount to MAX_AI_CARS on decode", () => {
      const state = createTestState();
      const buf = encodeGameState(state);
      // Corrupt aiCarCount byte to be > MAX_AI_CARS
      const view = new DataView(buf);
      // aiCarCount is at offset: 1(type) + 13(header) + 14(p1) + 14(p2) = 42
      view.setUint8(42, 255);
      const decoded = decodeGameState(buf);
      expect(decoded.aiCarCount).toBeLessThanOrEqual(MAX_AI_CARS);
    });

    it("clamps fuelStationCount to MAX on decode", () => {
      const state = createTestState();
      const buf = encodeGameState(state);
      const view = new DataView(buf);
      // fuelStationCount is at offset: 42 + 1(count) + 20*4(cars) = 123
      view.setUint8(123, 255);
      const decoded = decodeGameState(buf);
      expect(decoded.fuelStationCount).toBeLessThanOrEqual(4);
    });

    it("clamps winner to 2 on decode", () => {
      const buf = encodeGameEnd({ score1: 100, score2: 200, winner: 1 });
      const view = new DataView(buf);
      view.setUint8(5, 99); // corrupt winner byte
      const decoded = decodeGameEnd(buf);
      expect(decoded.winner).toBeLessThanOrEqual(2);
    });
  });

  describe("GAME_END encode consistency", () => {
    it("uses little-endian Uint16 for scores", () => {
      const buf = encodeGameEnd({ score1: 0x0102, score2: 0x0304, winner: 1 });
      const view = new DataView(buf);
      // Little-endian: low byte first
      expect(view.getUint16(1, true)).toBe(0x0102);
      expect(view.getUint16(3, true)).toBe(0x0304);
    });

    it("handles undefined/null score gracefully", () => {
      const buf = encodeGameEnd({ score1: undefined, score2: null, winner: 0 });
      const decoded = decodeGameEnd(buf);
      expect(decoded.score1).toBe(0);
      expect(decoded.score2).toBe(0);
    });
  });

  describe("GAME_STATE timed mode fields", () => {
    it("preserves gameTimer for Night Race", () => {
      const state = createTestState();
      state.mode = GAME_MODE.NIGHT_RACE;
      state.gameTimer = 10800; // 3 min at 60fps
      const decoded = decodeGameState(encodeGameState(state));
      expect(decoded.gameTimer).toBe(10800);
    });

    it("preserves gameTimer for Sprint", () => {
      const state = createTestState();
      state.mode = GAME_MODE.SPRINT;
      state.gameTimer = 5400; // 90s at 60fps
      const decoded = decodeGameState(encodeGameState(state));
      expect(decoded.gameTimer).toBe(5400);
    });
  });
});
