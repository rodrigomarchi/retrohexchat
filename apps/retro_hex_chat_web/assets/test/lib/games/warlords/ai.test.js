import { describe, expect, it } from "vitest";

import {
  CANVAS_H,
  FIREBALL_SIZE,
  P2_SHIELD_X,
  SHIELD_H,
  createInitialState,
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

  it("updates difficulty through the public setter", () => {
    const ai = createWarlordAI({ difficulty: "easy" });

    ai.setDifficulty("hard");

    expect(ai.difficulty).toBe("hard");
  });

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

  it("holds catch when an aligned fireball is about to touch the shield", () => {
    const state = playingState({
      fireballX: P2_SHIELD_X - FIREBALL_SIZE - 12,
      fireballY: 150,
      fireballVX: 4,
      fireballVY: 0,
      shield2Y: 150 - SHIELD_H / 2,
    });

    expect(shouldHoldCatch(state, 2, WARLORD_AI_DIFFICULTIES.normal, () => 0.5)).toBe(true);
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

    expect(ai.nextInputs({ state: createInitialState(), player: 2 })).toEqual({
      up: false,
      down: false,
      space: false,
    });
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
});
