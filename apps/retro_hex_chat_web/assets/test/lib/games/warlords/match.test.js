import { describe, expect, it } from "vitest";
import { mulberry32 } from "../../../support/games/seeded_random.js";
import { createWarlordAI } from "../../../../js/lib/games/warlords/ai.js";
import {
  checkGameOver,
  createInitialState,
  rebuildCastles,
  releaseBall,
  serveFireball,
  stepTick,
} from "../../../../js/lib/games/warlords/physics.js";
import { PHASE } from "../../../../js/lib/games/warlords/protocol.js";

const FPS = 60;
// Each king hit pauses the game, and the next round counts down, as the engine does.
const BETWEEN_ROUNDS_FRAMES = 120 + 3 * FPS;

/**
 * A whole match between two AIs, a tick at a time as the host plays it:
 * a caught fireball goes when Space is let go, and a king hit ends the round.
 * How many minutes it took, or null if nobody won within `limitMinutes`.
 */
function minutesToWin(difficulty1, difficulty2, seed, limitMinutes) {
  const ais = {
    1: createWarlordAI({ difficulty: difficulty1, rng: mulberry32(seed * 13 + 1) }),
    2: createWarlordAI({ difficulty: difficulty2, rng: mulberry32(seed * 7 + 5) }),
  };
  const levels = { 1: difficulty1, 2: difficulty2 };
  const random = mulberry32(seed * 31 + 7);
  let state = serveFireball({ ...createInitialState(), phase: PHASE.PLAYING }, random);
  let phase = state.phase;
  const held = { 1: false, 2: false };
  let frames = 0;

  while (frames < limitMinutes * 60 * FPS) {
    if (state.phase !== phase) {
      phase = state.phase;
      ais[1].forget();
      ais[2].forget();
    }
    const inputs = {};
    for (const player of [1, 2]) {
      inputs[player] = ais[player].nextInputs({ state, player, difficulty: levels[player] });
      if (held[player] && !inputs[player].space) state = releaseBall(state, player);
      held[player] = inputs[player].space;
    }
    state = stepTick(state, inputs[1], inputs[2]).state;
    frames++;
    if (state.phase !== PHASE.KING_HIT) continue;
    state = checkGameOver(state);
    if (state.phase === PHASE.FINISHED) return frames / (60 * FPS);
    frames += BETWEEN_ROUNDS_FRAMES;
    state = serveFireball(rebuildCastles(state), random);
  }
  return null;
}

describe("Hex Warlords, a whole match", () => {
  it("ends against the hard computer in minutes, not a quarter of an hour", () => {
    const seeds = [1, 2, 3, 4, 5, 6, 7, 8];
    const minutes = seeds.map((seed) => minutesToWin("easy", "hard", seed, 20));

    expect(minutes.every((m) => m !== null && m < 12)).toBe(true);
    expect(minutes.reduce((sum, m) => sum + m, 0) / seeds.length).toBeLessThan(6);
  });

  it("ends between two hard players too", () => {
    for (const seed of [1, 2, 3, 4]) {
      expect(minutesToWin("hard", "hard", seed, 20)).not.toBeNull();
    }
  });
});
