import { calibrate } from "../../../support/games/calibration.js";
import { mulberry32 } from "../../../support/games/seeded_random.js";
import {
  PIXEL_TANKS_AI_DIFFICULTIES,
  chooseTankTarget,
  createPixelTanksAI,
  lineOfSightClear,
  tankMovementInputs,
} from "../../../../js/lib/games/pixel_tanks/ai.js";
import {
  advanceRound,
  checkRoundEnd,
  createInitialState,
  decodeMaze,
  getMatchWinner,
  resetForNewRound,
  stepTick,
} from "../../../../js/lib/games/pixel_tanks/physics.js";
import { GAME_MODE, PHASE } from "../../../../js/lib/games/pixel_tanks/protocol.js";
import { normalizeAngle, rotationDelta } from "../../../../js/lib/games/core/ai.js";
import {
  createLookout,
  createPace,
  gaussian,
  playRounds,
} from "../../../support/games/calibration_players/duel.js";

const RELEASED = { rotateLeft: false, rotateRight: false, forward: false, fire: false };

// The average player: takes a fresh look every 12 frames (~200 ms) with an
// aim error of its own, fires when the barrel is about on the rival (at most
// one shell every 40 frames), and sidesteps half the shells it sees coming.
const PLAYER = { lookEvery: 12, aimSigma: 0.07, aimTolerance: 0.08, fireEvery: 40, dodgeOdds: 0.5 };
const PLAYER_SIGHT = {
  ...PIXEL_TANKS_AI_DIFFICULTIES.normal,
  standoffDistance: 170,
  threatFrames: 20,
  threatRadius: 140,
  threatMargin: 10,
};

function averagePlayer(random) {
  const lookout = createLookout(PLAYER.lookEvery);
  const pace = createPace(PLAYER.fireEvery);

  return (state, walls) => {
    lookout.tick();
    pace.tick();
    if (state.respawnPause > 0) return RELEASED;

    const target = lookout.plan(() => {
      const seen = chooseTankTarget(state, 1, walls, PLAYER_SIGHT);
      const dodges = seen.kind !== "evade" || random() < PLAYER.dodgeOdds;
      const chosen = dodges
        ? seen
        : chooseTankTarget({ ...state, m2Active: false }, 1, walls, PLAYER_SIGHT);
      return {
        ...chosen,
        angle: normalizeAngle(chosen.angle + gaussian(random) * PLAYER.aimSigma),
      };
    });

    const movement = tankMovementInputs(state.tank1Rot, target, {
      ...PLAYER_SIGHT,
      turnDeadzone: 0.05,
    });
    const fire =
      pace.ready() &&
      target.kind === "attack" &&
      !state.m1Active &&
      state.tank1Cooldown === 0 &&
      !state.tank2Invuln &&
      Math.abs(rotationDelta(state.tank1Rot, target.angle)) < PLAYER.aimTolerance &&
      lineOfSightClear(state.tank1X, state.tank1Y, state.tank2X, state.tank2Y, walls);
    if (fire) pace.spend();
    return { ...movement, fire };
  };
}

function playMatch({ difficulty, seed }) {
  const ai = createPixelTanksAI({ difficulty, rng: mulberry32(seed * 7919 + 1) });
  const player = averagePlayer(mulberry32(seed));
  const mazeIndex = 1 + (seed % 5);
  const walls = decodeMaze(mazeIndex);
  const end = playRounds(
    { ...createInitialState(GAME_MODE.RICOCHET, mazeIndex), phase: PHASE.PLAYING },
    {
      frame: (state, pressed) => {
        const inputs = {
          1: player(state, walls),
          2: ai.nextInputs({ state, walls, difficulty, player: 2 }),
        };
        return stepTick(state, walls, inputs, pressed);
      },
      ai,
      rules: { checkRoundEnd, advanceRound, resetForNewRound },
      phases: { play: PHASE.PLAYING, over: PHASE.MATCH_OVER },
    },
  );

  return getMatchWinner(end) === 2;
}

calibrate("Pixel Tanks", { play: playMatch, trials: 120 });
