import { describe, expect, it } from "vitest";
import { mulberry32 } from "../../../support/games/seeded_random.js";
import { createOutlawAI } from "../../../../js/lib/games/hex_outlaw/ai.js";
import {
  createInitialState,
  resetForNewRound,
  stepTick,
} from "../../../../js/lib/games/hex_outlaw/physics.js";
import { GAME_MODE, PHASE, SNAPSHOT } from "../../../../js/lib/games/hex_outlaw/protocol.js";

const FPS = 60;
const LIMIT_FRAMES = 10 * 60 * FPS;
const MATCHES_TIMEOUT_MS = 60_000;

/**
 * A whole duel between two hard gunslingers, a step at a time as the host
 * plays it, each seat's aim the last of up or down it pressed: how many
 * minutes it took, and whether it ended. With `guest`, gunslinger two plays
 * the street a guest's browser sees — the host's snapshot, sent over the
 * wire and copied onto the guest's own state.
 */
function hardDuel(mode, seed, { guest = false } = {}) {
  const ais = {
    1: createOutlawAI({ difficulty: "hard", rng: mulberry32(seed * 13 + 1) }),
    2: createOutlawAI({ difficulty: "hard", rng: mulberry32(seed * 7 + 5) }),
  };
  let state = { ...createInitialState(mode), phase: PHASE.PLAYING };
  let seen = createInitialState(mode);
  let pressed = { 1: false, 2: false };
  const aimUp = { 1: false, 2: false };
  let frame = 0;

  for (; frame < LIMIT_FRAMES && state.phase !== PHASE.MATCH_OVER; frame++) {
    seen = { ...seen, ...SNAPSHOT.decode(SNAPSHOT.encode(state)) };
    const inputs = {
      1: ais[1].nextInputs({ state, player: 1 }),
      2: ais[2].nextInputs({ state: guest ? seen : state, player: 2 }),
    };
    for (const player of [1, 2]) {
      if (inputs[player].up) aimUp[player] = true;
      if (inputs[player].down) aimUp[player] = false;
    }
    const step = stepTick(state, inputs, pressed, aimUp);
    ({ state, pressed } = step);
    if (step.events.roundOver && state.phase !== PHASE.MATCH_OVER) {
      state = { ...resetForNewRound(state), phase: PHASE.PLAYING };
      pressed = { 1: false, 2: false };
      ais[1].forget();
      ais[2].forget();
    }
  }
  return { minutes: frame / (60 * FPS), ended: state.phase === PHASE.MATCH_OVER };
}

describe.each([
  ["Hex Outlaw", GAME_MODE.QUICK_DRAW],
  ["Ricochet", GAME_MODE.RICOCHET],
  ["Stagecoach", GAME_MODE.STAGECOACH],
  ["No Man's Land", GAME_MODE.NO_MANS_LAND],
])("%s, two hard gunslingers", (_name, mode) => {
  it.each([
    ["on the host", false],
    ["with gunslinger two on a guest's browser", true],
  ])(
    "shoot it out to the end %s, in minutes",
    (_where, guest) => {
      const duels = [1, 2, 3, 4].map((seed) => hardDuel(mode, seed, { guest }));

      expect(duels.every((duel) => duel.ended)).toBe(true);
      const minutes = duels.reduce((sum, duel) => sum + duel.minutes, 0) / duels.length;
      expect(minutes).toBeGreaterThan(0.5);
      expect(minutes).toBeLessThan(5);
    },
    MATCHES_TIMEOUT_MS,
  );
});
