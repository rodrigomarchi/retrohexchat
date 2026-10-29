import { calibrate } from "../../../support/games/calibration.js";
import { mulberry32 } from "../../../support/games/seeded_random.js";
import { createBoxingAI, directionFacesOpponent } from "../../../../js/lib/games/hex_boxing/ai.js";
import {
  advanceRound,
  checkRoundEnd,
  createInitialState,
  resetForNewRound,
  stepTick,
} from "../../../../js/lib/games/hex_boxing/physics.js";
import { PHASE, PUNCH_STATE } from "../../../../js/lib/games/hex_boxing/protocol.js";
import {
  createLookout,
  createPace,
  gaussian,
  playRounds,
} from "../../../support/games/calibration_players/duel.js";

// The average player: re-reads the rival every 12 frames and closes to about
// 30 px with an error of its own, throws when it is in range and about
// lined up (at most every 24 frames), and backs off from 40% of the punches
// it sees coming, 12 frames after their wind-up starts.
const PLAYER = {
  lookEvery: 12,
  distance: 30,
  errorPx: 6,
  alignPx: 9,
  punchEvery: 24,
  seeAfter: 12,
  backOffOdds: 0.4,
  backOffFrames: 10,
};
const IN_RANGE = 44;

function averagePlayer(random) {
  const lookout = createLookout(PLAYER.lookEvery);
  const pace = createPace(PLAYER.punchEvery);
  let seen = 0;
  let backing = 0;

  return (s) => {
    lookout.tick();
    pace.tick();
    const coming = s.b2punchState === PUNCH_STATE.WINDUP || s.b2punchState === PUNCH_STATE.PUNCHING;
    seen = coming ? seen + 1 : 0;
    if (seen === PLAYER.seeAfter && random() < PLAYER.backOffOdds) backing = PLAYER.backOffFrames;
    if (backing > 0) {
      backing--;
      return { up: false, down: false, left: true, right: false, punch: false };
    }

    const goal = lookout.plan(() => ({
      x: s.b2x - PLAYER.distance + gaussian(random) * PLAYER.errorPx,
      y: s.b2y + gaussian(random) * PLAYER.errorPx,
    }));
    const dx = goal.x - s.b1x;
    const dy = goal.y - s.b1y;
    const inputs = { up: dy < -3, down: dy > 3, left: dx < -3, right: dx > 3, punch: false };

    const rx = s.b2x - s.b1x;
    const ry = s.b2y - s.b1y;
    const ready = pace.ready() && s.b1punchState === PUNCH_STATE.IDLE;
    if (Math.hypot(rx, ry) < IN_RANGE && ready) {
      if (!directionFacesOpponent(s.b1dir, rx, ry)) {
        return { up: false, down: false, left: rx < 0, right: rx > 0, punch: false };
      }
      if (Math.abs(ry) < PLAYER.alignPx) {
        inputs.punch = true;
        pace.spend();
      }
    }
    return inputs;
  };
}

function playMatch({ difficulty, seed }) {
  const ai = createBoxingAI({ difficulty, rng: mulberry32(seed * 7919 + 1) });
  const player = averagePlayer(mulberry32(seed));
  const end = playRounds(
    { ...createInitialState(), phase: PHASE.FIGHTING },
    {
      frame: (state, pressed) => {
        const inputs = { 1: player(state), 2: ai.nextInputs({ state, difficulty, player: 2 }) };
        return stepTick(state, inputs, pressed);
      },
      ai,
      rules: { checkRoundEnd, advanceRound, resetForNewRound },
      phases: { play: PHASE.FIGHTING, over: PHASE.MATCH_OVER },
    },
  );

  return end.roundWins2 > end.roundWins1;
}

calibrate("Hex Boxing", { play: playMatch, trials: 150 });
