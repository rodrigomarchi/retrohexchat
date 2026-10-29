/**
 * Deterministic opponent controller for Hex Frost solo sessions.
 * It emits the same held-input shape used by the P2P peer path, keeping the
 * host simulation shared between solo and network play.
 *
 * It plays from what is on screen, as a person does: it sees the ice a
 * reaction time late, picks a block it can see, and hops when it judges the
 * block will be under it on landing. That judgement carries one aim error,
 * drawn per jump and kept until the jump, so a misjudged hop ends in the
 * water.
 * @module games/hex_frost_ai
 */

import { normalizeFrostAIDifficulty } from "./difficulty.js";
import { BAILEY_STATE, BLOCK_STATE, ENEMY_TYPE, GAME_MODE, PHASE } from "./protocol.js";
import {
  BAILEY_W,
  BLOCK_W,
  CANVAS_W,
  IGLOO_W,
  JUMP_DURATION,
  NUM_ROWS,
  ROW_SPACING,
  ROW_Y,
  SHORE_H,
  SHORE_Y,
  getBlockAbsX,
  getBlockSpeed,
} from "./physics.js";
import {
  TableAI,
  createCommitment,
  createDelayedView,
  dutyFrame,
  edgeAware,
  toward,
} from "../core/ai.js";

const EDGE_MARGIN = 18;
const { edgeRisk } = edgeAware(CANVAS_W, EDGE_MARGIN);
const NEUTRAL_INPUTS = Object.freeze({ left: false, right: false, up: false, down: false });
// How far inside its own block the AI keeps while it walks.
const FOOTING = 8;
// A bear this close on the shore is one to get away from.
const BEAR_REACH = 44;
// A landing spot this risky is not jumped to.
const JUMP_RISK = 2;

export const FROST_AI_DIFFICULTIES = Object.freeze({
  easy: Object.freeze({
    reaction: 20,
    interval: 14,
    deadzone: 4,
    landMargin: 5.5,
    aimError: 13.5,
    walkDuty: 0.85,
    safetyWidth: 14,
    enemyWeight: 7,
    distanceWeight: 11,
    usefulBias: 14,
  }),
  normal: Object.freeze({
    reaction: 16,
    interval: 8,
    deadzone: 3,
    landMargin: 5.75,
    aimError: 13.25,
    walkDuty: 0.9,
    safetyWidth: 22,
    enemyWeight: 11,
    distanceWeight: 9,
    usefulBias: 22,
  }),
  hard: Object.freeze({
    reaction: 15,
    interval: 4,
    deadzone: 2,
    landMargin: 7,
    aimError: 12,
    walkDuty: 0.95,
    safetyWidth: 30,
    enemyWeight: 16,
    distanceWeight: 7,
    usefulBias: 34,
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

export class HexFrostAI extends TableAI {
  /**
   * @param {object} [options]
   * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
   * @param {() => number} [options.rng]
   * @param {number} [options.seed]
   */
  constructor(options = {}) {
    super(options, normalizeFrostAIDifficulty, FROST_AI_DIFFICULTIES, 0x66726f73);
    this._view = createDelayedView();
    this._aim = createCommitment();
    this.forget();
  }

  /**
   * @param {object} request
   * @param {object} request.state
   * @param {"easy"|"normal"|"hard"|string} [request.difficulty]
   * @param {1|2} [request.player]
   * @returns {{left: boolean, right: boolean, up: boolean, down: boolean}}
   */
  nextInputs(request = {}) {
    const { state, player } = this.startTurn(request);

    if (!state || state.phase !== PHASE.BUILDING) return NEUTRAL_INPUTS;

    const config = this.rowFor(request);

    const seen = this._view.see(state, config.reaction);
    this._watched++;
    const actor = playerState(state, player);
    if (!actor || !canAct(actor)) return NEUTRAL_INPUTS;
    // A round's first moments go to taking in the ice.
    if (this._watched <= config.reaction) return NEUTRAL_INPUTS;

    // A new row is a new hop to judge; back on the shore, it starts down again.
    if (actor.row !== this._row) {
      if (actor.row === -1) this._heading = 1;
      this._row = actor.row;
      this._hops++;
      this._target = null;
    }

    // It answers only what it has had time to see: itself standing where it is now.
    const seenActor = playerState(seen, player);
    if (!seenActor || !canAct(seenActor) || seenActor.row !== actor.row) {
      return holdFooting(state, actor, config);
    }

    if (
      this.frame % config.interval === 0 ||
      !this._target ||
      !targetVisible(state, this._target)
    ) {
      const target = chooseFrostTarget(seen, player, config, this._heading);
      if (target.row >= 0 && actor.row >= 0) this._heading = target.row > actor.row ? 1 : -1;
      this._target = target;
    }

    const target = this._target;
    const error = this._aim.hold(`${this._hops}:${target.row}:${target.index}`, () =>
      aimError(this.rng, config.aimError),
    );
    const inputs = steer(state, seen, actor, target, config, error);
    if (!dutyFrame(this.frame, config.walkDuty) && !inputs.up && !inputs.down) {
      return holdFooting(state, actor, config);
    }
    return inputs;
  }

  /**
   * A new round: what it saw, the aim it committed to, its hops and the way
   * it was heading all belong to the last one.
   * @returns {void}
   */
  forget() {
    this._view.reset();
    this._aim.reset();
    this._target = null;
    this._heading = 1;
    this._row = -1;
    this._hops = 0;
    this._watched = 0;
  }
}

/**
 * Where to go next: home once the igloo is built, else a block on the row
 * ahead in `heading` — or the row behind when that one has nothing to take.
 * @param {object} state - the state the AI sees
 * @param {1|2} player
 * @param {object} config
 * @param {1|-1} [heading] - 1 toward the water, -1 toward the shore
 * @returns {{x: number, row: number, index?: number, reason: string, risk: number}}
 */
export function chooseFrostTarget(
  state,
  player = 2,
  config = FROST_AI_DIFFICULTIES.normal,
  heading = 1,
) {
  const actor = playerState(state, player);
  if (!actor) return idleTarget();

  if (actor.iglooComplete) {
    const x = iglooCenterX(player);
    if (actor.row === -1) {
      return { x, row: -1, reason: "igloo", risk: pathRisk(state, x, -1, player, config) };
    }
    return { x: actor.x, row: actor.row - 1, ...rowTarget(state, actor.row - 1, player, config) };
  }

  if (actor.row === -1) return selectTargetBlock(state, 0, player, config);

  const ahead = actor.row + heading;
  const behind = actor.row - heading;
  const rows = [ahead, behind].filter((row) => row >= 0 && row < NUM_ROWS);
  let fallback = null;
  for (const row of rows) {
    const target = selectTargetBlock(state, row, player, config);
    if (target.reason === "block") return target;
    fallback ??= target;
  }
  return fallback ?? idleTarget();
}

/**
 * The best block to land on in a row, of those wholly on screen.
 * @param {object} state
 * @param {number} rowIndex
 * @param {1|2} player
 * @param {object} config
 * @returns {{x: number, row: number, index?: number, reason: string, risk: number}}
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
  const drift = row.direction * getBlockSpeed(state) * JUMP_DURATION;

  for (let index = 0; index < row.blocks.length; index++) {
    const block = row.blocks[index];
    const left = getBlockAbsX(block, row);
    if (!onScreen(left)) continue;

    const x = left + BLOCK_W / 2;
    const useful =
      block.state === BLOCK_STATE.WHITE ||
      (state.mode !== GAME_MODE.PEACEFUL && block.state === opponentState);
    const ownPenalty = block.state === ownState ? config.usefulBias * 1.8 : 0;
    const risk = pathRisk(state, x + drift, rowIndex, player, config);
    const distance = Math.abs(x + drift - actor.x);
    const score =
      risk * config.enemyWeight +
      distance / config.distanceWeight -
      (useful ? config.usefulBias : 0) +
      ownPenalty;

    if (!best || score < best.score) {
      best = { x, row: rowIndex, index, reason: useful ? "block" : "safe", risk, score };
    }
  }

  if (!best) return { x: CANVAS_W / 2, row: rowIndex, reason: "fallback", risk: 0 };
  return { x: best.x, row: best.row, index: best.index, reason: best.reason, risk: best.risk };
}

/**
 * Where a block will be once a jump started now lands: its left and right
 * edges, or null for one that is off screen by then.
 * @param {object} state
 * @param {number} rowIndex
 * @param {number} index
 * @returns {[number, number] | null}
 */
export function landingSpan(state, rowIndex, index) {
  const row = state.blockRows?.[rowIndex];
  const block = row?.blocks?.[index];
  if (!block) return null;
  const left = getBlockAbsX(block, row);
  const landing = left + row.direction * getBlockSpeed(state) * JUMP_DURATION;
  if (!onScreen(left) || !onScreen(landing)) return null;
  return [landing, landing + BLOCK_W];
}

/**
 * The keys for one frame: walk to where the target block will be on
 * landing — never off the block underfoot — and jump once the AI judges,
 * with its aim `error`, that it will land at least `landMargin` inside.
 * @param {object} state - the live state: blocks move on rails, so their
 *   positions are known
 * @param {object} seen - the state the AI sees, for enemies
 * @param {object} actor
 * @param {{x: number, row: number, index?: number}} target
 * @param {object} config
 * @param {number} [error] - how far off the AI is about where it stands
 * @returns {{left: boolean, right: boolean, up: boolean, down: boolean}}
 */
export function steer(state, seen, actor, target, config, error = 0) {
  if (!actor || !target) return NEUTRAL_INPUTS;
  const jumpKey = target.row < actor.row ? "up" : "down";
  const judged = actor.x + error;

  if (target.row === -1 && actor.row === -1) {
    return walk(state, actor, avoidBear(seen, actor.x, target.x), config);
  }

  if (target.row === -1) {
    if (bearNear(seen, actor.x)) return holdFooting(state, actor, config);
    return { ...NEUTRAL_INPUTS, up: true };
  }

  const span = landingSpan(state, target.row, target.index);
  if (!span) return holdFooting(state, actor, config);

  const [left, right] = span;
  const inside = Math.min(judged - left, right - judged);
  const risk = pathRisk(seen, actor.x, target.row, actor.playerNum ?? 2, config);
  if (inside >= config.landMargin && risk < JUMP_RISK) {
    return { ...NEUTRAL_INPUTS, [jumpKey]: true };
  }

  // On the shore it keeps clear of the bear while it lines up.
  const goal = (left + right) / 2 - error;
  if (actor.row === -1) return walk(state, actor, avoidBear(seen, actor.x, goal), config);
  return walk(state, actor, goal, config);
}

/**
 * How risky a spot is: enemies near it, the screen's edges, the opponent.
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
    if (enemy.x < -BLOCK_W || enemy.x > CANVAS_W) continue;
    risk += enemyThreat(enemy, x, rowIndex, targetY, config);
  }

  const opponent = playerState(state, player === 1 ? 2 : 1);
  if (opponent && opponent.row === rowIndex && Math.abs(opponent.x - x) < BAILEY_W * 2) {
    risk += 1.5;
  }

  return risk;
}

function enemyThreat(enemy, x, rowIndex, targetY, config) {
  switch (enemy.type) {
    case ENEMY_TYPE.BEAR:
      if (rowIndex !== -1) return 0;
      return proximityRisk(x, enemy.x + 10, config.safetyWidth + 28, 10);
    case ENEMY_TYPE.CRAB:
      if (enemy.row !== rowIndex) return 0;
      return proximityRisk(x, enemy.x, config.safetyWidth + 18, 9);
    case ENEMY_TYPE.CLAM:
      if (enemy.row !== rowIndex) return 0;
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

/** One aim error in pixels, most often small: the sum of two draws. */
function aimError(rng, size) {
  return (rng() + rng() - 1) * size;
}

/** Walk toward `goal`, kept on the block underfoot. */
function walk(state, actor, goal, config) {
  const footing = footingSpan(state, actor);
  const to = footing ? Math.max(footing[0], Math.min(footing[1], goal)) : goal;
  const [left, right] = toward(actor.x, to, config.deadzone);
  return { ...NEUTRAL_INPUTS, left, right };
}

/** Stay on the block underfoot as it drifts. */
function holdFooting(state, actor, config) {
  const footing = footingSpan(state, actor);
  if (!footing) return NEUTRAL_INPUTS;
  return walk(state, actor, actor.x, config);
}

/**
 * Where a bailey can stand on the block underfoot, `FOOTING` pixels in from
 * either edge; null on the shore or over water.
 * @param {object} state
 * @param {{x: number, row: number}} actor
 * @returns {[number, number] | null}
 */
export function footingSpan(state, actor) {
  if (actor.row < 0) return null;
  const row = state.blockRows?.[actor.row];
  if (!row) return null;
  for (const block of row.blocks) {
    const left = getBlockAbsX(block, row);
    if (actor.x >= left && actor.x <= left + BLOCK_W) {
      return [left + FOOTING, left + BLOCK_W - FOOTING];
    }
  }
  return null;
}

function rowTarget(state, rowIndex, player, config) {
  if (rowIndex === -1) {
    return { reason: "return", risk: 0 };
  }
  const target = selectTargetBlock(state, rowIndex, player, config);
  return { x: target.x, index: target.index, reason: "return", risk: target.risk };
}

/**
 * A bear on the shore within `reach` of `x`, or undefined.
 * @param {object} state
 * @param {number} x
 * @param {number} [reach]
 * @returns {object | undefined}
 */
export function bearNear(state, x, reach = BEAR_REACH) {
  const enemies = Array.isArray(state?.enemies) ? state.enemies : [];
  return enemies.find(
    (enemy) => enemy.type === ENEMY_TYPE.BEAR && Math.abs(enemy.x + 10 - x) < reach,
  );
}

/**
 * A goal on the shore that keeps away from a bear within `reach`: `goal`
 * itself when none is that close.
 * @param {object} state
 * @param {number} x
 * @param {number} goal
 * @param {number} [reach]
 * @returns {number}
 */
export function avoidBear(state, x, goal, reach = BEAR_REACH) {
  const bear = bearNear(state, x, reach);
  if (!bear) return goal;
  return bear.x + 10 > x ? x - reach : x + reach;
}

function targetVisible(state, target) {
  if (target.row === -1) return true;
  return landingSpan(state, target.row, target.index) !== null;
}

function onScreen(left) {
  return left >= 0 && left + BLOCK_W <= CANVAS_W;
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
  return ROW_Y[rowIndex];
}

function iglooCenterX(player) {
  return player === 1 ? 40 + IGLOO_W / 2 : CANVAS_W - IGLOO_W - 40 + IGLOO_W / 2;
}

function idleTarget() {
  return { x: CANVAS_W / 2, row: -1, reason: "idle", risk: 0 };
}
