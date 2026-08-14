import { describe, expect, it } from "vitest";
import {
  createTennisAI,
  normalizeTennisAIDifficulty,
  predictTennisIntercept,
  recoveryPosition,
  servingReadyPosition,
} from "../../../../js/lib/games/hex_tennis/ai.js";
import { GAME_MODE, PHASE } from "../../../../js/lib/games/hex_tennis/protocol.js";
import { createInitialState } from "../../../../js/lib/games/hex_tennis/physics.js";

function tennisState() {
  const state = createInitialState(GAME_MODE.CLASSIC);
  state.phase = PHASE.RALLY;
  return state;
}

describe("TennisAI", () => {
  it("normalizes invalid difficulties to normal", () => {
    expect(normalizeTennisAIDifficulty("easy")).toBe("easy");
    expect(normalizeTennisAIDifficulty("HARD")).toBe("hard");
    expect(normalizeTennisAIDifficulty("legendary")).toBe("normal");
    expect(normalizeTennisAIDifficulty(null)).toBe("normal");
  });

  it("stays neutral outside the serving and rally phases", () => {
    const ai = createTennisAI({ difficulty: "hard" });
    const state = createInitialState(GAME_MODE.CLASSIC);

    expect(ai.nextInputs({ state, player: 2 })).toEqual({
      up: false,
      down: false,
      left: false,
      right: false,
      serve: false,
    });
  });

  it("predicts the incoming ball near the AI hit zone", () => {
    const state = tennisState();
    state.p2y = 90;
    state.ball = { x: 260, y: 300, vx: 1, vy: -4, speed: 5, height: 0.3, heightVel: 0 };

    const predicted = predictTennisIntercept(state, 2, 0);

    expect(predicted.x).toBeCloseTo(310.25, 1);
    expect(predicted.y).toBeCloseTo(99, 1);
  });

  it("does not predict a ball moving away from the AI", () => {
    const state = tennisState();
    state.ball = { x: 260, y: 180, vx: 1, vy: 4, speed: 5, height: 0.3, heightVel: 0 };

    expect(predictTennisIntercept(state, 2)).toBeNull();
  });

  it("moves toward an incoming ball using the peer input shape", () => {
    const ai = createTennisAI({ difficulty: "hard", rng: () => 0.5 });
    const state = tennisState();
    state.p2x = 320;
    state.p2y = 80;
    state.ball = { x: 220, y: 220, vx: 0, vy: -5, speed: 5, height: 0.3, heightVel: 0 };

    const inputs = ai.nextInputs({ state, player: 2 });

    expect(inputs.left).toBe(true);
    expect(inputs.down).toBe(true);
    expect(inputs.right).toBe(false);
    expect(inputs.serve).toBe(false);
  });

  it("recovers toward center court when the ball is going away", () => {
    const state = tennisState();
    state.ball = { x: 500, y: 260, vx: 0, vy: 4, speed: 5, height: 0.3, heightVel: 0 };

    expect(recoveryPosition(state, 2, 0.5)).toMatchObject({ x: 410, y: 151 });
  });

  it("serves after a human-like delay when the AI is server", () => {
    const ai = createTennisAI({ difficulty: "hard", rng: () => 0 });
    const state = createInitialState(GAME_MODE.CLASSIC);
    state.phase = PHASE.SERVING;
    state.server = 2;

    let inputs = ai.nextInputs({ state, player: 2 });
    expect(inputs.serve).toBe(false);

    for (let i = 0; i < 12; i++) {
      inputs = ai.nextInputs({ state, player: 2 });
    }

    expect(inputs.serve).toBe(true);
    expect(ai.nextInputs({ state, player: 2 }).serve).toBe(false);
  });

  it("moves into the receiving ready position while waiting for the player serve", () => {
    const ai = createTennisAI({ difficulty: "normal" });
    const state = createInitialState(GAME_MODE.CLASSIC);
    state.phase = PHASE.SERVING;
    state.server = 1;
    state.p2x = 320;
    state.p2y = 70;

    const target = servingReadyPosition(state, 2);
    const inputs = ai.nextInputs({ state, player: 2 });

    expect(target.x).toBeGreaterThan(state.p2x);
    expect(inputs.right).toBe(true);
    expect(inputs.serve).toBe(false);
  });
});
