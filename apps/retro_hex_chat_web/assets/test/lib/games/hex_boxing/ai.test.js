import { describe, expect, it, vi } from "vitest";
import { createInitialState } from "../../../../js/lib/games/hex_boxing/physics.js";
import { PHASE, PUNCH_STATE } from "../../../../js/lib/games/hex_boxing/protocol.js";
import {
  BOXING_AI_DIFFICULTIES,
  boxingMovementInputs,
  boxingTargetPosition,
  createBoxingAI,
  directionFacesOpponent,
  normalizeBoxingAIDifficulty,
  shouldThrowPunch,
} from "../../../../js/lib/games/hex_boxing/ai.js";

function fightingState() {
  const state = createInitialState();
  state.phase = PHASE.FIGHTING;
  return state;
}

describe("BoxingAI", () => {
  it("normalizes invalid difficulties to normal", () => {
    expect(normalizeBoxingAIDifficulty("easy")).toBe("easy");
    expect(normalizeBoxingAIDifficulty("HARD")).toBe("hard");
    expect(normalizeBoxingAIDifficulty("legendary")).toBe("normal");
    expect(normalizeBoxingAIDifficulty(null)).toBe("normal");
  });

  it("lets difficulty be updated after creation", () => {
    const ai = createBoxingAI({ difficulty: "easy" });

    ai.setDifficulty("hard");

    expect(ai.difficulty).toBe("hard");
  });

  it("returns neutral inputs outside the fighting phase", () => {
    const ai = createBoxingAI({ difficulty: "hard", rng: () => 0 });
    const state = createInitialState();

    expect(ai.nextInputs({ state, player: 2 })).toEqual({
      up: false,
      down: false,
      left: false,
      right: false,
      punch: false,
    });
  });

  it("approaches the opponent from the right side for player 2", () => {
    const ai = createBoxingAI({ difficulty: "hard", rng: () => 0.5 });
    const state = fightingState();

    const inputs = ai.nextInputs({ state, player: 2 });

    expect(inputs.left).toBe(true);
    expect(inputs.right).toBe(false);
  });

  it("dodges an opponent punch when the difficulty roll allows it", () => {
    const state = fightingState();
    state.b1x = 420;
    state.b1y = 240;
    state.b1punchState = PUNCH_STATE.PUNCHING;
    state.b2x = 450;
    state.b2y = 240;

    const target = boxingTargetPosition(state, 2, BOXING_AI_DIFFICULTIES.hard, () => 0);

    expect(target.kind).toBe("dodge");
    expect(target.y).toBeLessThan(state.b2y);
  });

  it("holds position inside the deadzone", () => {
    expect(boxingMovementInputs({ x: 100, y: 100 }, { x: 104, y: 97 }, 6)).toEqual({
      up: false,
      down: false,
      left: false,
      right: false,
      punch: false,
    });
  });

  it("moves toward a target outside the deadzone", () => {
    expect(boxingMovementInputs({ x: 100, y: 100 }, { x: 80, y: 130 }, 6)).toEqual({
      up: false,
      down: true,
      left: true,
      right: false,
      punch: false,
    });
  });

  it("throws a one-frame punch when aligned and in range", () => {
    const ai = createBoxingAI({ difficulty: "hard", rng: () => 0 });
    const state = fightingState();
    state.b1x = 192;
    state.b1y = 240;
    state.b2x = 220;
    state.b2y = 240;
    state.b2dir = 4;

    const first = ai.nextInputs({ state, player: 2 });
    const second = ai.nextInputs({ state, player: 2 });

    expect(first.punch).toBe(true);
    expect(second.punch).toBe(false);
  });

  it("does not punch when the rng roll misses", () => {
    const state = fightingState();
    state.b1x = 192;
    state.b1y = 240;
    state.b2x = 220;
    state.b2y = 240;
    state.b2dir = 4;

    expect(shouldThrowPunch(state, 2, BOXING_AI_DIFFICULTIES.easy, () => 1)).toBe(false);
  });

  it("requires the boxer to face the opponent before punching", () => {
    const state = fightingState();
    state.b1x = 192;
    state.b1y = 240;
    state.b2x = 220;
    state.b2y = 240;
    state.b2dir = 0;

    expect(shouldThrowPunch(state, 2, BOXING_AI_DIFFICULTIES.hard, () => 0)).toBe(false);
  });

  it("maps 8-way facing directions against the opponent vector", () => {
    expect(directionFacesOpponent(4, -20, 0)).toBe(true);
    expect(directionFacesOpponent(0, -20, 0)).toBe(false);
    expect(directionFacesOpponent(6, 0, -20)).toBe(true);
    expect(directionFacesOpponent(2, 0, -20)).toBe(false);
  });

  it("uses the configured rng for target error and punch odds", () => {
    const rng = vi.fn(() => 0);
    const ai = createBoxingAI({ difficulty: "hard", rng });
    const state = fightingState();
    state.b1x = 192;
    state.b1y = 240;
    state.b2x = 220;
    state.b2y = 240;
    state.b2dir = 4;

    ai.nextInputs({ state, player: 2 });

    expect(rng).toHaveBeenCalled();
  });
});
