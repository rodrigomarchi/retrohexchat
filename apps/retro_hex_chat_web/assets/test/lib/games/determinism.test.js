// The same match seed plays the same match: the simulation draws only from
// the generator the seed starts, never from the page's Math.random, which
// here is left in a different state for each run.

import { afterEach, describe, expect, it } from "vitest";
import { playMatch } from "../../support/games/harness.js";

const GAME_IDS = [
  "hex_pong",
  "star_duel",
  "hex_frost",
  "hex_skiing",
  "hex_hockey",
  "hex_invaders",
  "hex_tennis",
  "hex_boxing",
  "hex_outlaw",
  "hex_raid",
  "pixel_tanks",
  "light_trails",
  "hex_warlords",
  "hex_enduro",
  "block_breakers",
];

let match = null;
afterEach(() => {
  match?.stop();
  match?.restore();
  match = null;
});

async function play(gameId, pageSeed) {
  match = await playMatch({ gameId, mode: "solo", seed: pageSeed, matchSeed: 12345 });
  match.advance(6000);
  const { state, results } = match.record();
  match.stop();
  match.restore();
  match = null;
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
