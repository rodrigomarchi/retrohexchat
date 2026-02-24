/**
 * Pure physics and game logic for Hex Outlaw.
 * All functions are pure — no side effects, no DOM, no network.
 * @module games/hex_outlaw_physics
 */

import { PHASE, GAME_MODE } from "./protocol.js";

// --- Canvas ---
export const CANVAS_W = 640;
export const CANVAS_H = 480;

// --- Arena boundaries ---
export const ARENA_TOP = 40;
export const ARENA_BOTTOM = CANVAS_H - 20;
export const ARENA_LEFT = 20;
export const ARENA_RIGHT = CANVAS_W - 20;
export const ARENA_W = ARENA_RIGHT - ARENA_LEFT;
export const ARENA_H = ARENA_BOTTOM - ARENA_TOP;

// --- Gunslinger ---
export const GUNSLINGER_W = 16;
export const GUNSLINGER_H = 24;
export const GUNSLINGER_SPEED = 2.5;
export const GUNSLINGER_SPEED_H = 2.0; // Horizontal speed (No Man's Land only)
export const GUNSLINGER_HIT_W = 10; // Hit box width
export const GUNSLINGER_HIT_H = 20; // Hit box height

// --- Spawn positions ---
export const P1_SPAWN_X = ARENA_LEFT + 60;
export const P2_SPAWN_X = ARENA_RIGHT - 60;
const SPAWN_Y = Math.round((ARENA_TOP + ARENA_BOTTOM) / 2);

// --- No Man's Land zone limits ---
export const NML_P1_MAX_X = ARENA_LEFT + Math.round(ARENA_W * 0.3);
export const NML_P2_MIN_X = ARENA_RIGHT - Math.round(ARENA_W * 0.3);

// --- Bullet ---
export const BULLET_SPEED_X = 8; // px/frame (~480px/s at 60fps, crosses in ~75 frames ≈ 1.25s)
export const BULLET_RADIUS = 3;
export const RICOCHET_ANGLE = Math.PI / 6; // 30 degrees

// --- Obstacles ---
// Cactus (Quick Draw)
export const CACTUS_X = Math.round(CANVAS_W / 2);
export const CACTUS_W = Math.round(ARENA_W * 0.06);
export const CACTUS_H = Math.round(ARENA_H * 0.4);

// Wall (Ricochet Alley)
export const WALL_X = Math.round(CANVAS_W / 2);
export const WALL_W = Math.round(ARENA_W * 0.1);
export const WALL_H = Math.round(ARENA_H * 0.6);

// Stagecoach
export const STAGE_W = Math.round(ARENA_W * 0.12);
export const STAGE_H = Math.round(ARENA_H * 0.3);
export const STAGE_SPEED = 1.5;

// --- Scoring ---
export const SCORE_TO_WIN = 10;
export const MAX_ROUNDS = 3;
export const ROUNDS_TO_WIN = 2;
export const HIT_PAUSE_DURATION = 90; // frames (~1.5s at 60fps)

// --- Shooting animation ---
export const SHOOT_ANIM_FRAMES = 12;

/**
 * Get obstacle center Y for fixed obstacles.
 * @returns {number}
 */
function obstacleCenter() {
  return Math.round((ARENA_TOP + ARENA_BOTTOM) / 2);
}

/**
 * Create initial game state.
 * @param {number} gameMode - GAME_MODE enum value
 * @returns {object}
 */
export function createInitialState(gameMode) {
  const mode = gameMode !== undefined ? gameMode : GAME_MODE.QUICK_DRAW;
  return {
    // Gunslinger 1 (P1 — green, left side)
    p1x: P1_SPAWN_X,
    p1y: SPAWN_Y,
    p1shooting: false,
    p1shootTimer: 0,

    // Gunslinger 2 (P2 — cyan, right side)
    p2x: P2_SPAWN_X,
    p2y: SPAWN_Y,
    p2shooting: false,
    p2shootTimer: 0,

    // Bullet 1 (P1's bullet)
    b1x: 0,
    b1y: 0,
    b1vx: 0,
    b1vy: 0,
    b1active: false,
    b1bounced: false,

    // Bullet 2 (P2's bullet)
    b2x: 0,
    b2y: 0,
    b2vx: 0,
    b2vy: 0,
    b2active: false,
    b2bounced: false,

    // Obstacle
    obsY: obstacleCenter(),
    obsDir: 1, // 1 = moving down, -1 = moving up (stagecoach only)

    // Scores
    score1: 0,
    score2: 0,

    // Meta
    phase: PHASE.WAITING,
    countdown: 0,
    round: 1,
    roundWins1: 0,
    roundWins2: 0,
    gameMode: mode,
    hitPauseTimer: 0,

    // Events (cleared each frame)
    lastHitPlayer: 0,
  };
}

/**
 * Move gunslinger vertically (and horizontally in No Man's Land).
 * @param {object} state
 * @param {number} player - 1 or 2
 * @param {number} dy - -1, 0, or 1
 * @param {number} dx - -1, 0, or 1 (only used in No Man's Land)
 * @returns {object}
 */
export function moveGunslinger(state, player, dy, dx) {
  const prefix = player === 1 ? "p1" : "p2";

  let newY = state[`${prefix}y`] + dy * GUNSLINGER_SPEED;
  newY = Math.max(ARENA_TOP + GUNSLINGER_H / 2, Math.min(ARENA_BOTTOM - GUNSLINGER_H / 2, newY));

  let newX = state[`${prefix}x`];
  if (state.gameMode === GAME_MODE.NO_MANS_LAND && dx !== 0) {
    newX += dx * GUNSLINGER_SPEED_H;
    if (player === 1) {
      newX = Math.max(ARENA_LEFT + GUNSLINGER_W / 2, Math.min(NML_P1_MAX_X, newX));
    } else {
      newX = Math.max(NML_P2_MIN_X, Math.min(ARENA_RIGHT - GUNSLINGER_W / 2, newX));
    }
  }

  return { ...state, [`${prefix}y`]: newY, [`${prefix}x`]: newX };
}

/**
 * Fire a bullet from the given player.
 * Only fires if the player's bullet is not active.
 * In ricochet mode, bullet travels at an angle (up or down based on aimUp).
 * @param {object} state
 * @param {number} player - 1 or 2
 * @param {boolean} aimUp - true to aim up-diagonal in ricochet mode
 * @returns {object}
 */
export function fireBullet(state, player, aimUp) {
  const prefix = player === 1 ? "p1" : "p2";
  const bPrefix = player === 1 ? "b1" : "b2";

  if (state[`${bPrefix}active`]) return state;

  const gunX = state[`${prefix}x`];
  const gunY = state[`${prefix}y`];

  // Bullet direction: P1 fires right, P2 fires left
  const dirX = player === 1 ? 1 : -1;
  let vx = BULLET_SPEED_X * dirX;
  let vy = 0;

  if (state.gameMode === GAME_MODE.RICOCHET) {
    const angle = RICOCHET_ANGLE;
    vx = BULLET_SPEED_X * Math.cos(angle) * dirX;
    vy = BULLET_SPEED_X * Math.sin(angle) * (aimUp ? -1 : 1);
  }

  // Bullet starts at gun tip (offset from gunslinger center)
  const bulletStartX = gunX + dirX * (GUNSLINGER_W / 2 + BULLET_RADIUS);

  return {
    ...state,
    [`${bPrefix}x`]: bulletStartX,
    [`${bPrefix}y`]: gunY,
    [`${bPrefix}vx`]: vx,
    [`${bPrefix}vy`]: vy,
    [`${bPrefix}active`]: true,
    [`${bPrefix}bounced`]: false,
    [`${prefix}shooting`]: true,
    [`${prefix}shootTimer`]: SHOOT_ANIM_FRAMES,
  };
}

/**
 * Tick bullet positions and handle ricochets.
 * @param {object} state
 * @returns {object}
 */
export function tickBullets(state) {
  let s = state;
  s = _tickBullet(s, "b1");
  s = _tickBullet(s, "b2");
  s = _tickShootTimers(s);
  return s;
}

function _tickBullet(state, prefix) {
  if (!state[`${prefix}active`]) return state;

  const x = state[`${prefix}x`] + state[`${prefix}vx`];
  let y = state[`${prefix}y`] + state[`${prefix}vy`];
  let vy = state[`${prefix}vy`];
  let bounced = state[`${prefix}bounced`];

  // Ricochet off top/bottom walls (max 1 bounce)
  if (!bounced && vy !== 0) {
    if (y - BULLET_RADIUS <= ARENA_TOP) {
      y = ARENA_TOP + BULLET_RADIUS;
      vy = -vy;
      bounced = true;
    } else if (y + BULLET_RADIUS >= ARENA_BOTTOM) {
      y = ARENA_BOTTOM - BULLET_RADIUS;
      vy = -vy;
      bounced = true;
    }
  }

  // Deactivate if out of horizontal bounds
  if (x < ARENA_LEFT - BULLET_RADIUS || x > ARENA_RIGHT + BULLET_RADIUS) {
    return {
      ...state,
      [`${prefix}x`]: x,
      [`${prefix}y`]: y,
      [`${prefix}active`]: false,
    };
  }

  // Deactivate if out of vertical bounds (after max bounces in ricochet)
  if (bounced && (y - BULLET_RADIUS < ARENA_TOP || y + BULLET_RADIUS > ARENA_BOTTOM)) {
    return {
      ...state,
      [`${prefix}x`]: x,
      [`${prefix}y`]: y,
      [`${prefix}active`]: false,
    };
  }

  return {
    ...state,
    [`${prefix}x`]: x,
    [`${prefix}y`]: y,
    [`${prefix}vy`]: vy,
    [`${prefix}bounced`]: bounced,
  };
}

function _tickShootTimers(state) {
  let s = state;
  if (s.p1shootTimer > 0) {
    s = {
      ...s,
      p1shootTimer: s.p1shootTimer - 1,
      p1shooting: s.p1shootTimer - 1 > 0,
    };
  }
  if (s.p2shootTimer > 0) {
    s = {
      ...s,
      p2shootTimer: s.p2shootTimer - 1,
      p2shooting: s.p2shootTimer - 1 > 0,
    };
  }
  return s;
}

/**
 * Get obstacle hitbox for the current game mode and state.
 * @param {object} state
 * @returns {{ x: number, y: number, w: number, h: number }|null}
 */
export function getObstacleRect(state) {
  switch (state.gameMode) {
    case GAME_MODE.QUICK_DRAW:
      return {
        x: CACTUS_X - CACTUS_W / 2,
        y: obstacleCenter() - CACTUS_H / 2,
        w: CACTUS_W,
        h: CACTUS_H,
      };
    case GAME_MODE.RICOCHET:
      return {
        x: WALL_X - WALL_W / 2,
        y: obstacleCenter() - WALL_H / 2,
        w: WALL_W,
        h: WALL_H,
      };
    case GAME_MODE.STAGECOACH:
      return {
        x: Math.round(CANVAS_W / 2) - STAGE_W / 2,
        y: state.obsY - STAGE_H / 2,
        w: STAGE_W,
        h: STAGE_H,
      };
    default:
      return null;
  }
}

/**
 * Check bullet collisions with opponent and obstacle.
 * Returns updated state with scoring and bullet deactivation.
 * @param {object} state
 * @returns {{ state: object, p1Hit: boolean, p2Hit: boolean, obsHit: boolean }}
 */
export function checkBulletCollisions(state) {
  let s = state;
  let p1Hit = false;
  let p2Hit = false;
  let obsHit = false;

  const obsRect = getObstacleRect(s);

  // Check bullet 1 (P1's bullet → can hit P2 or obstacle)
  if (s.b1active) {
    // Check obstacle first
    if (obsRect && bulletHitsRect(s.b1x, s.b1y, obsRect)) {
      s = { ...s, b1active: false };
      obsHit = true;
    }
    // Check P2
    else if (bulletHitsGunslinger(s.b1x, s.b1y, s.p2x, s.p2y)) {
      s = {
        ...s,
        b1active: false,
        score1: s.score1 + 1,
        lastHitPlayer: 1,
      };
      p2Hit = true;
    }
  }

  // Check bullet 2 (P2's bullet → can hit P1 or obstacle)
  if (s.b2active) {
    // Check obstacle first
    if (obsRect && bulletHitsRect(s.b2x, s.b2y, obsRect)) {
      s = { ...s, b2active: false };
      obsHit = obsHit || true;
    }
    // Check P1
    else if (bulletHitsGunslinger(s.b2x, s.b2y, s.p1x, s.p1y)) {
      s = {
        ...s,
        b2active: false,
        score2: s.score2 + 1,
        lastHitPlayer: 2,
      };
      p1Hit = true;
    }
  }

  return { state: s, p1Hit, p2Hit, obsHit };
}

/**
 * Check if a bullet (circle) hits a gunslinger (rect hitbox).
 * @param {number} bx - bullet x
 * @param {number} by - bullet y
 * @param {number} gx - gunslinger center x
 * @param {number} gy - gunslinger center y
 * @returns {boolean}
 */
function bulletHitsGunslinger(bx, by, gx, gy) {
  const halfW = GUNSLINGER_HIT_W / 2;
  const halfH = GUNSLINGER_HIT_H / 2;
  // Closest point on rect to circle center
  const closestX = Math.max(gx - halfW, Math.min(gx + halfW, bx));
  const closestY = Math.max(gy - halfH, Math.min(gy + halfH, by));
  const dx = bx - closestX;
  const dy = by - closestY;
  return dx * dx + dy * dy <= BULLET_RADIUS * BULLET_RADIUS;
}

/**
 * Check if a bullet hits a rectangular obstacle.
 * @param {number} bx - bullet x
 * @param {number} by - bullet y
 * @param {{ x: number, y: number, w: number, h: number }} rect
 * @returns {boolean}
 */
function bulletHitsRect(bx, by, rect) {
  const closestX = Math.max(rect.x, Math.min(rect.x + rect.w, bx));
  const closestY = Math.max(rect.y, Math.min(rect.y + rect.h, by));
  const dx = bx - closestX;
  const dy = by - closestY;
  return dx * dx + dy * dy <= BULLET_RADIUS * BULLET_RADIUS;
}

/**
 * Tick the stagecoach obstacle (moves vertically and bounces).
 * @param {object} state
 * @returns {object}
 */
export function tickObstacle(state) {
  if (state.gameMode !== GAME_MODE.STAGECOACH) return state;

  let y = state.obsY + state.obsDir * STAGE_SPEED;
  let dir = state.obsDir;

  const minY = ARENA_TOP + STAGE_H / 2;
  const maxY = ARENA_BOTTOM - STAGE_H / 2;

  if (y <= minY) {
    y = minY;
    dir = 1;
  } else if (y >= maxY) {
    y = maxY;
    dir = -1;
  }

  return { ...state, obsY: y, obsDir: dir };
}

/**
 * Enter hit pause phase after a player is hit.
 * @param {object} state
 * @returns {object}
 */
export function enterHitPause(state) {
  return {
    ...state,
    phase: PHASE.HIT_PAUSE,
    hitPauseTimer: HIT_PAUSE_DURATION,
    b1active: false,
    b2active: false,
  };
}

/**
 * Tick hit pause timer. Returns to PLAYING and resets positions when done.
 * @param {object} state
 * @returns {object}
 */
export function tickHitPause(state) {
  if (state.phase !== PHASE.HIT_PAUSE) return state;
  if (state.hitPauseTimer > 1) {
    return { ...state, hitPauseTimer: state.hitPauseTimer - 1 };
  }

  // Pause over — reset positions and return to PLAYING
  return {
    ...state,
    phase: PHASE.PLAYING,
    hitPauseTimer: 0,
    p1x: P1_SPAWN_X,
    p1y: SPAWN_Y,
    p2x: P2_SPAWN_X,
    p2y: SPAWN_Y,
    p1shooting: false,
    p1shootTimer: 0,
    p2shooting: false,
    p2shootTimer: 0,
    b1active: false,
    b2active: false,
    lastHitPlayer: 0,
  };
}

/**
 * Check if the round has ended (score reached).
 * @param {object} state
 * @returns {{ ended: boolean, roundWinner: number }}
 */
export function checkRoundEnd(state) {
  if (state.score1 >= SCORE_TO_WIN) {
    return { ended: true, roundWinner: 1 };
  }
  if (state.score2 >= SCORE_TO_WIN) {
    return { ended: true, roundWinner: 2 };
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
    p1x: P1_SPAWN_X,
    p1y: SPAWN_Y,
    p1shooting: false,
    p1shootTimer: 0,
    p2x: P2_SPAWN_X,
    p2y: SPAWN_Y,
    p2shooting: false,
    p2shootTimer: 0,
    b1x: 0,
    b1y: 0,
    b1vx: 0,
    b1vy: 0,
    b1active: false,
    b1bounced: false,
    b2x: 0,
    b2y: 0,
    b2vx: 0,
    b2vy: 0,
    b2active: false,
    b2bounced: false,
    obsY: obstacleCenter(),
    obsDir: 1,
    score1: 0,
    score2: 0,
    phase: PHASE.WAITING,
    countdown: 0,
    hitPauseTimer: 0,
    lastHitPlayer: 0,
    round: state.round + 1,
  };
}
