/**
 * Deterministic opponent controller for Hex Outlaw solo sessions.
 * The controller consumes plain game state and emits the same held-input shape
 * used by the P2P peer path.
 * @module games/hex_outlaw_ai
 */

import { GAME_MODE, PHASE } from "./protocol.js";
import {
  ARENA_BOTTOM,
  ARENA_TOP,
  BULLET_RADIUS,
  BULLET_SPEED_X,
  GUNSLINGER_H,
  GUNSLINGER_HIT_H,
  GUNSLINGER_HIT_W,
  GUNSLINGER_SPEED,
  NML_P1_MAX_X,
  NML_P2_MIN_X,
  RICOCHET_ANGLE,
  bulletHitsGunslinger,
  bulletHitsRect,
  bulletLeftArena,
  getObstacleRect,
  ricochet,
} from "./physics.js";
import { TableAI, clamp, createPerThing, normalizeDifficulty, randomUnit } from "../core/ai.js";

const NEUTRAL_INPUTS = Object.freeze({
  up: false,
  down: false,
  left: false,
  right: false,
  fire: false,
});
const PLAYER_PREFIX = Object.freeze({
  1: "p1",
  2: "p2",
});
const BULLET_PREFIX = Object.freeze({
  1: "b1",
  2: "b2",
});
const INPUT_TARGET_DEADZONE = 2;
// Ricochet: the heights a bank shot is looked for at, how close to the middle
// of a band of hitting heights is close enough, and how often the bands are
// looked for again.
const BANK_SCAN_STEP_PX = 2;
const BANK_SETTLE_PX = 3;
const BANK_PLAN_FRAMES = 6;

// dodgeChance: the odds a bullet is dodged at all, decided once per bullet,
// and only once the bullet is reactionFrames old. fireChance: the odds an
// opening is taken; a passed one waits out the cooldown. fireWindowPx stays
// inside the 13 px a bullet hits within, on every difficulty.
export const OUTLAW_AI_DIFFICULTIES = Object.freeze({
  easy: Object.freeze({
    dodgeTriggerPx: 18,
    threatFrames: 26,
    dodgeChance: 0.35,
    reactionFrames: 37,
    fireWindowPx: 9,
    fireCooldownFrames: 72,
    fireChance: 0.9,
    targetDeadzonePx: 8,
    preferredNmlOffset: 54,
  }),
  normal: Object.freeze({
    dodgeTriggerPx: 26,
    threatFrames: 40,
    dodgeChance: 0.38,
    reactionFrames: 36,
    fireWindowPx: 9,
    fireCooldownFrames: 70,
    fireChance: 0.9,
    targetDeadzonePx: 8,
    preferredNmlOffset: 54,
  }),
  hard: Object.freeze({
    dodgeTriggerPx: 34,
    threatFrames: 58,
    dodgeChance: 0.45,
    reactionFrames: 35,
    fireWindowPx: 9,
    fireCooldownFrames: 62,
    fireChance: 0.9,
    targetDeadzonePx: 8,
    preferredNmlOffset: 54,
  }),
});

// The street changes how much a dodge or a quicker draw is worth: around the
// moving stagecoach and across No Man's Land the same odds play differently,
// so those modes carry their own.
const MODE_DIFFICULTIES = Object.freeze({
  [GAME_MODE.STAGECOACH]: Object.freeze({
    easy: Object.freeze({ dodgeChance: 0.38, fireCooldownFrames: 69 }),
    normal: Object.freeze({ dodgeChance: 0.44, fireCooldownFrames: 62 }),
    hard: Object.freeze({ dodgeChance: 0.55, fireCooldownFrames: 50 }),
  }),
  [GAME_MODE.NO_MANS_LAND]: Object.freeze({
    easy: Object.freeze({ dodgeChance: 0.3, fireCooldownFrames: 67 }),
    normal: Object.freeze({ dodgeChance: 0.42, fireCooldownFrames: 65 }),
    hard: Object.freeze({ dodgeChance: 0.47, fireCooldownFrames: 59 }),
  }),
});

/**
 * The AI's settings for a difficulty on a street: the difficulty's own,
 * with the street's where it has some.
 * @param {"easy"|"normal"|"hard"} difficulty
 * @param {number} [gameMode]
 * @returns {object}
 */
export function outlawAIConfig(difficulty, gameMode) {
  return { ...OUTLAW_AI_DIFFICULTIES[difficulty], ...MODE_DIFFICULTIES[gameMode]?.[difficulty] };
}

/**
 * @param {unknown} difficulty
 * @returns {"easy"|"normal"|"hard"}
 */
export function normalizeOutlawAIDifficulty(difficulty) {
  return normalizeDifficulty(difficulty, OUTLAW_AI_DIFFICULTIES);
}

/**
 * Predict where the opponent's active bullet will cross the requested player.
 * Returns null when the bullet is inactive, moving away, blocked, or too far
 * in the future for the requested horizon.
 * @param {object} state
 * @param {1|2} [player]
 * @param {object} [options]
 * @param {number} [options.maxFrames]
 * @returns {number|null}
 */
export function predictIncomingBulletY(state, player = 2, options = {}) {
  if (!state) return null;

  const actor = playerState(state, player);
  const incomingBulletPlayer = player === 1 ? 2 : 1;
  const bullet = bulletState(state, incomingBulletPlayer);
  if (!actor || !bullet.active || !Number.isFinite(bullet.vx) || bullet.vx === 0) return null;

  const movingTowardActor = player === 1 ? bullet.vx < 0 : bullet.vx > 0;
  if (!movingTowardActor) return null;

  return simulateBulletCrossing(state, bullet, actor.x, {
    maxFrames: Number.isFinite(options.maxFrames) ? options.maxFrames : 80,
  });
}

/**
 * @param {object} [options]
 * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
 * @param {() => number} [options.rng]
 * @returns {OutlawAI}
 */
export function createOutlawAI(options = {}) {
  return new OutlawAI(options);
}

export class OutlawAI extends TableAI {
  /**
   * @param {object} [options]
   * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
   * @param {() => number} [options.rng]
   */
  constructor(options = {}) {
    super(options, normalizeOutlawAIDifficulty, OUTLAW_AI_DIFFICULTIES);
    this.fireCooldown = 0;
    this._incoming = null;
    this._bullets = createPerThing();
    // The aim this seat holds: the last of up or down it pressed, the way
    // the game keeps it. A new round keeps it too.
    this._aimUp = false;
    this._bankPlan = null;
  }

  /**
   * A new point, round or match: no bullet under watch.
   * @returns {void}
   */
  forget() {
    this._incoming = null;
    this._bullets.reset();
    this._bankPlan = null;
  }

  /**
   * @param {object} request
   * @param {object} request.state
   * @param {"easy"|"normal"|"hard"|string} [request.difficulty]
   * @param {1|2} [request.player]
   * @returns {{up: boolean, down: boolean, left: boolean, right: boolean, fire: boolean}}
   */
  nextInputs(request = {}) {
    const inputs = this._decide(request);
    if (inputs.up) this._aimUp = true;
    if (inputs.down) this._aimUp = false;
    return inputs;
  }

  // ex_dna:disable-for-lines:6 this AI's own turn: its cooldowns and the phase it plays in
  _decide(request) {
    const { state, player } = this.startTurn(request);
    if (this.fireCooldown > 0) this.fireCooldown--;

    if (!state || state.phase !== PHASE.PLAYING) return NEUTRAL_INPUTS;

    const difficulty = this.difficultyFor(request);
    const config = outlawAIConfig(difficulty, state.gameMode);

    const actor = playerState(state, player);
    const opponent = playerState(state, player === 1 ? 2 : 1);
    if (!actor || !opponent) return NEUTRAL_INPUTS;

    const threat = incomingThreat(this._noticedBullet(state, player, config), player, config);
    if (threat) {
      return {
        ...movementAwayFromThreat(state, player, threat.y),
        fire: false,
      };
    }

    if (state.gameMode === GAME_MODE.RICOCHET) return this._bankShot(state, player, config);

    const attack = chooseAttack(state, player, config);
    const movement = movementTowardAttack(state, player, attack, config);
    if (!fireOpening(state, player, attack, config, this.fireCooldown)) {
      return { ...movement, fire: false };
    }
    return { ...movement, fire: this._takesOpening(config) };
  }

  /** One roll per opening; a passed one waits out the cooldown like a shot. */
  _takesOpening(config) {
    this.fireCooldown = config.fireCooldownFrames;
    return randomUnit(this.rng) < config.fireChance;
  }

  /**
   * Ricochet: every shot flies at an angle, up or down as the seat last
   * pressed. Go to the middle of the nearest band of heights a bank shot
   * hits the rival from, arrive there holding the aim the shot needs, and
   * fire standing still.
   */
  _bankShot(state, player, config) {
    const actor = playerState(state, player);
    if (!this._bankPlan || this.frame - this._bankPlan.at >= BANK_PLAN_FRAMES) {
      this._bankPlan = { at: this.frame, shot: nearestBankShot(state, player, actor.y) };
    }
    const { shot } = this._bankPlan;
    if (!shot) return NEUTRAL_INPUTS;

    // A move is also an aim, so the shot's height is reached moving the way
    // the shot is aimed: from below for a shot aimed up, from above for one
    // aimed down. `past` is how far the seat is on that side of the height.
    const aimKey = shot.aimUp ? "up" : "down";
    const otherKey = shot.aimUp ? "down" : "up";
    const past = (actor.y - shot.y) * (shot.aimUp ? 1 : -1);
    let movement = NEUTRAL_INPUTS;
    if (past > BANK_SETTLE_PX) movement = { ...NEUTRAL_INPUTS, [aimKey]: true };
    else if (past < -BANK_SETTLE_PX || this._aimUp !== shot.aimUp) {
      movement = { ...NEUTRAL_INPUTS, [otherKey]: true };
    }

    // The rival moves too, so the plan is only the way there: the shot goes
    // whenever, from where this step leaves the seat, the aim it already
    // holds hits — a step that would turn the aim waits.
    const turnsAim = (movement.up && !this._aimUp) || (movement.down && this._aimUp);
    const step = (movement.down ? GUNSLINGER_SPEED : 0) - (movement.up ? GUNSLINGER_SPEED : 0);
    const nextY = clamp(actor.y + step, minPlayerY(), maxPlayerY());
    const open =
      !turnsAim &&
      this.fireCooldown <= 0 &&
      !bulletState(state, player).active &&
      bankShotHits(state, player, nextY, this._aimUp);
    return { ...movement, fire: open && this._takesOpening(config) };
  }

  /**
   * The state as this AI sees it: the rival's bullet is there only once it
   * is reactionFrames old, and only if this AI is to dodge it — decided once
   * per bullet.
   */
  _noticedBullet(state, player, config) {
    const prefix = BULLET_PREFIX[player === 1 ? 2 : 1];
    if (state[`${prefix}active`] !== true) {
      this._incoming = null;
      this._bullets.keep([]);
      return state;
    }

    if (this._incoming === null) this._incoming = this.frame;
    const bullet = this._incoming;
    this._bullets.keep([bullet]);
    const dodges = this._bullets.decide(bullet, () => randomUnit(this.rng) < config.dodgeChance);
    const seen = dodges && this.frame - bullet >= config.reactionFrames;
    return seen ? state : { ...state, [`${prefix}active`]: false };
  }
}

function incomingThreat(state, player, config) {
  const actor = playerState(state, player);
  const y = predictIncomingBulletY(state, player, { maxFrames: config.threatFrames });
  if (!actor || y === null) return null;

  return Math.abs(y - actor.y) <= config.dodgeTriggerPx ? { y } : null;
}

function chooseAttack(state, player, config) {
  const actor = playerState(state, player);
  const opponent = playerState(state, player === 1 ? 2 : 1);
  const targetY = chooseStraightShotY(state, player, actor, opponent, config);
  // In No Man's Land each side holds a spot a little back from its line.
  const nmlX =
    player === 1
      ? NML_P1_MAX_X - config.preferredNmlOffset
      : NML_P2_MIN_X + config.preferredNmlOffset;
  const targetX = state.gameMode === GAME_MODE.NO_MANS_LAND ? nmlX : actor.x;

  return { targetY, targetX, aimUp: targetY < actor.y };
}

function chooseStraightShotY(state, player, actor, opponent, config) {
  const rect = getObstacleRect(state);
  const desiredY = clamp(opponent.y, minPlayerY(), maxPlayerY());

  if (!rect || !lineBlockedAtY(desiredY, actor.x, opponent.x, rect)) return desiredY;

  const above = clamp(
    rect.y - GUNSLINGER_HIT_H - config.targetDeadzonePx,
    minPlayerY(),
    maxPlayerY(),
  );
  const below = clamp(
    rect.y + rect.h + GUNSLINGER_HIT_H + config.targetDeadzonePx,
    minPlayerY(),
    maxPlayerY(),
  );

  return Math.abs(actor.y - above) <= Math.abs(actor.y - below) ? above : below;
}

function fireOpening(state, player, attack, config, fireCooldown) {
  if (fireCooldown > 0) return false;
  if (bulletState(state, player).active) return false;

  const actor = playerState(state, player);
  const opponent = playerState(state, player === 1 ? 2 : 1);
  if (!actor || !opponent) return false;
  if (Math.abs(actor.y - opponent.y) > config.fireWindowPx) return false;

  const rect = getObstacleRect(state);
  return !rect || !lineBlockedAtY(actor.y, actor.x, opponent.x, rect);
}

function movementTowardAttack(state, player, attack, config) {
  const actor = playerState(state, player);
  if (!actor) return NEUTRAL_INPUTS;

  const vertical = movementTowardY(actor.y, attack.targetY, config.targetDeadzonePx);
  const horizontal =
    state.gameMode === GAME_MODE.NO_MANS_LAND
      ? movementTowardX(actor.x, attack.targetX)
      : { left: false, right: false };

  return {
    up: vertical.up,
    down: vertical.down,
    left: horizontal.left,
    right: horizontal.right,
  };
}

function movementAwayFromThreat(state, player, threatY) {
  const actor = playerState(state, player);
  if (!actor) return { up: false, down: false, left: false, right: false };

  const minY = minPlayerY();
  const maxY = maxPlayerY();
  const roomUp = actor.y - minY;
  const roomDown = maxY - actor.y;
  const moveDown =
    roomUp <= GUNSLINGER_H || (roomDown > GUNSLINGER_H && (threatY < actor.y || roomDown > roomUp));

  // In No Man's Land a dodge also steps back, away from the rival.
  const back = state.gameMode === GAME_MODE.NO_MANS_LAND;
  return {
    up: !moveDown,
    down: moveDown,
    left: back && player === 1,
    right: back && player === 2,
  };
}

function movementTowardY(currentY, targetY, deadzone) {
  const delta = targetY - currentY;
  if (Math.abs(delta) <= Math.max(deadzone, INPUT_TARGET_DEADZONE)) {
    return { up: false, down: false };
  }

  return delta < 0 ? { up: true, down: false } : { up: false, down: true };
}

function movementTowardX(currentX, targetX) {
  const delta = targetX - currentX;
  if (Math.abs(delta) <= INPUT_TARGET_DEADZONE) return { left: false, right: false };
  return delta < 0 ? { left: true, right: false } : { left: false, right: true };
}

/**
 * Whether a bank shot from height `y`, aimed up or down, hits the rival
 * where the rival stands now.
 */
function bankShotHits(state, player, y, aimUp) {
  const actor = playerState(state, player);
  const opponent = playerState(state, player === 1 ? 2 : 1);
  const dirX = player === 1 ? 1 : -1;
  const bullet = {
    x: actor.x + dirX * (GUNSLINGER_HIT_W / 2 + BULLET_RADIUS),
    y,
    vx: BULLET_SPEED_X * Math.cos(RICOCHET_ANGLE) * dirX,
    vy: BULLET_SPEED_X * Math.sin(RICOCHET_ANGLE) * (aimUp ? -1 : 1),
    bounced: false,
  };
  return simulatedShotHits(state, bullet, opponent);
}

/**
 * The bank shot nearest `fromY`: the middle of a band of heights a shot
 * aimed one way hits the rival from, and that aim — null when there is none.
 * @param {object} state
 * @param {1|2} player
 * @param {number} fromY
 * @returns {{ y: number, aimUp: boolean }|null}
 */
export function nearestBankShot(state, player, fromY) {
  let best = null;
  for (const aimUp of [true, false]) {
    let start = null;
    const close = (end) => {
      const y = (start + end) / 2;
      if (!best || Math.abs(y - fromY) < Math.abs(best.y - fromY)) best = { y, aimUp };
      start = null;
    };
    let last = null;
    for (let y = minPlayerY(); y <= maxPlayerY(); y += BANK_SCAN_STEP_PX) {
      if (bankShotHits(state, player, y, aimUp)) {
        if (start === null) start = y;
        last = y;
      } else if (start !== null) {
        close(last);
      }
    }
    if (start !== null) close(last);
  }
  return best;
}

/**
 * A bullet's flight, frame by frame, until `reached` says something (what it
 * says is the answer), the obstacle stops it, it leaves the street, or
 * `maxFrames` pass: `missed` then.
 */
function fly(state, bullet, maxFrames, reached, missed) {
  let x = bullet.x;
  let y = bullet.y;
  let vy = bullet.vy;
  let bounced = bullet.bounced;
  const rect = getObstacleRect(state);

  for (let frame = 0; frame < maxFrames; frame++) {
    x += bullet.vx;
    y += vy;

    ({ y, vy, bounced } = ricochet(y, vy, bounced));

    if (rect && bulletHitsRect(x, y, rect)) return missed;
    const answer = reached(x, y);
    if (answer !== undefined) return answer;
    if (bulletLeftArena(x, y, bounced)) return missed;
  }

  return missed;
}

function simulatedShotHits(state, bullet, opponent) {
  return fly(
    state,
    bullet,
    100,
    (x, y) => (bulletHitsGunslinger(x, y, opponent.x, opponent.y) ? true : undefined),
    false,
  );
}

function simulateBulletCrossing(state, bullet, targetX, options) {
  const halfW = GUNSLINGER_HIT_W / 2;
  const crossed = (x) =>
    bullet.vx > 0 ? x >= targetX - halfW : bullet.vx < 0 && x <= targetX + halfW;
  return fly(state, bullet, options.maxFrames, (x, y) => (crossed(x) ? y : undefined), null);
}

function lineBlockedAtY(y, fromX, toX, rect) {
  const minX = Math.min(fromX, toX);
  const maxX = Math.max(fromX, toX);
  const crossesX = rect.x <= maxX && rect.x + rect.w >= minX;
  const crossesY = y + BULLET_RADIUS >= rect.y && y - BULLET_RADIUS <= rect.y + rect.h;
  return crossesX && crossesY;
}

function playerState(state, player) {
  const prefix = PLAYER_PREFIX[player];
  if (!prefix) return null;
  const x = state[`${prefix}x`];
  const y = state[`${prefix}y`];
  return Number.isFinite(x) && Number.isFinite(y) ? { x, y } : null;
}

function bulletState(state, player) {
  const prefix = BULLET_PREFIX[player];
  return {
    x: state[`${prefix}x`],
    y: state[`${prefix}y`],
    vx: state[`${prefix}vx`],
    vy: state[`${prefix}vy`],
    active: state[`${prefix}active`] === true,
    bounced: state[`${prefix}bounced`] === true,
  };
}

function minPlayerY() {
  return ARENA_TOP + GUNSLINGER_H / 2;
}

function maxPlayerY() {
  return ARENA_BOTTOM - GUNSLINGER_H / 2;
}
