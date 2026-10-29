import { calibrate } from "../../../support/games/calibration.js";
import { averagePaddlePlayer } from "../../../support/games/calibration_players/paddle.js";
import { askAsTheEngineDoes } from "../../../support/games/calibration_players/engine_ai.js";
import { mulberry32 } from "../../../support/games/seeded_random.js";
import {
  createBreakoutAI,
  predictBreakoutInterceptX,
} from "../../../../js/lib/games/breakout/ai.js";
import { partnerDifficulty } from "../../../../js/lib/games/breakout/index.js";
import {
  CANVAS_W,
  createInitialState,
  INITIAL_BALL_SPEED,
  MAX_BALL_SPEED,
  PADDLE_W,
  serveAfter,
  stepTick,
} from "../../../../js/lib/games/breakout/physics.js";
import { PHASE } from "../../../../js/lib/games/breakout/protocol.js";

// The pause after a lost life and before the serve, as the game's flow has them.
const BETWEEN_LIVES_FRAMES = 90 + 48;
const MAX_FRAMES = 60 * 60 * 30;
const NO_KEYS = Object.freeze({ left: false, right: false });

// Block Breakers is co-op: the AI is the player's partner, and whether a board
// is cleared rests mostly on the player — even a partner that never misses
// clears few boards beside an average one. So a trial is one ball that reaches
// the partner's end of the board, and a "win" is the partner sending it back.
// The difficulty is the one the player picks: an easy game gets a partner that
// misses a ball in ten or so, a hard game one that misses two in five.
const PARTNER_RETURNS_TARGETS = Object.freeze({ easy: 0.92, normal: 0.8, hard: 0.6 });
// Which of the balls that reach the partner a trial judges: one of the first
// few dozen of a board, so early, slow balls and later, faster ones both count.
const LATEST_BALL = 40;

/**
 * An average player at the bottom paddle, for one ball in play.
 * @param {() => number} random
 */
function averagePlayer(random) {
  return averagePaddlePlayer(random, {
    coming: (state) => state.ballVY > 0,
    speed: (state) => state.ballSpeed,
    slowest: INITIAL_BALL_SPEED,
    fastest: MAX_BALL_SPEED,
    ball: (state) => state.ballX,
    arrival: (state) => predictBreakoutInterceptX(state, 1),
    at: (state) => state.paddle1X,
    length: PADDLE_W,
    span: CANVAS_W,
  });
}

/**
 * Boards played a tick at a time as the host plays them, with the pauses
 * between lives kept for the AI and the countdown left out, up to the ball
 * the trial judges among those that reach the partner.
 * @returns {boolean} whether the partner sent that ball back
 */
function play({ difficulty, seed }) {
  const partner = partnerDifficulty(difficulty);
  const ai = createBreakoutAI({ difficulty: partner, rng: mulberry32(seed ^ 0x62726b) });
  const ask = askAsTheEngineDoes(ai, partner);
  const random = mulberry32(seed ^ 0x706c61);
  let state = serveAfter(createInitialState(), null, random);
  let player = averagePlayer(random);
  let ballsLeft = 1 + Math.floor(random() * LATEST_BALL);

  for (let frame = 0; frame < MAX_FRAMES; frame++) {
    state = { ...state, paddle1X: player(state) };
    const comingUp = state.ballVY < 0;
    const remote = ask(state);
    const tick = stepTick(state, NO_KEYS, remote);
    state = tick.state;

    const returned = comingUp && tick.events.paddleHit;
    const missed = tick.events.exitSide === "top";
    if ((returned || missed) && --ballsLeft === 0) return returned;
    if (state.phase === PHASE.FINISHED) {
      state = serveAfter(createInitialState(), null, random);
      player = averagePlayer(random);
    } else if (state.phase === PHASE.LIFE_LOST) {
      for (let pause = 0; pause < BETWEEN_LIVES_FRAMES; pause++) {
        ask(state);
      }
      state = serveAfter(state, tick.events.exitSide, random);
      player = averagePlayer(random);
    }
  }
  return false;
}

calibrate("breakout", { play, targets: PARTNER_RETURNS_TARGETS, label: "balls returned" });
