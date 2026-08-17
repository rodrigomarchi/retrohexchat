import { describe, it, expect } from "vitest";
import {
  ENDURO_AI_DIFFICULTIES,
  chooseEnduroTarget,
  createHexEnduroAI,
  laneRisk,
  movementInputs,
  nearestFuelStation,
  normalizeEnduroAIDifficulty,
  shouldUseTurbo,
} from "../../../../js/lib/games/hex_enduro/ai.js";
import { GAME_MODE, PHASE } from "../../../../js/lib/games/hex_enduro/protocol.js";
import {
  FUEL_MAX,
  SPEED_MAX,
  createInitialState,
} from "../../../../js/lib/games/hex_enduro/physics.js";

function racingState(mode = GAME_MODE.CLASSIC_DUEL) {
  return {
    ...createInitialState(mode, 12345),
    phase: PHASE.RACING,
  };
}

describe("HexEnduroAI", () => {
  it("normalizes difficulty names", () => {
    expect(normalizeEnduroAIDifficulty("easy")).toBe("easy");
    expect(normalizeEnduroAIDifficulty("HARD")).toBe("hard");
    expect(normalizeEnduroAIDifficulty("legendary")).toBe("normal");
    expect(normalizeEnduroAIDifficulty(null)).toBe("normal");
  });

  it("updates difficulty through the public setter", () => {
    const ai = createHexEnduroAI({ difficulty: "easy" });

    ai.setDifficulty("hard");

    expect(ai.difficulty).toBe("hard");
  });

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
    const state = {
      ...racingState(),
      p1: { ...racingState().p1, lane: 0, targetLane: 0, zOffset: 90, speed: 720 },
      p2: {
        ...racingState().p2,
        lane: 1,
        targetLane: 1,
        zOffset: 20,
        speed: SPEED_MAX - 20,
        fuel: FUEL_MAX,
      },
    };

    expect(shouldUseTurbo(state, 2, { lane: 1 }, ENDURO_AI_DIFFICULTIES.hard)).toBe(true);
  });

  it("pulses turbo and then respects AI cooldown", () => {
    const ai = createHexEnduroAI({ difficulty: "hard", rng: () => 0.5 });
    const state = {
      ...racingState(),
      p1: { ...racingState().p1, lane: 0, targetLane: 0, zOffset: 90, speed: 720 },
      p2: {
        ...racingState().p2,
        lane: 1,
        targetLane: 1,
        zOffset: 20,
        speed: SPEED_MAX - 20,
        fuel: FUEL_MAX,
      },
    };

    expect(ai.nextInputs({ state, player: 2 })).toMatchObject({ turbo: true });
    expect(ai.nextInputs({ state, player: 2 })).toMatchObject({ turbo: false });
  });

  it("does not use turbo with low fuel or active boost", () => {
    const lowFuel = {
      ...racingState(),
      p1: { ...racingState().p1, lane: 0, targetLane: 0, zOffset: 90, speed: 720 },
      p2: {
        ...racingState().p2,
        lane: 1,
        targetLane: 1,
        zOffset: 20,
        speed: SPEED_MAX - 20,
        fuel: 100,
      },
    };
    const boosting = { ...lowFuel, p2: { ...lowFuel.p2, fuel: FUEL_MAX, boost: 20 } };

    expect(shouldUseTurbo(lowFuel, 2, { lane: 1 }, ENDURO_AI_DIFFICULTIES.hard)).toBe(false);
    expect(shouldUseTurbo(boosting, 2, { lane: 1 }, ENDURO_AI_DIFFICULTIES.hard)).toBe(false);
  });
});
