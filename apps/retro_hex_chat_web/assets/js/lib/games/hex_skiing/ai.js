/**
 * Deterministic opponent controller for Hex Skiing solo sessions.
 * It drives the same held-input shape used by P2P input transport, keeping
 * solo play on the host simulation path.
 * @module games/hex_skiing_ai
 */

import { normalizeSkiingAIDifficulty } from "./difficulty.js";
import { GAME_MODE, PHASE } from "./protocol.js";
import { CANVAS_W, SKIER_SCREEN_Y } from "./physics.js";

const EDGE_MARGIN = 24;
const NEUTRAL_INPUTS = Object.freeze({ left: false, right: false });

export const SKIING_AI_DIFFICULTIES = Object.freeze({
  easy: Object.freeze({
    interval: 14,
    obstacleLookAhead: 190,
    gateLookAhead: 420,
    itemLookAhead: 320,
    safetyWidth: 20,
    candidateStep: 24,
    deadzone: 18,
    velocityLead: 5,
    mistakeOdds: 0.28,
    mistakePixels: 60,
    gatePadding: 14,
  }),
  normal: Object.freeze({
    interval: 7,
    obstacleLookAhead: 270,
    gateLookAhead: 650,
    itemLookAhead: 500,
    safetyWidth: 28,
    candidateStep: 18,
    deadzone: 12,
    velocityLead: 8,
    mistakeOdds: 0.1,
    mistakePixels: 34,
    gatePadding: 10,
  }),
  hard: Object.freeze({
    interval: 3,
    obstacleLookAhead: 380,
    gateLookAhead: 850,
    itemLookAhead: 700,
    safetyWidth: 36,
    candidateStep: 12,
    deadzone: 8,
    velocityLead: 11,
    mistakeOdds: 0.02,
    mistakePixels: 16,
    gatePadding: 6,
  }),
});

export { normalizeSkiingAIDifficulty };

/**
 * @param {object} [options]
 * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
 * @param {() => number} [options.rng]
 * @param {number} [options.seed]
 * @returns {HexSkiingAI}
 */
export function createHexSkiingAI(options = {}) {
  return new HexSkiingAI(options);
}

export class HexSkiingAI {
  /**
   * @param {object} [options]
   * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
   * @param {() => number} [options.rng]
   * @param {number} [options.seed]
   */
  constructor(options = {}) {
    this.difficulty = normalizeSkiingAIDifficulty(options.difficulty);
    this.rng =
      typeof options.rng === "function" ? options.rng : createSeededRng(options.seed || 0x736b6969);
    this.frame = 0;
    this._target = null;
  }

  /**
   * @param {"easy"|"normal"|"hard"|string} difficulty
   * @returns {void}
   */
  setDifficulty(difficulty) {
    this.difficulty = normalizeSkiingAIDifficulty(difficulty);
  }

  /**
   * @param {object} request
   * @param {object} request.state
   * @param {"easy"|"normal"|"hard"|string} [request.difficulty]
   * @param {1|2} [request.player]
   * @returns {{left: boolean, right: boolean}}
   */
  nextInputs(request = {}) {
    const state = request.state;
    const player = request.player === 1 ? 1 : 2;

    this.frame++;

    if (!state || state.phase !== PHASE.RACING) {
      this._target = null;
      return NEUTRAL_INPUTS;
    }

    const actor = playerState(state, player);
    if (!actor || actor.stunTimer > 0) return NEUTRAL_INPUTS;

    const difficulty = normalizeSkiingAIDifficulty(request.difficulty || this.difficulty);
    if (difficulty !== this.difficulty) this.setDifficulty(difficulty);
    const config = SKIING_AI_DIFFICULTIES[difficulty];

    if (this.frame % config.interval === 0 || !this._target) {
      const target = chooseSkiingTarget(state, player, config);
      this._target = maybeApplyMistake(target, config, this.rng);
    }

    return movementInputs(actor, this._target, config);
  }
}

/**
 * @param {object} state
 * @param {1|2} player
 * @param {object} config
 * @returns {{x: number, reason: string, risk: number}}
 */
export function chooseSkiingTarget(state, player = 2, config = SKIING_AI_DIFFICULTIES.normal) {
  const actor = playerState(state, player);
  if (!actor) return { x: CANVAS_W / 2, reason: "idle", risk: 0 };

  const gate = nearestGate(state, player, config);
  const boost = nearestBoostItem(state, config);
  let preferredX = actor.x;
  let reason = "cruise";
  let gateBounds = null;

  if (gate) {
    preferredX = gate.x + gate.width / 2;
    gateBounds = gate;
    reason = "gate";
  } else if (boost) {
    preferredX = boost.x;
    reason = "boost";
  }

  if (state.mode === GAME_MODE.AVALANCHE_ESCAPE && boost) {
    preferredX = boost.x;
    reason = "boost";
    gateBounds = null;
  }

  const preferredRisk = pathRisk(state, preferredX, player, config);
  const target = safestXNear(state, player, preferredX, config, gateBounds);
  const risk = pathRisk(state, target, player, config);

  return {
    x: target,
    reason: preferredRisk >= 7 && risk < preferredRisk ? "avoid" : reason,
    risk,
  };
}

/**
 * @param {object} actor
 * @param {{x: number}|null} target
 * @param {object} config
 * @returns {{left: boolean, right: boolean}}
 */
export function movementInputs(actor, target, config = SKIING_AI_DIFFICULTIES.normal) {
  if (!actor || !target) return NEUTRAL_INPUTS;

  const projectedX = actor.x + (actor.velX || 0) * config.velocityLead;
  const delta = target.x - projectedX;

  return {
    left: delta < -config.deadzone,
    right: delta > config.deadzone,
  };
}

/**
 * @param {object} state
 * @param {1|2} player
 * @param {object} config
 * @returns {object|null}
 */
export function nearestGate(state, player = 2, config = SKIING_AI_DIFFICULTIES.normal) {
  const gates = Array.isArray(state.gates) ? state.gates : [];
  const skierY = skierWorldY(state);
  const clearedKey = player === 1 ? "clearedP1" : "clearedP2";

  return (
    gates
      .filter((gate) => !gate[clearedKey])
      .filter((gate) => gate.y >= skierY - 8 && gate.y <= skierY + config.gateLookAhead)
      .sort((a, b) => a.y - b.y)[0] || null
  );
}

/**
 * @param {object} state
 * @param {object} config
 * @returns {object|null}
 */
export function nearestBoostItem(state, config = SKIING_AI_DIFFICULTIES.normal) {
  if (state.mode === GAME_MODE.CLEAN_RUN) return null;

  const items = Array.isArray(state.items) ? state.items : [];
  const skierY = skierWorldY(state);

  return (
    items
      .filter((item) => item.collected === 0)
      .filter((item) => item.y >= skierY - 8 && item.y <= skierY + config.itemLookAhead)
      .sort((a, b) => a.y - b.y)[0] || null
  );
}

/**
 * @param {object} state
 * @param {number} x
 * @param {1|2} player
 * @param {object} config
 * @returns {number}
 */
export function pathRisk(state, x, player = 2, config = SKIING_AI_DIFFICULTIES.normal) {
  if (x < EDGE_MARGIN || x > CANVAS_W - EDGE_MARGIN) return Infinity;

  const skierY = skierWorldY(state);
  const obstacles = Array.isArray(state.obstacles) ? state.obstacles : [];
  let risk = edgeRisk(x);

  for (const obstacle of obstacles) {
    const dy = obstacle.y - skierY;
    if (dy < -24 || dy > config.obstacleLookAhead) continue;

    const width = (obstacle.w || 10) / 2 + config.safetyWidth;
    const dx = Math.abs(x - obstacle.x);
    if (dx > width) continue;

    const lateralOverlap = (width - dx) / width;
    const proximity = 1 - Math.max(0, dy) / config.obstacleLookAhead;
    const base = obstacle.type === "ice" ? 4 : obstacle.type === "rock" ? 13 : 16;
    risk += base * lateralOverlap * (0.45 + proximity);
  }

  const opponent = playerState(state, player === 1 ? 2 : 1);
  if (opponent) {
    const opponentDx = Math.abs(x - opponent.x);
    if (opponentDx < 16) risk += 2 * (1 - opponentDx / 16);
  }

  return risk;
}

/**
 * @param {object} state
 * @param {1|2} player
 * @param {number} preferredX
 * @param {object} config
 * @param {object|null} gate
 * @returns {number}
 */
export function safestXNear(state, player, preferredX, config, gate = null) {
  let bestX = clampX(preferredX);
  let bestScore = Infinity;

  for (let x = EDGE_MARGIN; x <= CANVAS_W - EDGE_MARGIN; x += config.candidateStep) {
    let score = pathRisk(state, x, player, config) * 12 + Math.abs(x - preferredX) / 9;

    if (gate) {
      const minGateX = gate.x + config.gatePadding;
      const maxGateX = gate.x + gate.width - config.gatePadding;
      if (x < minGateX || x > maxGateX) {
        score += 16 + Math.min(Math.abs(x - minGateX), Math.abs(x - maxGateX)) / 5;
      }
    }

    if (score < bestScore) {
      bestScore = score;
      bestX = x;
    }
  }

  return bestX;
}

function playerState(state, player) {
  if (!state) return null;
  return player === 1 ? state.p1 : state.p2;
}

function skierWorldY(state) {
  return (state.scrollY || 0) + SKIER_SCREEN_Y;
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
