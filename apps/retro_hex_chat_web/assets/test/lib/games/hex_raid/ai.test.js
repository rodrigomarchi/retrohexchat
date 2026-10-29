import { describe, it, expect } from "vitest";
import {
  RAID_AI_DIFFICULTIES,
  chooseRaidTarget,
  createHexRaidAI,
  movementInputs,
  nearestFuelTarget,
  nearestThreat,
  normalizeRaidAIDifficulty,
  noticedMines,
  shouldDeployMine,
  shouldFire,
} from "../../../../js/lib/games/hex_raid/ai.js";
import { createPerThing } from "../../../../js/lib/games/core/ai.js";
import { describeStrengthOrder } from "../../../support/games/strength_order.js";
import { ENEMY_TYPE, GAME_MODE, PHASE } from "../../../../js/lib/games/hex_raid/protocol.js";
import {
  MISSILE_RADIUS,
  SPEED_BASE,
  createInitialState,
} from "../../../../js/lib/games/hex_raid/physics.js";
import { itSetsDifficulty } from "../../../support/games/ai_tests.js";

function flyingState(mode = GAME_MODE.RIVER_DUEL) {
  return {
    ...createInitialState(mode, 12345),
    phase: PHASE.FLYING,
  };
}

/** Jet 2 with a boat about straight ahead of it, `overrides` on top. */
function boatAhead(overrides = {}) {
  return {
    ...flyingState(),
    jet2X: 320,
    enemies: [{ type: ENEMY_TYPE.BOAT, x: 322, y: 260, alive: true }],
    enemyCount: 1,
    ...overrides,
  };
}

describe("HexRaidAI", () => {
  it("normalizes difficulty names", () => {
    expect(normalizeRaidAIDifficulty("easy")).toBe("easy");
    expect(normalizeRaidAIDifficulty("HARD")).toBe("hard");
    expect(normalizeRaidAIDifficulty("legendary")).toBe("normal");
    expect(normalizeRaidAIDifficulty(null)).toBe("normal");
  });

  itSetsDifficulty(createHexRaidAI);

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
    const state = boatAhead();

    expect(shouldFire(state, 2, RAID_AI_DIFFICULTIES.hard)).toBe(true);
    expect(ai.nextInputs({ state, player: 2 })).toMatchObject({ fire: true });
    expect(ai.nextInputs({ state, player: 2 })).toMatchObject({ fire: false });
  });

  it("does not fire while the missile is active", () => {
    const state = boatAhead({ m2Active: true });

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

  it("drops a mine only when the rival flies close to its lane", () => {
    const config = RAID_AI_DIFFICULTIES.hard;
    const near = { ...flyingState(), jet1X: 320 + config.mineX - 1, jet2X: 320 };
    const far = { ...near, jet1X: 320 + config.mineX + 1 };
    const shielded = { ...near, jet1Invuln: true };

    expect(shouldDeployMine(near, 2, config)).toBe(true);
    expect(shouldDeployMine(far, 2, config)).toBe(false);
    expect(shouldDeployMine(shielded, 2, config)).toBe(false);
  });

  it("lets a missed chance to mine go until its cooldown is over", () => {
    const ai = createHexRaidAI({ difficulty: "easy", rng: () => 0.9 });
    const state = { ...flyingState(), jet1X: 320, jet2X: 324 };

    expect(ai.nextInputs({ state, player: 2 })).toMatchObject({ mine: false });
    expect(ai.mineCooldown).toBe(RAID_AI_DIFFICULTIES.easy.mineCd);
  });

  it("notices each rival mine or not once, and keeps that while it is in play", () => {
    const noticed = createPerThing();
    const draws = [false, true];
    const notices = () => draws.shift();
    const sight = {
      ...flyingState(),
      mines: [
        { id: 7, x: 320, y: 360, owner: 1, active: true },
        { id: 8, x: 200, y: 360, owner: 2, active: true },
      ],
    };

    expect(noticedMines(sight, 2, noticed, notices).mines.map((m) => m.id)).toEqual([8]);
    expect(noticedMines(sight, 2, noticed, notices).mines.map((m) => m.id)).toEqual([8]);
    expect(nearestThreat(noticedMines(sight, 2, noticed, notices), 2)).toBeNull();
  });

  it("dodges a rival mine it noticed", () => {
    const ai = createHexRaidAI({ difficulty: "hard", rng: () => 0.5 });
    const mine = { id: 1, x: 322, y: 360, owner: 1, active: true };
    const state = { ...flyingState(), jet1X: 100, jet2X: 320, mines: [mine], mineCount: 1 };

    for (let i = 0; i < 20; i++) ai.nextInputs({ state, player: 2 });

    expect(ai._target.kind).toBe("dodge");
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

  it("sees the river a reaction late", () => {
    const ai = createHexRaidAI({ difficulty: "normal", rng: () => 0.5 });
    const { reaction } = RAID_AI_DIFFICULTIES.normal;
    const calm = { ...flyingState(), jet2X: 320 };
    const boat = { type: ENEMY_TYPE.BOAT, x: 318, y: 330, alive: true, vx: 0 };
    const danger = { ...calm, enemies: [boat], enemyCount: 1 };

    for (let i = 0; i < 20; i++) ai.nextInputs({ state: calm, player: 2 });
    for (let i = 0; i < reaction; i++) {
      ai.nextInputs({ state: danger, player: 2 });
      expect(ai._target.kind).toBe("cruise");
    }

    for (let i = 0; i < 20; i++) ai.nextInputs({ state: danger, player: 2 });
    expect(ai._target.kind).toBe("dodge");
  });

  it("keeps one aim error for as long as it chases the same target", () => {
    const draws = [0.9, 0.9, 0.1, 0.1];
    const ai = createHexRaidAI({ difficulty: "easy", rng: () => draws.shift() ?? 0.5 });
    const state = { ...flyingState(), jet2X: 320 };
    const { interval, error } = RAID_AI_DIFFICULTIES.easy;

    ai.nextInputs({ state, player: 2 });
    const first = ai._target.x - chooseRaidTarget(state, 2, RAID_AI_DIFFICULTIES.easy).x;
    for (let i = 0; i < interval * 3; i++) ai.nextInputs({ state, player: 2 });
    const later = ai._target.x - chooseRaidTarget(state, 2, RAID_AI_DIFFICULTIES.easy).x;

    expect(first).toBeCloseTo(0.4 * error * 2);
    expect(later).toBeCloseTo(first);
  });

  it("draws a new aim error for a new target, even of the same kind", () => {
    let n = 0;
    const ai = createHexRaidAI({ difficulty: "normal", rng: () => (n++ * 0.37) % 1 });
    const config = RAID_AI_DIFFICULTIES.normal;
    const boat = (id) => ({
      ...flyingState(),
      jet2X: 320,
      enemies: [{ id, type: ENEMY_TYPE.BOAT, x: 200, y: 150, alive: true, vx: 0 }],
      enemyCount: 1,
    });
    const missOn = (state) => ai._target.x - chooseRaidTarget(state, 2, config).x;
    const fly = (state) => {
      for (let i = 0; i < config.reaction + config.interval * 2; i++) {
        ai.nextInputs({ state, player: 2 });
      }
    };

    fly(boat(7));
    expect(ai._target).toMatchObject({ kind: "attack", key: "enemy:7" });
    const first = missOn(boat(7));
    fly(boat(7));
    expect(missOn(boat(7))).toBeCloseTo(first);

    fly(boat(8));
    expect(ai._target).toMatchObject({ kind: "attack", key: "enemy:8" });
    expect(missOn(boat(8))).not.toBeCloseTo(first);
  });

  it("keeps a missed spot inside the river", () => {
    const state = {
      ...flyingState(),
      jet2X: 320,
      enemies: [{ id: 1, type: ENEMY_TYPE.BOAT, x: 200, y: 150, alive: true, vx: 0 }],
      enemyCount: 1,
    };
    const config = RAID_AI_DIFFICULTIES.normal;
    const farLeft = chooseRaidTarget(state, 2, config, () => -1000);

    expect(farLeft.x).toBe(chooseRaidTarget(state, 2, config, () => -5000).x);
    expect(farLeft.x).toBeGreaterThan(chooseRaidTarget(state, 2, config).x - 1000);
  });

  it("draws once per chance to fire, then waits out its cooldown", () => {
    const ai = createHexRaidAI({ difficulty: "easy", rng: () => 0.99 });
    const state = boatAhead();

    expect(ai.nextInputs({ state, player: 2 })).toMatchObject({ fire: false });
    expect(ai.fireCooldown).toBe(RAID_AI_DIFFICULTIES.easy.fireCd);
  });

  it("forgets a match's memories for the next one", () => {
    const ai = createHexRaidAI({ difficulty: "easy", rng: () => 0.99 });
    ai.nextInputs({ state: boatAhead(), player: 2 });

    ai.forget();

    expect(ai.fireCooldown).toBe(0);
    expect(ai._target).toBeNull();
  });

  it("fires on hard only inside the missile's hit window", () => {
    const hitWindow = MISSILE_RADIUS + 8;
    const config = RAID_AI_DIFFICULTIES.hard;
    const at = (x) => ({
      ...flyingState(),
      jet2X: 320,
      enemies: [{ type: ENEMY_TYPE.JET, x, y: 200, alive: true, vx: 0 }],
      enemyCount: 1,
    });

    expect(config.fireX).toBeLessThan(hitWindow);
    expect(shouldFire(at(320 + config.fireX), 2, config)).toBe(true);
    expect(shouldFire(at(320 + hitWindow), 2, config)).toBe(false);
  });

  it("leads a moving enemy on hard, not on easy", () => {
    const state = {
      ...flyingState(),
      jet2X: 320,
      enemies: [{ type: ENEMY_TYPE.HELI, x: 320, y: 120, alive: true, vx: 4 }],
      enemyCount: 1,
    };

    expect(chooseRaidTarget(state, 2, RAID_AI_DIFFICULTIES.hard)).toMatchObject({ kind: "attack" });
    expect(chooseRaidTarget(state, 2, RAID_AI_DIFFICULTIES.hard).x).toBeGreaterThan(330);
    expect(
      chooseRaidTarget({ ...state, jet2X: 320 }, 2, { ...RAID_AI_DIFFICULTIES.easy, fireY: 400 }).x,
    ).toBe(320);
  });

  it("ignores what has not come down onto the screen yet", () => {
    const state = {
      ...flyingState(),
      jet2X: 320,
      enemies: [{ type: ENEMY_TYPE.BOAT, x: 320, y: -15, alive: true, vx: 0 }],
      enemyCount: 1,
      fuels: [{ x: 320, y: -10, available: true }],
      fuelCount: 1,
      jet2Fuel: 50,
    };
    const config = { ...RAID_AI_DIFFICULTIES.hard, threatY: 480, fireY: 480, fuelY: 480 };

    expect(nearestThreat(state, 2, config)).toBeNull();
    expect(shouldFire(state, 2, config)).toBe(false);
    expect(nearestFuelTarget(state, 2, config)).toBeNull();
  });
});

describeStrengthOrder("Hex Raid AI", RAID_AI_DIFFICULTIES, {
  reaction: "down",
  interval: "down",
  error: "down",
  deadzone: "down",
  threatY: "up",
  dodgeX: "up",
  fuelAt: "up",
  fuelY: "up",
  fireY: "up",
  fireX: "down",
  fireOdds: "up",
  fireCd: "down",
  mineOdds: "up",
  mineCd: "down",
  mineX: "down",
  mineNotice: "up",
  lead: "up",
  cruise: "up",
});
