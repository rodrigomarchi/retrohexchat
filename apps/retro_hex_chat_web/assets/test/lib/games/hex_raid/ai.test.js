import { describe, it, expect } from "vitest";
import {
  RAID_AI_DIFFICULTIES,
  chooseRaidTarget,
  createHexRaidAI,
  movementInputs,
  nearestFuelTarget,
  nearestThreat,
  normalizeRaidAIDifficulty,
  shouldDeployMine,
  shouldFire,
} from "../../../../js/lib/games/hex_raid/ai.js";
import { ENEMY_TYPE, GAME_MODE, PHASE } from "../../../../js/lib/games/hex_raid/protocol.js";
import { SPEED_BASE, createInitialState } from "../../../../js/lib/games/hex_raid/physics.js";

function flyingState(mode = GAME_MODE.RIVER_DUEL) {
  return {
    ...createInitialState(mode, 12345),
    phase: PHASE.FLYING,
  };
}

describe("HexRaidAI", () => {
  it("normalizes difficulty names", () => {
    expect(normalizeRaidAIDifficulty("easy")).toBe("easy");
    expect(normalizeRaidAIDifficulty("HARD")).toBe("hard");
    expect(normalizeRaidAIDifficulty("legendary")).toBe("normal");
    expect(normalizeRaidAIDifficulty(null)).toBe("normal");
  });

  it("updates difficulty through the public setter", () => {
    const ai = createHexRaidAI({ difficulty: "easy" });

    ai.setDifficulty("hard");

    expect(ai.difficulty).toBe("hard");
  });

  it("returns neutral inputs outside flying phase", () => {
    const ai = createHexRaidAI({ difficulty: "hard", rng: () => 0.5 });

    expect(ai.nextInputs({ state: createInitialState(GAME_MODE.RIVER_DUEL, 12345) })).toEqual({
      left: false,
      right: false,
      accel: false,
      decel: false,
      fire: false,
      mine: false,
    });
  });

  it("seeks fuel when the AI jet is low on fuel", () => {
    const state = {
      ...flyingState(),
      jet2Fuel: 70,
      jet2X: 320,
      fuels: [{ x: 380, y: 330, available: true }],
      fuelCount: 1,
    };

    const fuel = nearestFuelTarget(state, 2, RAID_AI_DIFFICULTIES.hard);
    const target = chooseRaidTarget(state, 2, RAID_AI_DIFFICULTIES.hard);

    expect(fuel).toMatchObject({ x: 380, y: 330 });
    expect(target.x).toBeGreaterThan(320);
  });

  it("prioritizes dodging a threat in the current lane", () => {
    const state = {
      ...flyingState(),
      jet2X: 320,
      enemies: [{ type: ENEMY_TYPE.BOAT, x: 318, y: 310, alive: true }],
      enemyCount: 1,
    };

    const threat = nearestThreat(state, 2, RAID_AI_DIFFICULTIES.hard);
    const target = chooseRaidTarget(state, 2, RAID_AI_DIFFICULTIES.hard);

    expect(threat).toMatchObject({ x: 318, y: 310 });
    expect(target.x).toBeGreaterThan(320);
  });

  it("moves toward target position and speed", () => {
    const state = {
      ...flyingState(),
      jet2X: 300,
      jet2Speed: SPEED_BASE,
    };

    expect(movementInputs(state, 2, { x: 360, targetSpeed: 4 }, 6)).toEqual({
      left: false,
      right: true,
      accel: true,
      decel: false,
      fire: false,
      mine: false,
    });
  });

  it("fires when aligned with an enemy and respects AI cooldown", () => {
    const ai = createHexRaidAI({ difficulty: "hard", rng: () => 0.5 });
    const state = {
      ...flyingState(),
      jet2X: 320,
      enemies: [{ type: ENEMY_TYPE.BOAT, x: 322, y: 260, alive: true }],
      enemyCount: 1,
    };

    expect(shouldFire(state, 2, RAID_AI_DIFFICULTIES.hard)).toBe(true);
    expect(ai.nextInputs({ state, player: 2 })).toMatchObject({ fire: true });
    expect(ai.nextInputs({ state, player: 2 })).toMatchObject({ fire: false });
  });

  it("does not fire while the missile is active", () => {
    const state = {
      ...flyingState(),
      jet2X: 320,
      m2Active: true,
      enemies: [{ type: ENEMY_TYPE.BOAT, x: 322, y: 260, alive: true }],
      enemyCount: 1,
    };

    expect(shouldFire(state, 2, RAID_AI_DIFFICULTIES.hard)).toBe(false);
  });

  it("deploys mines only in mine-enabled modes", () => {
    const duel = {
      ...flyingState(),
      jet1X: 320,
      jet1Y: 430,
      jet2X: 324,
      jet2Y: 420,
    };
    const pacifist = { ...duel, mode: GAME_MODE.PACIFIST };

    expect(shouldDeployMine(duel, 2, RAID_AI_DIFFICULTIES.hard)).toBe(true);
    expect(shouldDeployMine(pacifist, 2, RAID_AI_DIFFICULTIES.hard)).toBe(false);
  });

  it("pulses mine input and then respects AI cooldown", () => {
    const ai = createHexRaidAI({ difficulty: "hard", rng: () => 0.5 });
    const state = {
      ...flyingState(),
      jet1X: 320,
      jet1Y: 430,
      jet2X: 324,
      jet2Y: 420,
    };

    expect(ai.nextInputs({ state, player: 2 })).toMatchObject({ mine: true });
    expect(ai.nextInputs({ state, player: 2 })).toMatchObject({ mine: false });
  });
});
