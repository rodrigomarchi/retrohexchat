/**
 * Deterministic opponent controller for Hex Raid solo sessions.
 * The controller emits the same held-input shape used by the P2P guest path,
 * keeping solo and P2P on the same host-authoritative simulation.
 *
 * @module games/hex_raid_ai
 */

import { normalizeRaidAIDifficulty } from "./difficulty.js";
import { GAME_MODE, PHASE } from "./protocol.js";
import {
  CANVAS_H,
  CANVAS_W,
  JET_RADIUS,
  MAX_MINES_PER_PLAYER,
  SPEED_BASE,
  SPEED_MAX,
  SPEED_MIN,
  getBankAtWorld,
} from "./physics.js";

const SAFE_MARGIN = JET_RADIUS + 18;
const TARGET_LOOKAHEAD_Y = 120;

const NEUTRAL_INPUTS = Object.freeze({
  left: false,
  right: false,
  accel: false,
  decel: false,
  fire: false,
  mine: false,
});

export const RAID_AI_DIFFICULTIES = Object.freeze({
  easy: Object.freeze({
    interval: 10,
    error: 36,
    deadzone: 14,
    threatY: 150,
    dodgeX: 44,
    fuelAt: 105,
    fuelY: 210,
    fireY: 230,
    fireX: 18,
    fireOdds: 0.42,
    fireCd: 36,
    mineOdds: 0.22,
    mineCd: 160,
    cruise: SPEED_BASE,
  }),
  normal: Object.freeze({
    interval: 5,
    error: 16,
    deadzone: 8,
    threatY: 210,
    dodgeX: 54,
    fuelAt: 135,
    fuelY: 270,
    fireY: 290,
    fireX: 26,
    fireOdds: 0.7,
    fireCd: 24,
    mineOdds: 0.46,
    mineCd: 110,
    cruise: SPEED_BASE + 1,
  }),
  hard: Object.freeze({
    interval: 2,
    error: 5,
    deadzone: 5,
    threatY: 280,
    dodgeX: 66,
    fuelAt: 165,
    fuelY: 340,
    fireY: 360,
    fireX: 34,
    fireOdds: 1,
    fireCd: 16,
    mineOdds: 0.74,
    mineCd: 80,
    cruise: SPEED_MAX,
  }),
});

export { normalizeRaidAIDifficulty };

/**
 * @param {object} [options]
 * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
 * @param {() => number} [options.rng]
 * @param {number} [options.seed]
 * @returns {HexRaidAI}
 */
export function createHexRaidAI(options = {}) {
  return new HexRaidAI(options);
}

export class HexRaidAI {
  /**
   * @param {object} [options]
   * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
   * @param {() => number} [options.rng]
   * @param {number} [options.seed]
   */
  constructor(options = {}) {
    this.difficulty = normalizeRaidAIDifficulty(options.difficulty);
    this.rng =
      typeof options.rng === "function" ? options.rng : createSeededRng(options.seed || 0x72616964);
    this.frame = 0;
    this.fireCooldown = 0;
    this.mineCooldown = 0;
    this._target = null;
  }

  /**
   * @param {"easy"|"normal"|"hard"|string} difficulty
   * @returns {void}
   */
  setDifficulty(difficulty) {
    this.difficulty = normalizeRaidAIDifficulty(difficulty);
  }

  /**
   * @param {object} request
   * @param {object} request.state
   * @param {"easy"|"normal"|"hard"|string} [request.difficulty]
   * @param {1|2} [request.player]
   * @returns {{left: boolean, right: boolean, accel: boolean, decel: boolean, fire: boolean, mine: boolean}}
   */
  nextInputs(request = {}) {
    const state = request.state;
    const player = request.player === 1 ? 1 : 2;

    this.frame++;
    if (this.fireCooldown > 0) this.fireCooldown--;
    if (this.mineCooldown > 0) this.mineCooldown--;

    if (!state || state.phase !== PHASE.FLYING || !jetAlive(state, player)) {
      this._target = null;
      return NEUTRAL_INPUTS;
    }

    const difficulty = normalizeRaidAIDifficulty(request.difficulty || this.difficulty);
    if (difficulty !== this.difficulty) this.setDifficulty(difficulty);
    const config = RAID_AI_DIFFICULTIES[difficulty];

    if (this.frame % config.interval === 0 || !this._target) {
      const target = chooseRaidTarget(state, player, config);
      this._target = applyTargetError(target, config.error, this.rng);
    }

    const movement = movementInputs(state, player, this._target, config.deadzone);
    const fire = this._firePressed(state, player, config);
    const mine = this._minePressed(state, player, config);

    return { ...movement, fire, mine };
  }

  /**
   * @param {object} state
   * @param {1|2} player
   * @param {object} config
   * @returns {boolean}
   */
  _firePressed(state, player, config) {
    if (this.fireCooldown > 0) return false;
    if (!shouldFire(state, player, config)) return false;
    if (this.rng() > config.fireOdds) return false;

    this.fireCooldown = config.fireCd;
    return true;
  }

  /**
   * @param {object} state
   * @param {1|2} player
   * @param {object} config
   * @returns {boolean}
   */
  _minePressed(state, player, config) {
    if (this.mineCooldown > 0) return false;
    if (!shouldDeployMine(state, player, config)) return false;
    if (this.rng() > config.mineOdds) return false;

    this.mineCooldown = config.mineCd;
    return true;
  }
}

/**
 * @param {object} state
 * @param {1|2} player
 * @param {object} config
 * @returns {{x: number, targetSpeed: number, kind: string}}
 */
export function chooseRaidTarget(state, player = 2, config = RAID_AI_DIFFICULTIES.normal) {
  const actor = jetState(state, player);
  if (!actor) return { x: CANVAS_W / 2, targetSpeed: SPEED_MIN };

  const threat = nearestThreat(state, player, config);
  if (threat) {
    return dodgeTarget(state, actor, threat, config);
  }

  const fuel = nearestFuelTarget(state, player, config);
  if (fuel) {
    return {
      x: clampToSafeRiver(state, fuel.x, fuel.y),
      targetSpeed: fuel.y > actor.y - 80 ? SPEED_MIN : SPEED_BASE,
    };
  }

  const bridge = bridgeTarget(state, player);
  if (bridge) return bridge;

  const attack = attackTarget(state, player, config);
  if (attack) return attack;

  return {
    x: riverCenterAt(state, Math.max(0, actor.y - TARGET_LOOKAHEAD_Y)),
    targetSpeed: config.cruise,
  };
}

/**
 * @param {object} state
 * @param {1|2} player
 * @param {{x: number, targetSpeed?: number}|null} target
 * @param {number} deadzone
 * @returns {{left: boolean, right: boolean, accel: boolean, decel: boolean, fire: boolean, mine: boolean}}
 */
export function movementInputs(state, player, target, deadzone) {
  const actor = jetState(state, player);
  if (!actor || !target) return NEUTRAL_INPUTS;

  const dx = target.x - actor.x;
  const targetSpeed = clamp(target.targetSpeed ?? SPEED_BASE, SPEED_MIN, SPEED_MAX);

  return {
    left: dx < -deadzone,
    right: dx > deadzone,
    accel: actor.speed < targetSpeed,
    decel: actor.speed > targetSpeed,
    fire: false,
    mine: false,
  };
}

/**
 * @param {object} state
 * @param {1|2} player
 * @param {object} config
 * @returns {{x: number, y: number, kind: string}|null}
 */
export function nearestFuelTarget(state, player = 2, config = RAID_AI_DIFFICULTIES.normal) {
  const actor = jetState(state, player);
  if (!actor || actor.fuel > config.fuelAt) return null;

  const fuels = Array.isArray(state.fuels) ? state.fuels : [];
  let best = null;
  let bestScore = Infinity;

  for (const fuel of fuels) {
    if (!fuel.available) continue;
    if (fuel.y > actor.y + 20) continue;

    const dy = actor.y - fuel.y;
    if (dy < 0 || dy > config.fuelY) continue;

    const score = dy + Math.abs(actor.x - fuel.x) * 0.55;
    if (score < bestScore) {
      best = fuel;
      bestScore = score;
    }
  }

  return best;
}

/**
 * @param {object} state
 * @param {1|2} player
 * @param {object} config
 * @returns {boolean}
 */
export function shouldFire(state, player = 2, config = RAID_AI_DIFFICULTIES.normal) {
  const actor = jetState(state, player);
  if (!actor || !actor.alive) return false;
  if (missileActive(state, player) || missileCooldown(state, player) > 0) return false;

  if (state.bridgeActive && state.bridgeY < actor.y && actor.y - state.bridgeY < config.fireY) {
    return true;
  }

  const enemies = Array.isArray(state.enemies) ? state.enemies : [];
  return enemies.some((enemy) => {
    if (!enemy.alive) return false;
    const dy = actor.y - enemy.y;
    return dy > 0 && dy < config.fireY && Math.abs(actor.x - enemy.x) <= config.fireX;
  });
}

/**
 * @param {object} state
 * @param {1|2} player
 * @param {object} config
 * @returns {boolean}
 */
export function shouldDeployMine(state, player = 2, config = RAID_AI_DIFFICULTIES.normal) {
  if (state.mode === GAME_MODE.PACIFIST) return false;

  const actor = jetState(state, player);
  const opponent = jetState(state, player === 1 ? 2 : 1);
  if (!actor || !opponent || !actor.alive || !opponent.alive) return false;
  if (mineCooldown(state, player) > 0) return false;

  let ownedMines = 0;
  const mines = Array.isArray(state.mines) ? state.mines : [];
  for (const mine of mines) {
    if (mine.active && mine.owner === player) ownedMines++;
  }
  if (ownedMines >= MAX_MINES_PER_PLAYER) return false;

  const closeLane = Math.abs(actor.x - opponent.x) < config.dodgeX;
  const opponentCanHitMine = opponent.y >= actor.y - 30 && opponent.y <= actor.y + 70;
  return closeLane && opponentCanHitMine;
}

/**
 * @param {object} state
 * @param {1|2} player
 * @param {object} config
 * @returns {{x: number, y: number, kind: string}|null}
 */
export function nearestThreat(state, player = 2, config = RAID_AI_DIFFICULTIES.normal) {
  const actor = jetState(state, player);
  if (!actor) return null;

  let best = null;
  let bestDistance = Infinity;
  const enemies = Array.isArray(state.enemies) ? state.enemies : [];
  const mines = Array.isArray(state.mines) ? state.mines : [];

  for (const enemy of enemies) {
    if (!enemy.alive) continue;
    const dy = actor.y - enemy.y;
    if (dy < -15 || dy > config.threatY) continue;
    if (Math.abs(actor.x - enemy.x) <= config.dodgeX) {
      const distance = Math.max(1, dy);
      if (distance < bestDistance) {
        best = enemy;
        bestDistance = distance;
      }
    }
  }

  for (const mine of mines) {
    if (!mine.active || mine.owner === player) continue;
    const dy = actor.y - mine.y;
    if (dy < -25 || dy > Math.min(config.threatY, 120)) continue;
    if (Math.abs(actor.x - mine.x) <= config.dodgeX + 10) {
      const distance = Math.max(1, dy) * 0.5;
      if (distance < bestDistance) {
        best = mine;
        bestDistance = distance;
      }
    }
  }

  if (state.bridgeActive && state.bridgeY < actor.y && actor.y - state.bridgeY < 95) {
    best = { x: CANVAS_W / 2, y: state.bridgeY, bridge: true };
  }

  return best;
}

/**
 * @param {object} state
 * @param {{x: number, y: number}} actor
 * @param {{x: number, y: number}} threat
 * @param {object} config
 * @returns {{x: number, targetSpeed: number, kind: string}}
 */
export function dodgeTarget(state, actor, threat, config = RAID_AI_DIFFICULTIES.normal) {
  const bank = safeBankAt(state, actor.y);
  const center = (bank.leftX + bank.rightX) / 2;
  const leftLane = bank.leftX + SAFE_MARGIN;
  const rightLane = bank.rightX - SAFE_MARGIN;
  const targetX = threat.x <= center ? rightLane : leftLane;

  return {
    x: clamp(targetX, leftLane, rightLane),
    targetSpeed: threat.bridge === true ? SPEED_MIN : Math.min(SPEED_BASE, config.cruise),
  };
}

function attackTarget(state, player, config) {
  const actor = jetState(state, player);
  const enemies = Array.isArray(state.enemies) ? state.enemies : [];
  let best = null;
  let bestScore = Infinity;

  for (const enemy of enemies) {
    if (!enemy.alive) continue;
    const dy = actor.y - enemy.y;
    if (dy <= 0 || dy > config.fireY) continue;

    const score = dy + Math.abs(actor.x - enemy.x) * 0.4;
    if (score < bestScore) {
      best = enemy;
      bestScore = score;
    }
  }

  if (!best) return null;
  return {
    x: clampToSafeRiver(state, best.x, best.y),
    targetSpeed: best.y > actor.y - 90 ? SPEED_MIN : config.cruise,
  };
}

function bridgeTarget(state, player) {
  const actor = jetState(state, player);
  if (!state.bridgeActive || !actor) return null;
  if (state.bridgeY > actor.y || actor.y - state.bridgeY > 240) return null;

  return {
    x: riverCenterAt(state, state.bridgeY),
    targetSpeed: state.bridgeY > actor.y - 120 ? SPEED_MIN : SPEED_BASE,
  };
}

function applyTargetError(target, errorPx, rng) {
  if (!target || errorPx <= 0) return target;
  return { ...target, x: target.x + (rng() - 0.5) * errorPx * 2 };
}

function jetState(state, player) {
  const prefix = player === 1 ? "jet1" : "jet2";
  return {
    x: state[`${prefix}X`],
    y: state[`${prefix}Y`],
    speed: state[`${prefix}Speed`],
    fuel: state[`${prefix}Fuel`],
    alive: state[`${prefix}Alive`],
  };
}

function jetAlive(state, player) {
  return player === 1 ? state.jet1Alive === true : state.jet2Alive === true;
}

function missileActive(state, player) {
  return player === 1 ? state.m1Active === true : state.m2Active === true;
}

function missileCooldown(state, player) {
  return player === 1 ? state.jet1MissileCooldown || 0 : state.jet2MissileCooldown || 0;
}

function mineCooldown(state, player) {
  return player === 1 ? state.jet1MineCooldown || 0 : state.jet2MineCooldown || 0;
}

function safeBankAt(state, screenY) {
  const worldY = (state.scrollY || 0) + (CANVAS_H - screenY);
  return getBankAtWorld(worldY, state.seed || 0, state.mode);
}

function riverCenterAt(state, screenY) {
  const bank = safeBankAt(state, screenY);
  return (bank.leftX + bank.rightX) / 2;
}

function clampToSafeRiver(state, x, screenY) {
  const bank = safeBankAt(state, screenY);
  return clamp(x, bank.leftX + SAFE_MARGIN, bank.rightX - SAFE_MARGIN);
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

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}
