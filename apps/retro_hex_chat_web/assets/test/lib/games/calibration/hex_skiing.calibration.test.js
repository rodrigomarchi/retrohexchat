import { calibrate } from "../../../support/games/calibration.js";
import { mulberry32 } from "../../../support/games/seeded_random.js";
import { createDelayedView } from "../../../../js/lib/games/core/ai.js";
import {
  chooseSkiingTarget,
  createHexSkiingAI,
  gaussian,
  movementInputs,
  VIEW_AHEAD,
} from "../../../../js/lib/games/hex_skiing/ai.js";
import {
  createInitialState,
  startNextRound,
  stepTick,
} from "../../../../js/lib/games/hex_skiing/physics.js";
import { GAME_MODE, PHASE } from "../../../../js/lib/games/hex_skiing/protocol.js";

// The average player's line: what is on screen, a gate's middle, around the trees.
const PLAYER_LINE = Object.freeze({
  obstacleLookAhead: VIEW_AHEAD,
  gateLookAhead: VIEW_AHEAD,
  itemLookAhead: VIEW_AHEAD,
  safetyWidth: 28,
  candidateStep: 18,
  deadzone: 12,
  velocityLead: 8,
  gatePadding: 10,
});
const PLAYER_REACTION = 12; // frames, 200 ms
const PLAYER_EVERY = 4; // frames between two looks
const PLAYER_AIM = 6; // px, the spread of where they steer

// A match runs for at most three rounds of a few minutes each.
const MAX_STEPS = 60 * 60 * 20;

/**
 * An average player at the keys of skier one: sees the slope on screen
 * PLAYER_REACTION frames late, picks a line every PLAYER_EVERY frames and
 * steers a little off it.
 * @param {() => number} random
 */
function averagePlayer(random) {
  const view = createDelayedView();
  let target = null;
  let frame = 0;

  return (state) => {
    const seen = view.see(state, PLAYER_REACTION);
    if (state.p1.stunTimer > 0) return { left: false, right: false };
    if (frame++ % PLAYER_EVERY === 0 || !target) {
      const line = chooseSkiingTarget(seen, 1, PLAYER_LINE);
      target = { x: line.x + gaussian(random) * PLAYER_AIM };
    }
    return movementInputs(state.p1, target, PLAYER_LINE);
  };
}

/**
 * One best-of-three Alpine race, ticked as the game's host ticks it, with the
 * countdowns between rounds left out.
 * @returns {boolean} whether the AI won
 */
function play({ difficulty, seed }) {
  const ai = createHexSkiingAI({ difficulty, rng: mulberry32(seed ^ 0x736b69) });
  const random = mulberry32(seed ^ 0x706c61);
  let player = averagePlayer(random);
  let state = { ...createInitialState(GAME_MODE.ALPINE_RACE, seed), phase: PHASE.RACING };

  for (let step = 0; step < MAX_STEPS && state.phase !== PHASE.FINISHED; step++) {
    if (state.phase === PHASE.ROUND_END) {
      // A new slope: both sides start the round with nothing seen of it,
      // the AI told so as the engine tells it on every phase change.
      state = { ...startNextRound(state), phase: PHASE.RACING };
      ai.forget();
      player = averagePlayer(random);
      continue;
    }
    const p2 = ai.nextInputs({ state, player: 2, difficulty });
    state = stepTick(state, { p1: player(state), p2 });
  }

  return state.p2RoundWins > state.p1RoundWins;
}

calibrate("hex_skiing", { play, trials: 200 });
