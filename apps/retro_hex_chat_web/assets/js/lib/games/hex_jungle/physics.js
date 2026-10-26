/**
 * Hex Jungle's simulation, as pure functions of the state: each takes the
 * state and gives back the next one. Units are the cartridge's (see
 * protocol.js); one call is one 60 Hz tick.
 *
 * @module games/hex_jungle/physics
 */

import {
  cadence,
  climbStep,
  edgeExit,
  fall,
  jumpStep,
  ladderGrab,
  overlaps,
} from "../core/platform.js";
import {
  BODY,
  CROC_CYCLE,
  CROC_HEADS_OPEN,
  CROC_HEADS_SHUT,
  CROC_SHUT_TICKS,
  EDGE_MAX,
  EDGE_MIN,
  EVENT,
  GROUND_Y,
  HOLE_POINTS,
  JUMP_LIFT,
  JUMP_STEER_TICKS,
  JUMP_TABLE,
  LADDER,
  LADDER_EVERY,
  LADDER_REACH_FROM_BELOW,
  LADDER_RUNG,
  LOG_BOX,
  LOG_ROLL_EVERY,
  LOG_SPACING,
  OBJECT_BOX,
  OBJECT_X,
  PHASE,
  PIT,
  PIT_DEATH_Y,
  RESPAWN_UNDER_Y,
  RESPAWN_Y,
  SCORPION_BOX,
  SCORPION_EVERY,
  SCORPION_START,
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
  TREASURE_BOX,
  TREASURES_TOTAL,
  UNDER_Y,
  VINE_CENTER,
  VINE_DROP_TICK,
  VINE_HANG_Y,
  VINE_PERIOD,
  VINE_REACH,
  VINE_SWING,
  WALK_EVERY,
  WALL_BOX,
  WALL_X,
} from "./protocol.js";
import { decodeScene, stepScreens, treasureSlot } from "./world.js";

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
    events: 0,
    taken: 0,
    treasures: 0,
    logs: logsFor(SEED),
    scorpionX: SCORPION_START,
    player: {
      x: START_X,
      y: GROUND_Y,
      facing: 1,
      jumpTick: null,
      jumpDir: 0,
      kneeling: null,
      onVine: false,
      fromVine: false,
      climbing: false,
    },
  };
}

const within = (x, [from, to]) => x >= from && x <= to;
const flag = (state, bit) => ({ ...state, events: state.events | bit });
const dies = (state) => flag({ ...state, phase: PHASE.DYING }, EVENT.DEATH);

/**
 * Where the vine hangs `tick` into the expedition.
 * @param {number} tick
 * @returns {number}
 */
export function vineX(tick) {
  return Math.round(VINE_CENTER + VINE_SWING * Math.cos((2 * Math.PI * tick) / VINE_PERIOD));
}

const LADDER_CLIMB = { top: GROUND_Y, bottom: UNDER_Y, rung: LADDER_RUNG, every: LADDER_EVERY };

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
    scorpionX: SCORPION_START,
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
  const scene = decodeScene(state.screen);
  let player = { ...state.player };
  const floor = floorUnder(player.x);
  let underground = state.underground;
  let events = state.events;

  if (player.onVine) {
    player = swing(player, inputs, state.tick);
  } else if (player.climbing) {
    player = climb(player, inputs, state.tick);
    underground = player.y > GROUND_Y;
    if (player.jumpTick === 0) events |= EVENT.JUMP;
  } else if (
    player.jumpTick === null &&
    player.y === floor &&
    reachesLadder(state, scene, inputs)
  ) {
    player = { ...player, x: LADDER.x, climbing: true };
  } else if (player.jumpTick === null && player.y === floor) {
    const dir = direction(inputs);
    if (pressedJump) {
      player = { ...player, y: player.y - JUMP_LIFT, jumpTick: 0, jumpDir: dir };
      events |= EVENT.JUMP;
    } else if (dir !== 0) {
      player.facing = dir;
      const stopped = player.kneeling === "rolling";
      if (!stopped && cadence(state.tick, WALK_EVERY)) player.x += dir;
    }
  } else if (player.jumpTick === null) {
    player = fall(player, floor);
  }

  if (player.jumpTick !== null) {
    player = stepJump(player, inputs, floorUnder);
    const vine = vineX(state.tick);
    if (scene.vine && !underground && player.jumpTick !== null && !player.fromVine) {
      if (Math.abs(player.x - vine) <= VINE_REACH) {
        player = catchVine(player, vine);
        events |= EVENT.VINE;
      }
    }
  }

  let next = {
    ...state,
    underground,
    events,
    tick: state.tick + 1,
    jumpHeld: inputs.jump,
    clockRunning: state.clockRunning || moved(inputs),
    player,
  };
  const exit = edgeExit(player.x, EDGE_MIN, EDGE_MAX);
  if (exit !== 0) next = changeScreen(next, exit);
  return next;
}

const landed = (player, floor) => ({
  ...player,
  y: floor,
  jumpTick: null,
  jumpDir: 0,
  fromVine: false,
});

/** One tick in the air: the table, then a fall to the floor under it. */
function stepJump(player, inputs, floorUnder) {
  if (player.jumpTick >= JUMP_TABLE.length) {
    const floor = floorUnder(player.x);
    const fallen = fall(player, floor);
    return fallen.y === floor ? landed(fallen, floor) : fallen;
  }
  let next = jumpStep(player, JUMP_TABLE);
  if (next.jumpTick <= JUMP_STEER_TICKS && direction(inputs) !== 0) {
    next = { ...next, jumpDir: direction(inputs) };
  }
  if (next.jumpDir !== 0) next.facing = next.jumpDir;
  if (cadence(next.jumpTick, WALK_EVERY)) next.x += next.jumpDir;
  // A drop from higher than the jump left (a vine) can reach the floor early.
  const floor = floorUnder(next.x);
  return next.y >= floor ? landed(next, floor) : next;
}

function catchVine(player, vine) {
  return { ...player, x: vine, y: VINE_HANG_Y, onVine: true, jumpTick: null, jumpDir: 0 };
}

/** One tick on the vine: carried along it, or letting go with down. */
function swing(player, inputs, tick) {
  const x = vineX(tick);
  if (!inputs.down) return { ...player, x };
  const toward = Math.sign(vineX(tick + 1) - x) || player.facing;
  return {
    ...player,
    x,
    onVine: false,
    fromVine: true,
    jumpTick: VINE_DROP_TICK,
    jumpDir: toward,
    facing: toward,
  };
}

/** Whether the player standing here takes the ladder with what they hold. */
function reachesLadder(state, scene, inputs) {
  if (!scene.ladder || ladderGrab(state.player.x, LADDER) === null) return false;
  if (!state.underground) return inputs.down;
  return inputs.up && state.player.y >= LADDER_REACH_FROM_BELOW;
}

/** One tick on the ladder: a rung at a time, off at the bottom or with a hop at the top. */
function climb(player, inputs, tick) {
  const dir = direction(inputs);
  if (player.y === GROUND_Y && dir !== 0) {
    return { ...player, climbing: false, y: GROUND_Y - JUMP_LIFT, jumpTick: 0, jumpDir: dir };
  }
  const way = (inputs.down ? 1 : 0) - (inputs.up ? 1 : 0);
  const next = climbStep(player, LADDER_CLIMB, way, tick);
  return next.y === UNDER_Y && way > 0 ? { ...next, climbing: false } : next;
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
  const scene = decodeScene(state.screen);
  let next = { ...state, player: { ...state.player, kneeling: null } };
  if (next.player.climbing) return pushOffLadder(next);
  if (next.underground) return stepTunnel(next, scene, tick);

  if (next.player.y > GROUND_Y && scene.holes.some((hole) => within(next.player.x, hole))) {
    const score = Math.max(0, next.score - HOLE_POINTS);
    return flag({ ...next, underground: true, score }, EVENT.HOLE);
  }
  if (next.player.y > PIT_DEATH_Y) return dies(next);

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
  if (deadly && overlaps(you, onGround({ ...OBJECT_BOX, x: OBJECT_X }))) next = dies(next);
  return next;
}

const touchesLog = (state) =>
  state.logs.some((log) => overlaps(body(state.player), onGround({ ...LOG_BOX, x: log.x })));

/** A log rolling into a climber near the top knocks them a rung down. */
function pushOffLadder(state) {
  if (!touchesLog(state)) return state;
  const y = Math.min(state.player.y + LADDER_RUNG, UNDER_Y);
  return { ...state, score: Math.max(0, state.score - 1), player: { ...state.player, y } };
}

const inTunnel = (box) => ({ x: box.x, y: UNDER_Y - box.h, w: box.w, h: box.h });

/** One tick of the tunnel: its wall pushes back, its scorpion creeps and stings. */
function stepTunnel(state, scene, tick) {
  const { wall, scorpion } = scene.underground;
  let next = state;
  if (wall && overlaps(body(next.player), inTunnel({ ...WALL_BOX, x: WALL_X[wall] }))) {
    const back = wall === "right" ? -1 : 1;
    next = flag({ ...next, player: { ...next.player, x: next.player.x + back } }, EVENT.WALL);
  }
  if (!scorpion) return next;
  let scorpionX = next.scorpionX;
  if (cadence(tick, SCORPION_EVERY)) scorpionX += Math.sign(next.player.x - scorpionX);
  next = { ...next, scorpionX };
  if (overlaps(body(next.player), inTunnel({ ...SCORPION_BOX, x: scorpionX }))) return dies(next);
  return next;
}

/**
 * Whether this screen's treasure is still where it lay.
 * @param {object} state
 * @returns {boolean}
 */
export function treasureLies(state) {
  const { treasure } = decodeScene(state.screen);
  return !!treasure && ((state.taken >>> treasureSlot(state.screen)) & 1) === 0;
}

/**
 * The treasure the player touches, taken for its points; the 32nd ends it.
 * @param {object} state
 * @returns {object}
 */
export function collectTreasure(state) {
  if (state.underground || !treasureLies(state)) return state;
  if (!overlaps(body(state.player), onGround({ ...TREASURE_BOX, x: OBJECT_X }))) return state;
  const { treasure } = decodeScene(state.screen);
  const treasures = state.treasures + 1;
  return {
    ...state,
    events: state.events | EVENT.TREASURE,
    score: state.score + treasure.points,
    taken: (state.taken | (1 << treasureSlot(state.screen))) >>> 0,
    treasures,
    phase: treasures >= TREASURES_TOTAL ? PHASE.FINISHED : state.phase,
  };
}

/**
 * One tick of the clock, once the first move has started it; zero ends it.
 * @param {object} state
 * @returns {object}
 */
export function tickClock(state) {
  if (!state.clockRunning || state.timerTicks <= 0) return state;
  const timerTicks = state.timerTicks - 1;
  return { ...state, timerTicks, phase: timerTicks === 0 ? PHASE.FINISHED : state.phase };
}

/**
 * A life taken.
 * @param {object} state
 * @returns {object}
 */
export function loseLife(state) {
  return { ...state, lives: Math.max(0, state.lives - 1) };
}

/**
 * The player back after a death: dropping at x 20 from the treetops, or from
 * the tunnel's roof, with the screen's logs and scorpion back where they start.
 * @param {object} state
 * @returns {object}
 */
export function respawn(state) {
  return {
    ...state,
    phase: PHASE.RESPAWN,
    logs: logsFor(state.screen),
    scorpionX: SCORPION_START,
    player: {
      ...state.player,
      x: START_X,
      y: state.underground ? RESPAWN_UNDER_Y : RESPAWN_Y,
      jumpTick: null,
      jumpDir: 0,
      kneeling: null,
      onVine: false,
      fromVine: false,
      climbing: false,
    },
  };
}

/**
 * One tick of the drop back in: a line a tick, and in play once on the floor.
 * @param {object} state
 * @returns {object}
 */
export function stepRespawn(state) {
  const floor = floorAt(state, state.player.x);
  const player = fall(state.player, floor);
  return {
    ...state,
    tick: state.tick + 1,
    player,
    phase: player.y === floor ? PHASE.PLAYING : state.phase,
  };
}

/**
 * One tick of the expedition.
 * @param {object} state
 * @param {object} inputs
 * @returns {object}
 */
export function stepTick(state, inputs) {
  const quiet = { ...state, events: 0 };
  return collectTreasure(stepHazards(stepPlayer(quiet, inputs), state.tick));
}
