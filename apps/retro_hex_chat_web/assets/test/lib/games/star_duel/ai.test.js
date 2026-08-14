import { describe, expect, it } from "vitest";
import {
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

function playingState(mode = GAME_MODE.OPEN_SPACE) {
  const state = createInitialState(mode, 1234);
  state.phase = PHASE.PLAYING;
  state.ship1 = { ...state.ship1, invulnerable: false, invulnTimer: 0 };
  state.ship2 = { ...state.ship2, invulnerable: false, invulnTimer: 0 };
  return state;
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

  it("rotates right toward a target above the opponent lane", () => {
    const ai = createStarDuelAI({ difficulty: "hard" });
    const state = playingState();
    state.ship1 = { ...state.ship1, y: 120 };
    state.ship2 = { ...state.ship2, rotation: Math.PI };

    const inputs = ai.nextInputs({ state, player: 2 });

    expect(inputs.rotateRight).toBe(true);
    expect(inputs.rotateLeft).toBe(false);
  });

  it("rotates left toward a target below the opponent lane", () => {
    const ai = createStarDuelAI({ difficulty: "hard" });
    const state = playingState();
    state.ship1 = { ...state.ship1, y: 360 };
    state.ship2 = { ...state.ship2, rotation: Math.PI };

    const inputs = ai.nextInputs({ state, player: 2 });

    expect(inputs.rotateLeft).toBe(true);
    expect(inputs.rotateRight).toBe(false);
  });

  it("fires a one-frame missile when aligned with a vulnerable opponent", () => {
    const ai = createStarDuelAI({ difficulty: "hard", rng: () => 0 });
    const state = playingState();
    state.ship2 = { ...state.ship2, rotation: Math.PI };

    const first = ai.nextInputs({ state, player: 2 });
    const second = ai.nextInputs({ state, player: 2 });

    expect(first.fire).toBe(true);
    expect(second.fire).toBe(false);
  });

  it("does not fire at an invulnerable opponent", () => {
    const ai = createStarDuelAI({ difficulty: "hard", rng: () => 0 });
    const state = playingState();
    state.ship1 = { ...state.ship1, invulnerable: true };
    state.ship2 = { ...state.ship2, rotation: Math.PI };

    expect(ai.nextInputs({ state, player: 2 }).fire).toBe(false);
  });

  it("does not fire through an asteroid in Debris Field", () => {
    const ai = createStarDuelAI({ difficulty: "hard", rng: () => 0 });
    const state = playingState(GAME_MODE.DEBRIS_FIELD);
    state.ship1 = { ...state.ship1, x: 160, y: 240 };
    state.ship2 = { ...state.ship2, x: 480, y: 240, rotation: Math.PI };
    state.asteroids = [{ x: 320, y: 240, radius: 34, vertices: [] }];

    expect(lineOfFireBlockedByAsteroid(state, 2)).toBe(true);
    expect(ai.nextInputs({ state, player: 2 }).fire).toBe(false);
  });

  it("thrusts away from the star when aligned in Gravity Well", () => {
    const ai = createStarDuelAI({ difficulty: "hard" });
    const state = playingState(GAME_MODE.GRAVITY_WELL);
    state.ship2 = {
      ...state.ship2,
      x: STAR_X + STAR_DANGER_RADIUS + 10,
      y: STAR_Y,
      rotation: 0,
    };

    const inputs = ai.nextInputs({ state, player: 2 });

    expect(inputs.thrust).toBe(true);
    expect(inputs.fire).toBe(false);
  });

  it("dodges an incoming missile instead of firing", () => {
    const ai = createStarDuelAI({ difficulty: "hard", rng: () => 1 });
    const state = playingState();
    state.missiles = [{ x: state.ship2.x - 70, y: state.ship2.y, vx: 8, vy: 0, owner: 1, age: 0 }];

    const threat = incomingMissileThreat(state, 2);
    const inputs = ai.nextInputs({ state, player: 2 });

    expect(threat).not.toBeNull();
    expect(inputs.fire).toBe(false);
    expect(inputs.thrust).toBe(true);
    expect(inputs.rotateLeft || inputs.rotateRight).toBe(true);
  });
});
