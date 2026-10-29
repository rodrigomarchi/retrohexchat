/**
 * Deterministic opponent controller for Light Trails solo sessions.
 * The controller consumes plain game state and emits the same direction command
 * shape used by the P2P peer path.
 * @module games/surround_ai
 */

import { CELL, DELTA, OPPOSITE } from "./physics.js";
import { DIR, GRID_H, GRID_W, PHASE } from "./protocol.js";
import { TableAI, aiRequest, normalizeDifficulty, randomUnit } from "../core/ai.js";

const GRID_AREA = GRID_W * GRID_H;
const TABLE_CENTER = Object.freeze({
  x: (GRID_W - 1) / 2,
  y: (GRID_H - 1) / 2,
});

const DIRECTIONS = Object.freeze([DIR.UP, DIR.DOWN, DIR.LEFT, DIR.RIGHT]);
// How far ahead each level sees, and how often it slips. `floodLimit` is how
// many open cells it counts behind each turn: a short count cannot tell a
// pocket from the open board. A mistake takes a turn that is open now but
// worse; a lapse keeps the cycle going straight for `lapseMoves` moves
// without looking, which is how it can drive into a wall.
export const SURROUND_AI_DIFFICULTIES = Object.freeze({
  easy: Object.freeze({
    floodLimit: 30,
    mistakeRate: 0.22,
    lapseRate: 0.05,
    lapseMoves: 4,
    corridorWeight: 2.4,
    centerWeight: 0.4,
    opponentDistanceWeight: 0.05,
  }),
  normal: Object.freeze({
    floodLimit: 60,
    mistakeRate: 0.17,
    lapseRate: 0.045,
    lapseMoves: 4,
    corridorWeight: 3.2,
    centerWeight: 0.7,
    opponentDistanceWeight: 0.08,
  }),
  hard: Object.freeze({
    floodLimit: GRID_AREA,
    mistakeRate: 0.11,
    lapseRate: 0.045,
    lapseMoves: 4,
    corridorWeight: 4,
    centerWeight: 1,
    opponentDistanceWeight: 0.12,
  }),
});

/**
 * @param {unknown} difficulty
 * @returns {"easy"|"normal"|"hard"}
 */
export function normalizeSurroundAIDifficulty(difficulty) {
  return normalizeDifficulty(difficulty, SURROUND_AI_DIFFICULTIES);
}

/**
 * @param {object} [options]
 * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
 * @param {() => number} [options.rng]
 * @returns {SurroundAI}
 */
export function createSurroundAI(options = {}) {
  return new SurroundAI(options);
}

export class SurroundAI extends TableAI {
  /**
   * @param {object} [options]
   * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
   * @param {() => number} [options.rng]
   */
  constructor(options = {}) {
    super(options, normalizeSurroundAIDifficulty, SURROUND_AI_DIFFICULTIES);
    this.lastDirection = null;
    this.lapseLeft = 0;
  }

  /**
   * A new round: no lapse running, no direction of the last round's cycle.
   * @returns {void}
   */
  forget() {
    this.lapseLeft = 0;
    this.lastDirection = null;
  }

  /**
   * @param {object} request
   * @param {object} request.state
   * @param {"easy"|"normal"|"hard"|string} [request.difficulty]
   * @param {1|2} [request.player]
   * @returns {number}
   */
  nextDirection(request = {}) {
    const { state, player } = aiRequest(request);
    const actor = playerState(state, player);

    if (!actor || state.phase !== PHASE.PLAYING) return actor?.dir ?? DIR.LEFT;

    const difficulty = this.difficultyFor(request);

    const config = SURROUND_AI_DIFFICULTIES[difficulty];
    if (this.lastDirection !== null && this.lapsing(config)) return actor.dir;

    const direction = chooseDirection(state, player, config, this.rng);
    this.lastDirection = direction;
    return direction;
  }

  /**
   * Whether this move is spent not looking: a lapse, once drawn, runs its
   * whole length, whatever lies ahead.
   * @param {object} config
   * @returns {boolean}
   */
  lapsing(config) {
    if (this.lapseLeft > 0) {
      this.lapseLeft--;
      return true;
    }
    if (randomUnit(this.rng) >= config.lapseRate) return false;
    this.lapseLeft = config.lapseMoves - 1;
    return true;
  }
}

function chooseDirection(state, player, config, rng) {
  const actor = playerState(state, player);
  const ranked = rankDirections(state, player, config);
  if (ranked.length === 0) return actor?.dir ?? DIR.LEFT;

  const safe = ranked.filter((choice) => choice.safe);
  if (safe.length > 1 && randomUnit(rng) < config.mistakeRate) {
    return safe[1 + Math.floor(randomUnit(rng) * (safe.length - 1))].direction;
  }

  return (safe[0] || ranked[0]).direction;
}

function rankDirections(state, player, config) {
  const actor = playerState(state, player);
  if (!actor) return [];

  return DIRECTIONS.filter((direction) => direction !== OPPOSITE[actor.dir])
    .map((direction) => {
      const next = advance(actor, direction);
      const safe = isOpenCell(state, next);
      const area = safe ? reachableArea(state, next, config.floodLimit) : 0;
      const corridor = safe ? corridorLength(state, next, direction) : 0;
      const center = safe ? centerScore(next) * config.centerWeight : 0;
      const opponent = safe ? opponentDistanceScore(state, player, next) : 0;
      const score =
        area + corridor * config.corridorWeight + center + opponent * config.opponentDistanceWeight;

      return { direction, safe, score };
    })
    .sort((left, right) => right.score - left.score);
}

/**
 * The open cells reachable from `start`, an open cell, counted up to `limit`.
 * @param {object} state
 * @param {{x: number, y: number}} start
 * @param {number} limit
 * @returns {number}
 */
export function reachableArea(state, start, limit) {
  const queue = [start];
  const visited = new Set([cellKey(start)]);
  let count = 0;
  let index = 0;

  while (index < queue.length && count < limit) {
    const current = queue[index];
    index++;
    count++;

    for (const direction of DIRECTIONS) {
      const next = advance(current, direction);
      const key = cellKey(next);
      if (visited.has(key) || !isOpenCell(state, next)) continue;
      visited.add(key);
      queue.push(next);
    }
  }

  return count;
}

function corridorLength(state, start, direction) {
  let count = 0;
  let current = start;

  while (count < 18 && isOpenCell(state, current)) {
    count++;
    current = advance(current, direction);
  }

  return count;
}

function centerScore(pos) {
  return -Math.hypot(pos.x - TABLE_CENTER.x, pos.y - TABLE_CENTER.y);
}

function opponentDistanceScore(state, player, pos) {
  const opponent = playerState(state, player === 1 ? 2 : 1);
  if (!opponent) return 0;

  return Math.hypot(pos.x - opponent.x, pos.y - opponent.y);
}

function playerState(state, player) {
  if (!state) return null;
  return player === 1 ? state.p1 : state.p2;
}

function advance(pos, direction) {
  const delta = DELTA[direction];
  return { x: pos.x + delta.x, y: pos.y + delta.y };
}

/**
 * Whether a cell is on the grid and empty.
 * @param {object} state
 * @param {{x: number, y: number}} pos
 * @returns {boolean}
 */
export function isOpenCell(state, pos) {
  return (
    pos.x >= 0 &&
    pos.x < GRID_W &&
    pos.y >= 0 &&
    pos.y < GRID_H &&
    state.grid?.[pos.y]?.[pos.x] === CELL.EMPTY
  );
}

function cellKey(pos) {
  return `${pos.x}:${pos.y}`;
}
