/**
 * Deterministic opponent controller for Hex Boxing solo sessions.
 * It emits the same held-input shape used by the P2P peer path.
 * @module games/hex_boxing_ai
 */

import { PHASE, PUNCH_STATE } from "./protocol.js";
import {
  BOXER_BODY_RADIUS,
  BOXER_SPEED,
  FIST_RADIUS,
  PUNCH_COOLDOWN,
  PUNCH_DURATION,
  PUNCH_RANGE,
  PUNCH_WINDUP,
  RING_BOTTOM,
  RING_LEFT,
  RING_RIGHT,
  RING_TOP,
} from "./physics.js";
import {
  TableAI,
  clamp,
  createDelayedView,
  createPerThing,
  normalizeDifficulty,
  toward,
} from "../core/ai.js";

const PLAYER_HALF_SIZE = BOXER_BODY_RADIUS;
const PLAYER_MIN_X = RING_LEFT + PLAYER_HALF_SIZE;
const PLAYER_MAX_X = RING_RIGHT - PLAYER_HALF_SIZE;
const PLAYER_MIN_Y = RING_TOP + PLAYER_HALF_SIZE;
const PLAYER_MAX_Y = RING_BOTTOM - PLAYER_HALF_SIZE;
// The farthest a fist lands from the puncher's centre.
const PUNCH_REACH = PUNCH_RANGE + BOXER_BODY_RADIUS + FIST_RADIUS;
// A dodge steps back this far from the rival, out of the fist's reach.
const DODGE_STEP_PX = 18;
// A dodge needs the step back, and a few frames to spare to be set again
// when the punch flies by; a wind-up seen later than that is not worth
// running from, and the AI stands and trades instead.
const DODGE_FRAMES = Math.ceil(DODGE_STEP_PX / BOXER_SPEED) + 3;
// The farthest a punch lands from: the fist at full reach touching the body.
const PUNCH_LANDING_PX = PUNCH_REACH + BOXER_BODY_RADIUS;
// A punch wound up, thrown, then the arm's recovery: no boxer punches faster.
const PUNCH_CYCLE_FRAMES = PUNCH_WINDUP + PUNCH_DURATION + PUNCH_COOLDOWN;

const NEUTRAL_INPUTS = Object.freeze({
  up: false,
  down: false,
  left: false,
  right: false,
  punch: false,
});

// reactionFrames: how old the rival's position, facing and punch are when
// this AI reads them. It steps in to idealDistancePx when its punch is ready
// and keeps to standoffDistancePx while it is not — out of reach on easy and
// normal, closer in on hard. punchAlignmentPx stays inside the 11 px a fist
// lands within and never loosens with difficulty; punchCooldownFrames is
// never shorter than a punch's own cycle. punchChance: the odds an opening is
// taken; a passed one waits out the cooldown. dodgeChance: the odds a punch
// is dodged, decided once per punch. punchReactionFrames: how late the AI
// sees a punch's wind-up start — the quicker it sees one, the likelier it is
// out of reach before the punch flies.
const EASY = Object.freeze({
  reactionFrames: 8,
  punchReactionFrames: 12,
  decisionInterval: 3,
  targetErrorPx: 6,
  deadzonePx: 4,
  idealDistancePx: 28,
  standoffDistancePx: 48,
  retreatDistancePx: 16,
  punchDistancePx: PUNCH_REACH,
  punchAlignmentPx: 7,
  punchChance: 1,
  punchCooldownFrames: 37,
  dodgeChance: 0.2,
});

export const BOXING_AI_DIFFICULTIES = Object.freeze({
  easy: EASY,
  normal: Object.freeze({
    ...EASY,
    punchReactionFrames: 6,
    standoffDistancePx: 44,
    punchCooldownFrames: 36,
    dodgeChance: 0.25,
  }),
  hard: Object.freeze({
    ...EASY,
    punchReactionFrames: 3,
    standoffDistancePx: 40,
    punchCooldownFrames: 35,
    dodgeChance: 0.25,
  }),
});

/** The shortest a difficulty may wait between punches. */
export const BOXING_PUNCH_CYCLE_FRAMES = PUNCH_CYCLE_FRAMES;

/**
 * @param {unknown} difficulty
 * @returns {"easy"|"normal"|"hard"}
 */
export function normalizeBoxingAIDifficulty(difficulty) {
  return normalizeDifficulty(difficulty, BOXING_AI_DIFFICULTIES);
}

/**
 * @param {object} [options]
 * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
 * @param {() => number} [options.rng]
 * @returns {BoxingAI}
 */
export function createBoxingAI(options = {}) {
  return new BoxingAI(options);
}

export class BoxingAI extends TableAI {
  /**
   * @param {object} [options]
   * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
   * @param {() => number} [options.rng]
   */
  constructor(options = {}) {
    super(options, normalizeBoxingAIDifficulty, BOXING_AI_DIFFICULTIES);
    this.punchCooldown = 0;
    this._target = null;
    this._view = createDelayedView();
    this._punchView = createDelayedView();
    this._punches = createPerThing();
    this._rivalPunch = null;
  }

  /**
   * A new round or match: no target held, the rival and its punches unseen
   * until they are looked at again.
   * @returns {void}
   */
  forget() {
    this._target = null;
    this._view.reset();
    this._punchView.reset();
    this._punches.reset();
    this._rivalPunch = null;
  }

  /**
   * @param {object} request
   * @param {object} request.state
   * @param {"easy"|"normal"|"hard"|string} [request.difficulty]
   * @param {1|2} [request.player]
   * @returns {{up: boolean, down: boolean, left: boolean, right: boolean, punch: boolean}}
   */
  nextInputs(request = {}) {
    const { state, player } = this.startTurn(request);
    if (this.punchCooldown > 0) this.punchCooldown--;

    if (!state || state.phase !== PHASE.FIGHTING) return NEUTRAL_INPUTS;

    const actor = boxerState(state, player);
    const opponent = boxerState(state, player === 1 ? 2 : 1);
    if (!actor || !opponent) return NEUTRAL_INPUTS;

    const config = this.rowFor(request);

    const seen = this._seen(state, player, config);
    const dodge = this._dodges(state, player, config);
    const ready = this.punchCooldown <= 0 && actor.punchState === PUNCH_STATE.IDLE;
    // A punch of its own wound up or in flight: it stands and delivers.
    const throwing =
      actor.punchState === PUNCH_STATE.WINDUP || actor.punchState === PUNCH_STATE.PUNCHING;
    const dodging = this._target?.kind === "dodge";
    if (this.frame % config.decisionInterval === 0 || !this._target || dodge !== dodging) {
      const plan = { dodge, ready };
      const target = boxingTargetPosition(dodge ? state : seen, player, config, plan);
      this._target = dodge ? target : applyTargetError(target, config.targetErrorPx, this.rng);
    }

    const facing = ready && !dodge ? boxingFacingInputs(seen, player, config) : null;
    const movement =
      throwing && !dodge
        ? NEUTRAL_INPUTS
        : (facing ?? boxingMovementInputs(actor, this._target, config.deadzonePx));
    if (!ready || !shouldThrowPunch(seen, player, config)) return { ...movement, punch: false };

    // One roll per opening; a passed one waits out the cooldown like a punch.
    this.punchCooldown = config.punchCooldownFrames;
    return { ...movement, punch: this.rng() < config.punchChance };
  }

  /** The state with the rival where it stood, faced and punched reactionFrames ago. */
  _seen(state, player, config) {
    const prefix = player === 1 ? "b2" : "b1";
    const rival = this._view.see(boxerState(state, player === 1 ? 2 : 1), config.reactionFrames);
    return {
      ...state,
      [`${prefix}x`]: rival.x,
      [`${prefix}y`]: rival.y,
      [`${prefix}dir`]: rival.dir,
      [`${prefix}punchState`]: rival.punchState,
    };
  }

  /**
   * Whether to dodge the punch this AI sees coming — punchReactionFrames
   * after it starts — decided once per punch.
   */
  _dodges(state, player, config) {
    const rival = boxerState(state, player === 1 ? 2 : 1);
    const punchState = this._punchView.see(rival.punchState, config.punchReactionFrames);
    if (punchState !== PUNCH_STATE.WINDUP && punchState !== PUNCH_STATE.PUNCHING) {
      this._rivalPunch = null;
      this._punches.keep([]);
      return false;
    }

    if (this._rivalPunch === null) this._rivalPunch = this.frame;
    this._punches.keep([this._rivalPunch]);
    // Seen punchReactionFrames into its wind-up: is there still time to step out?
    const inTime =
      punchState === PUNCH_STATE.WINDUP &&
      config.punchReactionFrames + DODGE_FRAMES <= PUNCH_WINDUP;
    return this._punches.decide(this._rivalPunch, () => inTime && this.rng() < config.dodgeChance);
  }
}

/**
 * Where to stand: a step back from a punch the AI dodges, in at
 * idealDistancePx when its own punch is ready, back at standoffDistancePx
 * while it is not.
 * @param {object} state
 * @param {1|2} player
 * @param {object} config
 * @param {{ dodge?: boolean, ready?: boolean }} [plan]
 * @returns {{x: number, y: number, kind: "approach"|"standoff"|"retreat"|"dodge"}}
 */
export function boxingTargetPosition(
  state,
  player = 2,
  config = BOXING_AI_DIFFICULTIES.normal,
  plan = {},
) {
  const ring = corner(state, player);
  if (!ring) return { x: 320, y: 240, kind: "approach" };

  const { actor, opponent, distance } = ring;
  const side = player === 1 ? -1 : 1;

  if (plan.dodge === true && distance < PUNCH_LANDING_PX) {
    const away = Math.sign(actor.x - opponent.x) || side;
    return {
      x: clamp(actor.x + away * DODGE_STEP_PX, PLAYER_MIN_X, PLAYER_MAX_X),
      y: actor.y,
      kind: "dodge",
    };
  }

  const kind =
    distance < config.retreatDistancePx
      ? "retreat"
      : plan.ready === false
        ? "standoff"
        : "approach";
  const targetDistance = {
    retreat: config.retreatDistancePx + 12,
    standoff: config.standoffDistancePx,
    approach: config.idealDistancePx,
  }[kind];

  return {
    x: clamp(opponent.x + side * targetDistance, PLAYER_MIN_X, PLAYER_MAX_X),
    y: clamp(opponent.y, PLAYER_MIN_Y, PLAYER_MAX_Y),
    kind,
  };
}

/**
 * @param {{x: number, y: number}} actor
 * @param {{x: number, y: number}} target
 * @param {number} deadzone
 * @returns {{up: boolean, down: boolean, left: boolean, right: boolean, punch: boolean}}
 */
export function boxingMovementInputs(actor, target, deadzone) {
  if (!actor || !target) return NEUTRAL_INPUTS;

  const [left, right] = toward(actor.x, target.x, deadzone);
  const [up, down] = toward(actor.y, target.y, deadzone);
  return { left, right, up, down, punch: false };
}

/**
 * A step toward the rival, for a boxer in range and lined up but facing
 * elsewhere — the step turns it to face; null when there is nothing to turn.
 * @param {object} state
 * @param {1|2} player
 * @param {object} config
 * @returns {{up: boolean, down: boolean, left: boolean, right: boolean, punch: boolean}|null}
 */
export function boxingFacingInputs(state, player = 2, config = BOXING_AI_DIFFICULTIES.normal) {
  const ring = corner(state, player);
  if (!inPunchLine(ring, config) || facesRival(ring)) return null;

  const { dx, dy } = ring;
  const across = Math.abs(dx) >= Math.abs(dy);
  return {
    ...NEUTRAL_INPUTS,
    left: across && dx < 0,
    right: across && dx > 0,
    up: !across && dy < 0,
    down: !across && dy > 0,
  };
}

/**
 * @param {object} state
 * @param {1|2} player
 * @param {object} config
 * @param {() => number} [rng]
 * @returns {boolean}
 */
export function shouldThrowPunch(state, player = 2, config = BOXING_AI_DIFFICULTIES.normal, rng) {
  const ring = corner(state, player);
  if (!inPunchLine(ring, config) || ring.actor.punchState !== PUNCH_STATE.IDLE) return false;
  if (!facesRival(ring)) return false;

  const roll = typeof rng === "function" ? rng() : 0;
  return roll < config.punchChance;
}

/**
 * @param {number} dir
 * @param {number} dx
 * @param {number} dy
 * @returns {boolean}
 */
export function directionFacesOpponent(dir, dx, dy) {
  if (Math.abs(dx) >= Math.abs(dy)) {
    return dx < 0 ? dir >= 3 && dir <= 5 : dir === 0 || dir === 1 || dir === 7;
  }

  return dy < 0 ? dir >= 5 && dir <= 7 : dir >= 1 && dir <= 3;
}

/** Both boxers, as `player` sees them: itself, its rival, and the gap between. */
function corner(state, player) {
  const actor = boxerState(state, player);
  const opponent = boxerState(state, player === 1 ? 2 : 1);
  if (!actor || !opponent) return null;

  const dx = opponent.x - actor.x;
  const dy = opponent.y - actor.y;
  return { actor, opponent, dx, dy, distance: Math.hypot(dx, dy) };
}

/** Whether the rival is within reach and about level with the puncher. */
function inPunchLine(ring, config) {
  return (
    ring !== null &&
    ring.distance <= config.punchDistancePx &&
    Math.abs(ring.dy) <= config.punchAlignmentPx
  );
}

function facesRival(ring) {
  return directionFacesOpponent(ring.actor.dir, ring.dx, ring.dy);
}

function boxerState(state, player) {
  const prefix = player === 1 ? "b1" : "b2";
  if (typeof state?.[`${prefix}x`] !== "number" || typeof state?.[`${prefix}y`] !== "number") {
    return null;
  }

  return {
    x: state[`${prefix}x`],
    y: state[`${prefix}y`],
    dir: state[`${prefix}dir`],
    punchState: state[`${prefix}punchState`],
  };
}

function applyTargetError(target, amount, rng) {
  if (!amount) return target;
  const offsetX = (rng() * 2 - 1) * amount;
  const offsetY = (rng() * 2 - 1) * amount;

  return {
    ...target,
    x: clamp(target.x + offsetX, PLAYER_MIN_X, PLAYER_MAX_X),
    y: clamp(target.y + offsetY, PLAYER_MIN_Y, PLAYER_MAX_Y),
  };
}
