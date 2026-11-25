import { describe, expect, it } from "vitest";
import { mulberry32 } from "../../../support/games/seeded_random.js";
import { createHexRaidAI } from "../../../../js/lib/games/hex_raid/ai.js";
import { createInitialState, stepTick } from "../../../../js/lib/games/hex_raid/physics.js";
import { GAME_MODE, PHASE } from "../../../../js/lib/games/hex_raid/protocol.js";

const FPS = 60;
const LIMIT_FRAMES = 10 * 60 * FPS;
const MATCHES_TIMEOUT_MS = 30_000;

/**
 * A whole match between two hard AIs, a step at a time as the host plays it:
 * how many minutes it took, and how many of the six lives went to the
 * river's boats, helicopters, jets, bridges and banks rather than to fuel or
 * mines.
 */
function hardMatch(mode, seed) {
  const ais = {
    1: createHexRaidAI({ difficulty: "hard", rng: mulberry32(seed * 13 + 1) }),
    2: createHexRaidAI({ difficulty: "hard", rng: mulberry32(seed * 7 + 5) }),
  };
  let state = { ...createInitialState(mode, 1000 + seed * 97), phase: PHASE.FLYING };
  let held = { 1: { fire: false, mine: false }, 2: { fire: false, mine: false } };
  let crashes = 0;
  let frame = 0;

  for (; frame < LIMIT_FRAMES && state.phase !== PHASE.FINISHED; frame++) {
    const keys = {
      1: ais[1].nextInputs({ state, player: 1 }),
      2: ais[2].nextInputs({ state, player: 2 }),
    };
    const before = state;
    ({ state, held } = stepTick(state, keys, held, frame));
    for (const player of [1, 2]) {
      const died = before[`jet${player}Alive`] && !state[`jet${player}Alive`];
      const { fuelEmpty, mineHit } = state.events;
      if (died && !(fuelEmpty & player) && mineHit !== player) crashes++;
    }
  }
  return { minutes: frame / (60 * FPS), crashes };
}

describe.each([
  ["River Duel", GAME_MODE.RIVER_DUEL],
  ["Pacifist", GAME_MODE.PACIFIST],
  ["Blitz", GAME_MODE.BLITZ],
])("Hex Raid %s, two hard jets", (_name, mode) => {
  it(
    "fly past the river's traffic for minutes, not seconds",
    () => {
      const matches = [1, 2, 3, 4].map((seed) => hardMatch(mode, seed));
      const minutes = matches.reduce((sum, m) => sum + m.minutes, 0);
      const crashes = matches.reduce((sum, m) => sum + m.crashes, 0);

      expect(minutes / matches.length).toBeGreaterThan(1.2);
      // Crashing into a boat, a helicopter or a jet is a slip, not the pace:
      // under one and a half a minute for the two of them.
      expect(crashes / minutes).toBeLessThan(1.5);
    },
    MATCHES_TIMEOUT_MS,
  );
});
