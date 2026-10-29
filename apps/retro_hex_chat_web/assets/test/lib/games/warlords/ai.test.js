import { describe, expect, it } from "vitest";

import {
  expectFreshLookAfterForget,
  expectNeutralOutsidePlay,
  expectOneAimPerApproach,
  itSetsDifficulty,
} from "../../../support/games/ai_tests.js";

import {
  CANVAS_H,
  FIREBALL_SIZE,
  P2_SHIELD_X,
  SHIELD_H,
  createInitialState,
  P1_SHIELD_X,
  SHIELD_W,
} from "../../../../js/lib/games/warlords/physics.js";
import { PHASE } from "../../../../js/lib/games/warlords/protocol.js";
import {
  WARLORD_AI_DIFFICULTIES,
  createWarlordAI,
  normalizeWarlordAIDifficulty,
  predictWarlordInterceptY,
  reflectWarlordY,
  shouldHoldCatch,
  warlordMovementInputs,
} from "../../../../js/lib/games/warlords/ai.js";

function playingState(overrides = {}) {
  return {
    ...createInitialState(),
    phase: PHASE.PLAYING,
    ...overrides,
  };
}

describe("WarlordAI", () => {
  it("normalizes difficulty names", () => {
    expect(normalizeWarlordAIDifficulty("easy")).toBe("easy");
    expect(normalizeWarlordAIDifficulty("HARD")).toBe("hard");
    expect(normalizeWarlordAIDifficulty("legendary")).toBe("normal");
    expect(normalizeWarlordAIDifficulty(null)).toBe("normal");
  });

  itSetsDifficulty(createWarlordAI);

  it("predicts a straight intercept for the right-side shield", () => {
    const state = playingState({
      fireballX: 320,
      fireballY: 120,
      fireballVX: 5,
      fireballVY: 2,
    });
    const targetX = P2_SHIELD_X - FIREBALL_SIZE / 2;
    const frames = (targetX - state.fireballX) / state.fireballVX;

    expect(predictWarlordInterceptY(state, 2)).toBeCloseTo(
      state.fireballY + state.fireballVY * frames,
    );
  });

  it("reflects predicted intercepts off top and bottom walls", () => {
    const state = playingState({
      fireballX: P2_SHIELD_X - 160,
      fireballY: CANVAS_H - FIREBALL_SIZE,
      fireballVX: 5,
      fireballVY: 5,
    });
    const targetX = P2_SHIELD_X - FIREBALL_SIZE / 2;
    const rawY =
      state.fireballY + state.fireballVY * ((targetX - state.fireballX) / state.fireballVX);

    expect(predictWarlordInterceptY(state, 2)).toBeCloseTo(reflectWarlordY(rawY));
  });

  it("does not predict while the fireball moves away from the shield", () => {
    const state = playingState({ fireballVX: -4 });

    expect(predictWarlordInterceptY(state, 2)).toBeNull();
  });

  it("moves up or down toward a sampled target", () => {
    const state = playingState({ shield2Y: 220 });

    expect(warlordMovementInputs(state, 2, 120, 6)).toEqual({ up: true, down: false });
    expect(warlordMovementInputs(state, 2, 360, 6)).toEqual({ up: false, down: true });
  });

  it("tracks an incoming fireball", () => {
    const ai = createWarlordAI({ difficulty: "hard", rng: () => 0.5 });
    const state = playingState({
      fireballX: P2_SHIELD_X - 120,
      fireballY: 120,
      fireballVX: 4,
      fireballVY: 0,
      shield2Y: CANVAS_H / 2,
    });

    expect(ai.nextInputs({ state, player: 2 })).toEqual({
      up: true,
      down: false,
      space: false,
    });
  });

  /** A fireball lined up with player two's shield, a frame or two from touching it. */
  const aboutToTouch = () =>
    playingState({
      fireballX: P2_SHIELD_X - FIREBALL_SIZE - 12,
      fireballY: 150,
      fireballVX: 4,
      fireballVY: 0,
      shield2Y: 150 - SHIELD_H / 2,
    });

  it("holds catch when an aligned fireball is about to touch the shield", () => {
    const state = aboutToTouch();

    expect(shouldHoldCatch(state, 2, WARLORD_AI_DIFFICULTIES.normal, () => true)).toBe(true);
    expect(shouldHoldCatch(state, 2, WARLORD_AI_DIFFICULTIES.normal, () => false)).toBe(false);
  });

  it("releases a caught fireball after the configured delay", () => {
    const ai = createWarlordAI({ difficulty: "hard", rng: () => 0.5 });
    const state = playingState({ caughtBy: 2 });

    for (let frame = 1; frame < WARLORD_AI_DIFFICULTIES.hard.releaseFrames; frame++) {
      expect(ai.nextInputs({ state, player: 2 }).space).toBe(true);
    }

    expect(ai.nextInputs({ state, player: 2 }).space).toBe(false);
  });

  it("stays neutral outside active play", () => {
    const ai = createWarlordAI({ difficulty: "hard", rng: () => 0.5 });
    expectNeutralOutsidePlay(ai, createInitialState(), { up: false, down: false, space: false });
  });

  it("keeps harder difficulties more precise than easier ones", () => {
    expect(WARLORD_AI_DIFFICULTIES.hard.errorPx).toBeLessThan(WARLORD_AI_DIFFICULTIES.easy.errorPx);
    expect(WARLORD_AI_DIFFICULTIES.hard.deadzonePx).toBeLessThan(
      WARLORD_AI_DIFFICULTIES.easy.deadzonePx,
    );
    expect(WARLORD_AI_DIFFICULTIES.hard.releaseFrames).toBeLessThan(
      WARLORD_AI_DIFFICULTIES.easy.releaseFrames,
    );
  });

  it("keeps one aim error for a whole approach and draws a new one for the next", () => {
    const fireball = { fireballX: 320, fireballY: 240, fireballVY: 0, shield2Y: 210 };
    const incoming = playingState({ ...fireball, fireballVX: 4 });
    expectOneAimPerApproach({
      create: (rng) => createWarlordAI({ difficulty: "hard", rng }),
      incoming,
      away: playingState({ ...fireball, fireballVX: -4 }),
      every: WARLORD_AI_DIFFICULTIES.hard.decisionFrames,
      aim: (ai) => ai.sampledTargetY,
      intercept: predictWarlordInterceptY(incoming, 2),
      errorPx: WARLORD_AI_DIFFICULTIES.hard.errorPx,
    });
  });

  it("aims shield one at its face, where the fireball meets it", () => {
    const state = playingState({ fireballX: 300, fireballY: 150, fireballVX: -4, fireballVY: 1 });
    const faceX = P1_SHIELD_X + SHIELD_W + FIREBALL_SIZE / 2;

    expect(predictWarlordInterceptY(state, 1)).toBeCloseTo(150 + (300 - faceX) / 4);
  });

  it("decides once per approach whether to catch", () => {
    let draw = 0;
    const ai = createWarlordAI({ difficulty: "normal", rng: () => draw });
    const state = aboutToTouch();

    expect(ai.nextInputs({ state, player: 2 }).space).toBe(true);
    // Later draws would say no, but this approach's catch was already decided
    draw = 0.99;
    for (let frame = 0; frame < 10; frame++) {
      expect(ai.nextInputs({ state, player: 2 }).space).toBe(true);
    }
  });

  it("looks again at once after forgetting the last round", () => {
    expectFreshLookAfterForget({
      create: (rng) => createWarlordAI({ difficulty: "easy", rng }),
      before: playingState({ fireballX: 320, fireballY: 150, fireballVX: 4, fireballVY: 0 }),
      after: playingState({ fireballX: 320, fireballY: 320, fireballVX: 4, fireballVY: 0 }),
      aim: (ai) => ai.sampledTargetY,
    });
  });
});
