/**
 * Deterministic opponent controller for Hex Enduro solo sessions.
 * It emits the same held-input shape used by the P2P peer path, keeping the
 * host simulation shared between solo and network play.
 * @module games/hex_enduro_ai
 */

import { normalizeEnduroAIDifficulty } from "./difficulty.js";
import { GAME_MODE, PHASE } from "./protocol.js";
import { LANE_COUNT, SPEED_MAX, TURBO_FUEL_COST } from "./physics.js";

const COLLISION_ZONE_Z = 40;
const PLAYER_COLLISION_BUFFER_Z = 135;
const CRUISE_LANE = 1;

const NEUTRAL_INPUTS = Object.freeze({
  left: false,
  right: false,
  accel: false,
  brake: false,
  turbo: false,
});

export const ENDURO_AI_DIFFICULTIES = Object.freeze({
  easy: Object.freeze({
    interval: 12,
    laneMistake: 0.28,
    threatZ: 260,
    fuelAt: 260,
    fuelZ: 900,
    targetSpeed: 610,
    brakeSpeed: 360,
    turboOdds: 0.22,
    turboCd: 520,
    slipstreamBias: 0.25,
  }),
  normal: Object.freeze({
    interval: 6,
    laneMistake: 0.12,
    threatZ: 360,
    fuelAt: 390,
    fuelZ: 1150,
    targetSpeed: 720,
    brakeSpeed: 430,
    turboOdds: 0.5,
    turboCd: 360,
    slipstreamBias: 0.45,
  }),
  hard: Object.freeze({
    interval: 2,
    laneMistake: 0.02,
    threatZ: 520,
    fuelAt: 520,
    fuelZ: 1450,
    targetSpeed: 820,
    brakeSpeed: 520,
    turboOdds: 0.85,
    turboCd: 240,
    slipstreamBias: 0.65,
  }),
});

export { normalizeEnduroAIDifficulty };

/**
 * @param {object} [options]
 * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
 * @param {() => number} [options.rng]
 * @param {number} [options.seed]
 * @returns {HexEnduroAI}
 */
export function createHexEnduroAI(options = {}) {
  return new HexEnduroAI(options);
}

export class HexEnduroAI {
  /**
   * @param {object} [options]
   * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
   * @param {() => number} [options.rng]
   * @param {number} [options.seed]
   */
  constructor(options = {}) {
    this.difficulty = normalizeEnduroAIDifficulty(options.difficulty);
    this.rng =
      typeof options.rng === "function" ? options.rng : createSeededRng(options.seed || 0x656e6475);
    this.frame = 0;
    this.turboCooldown = 0;
    this._target = null;
  }

  /**
   * @param {"easy"|"normal"|"hard"|string} difficulty
   * @returns {void}
   */
  setDifficulty(difficulty) {
    this.difficulty = normalizeEnduroAIDifficulty(difficulty);
  }

  /**
   * @param {object} request
   * @param {object} request.state
   * @param {"easy"|"normal"|"hard"|string} [request.difficulty]
   * @param {1|2} [request.player]
   * @returns {{left: boolean, right: boolean, accel: boolean, brake: boolean, turbo: boolean}}
   */
  nextInputs(request = {}) {
    const state = request.state;
    const player = request.player === 1 ? 1 : 2;

    this.frame++;
    if (this.turboCooldown > 0) this.turboCooldown--;

    if (!state || state.phase !== PHASE.RACING) {
      this._target = null;
      return NEUTRAL_INPUTS;
    }

    const actor = playerState(state, player);
    if (!actor) return NEUTRAL_INPUTS;

    const difficulty = normalizeEnduroAIDifficulty(request.difficulty || this.difficulty);
    if (difficulty !== this.difficulty) this.setDifficulty(difficulty);
    const config = ENDURO_AI_DIFFICULTIES[difficulty];

    if (this.frame % config.interval === 0 || !this._target) {
      const target = chooseEnduroTarget(state, player, config, this.rng);
      this._target = maybeApplyLaneMistake(target, state, player, config, this.rng);
    }

    const movement = movementInputs(state, player, this._target);
    const turbo = this._turboPressed(state, player, this._target, config);
    return { ...movement, turbo };
  }

  /**
   * @param {object} state
   * @param {1|2} player
   * @param {{lane: number, targetSpeed: number}} target
   * @param {object} config
   * @returns {boolean}
   */
  _turboPressed(state, player, target, config) {
    if (this.turboCooldown > 0) return false;
    if (!shouldUseTurbo(state, player, target, config)) return false;
    if (this.rng() > config.turboOdds) return false;

    this.turboCooldown = config.turboCd;
    return true;
  }
}

/**
 * @param {object} state
 * @param {1|2} player
 * @param {object} config
 * @param {() => number} [rng]
 * @returns {{lane: number, targetSpeed: number, reason: string}}
 */
export function chooseEnduroTarget(
  state,
  player = 2,
  config = ENDURO_AI_DIFFICULTIES.normal,
  rng = Math.random,
) {
  const actor = playerState(state, player);
  if (!actor) return { lane: CRUISE_LANE, targetSpeed: 0, reason: "idle" };

  const fuel = nearestFuelStation(state, player, config);
  if (fuel) {
    return {
      lane: fuel.lane,
      targetSpeed: fuel.zPos < 180 ? Math.min(actor.speed, config.brakeSpeed) : config.targetSpeed,
      reason: "fuel",
    };
  }

  const opponent = playerState(state, player === 1 ? 2 : 1);
  const slipstream = slipstreamLane(actor, opponent, config, rng);
  if (slipstream !== null && laneRisk(state, slipstream, player, config) < 6) {
    return { lane: slipstream, targetSpeed: config.targetSpeed, reason: "slipstream" };
  }

  const lane = safestLane(state, player, config);
  const risk = laneRisk(state, lane, player, config);

  return {
    lane,
    targetSpeed: risk >= 8 ? config.brakeSpeed : config.targetSpeed,
    reason: risk >= 8 ? "avoid" : "cruise",
  };
}

/**
 * @param {object} state
 * @param {1|2} player
 * @param {{lane: number, targetSpeed?: number}|null} target
 * @returns {{left: boolean, right: boolean, accel: boolean, brake: boolean, turbo: boolean}}
 */
export function movementInputs(state, player, target) {
  const actor = playerState(state, player);
  if (!actor || !target) return NEUTRAL_INPUTS;

  const currentTargetLane = Number.isInteger(actor.targetLane) ? actor.targetLane : actor.lane;
  const laneDelta = target.lane - currentTargetLane;
  const targetSpeed = target.targetSpeed ?? SPEED_MAX;
  const speedGap = targetSpeed - actor.speed;

  return {
    left: laneDelta < 0,
    right: laneDelta > 0,
    accel: speedGap > 18,
    brake: speedGap < -35,
    turbo: false,
  };
}

/**
 * @param {object} state
 * @param {number} lane
 * @param {1|2} player
 * @param {object} config
 * @returns {number}
 */
export function laneRisk(state, lane, player = 2, config = ENDURO_AI_DIFFICULTIES.normal) {
  const actor = playerState(state, player);
  if (!actor || lane < 0 || lane >= LANE_COUNT) return Infinity;

  let risk = Math.abs(lane - actor.lane) * 0.55;
  const cars = Array.isArray(state.aiCars) ? state.aiCars : [];
  for (const car of cars) {
    if (car.lane !== lane) continue;
    if (car.zPos < -COLLISION_ZONE_Z || car.zPos > config.threatZ) continue;

    if (Math.abs(car.zPos) < COLLISION_ZONE_Z) {
      risk += 30;
    } else {
      risk += 9 * (1 - car.zPos / config.threatZ);
    }
  }

  const opponent = playerState(state, player === 1 ? 2 : 1);
  if (opponent && opponent.lane === lane) {
    const relativeZ = Math.abs(actor.zOffset - opponent.zOffset);
    if (relativeZ < PLAYER_COLLISION_BUFFER_Z) {
      risk += 12 * (1 - relativeZ / PLAYER_COLLISION_BUFFER_Z);
    }
  }

  return risk;
}

/**
 * @param {object} state
 * @param {1|2} player
 * @param {object} config
 * @returns {{lane: number, zPos: number}|null}
 */
export function nearestFuelStation(state, player = 2, config = ENDURO_AI_DIFFICULTIES.normal) {
  if (state.mode === GAME_MODE.SPRINT) return null;

  const actor = playerState(state, player);
  if (!actor || actor.fuel > config.fuelAt) return null;

  const stations = Array.isArray(state.fuelStations) ? state.fuelStations : [];
  let best = null;
  let bestScore = Infinity;

  for (const station of stations) {
    if (station.zPos < -20 || station.zPos > config.fuelZ) continue;
    const score = station.zPos + Math.abs(station.lane - actor.lane) * 180;
    if (score < bestScore) {
      best = station;
      bestScore = score;
    }
  }

  return best;
}

/**
 * @param {object} state
 * @param {1|2} player
 * @param {{lane: number}|null} target
 * @param {object} config
 * @returns {boolean}
 */
export function shouldUseTurbo(
  state,
  player = 2,
  target = null,
  config = ENDURO_AI_DIFFICULTIES.normal,
) {
  const actor = playerState(state, player);
  if (!actor || state.phase !== PHASE.RACING) return false;
  if (actor.boost > 0 || actor.turboCooldown > 0 || actor.collisionTimer > 0) return false;
  if (state.mode !== GAME_MODE.SPRINT && actor.fuel < TURBO_FUEL_COST + 120) return false;
  if (target && target.lane !== actor.lane) return false;
  if (laneRisk(state, actor.lane, player, config) >= 4) return false;

  const opponent = playerState(state, player === 1 ? 2 : 1);
  const chasing = opponent ? opponent.zOffset >= actor.zOffset - 40 : false;
  return actor.speed >= Math.min(config.targetSpeed - 80, SPEED_MAX - 80) && chasing;
}

function safestLane(state, player, config) {
  let bestLane = CRUISE_LANE;
  let bestRisk = Infinity;

  for (let lane = 0; lane < LANE_COUNT; lane++) {
    const risk = laneRisk(state, lane, player, config);
    if (risk < bestRisk) {
      bestLane = lane;
      bestRisk = risk;
    }
  }

  return bestLane;
}

function slipstreamLane(actor, opponent, config, rng) {
  if (!opponent) return null;

  const opponentAhead = opponent.zOffset > actor.zOffset + 45;
  const closeEnough = opponent.zOffset - actor.zOffset < 260;
  if (!opponentAhead || !closeEnough) return null;
  if (rng() > config.slipstreamBias) return null;

  return opponent.lane;
}

function maybeApplyLaneMistake(target, state, player, config, rng) {
  if (rng() >= config.laneMistake) return target;

  const actor = playerState(state, player);
  if (!actor) return target;

  const drift = rng() < 0.5 ? -1 : 1;
  const lane = clampLane(target.lane + drift);
  return { ...target, lane };
}

function playerState(state, player) {
  return player === 1 ? state?.p1 : state?.p2;
}

function clampLane(lane) {
  return Math.max(0, Math.min(LANE_COUNT - 1, lane));
}

function createSeededRng(seed) {
  let value = seed >>> 0;
  return () => {
    value = (value + 0x6d2b79f5) | 0;
    let t = Math.imul(value ^ (value >>> 15), 1 | value);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
