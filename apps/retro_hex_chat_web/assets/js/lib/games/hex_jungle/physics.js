/**
 * Hex Jungle's simulation, as pure functions of the state: each takes the
 * state and gives back the next one. Units are the cartridge's (see
 * protocol.js); one call is one 60 Hz tick.
 *
 * @module games/hex_jungle/physics
 */

import { cadence, edgeExit, fall, jumpStep, overlaps } from "../core/platform.js";
import {
  BODY,
  CROC_CYCLE,
  CROC_HEADS_OPEN,
  CROC_HEADS_SHUT,
  CROC_SHUT_TICKS,
  EDGE_MAX,
  EDGE_MIN,
  GROUND_Y,
  HOLE_POINTS,
  JUMP_LIFT,
  JUMP_STEER_TICKS,
  JUMP_TABLE,
  LOG_BOX,
  LOG_ROLL_EVERY,
  LOG_SPACING,
  OBJECT_BOX,
  OBJECT_X,
  PHASE,
  PIT,
  PIT_DEATH_Y,
  SCREEN_W,
  SEED,
  SHIFT_CYCLE,
  SHIFT_INSETS,
  SHIFT_OPEN_FROM,
  SHIFT_OPENING_FROM,
  SHIFT_SHUT_FROM,
  SHIFT_STAGE_TICKS,
  START_LIVES,
  START_SCORE,
  START_X,
  TIME_TICKS,
  UNDER_Y,
  WALK_EVERY,
} from "./protocol.js";
import { decodeScene, stepScreens } from "./world.js";

/** The jungle as the expedition finds it. */
export function createInitialState() {
  return {
    phase: PHASE.WAITING,
    tick: 0,
    screen: SEED,
    underground: false,
    score: START_SCORE,
    lives: START_LIVES,
    timerTicks: TIME_TICKS,
    clockRunning: false,
    jumpHeld: false,
    logs: logsFor(SEED),
    player: { x: START_X, y: GROUND_Y, facing: 1, jumpTick: null, jumpDir: 0, kneeling: null },
  };
}

const within = (x, [from, to]) => x >= from && x <= to;

/**
 * Where a shifting pit's edges stand, `tick` into its cycle: how far each
 * edge has moved in, or null while it is shut.
 * @param {number} tick
 * @returns {number|null}
 */
export function shiftingInset(tick) {
  const t = tick % SHIFT_CYCLE;
  if (t < SHIFT_SHUT_FROM) return SHIFT_INSETS[Math.floor(t / SHIFT_STAGE_TICKS)];
  if (t < SHIFT_OPENING_FROM) return null;
  if (t < SHIFT_OPEN_FROM) {
    return SHIFT_INSETS[
      SHIFT_INSETS.length - 1 - Math.floor((t - SHIFT_OPENING_FROM) / SHIFT_STAGE_TICKS)
    ];
  }
  return 0;
}

/** Whether the ground at `x` of a pit screen gives way, `tick` into the expedition. */
function pitOpenAt(pit, x, tick) {
  if (pit.crocodiles) {
    const heads = tick % CROC_CYCLE < CROC_SHUT_TICKS ? CROC_HEADS_SHUT : CROC_HEADS_OPEN;
    return within(x, PIT) && !heads.some((head) => within(x, head));
  }
  if (!pit.shifting) return within(x, PIT);
  const inset = shiftingInset(tick);
  return inset !== null && within(x, [PIT[0] + inset, PIT[1] - inset]);
}

/**
 * The floor under `x`: the tunnel's below ground, the tunnel's through a
 * hole, none over an open pit, and the jungle's everywhere else.
 * @param {object} state
 * @param {number} x
 * @returns {number} a line, or Infinity where nothing holds the player up
 */
export function floorAt(state, x) {
  if (state.underground) return UNDER_Y;
  const scene = decodeScene(state.screen);
  if (scene.holes.some((hole) => within(x, hole))) return UNDER_Y;
  if (scene.pit && pitOpenAt(scene.pit, x, state.tick)) return Infinity;
  return GROUND_Y;
}

/**
 * The logs a screen starts with, from x 124 to the right.
 * @param {number} screen
 * @returns {{ x: number }[]}
 */
export function logsFor(screen) {
  const { hazard } = decodeScene(screen);
  if (hazard?.kind !== "log") return [];
  return Array.from({ length: hazard.count }, (_, i) => ({
    x: OBJECT_X + i * LOG_SPACING[hazard.spread],
  }));
}
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
    logs: logsFor(screen),
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
  const floorUnder = (x) => floorAt(state, x);
  const pressedJump = inputs.jump && !state.jumpHeld;
  let player = { ...state.player };
  const floor = floorUnder(player.x);

  if (player.jumpTick === null && player.y === floor) {
    const dir = direction(inputs);
    if (pressedJump) {
      player = { ...player, y: player.y - JUMP_LIFT, jumpTick: 0, jumpDir: dir };
    } else if (dir !== 0) {
      player.facing = dir;
      const stopped = player.kneeling === "rolling";
      if (!stopped && cadence(state.tick, WALK_EVERY)) player.x += dir;
    }
  } else if (player.jumpTick === null) {
    player = fall(player, floor);
  }

  if (player.jumpTick !== null) player = stepJump(player, inputs, floorUnder);

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

/** One tick in the air: the table, then a fall to the floor under it. */
function stepJump(player, inputs, floorUnder) {
  if (player.jumpTick >= JUMP_TABLE.length) {
    const floor = floorUnder(player.x);
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

const body = (player) => ({ x: player.x, y: player.y - BODY.h, w: BODY.w, h: BODY.h });
const onGround = (box) => ({ x: box.x, y: GROUND_Y - box.h, w: box.w, h: box.h });

/**
 * One tick of what the ground does to the player: a hole drops them into the
 * tunnel, a pit swallows them, logs roll and bruise, fire and snakes kill.
 * @param {object} state - after the player's own movement
 * @param {number} tick - the tick being stepped
 * @returns {object}
 */
export function stepHazards(state, tick) {
  if (state.underground) return state;
  const scene = decodeScene(state.screen);
  let next = { ...state, player: { ...state.player, kneeling: null } };

  if (next.player.y > GROUND_Y && scene.holes.some((hole) => within(next.player.x, hole))) {
    return { ...next, underground: true, score: Math.max(0, next.score - HOLE_POINTS) };
  }
  if (next.player.y > PIT_DEATH_Y) return { ...next, phase: PHASE.DYING };

  const rolling = scene.hazard?.kind === "log" && scene.hazard.rolling;
  if (rolling && cadence(tick, LOG_ROLL_EVERY)) {
    next.logs = next.logs.map((log) => ({ x: (log.x - 1 + SCREEN_W) % SCREEN_W }));
  }
  const you = body(next.player);
  if (next.logs.some((log) => overlaps(you, onGround({ ...LOG_BOX, x: log.x })))) {
    next.score = Math.max(0, next.score - 1);
    next.player.kneeling = rolling ? "rolling" : "still";
  }
  const deadly = scene.hazard?.kind === "fire" || scene.hazard?.kind === "snake";
  if (deadly && overlaps(you, onGround({ ...OBJECT_BOX, x: OBJECT_X }))) {
    next = { ...next, phase: PHASE.DYING };
  }
  return next;
}

/**
 * One tick of the expedition.
 * @param {object} state
 * @param {object} inputs
 * @returns {object}
 */
export function stepTick(state, inputs) {
  return stepHazards(stepPlayer(state, inputs), state.tick);
}
