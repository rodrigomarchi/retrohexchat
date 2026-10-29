import { describe, expect, it } from "vitest";

import {
  expectFreshLookAfterForget,
  expectNeutralOutsidePlay,
  expectOneAimPerApproach,
} from "../../../support/games/ai_tests.js";

import {
  createInitialState,
  BALL_SIZE,
  CANVAS_H,
  CANVAS_W,
  PADDLE_H,
  PADDLE_MARGIN,
  PADDLE_W,
} from "../../../../js/lib/games/pong/physics.js";
import { PHASE } from "../../../../js/lib/games/pong/protocol.js";
import {
  createPongAI,
  normalizePongAIDifficulty,
  PONG_AI_DIFFICULTIES,
  predictPaddleInterceptY,
  reflectPongY,
} from "../../../../js/lib/games/pong/ai.js";

function playingState(overrides = {}) {
  return {
    ...createInitialState(),
    phase: PHASE.PLAYING,
    ...overrides,
  };
}

describe("Pong AI", () => {
  it("normalizes unknown difficulty to normal", () => {
    expect(normalizePongAIDifficulty("hard")).toBe("hard");
    expect(normalizePongAIDifficulty("unknown")).toBe("normal");
    expect(normalizePongAIDifficulty(null)).toBe("normal");
  });

  it("predicts a straight intercept for player two", () => {
    const state = playingState({
      ballX: 320,
      ballY: 120,
      ballVX: 7,
      ballVY: 2,
    });

    const targetX = CANVAS_W - PADDLE_MARGIN - PADDLE_W - BALL_SIZE / 2;
    const frames = (targetX - state.ballX) / state.ballVX;

    expect(predictPaddleInterceptY(state, 2)).toBeCloseTo(state.ballY + state.ballVY * frames);
  });

  it("reflects predicted intercepts off the top and bottom walls", () => {
    const state = playingState({
      ballX: 500,
      ballY: CANVAS_H - BALL_SIZE,
      ballVX: 5,
      ballVY: 3,
    });

    const targetX = CANVAS_W - PADDLE_MARGIN - PADDLE_W - BALL_SIZE / 2;
    const rawY = state.ballY + state.ballVY * ((targetX - state.ballX) / state.ballVX);

    expect(predictPaddleInterceptY(state, 2)).toBeCloseTo(reflectPongY(rawY));
  });

  it("does not predict an intercept while the ball moves away from the paddle", () => {
    const state = playingState({ ballVX: -5 });

    expect(predictPaddleInterceptY(state, 2)).toBeNull();
  });

  it.each([
    ["down", "below", 220, 100, { up: false, down: true }],
    ["up", "above", 180, 300, { up: true, down: false }],
  ])(
    "moves the AI paddle %s when the target is %s its center",
    (_way, _side, ballY, paddle2Y, keys) => {
      const ai = createPongAI({ difficulty: "hard", rng: () => 0.5 });
      const state = playingState({ ballX: 500, ballY, ballVX: 5, ballVY: 0, paddle2Y });

      expect(ai.nextInputs({ state, player: 2 })).toEqual(keys);
    },
  );

  it("returns toward the table center while the ball moves away", () => {
    const ai = createPongAI({ difficulty: "hard", rng: () => 0.5 });
    const state = playingState({
      ballVX: -5,
      paddle2Y: 20,
    });

    expect(ai.nextInputs({ state, player: 2 })).toEqual({ up: false, down: true });
  });

  it("stays neutral outside active play", () => {
    const ai = createPongAI({ difficulty: "hard", rng: () => 0.5 });
    expectNeutralOutsidePlay(ai, createInitialState(), { up: false, down: false });
  });

  it("keeps harder difficulties more precise than easier ones", () => {
    expect(PONG_AI_DIFFICULTIES.hard.errorPx).toBeLessThan(PONG_AI_DIFFICULTIES.easy.errorPx);
    expect(PONG_AI_DIFFICULTIES.hard.deadzonePx).toBeLessThan(PONG_AI_DIFFICULTIES.easy.deadzonePx);
    expect(PONG_AI_DIFFICULTIES.hard.reactionFrames).toBeLessThan(
      PONG_AI_DIFFICULTIES.easy.reactionFrames,
    );
  });

  it("does not move when the target is inside the active deadzone", () => {
    const ai = createPongAI({ difficulty: "hard", rng: () => 0.5 });
    const targetY = 200;
    const state = playingState({
      ballX: 500,
      ballY: targetY,
      ballVX: 5,
      ballVY: 0,
      paddle2Y: targetY - PADDLE_H / 2,
    });

    expect(ai.nextInputs({ state, player: 2 })).toEqual({ up: false, down: false });
  });

  it("keeps one aim error for a whole approach and draws a new one for the next", () => {
    const incoming = playingState({ ballX: 320, ballY: 240, ballVX: 5, ballVY: 0, paddle2Y: 200 });
    expectOneAimPerApproach({
      create: (rng) => createPongAI({ difficulty: "hard", rng }),
      incoming,
      away: playingState({ ballX: 320, ballY: 240, ballVX: -5, ballVY: 0, paddle2Y: 200 }),
      every: PONG_AI_DIFFICULTIES.hard.reactionFrames,
      aim: (ai) => ai.sampledTargetY,
      intercept: predictPaddleInterceptY(incoming, 2),
      errorPx: PONG_AI_DIFFICULTIES.hard.errorPx,
    });
  });

  it("looks again at once after forgetting the last round", () => {
    expectFreshLookAfterForget({
      create: (rng) => createPongAI({ difficulty: "easy", rng }),
      before: playingState({ ballX: 320, ballY: 150, ballVX: 5, ballVY: 0 }),
      after: playingState({ ballX: 320, ballY: 320, ballVX: 5, ballVY: 0 }),
      aim: (ai) => ai.sampledTargetY,
    });
  });
});
