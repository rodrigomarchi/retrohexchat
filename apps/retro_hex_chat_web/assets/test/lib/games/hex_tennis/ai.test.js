import { describe, expect, it } from "vitest";
import {
  TENNIS_AI_DIFFICULTIES,
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

    expect(ai.nextInputs({ state, player: 2 })).toMatchObject({
      left: true,
      down: true,
      right: false,
      serve: false,
    });
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

  it("keeps one aim error for a whole approach and draws a new one for the next", () => {
    let draw = 0.9;
    const ai = createTennisAI({ difficulty: "easy", rng: () => draw });
    const { targetErrorPx, decisionInterval } = TENNIS_AI_DIFFICULTIES.easy;
    const state = tennisState();
    state.p2x = 220 + 0.8 * targetErrorPx;
    state.p2y = 80;
    const incoming = { x: 220, y: 220, vx: 0, vy: -5, speed: 5, height: 0.3, heightVel: 0 };
    const away = { ...incoming, vy: 5 };
    const sideways = () => {
      const { left, right } = ai.nextInputs({ state, player: 2 });
      return { left, right };
    };

    state.ball = incoming;
    sideways();
    draw = 0.1;
    for (let frame = 0; frame < decisionInterval * 4; frame++) {
      expect(sideways()).toEqual({ left: false, right: false });
    }

    state.ball = away;
    for (let frame = 0; frame < decisionInterval; frame++) sideways();
    state.ball = incoming;
    for (let frame = 0; frame < decisionInterval; frame++) sideways();
    expect(sideways()).toEqual({ left: true, right: false });
  });

  /** An easy AI that has drawn its recovery while the ball goes away, its next draws different. */
  function recovering() {
    let draw = 0.9;
    const ai = createTennisAI({ difficulty: "easy", rng: () => draw });
    const state = tennisState();
    state.ball = { x: 500, y: 260, vx: 0, vy: 4, speed: 5, height: 0.3, heightVel: 0 };
    ai.nextInputs({ state, player: 2 });
    draw = 0.1;
    return { ai, state, recoveryX: ai._target.x };
  }

  it("keeps one recovery error while the ball is going away", () => {
    const { ai, state, recoveryX } = recovering();
    for (let frame = 0; frame < TENNIS_AI_DIFFICULTIES.easy.decisionInterval * 4; frame++) {
      ai.nextInputs({ state, player: 2 });
      expect(ai._target.x).toBe(recoveryX);
    }
  });

  it("draws a fresh recovery error after forgetting the last point", () => {
    const { ai, state, recoveryX } = recovering();
    ai.forget();
    ai.nextInputs({ state, player: 2 });
    expect(ai._target.x).not.toBe(recoveryX);
  });
});
