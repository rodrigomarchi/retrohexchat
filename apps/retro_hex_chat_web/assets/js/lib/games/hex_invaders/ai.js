/**
 * Deterministic opponent controller for Hex Invaders solo sessions.
 * The controller consumes plain game state and emits the same held-input shape
 * used by the P2P peer path.
 * @module games/hex_invaders_ai
 */

import { ALIEN_TYPE, GAME_MODE, PHASE } from "./protocol.js";
import {
  ALIEN_H,
  ALIEN_W,
  CANVAS_W,
  CANNON_W,
  CANNON_Y_OFFSET,
  DIVIDER_X,
  HALF_W,
} from "./physics.js";
import {
  TableAI,
  clamp,
  createCommitment,
  createPerThing,
  normalizeDifficulty,
  randomUnit,
} from "../core/ai.js";

const UFO_W = 24;
const NEUTRAL_INPUTS = Object.freeze({
  left: false,
  right: false,
  fire: false,
});

// `noticeChance` is drawn once per bomb: a bomb the AI does not notice stays
// unnoticed until it lands. It only sees bombs below `bombDangerY` and within
// `bombDangerX` of its cannon (a bomb hits within 16 px). `fireChance` is
// drawn once per chance to shoot — a target lined up with the missile ready —
// and a declined chance waits until the cannon comes into line again or takes
// another target; `fireCooldownFrames`
// holds the next shot past the missile's flight, which sets how fast it
// clears its aliens and sends reinforcements across.
export const INVADERS_AI_DIFFICULTIES = Object.freeze({
  easy: Object.freeze({
    decisionInterval: 12,
    aimTolerancePx: 10,
    targetErrorPx: 22,
    targetDeadzonePx: 8,
    fireCooldownFrames: 110,
    fireChance: 0.6,
    noticeChance: 0.2,
    bombDangerY: 380,
    bombDangerX: 20,
    dodgeDistancePx: 36,
    ufoPriority: false,
  }),
  normal: Object.freeze({
    decisionInterval: 6,
    aimTolerancePx: 8,
    targetErrorPx: 12,
    targetDeadzonePx: 6,
    fireCooldownFrames: 70,
    fireChance: 0.8,
    noticeChance: 0.5,
    bombDangerY: 350,
    bombDangerX: 22,
    dodgeDistancePx: 44,
    ufoPriority: true,
  }),
  hard: Object.freeze({
    decisionInterval: 2,
    aimTolerancePx: 6,
    targetErrorPx: 4,
    targetDeadzonePx: 4,
    fireCooldownFrames: 60,
    fireChance: 1,
    noticeChance: 0.65,
    bombDangerY: 320,
    bombDangerX: 28,
    dodgeDistancePx: 52,
    ufoPriority: true,
  }),
});

// In co-op the AI is the player's partner, not their opponent. The difficulty
// the player picks is how hard the game should be for them, so an easy game
// gets the strongest partner and a hard game the weakest.
const COOP_PARTNER = Object.freeze({ easy: "hard", normal: "normal", hard: "easy" });

/**
 * The row of the table the AI plays by: the chosen difficulty against the
 * player, its mirror beside them in co-op.
 * @param {"easy"|"normal"|"hard"} difficulty
 * @param {number} mode - GAME_MODE
 * @returns {"easy"|"normal"|"hard"}
 */
export function invadersAILevel(difficulty, mode) {
  return mode === GAME_MODE.COOP ? COOP_PARTNER[difficulty] : difficulty;
}

/**
 * @param {unknown} difficulty
 * @returns {"easy"|"normal"|"hard"}
 */
export function normalizeInvadersAIDifficulty(difficulty) {
  return normalizeDifficulty(difficulty, INVADERS_AI_DIFFICULTIES);
}

/**
 * @param {object} [options]
 * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
 * @param {() => number} [options.rng]
 * @returns {HexInvadersAI}
 */
export function createHexInvadersAI(options = {}) {
  return new HexInvadersAI(options);
}

export class HexInvadersAI extends TableAI {
  /**
   * @param {object} [options]
   * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
   * @param {() => number} [options.rng]
   */
  constructor(options = {}) {
    super(options, normalizeInvadersAIDifficulty, INVADERS_AI_DIFFICULTIES);
    this.fireCooldown = 0;
    this._target = null;
    this.noticed = createPerThing();
    this.willFire = createCommitment();
    this._lined = false;
    this._chance = 0;
  }

  /**
   * A new wave or match: no target held, no shot decided on, no bomb
   * noticed, the trigger ready.
   * @returns {void}
   */
  forget() {
    this._target = null;
    this.willFire.reset();
    this.noticed.reset();
    this.fireCooldown = 0;
    this._lined = false;
  }

  /**
   * @param {object} request
   * @param {object} request.state
   * @param {"easy"|"normal"|"hard"|string} [request.difficulty]
   * @param {1|2} [request.player]
   * @returns {{left: boolean, right: boolean, fire: boolean}}
   */
  // ex_dna:disable-for-lines:6 this AI's own turn: its cooldowns and the phase it plays in
  nextInputs(request = {}) {
    const { state, player } = this.startTurn(request);
    if (this.fireCooldown > 0) this.fireCooldown--;

    if (!state || state.phase !== PHASE.PLAYING) return NEUTRAL_INPUTS;

    const difficulty = this.difficultyFor(request);
    const config = INVADERS_AI_DIFFICULTIES[invadersAILevel(difficulty, state.mode)];

    const bombs = Array.isArray(state.bombs) ? state.bombs : [];
    this.noticed.keep(bombs.map(bombId));
    const noticed = (bomb) =>
      this.noticed.decide(bombId(bomb), () => randomUnit(this.rng) < config.noticeChance);
    const threat = incomingBombThreat(state, player, config, noticed);
    if (threat) {
      const target = dodgeTarget(state, player, threat, config);
      return {
        ...movementInputs(state, player, target.x, config.targetDeadzonePx),
        fire: false,
      };
    }

    if (
      this.frame % config.decisionInterval === 0 ||
      !isTargetStillValid(state, player, this._target)
    ) {
      this._target = chooseInvaderTarget(state, player, config, this.rng);
    }

    if (!this._target) return NEUTRAL_INPUTS;

    const movement = movementInputs(state, player, this._target.x, config.targetDeadzonePx);
    // A chance to shoot opens when the cannon comes into line with its target,
    // the missile ready; it stays the same chance while the line holds.
    const lined = canFire(state, player, this._target, config, this.fireCooldown);
    if (lined && !this._lined) this._chance++;
    this._lined = lined;
    const fire =
      lined &&
      this.willFire.hold(`${targetId(this._target)}:${this._chance}`, () => {
        return randomUnit(this.rng) < config.fireChance;
      });
    if (fire) {
      this.fireCooldown = config.fireCooldownFrames;
      this.willFire.reset();
    }

    return {
      ...movement,
      fire,
    };
  }
}

/**
 * @param {object} state
 * @param {1|2} [player]
 * @param {object} [config]
 * @param {() => number} [rng]
 * @returns {{kind: "alien"|"ufo", x: number, y: number, index?: number}|null}
 */
export function chooseInvaderTarget(
  state,
  player = 2,
  config = INVADERS_AI_DIFFICULTIES.normal,
  rng = Math.random,
) {
  if (!state) return null;

  const bounds = cannonBounds(state, player);
  const ufoX = (state.ufoX || 0) + UFO_W / 2;
  if (
    config.ufoPriority &&
    state.ufoActive &&
    ufoX >= bounds.min - CANNON_W &&
    ufoX <= bounds.max + CANNON_W
  ) {
    return {
      kind: "ufo",
      x: clamp(ufoX + errorOffset(config.targetErrorPx, rng), bounds.min, bounds.max),
      y: 18,
    };
  }

  const aliens = aliensForPlayer(state, player);
  const actorX = cannonX(state, player);
  let best = null;
  let bestScore = -Infinity;

  for (let index = 0; index < aliens.length; index++) {
    const alien = aliens[index];
    if (!alien || alien.type === ALIEN_TYPE.NONE) continue;

    const x = alien.x + ALIEN_W / 2;
    const y = alien.y + ALIEN_H / 2;
    const typeBonus =
      alien.type === ALIEN_TYPE.ARMORED ? 14 : alien.type === ALIEN_TYPE.TOP ? 8 : 0;
    const score = y * 1.8 - Math.abs(x - actorX) + typeBonus;

    if (score > bestScore) {
      bestScore = score;
      best = { kind: "alien", index, x, y };
    }
  }

  if (!best) return null;

  return {
    ...best,
    x: clamp(best.x + errorOffset(config.targetErrorPx, rng), bounds.min, bounds.max),
  };
}

/**
 * The lowest bomb close enough to hit the cannon, among those the AI noticed.
 * @param {object} state
 * @param {1|2} [player]
 * @param {object} [config]
 * @param {(bomb: object) => boolean} [noticed] - every bomb, unless told
 * @returns {{side: number, x: number, y: number}|null}
 */
export function incomingBombThreat(
  state,
  player = 2,
  config = INVADERS_AI_DIFFICULTIES.normal,
  noticed = () => true,
) {
  if (!state || !Array.isArray(state.bombs)) return null;

  const actorX = cannonX(state, player);
  const relevant = state.bombs
    .filter((bomb) => bombThreatensPlayer(state, player, bomb))
    .filter(
      (bomb) =>
        bomb.y >= config.bombDangerY &&
        bomb.y <= CANNON_Y_OFFSET + CANNON_W &&
        Math.abs(bomb.x - actorX) <= config.bombDangerX &&
        noticed(bomb),
    )
    .sort((a, b) => b.y - a.y);

  return relevant[0] || null;
}

/**
 * @param {object} state
 * @param {1|2} player
 * @param {number} targetX
 * @param {number} [deadzonePx]
 * @returns {{left: boolean, right: boolean}}
 */
export function movementInputs(state, player, targetX, deadzonePx = 4) {
  const actorX = cannonX(state, player);

  return {
    left: targetX < actorX - deadzonePx,
    right: targetX > actorX + deadzonePx,
  };
}

/**
 * @param {object} state
 * @param {1|2} player
 * @returns {number}
 */
function cannonX(state, player) {
  return player === 1 ? state.cannon1X : state.cannon2X;
}

/**
 * @param {object} state
 * @param {1|2} player
 * @returns {Array<object>}
 */
function aliensForPlayer(state, player) {
  if (state.mode === GAME_MODE.COOP) return state.aliens1 || [];
  return player === 1 ? state.aliens1 || [] : state.aliens2 || [];
}

/**
 * @param {object} state
 * @param {1|2} player
 * @returns {{min: number, max: number}}
 */
function cannonBounds(state, player) {
  const halfCannon = CANNON_W / 2;

  if (state.mode === GAME_MODE.COOP) {
    return { min: halfCannon, max: CANVAS_W - halfCannon };
  }

  if (player === 1) {
    return { min: halfCannon, max: HALF_W - halfCannon };
  }

  return { min: DIVIDER_X + halfCannon, max: CANVAS_W - halfCannon };
}

/**
 * @param {object} state
 * @param {1|2} player
 * @param {object|null} target
 * @returns {boolean}
 */
function isTargetStillValid(state, player, target) {
  if (!target) return false;
  if (target.kind === "ufo") return state.ufoActive === true;
  if (target.kind !== "alien" || !Number.isInteger(target.index)) return false;

  const alien = aliensForPlayer(state, player)[target.index];
  return !!alien && alien.type !== ALIEN_TYPE.NONE;
}

/**
 * Whether the cannon has a shot: the missile ready and the target lined up.
 * @param {object} state
 * @param {1|2} player
 * @param {object} target
 * @param {object} config
 * @param {number} cooldown
 * @returns {boolean}
 */
function canFire(state, player, target, config, cooldown) {
  if (cooldown > 0) return false;
  if (player === 1 ? state.m1Active : state.m2Active) return false;

  return Math.abs(cannonX(state, player) - target.x) <= config.aimTolerancePx;
}

/**
 * What a target is, the same for as long as it stays the target: the UFO,
 * or an alien by its place in its formation — re-aimed at with a fresh
 * error each look, but the same chance to shoot.
 * @param {{kind: string, index?: number}} target
 * @returns {string}
 */
function targetId(target) {
  return target.kind === "alien" ? `alien:${target.index}` : target.kind;
}

/**
 * A bomb's number, or — for one without — its side and column, which stay
 * the same while it falls.
 * @param {{id?: number, side: number, x: number}} bomb
 * @returns {number|string}
 */
function bombId(bomb) {
  return bomb.id ?? `${bomb.side}:${bomb.x}`;
}

/**
 * @param {object} state
 * @param {1|2} player
 * @param {{side: number, x: number, y: number}} bomb
 * @returns {boolean}
 */
function bombThreatensPlayer(state, player, bomb) {
  return state.mode === GAME_MODE.COOP || bomb.side === player;
}

/**
 * @param {object} state
 * @param {1|2} player
 * @param {{x: number}} threat
 * @param {object} config
 * @returns {{kind: "dodge", x: number}}
 */
function dodgeTarget(state, player, threat, config) {
  const actorX = cannonX(state, player);
  const bounds = cannonBounds(state, player);
  const preferredDirection = threat.x <= actorX ? 1 : -1;
  const preferredX = actorX + preferredDirection * config.dodgeDistancePx;
  const fallbackX = actorX - preferredDirection * config.dodgeDistancePx;
  const targetX = preferredX >= bounds.min && preferredX <= bounds.max ? preferredX : fallbackX;

  return {
    kind: "dodge",
    x: clamp(targetX, bounds.min, bounds.max),
  };
}

/**
 * @param {number} maxPx
 * @param {() => number} rng
 * @returns {number}
 */
function errorOffset(maxPx, rng) {
  if (!Number.isFinite(maxPx) || maxPx <= 0) return 0;
  return (rng() * 2 - 1) * maxPx;
}
