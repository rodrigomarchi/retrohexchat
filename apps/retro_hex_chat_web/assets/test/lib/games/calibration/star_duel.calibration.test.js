import { calibrate } from "../../../support/games/calibration.js";
import { mulberry32 } from "../../../support/games/seeded_random.js";
import {
  STAR_DUEL_AI_DIFFICULTIES,
  createStarDuelAI,
  incomingMissileThreat,
  toroidalVector,
} from "../../../../js/lib/games/star_duel/ai.js";
import {
  CANVAS_H,
  CANVAS_W,
  MISSILE_SPEED,
  WIN_SCORE,
  createInitialState,
  spawnShips,
  stepTick,
} from "../../../../js/lib/games/star_duel/physics.js";
import { GAME_MODE, PHASE } from "../../../../js/lib/games/star_duel/protocol.js";
import { rotationDelta } from "../../../../js/lib/games/core/ai.js";
import {
  createLookout,
  createPace,
  gaussian,
} from "../../../support/games/calibration_players/duel.js";

// The average player: takes a fresh look every 12 frames with an aim error
// of its own, leads the rival by half the missile's flight, fires when the
// nose is about on it (at most one missile every 20 frames), and turns side
// on to 40% of the missiles it notices coming.
const PLAYER = {
  lookEvery: 12,
  aimSigma: 0.06,
  aimTolerance: 0.07,
  fireEvery: 20,
  dodgeOdds: 0.4,
  lead: 0.5,
};
const PLAYER_SIGHT = {
  ...STAR_DUEL_AI_DIFFICULTIES.easy,
  threatFrames: 20,
  threatRadius: 120,
  missileAvoidMargin: 6,
};
// A point no one wins in this many frames starts over from the spawn.
const STALEMATE_FRAMES = 3600;
const RELEASED = { fire1: false, fire2: false, warp1: false, warp2: false };

const wrap = (value, max) => ((value % max) + max) % max;

function averagePlayer(random) {
  const lookout = createLookout(PLAYER.lookEvery);
  const pace = createPace(PLAYER.fireEvery);
  let dodgeFor = null;
  let dodging = false;

  return (state) => {
    const frame = lookout.tick();
    pace.tick();
    const me = state.ship1;
    const rival = state.ship2;

    const look = lookout.plan(() => {
      const flight =
        (toroidalVector(me.x, me.y, rival.x, rival.y).distance / MISSILE_SPEED) * PLAYER.lead;
      const aim = toroidalVector(
        me.x,
        me.y,
        wrap(rival.x + rival.vx * flight, CANVAS_W),
        wrap(rival.y + rival.vy * flight, CANVAS_H),
      );
      const next = {
        angle: Math.atan2(aim.dy, aim.dx) + gaussian(random) * PLAYER.aimSigma,
        distance: aim.distance,
      };
      const threat = incomingMissileThreat(state, 1, PLAYER_SIGHT);
      if (threat && threat.missile !== dodgeFor) {
        dodgeFor = threat.missile;
        dodging = random() < PLAYER.dodgeOdds;
      }
      if (threat && dodging) {
        next.evade = Math.atan2(threat.missile.vy, threat.missile.vx) + Math.PI / 2;
      }
      return next;
    });

    const evading = look.evade !== undefined;
    const turn = rotationDelta(me.rotation, evading ? look.evade : look.angle);
    const inputs = {
      rotateLeft: turn < -0.04,
      rotateRight: turn > 0.04,
      thrust: evading ? Math.abs(turn) < 1 : look.distance > 170 && Math.abs(turn) < 0.6,
      fire: false,
      warp: false,
    };
    if (
      !evading &&
      pace.ready() &&
      !rival.invulnerable &&
      Math.abs(rotationDelta(me.rotation, look.angle)) < PLAYER.aimTolerance
    ) {
      inputs.fire = true;
      pace.spend();
    }
    if (evading && frame % PLAYER.lookEvery === PLAYER.lookEvery - 1) delete look.evade;
    return inputs;
  };
}

function playMatch({ difficulty, seed }) {
  const ai = createStarDuelAI({ difficulty, rng: mulberry32(seed * 7919 + 1) });
  const player = averagePlayer(mulberry32(seed));
  const random = mulberry32(seed * 31 + 7);
  let state = { ...createInitialState(GAME_MODE.OPEN_SPACE, 1), phase: PHASE.PLAYING };

  while (state.score1 < WIN_SCORE && state.score2 < WIN_SCORE) {
    let pressed = RELEASED;
    for (let frame = 0; frame < STALEMATE_FRAMES; frame++) {
      const inputs = { 1: player(state), 2: ai.nextInputs({ state, difficulty, player: 2 }) };
      const step = stepTick(state, inputs, pressed, random);
      state = step.state;
      pressed = step.pressed;
      if (step.events.scored || !state.ship1.alive || !state.ship2.alive) break;
    }
    // The round over between kills: the AI forgets the round, as the engine has it do.
    ai.forget();
    state = spawnShips(state);
  }

  return state.score2 > state.score1;
}

calibrate("Star Duel", { play: playMatch, trials: 150 });
