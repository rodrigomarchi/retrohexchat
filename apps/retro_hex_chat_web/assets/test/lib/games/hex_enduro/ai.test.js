import { describe, it, expect } from "vitest";
import { describeStrengthOrder } from "../../../support/games/strength_order.js";
import {
  ENDURO_AI_DIFFICULTIES,
  chooseEnduroTarget,
  createHexEnduroAI,
  enduroAIConfig,
  laneRisk,
  movementInputs,
  nearestFuelStation,
  normalizeEnduroAIDifficulty,
  shouldUseTurbo,
} from "../../../../js/lib/games/hex_enduro/ai.js";
import { GAME_MODE, PHASE, WEATHER } from "../../../../js/lib/games/hex_enduro/protocol.js";
import {
  FUEL_MAX,
  SPEED_MAX,
  createInitialState,
} from "../../../../js/lib/games/hex_enduro/physics.js";
import { itSetsDifficulty } from "../../../support/games/ai_tests.js";

function racingState(mode = GAME_MODE.CLASSIC_DUEL) {
  return {
    ...createInitialState(mode, 12345),
    phase: PHASE.RACING,
  };
}

/** The AI's car close behind on the middle lane, near top speed, with a full tank. */
function chasingState(p2 = {}) {
  const state = racingState();
  return {
    ...state,
    p1: { ...state.p1, lane: 0, targetLane: 0, zOffset: 90, speed: 720 },
    p2: {
      ...state.p2,
      lane: 1,
      targetLane: 1,
      zOffset: 20,
      speed: SPEED_MAX - 20,
      fuel: FUEL_MAX,
      ...p2,
    },
  };
}

describe("HexEnduroAI", () => {
  it("normalizes difficulty names", () => {
    expect(normalizeEnduroAIDifficulty("easy")).toBe("easy");
    expect(normalizeEnduroAIDifficulty("HARD")).toBe("hard");
    expect(normalizeEnduroAIDifficulty("legendary")).toBe("normal");
    expect(normalizeEnduroAIDifficulty(null)).toBe("normal");
  });

  itSetsDifficulty(createHexEnduroAI);

  it("returns neutral inputs outside racing phase", () => {
    const ai = createHexEnduroAI({ difficulty: "hard", rng: () => 0.5 });

    expect(ai.nextInputs({ state: createInitialState(GAME_MODE.CLASSIC_DUEL, 12345) })).toEqual({
      left: false,
      right: false,
      accel: false,
      brake: false,
      turbo: false,
    });
  });

  it("seeks fuel when the AI car is low on fuel", () => {
    const state = {
      ...racingState(),
      p2: { ...racingState().p2, lane: 0, targetLane: 0, fuel: 180 },
      fuelStations: [{ lane: 2, zPos: 560 }],
    };

    const fuel = nearestFuelStation(state, 2, ENDURO_AI_DIFFICULTIES.hard);
    const target = chooseEnduroTarget(state, 2, ENDURO_AI_DIFFICULTIES.hard, () => 0.5);

    expect(fuel).toMatchObject({ lane: 2, zPos: 560 });
    expect(target).toMatchObject({ lane: 2, reason: "fuel" });
  });

  it("ignores fuel stations in sprint mode", () => {
    const state = {
      ...racingState(GAME_MODE.SPRINT),
      p2: { ...racingState(GAME_MODE.SPRINT).p2, fuel: 20 },
      fuelStations: [{ lane: 1, zPos: 300 }],
    };

    expect(nearestFuelStation(state, 2, ENDURO_AI_DIFFICULTIES.hard)).toBeNull();
  });

  it("avoids traffic in the current lane", () => {
    const state = {
      ...racingState(),
      p2: { ...racingState().p2, lane: 1, targetLane: 1, speed: 650 },
      aiCars: [{ lane: 1, zPos: 22, speed: 35, type: 0 }],
    };

    const target = chooseEnduroTarget(state, 2, ENDURO_AI_DIFFICULTIES.hard, () => 0.5);

    expect(laneRisk(state, 1, 2, ENDURO_AI_DIFFICULTIES.hard)).toBeGreaterThan(20);
    expect(target.lane).not.toBe(1);
    expect(target.reason).toBe("cruise");
  });

  it("can choose the opponent lane to draft in slipstream", () => {
    const state = {
      ...racingState(),
      p1: { ...racingState().p1, lane: 2, targetLane: 2, zOffset: 120, speed: 700 },
      p2: { ...racingState().p2, lane: 0, targetLane: 0, zOffset: 0, speed: 690 },
    };

    const target = chooseEnduroTarget(state, 2, ENDURO_AI_DIFFICULTIES.hard, () => 0);

    expect(target).toMatchObject({ lane: 2, reason: "slipstream" });
  });

  it("moves toward target lane and speed", () => {
    const state = {
      ...racingState(),
      p2: { ...racingState().p2, lane: 0, targetLane: 0, speed: 320 },
    };

    expect(movementInputs(state, 2, { lane: 2, targetSpeed: 700 })).toEqual({
      left: false,
      right: true,
      accel: true,
      brake: false,
      turbo: false,
    });
  });

  it("brakes when target speed is much lower", () => {
    const state = {
      ...racingState(),
      p2: { ...racingState().p2, lane: 1, targetLane: 1, speed: 760 },
    };

    expect(movementInputs(state, 2, { lane: 1, targetSpeed: 420 })).toMatchObject({
      accel: false,
      brake: true,
    });
  });

  it("uses turbo on a clear lane while chasing", () => {
    const state = chasingState();

    expect(shouldUseTurbo(state, 2, { lane: 1 }, ENDURO_AI_DIFFICULTIES.hard)).toBe(true);
  });

  it("pulses turbo and then respects AI cooldown", () => {
    const ai = createHexEnduroAI({ difficulty: "hard", rng: () => 0.5 });
    const state = chasingState();

    expect(ai.nextInputs({ state, player: 2 })).toMatchObject({ turbo: true });
    expect(ai.nextInputs({ state, player: 2 })).toMatchObject({ turbo: false });
  });

  it("does not use turbo with low fuel or active boost", () => {
    const lowFuel = chasingState({ fuel: 100 });
    const boosting = chasingState({ boost: 20 });

    expect(shouldUseTurbo(lowFuel, 2, { lane: 1 }, ENDURO_AI_DIFFICULTIES.hard)).toBe(false);
    expect(shouldUseTurbo(boosting, 2, { lane: 1 }, ENDURO_AI_DIFFICULTIES.hard)).toBe(false);
  });

  it("plans from the road as it was `reaction` frames ago", () => {
    const { reaction, interval } = ENDURO_AI_DIFFICULTIES.hard;
    const ai = createHexEnduroAI({ difficulty: "hard", rng: () => 0.99 });
    const base = racingState();
    const clear = {
      ...base,
      p1: { ...base.p1, lane: 2, targetLane: 2, zOffset: -900 },
      p2: { ...base.p2, lane: 0, targetLane: 0 },
    };
    const blocked = { ...clear, aiCars: [{ lane: 0, zPos: 200, speed: 30, type: 0 }] };

    for (let frame = 0; frame < 10; frame++) ai.nextInputs({ state: clear, player: 2 });
    const unseen = [];
    for (let frame = 0; frame < reaction; frame++) {
      unseen.push(ai.nextInputs({ state: blocked, player: 2 }).right);
    }
    const seen = [];
    for (let frame = 0; frame < interval; frame++) {
      seen.push(ai.nextInputs({ state: blocked, player: 2 }).right);
    }

    expect(unseen).not.toContain(true);
    expect(seen).toContain(true);
  });

  it("takes one draw for each chance to draft, slip a lane or fire turbo", () => {
    // The first look's three draws all say no; every later draw would say yes.
    const draws = [0.99, 0.99, 0.99];
    const ai = createHexEnduroAI({ difficulty: "hard", rng: () => draws.shift() ?? 0 });
    const state = chasingState();
    const inputs = [];
    for (let frame = 0; frame < ENDURO_AI_DIFFICULTIES.hard.interval * 3; frame++) {
      inputs.push(ai.nextInputs({ state, player: 2 }));
    }

    expect(inputs.some((input) => input.left || input.right || input.turbo)).toBe(false);

    ai.forget();
    expect(ai.nextInputs({ state, player: 2 }).left).toBe(true);
  });

  it("does not reach for a fuel station hidden in the fog", () => {
    const base = racingState();
    const day = {
      ...base,
      p2: { ...base.p2, fuel: 100 },
      fuelStations: [{ lane: 2, zPos: 1000 }],
    };
    const fog = { ...day, weather: WEATHER.FOG };

    expect(nearestFuelStation(day, 2, ENDURO_AI_DIFFICULTIES.hard)).toMatchObject({ lane: 2 });
    expect(nearestFuelStation(fog, 2, ENDURO_AI_DIFFICULTIES.hard)).toBeNull();
  });

  it("tunes its settings to the race's length", () => {
    const { hard, normal } = ENDURO_AI_DIFFICULTIES;

    expect(enduroAIConfig("hard", GAME_MODE.NIGHT_RACE)).toBe(hard);
    expect(enduroAIConfig("easy", GAME_MODE.SPRINT)).toBe(ENDURO_AI_DIFFICULTIES.easy);
    expect(enduroAIConfig("hard", GAME_MODE.CLASSIC_DUEL).reaction).toBeGreaterThan(hard.reaction);
    expect(enduroAIConfig("normal", GAME_MODE.CLASSIC_DUEL).reaction).toBeGreaterThan(
      normal.reaction,
    );
    expect(enduroAIConfig("hard", GAME_MODE.SPRINT).reaction).toBeLessThan(hard.reaction);
  });
});

// Each setting, and which way a stronger driver has it.
const STRONGER = {
  interval: "down",
  reaction: "down",
  laneMistake: "down",
  threatZ: "up",
  fuelAt: "up",
  fuelZ: "up",
  targetSpeed: "up",
  brakeSpeed: "up",
  turboOdds: "up",
  turboCd: "down",
  slipstreamBias: "up",
};

for (const [name, mode] of Object.entries(GAME_MODE)) {
  const table = Object.fromEntries(
    ["easy", "normal", "hard"].map((difficulty) => [difficulty, enduroAIConfig(difficulty, mode)]),
  );
  describeStrengthOrder(`Hex Enduro AI, ${name}`, table, STRONGER);
}
