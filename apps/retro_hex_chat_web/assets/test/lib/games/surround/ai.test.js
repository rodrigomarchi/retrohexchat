import { describe, expect, it } from "vitest";

import { CELL, createInitialState } from "../../../../js/lib/games/surround/physics.js";
import { DIR, PHASE } from "../../../../js/lib/games/surround/protocol.js";
import {
  createSurroundAI,
  normalizeSurroundAIDifficulty,
  SURROUND_AI_DIFFICULTIES,
} from "../../../../js/lib/games/surround/ai.js";

function playingState() {
  const state = createInitialState(0);
  state.phase = PHASE.PLAYING;
  return state;
}

function movePlayer(state, player, next) {
  const key = player === 1 ? "p1" : "p2";
  const cell = player === 1 ? CELL.P1_TRAIL : CELL.P2_TRAIL;
  state.grid[state[key].y][state[key].x] = CELL.EMPTY;
  state[key] = { ...next };
  state.grid[next.y][next.x] = cell;
  return state;
}

function block(state, x, y) {
  state.grid[y][x] = CELL.P1_TRAIL;
}

describe("Surround AI", () => {
  it("normalizes unknown difficulty to normal", () => {
    expect(normalizeSurroundAIDifficulty("hard")).toBe("hard");
    expect(normalizeSurroundAIDifficulty("unknown")).toBe("normal");
    expect(normalizeSurroundAIDifficulty(null)).toBe("normal");
  });

  it("keeps the current direction outside active play", () => {
    const ai = createSurroundAI({ difficulty: "hard", rng: () => 0.5 });
    const state = createInitialState(0);

    expect(ai.nextDirection({ state, player: 2 })).toBe(DIR.LEFT);
  });

  it("turns away from an immediate wall collision", () => {
    const ai = createSurroundAI({ difficulty: "hard", rng: () => 0.5 });
    const state = movePlayer(playingState(), 2, { x: 59, y: 20, dir: DIR.RIGHT });

    expect(ai.nextDirection({ state, player: 2 })).toBe(DIR.UP);
  });

  it("never chooses a 180 degree reversal", () => {
    const ai = createSurroundAI({ difficulty: "hard", rng: () => 0.5 });
    const state = movePlayer(playingState(), 2, { x: 20, y: 20, dir: DIR.LEFT });

    expect(ai.nextDirection({ state, player: 2 })).not.toBe(DIR.RIGHT);
  });

  it("prefers the route with more open cells", () => {
    const ai = createSurroundAI({ difficulty: "hard", rng: () => 0.5 });
    const state = movePlayer(playingState(), 2, { x: 10, y: 10, dir: DIR.RIGHT });
    block(state, 11, 10);
    block(state, 10, 8);
    block(state, 9, 9);
    block(state, 11, 9);

    expect(ai.nextDirection({ state, player: 2 })).toBe(DIR.DOWN);
  });

  it("difficulty changes decision strength and mistake rate", () => {
    expect(SURROUND_AI_DIFFICULTIES.hard.floodLimit).toBeGreaterThan(
      SURROUND_AI_DIFFICULTIES.easy.floodLimit,
    );
    expect(SURROUND_AI_DIFFICULTIES.hard.decisionFrames).toBeLessThan(
      SURROUND_AI_DIFFICULTIES.easy.decisionFrames,
    );
    expect(SURROUND_AI_DIFFICULTIES.hard.mistakeRate).toBeLessThan(
      SURROUND_AI_DIFFICULTIES.easy.mistakeRate,
    );
  });

  it("controlled mistakes still pick a safe non-reversal direction", () => {
    const rolls = [0, 1];
    const ai = createSurroundAI({ difficulty: "easy", rng: () => rolls.shift() ?? 0.5 });
    const state = movePlayer(playingState(), 2, { x: 20, y: 20, dir: DIR.LEFT });

    const direction = ai.nextDirection({ state, player: 2 });

    expect(direction).not.toBe(DIR.RIGHT);
    expect([DIR.UP, DIR.DOWN, DIR.LEFT]).toContain(direction);
  });
});
