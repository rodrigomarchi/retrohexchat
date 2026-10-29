/**
 * Deterministic opponent controller for Hex Skiing solo sessions.
 * It drives the same held-input shape used by P2P input transport, keeping
 * solo play on the host simulation path.
 *
 * It plays like a person at the keys: it sees only the slope on screen
 * below the skier, sees it `reaction` frames late, and aims with an error
 * drawn once per gate it heads for (once per look when there is none), so a
 * bad line into a gate stays bad and costs the gate.
 * @module games/hex_skiing_ai
 */

import { normalizeSkiingAIDifficulty } from "./difficulty.js";
import { GAME_MODE, PHASE } from "./protocol.js";
import { CANVAS_H, CANVAS_W, SKIER_SCREEN_Y } from "./physics.js";
import { TableAI, createCommitment, createDelayedView, edgeAware, randomUnit } from "../core/ai.js";

const EDGE_MARGIN = 24;
// How far down the slope the screen shows below the skier.
export const VIEW_AHEAD = CANVAS_H - SKIER_SCREEN_Y;
const { clampX, edgeRisk } = edgeAware(CANVAS_W, EDGE_MARGIN);
const NEUTRAL_INPUTS = Object.freeze({ left: false, right: false });

export const SKIING_AI_DIFFICULTIES = Object.freeze({
  easy: Object.freeze({
    interval: 8,
    reaction: 8,
    obstacleLookAhead: 80,
    gateLookAhead: VIEW_AHEAD,
    itemLookAhead: VIEW_AHEAD,
    safetyWidth: 8,
    candidateStep: 24,
    deadzone: 14,
    velocityLead: 6,
    aimError: 6,
    gatePadding: 8,
  }),
  normal: Object.freeze({
    interval: 8,
    reaction: 7,
    obstacleLookAhead: 80,
    gateLookAhead: VIEW_AHEAD,
    itemLookAhead: VIEW_AHEAD,
    safetyWidth: 8,
    candidateStep: 18,
    deadzone: 10,
    velocityLead: 8,
    aimError: 4,
    gatePadding: 12,
  }),
  hard: Object.freeze({
    interval: 8,
    reaction: 7,
    obstacleLookAhead: VIEW_AHEAD,
    gateLookAhead: VIEW_AHEAD,
    itemLookAhead: VIEW_AHEAD,
    safetyWidth: 12,
    candidateStep: 12,
    deadzone: 10,
    velocityLead: 8,
    aimError: 3,
    gatePadding: 12,
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

export class HexSkiingAI extends TableAI {
  /**
   * @param {object} [options]
   * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
   * @param {() => number} [options.rng]
   * @param {number} [options.seed]
   */
  constructor(options = {}) {
    super(options, normalizeSkiingAIDifficulty, SKIING_AI_DIFFICULTIES, 0x736b6969);
    this._target = null;
    this._looks = 0;
    this._view = createDelayedView();
    this._aim = createCommitment();
  }

  /**
   * A new round is a new slope: what it saw, the line it held and the aim
   * it committed to all belonged to the last one.
   * @returns {void}
   */
  forget() {
    this._target = null;
    this._view.reset();
    this._aim.reset();
  }

  /**
   * @param {object} request
   * @param {object} request.state
   * @param {"easy"|"normal"|"hard"|string} [request.difficulty]
   * @param {1|2} [request.player]
   * @returns {{left: boolean, right: boolean}}
   */
  nextInputs(request = {}) {
    const { state, player } = this.startTurn(request);

    if (!state || state.phase !== PHASE.RACING) {
      this.forget();
      return NEUTRAL_INPUTS;
    }

    const config = this.rowFor(request);
    // It knows where its own skier is now, but sees the slope late — and
    // keeps watching it while down after a crash.
    const seen = this._view.see(state, config.reaction);

    const actor = playerState(state, player);
    if (!actor || actor.stunTimer > 0) return NEUTRAL_INPUTS;
    if (this.frame % config.interval === 0 || !this._target) {
      this._looks++;
      const target = chooseSkiingTarget(seen, player, config);
      const error = this._aim.hold(target.gateY ?? -this._looks, () => gaussian(this.rng));
      this._target = { ...target, x: clampX(target.x + error * config.aimError) };
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
    gateY: gateBounds ? gateBounds.y : null,
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
      .filter((gate) => gate.y >= skierY - 8 && gate.y <= skierY + lookAhead(config.gateLookAhead))
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
      .filter((item) => item.y >= skierY - 8 && item.y <= skierY + lookAhead(config.itemLookAhead))
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
  const ahead = lookAhead(config.obstacleLookAhead);
  let risk = edgeRisk(x);

  for (const obstacle of obstacles) {
    const dy = obstacle.y - skierY;
    if (dy < -24 || dy > ahead) continue;

    const width = (obstacle.w || 10) / 2 + config.safetyWidth;
    const dx = Math.abs(x - obstacle.x);
    if (dx > width) continue;

    const lateralOverlap = (width - dx) / width;
    const proximity = 1 - Math.max(0, dy) / ahead;
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

/** A look-ahead no further than the screen shows. */
function lookAhead(distance) {
  return Math.min(distance, VIEW_AHEAD);
}

/**
 * A standard normal draw: how far off, in aim errors, a line is.
 * @param {() => number} rng
 * @returns {number}
 */
export function gaussian(rng) {
  const radius = Math.sqrt(-2 * Math.log(1 - randomUnit(rng)));
  return radius * Math.cos(2 * Math.PI * randomUnit(rng));
}
