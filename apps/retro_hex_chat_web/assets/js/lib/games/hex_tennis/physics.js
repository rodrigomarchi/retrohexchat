/**
 * Pure physics functions for Hex Tennis.
 * All functions are stateless: (state) => newState.
 * No side effects, no DOM, no audio.
 * @module games/hex_tennis/physics
 */

import { PHASE, GAME_MODE, ANNOUNCEMENT, OUT_TYPE } from "./protocol.js";

// --- Canvas & Court Constants ---
export const CANVAS_W = 640;
export const CANVAS_H = 480;

export const COURT_LEFT = 50;
export const COURT_RIGHT = 590;
export const COURT_TOP = 40;
export const COURT_BOTTOM = 440;
export const COURT_W = COURT_RIGHT - COURT_LEFT; // 540
export const COURT_H = COURT_BOTTOM - COURT_TOP; // 400
export const COURT_CENTER_X = 320;
export const COURT_CENTER_Y = 240;

// Net
export const NET_Y = 240;
export const NET_HALF_H = 3;
export const NET_HEIGHT_FACTOR = 0.35;

// Service lines
export const SERVICE_LINE_TOP = 160;
export const SERVICE_LINE_BOTTOM = 320;
export const CENTER_LINE_X = 320;

// Player
const PLAYER_W = 24;
const PLAYER_H = 24;
export const PLAYER_SPEED = 3.5;
const PLAYER_HALF_W = PLAYER_W / 2; // 12
const PLAYER_HALF_H = PLAYER_H / 2; // 12

// Hit zone
export const HIT_ZONE_W = 36;
export const HIT_ZONE_H = 36;

// Ball
export const BALL_RADIUS = 4;
export const BALL_INITIAL_SPEED = 5.0;
export const BALL_MAX_SPEED = 9.0;
export const BALL_DECELERATION = 0.02;
export const BALL_MIN_SPEED = 1.5;
const BALL_GRAVITY = 0.015;
// A return leaves the racket this high, and passes at least NET_MARGIN over the net.
const RETURN_HEIGHT = 0.1;
const NET_MARGIN = 0.1;

// Serve
export const SERVE_SPEED = 6.0;
const SERVE_HEIGHT = 0.3;
export const SERVE_TIMEOUT_FRAMES = 600; // 10 seconds at 60fps

// Player movement bounds
const P1_MIN_Y = NET_Y + NET_HALF_H + 10;
const P1_MAX_Y = COURT_BOTTOM - PLAYER_HALF_H;
const P2_MIN_Y = COURT_TOP + PLAYER_HALF_H;
const P2_MAX_Y = NET_Y - NET_HALF_H - 10;
const PLAYER_MIN_X = COURT_LEFT + PLAYER_HALF_W;
const PLAYER_MAX_X = COURT_RIGHT - PLAYER_HALF_W;

/** A tick's event flags, all down: no hit, serve, fault, out, point or call. */
const NO_EVENTS = Object.freeze({
  hitEvent: false,
  serveEvent: false,
  netFault: false,
  outOfBounds: false,
  outType: OUT_TYPE.NONE,
  pointWinner: 0,
  faultEvent: false,
  announcement: ANNOUNCEMENT.NONE,
});

/**
 * Create the initial game state for a given mode.
 * @param {number} gameMode - GAME_MODE enum
 * @returns {object}
 */
export function createInitialState(gameMode) {
  return {
    p1x: COURT_CENTER_X,
    p1y: COURT_BOTTOM - 30,
    p2x: COURT_CENTER_X,
    p2y: COURT_TOP + 30,

    ball: {
      x: COURT_CENTER_X,
      y: COURT_CENTER_Y,
      vx: 0,
      vy: 0,
      speed: 0,
      height: 0,
      heightVel: 0,
      landX: null,
      landY: null,
    },

    p1Points: 0,
    p2Points: 0,
    p1Games: 0,
    p2Games: 0,
    isTiebreak: false,

    server: 1,
    isSecondServe: false,
    totalPointsInGame: 0,

    phase: PHASE.WAITING,
    countdown: 3,

    ...NO_EVENTS,

    lastHitter: 0,
    rallyCount: 0,
    serveTimer: SERVE_TIMEOUT_FRAMES,
    gameMode,
    winner: 0,
  };
}

/**
 * Update a player's position based on inputs.
 * @param {object} state
 * @param {number} player - 1 or 2
 * @param {object} inputs - { up, down, left, right }
 * @returns {object} new state
 */
export function updatePlayer(state, player, inputs) {
  const xKey = player === 1 ? "p1x" : "p2x";
  const yKey = player === 1 ? "p1y" : "p2y";

  let dx = 0;
  let dy = 0;

  if (inputs.up && !inputs.down) dy = -PLAYER_SPEED;
  else if (inputs.down && !inputs.up) dy = PLAYER_SPEED;

  if (inputs.left && !inputs.right) dx = -PLAYER_SPEED;
  else if (inputs.right && !inputs.left) dx = PLAYER_SPEED;

  let nx = state[xKey] + dx;
  let ny = state[yKey] + dy;

  // Clamp X
  nx = Math.max(PLAYER_MIN_X, Math.min(PLAYER_MAX_X, nx));

  // Clamp Y (P1 bottom half, P2 top half)
  if (player === 1) {
    ny = Math.max(P1_MIN_Y, Math.min(P1_MAX_Y, ny));
  } else {
    ny = Math.max(P2_MIN_Y, Math.min(P2_MAX_Y, ny));
  }

  return { ...state, [xKey]: nx, [yKey]: ny };
}

/**
 * Update ball position, velocity, and height.
 * @param {object} state
 * @returns {object} new state
 */
export function updateBall(state) {
  if (state.phase !== PHASE.RALLY) return state;

  const b = state.ball;
  let { x, y, vx, vy, speed, height, heightVel, landX, landY } = b;

  // Move
  x += vx;
  y += vy;

  // Deceleration
  speed = Math.max(speed - BALL_DECELERATION, BALL_MIN_SPEED);
  const mag = Math.sqrt(vx * vx + vy * vy);
  if (mag > 0) {
    const scale = speed / mag;
    vx *= scale;
    vy *= scale;
  }

  // Height arc (parabolic); where it first touches the ground after a shot is where it landed
  height += heightVel;
  heightVel -= BALL_GRAVITY;
  if (height < 0) {
    height = 0;
    heightVel = 0;
    if (!Number.isFinite(landY)) {
      landX = x;
      landY = y;
    }
  }

  return {
    ...state,
    ball: { x, y, vx, vy, speed, height, heightVel, landX, landY },
  };
}

/**
 * Check if the ball is in a player's hit zone. If so, auto-return it.
 * The return angle depends on where the ball contacts the hit zone.
 * @param {object} state
 * @param {number} player - 1 or 2
 * @returns {object} new state
 */
export function checkHitZone(state, player) {
  const px = player === 1 ? state.p1x : state.p2x;
  const py = player === 1 ? state.p1y : state.p2y;
  const b = state.ball;

  // Hit zone bounds
  const zLeft = px - HIT_ZONE_W / 2;
  const zRight = px + HIT_ZONE_W / 2;
  const zTop = py - HIT_ZONE_H / 2;
  const zBottom = py + HIT_ZONE_H / 2;

  // Ball must be inside the zone
  if (b.x < zLeft || b.x > zRight || b.y < zTop || b.y > zBottom) {
    return state;
  }

  // Ball must be on this player's side of the net, clear of it
  const netClear = NET_HALF_H + BALL_RADIUS;
  if (player === 1 ? b.y < NET_Y + netClear : b.y > NET_Y - netClear) return state;

  // Ball must be coming TOWARD this player (not already moving away)
  if (player === 1 && b.vy < 0) return state; // ball going up, away from P1
  if (player === 2 && b.vy > 0) return state; // ball going down, away from P2

  // Relative position in zone: -1 to +1
  const relX = (b.x - px) / (HIT_ZONE_W / 2); // horizontal offset
  const relY = (b.y - py) / (HIT_ZONE_H / 2); // vertical offset

  // Direction: P1 hits upward (-1), P2 hits downward (+1)
  const dir = player === 1 ? -1 : 1;

  // Cross-court angle based on horizontal offset (max 45 degrees)
  const crossAngle = relX * (Math.PI / 4);

  // Force factor based on depth in zone
  // P1: front of zone = closer to net = negative relY → more force
  // P2: front of zone = closer to net = positive relY → more force
  const depthFactor = player === 1 ? 1.0 - relY * 0.3 : 1.0 + relY * 0.3;

  const newSpeed = Math.min(BALL_INITIAL_SPEED + b.speed * 0.3 * depthFactor, BALL_MAX_SPEED);

  const newVx = Math.sin(crossAngle) * newSpeed;
  const newVy = Math.cos(crossAngle) * newSpeed * dir;

  // The arc peaks over the net, so it lands about as deep in the far half as
  // it was hit in this one; a ball met close to the net is struck from high
  // enough to be over it by the time it gets there
  const toNet = Math.abs(NET_Y - b.y);
  const newHeightVel = BALL_GRAVITY * (toNet / Math.abs(newVy));
  const framesToNetBand = Math.max(1, (toNet - netClear) / Math.abs(newVy));
  const heightAtNetBand =
    RETURN_HEIGHT +
    framesToNetBand * newHeightVel -
    (BALL_GRAVITY * framesToNetBand * (framesToNetBand - 1)) / 2;
  const newHeight = RETURN_HEIGHT + Math.max(0, NET_HEIGHT_FACTOR + NET_MARGIN - heightAtNetBand);

  return {
    ...state,
    ball: {
      ...b,
      vx: newVx,
      vy: newVy,
      speed: newSpeed,
      height: newHeight,
      heightVel: newHeightVel,
      landX: null,
      landY: null,
    },
    lastHitter: player,
    hitEvent: true,
    rallyCount: state.rallyCount + 1,
  };
}

/**
 * Check if the ball hits the net.
 * @param {object} state
 * @returns {object} new state
 */
export function checkNetCollision(state) {
  const b = state.ball;

  // Ball must be in the net zone
  if (Math.abs(b.y - NET_Y) > NET_HALF_H + BALL_RADIUS) {
    return state;
  }

  // If ball height is below the net threshold, it hits
  if (b.height < NET_HEIGHT_FACTOR) {
    // Hitter loses the point
    const loser = state.lastHitter;
    const winner = loser === 1 ? 2 : 1;

    return {
      ...state,
      ball: { ...b, vx: 0, vy: 0, speed: 0 },
      netFault: true,
      pointWinner: winner,
    };
  }

  return state;
}

/**
 * Check if the ball is out of bounds.
 * @param {object} state
 * @returns {object} new state
 */
export function checkOutOfBounds(state) {
  const b = state.ball;

  // Dead ball: speed too low and on ground
  if (b.speed < BALL_MIN_SPEED && b.height <= 0 && state.lastHitter > 0) {
    const winner = state.lastHitter === 1 ? 2 : 1;
    return {
      ...state,
      outOfBounds: true,
      outType: OUT_TYPE.DEAD,
      pointWinner: winner,
    };
  }

  const wide = b.x < COURT_LEFT - 10 || b.x > COURT_RIGHT + 10;
  const past = b.height <= 0 && (b.y < COURT_TOP - 20 || b.y > COURT_BOTTOM + 20);

  // Landed in the receiver's half and got past them: the hitter's point —
  // an ace off an unreturned serve, a winner off a rally shot.
  if ((wide || past) && landedIn(state)) {
    if (state.rallyCount === 0) {
      return {
        ...state,
        outOfBounds: true,
        outType: OUT_TYPE.ACE,
        pointWinner: state.lastHitter,
      };
    }
    return { ...state, pointWinner: state.lastHitter };
  }

  // Sideline out (left/right)
  if (wide) {
    const winner = state.lastHitter === 1 ? 2 : 1;
    return {
      ...state,
      outOfBounds: true,
      outType: OUT_TYPE.WIDE,
      pointWinner: winner,
    };
  }

  // Ball past top baseline (P2's side)
  if (b.y < COURT_TOP - 20 && b.height <= 0) {
    if (state.rallyCount === 0 && state.lastHitter === 1) {
      // Unreturned serve = ACE for server
      return {
        ...state,
        outOfBounds: true,
        outType: OUT_TYPE.ACE,
        pointWinner: 1,
      };
    }
    const winner = state.lastHitter === 1 ? 2 : 1;
    return {
      ...state,
      outOfBounds: true,
      outType: OUT_TYPE.LONG,
      pointWinner: winner,
    };
  }

  // Ball past bottom baseline (P1's side)
  if (b.y > COURT_BOTTOM + 20 && b.height <= 0) {
    if (state.rallyCount === 0 && state.lastHitter === 2) {
      // Unreturned serve = ACE for server
      return {
        ...state,
        outOfBounds: true,
        outType: OUT_TYPE.ACE,
        pointWinner: 2,
      };
    }
    const winner = state.lastHitter === 2 ? 1 : 2;
    return {
      ...state,
      outOfBounds: true,
      outType: OUT_TYPE.LONG,
      pointWinner: winner,
    };
  }

  return state;
}

/**
 * Whether the last shot first touched down inside the half of the player it
 * was hit to.
 * @param {object} state
 * @returns {boolean}
 */
function landedIn(state) {
  const { landX, landY } = state.ball;
  if (!Number.isFinite(landX) || !Number.isFinite(landY)) return false;
  if (landX < COURT_LEFT || landX > COURT_RIGHT) return false;
  return state.lastHitter === 1
    ? landY >= COURT_TOP && landY < NET_Y
    : landY > NET_Y && landY <= COURT_BOTTOM;
}

/**
 * Perform a serve.
 * @param {object} state
 * @param {() => number} [random=Math.random] - draws in [0, 1)
 * @returns {object} new state
 */
export function performServe(state, random = Math.random) {
  const srv = state.server;
  const sx = srv === 1 ? state.p1x : state.p2x;
  const sy = srv === 1 ? state.p1y : state.p2y;

  // Serve target: alternate deuce/ad court
  const isDeuceCourt = state.totalPointsInGame % 2 === 0;
  const targetX = isDeuceCourt ? CENTER_LINE_X + 70 : CENTER_LINE_X - 70;
  const targetY = srv === 1 ? SERVICE_LINE_TOP + 40 : SERVICE_LINE_BOTTOM - 40;

  // Slight randomness in target
  const tx = targetX + (random() - 0.5) * 30;
  const ty = targetY + (random() - 0.5) * 15;

  // Direction toward target
  const dx = tx - sx;
  const dy = ty - sy;
  const dist = Math.max(Math.sqrt(dx * dx + dy * dy), 0.001);

  const speed = state.isSecondServe ? SERVE_SPEED * 0.8 : SERVE_SPEED;
  const startY = sy + (srv === 1 ? -15 : 15);
  const arc = serveArc(startY, dy / dist, dist, speed);

  return {
    ...state,
    ball: {
      x: sx,
      y: startY,
      vx: (dx / dist) * speed,
      vy: (dy / dist) * speed,
      speed,
      height: arc.height,
      heightVel: arc.heightVel,
      landX: null,
      landY: null,
    },
    phase: PHASE.RALLY,
    lastHitter: srv,
    rallyCount: 0,
    serveEvent: true,
    serveTimer: SERVE_TIMEOUT_FRAMES,
  };
}

/**
 * The arc that brings a serve hit at `speed` down `distance` away, on its
 * target, and over the net on the way: the frames it takes to get there,
 * slowing as it goes, and the lift that lands it on the last of them. A serve
 * whose arc would pass the net lower than NET_MARGIN over it is struck from
 * higher, still landing on the same frame.
 * @param {number} startY - where the ball leaves the racket
 * @param {number} alongY - the share of its travel that goes up or down the court
 * @param {number} distance
 * @param {number} speed
 * @returns {{ height: number, heightVel: number }}
 */
function serveArc(startY, alongY, distance, speed) {
  const netClear = NET_HALF_H + BALL_RADIUS;
  let travelled = 0;
  let pace = speed;
  let frames = 0;
  let netFrom = null;
  let netTo = null;
  while (travelled < distance && frames < SERVE_TIMEOUT_FRAMES) {
    travelled += pace;
    pace = Math.max(pace - BALL_DECELERATION, BALL_MIN_SPEED);
    frames++;
    if (Math.abs(startY + travelled * alongY - NET_Y) <= netClear) {
      netFrom ??= frames;
      netTo = frames;
    }
  }
  if (frames === 0) return { height: SERVE_HEIGHT, heightVel: 0 };

  // The height after k frames is height + k·heightVel − fallen(k)
  const fallen = (k) => (BALL_GRAVITY * k * (k - 1)) / 2;
  const over = NET_HEIGHT_FACTOR + NET_MARGIN;
  let height = SERVE_HEIGHT;
  let heightVel = (fallen(frames) - height) / frames;
  for (const k of [netFrom, netTo]) {
    if (k === null || k >= frames) continue;
    if (height + k * heightVel - fallen(k) >= over) continue;
    heightVel = (fallen(frames) - fallen(k) - over) / (frames - k);
    height = fallen(frames) - frames * heightVel;
  }
  return { height, heightVel };
}

/**
 * Check if a serve has landed and whether it's a fault.
 * @param {object} state
 * @returns {object} new state
 */
export function checkServeLanding(state) {
  // Only check on serves that haven't been returned (rallyCount === 0)
  if (state.rallyCount !== 0) return state;
  if (state.ball.height > 0 || !Number.isFinite(state.ball.landY)) return state;

  const b = state.ball;
  const srv = state.server;
  const isDeuceCourt = state.totalPointsInGame % 2 === 0;

  // The service box: between the net and the receiver's service line, on the
  // half performServe aims at — the right one on the deuce court, the left on the ad
  const boxTop = srv === 1 ? SERVICE_LINE_TOP : NET_Y;
  const boxBottom = srv === 1 ? NET_Y : SERVICE_LINE_BOTTOM;
  const boxLeft = isDeuceCourt ? CENTER_LINE_X : COURT_LEFT;
  const boxRight = isDeuceCourt ? COURT_RIGHT : CENTER_LINE_X;

  // Judged where the serve first touched down, not where it has rolled to since
  const inBox =
    b.landX >= boxLeft && b.landX <= boxRight && b.landY >= boxTop && b.landY <= boxBottom;

  if (!inBox) {
    // Fault
    if (state.isSecondServe) {
      // Double fault — point to receiver
      const receiver = srv === 1 ? 2 : 1;
      return {
        ...state,
        faultEvent: true,
        pointWinner: receiver,
        outOfBounds: true,
        outType: OUT_TYPE.LONG,
      };
    }
    // First serve fault → second serve
    return {
      ...state,
      faultEvent: true,
      isSecondServe: true,
      phase: PHASE.SERVING,
      ball: {
        x: COURT_CENTER_X,
        y: COURT_CENTER_Y,
        vx: 0,
        vy: 0,
        speed: 0,
        height: 0,
        heightVel: 0,
      },
      serveTimer: SERVE_TIMEOUT_FRAMES,
    };
  }

  return state;
}

/** The point took the game: count it, clear the points, announce it, change server. */
function _winGame(s, pw) {
  if (pw === 1) s.p1Games++;
  else s.p2Games++;
  s.p1Points = 0;
  s.p2Points = 0;
  s.totalPointsInGame = 0;
  s.announcement = ANNOUNCEMENT.GAME;
  s.server = s.server === 1 ? 2 : 1;
  return _checkSetWin(s);
}

/**
 * Advance the score after a point is won.
 * Handles all 3 game modes, deuce/advantage, tiebreak, game/set win.
 * @param {object} state
 * @returns {object} new state
 */
export function advanceScore(state) {
  const pw = state.pointWinner;
  if (pw === 0) return state;

  const s = { ...state };

  // Sudden Death: each point = a game
  if (s.gameMode === GAME_MODE.SUDDEN_DEATH) return _winGame(s, pw);

  // Tiebreak scoring
  if (s.isTiebreak) {
    return _advanceTiebreak(s, pw);
  }

  // Normal tennis scoring
  const pKey = pw === 1 ? "p1Points" : "p2Points";
  const oKey = pw === 1 ? "p2Points" : "p1Points";

  s[pKey]++;

  // Check for game win (need 4+ points and 2+ lead)
  if (s[pKey] >= 4 && s[pKey] - s[oKey] >= 2) return _winGame(s, pw);

  // Deuce: both at 3+ and equal
  if (s.p1Points >= 3 && s.p2Points >= 3) {
    if (s.p1Points === s.p2Points) {
      // Back to deuce (also reset points to 3-3 to keep it clean)
      s.p1Points = 3;
      s.p2Points = 3;
      s.announcement = ANNOUNCEMENT.DEUCE;
    } else if (s.p1Points > s.p2Points) {
      s.announcement = ANNOUNCEMENT.ADV_P1;
    } else {
      s.announcement = ANNOUNCEMENT.ADV_P2;
    }
  }

  s.totalPointsInGame++;
  return s;
}

/**
 * Advance score during a tiebreak.
 * @private
 */
function _advanceTiebreak(state, pw) {
  const s = { ...state };
  const pKey = pw === 1 ? "p1Points" : "p2Points";
  s[pKey]++;

  const totalPoints = s.p1Points + s.p2Points;

  // Server rotates: after 1st point, then every 2 points
  if (totalPoints === 1 || (totalPoints > 1 && (totalPoints - 1) % 2 === 0)) {
    s.server = s.server === 1 ? 2 : 1;
  }

  // Win tiebreak: 7+ points with 2+ lead
  const leader = s.p1Points > s.p2Points ? 1 : 2;
  const leaderPts = Math.max(s.p1Points, s.p2Points);
  const diff = Math.abs(s.p1Points - s.p2Points);

  if (leaderPts >= 7 && diff >= 2) {
    if (leader === 1) s.p1Games++;
    else s.p2Games++;
    s.isTiebreak = false;
    s.announcement = ANNOUNCEMENT.GAME;
    // Tiebreak winner wins the set directly (7-6 is a valid set win)
    return { ...s, phase: PHASE.GAME_OVER, winner: leader };
  }

  s.totalPointsInGame++;
  return s;
}

/**
 * Check if the set is won.
 * @param {object} state
 * @returns {object} new state with winner/phase if set is won
 */
export function checkSetWin(state) {
  return _checkSetWin(state);
}

/** @private */
function _checkSetWin(state) {
  const { p1Games, p2Games, gameMode } = state;

  if (gameMode === GAME_MODE.QUICK) {
    if (p1Games >= 3) return { ...state, phase: PHASE.GAME_OVER, winner: 1 };
    if (p2Games >= 3) return { ...state, phase: PHASE.GAME_OVER, winner: 2 };
    return state;
  }

  // Sudden Death: first to 6 wins outright (no win-by-2, no tiebreak)
  if (gameMode === GAME_MODE.SUDDEN_DEATH) {
    if (p1Games >= 6) return { ...state, phase: PHASE.GAME_OVER, winner: 1 };
    if (p2Games >= 6) return { ...state, phase: PHASE.GAME_OVER, winner: 2 };
    return state;
  }

  // Classic: first to 6, win by 2
  if (p1Games >= 6 && p1Games - p2Games >= 2) {
    return { ...state, phase: PHASE.GAME_OVER, winner: 1 };
  }
  if (p2Games >= 6 && p2Games - p1Games >= 2) {
    return { ...state, phase: PHASE.GAME_OVER, winner: 2 };
  }

  // Tiebreak at 6-6 (Classic only)
  if (p1Games === 6 && p2Games === 6 && !state.isTiebreak) {
    return { ...state, isTiebreak: true, announcement: ANNOUNCEMENT.TIEBREAK };
  }

  return state;
}

/**
 * Should players change ends?
 * @param {object} state
 * @returns {boolean}
 */
export function shouldChangeover(state) {
  if (state.isTiebreak) {
    const totalPoints = state.p1Points + state.p2Points;
    return totalPoints > 0 && totalPoints % 6 === 0;
  }

  const totalGames = state.p1Games + state.p2Games;
  return totalGames > 0 && totalGames % 2 === 1;
}

/**
 * Reset state for the next point (after a point was scored).
 * Preserves score, server, game mode.
 * @param {object} state
 * @returns {object} new state
 */
export function resetForNextPoint(state) {
  const srv = state.server;
  return {
    ...state,
    p1x: COURT_CENTER_X,
    p1y: COURT_BOTTOM - 30,
    p2x: COURT_CENTER_X,
    p2y: COURT_TOP + 30,
    ball: {
      x: srv === 1 ? COURT_CENTER_X : COURT_CENTER_X,
      y: srv === 1 ? COURT_BOTTOM - 30 : COURT_TOP + 30,
      vx: 0,
      vy: 0,
      speed: 0,
      height: 0,
      heightVel: 0,
    },
    phase: PHASE.SERVING,
    ...NO_EVENTS,
    lastHitter: 0,
    rallyCount: 0,
    isSecondServe: false,
    serveTimer: SERVE_TIMEOUT_FRAMES,
  };
}

/**
 * Clear per-frame event flags. Called at the start of each game loop iteration.
 * @param {object} state
 * @returns {object} new state
 */
export function clearEventFlags(state) {
  return { ...state, ...NO_EVENTS };
}

/**
 * One tick of the serve as the host runs it: both players move, the server
 * serves on a fresh press of serve, and the serve clock serves for them when
 * it runs out. `pressed` is whether each side's serve key was down last tick.
 * @param {object} state
 * @param {{ up: boolean, down: boolean, left: boolean, right: boolean, serve: boolean }} local
 * @param {{ up: boolean, down: boolean, left: boolean, right: boolean, serve: boolean }} remote
 * @param {{ local: boolean, remote: boolean }} pressed
 * @param {() => number} [random=Math.random] - draws in [0, 1)
 * @returns {{ state: object, pressed: { local: boolean, remote: boolean }, served: boolean }}
 */
export function stepServing(state, local, remote, pressed, random = Math.random) {
  let s = updatePlayer(state, 1, local);
  s = updatePlayer(s, 2, remote);
  let served = false;
  if (local.serve && !pressed.local && s.server === 1) {
    s = performServe(s, random);
    served = true;
  }
  if (remote.serve && !pressed.remote && s.server === 2) {
    s = performServe(s, random);
    served = true;
  }

  if (s.phase === PHASE.SERVING) {
    s = { ...s, serveTimer: s.serveTimer - 1 };
    if (s.serveTimer <= 0) {
      s = performServe(s, random);
      served = true;
    }
  }
  return { state: s, pressed: { local: local.serve, remote: remote.serve }, served };
}

/**
 * One tick of the ball in play as the host runs it: both players move, the
 * ball moves and is struck in a hit zone, a serve's landing is judged — a
 * first fault sends play back to the serve — and the net and the lines are
 * checked. A point decided is scored, and play pauses on it unless it ended
 * the match. The tick's event flags are set on the state.
 * @param {object} state
 * @param {{ up: boolean, down: boolean, left: boolean, right: boolean }} local
 * @param {{ up: boolean, down: boolean, left: boolean, right: boolean }} remote
 * @returns {{ state: object, point: boolean }}
 */
export function stepRally(state, local, remote) {
  let s = clearEventFlags(state);
  s = updatePlayer(s, 1, local);
  s = updatePlayer(s, 2, remote);
  s = checkHitZone(checkHitZone(updateBall(s), 1), 2);
  s = checkServeLanding(s);
  if (s.faultEvent && s.phase === PHASE.SERVING) return { state: s, point: false };

  s = checkOutOfBounds(checkNetCollision(s));
  if (s.pointWinner === 0) return { state: s, point: false };

  s = advanceScore(s);
  if (s.phase !== PHASE.GAME_OVER) s.phase = PHASE.POINT;
  return { state: s, point: true };
}
