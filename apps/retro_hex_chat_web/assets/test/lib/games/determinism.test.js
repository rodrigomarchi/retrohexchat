// The same match seed plays the same match: the simulation draws only from
// the generator the seed starts, never from the page's Math.random, which
// here is left in a different state for each run.

import { describe, expect, it } from "vitest";
import { recordedMatch } from "../../support/games/harness.js";
import { ENGINE_GAME_IDS } from "../../support/games/engines.js";

const GAME_IDS = ENGINE_GAME_IDS;

async function play(gameId, pageSeed) {
  const options = { gameId, mode: "solo", seed: pageSeed, matchSeed: 12345 };
  const { state, results } = await recordedMatch(options, 6000);
  return { state, results };
}

describe("a match seed", () => {
  for (const gameId of GAME_IDS) {
    it(`${gameId}: plays the same solo match whatever the page's Math.random`, async () => {
      const first = await play(gameId, 1);
      const second = await play(gameId, 2);

      expect(second).toEqual(first);
    });
  }
});
