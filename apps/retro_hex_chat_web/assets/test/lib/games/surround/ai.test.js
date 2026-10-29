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

/**
 * An easy AI that has just started a lapse, heading left into the wall: one
 * look in the open to have a heading, then a lapse drawn at the wall.
 */
function lapsingAtWall() {
  const rolls = [];
  const ai = createSurroundAI({ difficulty: "easy", rng: () => rolls.shift() ?? 0.99 });
  ai.nextDirection({ state: playingState(), player: 2 });
  const atWall = movePlayer(playingState(), 2, { x: 0, y: 20, dir: DIR.LEFT });
  rolls.push(0);
  expect(ai.nextDirection({ state: atWall, player: 2 })).toBe(DIR.LEFT);
  return { ai, atWall };
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

  it("difficulty changes how far it sees and how often it slips", () => {
    const { easy, normal, hard } = SURROUND_AI_DIFFICULTIES;
    expect(hard.floodLimit).toBeGreaterThan(normal.floodLimit);
    expect(normal.floodLimit).toBeGreaterThan(easy.floodLimit);
    expect(hard.mistakeRate).toBeLessThan(normal.mistakeRate);
    expect(normal.mistakeRate).toBeLessThan(easy.mistakeRate);
    expect(hard.lapseRate).toBeLessThanOrEqual(normal.lapseRate);
    expect(normal.lapseRate).toBeLessThanOrEqual(easy.lapseRate);
  });

  it("a lapse keeps going straight for its whole length, into a wall if one is there", () => {
    const { ai, atWall } = lapsingAtWall();
    const rest = Array.from({ length: SURROUND_AI_DIFFICULTIES.easy.lapseMoves - 1 }, () =>
      ai.nextDirection({ state: atWall, player: 2 }),
    );

    expect(rest.every((direction) => direction === DIR.LEFT)).toBe(true);
    expect(ai.nextDirection({ state: atWall, player: 2 })).not.toBe(DIR.LEFT);
  });

  it("forgets a lapse, and the last round's heading, between rounds", () => {
    const { ai, atWall } = lapsingAtWall();

    // The engine calls forget() on every phase change: the crash, the next countdown.
    ai.forget();

    expect(ai.lastDirection).toBeNull();
    expect(ai.nextDirection({ state: atWall, player: 2 })).not.toBe(DIR.LEFT);
  });

  it("keeps a lapse through a move outside play: forgetting is the engine's call", () => {
    const { ai, atWall } = lapsingAtWall();

    ai.nextDirection({ state: createInitialState(1), player: 2 });

    expect(ai.nextDirection({ state: atWall, player: 2 })).toBe(DIR.LEFT);
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
