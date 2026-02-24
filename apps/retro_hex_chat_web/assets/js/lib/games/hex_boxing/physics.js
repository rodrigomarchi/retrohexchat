/**
 * Pure physics and game logic for Hex Boxing.
 * All functions are pure — no side effects, no DOM, no network.
 * @module games/hex_boxing_physics
 */

import { PHASE, PUNCH_STATE } from "./protocol.js";

// --- Canvas ---
export const CANVAS_W = 640;
export const CANVAS_H = 480;

// --- Ring boundaries ---
export const RING_PADDING = 24;
export const RING_LEFT = RING_PADDING;
export const RING_RIGHT = CANVAS_W - RING_PADDING;
export const RING_TOP = 44;
export const RING_BOTTOM = CANVAS_H - 44;

// --- Boxer ---
export const BOXER_BODY_RADIUS = 8;
export const BOXER_SPEED = 2.5;

// --- Punch ---
export const PUNCH_RANGE = 24;
export const PUNCH_DURATION = 9; // frames (~150ms)
export const PUNCH_COOLDOWN = 12; // frames (~200ms)
export const FIST_RADIUS = 3;

// --- Scoring zones (distance between body centers minus radii) ---
export const CLOSE_DIST = 12; // 3 points
export const MEDIUM_DIST = 18; // 2 points
// Anything beyond MEDIUM_DIST up to PUNCH_RANGE + FIST_RADIUS = 1 point

// --- Gameplay ---
export const ROUND_DURATION = 7200; // frames (2 min at 60fps)
export const MAX_ROUNDS = 3;
export const ROUNDS_TO_WIN = 2;
export const KO_SCORE = 100;

// --- 8-direction lookup tables ---
// 0=right, 1=down-right, 2=down, 3=down-left, 4=left, 5=up-left, 6=up, 7=up-right
const SQRT2_2 = Math.SQRT2 / 2;
export const DIR_DX = [1, SQRT2_2, 0, -SQRT2_2, -1, -SQRT2_2, 0, SQRT2_2];
export const DIR_DY = [0, SQRT2_2, 1, SQRT2_2, 0, -SQRT2_2, -1, -SQRT2_2];

// --- Spawn positions ---
const P1_SPAWN_X = Math.round(CANVAS_W * 0.3);
const P1_SPAWN_Y = Math.round((RING_TOP + RING_BOTTOM) / 2);
const P2_SPAWN_X = Math.round(CANVAS_W * 0.7);
const P2_SPAWN_Y = P1_SPAWN_Y;

/**
 * Create initial game state.
 * @returns {object}
 */
export function createInitialState() {
  return {
    // Boxer 1 (P1 — green, left side, facing right)
    b1x: P1_SPAWN_X,
    b1y: P1_SPAWN_Y,
    b1dir: 0,
    b1punchState: PUNCH_STATE.IDLE,
    b1punchTimer: 0,
    b1cooldownTimer: 0,
    b1arm: 0,

    // Boxer 2 (P2 — cyan, right side, facing left)
    b2x: P2_SPAWN_X,
    b2y: P2_SPAWN_Y,
    b2dir: 4,
    b2punchState: PUNCH_STATE.IDLE,
    b2punchTimer: 0,
    b2cooldownTimer: 0,
    b2arm: 0,

    // Scores
    score1: 0,
    score2: 0,

    // Meta
    phase: PHASE.WAITING,
    countdown: 0,
    round: 1,
    roundWins1: 0,
    roundWins2: 0,
    roundTimer: ROUND_DURATION,

    // Event flags (cleared each frame by engine)
    lastHitPlayer: 0,
    lastHitPoints: 0,
    koPlayer: 0,
  };
}

/**
 * Clamp position to ring boundaries.
 * @param {number} x
 * @param {number} y
 * @returns {{ x: number, y: number }}
 */
export function clampToRing(x, y) {
  return {
    x: Math.max(RING_LEFT + BOXER_BODY_RADIUS, Math.min(RING_RIGHT - BOXER_BODY_RADIUS, x)),
    y: Math.max(RING_TOP + BOXER_BODY_RADIUS, Math.min(RING_BOTTOM - BOXER_BODY_RADIUS, y)),
  };
}

/**
 * Move boxer in the given direction (0-7) and update facing.
 * Also pushes opponent apart if body collision occurs.
 * @param {object} state
 * @param {number} player - 1 or 2
 * @param {number} dirIndex - 0-7
 * @returns {object} Updated state
 */
export function moveBoxer(state, player, dirIndex) {
  const prefix = player === 1 ? "b1" : "b2";
  const otherPrefix = player === 1 ? "b2" : "b1";

  const dx = DIR_DX[dirIndex] * BOXER_SPEED;
  const dy = DIR_DY[dirIndex] * BOXER_SPEED;

  let newX = state[`${prefix}x`] + dx;
  let newY = state[`${prefix}y`] + dy;

  // Clamp to ring
  const clamped = clampToRing(newX, newY);
  newX = clamped.x;
  newY = clamped.y;

  // Update facing direction
  let result = { ...state, [`${prefix}x`]: newX, [`${prefix}y`]: newY, [`${prefix}dir`]: dirIndex };

  // Check body-body collision and push apart
  result = resolveBodyCollision(result, prefix, otherPrefix);

  return result;
}

/**
 * Resolve body collision between two boxers — push the moving one back.
 * @param {object} state
 * @param {string} movedPrefix - prefix of boxer that just moved
 * @param {string} otherPrefix - prefix of the other boxer
 * @returns {object}
 */
function resolveBodyCollision(state, movedPrefix, otherPrefix) {
  const ax = state[`${movedPrefix}x`];
  const ay = state[`${movedPrefix}y`];
  const bx = state[`${otherPrefix}x`];
  const by = state[`${otherPrefix}y`];

  const dx = ax - bx;
  const dy = ay - by;
  const dist = Math.sqrt(dx * dx + dy * dy);
  const minDist = BOXER_BODY_RADIUS * 2;

  if (dist >= minDist || dist === 0) return state;

  // Push apart along collision axis
  const overlap = minDist - dist;
  const nx = dx / dist;
  const ny = dy / dist;

  // Push the mover back by the full overlap
  const pushedX = ax + nx * overlap;
  const pushedY = ay + ny * overlap;
  const clamped = clampToRing(pushedX, pushedY);

  return {
    ...state,
    [`${movedPrefix}x`]: clamped.x,
    [`${movedPrefix}y`]: clamped.y,
  };
}

/**
 * Start a punch if boxer is idle.
 * Alternates between left (0) and right (1) arm.
 * @param {object} state
 * @param {number} player - 1 or 2
 * @returns {object}
 */
export function startPunch(state, player) {
  const prefix = player === 1 ? "b1" : "b2";

  if (state[`${prefix}punchState`] !== PUNCH_STATE.IDLE) return state;

  return {
    ...state,
    [`${prefix}punchState`]: PUNCH_STATE.PUNCHING,
    [`${prefix}punchTimer`]: PUNCH_DURATION,
    [`${prefix}arm`]: state[`${prefix}arm`] === 0 ? 1 : 0,
  };
}

/**
 * Tick punch timers for both boxers. Transitions:
 * PUNCHING (timer > 0) → PUNCHING (timer--)
 * PUNCHING (timer = 0) → COOLDOWN (timer = PUNCH_COOLDOWN)
 * COOLDOWN (timer > 0) → COOLDOWN (timer--)
 * COOLDOWN (timer = 0) → IDLE
 * @param {object} state
 * @returns {object}
 */
export function tickPunchTimers(state) {
  let s = state;
  s = _tickPunchTimer(s, "b1");
  s = _tickPunchTimer(s, "b2");
  return s;
}

function _tickPunchTimer(state, prefix) {
  const ps = state[`${prefix}punchState`];
  const timer = state[`${prefix}punchTimer`];
  const cdTimer = state[`${prefix}cooldownTimer`];

  if (ps === PUNCH_STATE.PUNCHING) {
    if (timer > 1) {
      return { ...state, [`${prefix}punchTimer`]: timer - 1 };
    }
    // Punch finished → enter cooldown
    return {
      ...state,
      [`${prefix}punchState`]: PUNCH_STATE.COOLDOWN,
      [`${prefix}punchTimer`]: 0,
      [`${prefix}cooldownTimer`]: PUNCH_COOLDOWN,
    };
  }

  if (ps === PUNCH_STATE.COOLDOWN) {
    if (cdTimer > 1) {
      return { ...state, [`${prefix}cooldownTimer`]: cdTimer - 1 };
    }
    // Cooldown finished → idle
    return {
      ...state,
      [`${prefix}punchState`]: PUNCH_STATE.IDLE,
      [`${prefix}cooldownTimer`]: 0,
    };
  }

  return state;
}

/**
 * Calculate fist position for a boxer mid-punch.
 * Returns null if not currently punching.
 * @param {object} state
 * @param {number} player - 1 or 2
 * @returns {{ x: number, y: number }|null}
 */
export function getFistPosition(state, player) {
  const prefix = player === 1 ? "b1" : "b2";

  if (state[`${prefix}punchState`] !== PUNCH_STATE.PUNCHING) return null;

  const timer = state[`${prefix}punchTimer`];
  // Extension: rises from 0 to PUNCH_RANGE at midpoint, then retracts
  // timer goes from PUNCH_DURATION down to 1
  const progress = 1 - (timer - 1) / (PUNCH_DURATION - 1);
  // Triangle wave: 0→1→0 over the punch duration
  const extension = progress <= 0.5 ? progress * 2 : (1 - progress) * 2;
  const reach = BOXER_BODY_RADIUS + extension * PUNCH_RANGE;

  const dir = state[`${prefix}dir`];
  const bx = state[`${prefix}x`];
  const by = state[`${prefix}y`];

  return {
    x: bx + DIR_DX[dir] * reach,
    y: by + DIR_DY[dir] * reach,
  };
}

/**
 * Check if attacker's punch hits the opponent.
 * Returns updated state with score and event flags if hit.
 * Only scores once per punch (uses a simple "already hit" check via punchTimer).
 * @param {object} state
 * @param {number} attacker - 1 or 2
 * @returns {object}
 */
export function checkPunchHit(state, attacker) {
  const fist = getFistPosition(state, attacker);
  if (!fist) return state;

  const defPrefix = attacker === 1 ? "b2" : "b1";
  const defX = state[`${defPrefix}x`];
  const defY = state[`${defPrefix}y`];

  const dx = fist.x - defX;
  const dy = fist.y - defY;
  const dist = Math.sqrt(dx * dx + dy * dy);

  if (dist >= FIST_RADIUS + BOXER_BODY_RADIUS) return state;

  // Hit detected! Calculate distance-based score
  const atkPrefix = attacker === 1 ? "b1" : "b2";
  const atkX = state[`${atkPrefix}x`];
  const atkY = state[`${atkPrefix}y`];
  const bodyDist = Math.sqrt((atkX - defX) * (atkX - defX) + (atkY - defY) * (atkY - defY));
  const impactDist = bodyDist - BOXER_BODY_RADIUS * 2;

  let points;
  if (impactDist < CLOSE_DIST) {
    points = 3;
  } else if (impactDist < MEDIUM_DIST) {
    points = 2;
  } else {
    points = 1;
  }

  const scoreKey = attacker === 1 ? "score1" : "score2";
  const newScore = Math.min(state[scoreKey] + points, 255);

  // End the punch immediately to prevent multi-hit
  return {
    ...state,
    [scoreKey]: newScore,
    [`${atkPrefix}punchState`]: PUNCH_STATE.COOLDOWN,
    [`${atkPrefix}punchTimer`]: 0,
    [`${atkPrefix}cooldownTimer`]: PUNCH_COOLDOWN,
    lastHitPlayer: attacker,
    lastHitPoints: points,
  };
}

/**
 * Tick the round timer.
 * @param {object} state
 * @returns {object}
 */
export function tickRoundTimer(state) {
  if (state.roundTimer <= 0) return state;
  return { ...state, roundTimer: state.roundTimer - 1 };
}

/**
 * Check if the round has ended (KO or time up).
 * @param {object} state
 * @returns {{ ended: boolean, roundWinner: number }}
 */
export function checkRoundEnd(state) {
  if (state.score1 >= KO_SCORE) {
    return { ended: true, roundWinner: 1 };
  }
  if (state.score2 >= KO_SCORE) {
    return { ended: true, roundWinner: 2 };
  }
  if (state.roundTimer <= 0) {
    // Decision by points; tie goes to player 1 (host advantage, rare edge case)
    const winner = state.score1 >= state.score2 ? 1 : 2;
    return { ended: true, roundWinner: winner };
  }
  return { ended: false, roundWinner: 0 };
}

/**
 * Advance to the next round or match over.
 * @param {object} state
 * @param {number} roundWinner - 1 or 2
 * @returns {object}
 */
export function advanceRound(state, roundWinner) {
  const rw1 = state.roundWins1 + (roundWinner === 1 ? 1 : 0);
  const rw2 = state.roundWins2 + (roundWinner === 2 ? 1 : 0);

  const matchOver = rw1 >= ROUNDS_TO_WIN || rw2 >= ROUNDS_TO_WIN;

  return {
    ...state,
    roundWins1: rw1,
    roundWins2: rw2,
    phase: matchOver ? PHASE.MATCH_OVER : PHASE.ROUND_OVER,
    koPlayer: state.score1 >= KO_SCORE ? 2 : state.score2 >= KO_SCORE ? 1 : 0,
  };
}

/**
 * Reset state for a new round (keep roundWins and round counter).
 * @param {object} state
 * @returns {object}
 */
export function resetForNewRound(state) {
  return {
    ...state,
    b1x: P1_SPAWN_X,
    b1y: P1_SPAWN_Y,
    b1dir: 0,
    b1punchState: PUNCH_STATE.IDLE,
    b1punchTimer: 0,
    b1cooldownTimer: 0,
    b2x: P2_SPAWN_X,
    b2y: P2_SPAWN_Y,
    b2dir: 4,
    b2punchState: PUNCH_STATE.IDLE,
    b2punchTimer: 0,
    b2cooldownTimer: 0,
    score1: 0,
    score2: 0,
    phase: PHASE.WAITING,
    countdown: 0,
    roundTimer: ROUND_DURATION,
    lastHitPlayer: 0,
    lastHitPoints: 0,
    koPlayer: 0,
    round: state.round + 1,
  };
}
