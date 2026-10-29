/**
 * Deterministic opponent controller for Pixel Tanks solo sessions.
 * It emits the same held-input shape used by the P2P peer path.
 * @module games/pixel_tanks_ai
 */

import { PHASE } from "./protocol.js";
import {
  CANVAS_H,
  CANVAS_W,
  GRID_COLS,
  GRID_ROWS,
  MISSILE_RADIUS,
  TANK_RADIUS,
  WALL_SIZE,
} from "./physics.js";
import {
  TableAI,
  clamp,
  createCommitment,
  createPerThing,
  normalizeAngle,
  normalizeDifficulty,
  rotationDelta,
} from "../core/ai.js";

const PATH_LOOKAHEAD_CELLS = 3;

const NEUTRAL_INPUTS = Object.freeze({
  rotateLeft: false,
  rotateRight: false,
  forward: false,
  fire: false,
});

// aimErrorAngle: the most a shot is off, drawn once per shot and kept until
// it is fired. aimTolerance and turnDeadzone never loosen with difficulty.
// fireChance: the odds an opening is taken; a passed one waits out the
// cooldown. dodgeChance: the odds a shell is dodged at all, decided once per
// shell, and only once the shell is reactionFrames old.
export const PIXEL_TANKS_AI_DIFFICULTIES = Object.freeze({
  easy: Object.freeze({
    decisionInterval: 10,
    aimErrorAngle: 0.12,
    turnDeadzone: 0.03,
    moveAngle: 0.72,
    aimTolerance: 0.04,
    standoffDistance: 190,
    fireMaxDistance: 560,
    fireCooldownFrames: 50,
    fireChance: 0.85,
    dodgeChance: 0.2,
    reactionFrames: 24,
    threatFrames: 24,
    threatRadius: 140,
    threatMargin: 18,
  }),
  normal: Object.freeze({
    decisionInterval: 5,
    aimErrorAngle: 0.115,
    turnDeadzone: 0.03,
    moveAngle: 0.94,
    aimTolerance: 0.035,
    standoffDistance: 150,
    fireMaxDistance: 610,
    fireCooldownFrames: 50,
    fireChance: 0.85,
    dodgeChance: 0.2,
    reactionFrames: 18,
    threatFrames: 38,
    threatRadius: 185,
    threatMargin: 28,
  }),
  hard: Object.freeze({
    decisionInterval: 2,
    aimErrorAngle: 0.09,
    turnDeadzone: 0.03,
    moveAngle: 1.15,
    aimTolerance: 0.03,
    standoffDistance: 120,
    fireMaxDistance: 680,
    fireCooldownFrames: 46,
    fireChance: 1,
    dodgeChance: 0.3,
    reactionFrames: 12,
    threatFrames: 58,
    threatRadius: 230,
    threatMargin: 38,
  }),
});

/**
 * @param {unknown} difficulty
 * @returns {"easy"|"normal"|"hard"}
 */
export function normalizePixelTanksAIDifficulty(difficulty) {
  return normalizeDifficulty(difficulty, PIXEL_TANKS_AI_DIFFICULTIES);
}

/**
 * @param {object} [options]
 * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
 * @param {() => number} [options.rng]
 * @returns {PixelTanksAI}
 */
export function createPixelTanksAI(options = {}) {
  return new PixelTanksAI(options);
}

export class PixelTanksAI extends TableAI {
  /**
   * @param {object} [options]
   * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
   * @param {() => number} [options.rng]
   */
  constructor(options = {}) {
    super(options, normalizePixelTanksAIDifficulty, PIXEL_TANKS_AI_DIFFICULTIES);
    this.fireCooldown = 0;
    this.shot = 0;
    this._target = null;
    this._aim = createCommitment();
    this._shells = createPerThing();
  }

  /**
   * A new round or match: no target held, no shell under watch, and the next
   * shot draws a fresh aim.
   * @returns {void}
   */
  forget() {
    this._target = null;
    this._shells.reset();
    this._aim.reset();
  }

  /**
   * @param {object} request
   * @param {object} request.state
   * @param {Uint8Array} [request.walls]
   * @param {"easy"|"normal"|"hard"|string} [request.difficulty]
   * @param {1|2} [request.player]
   * @returns {{rotateLeft: boolean, rotateRight: boolean, forward: boolean, fire: boolean}}
   */
  // ex_dna:disable-for-lines:6 this AI's own turn: its cooldowns and the phase it plays in
  nextInputs(request = {}) {
    const { state, player } = this.startTurn(request);
    if (this.fireCooldown > 0) this.fireCooldown--;

    if (!state || state.phase !== PHASE.PLAYING) return NEUTRAL_INPUTS;
    // The tanks hold still after a hit and start over from their spawns.
    if (state.respawnPause > 0) {
      this.forget();
      return NEUTRAL_INPUTS;
    }

    const actor = tankState(state, player);
    const opponent = tankState(state, player === 1 ? 2 : 1);
    if (!isLiveTank(actor) || !isLiveTank(opponent)) return NEUTRAL_INPUTS;

    const config = this.rowFor(request);

    if (this.frame % config.decisionInterval === 0 || !this._target) {
      const seen = this._noticedShells(state, player, config);
      const target = chooseTankTarget(seen, player, request.walls, config);
      const error = this._aim.hold(this.shot, () => (this.rng() * 2 - 1) * config.aimErrorAngle);
      this._target = target.kind === "attack" ? applyAngleError(target, error) : target;
    }

    const movement = tankMovementInputs(actor.rotation, this._target, config);
    const open = shouldFire(state, player, this._target, config, this.fireCooldown, null, {
      walls: request.walls,
    });
    if (!open) return { ...movement, fire: false };

    // One roll per opening; a passed one waits out the cooldown like a shot.
    this.fireCooldown = config.fireCooldownFrames;
    this.shot++;
    this._target = null;
    return { ...movement, fire: this.rng() < config.fireChance };
  }

  /**
   * The state as this AI sees it: the rival's shell is there only once it is
   * reactionFrames old, and only if this AI is to dodge it — decided once
   * per shell.
   */
  _noticedShells(state, player, config) {
    const prefix = player === 1 ? "m2" : "m1";
    if (!state[`${prefix}Active`]) {
      this._shells.keep([]);
      return state;
    }

    const age = state[`${prefix}Age`] || 0;
    const shell = this.frame - age;
    this._shells.keep([shell]);
    const dodges = this._shells.decide(shell, () => this.rng() < config.dodgeChance);
    return dodges && age >= config.reactionFrames
      ? state
      : { ...state, [`${prefix}Active`]: false };
  }
}

/**
 * @param {object} state
 * @param {1|2} player
 * @param {Uint8Array} [walls]
 * @param {object} [config]
 * @returns {{angle: number, distance: number, advance: boolean, kind: "evade"|"attack"|"navigate"}}
 */
export function chooseTankTarget(
  state,
  player = 2,
  walls,
  config = PIXEL_TANKS_AI_DIFFICULTIES.normal,
) {
  const actor = tankState(state, player);
  const opponent = tankState(state, player === 1 ? 2 : 1);
  if (!actor || !opponent) return { angle: 0, distance: 0, advance: false, kind: "navigate" };

  const threat = incomingMissileThreat(state, player, config);
  if (threat) {
    return {
      angle: threat.evadeAngle,
      distance: threat.distance,
      advance: true,
      kind: "evade",
    };
  }

  const vector = vectorTo(actor, opponent);
  const clearShot = lineOfSightClear(actor.x, actor.y, opponent.x, opponent.y, walls);
  if (clearShot) {
    return {
      angle: vector.angle,
      distance: vector.distance,
      advance: vector.distance > config.standoffDistance,
      kind: "attack",
    };
  }

  const waypoint = nextPathWaypoint(actor, opponent, walls);
  if (waypoint) {
    const waypointVector = vectorTo(actor, waypoint);
    return {
      angle: waypointVector.angle,
      distance: waypointVector.distance,
      advance: true,
      kind: "navigate",
    };
  }

  return {
    angle: vector.angle,
    distance: vector.distance,
    advance: movementRayClear(actor, vector.angle, walls),
    kind: "navigate",
  };
}

/**
 * @param {number} currentRotation
 * @param {{angle: number, advance: boolean}|null} target
 * @param {object} [config]
 * @returns {{rotateLeft: boolean, rotateRight: boolean, forward: boolean, fire: boolean}}
 */
export function tankMovementInputs(
  currentRotation,
  target,
  config = PIXEL_TANKS_AI_DIFFICULTIES.normal,
) {
  if (!target) return NEUTRAL_INPUTS;

  const delta = rotationDelta(currentRotation, target.angle);
  const alignedForMove = Math.abs(delta) <= config.moveAngle;

  return {
    rotateLeft: delta < -config.turnDeadzone,
    rotateRight: delta > config.turnDeadzone,
    forward: target.advance === true && alignedForMove,
    fire: false,
  };
}

/**
 * @param {object} state
 * @param {1|2} player
 * @param {{angle: number, distance: number}|null} target
 * @param {object} [config]
 * @param {number} [cooldown]
 * @param {() => number} [rng]
 * @param {object} [options]
 * @param {Uint8Array} [options.walls]
 * @returns {boolean}
 */
export function shouldFire(
  state,
  player = 2,
  target,
  config = PIXEL_TANKS_AI_DIFFICULTIES.normal,
  cooldown = 0,
  rng,
  options = {},
) {
  const actor = tankState(state, player);
  const opponent = tankState(state, player === 1 ? 2 : 1);
  const missile = missileState(state, player);

  if (!target || !isLiveTank(actor) || !isLiveTank(opponent)) return false;
  if (opponent.invulnerable) return false;
  if (missile.active) return false;
  if (cooldown > 0 || actor.cooldown > 0) return false;
  if (target.distance > config.fireMaxDistance) return false;
  if (!lineOfSightClear(actor.x, actor.y, opponent.x, opponent.y, options.walls)) return false;
  if (Math.abs(rotationDelta(actor.rotation, target.angle)) > config.aimTolerance) return false;

  const roll = typeof rng === "function" ? rng() : 0;
  return roll <= config.fireChance;
}

/**
 * @param {object} state
 * @param {1|2} player
 * @param {object} [config]
 * @returns {{frames: number, distance: number, evadeAngle: number}|null}
 */
export function incomingMissileThreat(
  state,
  player = 2,
  config = PIXEL_TANKS_AI_DIFFICULTIES.normal,
) {
  const actor = tankState(state, player);
  const incoming = missileState(state, player === 1 ? 2 : 1);
  if (!actor || !incoming.active) return null;

  const speed = Math.hypot(incoming.vx, incoming.vy);
  if (speed <= 0) return null;

  const dx = actor.x - incoming.x;
  const dy = actor.y - incoming.y;
  const directDistance = Math.hypot(dx, dy);
  if (directDistance > config.threatRadius) return null;

  const projection = (incoming.vx * dx + incoming.vy * dy) / speed;
  if (projection < 0) return null;

  const frames = projection / speed;
  if (frames > config.threatFrames) return null;

  const closestX = incoming.x + incoming.vx * frames;
  const closestY = incoming.y + incoming.vy * frames;
  const missDistance = Math.hypot(actor.x - closestX, actor.y - closestY);
  if (missDistance > TANK_RADIUS + MISSILE_RADIUS + config.threatMargin) return null;

  const side = actor.y <= incoming.y ? -1 : 1;
  return {
    frames,
    distance: missDistance,
    evadeAngle: normalizeAngle(Math.atan2(incoming.vy, incoming.vx) + side * (Math.PI / 2)),
  };
}

/**
 * @param {number} fromX
 * @param {number} fromY
 * @param {number} toX
 * @param {number} toY
 * @param {Uint8Array} [walls]
 * @returns {boolean}
 */
export function lineOfSightClear(fromX, fromY, toX, toY, walls) {
  if (!walls) return true;

  const dx = toX - fromX;
  const dy = toY - fromY;
  const distance = Math.hypot(dx, dy);
  if (distance <= 0) return true;

  const steps = Math.max(1, Math.ceil(distance / (WALL_SIZE / 2)));
  for (let i = 1; i < steps; i++) {
    const t = i / steps;
    const col = Math.floor((fromX + dx * t) / WALL_SIZE);
    const row = Math.floor((fromY + dy * t) / WALL_SIZE);
    if (cellBlocked(row, col, walls)) return false;
  }

  return true;
}

function nextPathWaypoint(actor, opponent, walls) {
  if (!walls) return null;

  const start = nearestOpenCell(toCell(actor.x, actor.y), walls);
  const goal = nearestOpenCell(toCell(opponent.x, opponent.y), walls);
  if (!start || !goal) return null;

  const startIndex = cellIndex(start.row, start.col);
  const goalIndex = cellIndex(goal.row, goal.col);
  if (startIndex === goalIndex) return cellCenter(goal.row, goal.col);

  const queue = [startIndex];
  const previous = new Int32Array(GRID_COLS * GRID_ROWS);
  previous.fill(-1);
  previous[startIndex] = startIndex;

  for (let head = 0; head < queue.length; head++) {
    const index = queue[head];
    if (index === goalIndex) break;

    const row = Math.floor(index / GRID_COLS);
    const col = index % GRID_COLS;
    for (const [nextRow, nextCol] of [
      [row - 1, col],
      [row + 1, col],
      [row, col - 1],
      [row, col + 1],
    ]) {
      if (cellBlocked(nextRow, nextCol, walls)) continue;
      const nextIndex = cellIndex(nextRow, nextCol);
      if (previous[nextIndex] !== -1) continue;
      previous[nextIndex] = index;
      queue.push(nextIndex);
    }
  }

  if (previous[goalIndex] === -1) return null;

  const path = [];
  let cursor = goalIndex;
  while (cursor !== startIndex) {
    path.push(cursor);
    cursor = previous[cursor];
  }
  path.reverse();

  const waypointIndex = path[Math.min(PATH_LOOKAHEAD_CELLS - 1, path.length - 1)];
  const row = Math.floor(waypointIndex / GRID_COLS);
  const col = waypointIndex % GRID_COLS;
  return cellCenter(row, col);
}

function nearestOpenCell(cell, walls) {
  if (!cellBlocked(cell.row, cell.col, walls)) return cell;

  const queue = [cell];
  const seen = new Set([`${cell.row}:${cell.col}`]);
  for (let head = 0; head < queue.length; head++) {
    const current = queue[head];
    for (const [row, col] of [
      [current.row - 1, current.col],
      [current.row + 1, current.col],
      [current.row, current.col - 1],
      [current.row, current.col + 1],
    ]) {
      const key = `${row}:${col}`;
      if (seen.has(key)) continue;
      seen.add(key);
      if (!cellBlocked(row, col, walls)) return { row, col };
      if (row > 0 && row < GRID_ROWS - 1 && col > 0 && col < GRID_COLS - 1) {
        queue.push({ row, col });
      }
    }
  }

  return null;
}

function movementRayClear(actor, angle, walls) {
  if (!walls) return true;

  const probeX = actor.x + Math.cos(angle) * WALL_SIZE;
  const probeY = actor.y + Math.sin(angle) * WALL_SIZE;
  const col = Math.floor(probeX / WALL_SIZE);
  const row = Math.floor(probeY / WALL_SIZE);
  return !cellBlocked(row, col, walls);
}

function applyAngleError(target, error) {
  if (!target || !error) return target;
  return { ...target, angle: normalizeAngle(target.angle + error) };
}

function tankState(state, player) {
  const prefix = player === 1 ? "tank1" : "tank2";
  if (typeof state?.[`${prefix}X`] !== "number" || typeof state?.[`${prefix}Y`] !== "number") {
    return null;
  }

  return {
    x: state[`${prefix}X`],
    y: state[`${prefix}Y`],
    rotation: state[`${prefix}Rot`],
    alive: state[`${prefix}Alive`] !== false,
    invulnerable: state[`${prefix}Invuln`] === true,
    cooldown: state[`${prefix}Cooldown`] || 0,
  };
}

function missileState(state, player) {
  const prefix = player === 1 ? "m1" : "m2";
  return {
    x: state?.[`${prefix}X`] || 0,
    y: state?.[`${prefix}Y`] || 0,
    vx: state?.[`${prefix}VX`] || 0,
    vy: state?.[`${prefix}VY`] || 0,
    active: state?.[`${prefix}Active`] === true,
  };
}

function isLiveTank(tank) {
  return !!tank && tank.alive;
}

function vectorTo(from, to) {
  const dx = to.x - from.x;
  const dy = to.y - from.y;
  return {
    angle: normalizeAngle(Math.atan2(dy, dx)),
    distance: Math.hypot(dx, dy),
  };
}

function toCell(x, y) {
  return {
    row: clamp(Math.floor(y / WALL_SIZE), 0, GRID_ROWS - 1),
    col: clamp(Math.floor(x / WALL_SIZE), 0, GRID_COLS - 1),
  };
}

function cellCenter(row, col) {
  return {
    x: clamp(col * WALL_SIZE + WALL_SIZE / 2, WALL_SIZE, CANVAS_W - WALL_SIZE),
    y: clamp(row * WALL_SIZE + WALL_SIZE / 2, WALL_SIZE, CANVAS_H - WALL_SIZE),
  };
}

function cellBlocked(row, col, walls) {
  if (!walls) return false;
  if (row < 0 || row >= GRID_ROWS || col < 0 || col >= GRID_COLS) return true;
  return walls[cellIndex(row, col)] === 1;
}

function cellIndex(row, col) {
  return row * GRID_COLS + col;
}
