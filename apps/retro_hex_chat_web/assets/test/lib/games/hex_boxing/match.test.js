import { describe, expect, it } from "vitest";
import { mulberry32 } from "../../../support/games/seeded_random.js";
import { createBoxingAI } from "../../../../js/lib/games/hex_boxing/ai.js";
import {
  ROUND_DURATION,
  advanceRound,
  checkRoundEnd,
  createInitialState,
  resetForNewRound,
  stepTick,
} from "../../../../js/lib/games/hex_boxing/physics.js";
import { PHASE, SNAPSHOT } from "../../../../js/lib/games/hex_boxing/protocol.js";

const FPS = 60;
const MATCHES_TIMEOUT_MS = 30_000;

/**
 * A whole match between two hard boxers, a step at a time as the host plays
 * it: how many minutes of fighting it took and how many rounds. With
 * `guest`, boxer two fights the ring a guest's browser sees — the host's
 * snapshot, sent over the wire and copied onto the guest's own state.
 */
function hardMatch(seed, { guest = false } = {}) {
  const ais = {
    1: createBoxingAI({ difficulty: "hard", rng: mulberry32(seed * 13 + 1) }),
    2: createBoxingAI({ difficulty: "hard", rng: mulberry32(seed * 7 + 5) }),
  };
  let state = { ...createInitialState(), phase: PHASE.FIGHTING };
  let seen = createInitialState();
  let pressed = { 1: false, 2: false };
  let frames = 0;
  let rounds = 0;

  while (state.phase !== PHASE.MATCH_OVER) {
    seen = { ...seen, ...SNAPSHOT.decode(SNAPSHOT.encode(state)) };
    const inputs = {
      1: ais[1].nextInputs({ state, player: 1 }),
      2: ais[2].nextInputs({ state: guest ? seen : state, player: 2 }),
    };
    ({ state, pressed } = stepTick(state, inputs, pressed));
    frames++;

    const end = checkRoundEnd(state);
    if (!end.ended) continue;
    rounds++;
    state = advanceRound(state, end.roundWinner);
    if (state.phase === PHASE.MATCH_OVER) break;
    state = { ...resetForNewRound(state), phase: PHASE.FIGHTING };
    pressed = { 1: false, 2: false };
    ais[1].forget();
    ais[2].forget();
  }
  return { minutes: frames / (60 * FPS), rounds };
}

describe("Hex Boxing, two hard boxers", () => {
  it.each([
    ["on the host", false],
    ["with boxer two on a guest's browser", true],
  ])(
    "trade punches %s for minutes, each round ending before its bell",
    (_where, guest) => {
      const matches = [1, 2, 3, 4].map((seed) => hardMatch(seed, { guest }));
      const minutes = matches.reduce((sum, m) => sum + m.minutes, 0);
      const rounds = matches.reduce((sum, m) => sum + m.rounds, 0);

      expect(minutes / matches.length).toBeGreaterThan(1.2);
      // A knockout ends a round well inside its two minutes.
      expect(minutes / rounds).toBeLessThan(ROUND_DURATION / (60 * FPS));
    },
    MATCHES_TIMEOUT_MS,
  );
});
