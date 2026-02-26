/**
 * Hex Hockey — Pure physics / game-logic functions.
 *
 * Every exported function is pure: (state, inputs) → newState.
 * No DOM, no canvas, no audio — only data transformations.
 */

import { PHASE, GAME_MODE, EVENT } from "./protocol.js";

// ── Canvas & layout constants ──────────────────────────────────
export const CANVAS_W = 640;
export const CANVAS_H = 480;

// ── Rink geometry ──────────────────────────────────────────────
export const RINK_PAD = 20; // padding from canvas edge to rink walls
export const RINK_LEFT = RINK_PAD;
export const RINK_RIGHT = CANVAS_W - RINK_PAD;
export const RINK_TOP = 50; // leave room for HUD
export const RINK_BOTTOM = CANVAS_H - RINK_PAD;
export const RINK_W = RINK_RIGHT - RINK_LEFT;
export const RINK_H = RINK_BOTTOM - RINK_TOP;
export const RINK_CX = (RINK_LEFT + RINK_RIGHT) / 2;
export const RINK_CY = (RINK_TOP + RINK_BOTTOM) / 2;

// Goal dimensions (openings on left/right walls)
export const GOAL_DEPTH = 18; // how deep the goal pocket extends beyond rink wall
export const GOAL_HEIGHT = Math.round(RINK_H * 0.3); // ~30% of rink height
export const GOAL_TOP = RINK_CY - GOAL_HEIGHT / 2;
export const GOAL_BOTTOM = RINK_CY + GOAL_HEIGHT / 2;

// Goal line positions (inside edges where puck must cross)
export const GOAL_LINE_LEFT = RINK_LEFT;
export const GOAL_LINE_RIGHT = RINK_RIGHT;

// ── Entity sizes ───────────────────────────────────────────────
export const PLAYER_W = 8;
export const PLAYER_H = 8;
export const GOALIE_W = 12;
export const GOALIE_H = 8;
export const PUCK_R = 3; // puck radius

// ── Player movement ────────────────────────────────────────────
const PLAYER_SPEED = 2.5;
const DIAGONAL_FACTOR = Math.SQRT1_2; // ~0.707

// ── Goalie AI ──────────────────────────────────────────────────
const GOALIE_MAX_SPEED = PLAYER_SPEED * 0.7;
const GOALIE_LERP_FAR = 0.04; // smoothing when puck is far
const GOALIE_LERP_NEAR = 0.08; // smoothing when puck is close
const GOALIE_NEAR_DIST = 200; // px threshold for "near"
const GOALIE_X_OFFSET = 30; // distance from goal line into the rink

// ── Puck physics ───────────────────────────────────────────────
const PUCK_FRICTION = 0.997;
const PUCK_SPEED_CAP = 8;
const PUCK_STUCK_THRESHOLD = 0.3;
const PUCK_STUCK_FRAMES = 300; // ~5 seconds at 60fps

// ── Shot / capture / tackle ────────────────────────────────────
const SHOT_SPEED_BASE = 5;
const CAPTURE_DIST = 10;
const TACKLE_RANGE = 20;
const STUN_DURATION = 18; // frames (~300ms at 60fps)
const TACKLE_SUCCESS_CLASSIC = 0.6;
const TACKLE_SUCCESS_BLITZ = 0.8;

// ── Timing ─────────────────────────────────────────────────────
const PERIOD_DURATION_CLASSIC = 120 * 60; // 2 min in frames
const PERIOD_DURATION_BLITZ = 180 * 60; // 3 min in frames
const GOAL_CELEBRATION_FRAMES = 120; // 2 seconds
const PERIOD_BREAK_FRAMES = 180; // 3 seconds
const COUNTDOWN_TICKS = 3; // 3-2-1-GO

// ── Showdown mode ──────────────────────────────────────────────
const SHOWDOWN_TARGET = 5; // first to 5 goals
const SHOWDOWN_SPEED_BUMP = 0.5; // puck speed increase per goal scored

// ── Stick offset for puck carry ────────────────────────────────
const STICK_OFFSET = 8; // puck distance from player center when carrying

// ── 8-direction vectors (normalized) ───────────────────────────
// Directions: 0=right, 1=down-right, 2=down, 3=down-left,
//             4=left, 5=up-left, 6=up, 7=up-right
const DIR_VX = [1, DIAGONAL_FACTOR, 0, -DIAGONAL_FACTOR, -1, -DIAGONAL_FACTOR, 0, DIAGONAL_FACTOR];
const DIR_VY = [0, DIAGONAL_FACTOR, 1, DIAGONAL_FACTOR, 0, -DIAGONAL_FACTOR, -1, -DIAGONAL_FACTOR];

// ── Center circle ──────────────────────────────────────────────
export const CENTER_CIRCLE_R = 40;

// ── Corner radius (visual only) ────────────────────────────────
export const CORNER_R = 20;

/**
 * Resolve direction index (0-7) from dx, dy inputs.
 * Returns -1 if no input.
 */
function resolveDirection(left, right, up, down) {
  const dx = (right ? 1 : 0) - (left ? 1 : 0);
  const dy = (down ? 1 : 0) - (up ? 1 : 0);
  if (dx === 0 && dy === 0) return -1;
  if (dx === 1 && dy === 0) return 0;
  if (dx === 1 && dy === 1) return 1;
  if (dx === 0 && dy === 1) return 2;
  if (dx === -1 && dy === 1) return 3;
  if (dx === -1 && dy === 0) return 4;
  if (dx === -1 && dy === -1) return 5;
  if (dx === 0 && dy === -1) return 6;
  if (dx === 1 && dy === -1) return 7;
  return -1;
}

/**
 * Get shot speed for current mode and state.
 */
function getShotSpeed(mode, totalGoals) {
  let base = SHOT_SPEED_BASE;
  if (mode === GAME_MODE.BLITZ) base *= 1.25;
  if (mode === GAME_MODE.SHOWDOWN) base += SHOWDOWN_SPEED_BUMP * totalGoals;
  return Math.min(base, PUCK_SPEED_CAP);
}

/**
 * Get tackle success rate for mode.
 */
function getTackleChance(mode) {
  return mode === GAME_MODE.BLITZ ? TACKLE_SUCCESS_BLITZ : TACKLE_SUCCESS_CLASSIC;
}

/**
 * Get period duration in frames for mode.
 */
function getPeriodDuration(mode) {
  if (mode === GAME_MODE.SHOWDOWN) return 0; // no timer
  return mode === GAME_MODE.BLITZ ? PERIOD_DURATION_BLITZ : PERIOD_DURATION_CLASSIC;
}

/**
 * Get max periods for mode.
 */
function getMaxPeriods(mode) {
  if (mode === GAME_MODE.BLITZ) return 1;
  if (mode === GAME_MODE.SHOWDOWN) return 1; // unlimited, but period stays 1
  return 3;
}

// ── State creation ─────────────────────────────────────────────

/**
 * Create the initial game state.
 * @param {number} mode - GAME_MODE enum value
 * @returns {object} Full game state
 */
export function createInitialState(mode) {
  const state = {
    phase: PHASE.WAITING,
    mode,
    eventFlags: 0,

    // Field players
    p1: {
      x: RINK_CX - 60,
      y: RINK_CY,
      facing: 0, // 0-7 direction
      hasPuck: false,
      stunTimer: 0,
    },
    p2: {
      x: RINK_CX + 60,
      y: RINK_CY,
      facing: 4, // facing left
      hasPuck: false,
      stunTimer: 0,
    },

    // Goalies (auto-controlled)
    g1: { y: RINK_CY },
    g2: { y: RINK_CY },

    // Puck
    puck: {
      x: RINK_CX,
      y: RINK_CY,
      vx: 0,
      vy: 0,
      possessedBy: 0, // 0=none, 1=p1, 2=p2
    },

    // Scoring
    scoreP1: 0,
    scoreP2: 0,
    period: 1,
    timerFrames: getPeriodDuration(mode),

    // Flow control
    countdownValue: COUNTDOWN_TICKS,
    countdownFrames: 0,
    celebrationFrames: 0,
    periodBreakFrames: 0,
    puckStuckFrames: 0,

    // Side tracking (swap each period)
    // false = P1 on left, P2 on right (default)
    // true = P1 on right, P2 on left
    sidesSwapped: false,

    // Frame counter
    frameCount: 0,
  };

  return state;
}

/**
 * Reset positions for a face-off.
 * @param {object} state
 * @param {string|null} lastScoredBy - "p1" or "p2" (puck goes to the team that was scored on)
 */
export function resetForFaceoff(state, _lastScoredBy) {
  const leftSide = state.sidesSwapped;

  // P1 position: on their half of center
  const p1OffsetX = leftSide ? 60 : -60;
  state.p1.x = RINK_CX + p1OffsetX;
  state.p1.y = RINK_CY;
  state.p1.facing = leftSide ? 4 : 0; // face toward center
  state.p1.hasPuck = false;
  state.p1.stunTimer = 0;

  // P2 position: on their half of center
  const p2OffsetX = leftSide ? -60 : 60;
  state.p2.x = RINK_CX + p2OffsetX;
  state.p2.y = RINK_CY;
  state.p2.facing = leftSide ? 0 : 4;
  state.p2.hasPuck = false;
  state.p2.stunTimer = 0;

  // Goalies centered
  state.g1.y = RINK_CY;
  state.g2.y = RINK_CY;

  // Puck at center
  state.puck.x = RINK_CX;
  state.puck.y = RINK_CY;
  state.puck.vx = 0;
  state.puck.vy = 0;
  state.puck.possessedBy = 0;

  state.puckStuckFrames = 0;
}

/**
 * Get the goalie X positions based on side swap state.
 * Returns { g1x, g2x } — P1's goalie X and P2's goalie X.
 */
export function getGoalieXPositions(state) {
  if (state.sidesSwapped) {
    // P1 defends right, P2 defends left
    return {
      g1x: RINK_RIGHT - GOALIE_X_OFFSET,
      g2x: RINK_LEFT + GOALIE_X_OFFSET,
    };
  }
  // Default: P1 defends left, P2 defends right
  return {
    g1x: RINK_LEFT + GOALIE_X_OFFSET,
    g2x: RINK_RIGHT - GOALIE_X_OFFSET,
  };
}

// ── Player update ──────────────────────────────────────────────

/**
 * Update a field player's position and facing.
 * @param {object} state
 * @param {object} inputs - { left, right, up, down, action }
 * @param {boolean} isP1
 */
export function updatePlayer(state, inputs, isP1) {
  const player = isP1 ? state.p1 : state.p2;

  // Can't move while stunned
  if (player.stunTimer > 0) {
    player.stunTimer--;
    return;
  }

  const dir = resolveDirection(inputs.left, inputs.right, inputs.up, inputs.down);

  if (dir >= 0) {
    player.facing = dir;
    const dx = DIR_VX[dir] * PLAYER_SPEED;
    const dy = DIR_VY[dir] * PLAYER_SPEED;

    let newX = player.x + dx;
    let newY = player.y + dy;

    // Clamp to rink bounds (with half-size margin)
    const hw = PLAYER_W / 2;
    const hh = PLAYER_H / 2;
    newX = Math.max(RINK_LEFT + hw, Math.min(RINK_RIGHT - hw, newX));
    newY = Math.max(RINK_TOP + hh, Math.min(RINK_BOTTOM - hh, newY));

    player.x = newX;
    player.y = newY;
  }

  // If carrying puck, update puck position to follow player
  if (player.hasPuck) {
    let px = player.x + DIR_VX[player.facing] * STICK_OFFSET;
    let py = player.y + DIR_VY[player.facing] * STICK_OFFSET;

    // Clamp carried puck within rink bounds (prevent visual clipping through walls)
    px = Math.max(RINK_LEFT + PUCK_R, Math.min(RINK_RIGHT - PUCK_R, px));
    py = Math.max(RINK_TOP + PUCK_R, Math.min(RINK_BOTTOM - PUCK_R, py));

    state.puck.x = px;
    state.puck.y = py;
    state.puck.vx = 0;
    state.puck.vy = 0;
    state.puck.possessedBy = isP1 ? 1 : 2;
  }
}

// ── Goalie AI ──────────────────────────────────────────────────

/**
 * Update goalie position (AI-controlled, follows puck Y).
 * @param {object} state
 * @param {boolean} isG1 - true for goalie 1
 */
export function updateGoalie(state, isG1) {
  const goalie = isG1 ? state.g1 : state.g2;
  const { g1x, g2x } = getGoalieXPositions(state);
  const goalieX = isG1 ? g1x : g2x;

  // Distance from goalie to puck
  const distToPuck = Math.abs(state.puck.x - goalieX);

  // Lerp factor: more responsive when puck is nearby
  const lerp = distToPuck < GOALIE_NEAR_DIST ? GOALIE_LERP_NEAR : GOALIE_LERP_FAR;

  // Target Y: follow puck Y
  const targetY = state.puck.y;

  // Smooth movement toward target
  const diff = targetY - goalie.y;
  let move = diff * lerp;

  // Cap movement speed
  if (Math.abs(move) > GOALIE_MAX_SPEED) {
    move = Math.sign(move) * GOALIE_MAX_SPEED;
  }

  goalie.y += move;

  // Clamp goalie to goal area bounds (can only move within goal opening range + some margin)
  const margin = GOALIE_H;
  goalie.y = Math.max(GOAL_TOP - margin, Math.min(GOAL_BOTTOM + margin, goalie.y));
}

// ── Puck physics ───────────────────────────────────────────────

/**
 * Update free puck physics (friction, walls, speed cap).
 * Only applies when puck is not possessed.
 * @param {object} state
 * @returns {number} event flags for wall bounces
 */
export function updatePuck(state) {
  if (state.puck.possessedBy !== 0) return 0;

  // NaN guard — reset corrupted velocity to zero
  if (Number.isNaN(state.puck.vx)) state.puck.vx = 0;
  if (Number.isNaN(state.puck.vy)) state.puck.vy = 0;

  let events = 0;

  // Apply friction
  state.puck.vx *= PUCK_FRICTION;
  state.puck.vy *= PUCK_FRICTION;

  // Speed cap
  const speed = Math.sqrt(state.puck.vx ** 2 + state.puck.vy ** 2);
  if (speed > PUCK_SPEED_CAP) {
    const scale = PUCK_SPEED_CAP / speed;
    state.puck.vx *= scale;
    state.puck.vy *= scale;
  }

  // Anti-tunneling: for fast puck, use sub-steps
  const steps = speed > 4 ? 3 : 1;
  const svx = state.puck.vx / steps;
  const svy = state.puck.vy / steps;

  for (let i = 0; i < steps; i++) {
    state.puck.x += svx;
    state.puck.y += svy;

    // Wall bounce (top/bottom)
    if (state.puck.y - PUCK_R < RINK_TOP) {
      state.puck.y = RINK_TOP + PUCK_R;
      state.puck.vy = Math.abs(state.puck.vy);
      events |= EVENT.WALL_BOUNCE;
    } else if (state.puck.y + PUCK_R > RINK_BOTTOM) {
      state.puck.y = RINK_BOTTOM - PUCK_R;
      state.puck.vy = -Math.abs(state.puck.vy);
      events |= EVENT.WALL_BOUNCE;
    }

    // Left/right wall bounces (but not in goal opening)
    if (state.puck.x - PUCK_R < RINK_LEFT) {
      if (state.puck.y < GOAL_TOP || state.puck.y > GOAL_BOTTOM) {
        // Hit the wall, not the goal opening — bounce
        state.puck.x = RINK_LEFT + PUCK_R;
        state.puck.vx = Math.abs(state.puck.vx);
        events |= EVENT.WALL_BOUNCE;
      }
    } else if (state.puck.x + PUCK_R > RINK_RIGHT) {
      if (state.puck.y < GOAL_TOP || state.puck.y > GOAL_BOTTOM) {
        state.puck.x = RINK_RIGHT - PUCK_R;
        state.puck.vx = -Math.abs(state.puck.vx);
        events |= EVENT.WALL_BOUNCE;
      }
    }

    // Goal back wall (puck entered goal pocket — will be caught by checkGoal)
    if (state.puck.x < RINK_LEFT - GOAL_DEPTH) {
      state.puck.x = RINK_LEFT - GOAL_DEPTH;
      state.puck.vx = 0;
    } else if (state.puck.x > RINK_RIGHT + GOAL_DEPTH) {
      state.puck.x = RINK_RIGHT + GOAL_DEPTH;
      state.puck.vx = 0;
    }
  }

  // Track stuck puck
  if (speed < PUCK_STUCK_THRESHOLD) {
    state.puckStuckFrames++;
  } else {
    state.puckStuckFrames = 0;
  }

  return events;
}

// ── Capture ────────────────────────────────────────────────────

/**
 * Check if a field player captures the free puck.
 * @param {object} state
 * @returns {number} event flags
 */
export function checkCapture(state) {
  if (state.puck.possessedBy !== 0) return 0;

  const players = [
    { player: state.p1, id: 1 },
    { player: state.p2, id: 2 },
  ];

  for (const { player, id } of players) {
    if (player.stunTimer > 0) continue;

    const dx = player.x - state.puck.x;
    const dy = player.y - state.puck.y;
    const dist = Math.sqrt(dx * dx + dy * dy);

    if (dist < CAPTURE_DIST) {
      player.hasPuck = true;
      state.puck.possessedBy = id;
      state.puck.vx = 0;
      state.puck.vy = 0;
      state.puckStuckFrames = 0;
      return EVENT.CAPTURE;
    }
  }

  return 0;
}

// ── Goalie block ───────────────────────────────────────────────

/**
 * Check if a goalie blocks the puck (when puck is free and moving).
 * @param {object} state
 * @returns {number} event flags
 */
export function checkGoalieBlock(state) {
  if (state.puck.possessedBy !== 0) return 0;

  const speed = Math.sqrt(state.puck.vx ** 2 + state.puck.vy ** 2);
  if (speed < 0.5) return 0; // puck too slow to need blocking

  const { g1x, g2x } = getGoalieXPositions(state);
  const goalies = [
    { y: state.g1.y, x: g1x },
    { y: state.g2.y, x: g2x },
  ];

  for (const goalie of goalies) {
    const dx = state.puck.x - goalie.x;
    const dy = state.puck.y - goalie.y;

    // Check if puck is within goalie's hitbox
    if (Math.abs(dx) < GOALIE_W / 2 + PUCK_R && Math.abs(dy) < GOALIE_H / 2 + PUCK_R) {
      // Reflect puck away from goalie
      if (Math.abs(dx) > Math.abs(dy)) {
        state.puck.vx = -state.puck.vx * 0.8;
      } else {
        state.puck.vy = -state.puck.vy * 0.8;
      }

      // Push puck out of goalie
      const pushDist = GOALIE_W / 2 + PUCK_R + 2;
      if (Math.abs(dx) > Math.abs(dy)) {
        state.puck.x = goalie.x + Math.sign(dx) * pushDist;
      } else {
        state.puck.y = goalie.y + Math.sign(dy) * (GOALIE_H / 2 + PUCK_R + 2);
      }

      return EVENT.GOALIE_BLOCK;
    }
  }

  return 0;
}

// ── Shoot ──────────────────────────────────────────────────────

/**
 * Handle player shooting the puck.
 * @param {object} state
 * @param {boolean} isP1
 * @returns {number} event flags
 */
export function handleShoot(state, isP1) {
  const player = isP1 ? state.p1 : state.p2;

  if (!player.hasPuck) return 0;
  if (player.stunTimer > 0) return 0;

  const totalGoals = state.scoreP1 + state.scoreP2;
  const shotSpeed = getShotSpeed(state.mode, totalGoals);

  player.hasPuck = false;
  state.puck.possessedBy = 0;
  state.puck.vx = DIR_VX[player.facing] * shotSpeed;
  state.puck.vy = DIR_VY[player.facing] * shotSpeed;

  // Offset puck slightly ahead of player to avoid immediate recapture
  state.puck.x = player.x + DIR_VX[player.facing] * (STICK_OFFSET + 4);
  state.puck.y = player.y + DIR_VY[player.facing] * (STICK_OFFSET + 4);

  return EVENT.SHOT;
}

// ── Tackle ─────────────────────────────────────────────────────

/**
 * Handle tackle attempt.
 * @param {object} state
 * @param {boolean} isP1 - attacking player
 * @returns {number} event flags
 */
export function handleTackle(state, isP1) {
  const attacker = isP1 ? state.p1 : state.p2;
  const defender = isP1 ? state.p2 : state.p1;

  // Can't tackle if we have the puck or are stunned
  if (attacker.hasPuck) return 0;
  if (attacker.stunTimer > 0) return 0;
  // Can only tackle the player who has the puck
  if (!defender.hasPuck) return 0;

  // Check distance
  const dx = attacker.x - defender.x;
  const dy = attacker.y - defender.y;
  const dist = Math.sqrt(dx * dx + dy * dy);

  if (dist > TACKLE_RANGE) return 0;

  const chance = getTackleChance(state.mode);

  if (Math.random() < chance) {
    // Tackle success — free the puck
    defender.hasPuck = false;
    state.puck.possessedBy = 0;
    // Give puck a small velocity away from defender
    const angle = Math.atan2(dy, dx);
    state.puck.vx = -Math.cos(angle) * 2;
    state.puck.vy = -Math.sin(angle) * 2;
    state.puckStuckFrames = 0;
    return EVENT.TACKLE_SUCCESS;
  }

  // Tackle failed — stun the attacker
  attacker.stunTimer = STUN_DURATION;
  return EVENT.TACKLE_FAIL;
}

// ── Goal detection ─────────────────────────────────────────────

/**
 * Check if a goal was scored.
 * @param {object} state
 * @returns {string|null} "p1" or "p2" (who scored), or null
 */
export function checkGoal(state) {
  if (state.puck.possessedBy !== 0) return null;

  const px = state.puck.x;
  const py = state.puck.y;

  // Puck must be within goal opening vertically
  if (py < GOAL_TOP || py > GOAL_BOTTOM) return null;

  // Check left goal (past left goal line)
  if (px < GOAL_LINE_LEFT - PUCK_R) {
    // Who defends left?
    if (state.sidesSwapped) {
      // P2 defends left → P1 scored
      return "p1";
    }
    // P1 defends left → P2 scored
    return "p2";
  }

  // Check right goal (past right goal line)
  if (px > GOAL_LINE_RIGHT + PUCK_R) {
    if (state.sidesSwapped) {
      // P1 defends right → P2 scored
      return "p2";
    }
    // P2 defends right → P1 scored
    return "p1";
  }

  return null;
}

/**
 * Check if puck has been stuck too long.
 * @param {object} state
 * @returns {boolean}
 */
export function checkPuckStuck(state) {
  return state.puckStuckFrames >= PUCK_STUCK_FRAMES;
}

// ── Period / game flow ─────────────────────────────────────────

/**
 * Advance to next period (or sudden death / finished).
 * @param {object} state
 * @returns {number} event flags
 */
export function advancePeriod(state) {
  const maxPeriods = getMaxPeriods(state.mode);

  if (state.mode === GAME_MODE.SHOWDOWN) {
    // Showdown has no periods — game continues until target score
    return 0;
  }

  if (state.period >= maxPeriods) {
    // Check for tie → sudden death
    if (state.scoreP1 === state.scoreP2) {
      state.phase = PHASE.FACE_OFF;
      state.period = maxPeriods + 1;
      state.timerFrames = 0; // no timer in sudden death
      state.sidesSwapped = !state.sidesSwapped;
      resetForFaceoff(state, null);
      return EVENT.SUDDEN_DEATH;
    }
    // Game over
    state.phase = PHASE.FINISHED;
    return EVENT.PERIOD_END;
  }

  // Next period
  state.period++;
  state.timerFrames = getPeriodDuration(state.mode);
  state.sidesSwapped = !state.sidesSwapped;
  resetForFaceoff(state, null);
  state.phase = PHASE.PERIOD_BREAK;
  state.periodBreakFrames = PERIOD_BREAK_FRAMES;
  return EVENT.PERIOD_END;
}

/**
 * Check if game is over (Showdown mode: first to target).
 * @param {object} state
 * @returns {boolean}
 */
export function checkShowdownWin(state) {
  if (state.mode !== GAME_MODE.SHOWDOWN) return false;
  return state.scoreP1 >= SHOWDOWN_TARGET || state.scoreP2 >= SHOWDOWN_TARGET;
}

/**
 * Determine the winner.
 * @param {object} state
 * @returns {object} { winner: "p1"|"p2"|"draw", scoreP1, scoreP2 }
 */
export function determineWinner(state) {
  let winner = "draw";
  if (state.scoreP1 > state.scoreP2) winner = "p1";
  else if (state.scoreP2 > state.scoreP1) winner = "p2";

  return {
    winner,
    score_p1: state.scoreP1,
    score_p2: state.scoreP2,
    periods: state.period,
    mode: state.mode,
  };
}

// ── Countdown ──────────────────────────────────────────────────
export const COUNTDOWN_FRAME_INTERVAL = 60; // frames per countdown tick

// ── Pack / Unpack for network sync (used by protocol.js) ──────

/**
 * Pack state into a flat object for encoding.
 * @param {object} state
 * @returns {object}
 */
export function packState(state) {
  return {
    phase: state.phase,
    mode: state.mode,
    eventFlags: state.eventFlags,
    p1x: Math.round(state.p1.x),
    p1y: Math.round(state.p1.y),
    p1facing: state.p1.facing,
    p1hasPuck: state.p1.hasPuck,
    p1stunned: state.p1.stunTimer > 0,
    p2x: Math.round(state.p2.x),
    p2y: Math.round(state.p2.y),
    p2facing: state.p2.facing,
    p2hasPuck: state.p2.hasPuck,
    p2stunned: state.p2.stunTimer > 0,
    g1y: Math.round(state.g1.y),
    g2y: Math.round(state.g2.y),
    puckX: Math.round(state.puck.x),
    puckY: Math.round(state.puck.y),
    puckVx: state.puck.vx,
    puckVy: state.puck.vy,
    puckPossessedBy: state.puck.possessedBy,
    scoreP1: state.scoreP1,
    scoreP2: state.scoreP2,
    period: state.period,
    timerFrames: state.timerFrames,
    countdownValue: state.countdownValue,
    stunTimerP1: state.p1.stunTimer,
    stunTimerP2: state.p2.stunTimer,
    sidesSwapped: state.sidesSwapped,
  };
}

/**
 * Unpack flat object into full state (for peer rendering).
 * @param {object} packed
 * @returns {object} State suitable for renderer
 */
export function unpackState(packed) {
  return {
    phase: packed.phase,
    mode: packed.mode,
    eventFlags: packed.eventFlags,
    p1: {
      x: packed.p1x,
      y: packed.p1y,
      facing: packed.p1facing,
      hasPuck: packed.p1hasPuck,
      stunTimer: packed.stunTimerP1,
    },
    p2: {
      x: packed.p2x,
      y: packed.p2y,
      facing: packed.p2facing,
      hasPuck: packed.p2hasPuck,
      stunTimer: packed.stunTimerP2,
    },
    g1: { y: packed.g1y },
    g2: { y: packed.g2y },
    puck: {
      x: packed.puckX,
      y: packed.puckY,
      vx: packed.puckVx,
      vy: packed.puckVy,
      possessedBy: packed.puckPossessedBy,
    },
    scoreP1: packed.scoreP1,
    scoreP2: packed.scoreP2,
    period: packed.period,
    timerFrames: packed.timerFrames,
    countdownValue: packed.countdownValue,
    sidesSwapped: packed.sidesSwapped,
    frameCount: 0,
  };
}

// ── Exported constants for renderer ────────────────────────────
export { GOAL_CELEBRATION_FRAMES, PERIOD_BREAK_FRAMES, STUN_DURATION, SHOWDOWN_TARGET };
