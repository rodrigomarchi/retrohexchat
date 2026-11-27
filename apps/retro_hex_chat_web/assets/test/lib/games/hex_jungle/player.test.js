import { describe, expect, it } from "vitest";
import {
  createInitialState,
  stepTick,
  tickClock,
} from "../../../../js/lib/games/hex_jungle/physics.js";
import { createHexJunglePlayer } from "../../../../js/lib/games/hex_jungle/player.js";
import { PHASE } from "../../../../js/lib/games/hex_jungle/protocol.js";

/** An expedition played by the computer player for `ticks` ticks. */
function expedition(ticks) {
  const player = createHexJunglePlayer();
  let state = { ...createInitialState(), phase: PHASE.PLAYING };
  for (let t = 0; t < ticks && state.phase === PHASE.PLAYING; t++) {
    const keys = player.nextInputs({ state });
    state = tickClock(stepTick(state, keys));
  }
  return state;
}

describe("Hex Jungle's computer player", () => {
  // Three minutes: logs, a vine, crocodiles, shifting tar and a tunnel.
  it("finds treasures without losing a life", () => {
    const state = expedition(3 * 60 * 60);
    expect(state.phase).toBe(PHASE.PLAYING);
    expect(state.treasures).toBeGreaterThanOrEqual(3);
  }, 60_000);

  it("waits for nothing before it moves", () => {
    const player = createHexJunglePlayer();
    const state = { ...createInitialState(), phase: PHASE.PLAYING };
    const keys = player.nextInputs({ state });
    expect(Object.values(keys).some(Boolean)).toBe(true);
  });
});
