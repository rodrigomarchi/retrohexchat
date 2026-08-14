/**
 * Deterministic opponent controller for Light Trails solo sessions.
 * The controller consumes plain game state and emits the same direction command
 * shape used by the P2P peer path.
 * @module games/surround_ai
 */

import { CELL } from "./physics.js";
import { DIR, GRID_H, GRID_W, PHASE } from "./protocol.js";

const DEFAULT_DIFFICULTY = "normal";
const GRID_AREA = GRID_W * GRID_H;
const TABLE_CENTER = Object.freeze({
  x: (GRID_W - 1) / 2,
  y: (GRID_H - 1) / 2,
});

const DIRECTIONS = Object.freeze([DIR.UP, DIR.DOWN, DIR.LEFT, DIR.RIGHT]);
const OPPOSITE = Object.freeze({
  [DIR.UP]: DIR.DOWN,
  [DIR.DOWN]: DIR.UP,
  [DIR.LEFT]: DIR.RIGHT,
  [DIR.RIGHT]: DIR.LEFT,
});

const DELTA = Object.freeze({
  [DIR.UP]: Object.freeze({ x: 0, y: -1 }),
  [DIR.DOWN]: Object.freeze({ x: 0, y: 1 }),
  [DIR.LEFT]: Object.freeze({ x: -1, y: 0 }),
  [DIR.RIGHT]: Object.freeze({ x: 1, y: 0 }),
});

export const SURROUND_AI_DIFFICULTIES = Object.freeze({
  easy: Object.freeze({
    decisionFrames: 4,
    floodLimit: 120,
    mistakeRate: 0.18,
    corridorWeight: 2.4,
    centerWeight: 0.4,
    opponentDistanceWeight: 0.05,
  }),
  normal: Object.freeze({
    decisionFrames: 2,
    floodLimit: 520,
    mistakeRate: 0.05,
    corridorWeight: 3.2,
    centerWeight: 0.7,
    opponentDistanceWeight: 0.08,
  }),
  hard: Object.freeze({
    decisionFrames: 1,
    floodLimit: GRID_AREA,
    mistakeRate: 0,
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
  if (typeof difficulty !== "string") return DEFAULT_DIFFICULTY;

  const key = difficulty.toLowerCase();
  return Object.prototype.hasOwnProperty.call(SURROUND_AI_DIFFICULTIES, key)
    ? key
    : DEFAULT_DIFFICULTY;
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

export class SurroundAI {
  /**
   * @param {object} [options]
   * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
   * @param {() => number} [options.rng]
   */
  constructor(options = {}) {
    this.difficulty = normalizeSurroundAIDifficulty(options.difficulty);
    this.rng = typeof options.rng === "function" ? options.rng : Math.random;
    this.frame = 0;
    this.lastDirection = null;
  }

  /**
   * @param {"easy"|"normal"|"hard"|string} difficulty
   * @returns {void}
   */
  setDifficulty(difficulty) {
    this.difficulty = normalizeSurroundAIDifficulty(difficulty);
  }

  /**
   * @param {object} request
   * @param {object} request.state
   * @param {"easy"|"normal"|"hard"|string} [request.difficulty]
   * @param {1|2} [request.player]
   * @returns {number}
   */
  nextDirection(request = {}) {
    const state = request.state;
    const player = request.player === 1 ? 1 : 2;
    const actor = playerState(state, player);

    if (!actor || state.phase !== PHASE.PLAYING) {
      this.frame++;
      return this.lastDirection ?? actor?.dir ?? DIR.LEFT;
    }

    const difficulty = normalizeSurroundAIDifficulty(request.difficulty || this.difficulty);
    if (difficulty !== this.difficulty) this.setDifficulty(difficulty);

    const config = SURROUND_AI_DIFFICULTIES[difficulty];
    if (
      this.lastDirection !== null &&
      this.frame % config.decisionFrames !== 0 &&
      isSafeDirection(state, player, this.lastDirection)
    ) {
      this.frame++;
      return this.lastDirection;
    }

    const direction = chooseDirection(state, player, config, this.rng);
    this.lastDirection = direction;
    this.frame++;
    return direction;
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

function isSafeDirection(state, player, direction) {
  const actor = playerState(state, player);
  if (!actor || direction === OPPOSITE[actor.dir]) return false;

  return isOpenCell(state, advance(actor, direction));
}

function reachableArea(state, start, limit) {
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

function isOpenCell(state, pos) {
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

function randomUnit(rng) {
  const value = Number(rng());
  if (!Number.isFinite(value)) return 0;
  return Math.max(0, Math.min(value, 0.999999999));
}
