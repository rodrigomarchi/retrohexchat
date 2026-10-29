/**
 * Pure physics and game logic for Hex Outlaw.
 * All functions are pure — no side effects, no DOM, no network.
 * @module games/hex_outlaw_physics
 */

import { BULLET_SPEED_X, PHASE, GAME_MODE } from "./protocol.js";
import { closeRound, pointsReached } from "../core/rounds.js";

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
// The bullet speed is part of the wire format, so the protocol owns it.
export { BULLET_SPEED_X };
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

/**
 * A bullet's height and climb after a step that moved it to `y`: the first
 * time it reaches the ceiling or the floor it turns back; after that it does
 * not bounce again.
 * @param {number} y
 * @param {number} vy
 * @param {boolean} bounced
 * @returns {{ y: number, vy: number, bounced: boolean }}
 */
export function ricochet(y, vy, bounced) {
  if (bounced || vy === 0) return { y, vy, bounced };
  if (y - BULLET_RADIUS <= ARENA_TOP) {
    return { y: ARENA_TOP + BULLET_RADIUS, vy: -vy, bounced: true };
  }
  if (y + BULLET_RADIUS >= ARENA_BOTTOM) {
    return { y: ARENA_BOTTOM - BULLET_RADIUS, vy: -vy, bounced: true };
  }
  return { y, vy, bounced };
}

/**
 * Whether a bullet at (x, y) has left the street: past either side, or —
 * once it has used its one bounce — past the ceiling or the floor.
 * @param {number} x
 * @param {number} y
 * @param {boolean} bounced
 * @returns {boolean}
 */
export function bulletLeftArena(x, y, bounced) {
  if (x < ARENA_LEFT - BULLET_RADIUS || x > ARENA_RIGHT + BULLET_RADIUS) return true;
  return bounced && (y - BULLET_RADIUS < ARENA_TOP || y + BULLET_RADIUS > ARENA_BOTTOM);
}

function _tickBullet(state, prefix) {
  if (!state[`${prefix}active`]) return state;

  const x = state[`${prefix}x`] + state[`${prefix}vx`];
  const { y, vy, bounced } = ricochet(
    state[`${prefix}y`] + state[`${prefix}vy`],
    state[`${prefix}vy`],
    state[`${prefix}bounced`],
  );

  if (bulletLeftArena(x, y, bounced)) {
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
  for (const prefix of ["p1", "p2"]) {
    const timer = s[`${prefix}shootTimer`];
    if (timer > 0) {
      s = { ...s, [`${prefix}shootTimer`]: timer - 1, [`${prefix}shooting`]: timer - 1 > 0 };
    }
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
 * Whether a bullet (a circle) at (bx, by) touches a rectangle.
 * @param {number} bx
 * @param {number} by
 * @param {{ x: number, y: number, w: number, h: number }} rect
 * @returns {boolean}
 */
export function bulletHitsRect(bx, by, rect) {
  const closestX = Math.max(rect.x, Math.min(rect.x + rect.w, bx));
  const closestY = Math.max(rect.y, Math.min(rect.y + rect.h, by));
  const dx = bx - closestX;
  const dy = by - closestY;
  return dx * dx + dy * dy <= BULLET_RADIUS * BULLET_RADIUS;
}

/**
 * Whether a bullet at (bx, by) hits the gunslinger standing at (gx, gy).
 * @param {number} bx
 * @param {number} by
 * @param {number} gx
 * @param {number} gy
 * @returns {boolean}
 */
export function bulletHitsGunslinger(bx, by, gx, gy) {
  const w = GUNSLINGER_HIT_W;
  const h = GUNSLINGER_HIT_H;
  return bulletHitsRect(bx, by, { x: gx - w / 2, y: gy - h / 2, w, h });
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
  return pointsReached(state, SCORE_TO_WIN);
}

/**
 * Advance to the next round or match over.
 * @param {object} state
 * @param {number} roundWinner - 1 or 2
 * @returns {object}
 */
export function advanceRound(state, roundWinner) {
  return closeRound(state, roundWinner, ROUNDS_TO_WIN, PHASE);
}

/**
 * One frame of the duel on the host. While the street is frozen after a hit
 * only the freeze and the stagecoach move. Otherwise both gunslingers move,
 * a shot goes on the press (not while the key is held) at the shooter's aim,
 * the stagecoach and the bullets move, and a hit either ends the round or
 * freezes the street.
 *
 * `pressed` is whether each fire key was already down last frame; the next
 * frame's comes back beside the state. `aimUp` is each shooter's ricochet aim
 * for this frame's shot. `events` says what the frame did, for the sounds and
 * sparks: the players who fired, the bullets that ricocheted, the gunslinger
 * hit and where, whether a bullet struck the obstacle, and whether the round
 * is over.
 * @param {object} state
 * @param {{ 1: object, 2: object }} inputs - each player's held inputs
 * @param {{ 1: boolean, 2: boolean }} pressed
 * @param {{ 1: boolean, 2: boolean }} aimUp
 * @returns {{
 *   state: object,
 *   pressed: { 1: boolean, 2: boolean },
 *   paused: boolean,
 *   events: {
 *     fired: number[],
 *     ricochets: number,
 *     hit: { player: number, x: number, y: number } | null,
 *     obstacleHit: boolean,
 *     roundOver: boolean,
 *   },
 * }}
 */
export function stepTick(state, inputs, pressed, aimUp) {
  const events = { fired: [], ricochets: 0, hit: null, obstacleHit: false, roundOver: false };
  let s = { ...state, lastHitPlayer: 0 };
  if (s.phase === PHASE.HIT_PAUSE) {
    return { state: tickObstacle(tickHitPause(s)), pressed, paused: true, events };
  }

  for (const player of [1, 2]) {
    const own = inputs[player];
    const dy = (own.down ? 1 : 0) - (own.up ? 1 : 0);
    const dx = (own.right ? 1 : 0) - (own.left ? 1 : 0);
    if (dy !== 0 || dx !== 0) s = moveGunslinger(s, player, dy, dx);
  }

  const nextPressed = { ...pressed };
  for (const player of [1, 2]) {
    if (inputs[player].fire && !pressed[player]) {
      const before = s;
      s = fireBullet(s, player, aimUp[player]);
      if (s !== before) events.fired.push(player);
    }
    nextPressed[player] = inputs[player].fire;
  }

  s = tickObstacle(s);
  const bounced = { b1: s.b1bounced, b2: s.b2bounced };
  s = tickBullets(s);
  for (const bullet of ["b1", "b2"]) {
    if (!bounced[bullet] && s[`${bullet}bounced`]) events.ricochets++;
  }

  const collisions = checkBulletCollisions(s);
  s = collisions.state;
  events.obstacleHit = collisions.obsHit;
  if (collisions.p1Hit || collisions.p2Hit) {
    const player = collisions.p2Hit ? 2 : 1;
    events.hit = { player, x: s[`p${player}x`], y: s[`p${player}y`] };
    const { ended, roundWinner } = checkRoundEnd(s);
    events.roundOver = ended;
    s = ended ? advanceRound(s, roundWinner) : enterHitPause(s);
  }

  return { state: s, pressed: nextPressed, paused: false, events };
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
