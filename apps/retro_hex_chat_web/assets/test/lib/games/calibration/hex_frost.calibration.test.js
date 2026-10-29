import { calibrate } from "../../../support/games/calibration.js";
import { engineAI } from "../../../support/games/calibration_players/engine_ai.js";
import { createFrostPlayer } from "../../../support/games/calibration_players/hex_frost.js";
import { mulberry32 } from "../../../support/games/seeded_random.js";
import { createHexFrostAI } from "../../../../js/lib/games/hex_frost/ai.js";
import {
  createInitialState,
  determineWinner,
  startNextRound,
  stepTick,
} from "../../../../js/lib/games/hex_frost/physics.js";
import { GAME_MODE, PHASE } from "../../../../js/lib/games/hex_frost/protocol.js";
import { aiRandom } from "../../../../js/lib/games/core/rng.js";

const NEUTRAL = { left: false, right: false, up: false, down: false };
// Every round lasts at most the temperature's 45 s; five rounds fit well inside.
const MAX_FRAMES = 60 * 60 * 6;

/**
 * One Arctic Race match, stepped as the host's building phase steps it — the
 * countdowns between rounds skipped, since nobody moves in them — between
 * the scripted player as P1 and the AI as P2. True when the AI wins it.
 */
function play({ difficulty, seed }) {
  const ai = engineAI(createHexFrostAI({ difficulty, rng: aiRandom(seed) }), difficulty);
  const person = createFrostPlayer({ rng: mulberry32(seed) });
  let state = { ...createInitialState(GAME_MODE.ARCTIC_RACE, seed), phase: PHASE.BUILDING };

  for (let frame = 0; frame < MAX_FRAMES; frame++) {
    const p1 = { ...NEUTRAL, ...person.nextInputs({ state }) };
    const p2 = { ...NEUTRAL, ...ai.ask(state) };
    state = stepTick(state, p1, p2);
    if (state.phase === PHASE.ROUND_END) {
      // Both sides see the round end before the next one starts; the engine
      // watches it without asking the AI anything.
      person.nextInputs({ state });
      ai.watch(state);
      state = startNextRound(state);
      if (state.phase === PHASE.FINISHED) break;
      state = { ...state, phase: PHASE.BUILDING };
    }
  }

  return determineWinner(state) === 2;
}

calibrate("hex_frost", { play, trials: 400 });
