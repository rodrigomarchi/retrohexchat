/**
 * Deterministic opponent controller for Hex Hockey solo sessions.
 * It reads plain game state and emits the same held-input shape used by the P2P
 * peer path, so the host simulation stays shared between solo and P2P.
 * @module games/hex_hockey_ai
 */

import { PHASE } from "./protocol.js";
import {
  RINK_LEFT,
  RINK_RIGHT,
  RINK_TOP,
  RINK_BOTTOM,
  RINK_CX,
  RINK_CY,
  GOAL_TOP,
  GOAL_BOTTOM,
  GOAL_LINE_LEFT,
  GOAL_LINE_RIGHT,
} from "./physics.js";
import {
  TableAI,
  clamp,
  createCommitment,
  dutyFrame,
  normalizeDifficulty,
  toward,
} from "../core/ai.js";

const PLAYER_HALF_SIZE = 4;
const PLAYER_MIN_X = RINK_LEFT + PLAYER_HALF_SIZE;
const PLAYER_MAX_X = RINK_RIGHT - PLAYER_HALF_SIZE;
const PLAYER_MIN_Y = RINK_TOP + PLAYER_HALF_SIZE;
const PLAYER_MAX_Y = RINK_BOTTOM - PLAYER_HALF_SIZE;
const GOAL_LANE_MARGIN = 12;
const ATTACK_SHOOT_DISTANCE = 190;
const TACKLE_COOLDOWN_MIN = 10;
// An angled shot is taken this far out from the goal line and from the
// rink's middle, so a diagonal shot from there crosses the line mid-goal.
const ANGLE_SHOT_DEPTH = 90;
const ANGLE_SHOT_REACH = 16;
const ANGLE_SHOT_TURN = 20;
// Closer than this to its target, the skater's steering error shrinks with the distance.
const STEER_ERROR_REACH = 120;
// The eight facings as steps: 0 is right, counting clockwise.
const FACING_DX = [1, 1, 0, -1, -1, -1, 0, 1];
const FACING_DY = [0, 1, 1, 1, 0, -1, -1, -1];

const NEUTRAL_INPUTS = Object.freeze({
  left: false,
  right: false,
  up: false,
  down: false,
  action: false,
});

/**
 * How each difficulty plays. The skater moves on `movementDuty` of the
 * frames. With the puck it either skates the goal lane and shoots from within
 * `shootRangePx`, or — on `angleShotChance` of its possessions, decided as it
 * takes the puck — shoots diagonally from beside the goal, past a goalie that
 * follows the puck. Each time it closes within `tackleRangePx` of the puck
 * carrier (the rink's tackle reach is 20 px) it waits `tackleDelayFrames`,
 * then decides once, with `tackleChance`, whether to try a tackle.
 * `deadzonePx` stays within 7 px, so a skater that stops short of the puck
 * on both axes is still within the rink's 10 px capture reach.
 */
export const HOCKEY_AI_DIFFICULTIES = Object.freeze({
  easy: Object.freeze({
    decisionInterval: 4,
    targetErrorPx: 22,
    deadzonePx: 7,
    movementDuty: 0.85,
    shootCooldownFrames: 54,
    angleShotChance: 0.6,
    shootRangePx: 190,
    shootChance: 0.7,
    tackleRangePx: 16,
    tackleDelayFrames: 14,
    tackleChance: 0.55,
    defensiveBias: 0.42,
  }),
  normal: Object.freeze({
    decisionInterval: 4,
    targetErrorPx: 18,
    deadzonePx: 7,
    movementDuty: 0.9,
    shootCooldownFrames: 32,
    angleShotChance: 0.65,
    shootRangePx: 190,
    shootChance: 0.72,
    tackleRangePx: 18,
    tackleDelayFrames: 12,
    tackleChance: 0.6,
    defensiveBias: 0.58,
  }),
  hard: Object.freeze({
    decisionInterval: 1,
    targetErrorPx: 6,
    deadzonePx: 4,
    movementDuty: 1,
    shootCooldownFrames: 18,
    angleShotChance: 0.95,
    shootRangePx: 150,
    shootChance: 1,
    tackleRangePx: 20,
    tackleDelayFrames: 4,
    tackleChance: 0.85,
    defensiveBias: 0.74,
  }),
});

/**
 * @param {unknown} difficulty
 * @returns {"easy"|"normal"|"hard"}
 */
export function normalizeHockeyAIDifficulty(difficulty) {
  return normalizeDifficulty(difficulty, HOCKEY_AI_DIFFICULTIES);
}

/**
 * @param {object} [options]
 * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
 * @param {() => number} [options.rng]
 * @returns {HockeyAI}
 */
export function createHockeyAI(options = {}) {
  return new HockeyAI(options);
}

export class HockeyAI extends TableAI {
  /**
   * @param {object} [options]
   * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
   * @param {() => number} [options.rng]
   */
  constructor(options = {}) {
    super(options, normalizeHockeyAIDifficulty, HOCKEY_AI_DIFFICULTIES);
    this.actionCooldown = 0;
    this._target = null;
    this.tackle = createCommitment();
    this.contact = 0;
    this.contactFrames = 0;
    this.plan = createCommitment();
    this.possession = 0;
    this.carrying = false;
    this.shot = createCommitment();
    this.opportunity = 0;
    this.lined = false;
    this.linedFrames = 0;
    this.steer = createCommitment();
    this.puckTurn = 0;
    this.puckHolder = null;
  }

  /**
   * A new face-off, period or match: no target held, no action cooling down,
   * and every decision kept for a contact, a possession, a shot or a steer is
   * drawn afresh.
   * @returns {void}
   */
  forget() {
    this._target = null;
    this.actionCooldown = 0;
    this.contactFrames = 0;
    this.carrying = false;
    this.lined = false;
    this.puckHolder = null;
    for (const decision of [this.tackle, this.plan, this.shot, this.steer]) decision.reset();
  }

  /**
   * @param {object} request
   * @param {object} request.state
   * @param {"easy"|"normal"|"hard"|string} [request.difficulty]
   * @param {1|2} [request.player]
   * @returns {{left: boolean, right: boolean, up: boolean, down: boolean, action: boolean}}
   */
  nextInputs(request = {}) {
    const { state, player } = this.startTurn(request);
    if (this.actionCooldown > 0) this.actionCooldown--;

    if (!state || (state.phase !== PHASE.PLAYING && state.phase !== PHASE.SUDDEN_DEATH)) {
      this._target = null;
      return NEUTRAL_INPUTS;
    }

    const actor = player === 1 ? state.p1 : state.p2;
    if (!actor || actor.stunTimer > 0) return NEUTRAL_INPUTS;

    const config = this.rowFor(request);

    if (actor.hasPuck && !this.carrying) this.possession++;
    this.carrying = actor.hasPuck === true;
    if (state.puck.possessedBy !== this.puckHolder) this.puckTurn++;
    this.puckHolder = state.puck.possessedBy;

    if (this.frame % config.decisionInterval === 0 || !this._target) {
      const spot = this._angleSpot(state, player, config);
      this._target = spot
        ? angleShotTarget(state, player, spot)
        : this._steerOff(state, player, chooseHockeyTarget(state, player, config), config);
    }

    const movement = dutyFrame(this.frame, config.movementDuty)
      ? movementInputs(state, player, this._target, config.deadzonePx)
      : NEUTRAL_INPUTS;
    const action = this._actionPressed(state, player, config);
    return { ...movement, action };
  }

  /**
   * @param {object} state
   * @param {1|2} player
   * @param {object} config
   * @returns {boolean}
   */
  _actionPressed(state, player, config) {
    const tackleReady = this._tackleReady(state, player, config);
    const shotReady = this._shotReady(state, player, config);
    if (this.actionCooldown > 0) return false;

    if (playerHasPuck(state, player)) {
      if (!shotReady) return false;

      this.actionCooldown = config.shootCooldownFrames;
      return true;
    }

    if (!tackleReady) return false;

    this.contactFrames = 0;
    this.actionCooldown = Math.max(TACKLE_COOLDOWN_MIN, Math.floor(config.shootCooldownFrames / 2));
    return true;
  }

  /**
   * Whether the carrier is lined up for its shot and decided to take it: the
   * decision is drawn once, with `shootChance`, each time it lines up, and
   * thought over again every `shootCooldownFrames` it stays lined up.
   * @param {object} state
   * @param {1|2} player
   * @param {object} config
   * @returns {boolean}
   */
  _shotReady(state, player, config) {
    const spot = this._angleSpot(state, player, config);
    let lined = false;
    if (playerHasPuck(state, player)) {
      lined = spot
        ? angleShotReady(state, player, spot)
        : shouldShoot(state, player, config.shootRangePx);
    }
    if (lined && !this.lined) {
      this.opportunity++;
      this.linedFrames = 0;
    }
    this.lined = lined;
    if (!lined) return false;

    const rethink = Math.floor(this.linedFrames++ / config.shootCooldownFrames);
    return this.shot.hold(`${this.opportunity}:${rethink}`, () => this.rng() <= config.shootChance);
  }

  /**
   * Where the skater heads for `target`, off it by an error of up to
   * `targetErrorPx` on each axis, drawn once for each kind of target while
   * the puck stays with the same holder. The error shrinks as the skater
   * closes in, so it misjudges the way there but still arrives.
   * @param {object} state
   * @param {1|2} player
   * @param {{x: number, y: number, kind: string}} target
   * @param {object} config
   * @returns {{x: number, y: number, kind: string}}
   */
  _steerOff(state, player, target, config) {
    const offset = this.steer.hold(`${target.kind}:${this.puckTurn}`, () => ({
      x: errorOffset(config.targetErrorPx, this.rng),
      y: errorOffset(config.targetErrorPx, this.rng),
    }));
    const away = Math.min(1, distance(playerState(state, player), target) / STEER_ERROR_REACH);
    return applyTargetError(target, { x: offset.x * away, y: offset.y * away });
  }

  /**
   * The spot of this possession's angled shot, when it is going for one:
   * decided once as the skater takes the puck, from above or below the goal.
   * @param {object} state
   * @param {1|2} player
   * @param {object} config
   * @returns {{x: number, y: number, facing: number}|null}
   */
  _angleSpot(state, player, config) {
    if (!playerHasPuck(state, player)) return null;
    const side = this.plan.hold(this.possession, () => {
      if (this.rng() >= config.angleShotChance) return 0;
      return this.rng() < 0.5 ? -1 : 1;
    });
    return side === 0 ? null : angleShotSpot(state, player, side);
  }

  /**
   * Whether this contact with the puck carrier has lasted past the reaction
   * delay and is one the skater decided to tackle in. A contact begins when
   * it closes within reach, and again after each try.
   * @param {object} state
   * @param {1|2} player
   * @param {object} config
   * @returns {boolean}
   */
  _tackleReady(state, player, config) {
    const opponent = player === 1 ? state.p2 : state.p1;
    const inReach =
      opponent?.hasPuck === true &&
      distance(playerState(state, player), opponent) <= config.tackleRangePx;
    if (!inReach) {
      this.contactFrames = 0;
      return false;
    }

    if (this.contactFrames === 0) this.contact++;
    this.contactFrames++;
    if (this.contactFrames <= config.tackleDelayFrames) return false;
    return this.tackle.hold(this.contact, () => this.rng() <= config.tackleChance);
  }
}

/**
 * @param {object} state
 * @param {1|2} player
 * @param {object} config
 * @returns {{x: number, y: number, kind: "attack"|"chase"|"defend"|"tackle"}}
 */
export function chooseHockeyTarget(state, player = 2, config = HOCKEY_AI_DIFFICULTIES.normal) {
  const actor = playerState(state, player);
  const opponent = playerState(state, player === 1 ? 2 : 1);

  if (actor?.hasPuck) {
    return { ...attackingGoalCenter(state, player), kind: "attack" };
  }

  if (opponent?.hasPuck) {
    return { x: opponent.x, y: opponent.y, kind: "tackle" };
  }

  if (puckThreatensOwnGoal(state, player)) {
    return defensiveHomePosition(state, player, config.defensiveBias);
  }

  return {
    x: clamp(state.puck.x, PLAYER_MIN_X, PLAYER_MAX_X),
    y: clamp(state.puck.y, PLAYER_MIN_Y, PLAYER_MAX_Y),
    kind: "chase",
  };
}

/**
 * @param {object} state
 * @param {1|2} player
 * @returns {{x: number, y: number}}
 */
export function attackingGoalCenter(state, player = 2) {
  const attackingRight = player === 1 ? state.sidesSwapped === false : state.sidesSwapped === true;

  return {
    x: attackingRight ? GOAL_LINE_RIGHT + GOAL_LANE_MARGIN : GOAL_LINE_LEFT - GOAL_LANE_MARGIN,
    y: RINK_CY,
  };
}

/**
 * Where an angled shot is taken from, above (`side` -1) or below (1) the
 * goal, and the facing that sends it into the goal.
 * @param {object} state
 * @param {1|2} player
 * @param {-1|1} side
 * @returns {{x: number, y: number, facing: number}}
 */
export function angleShotSpot(state, player, side) {
  const attackingRight = attackingGoalCenter(state, player).x > RINK_CX;
  const towardGoal = attackingRight ? 1 : -1;
  const goalLine = attackingRight ? GOAL_LINE_RIGHT : GOAL_LINE_LEFT;
  const facing = FACING_DX.findIndex((dx, i) => dx === towardGoal && FACING_DY[i] === -side);
  return {
    x: goalLine - towardGoal * ANGLE_SHOT_DEPTH,
    y: RINK_CY + side * ANGLE_SHOT_DEPTH,
    facing,
  };
}

/**
 * Where to skate for an angled shot: to its spot, then a step on toward the
 * goal to turn and face it.
 * @param {object} state
 * @param {1|2} player
 * @param {{x: number, y: number, facing: number}} spot
 * @returns {{x: number, y: number, kind: "angle"}}
 */
export function angleShotTarget(state, player, spot) {
  const actor = playerState(state, player);
  const atSpot = distance(actor, spot) <= ANGLE_SHOT_REACH;
  return {
    x: spot.x + (atSpot ? FACING_DX[spot.facing] * ANGLE_SHOT_TURN : 0),
    y: spot.y + (atSpot ? FACING_DY[spot.facing] * ANGLE_SHOT_TURN : 0),
    kind: "angle",
  };
}

/**
 * Whether the carrier stands at its angled-shot spot facing the goal.
 * @param {object} state
 * @param {1|2} player
 * @param {{x: number, y: number, facing: number}} spot
 * @returns {boolean}
 */
export function angleShotReady(state, player, spot) {
  const actor = playerState(state, player);
  return actor?.facing === spot.facing && distance(actor, spot) <= ANGLE_SHOT_REACH;
}

/**
 * @param {object} state
 * @param {1|2} player
 * @param {number} [bias]
 * @returns {{x: number, y: number, kind: "defend"}}
 */
export function defensiveHomePosition(state, player = 2, bias = 0.58) {
  const defendsRight = player === 1 ? state.sidesSwapped === true : state.sidesSwapped === false;
  const homeX = defendsRight ? RINK_RIGHT - 85 : RINK_LEFT + 85;
  const puckY = state?.puck?.y ?? RINK_CY;

  return {
    x: homeX,
    y: clamp(puckY * bias + RINK_CY * (1 - bias), GOAL_TOP, GOAL_BOTTOM),
    kind: "defend",
  };
}

/**
 * @param {object} state
 * @param {1|2} player
 * @param {{x: number, y: number}} target
 * @param {number} deadzone
 * @returns {{left: boolean, right: boolean, up: boolean, down: boolean, action: boolean}}
 */
export function movementInputs(state, player, target, deadzone) {
  const actor = playerState(state, player);
  if (!actor || !target) return NEUTRAL_INPUTS;

  const [left, right] = toward(actor.x, target.x, deadzone);
  const [up, down] = toward(actor.y, target.y, deadzone);
  return { left, right, up, down, action: false };
}

/**
 * Whether the puck carrier faces the goal from inside its lane and within
 * `range` of the goal line.
 * @param {object} state
 * @param {1|2} player
 * @param {number} [range]
 * @returns {boolean}
 */
export function shouldShoot(state, player = 2, range = ATTACK_SHOOT_DISTANCE) {
  const actor = playerState(state, player);
  if (!actor?.hasPuck) return false;

  const goal = attackingGoalCenter(state, player);
  const attackingRight = goal.x > RINK_CX;
  const facingGoal = attackingRight
    ? actor.facing === 0 || actor.facing === 1 || actor.facing === 7
    : actor.facing === 3 || actor.facing === 4 || actor.facing === 5;
  if (!facingGoal) return false;

  const inLane = actor.y >= GOAL_TOP - 18 && actor.y <= GOAL_BOTTOM + 18;
  const closeEnough = Math.abs(goal.x - actor.x) <= range;
  return inLane && closeEnough;
}

/**
 * @param {object} state
 * @param {1|2} player
 * @returns {boolean}
 */
function playerHasPuck(state, player) {
  return playerState(state, player)?.hasPuck === true;
}

/**
 * @param {object} state
 * @param {1|2} player
 * @returns {object|null}
 */
function playerState(state, player) {
  return player === 1 ? state?.p1 || null : state?.p2 || null;
}

/**
 * @param {object} state
 * @param {1|2} player
 * @returns {boolean}
 */
function puckThreatensOwnGoal(state, player) {
  const puck = state?.puck;
  if (!puck || puck.possessedBy !== 0) return false;

  const defendsRight = player === 1 ? state.sidesSwapped === true : state.sidesSwapped === false;
  const movingTowardGoal = defendsRight ? puck.vx > 0 : puck.vx < 0;
  const onDefensiveHalf = defendsRight ? puck.x > RINK_CX : puck.x < RINK_CX;
  return movingTowardGoal && onDefensiveHalf;
}

/**
 * The target moved by `offset`, kept on the rink.
 * @param {{x: number, y: number, kind: string}} target
 * @param {{x: number, y: number}} offset
 * @returns {{x: number, y: number, kind: string}}
 */
function applyTargetError(target, offset) {
  if (!target) return target;

  return {
    ...target,
    x: clamp(target.x + offset.x, PLAYER_MIN_X, PLAYER_MAX_X),
    y: clamp(target.y + offset.y, PLAYER_MIN_Y, PLAYER_MAX_Y),
  };
}

/**
 * @param {object} a
 * @param {object} b
 * @returns {number}
 */
function distance(a, b) {
  const dx = a.x - b.x;
  const dy = a.y - b.y;
  return Math.sqrt(dx * dx + dy * dy);
}

/**
 * @param {number} amount
 * @param {() => number} rng
 * @returns {number}
 */
function errorOffset(amount, rng) {
  return (rng() * 2 - 1) * amount;
}
