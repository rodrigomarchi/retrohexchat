import { calibrate } from "../../../support/games/calibration.js";
import { missChance } from "../../../support/games/calibration_players/paddle.js";
import { askAsTheEngineDoes } from "../../../support/games/calibration_players/engine_ai.js";
import { mulberry32 } from "../../../support/games/seeded_random.js";
import { createTennisAI, servingReadyPosition } from "../../../../js/lib/games/hex_tennis/ai.js";
import {
  BALL_INITIAL_SPEED,
  BALL_MAX_SPEED,
  COURT_CENTER_X,
  COURT_LEFT,
  COURT_RIGHT,
  COURT_TOP,
  createInitialState,
  HIT_ZONE_W,
  stepRally,
  stepServing,
} from "../../../../js/lib/games/hex_tennis/physics.js";
import { GAME_MODE, PHASE } from "../../../../js/lib/games/hex_tennis/protocol.js";

// They meet the ball this deep in their half, and aim at a random spot along
// the far baseline this far inside the sidelines, a little off.
const PLAYER_CONTACT_Y = 360;
const PLAYER_AIM_MARGIN = 40;
const PLAYER_AIM_SPREAD = 0.15;
// Before serving they take a moment in the ready position.
const PLAYER_SERVE_FRAMES = 30;
const MAX_POINT_FRAMES = 60 * 60;
const NO_KEYS = Object.freeze({ up: false, down: false, left: false, right: false, serve: false });
const SERVE_KEY = Object.freeze({ ...NO_KEYS, serve: true });

/**
 * An average player in the near court. Once per ball coming their way they
 * let it go when it is heading wide, miss it now and then — more often the
 * faster it comes — or meet it at the spot along their hit zone that sends
 * it toward a corner they picked. A ball they let go finds them across the
 * court from it.
 * @param {() => number} random
 * @returns {(state: object) => {x: number, y: number}} where player one stands this tick
 */
function averagePlayer(random) {
  let meet = null;
  let arrivalX = COURT_CENTER_X;
  return (state) => {
    const { ball } = state;
    if (ball.vy <= 0) {
      meet = null;
      return { x: state.p1x, y: PLAYER_CONTACT_Y };
    }
    if (meet === null) {
      arrivalX = ball.x + ball.vx * ((PLAYER_CONTACT_Y - ball.y) / ball.vy);
      const wide = arrivalX < COURT_LEFT || arrivalX > COURT_RIGHT;
      if (wide || random() < missChance(ball.speed, BALL_INITIAL_SPEED, BALL_MAX_SPEED)) {
        meet = "leave";
      } else {
        const aimX =
          COURT_LEFT +
          PLAYER_AIM_MARGIN +
          random() * (COURT_RIGHT - COURT_LEFT - 2 * PLAYER_AIM_MARGIN);
        const angle = Math.atan2(aimX - arrivalX, PLAYER_CONTACT_Y - COURT_TOP);
        const spread = (random() * 2 - 1) * PLAYER_AIM_SPREAD;
        meet = Math.max(-0.95, Math.min(0.95, angle / (Math.PI / 4) + spread));
      }
    }
    if (meet === "leave") {
      return { x: arrivalX < COURT_CENTER_X ? COURT_RIGHT : COURT_LEFT, y: PLAYER_CONTACT_Y };
    }
    return { x: ball.x - (meet * HIT_ZONE_W) / 2, y: PLAYER_CONTACT_Y };
  };
}

/**
 * One point, a tick at a time as the host plays it, from a serve by either
 * side; the AI walks to its spot and serves by its own controls.
 * @returns {boolean} whether the AI won it
 */
function play({ difficulty, seed }) {
  const ai = createTennisAI({ difficulty, rng: mulberry32(seed ^ 0x74656e) });
  const ask = askAsTheEngineDoes(ai, difficulty);
  const random = mulberry32(seed ^ 0x706c61);
  let player = averagePlayer(random);
  let state = {
    ...createInitialState(GAME_MODE.CLASSIC),
    server: random() < 0.5 ? 1 : 2,
    totalPointsInGame: Math.floor(random() * 4),
    phase: PHASE.SERVING,
  };
  let pressed = { local: false, remote: false };
  let servingFrames = 0;

  for (let frame = 0; frame < MAX_POINT_FRAMES; frame++) {
    if (state.phase === PHASE.SERVING) {
      const ready = servingReadyPosition(state, 1);
      state = { ...state, p1x: ready.x, p1y: ready.y };
      const remote = ask(state);
      servingFrames++;
      const local =
        state.server === 1 && servingFrames >= PLAYER_SERVE_FRAMES ? SERVE_KEY : NO_KEYS;
      const tick = stepServing(state, local, remote, pressed, random);
      ({ state, pressed } = tick);
      if (tick.served) {
        player = averagePlayer(random);
        servingFrames = 0;
      }
      continue;
    }

    const stand = player(state);
    state = { ...state, p1x: stand.x, p1y: stand.y };
    const remote = ask(state);
    const tick = stepRally(state, NO_KEYS, remote);
    state = tick.state;
    if (tick.point) return state.pointWinner === 2;
  }
  return false;
}

calibrate("hex_tennis", { play, label: "points" });
