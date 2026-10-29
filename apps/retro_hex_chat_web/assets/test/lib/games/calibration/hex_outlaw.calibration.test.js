import { calibrate } from "../../../support/games/calibration.js";
import { mulberry32 } from "../../../support/games/seeded_random.js";
import { createOutlawAI, predictIncomingBulletY } from "../../../../js/lib/games/hex_outlaw/ai.js";
import {
  createInitialState,
  resetForNewRound,
  stepTick,
} from "../../../../js/lib/games/hex_outlaw/physics.js";
import { GAME_MODE, PHASE } from "../../../../js/lib/games/hex_outlaw/protocol.js";
import {
  createLookout,
  createPace,
  gaussian,
} from "../../../support/games/calibration_players/duel.js";

// The average player: takes a fresh look every 12 frames with an aim error
// of its own, sometimes wanders off the line, fires when it thinks it is
// lined up (at most one shot every 30 frames), and steps out of 60% of the
// bullets it notices, 14 frames after they leave the barrel.
const PLAYER = {
  lookEvery: 12,
  aimSigma: 8,
  fireWindow: 6,
  fireEvery: 30,
  wanderOdds: 0.25,
  dodgeOdds: 0.6,
  dodgeAfter: 14,
};
// A match nobody has won in this many frames counts as one the AI did not.
const MATCH_FRAMES = 60 * 60 * 15;

function averagePlayer(random) {
  const lookout = createLookout(PLAYER.lookEvery);
  const pace = createPace(PLAYER.fireEvery);
  let bulletAge = 0;
  let dodges = false;
  let dodgeDir = 0;

  return (s) => {
    lookout.tick();
    pace.tick();
    if (!s.b2active) bulletAge = 0;
    else if (bulletAge++ === 0) {
      dodges = random() < PLAYER.dodgeOdds;
      dodgeDir = 0;
    }

    if (s.b2active && dodges && bulletAge >= PLAYER.dodgeAfter) {
      const y = predictIncomingBulletY(s, 1);
      if (y !== null && Math.abs(y - s.p1y) < 16 && !dodgeDir) {
        dodgeDir = s.p1y < 80 ? 1 : s.p1y > 420 ? -1 : y > s.p1y ? -1 : 1;
      }
      if (dodgeDir) return { up: dodgeDir < 0, down: dodgeDir > 0, left: false, right: false };
    }

    const { goal, wander } = lookout.plan(() => ({
      goal: s.p2y + gaussian(random) * PLAYER.aimSigma,
      wander: random() < PLAYER.wanderOdds ? (random() < 0.5 ? -40 : 40) : 0,
    }));
    const delta = goal + wander - s.p1y;
    const fire =
      pace.ready() && !s.b1active && wander === 0 && Math.abs(goal - s.p1y) < PLAYER.fireWindow;
    if (fire) pace.spend();
    return { up: delta < -3, down: delta > 3, left: false, right: false, fire };
  };
}

function playMatch(gameMode, { difficulty, seed }) {
  const ai = createOutlawAI({ difficulty, rng: mulberry32(seed * 7919 + 1) });
  const player = averagePlayer(mulberry32(seed));
  let state = { ...createInitialState(gameMode), phase: PHASE.PLAYING };
  let pressed = { 1: false, 2: false };
  const aimUp = { 1: false, 2: false };

  for (let frame = 0; frame < MATCH_FRAMES && state.phase !== PHASE.MATCH_OVER; frame++) {
    let inputs = { 1: {}, 2: {} };
    if (state.phase === PHASE.PLAYING) {
      inputs = { 1: player(state), 2: ai.nextInputs({ state, difficulty, player: 2 }) };
      // The AI's aim counts for this frame's shot, as in a solo match.
      if (inputs[2].up) aimUp[2] = true;
      if (inputs[2].down) aimUp[2] = false;
    }
    const step = stepTick(state, inputs, pressed, aimUp);
    // Every change of phase — the freeze after a hit, its end, the round over
    // — starts the AI's memories afresh, as the engine does.
    if (step.state.phase !== state.phase) ai.forget();
    state = step.state;
    pressed = step.pressed;

    if (state.phase === PHASE.ROUND_OVER) {
      // The round over and the bell, then the next round.
      state = { ...resetForNewRound(state), phase: PHASE.PLAYING };
      pressed = { 1: false, 2: false };
    }
  }

  return state.phase === PHASE.MATCH_OVER && state.roundWins2 > state.roundWins1;
}
for (const [label, gameMode] of [
  ["Quick Draw", GAME_MODE.QUICK_DRAW],
  ["Stagecoach", GAME_MODE.STAGECOACH],
  ["No Man's Land", GAME_MODE.NO_MANS_LAND],
]) {
  calibrate(`Hex Outlaw ${label}`, { play: (trial) => playMatch(gameMode, trial), trials: 150 });
}
