import { describe, expect, it } from "vitest";

import {
  BALL_SIZE,
  CANVAS_W,
  PADDLE_H,
  PADDLE_MARGIN,
  PADDLE_W,
  createInitialState,
} from "../../../../js/lib/games/breakout/physics.js";
import { PHASE } from "../../../../js/lib/games/breakout/protocol.js";
import {
  BREAKOUT_AI_DIFFICULTIES,
  breakoutMovementInputs,
  createBreakoutAI,
  normalizeBreakoutAIDifficulty,
  predictBreakoutInterceptX,
  reflectBreakoutX,
} from "../../../../js/lib/games/breakout/ai.js";

function playingState(overrides = {}) {
  return {
    ...createInitialState(),
    phase: PHASE.PLAYING,
    ...overrides,
  };
}

describe("BreakoutAI", () => {
  it("normalizes difficulty names", () => {
    expect(normalizeBreakoutAIDifficulty("easy")).toBe("easy");
    expect(normalizeBreakoutAIDifficulty("HARD")).toBe("hard");
    expect(normalizeBreakoutAIDifficulty("legendary")).toBe("normal");
    expect(normalizeBreakoutAIDifficulty(null)).toBe("normal");
  });

  it("updates difficulty through the public setter", () => {
    const ai = createBreakoutAI({ difficulty: "easy" });

    ai.setDifficulty("hard");

    expect(ai.difficulty).toBe("hard");
  });

  it("predicts a straight intercept for the top paddle", () => {
    const state = playingState({
      ballX: 320,
      ballY: 240,
      ballVX: 3,
      ballVY: -4,
    });
    const targetY = PADDLE_MARGIN + PADDLE_H + BALL_SIZE / 2;
    const frames = (targetY - state.ballY) / state.ballVY;

    expect(predictBreakoutInterceptX(state, 2)).toBeCloseTo(state.ballX + state.ballVX * frames);
  });

  it("reflects predicted intercepts off side walls", () => {
    const state = playingState({
      ballX: CANVAS_W - BALL_SIZE,
      ballY: 220,
      ballVX: 9,
      ballVY: -3,
    });
    const targetY = PADDLE_MARGIN + PADDLE_H + BALL_SIZE / 2;
    const rawX = state.ballX + state.ballVX * ((targetY - state.ballY) / state.ballVY);

    expect(predictBreakoutInterceptX(state, 2)).toBeCloseTo(reflectBreakoutX(rawX));
  });

  it("does not predict an intercept while the ball moves away from the top paddle", () => {
    const state = playingState({ ballVY: 4 });

    expect(predictBreakoutInterceptX(state, 2)).toBeNull();
  });

  it("moves left or right toward a sampled target", () => {
    const state = playingState({ paddle2X: 300 });

    expect(breakoutMovementInputs(state, 2, 120, 6)).toEqual({ left: true, right: false });
    expect(breakoutMovementInputs(state, 2, 520, 6)).toEqual({ left: false, right: true });
  });

  it("tracks an incoming top-side ball", () => {
    const ai = createBreakoutAI({ difficulty: "hard", rng: () => 0.5 });
    const state = playingState({
      ballX: 120,
      ballY: 220,
      ballVX: 0,
      ballVY: -4,
      paddle2X: CANVAS_W / 2,
    });

    expect(ai.nextInputs({ state, player: 2 })).toEqual({ left: true, right: false });
  });

  it("recenters while the ball moves away", () => {
    const ai = createBreakoutAI({ difficulty: "hard", rng: () => 0.5 });
    const state = playingState({
      ballX: 320,
      ballVY: 4,
      paddle2X: 0,
    });

    expect(ai.nextInputs({ state, player: 2 })).toEqual({ left: false, right: true });
  });

  it("stays neutral outside active play", () => {
    const ai = createBreakoutAI({ difficulty: "hard", rng: () => 0.5 });

    expect(ai.nextInputs({ state: createInitialState(), player: 2 })).toEqual({
      left: false,
      right: false,
    });
  });

  it("keeps harder difficulties more precise than easier ones", () => {
    expect(BREAKOUT_AI_DIFFICULTIES.hard.errorPx).toBeLessThan(
      BREAKOUT_AI_DIFFICULTIES.easy.errorPx,
    );
    expect(BREAKOUT_AI_DIFFICULTIES.hard.deadzonePx).toBeLessThan(
      BREAKOUT_AI_DIFFICULTIES.easy.deadzonePx,
    );
    expect(BREAKOUT_AI_DIFFICULTIES.hard.reactionFrames).toBeLessThan(
      BREAKOUT_AI_DIFFICULTIES.easy.reactionFrames,
    );
  });

  it("uses the cached decision between difficulty ticks", () => {
    const ai = createBreakoutAI({ difficulty: "easy", rng: () => 0.5 });
    const first = playingState({
      ballX: 120,
      ballY: 220,
      ballVX: 0,
      ballVY: -4,
      paddle2X: CANVAS_W / 2 - PADDLE_W / 2,
    });
    const second = playingState({
      ballX: 520,
      ballY: 220,
      ballVX: 0,
      ballVY: -4,
      paddle2X: CANVAS_W / 2 - PADDLE_W / 2,
    });

    expect(ai.nextInputs({ state: first, player: 2 })).toEqual({ left: true, right: false });
    expect(ai.nextInputs({ state: second, player: 2 })).toEqual({ left: true, right: false });
  });
});
