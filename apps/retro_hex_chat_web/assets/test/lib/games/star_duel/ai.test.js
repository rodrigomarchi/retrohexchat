import { describe, expect, it } from "vitest";
import {
  STAR_DUEL_AI_DIFFICULTIES,
  createStarDuelAI,
  incomingMissileThreat,
  lineOfFireBlockedByAsteroid,
  normalizeStarDuelAIDifficulty,
  toroidalVector,
} from "../../../../js/lib/games/star_duel/ai.js";
import { GAME_MODE, PHASE } from "../../../../js/lib/games/star_duel/protocol.js";
import {
  createInitialState,
  STAR_DANGER_RADIUS,
  STAR_X,
  STAR_Y,
} from "../../../../js/lib/games/star_duel/physics.js";
import {
  expectOneFramePress,
  expectPassedOpeningWaits,
  scriptedRng,
} from "../../../support/games/ai_tests.js";
import { describeStrengthOrder } from "../../../support/games/strength_order.js";

function playingState(mode = GAME_MODE.OPEN_SPACE) {
  const state = createInitialState(mode, 1234);
  state.phase = PHASE.PLAYING;
  state.ship1 = { ...state.ship1, invulnerable: false, invulnTimer: 0 };
  state.ship2 = { ...state.ship2, invulnerable: false, invulnTimer: 0 };
  return state;
}

/**
 * Player two turned to face player one across the field; each ship takes
 * its own `overrides`.
 */
function facing(ship1 = {}, ship2 = {}, mode = GAME_MODE.OPEN_SPACE) {
  const state = playingState(mode);
  return {
    ...state,
    ship1: { ...state.ship1, ...ship1 },
    ship2: { ...state.ship2, rotation: Math.PI, ...ship2 },
  };
}

/** Player one shielded, 100 px in front of player two, out of its thrusting range. */
function closeIn() {
  const state = playingState();
  return facing({ x: state.ship2.x - 100, invulnerable: true });
}

/** `state` with player one's missile `distance` px short of player two, `age` frames old. */
function withMissile(state, distance, age) {
  const { x, y } = state.ship2;
  return { ...state, missiles: [{ x: x - distance, y, vx: 8, vy: 0, owner: 1, age }] };
}

function look(ai, state) {
  return ai.nextInputs({ state, player: 2 });
}

describe("StarDuelAI", () => {
  it("normalizes invalid difficulties to normal", () => {
    expect(normalizeStarDuelAIDifficulty("easy")).toBe("easy");
    expect(normalizeStarDuelAIDifficulty("HARD")).toBe("hard");
    expect(normalizeStarDuelAIDifficulty("legendary")).toBe("normal");
    expect(normalizeStarDuelAIDifficulty(null)).toBe("normal");
  });

  it("stays neutral outside the playing phase", () => {
    const ai = createStarDuelAI({ difficulty: "hard" });
    const state = createInitialState(GAME_MODE.OPEN_SPACE, 1234);

    expect(ai.nextInputs({ state, player: 2 })).toEqual({
      rotateLeft: false,
      rotateRight: false,
      thrust: false,
      fire: false,
      warp: false,
    });
  });

  it("uses toroidal vectors across arena edges", () => {
    expect(toroidalVector(630, 240, 10, 240)).toMatchObject({
      dx: 20,
      dy: 0,
      distance: 20,
    });
  });

  it.each([
    ["right", 120],
    ["left", 360],
  ])("rotates %s toward a rival off its lane", (side, y) => {
    const ai = createStarDuelAI({ difficulty: "hard" });
    const inputs = look(ai, facing({ y }));

    expect(inputs.rotateRight).toBe(side === "right");
    expect(inputs.rotateLeft).toBe(side === "left");
  });

  it("fires a one-frame missile when aligned with a vulnerable opponent", () => {
    const ai = createStarDuelAI({ difficulty: "hard", rng: () => 0 });
    const state = facing();

    expectOneFramePress(() => look(ai, state).fire);
  });

  it("does not fire at an invulnerable opponent", () => {
    const ai = createStarDuelAI({ difficulty: "hard", rng: () => 0 });

    expect(look(ai, facing({ invulnerable: true })).fire).toBe(false);
  });

  it("does not fire through an asteroid in Debris Field", () => {
    const ai = createStarDuelAI({ difficulty: "hard", rng: () => 0 });
    const state = facing({ x: 160, y: 240 }, { x: 480, y: 240 }, GAME_MODE.DEBRIS_FIELD);
    state.asteroids = [{ x: 320, y: 240, radius: 34, vertices: [] }];

    expect(lineOfFireBlockedByAsteroid(state, 2)).toBe(true);
    expect(look(ai, state).fire).toBe(false);
  });

  it("thrusts away from the star when aligned in Gravity Well", () => {
    const ai = createStarDuelAI({ difficulty: "hard" });
    const nearStar = { x: STAR_X + STAR_DANGER_RADIUS + 10, y: STAR_Y, rotation: 0 };

    const inputs = look(ai, facing({}, nearStar, GAME_MODE.GRAVITY_WELL));

    expect(inputs.thrust).toBe(true);
    expect(inputs.fire).toBe(false);
  });

  it("dodges an incoming missile instead of firing", () => {
    const ai = createStarDuelAI({ difficulty: "hard", rng: () => 0 });
    const state = withMissile(playingState(), 70, 20);

    const inputs = look(ai, state);

    expect(incomingMissileThreat(state, 2)).not.toBeNull();
    expect(inputs.fire).toBe(false);
    expect(inputs.thrust).toBe(true);
    expect(inputs.rotateLeft || inputs.rotateRight).toBe(true);
  });

  it("does not see a missile until it is reactionFrames old, and dodges it after", () => {
    const ai = createStarDuelAI({ difficulty: "hard", rng: () => 0 });
    const state = closeIn();
    const reaction = STAR_DUEL_AI_DIFFICULTIES.hard.reactionFrames;

    const young = look(ai, withMissile(state, 60, 0));
    for (let age = 1; age < reaction; age++) look(ai, withMissile(state, 60, age));
    const old = look(ai, withMissile(state, 60, reaction));

    expect(young.thrust).toBe(false);
    expect(old.thrust).toBe(true);
  });

  it("decides once per missile whether to dodge it", () => {
    const ai = createStarDuelAI({ difficulty: "hard", rng: scriptedRng([0.99, 0.99], 0) });
    const state = closeIn();

    for (let age = 0; age < 12; age++) {
      expect(look(ai, withMissile(state, 60, age)).thrust).toBe(false);
    }
  });

  it("keeps one aim error for a shot instead of drawing a fresh one each frame", () => {
    const draws = [0.999, 0.001];
    let next = 0;
    const ai = createStarDuelAI({ difficulty: "hard", rng: () => draws[next++ % 2] });
    const state = facing({ invulnerable: true });

    const turns = Array.from({ length: 10 }, () => look(ai, state).rotateRight);

    expect(turns.every((right) => right === turns[0])).toBe(true);
    expect(next).toBe(1);
  });

  it("rolls the fire odds once per opening and waits out the cooldown after passing", () => {
    const ai = createStarDuelAI({ difficulty: "normal", rng: scriptedRng([0.5, 0.99], 0.5) });
    const state = facing();

    expectPassedOpeningWaits(
      () => look(ai, state).fire,
      STAR_DUEL_AI_DIFFICULTIES.normal.fireCooldownFrames,
    );
  });

  it("leads a moving rival by its distance, not by a fixed time", () => {
    // A rival 3 px/frame across the line, a missile at 8 px/frame: leading by
    // the whole flight puts the aim the same atan(3/8) off at any distance.
    const leadAngle = Math.atan2(3, 8);
    const turnsAt = (distance) => {
      const ai = createStarDuelAI({ difficulty: "hard", rng: () => 0.5 });
      const rival = { x: 480 - distance, y: 240, vx: 0, vy: 3, invulnerable: true };
      const inputs = look(ai, facing(rival, { x: 480, y: 240, rotation: Math.PI - leadAngle }));
      return inputs.rotateLeft || inputs.rotateRight;
    };

    expect(turnsAt(80)).toBe(false);
    expect(turnsAt(320)).toBe(false);
  });

  it("never turns to a stop outside the angle it fires within", () => {
    for (const config of Object.values(STAR_DUEL_AI_DIFFICULTIES)) {
      expect(config.turnDeadzone).toBeLessThanOrEqual(config.aimTolerance);
    }
  });
});

describe("StarDuelAI between rounds", () => {
  it("forgets where the rival was once a new round starts", () => {
    const turnsLeft = (forget) => {
      const ai = createStarDuelAI({ difficulty: "hard", rng: () => 0.5 });
      for (let frame = 0; frame < 10; frame++) look(ai, facing({ y: 120, invulnerable: true }));
      if (forget) ai.forget();
      return look(ai, facing({ y: 360, invulnerable: true })).rotateLeft;
    };

    expect(turnsLeft(false)).toBe(false);
    expect(turnsLeft(true)).toBe(true);
  });
});

describeStrengthOrder("Star Duel", STAR_DUEL_AI_DIFFICULTIES, {
  reactionFrames: "down",
  turnDeadzone: "down",
  aimTolerance: "down",
  aimErrorAngle: "down",
  thrustAngle: "up",
  evasionThrustAngle: "up",
  standoffDistance: "down",
  leadSkill: "up",
  fireCooldownFrames: "down",
  fireChance: "up",
  dodgeChance: "up",
  threatFrames: "up",
  threatRadius: "up",
  missileAvoidMargin: "up",
  starAvoidRadius: "up",
  asteroidAvoidMargin: "up",
  asteroidShotMargin: "up",
  emergencyWarp: "up",
});
