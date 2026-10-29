import { calibrate } from "../../../support/games/calibration.js";
import { askAsTheEngineDoes } from "../../../support/games/calibration_players/engine_ai.js";
import { mulberry32 } from "../../../support/games/seeded_random.js";
import { createHockeyAI } from "../../../../js/lib/games/hex_hockey/ai.js";
import {
  createInitialState,
  RINK_BOTTOM,
  RINK_CY,
  RINK_RIGHT,
  RINK_TOP,
  resetForFaceoff,
  stepTick,
} from "../../../../js/lib/games/hex_hockey/physics.js";
import { GAME_MODE, PHASE } from "../../../../js/lib/games/hex_hockey/protocol.js";

// The average player sees the rink this many frames late, presses tackle at
// most this often when in reach, and shoots from somewhere in the attacking
// zone once they have turned toward the goal.
const PLAYER_REACTION = 12; // frames, 200 ms
const PLAYER_TACKLE_EVERY = 20;
const PLAYER_TACKLE_REACH = 18;
const SHOOTING_ZONE = Object.freeze({ fromX: 440, toX: 580, margin: 40 });
// The next goal from a face-off, given up on after two minutes of play.
const MAX_FRAMES = 120 * 60;
const DIRECTION_X = [1, 1, 0, -1, -1, -1, 0, 1];
const DIRECTION_Y = [0, 1, 1, 1, 0, -1, -1, -1];

/**
 * An average player skating player one, attacking the right goal: chases a
 * loose puck and the AI's carrier, tackles when close, and with the puck
 * skates to a spot they picked, turns toward the goal and shoots.
 * @param {() => number} random
 * @returns {(state: object, frame: number) => object} player one's inputs
 */
function averagePlayer(random) {
  const seen = [];
  let spot = null;
  const pickSpot = () => ({
    x: SHOOTING_ZONE.fromX + random() * (SHOOTING_ZONE.toX - SHOOTING_ZONE.fromX),
    y:
      RINK_TOP +
      SHOOTING_ZONE.margin +
      random() * (RINK_BOTTOM - RINK_TOP - 2 * SHOOTING_ZONE.margin),
  });

  return (state, frame) => {
    seen.push(structuredClone(state));
    if (seen.length > PLAYER_REACTION + 1) seen.shift();
    const view = seen[0];
    const me = state.p1;
    const inputs = { left: false, right: false, up: false, down: false, action: false };
    const skateTo = (x, y, deadzone = 2) => {
      inputs.left = x < me.x - deadzone;
      inputs.right = x > me.x + deadzone;
      inputs.up = y < me.y - deadzone;
      inputs.down = y > me.y + deadzone;
    };

    if (me.hasPuck) {
      spot ??= pickSpot();
      if (Math.hypot(spot.x - me.x, spot.y - me.y) > 6) {
        skateTo(spot.x, spot.y);
        return inputs;
      }
      const angle = Math.atan2(RINK_CY - me.y, RINK_RIGHT + 10 - me.x);
      const facing = (((Math.round(angle / (Math.PI / 4)) % 8) + 8) % 8) | 0;
      if (me.facing === facing) return { ...inputs, action: true };
      skateTo(me.x + DIRECTION_X[facing] * 10, me.y + DIRECTION_Y[facing] * 10, 0);
      return inputs;
    }

    spot = null;
    if (view.puck.possessedBy === 2) {
      skateTo(view.p2.x, view.p2.y, 1);
      const reach = Math.hypot(state.p2.x - me.x, state.p2.y - me.y);
      inputs.action =
        state.p2.hasPuck && reach < PLAYER_TACKLE_REACH && frame % PLAYER_TACKLE_EVERY === 0;
      return inputs;
    }
    skateTo(view.puck.x, view.puck.y, 1);
    return inputs;
  };
}

/**
 * Who scores next from a centre face-off, a tick of play at a time as the
 * host plays it.
 * @returns {boolean} whether the AI scored it
 */
function play({ difficulty, seed }) {
  const ai = createHockeyAI({ difficulty, rng: mulberry32(seed ^ 0x686f63) });
  const ask = askAsTheEngineDoes(ai, difficulty);
  const random = mulberry32(seed ^ 0x706c61);
  const player = averagePlayer(random);
  const state = createInitialState(GAME_MODE.CLASSIC);
  resetForFaceoff(state, null);
  state.phase = PHASE.PLAYING;
  let handled = { local: false, remote: false };
  let held = { local: false, remote: false };

  for (let frame = 0; frame < MAX_FRAMES; frame++) {
    const remote = ask(state);
    const local = player(state, frame);
    // As the game does it: a fresh press of action is one to act on.
    handled = {
      local: handled.local && !(local.action && !held.local),
      remote: handled.remote && !(remote.action && !held.remote),
    };
    held = { local: local.action, remote: remote.action };

    const tick = stepTick(state, local, remote, handled, random);
    handled = tick.handled;
    if (tick.scored) return tick.scored === "p2";
  }
  return false;
}

calibrate("hex_hockey", { play, label: "next goals" });
