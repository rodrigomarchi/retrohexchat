import { calibrate } from "../../../support/games/calibration.js";
import { averagePaddlePlayer } from "../../../support/games/calibration_players/paddle.js";
import { askAsTheEngineDoes } from "../../../support/games/calibration_players/engine_ai.js";
import { mulberry32 } from "../../../support/games/seeded_random.js";
import { createWarlordAI, predictWarlordInterceptY } from "../../../../js/lib/games/warlords/ai.js";
import {
  CANVAS_H,
  createInitialState,
  INITIAL_BALL_SPEED,
  MAX_BALL_SPEED,
  P1_SHIELD_X,
  P2_SHIELD_X,
  releaseBall,
  serveFireball,
  SHIELD_H,
  SHIELD_W,
  stepTick,
} from "../../../../js/lib/games/warlords/physics.js";
import { PHASE } from "../../../../js/lib/games/warlords/protocol.js";

const MAX_RALLY_FRAMES = 20000;
const NO_KEYS = Object.freeze({ up: false, down: false, space: false });

/**
 * An average player at shield one, who never catches.
 * @param {() => number} random
 */
function averagePlayer(random) {
  return averagePaddlePlayer(random, {
    coming: (state) => state.caughtBy === 0 && state.fireballVX < 0,
    speed: (state) => state.fireballSpeed,
    slowest: INITIAL_BALL_SPEED,
    fastest: MAX_BALL_SPEED,
    ball: (state) => state.fireballY,
    arrival: (state) => predictWarlordInterceptY(state, 1),
    at: (state) => state.shield1Y,
    length: SHIELD_H,
    span: CANVAS_H,
  });
}

/**
 * One rally between the shields, a tick of play at a time as the host plays
 * it, catches and releases included: served at a speed anywhere from the
 * serve's to the top one, as rallies come later in a round, and over once
 * the fireball gets past a shield. The castles behind are left out.
 * @returns {boolean} whether the AI won
 */
function play({ difficulty, seed }) {
  const ai = createWarlordAI({ difficulty, rng: mulberry32(seed ^ 0x776172) });
  const ask = askAsTheEngineDoes(ai, difficulty);
  const random = mulberry32(seed ^ 0x706c61);
  const player = averagePlayer(random);
  const served = serveFireball(
    {
      ...createInitialState(),
      p1Bricks: [],
      p2Bricks: [],
      round: random() < 0.5 ? 1 : 2,
      phase: PHASE.PLAYING,
    },
    random,
  );
  const speed = INITIAL_BALL_SPEED + random() * (MAX_BALL_SPEED - INITIAL_BALL_SPEED);
  const scale = speed / served.fireballSpeed;
  let state = {
    ...served,
    fireballVX: served.fireballVX * scale,
    fireballVY: served.fireballVY * scale,
    fireballSpeed: speed,
  };
  let spaceHeld = false;

  for (let frame = 0; frame < MAX_RALLY_FRAMES; frame++) {
    state = { ...state, shield1Y: player(state) };
    const remote = ask(state);
    // As the game does it: a caught fireball goes when Space is let go.
    if (spaceHeld && !remote.space) state = releaseBall(state, 2);
    spaceHeld = remote.space;
    state = stepTick(state, NO_KEYS, remote).state;

    if (state.fireballX < P1_SHIELD_X) return true;
    if (state.fireballX > P2_SHIELD_X + SHIELD_W) return false;
  }
  return false;
}

calibrate("warlords", { play, label: "rallies" });
