/**
 * Hex Jungle's simulation, as pure functions of the state: each takes the
 * state and gives back the next one. Units are the cartridge's (see
 * protocol.js); one call is one 60 Hz tick.
 *
 * @module games/hex_jungle/physics
 */

import { cadence, edgeExit, fall, jumpStep } from "../core/platform.js";
import {
  EDGE_MAX,
  EDGE_MIN,
  GROUND_Y,
  JUMP_LIFT,
  JUMP_STEER_TICKS,
  JUMP_TABLE,
  SEED,
  START_LIVES,
  START_SCORE,
  START_X,
  TIME_TICKS,
  UNDER_Y,
  WALK_EVERY,
} from "./protocol.js";
import { stepScreens } from "./world.js";

/** The jungle as the expedition finds it. */
export function createInitialState() {
  return {
    tick: 0,
    screen: SEED,
    underground: false,
    score: START_SCORE,
    lives: START_LIVES,
    timerTicks: TIME_TICKS,
    clockRunning: false,
    jumpHeld: false,
    player: { x: START_X, y: GROUND_Y, facing: 1, jumpTick: null, jumpDir: 0 },
  };
}

const floorOf = (state) => (state.underground ? UNDER_Y : GROUND_Y);
const direction = (inputs) => (inputs.right ? 1 : 0) - (inputs.left ? 1 : 0);
const moved = (inputs) => inputs.left || inputs.right || inputs.up || inputs.down || inputs.jump;

/**
 * The next screen along, `direction` 1 to the right or -1 to the left; three
 * of the surface's at a time underground.
 * @param {object} state
 * @param {1|-1} toward
 * @returns {object}
 */
export function changeScreen(state, toward) {
  const screen = stepScreens(state.screen, state.underground ? 3 : 1, toward);
  return {
    ...state,
    screen,
    player: { ...state.player, x: toward > 0 ? EDGE_MIN : EDGE_MAX },
  };
}

/**
 * One tick of the player's own movement: running, jumping, landing, and the
 * screen changing under their feet at an edge.
 * @param {object} state
 * @param {{ left: boolean, right: boolean, up: boolean, down: boolean, jump: boolean }} inputs
 * @returns {object}
 */
export function stepPlayer(state, inputs) {
  const floor = floorOf(state);
  const pressedJump = inputs.jump && !state.jumpHeld;
  let player = { ...state.player };

  if (player.jumpTick === null && player.y === floor) {
    const dir = direction(inputs);
    if (pressedJump) {
      player = { ...player, y: player.y - JUMP_LIFT, jumpTick: 0, jumpDir: dir };
    } else if (dir !== 0) {
      player.facing = dir;
      if (cadence(state.tick, WALK_EVERY)) player.x += dir;
    }
  }

  if (player.jumpTick !== null) player = stepJump(player, inputs, floor);

  let next = {
    ...state,
    tick: state.tick + 1,
    jumpHeld: inputs.jump,
    clockRunning: state.clockRunning || moved(inputs),
    player,
  };
  const exit = edgeExit(player.x, EDGE_MIN, EDGE_MAX);
  if (exit !== 0) next = changeScreen(next, exit);
  return next;
}

/** One tick in the air: the table, then a fall to the floor. */
function stepJump(player, inputs, floor) {
  if (player.jumpTick >= JUMP_TABLE.length) {
    const fallen = fall(player, floor);
    return fallen.y === floor ? { ...fallen, jumpTick: null, jumpDir: 0 } : fallen;
  }
  let next = jumpStep(player, JUMP_TABLE);
  if (next.jumpTick <= JUMP_STEER_TICKS && direction(inputs) !== 0) {
    next = { ...next, jumpDir: direction(inputs) };
  }
  if (next.jumpDir !== 0) next.facing = next.jumpDir;
  if (cadence(next.jumpTick, WALK_EVERY)) next.x += next.jumpDir;
  return next;
}
