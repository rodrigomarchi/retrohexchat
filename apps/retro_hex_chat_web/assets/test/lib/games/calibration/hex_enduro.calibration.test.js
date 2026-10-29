import { calibrate } from "../../../support/games/calibration.js";
import { mulberry32 } from "../../../support/games/seeded_random.js";
import { askAsTheEngineDoes } from "../../../support/games/calibration_players/engine_ai.js";
import { createDelayedView } from "../../../../js/lib/games/core/ai.js";
import {
  chooseEnduroTarget,
  createHexEnduroAI,
  laneRisk,
  maybeApplyLaneMistake,
  movementInputs,
} from "../../../../js/lib/games/hex_enduro/ai.js";
import {
  createInitialState,
  determineWinner,
  stepTick,
} from "../../../../js/lib/games/hex_enduro/physics.js";
import { GAME_MODE, PHASE } from "../../../../js/lib/games/hex_enduro/protocol.js";

// The average driver: sees the road 15 frames (250 ms) late, picks a lane every
// 10 frames from the traffic 450 deep, one pick in ten the lane beside the right
// one; floors it, heads for fuel under 400, and fires turbo on a clear lane.
const PLAYER = Object.freeze({
  delay: 15,
  every: 10,
  plan: Object.freeze({
    laneMistake: 0.1,
    threatZ: 450,
    fuelAt: 400,
    fuelZ: 1500,
    targetSpeed: 800,
    brakeSpeed: 450,
    slipstreamBias: 0.3,
  }),
});

function averageDriver(random) {
  const view = createDelayedView();
  let target = null;
  let frame = 0;
  let pressed = false;

  return (state) => {
    const seen = view.see(state, PLAYER.delay);

    if (frame++ % PLAYER.every === 0 || !target) {
      target = chooseEnduroTarget(seen, 1, PLAYER.plan, random);
      target = maybeApplyLaneMistake(target, seen, 1, PLAYER.plan, random);
    }

    const me = state.p1;
    const ready = me.turboCooldown === 0 && me.boost === 0 && me.collisionTimer === 0;
    const fuelled = state.mode === GAME_MODE.SPRINT || me.fuel > 300;
    const turbo = ready && fuelled && !pressed && laneRisk(seen, me.lane, 1, PLAYER.plan) < 4;
    pressed = turbo;
    return { ...movementInputs(state, 1, target), turbo };
  };
}

/** One race as the host steps it, the AI driving the second car. */
function race(mode, { difficulty, seed }) {
  let state = { ...createInitialState(mode, (seed * 7919 + 1000) >>> 0), phase: PHASE.RACING };
  let turboHeld = { p1: false, p2: false };
  const ai = askAsTheEngineDoes(
    createHexEnduroAI({ difficulty, rng: mulberry32(seed ^ 0x5a5a) }),
    difficulty,
  );
  const driver = averageDriver(mulberry32(seed ^ 0x1234));

  while (state.phase === PHASE.RACING) {
    const remote = ai(state);
    ({ state, turboHeld } = stepTick(state, driver(state), remote, turboHeld));
  }

  return determineWinner(state) === 2;
}

// The ten-minute duel is the slowest race to play, so it plays fewer of them.
calibrate("hex_enduro", { play: (trial) => race(GAME_MODE.CLASSIC_DUEL, trial), trials: 100 });
calibrate("hex_enduro_night", { play: (trial) => race(GAME_MODE.NIGHT_RACE, trial), trials: 200 });
calibrate("hex_enduro_sprint", { play: (trial) => race(GAME_MODE.SPRINT, trial), trials: 200 });
