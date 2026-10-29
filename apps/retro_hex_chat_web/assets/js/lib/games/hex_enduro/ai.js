/**
 * Deterministic opponent controller for Hex Enduro solo sessions.
 * It emits the same held-input shape used by the P2P peer path, keeping the
 * host simulation shared between solo and network play.
 * @module games/hex_enduro_ai
 */

import { normalizeEnduroAIDifficulty } from "./difficulty.js";
import { GAME_MODE, PHASE, WEATHER } from "./protocol.js";
import { LANE_COUNT, MAX_Z, SPEED_MAX, TURBO_FUEL_COST } from "./physics.js";
import { TableAI, createCommitment, createDelayedView } from "../core/ai.js";

const COLLISION_ZONE_Z = 40;
const PLAYER_COLLISION_BUFFER_Z = 135;
const CRUISE_LANE = 1;
// The renderer hides cars and fuel stations past this share of the road in fog.
const FOG_VISIBLE_Z = MAX_Z * 0.4;

const NEUTRAL_INPUTS = Object.freeze({
  left: false,
  right: false,
  accel: false,
  brake: false,
  turbo: false,
});

// interval: frames between looks at the road; reaction: how many frames old the road it
// looks at is; laneMistake: the odds it drives the lane beside each lane it picks.
export const ENDURO_AI_DIFFICULTIES = Object.freeze({
  easy: Object.freeze({
    interval: 10,
    reaction: 16,
    laneMistake: 0.7,
    threatZ: 330,
    fuelAt: 300,
    fuelZ: 900,
    targetSpeed: 690,
    brakeSpeed: 400,
    turboOdds: 0.3,
    turboCd: 480,
    slipstreamBias: 0.3,
  }),
  normal: Object.freeze({
    interval: 7,
    reaction: 14,
    laneMistake: 0.6,
    threatZ: 360,
    fuelAt: 380,
    fuelZ: 1150,
    targetSpeed: 770,
    brakeSpeed: 430,
    turboOdds: 0.5,
    turboCd: 360,
    slipstreamBias: 0.45,
  }),
  hard: Object.freeze({
    interval: 5,
    reaction: 10,
    laneMistake: 0.4,
    threatZ: 420,
    fuelAt: 450,
    fuelZ: 1400,
    targetSpeed: 800,
    brakeSpeed: 480,
    turboOdds: 0.8,
    turboCd: 280,
    slipstreamBias: 0.6,
  }),
});

// A small edge decides nearly every ten-minute duel and few ninety-second sprints:
// the AI reacts later and slips more in the duel, and sooner in the sprint, so
// each difficulty wins about as often in every race.
const MODE_TUNING = Object.freeze({
  [GAME_MODE.CLASSIC_DUEL]: {
    easy: { reaction: 18, laneMistake: 0.8, threatZ: 300, targetSpeed: 655 },
    normal: { reaction: 16, laneMistake: 0.65, targetSpeed: 740 },
    hard: { reaction: 12, laneMistake: 0.45, threatZ: 390, targetSpeed: 780 },
  },
  [GAME_MODE.SPRINT]: {
    normal: { reaction: 11, laneMistake: 0.5, threatZ: 390 },
    hard: { reaction: 7, laneMistake: 0.3, threatZ: 450 },
  },
});

const TUNED = Object.freeze(
  Object.fromEntries(
    Object.entries(MODE_TUNING).map(([mode, byDifficulty]) => [
      mode,
      Object.fromEntries(
        Object.entries(byDifficulty).map(([difficulty, tuning]) => [
          difficulty,
          Object.freeze({ ...ENDURO_AI_DIFFICULTIES[difficulty], ...tuning }),
        ]),
      ),
    ]),
  ),
);

/**
 * The AI's settings for a difficulty in a race mode.
 * @param {"easy"|"normal"|"hard"} difficulty
 * @param {number} mode - GAME_MODE
 * @returns {object}
 */
export function enduroAIConfig(difficulty, mode) {
  return TUNED[mode]?.[difficulty] ?? ENDURO_AI_DIFFICULTIES[difficulty];
}

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

export class HexEnduroAI extends TableAI {
  /**
   * @param {object} [options]
   * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
   * @param {() => number} [options.rng]
   * @param {number} [options.seed]
   */
  constructor(options = {}) {
    super(options, normalizeEnduroAIDifficulty, ENDURO_AI_DIFFICULTIES, 0x656e6475);
    this.turboCooldown = 0;
    this._target = null;
    this._view = createDelayedView();
    // A wrong lane is drawn once per lane it means to drive, and whether to
    // draft once per time the opponent pulls just ahead.
    this._slip = createCommitment();
    this._draft = createCommitment();
    this._draftChance = 0;
    this._draftOpen = false;
  }

  /**
   * @param {object} request
   * @param {object} request.state
   * @param {"easy"|"normal"|"hard"|string} [request.difficulty]
   * @param {1|2} [request.player]
   * @returns {{left: boolean, right: boolean, accel: boolean, brake: boolean, turbo: boolean}}
   */
  nextInputs(request = {}) {
    const { state, player } = this.startTurn(request);
    if (this.turboCooldown > 0) this.turboCooldown--;

    if (!state || state.phase !== PHASE.RACING) {
      this.forget();
      return NEUTRAL_INPUTS;
    }

    const actor = playerState(state, player);
    if (!actor) return NEUTRAL_INPUTS;

    const difficulty = this.difficultyFor(request);
    const config = enduroAIConfig(difficulty, state.mode);
    // It plans from the road as it was `reaction` frames ago and drives the car it has now.
    const seen = this._view.see(state, config.reaction);

    if (this.frame % config.interval === 0 || !this._target) {
      this._target = this._choose(seen, player, config);
    }

    const movement = movementInputs(state, player, this._target);
    const turbo = this._turboPressed(seen, player, this._target, config);
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

    // Each chance is one draw; taken or not, the next waits out the cooldown.
    this.turboCooldown = config.turboCd;
    return this.rng() <= config.turboOdds;
  }

  /**
   * The lane and speed to drive, from the road it sees.
   * @param {object} seen
   * @param {1|2} player
   * @param {object} config
   * @returns {{lane: number, targetSpeed: number, reason: string}}
   */
  _choose(seen, player, config) {
    const open = draftChance(playerState(seen, player), playerState(seen, player === 1 ? 2 : 1));
    if (open && !this._draftOpen) this._draftChance++;
    this._draftOpen = open;

    const target = chooseEnduroTarget(seen, player, config, () =>
      this._draft.hold(this._draftChance, this.rng),
    );
    const slip = this._slip.hold(
      `${target.reason}:${target.lane}`,
      () => maybeApplyLaneMistake(target, seen, player, config, this.rng).lane - target.lane,
    );
    return { ...target, lane: target.lane + slip };
  }

  /** Drop what it remembers of the race before. */
  forget() {
    this._target = null;
    this._view.reset();
    this._slip.reset();
    this._draft.reset();
    this._draftOpen = false;
    this.turboCooldown = 0;
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
  const threatZ = Math.min(config.threatZ, visibleZ(state));
  for (const car of cars) {
    if (car.lane !== lane) continue;
    if (car.zPos < -COLLISION_ZONE_Z || car.zPos > threatZ) continue;

    if (Math.abs(car.zPos) < COLLISION_ZONE_Z) {
      risk += 30;
    } else {
      risk += 9 * (1 - car.zPos / threatZ);
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
  const reach = Math.min(config.fuelZ, visibleZ(state));
  let best = null;
  let bestScore = Infinity;

  for (const station of stations) {
    if (station.zPos < -20 || station.zPos > reach) continue;
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

/**
 * Whether the opponent is just far enough ahead to draft behind.
 * @param {object} actor
 * @param {object} [opponent]
 * @returns {boolean}
 */
export function draftChance(actor, opponent) {
  if (!actor || !opponent) return false;
  const gap = opponent.zOffset - actor.zOffset;
  return gap > 45 && gap < 260;
}

function slipstreamLane(actor, opponent, config, rng) {
  if (!draftChance(actor, opponent)) return null;
  if (rng() > config.slipstreamBias) return null;

  return opponent.lane;
}

/**
 * The lane beside the one picked, `config.laneMistake` of the time.
 * @param {{lane: number}} target
 * @param {object} state
 * @param {1|2} player
 * @param {{laneMistake: number}} config
 * @param {() => number} rng
 * @returns {{lane: number}}
 */
export function maybeApplyLaneMistake(target, state, player, config, rng) {
  if (rng() >= config.laneMistake) return target;

  const actor = playerState(state, player);
  if (!actor) return target;

  const drift = rng() < 0.5 ? -1 : 1;
  const lane = clampLane(target.lane + drift);
  return { ...target, lane };
}

/** How far up the road the player can see: the whole road, or what the fog leaves. */
function visibleZ(state) {
  return state.weather === WEATHER.FOG ? FOG_VISIBLE_Z : MAX_Z;
}

function playerState(state, player) {
  return player === 1 ? state?.p1 : state?.p2;
}

function clampLane(lane) {
  return Math.max(0, Math.min(LANE_COUNT - 1, lane));
}
