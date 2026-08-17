/**
 * Deterministic opponent controller for Hex Frost solo sessions.
 * It emits the same held-input shape used by the P2P peer path, keeping the
 * host simulation shared between solo and network play.
 * @module games/hex_frost_ai
 */

import { normalizeFrostAIDifficulty } from "./difficulty.js";
import { BAILEY_STATE, BLOCK_STATE, ENEMY_TYPE, GAME_MODE, PHASE } from "./protocol.js";
import {
  BAILEY_W,
  BLOCK_W,
  CANVAS_W,
  IGLOO_W,
  NUM_ROWS,
  ROW_SPACING,
  ROW_Y,
  SHORE_H,
  SHORE_Y,
  getBlockAbsX,
  getBaileyY,
} from "./physics.js";

const EDGE_MARGIN = 18;
const NEUTRAL_INPUTS = Object.freeze({ left: false, right: false, up: false, down: false });

export const FROST_AI_DIFFICULTIES = Object.freeze({
  easy: Object.freeze({
    interval: 16,
    deadzone: 18,
    jumpDeadzone: 18,
    safetyWidth: 18,
    enemyWeight: 7,
    distanceWeight: 11,
    usefulBias: 14,
    mistakeOdds: 0.24,
    mistakePixels: 58,
  }),
  normal: Object.freeze({
    interval: 8,
    deadzone: 12,
    jumpDeadzone: 13,
    safetyWidth: 24,
    enemyWeight: 11,
    distanceWeight: 9,
    usefulBias: 22,
    mistakeOdds: 0.09,
    mistakePixels: 34,
  }),
  hard: Object.freeze({
    interval: 3,
    deadzone: 8,
    jumpDeadzone: 9,
    safetyWidth: 31,
    enemyWeight: 16,
    distanceWeight: 7,
    usefulBias: 34,
    mistakeOdds: 0.015,
    mistakePixels: 16,
  }),
});

export { normalizeFrostAIDifficulty };

/**
 * @param {object} [options]
 * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
 * @param {() => number} [options.rng]
 * @param {number} [options.seed]
 * @returns {HexFrostAI}
 */
export function createHexFrostAI(options = {}) {
  return new HexFrostAI(options);
}

export class HexFrostAI {
  /**
   * @param {object} [options]
   * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
   * @param {() => number} [options.rng]
   * @param {number} [options.seed]
   */
  constructor(options = {}) {
    this.difficulty = normalizeFrostAIDifficulty(options.difficulty);
    this.rng =
      typeof options.rng === "function" ? options.rng : createSeededRng(options.seed || 0x66726f73);
    this.frame = 0;
    this._target = null;
  }

  /**
   * @param {"easy"|"normal"|"hard"|string} difficulty
   * @returns {void}
   */
  setDifficulty(difficulty) {
    this.difficulty = normalizeFrostAIDifficulty(difficulty);
  }

  /**
   * @param {object} request
   * @param {object} request.state
   * @param {"easy"|"normal"|"hard"|string} [request.difficulty]
   * @param {1|2} [request.player]
   * @returns {{left: boolean, right: boolean, up: boolean, down: boolean}}
   */
  nextInputs(request = {}) {
    const state = request.state;
    const player = request.player === 1 ? 1 : 2;

    this.frame++;

    if (!state || state.phase !== PHASE.BUILDING) {
      this._target = null;
      return NEUTRAL_INPUTS;
    }

    const actor = playerState(state, player);
    if (!actor || !canAct(actor)) return NEUTRAL_INPUTS;

    const difficulty = normalizeFrostAIDifficulty(request.difficulty || this.difficulty);
    if (difficulty !== this.difficulty) this.setDifficulty(difficulty);
    const config = FROST_AI_DIFFICULTIES[difficulty];

    if (this.frame % config.interval === 0 || !this._target) {
      const target = chooseFrostTarget(state, player, config);
      this._target = maybeApplyMistake(target, config, this.rng);
    }

    return movementInputs(actor, this._target, config);
  }
}

/**
 * @param {object} state
 * @param {1|2} player
 * @param {object} config
 * @returns {{x: number, row: number, reason: string, risk: number, jump: "up"|"down"|null}}
 */
export function chooseFrostTarget(state, player = 2, config = FROST_AI_DIFFICULTIES.normal) {
  const actor = playerState(state, player);
  if (!actor) return idleTarget();

  if (actor.iglooComplete && actor.row === -1) {
    const targetX = iglooCenterX(player);
    return {
      x: targetX,
      row: -1,
      reason: "igloo",
      risk: pathRisk(state, targetX, -1, player, config),
      jump: null,
    };
  }

  const targetRow = nextTargetRow(actor);
  if (targetRow === -1) {
    const targetX = iglooReturnX(state, actor, player, config);
    return {
      x: targetX,
      row: -1,
      reason: actor.iglooComplete ? "return" : "shore",
      risk: pathRisk(state, targetX, -1, player, config),
      jump: jumpDirection(actor.row, -1),
    };
  }

  const blockTarget = selectTargetBlock(state, targetRow, player, config);
  return {
    ...blockTarget,
    jump: jumpDirection(actor.row, targetRow),
  };
}

/**
 * @param {object} state
 * @param {number} rowIndex
 * @param {1|2} player
 * @param {object} config
 * @returns {{x: number, row: number, reason: string, risk: number}}
 */
export function selectTargetBlock(
  state,
  rowIndex,
  player = 2,
  config = FROST_AI_DIFFICULTIES.normal,
) {
  const row = Array.isArray(state.blockRows) ? state.blockRows[rowIndex] : null;
  const actor = playerState(state, player);
  if (!row || !Array.isArray(row.blocks) || !actor) {
    return { x: CANVAS_W / 2, row: rowIndex, reason: "fallback", risk: 0 };
  }

  let best = null;
  const ownState = player === 1 ? BLOCK_STATE.BLUE_P1 : BLOCK_STATE.BLUE_P2;
  const opponentState = player === 1 ? BLOCK_STATE.BLUE_P2 : BLOCK_STATE.BLUE_P1;

  for (let index = 0; index < row.blocks.length; index++) {
    const block = row.blocks[index];
    const x = clampX(getBlockAbsX(block, row) + BLOCK_W / 2);
    if (x < -BLOCK_W || x > CANVAS_W + BLOCK_W) continue;

    const useful =
      block.state === BLOCK_STATE.WHITE ||
      (state.mode !== GAME_MODE.PEACEFUL && block.state === opponentState);
    const ownPenalty = block.state === ownState ? config.usefulBias * 1.8 : 0;
    const risk = pathRisk(state, x, rowIndex, player, config);
    const distance = Math.abs(x - actor.x);
    const score =
      risk * config.enemyWeight +
      distance / config.distanceWeight -
      (useful ? config.usefulBias : 0) +
      ownPenalty;

    if (!best || score < best.score) {
      best = {
        x,
        row: rowIndex,
        reason: useful ? "block" : "safe",
        risk,
        score,
        block,
        index,
      };
    }
  }

  if (!best) return { x: CANVAS_W / 2, row: rowIndex, reason: "fallback", risk: 0 };
  return {
    x: best.x,
    row: best.row,
    reason: best.reason,
    risk: best.risk,
    block: best.block,
    index: best.index,
  };
}

/**
 * @param {object} actor
 * @param {{x: number, jump?: "up"|"down"|null}|null} target
 * @param {object} config
 * @returns {{left: boolean, right: boolean, up: boolean, down: boolean}}
 */
export function movementInputs(actor, target, config = FROST_AI_DIFFICULTIES.normal) {
  if (!actor || !target) return NEUTRAL_INPUTS;

  const delta = target.x - actor.x;
  const aligned = Math.abs(delta) <= config.jumpDeadzone;

  return {
    left: delta < -config.deadzone,
    right: delta > config.deadzone,
    up: aligned && target.jump === "up",
    down: aligned && target.jump === "down",
  };
}

/**
 * @param {object} state
 * @param {number} x
 * @param {number} rowIndex
 * @param {1|2} player
 * @param {object} config
 * @returns {number}
 */
export function pathRisk(state, x, rowIndex, player = 2, config = FROST_AI_DIFFICULTIES.normal) {
  if (x < EDGE_MARGIN || x > CANVAS_W - EDGE_MARGIN) return Infinity;

  let risk = edgeRisk(x);
  const enemies = Array.isArray(state.enemies) ? state.enemies : [];
  const targetY = rowY(rowIndex);

  for (const enemy of enemies) {
    const enemyRisk = enemyThreat(state, enemy, x, rowIndex, targetY, config);
    risk += enemyRisk;
  }

  const opponent = playerState(state, player === 1 ? 2 : 1);
  if (opponent && opponent.row === rowIndex && Math.abs(opponent.x - x) < BAILEY_W * 2) {
    risk += 1.5;
  }

  return risk;
}

function enemyThreat(state, enemy, x, rowIndex, targetY, config) {
  switch (enemy.type) {
    case ENEMY_TYPE.BEAR:
      if (rowIndex !== -1) return 0;
      return proximityRisk(x, enemy.x + 10, config.safetyWidth + 28, 10);
    case ENEMY_TYPE.CRAB:
      if (enemy.row !== rowIndex) return 0;
      return proximityRisk(x, enemy.x, config.safetyWidth + 18, 9);
    case ENEMY_TYPE.CLAM:
      if (enemy.row !== rowIndex || enemy.state === 0) return 0;
      return proximityRisk(x, enemy.x, config.safetyWidth + 16, 8);
    case ENEMY_TYPE.GOOSE: {
      const gooseY = ROW_Y[enemy.row] + ROW_SPACING / 2;
      const yRisk = Math.max(0, 1 - Math.abs(targetY - gooseY) / ROW_SPACING);
      return proximityRisk(x, enemy.x, config.safetyWidth + 18, 7) * yRisk;
    }
    default:
      return 0;
  }
}

function proximityRisk(x, hazardX, width, base) {
  const dx = Math.abs(x - hazardX);
  if (dx > width) return 0;
  return base * (1 - dx / width);
}

function nextTargetRow(actor) {
  if (actor.iglooComplete) return actor.row - 1;
  if (actor.row === -1) return 0;
  if (actor.row >= NUM_ROWS - 1) return actor.row - 1;
  return actor.row + 1;
}

function iglooReturnX(state, actor, player, config) {
  if (actor.iglooComplete) return iglooCenterX(player);
  const currentRisk = pathRisk(state, actor.x, -1, player, config);
  if (currentRisk < 3) return actor.x;
  return currentRisk > pathRisk(state, CANVAS_W / 2, -1, player, config) ? CANVAS_W / 2 : actor.x;
}

function jumpDirection(fromRow, toRow) {
  if (toRow < fromRow) return "up";
  if (toRow > fromRow) return "down";
  return null;
}

function playerState(state, player) {
  if (!state) return null;
  return player === 1 ? state.p1 : state.p2;
}

function canAct(actor) {
  return actor.state === BAILEY_STATE.IDLE || actor.state === BAILEY_STATE.WALKING;
}

function rowY(rowIndex) {
  if (rowIndex === -1) return SHORE_Y + SHORE_H / 2;
  return ROW_Y[rowIndex] || getBaileyY({ row: rowIndex, state: BAILEY_STATE.IDLE });
}

function iglooCenterX(player) {
  return player === 1 ? 40 + IGLOO_W / 2 : CANVAS_W - IGLOO_W - 40 + IGLOO_W / 2;
}

function idleTarget() {
  return { x: CANVAS_W / 2, row: -1, reason: "idle", risk: 0, jump: null };
}

function edgeRisk(x) {
  const left = Math.max(0, EDGE_MARGIN * 2 - x);
  const right = Math.max(0, x - (CANVAS_W - EDGE_MARGIN * 2));
  return (left + right) / 8;
}

function maybeApplyMistake(target, config, rng) {
  if (!target || rng() >= config.mistakeOdds) return target;
  const direction = rng() < 0.5 ? -1 : 1;
  return { ...target, x: clampX(target.x + direction * config.mistakePixels), reason: "mistake" };
}

function clampX(x) {
  return Math.max(EDGE_MARGIN, Math.min(CANVAS_W - EDGE_MARGIN, x));
}

function createSeededRng(seed) {
  let s = seed | 0;
  return function rng() {
    s = (s + 0x6d2b79f5) | 0;
    let t = Math.imul(s ^ (s >>> 15), 1 | s);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
