import { calibrate } from "../../../support/games/calibration.js";
import { averagePaddlePlayer } from "../../../support/games/calibration_players/paddle.js";
import { askAsTheEngineDoes } from "../../../support/games/calibration_players/engine_ai.js";
import { mulberry32 } from "../../../support/games/seeded_random.js";
import { createPongAI, predictPaddleInterceptY } from "../../../../js/lib/games/pong/ai.js";
import {
  CANVAS_H,
  createInitialState,
  INITIAL_BALL_SPEED,
  MAX_BALL_SPEED,
  PADDLE_H,
  serveBall,
  stepTick,
} from "../../../../js/lib/games/pong/physics.js";
import { PHASE } from "../../../../js/lib/games/pong/protocol.js";

const SCORED_PAUSE_FRAMES = 60;
const MAX_RALLY_FRAMES = 20000;
const NO_KEYS = Object.freeze({ up: false, down: false });

/**
 * An average player at paddle one for one point.
 * @param {() => number} random
 */
function averagePlayer(random) {
  return averagePaddlePlayer(random, {
    coming: (state) => state.ballVX < 0,
    speed: (state) => state.ballSpeed,
    slowest: INITIAL_BALL_SPEED,
    fastest: MAX_BALL_SPEED,
    ball: (state) => state.ballY,
    arrival: (state) => predictPaddleInterceptY(state, 1),
    at: (state) => state.paddle1Y,
    length: PADDLE_H,
    span: CANVAS_H,
  });
}

/**
 * One match to 11, a tick of play at a time as the host plays it, with the
 * pause after each point kept for the AI and the countdown left out.
 * @returns {boolean} whether the AI won
 */
function play({ difficulty, seed }) {
  const ai = createPongAI({ difficulty, rng: mulberry32(seed ^ 0x706f6e) });
  const ask = askAsTheEngineDoes(ai, difficulty);
  const random = mulberry32(seed ^ 0x706c61);
  let state = { ...createInitialState(), lastScorer: random() < 0.5 ? 1 : 2 };

  while (state.phase !== PHASE.FINISHED) {
    state = serveBall({ ...state, phase: PHASE.PLAYING }, random);
    const player = averagePlayer(random);
    for (let frame = 0; frame < MAX_RALLY_FRAMES && state.phase === PHASE.PLAYING; frame++) {
      state = { ...state, paddle1Y: player(state) };
      const remote = ask(state);
      state = stepTick(state, NO_KEYS, remote).state;
    }
    for (let frame = 0; frame < SCORED_PAUSE_FRAMES; frame++) {
      ask(state);
    }
  }
  return state.winner === 2;
}

calibrate("pong", { play });
