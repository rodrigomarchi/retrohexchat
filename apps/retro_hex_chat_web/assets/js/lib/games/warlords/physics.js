/**
 * Pure physics and game logic for Hex Warlords.
 * All functions are pure — no side effects, no DOM, no network.
 * @module games/warlords_physics
 */

import { PHASE, BRICKS_ROWS, BRICKS_COLS, INITIAL_LIVES } from "./protocol.js";

// --- Canvas ---
export const CANVAS_W = 640;
export const CANVAS_H = 480;

// --- Shield ---
export const SHIELD_W = 12;
export const SHIELD_H = 60;
export const SHIELD_SPEED = 6;

// --- Fireball ---
export const FIREBALL_SIZE = 8;
export const INITIAL_BALL_SPEED = 3;
export const SPEED_INCREMENT = 0.05;
export const MAX_BALL_SPEED = 5.5;
export const MAX_BOUNCE_ANGLE = (60 * Math.PI) / 180;

// --- Bricks ---
export const BRICK_W = 20;
export const BRICK_H = 16;
export const BRICK_GAP = 2;

// --- Castle positioning ---
// P1 castle on left side, P2 castle on right side
const CASTLE_MARGIN_X = 50;
const CASTLE_Y_CENTER = CANVAS_H / 2;

// P1 castle brick area: left edge
export const P1_CASTLE_X = CASTLE_MARGIN_X;
export const P1_CASTLE_Y = CASTLE_Y_CENTER - (BRICKS_ROWS * (BRICK_H + BRICK_GAP) - BRICK_GAP) / 2;
// P1 shield: just to the right of the castle
export const P1_SHIELD_X = P1_CASTLE_X + BRICKS_COLS * (BRICK_W + BRICK_GAP) + 4;

// P2 castle brick area: right edge (mirrored)
export const P2_CASTLE_X =
  CANVAS_W - CASTLE_MARGIN_X - BRICKS_COLS * (BRICK_W + BRICK_GAP) + BRICK_GAP;
export const P2_CASTLE_Y = P1_CASTLE_Y;
// P2 shield: just to the left of the castle
export const P2_SHIELD_X = P2_CASTLE_X - SHIELD_W - 4;

// --- King positions (center of castle) ---
export const P1_KING_X = P1_CASTLE_X + (BRICKS_COLS * (BRICK_W + BRICK_GAP) - BRICK_GAP) / 2;
export const P1_KING_Y = CASTLE_Y_CENTER;
export const P2_KING_X = P2_CASTLE_X + (BRICKS_COLS * (BRICK_W + BRICK_GAP) - BRICK_GAP) / 2;
export const P2_KING_Y = CASTLE_Y_CENTER;
export const KING_SIZE = 14;

// Brick color tiers by column distance from the outside edge
// P1: col 3 is outermost (right), col 0 is innermost (left, near king)
// P2: col 0 is outermost (left), col 3 is innermost (right, near king)
const BRICK_COLORS_OUTER_TO_INNER = ["#00ff66", "#00ccff", "#ffcc00", "#ff3366"];

/**
 * Create the initial game state.
 * @returns {object}
 */
export function createInitialState() {
  const shieldStartY = CASTLE_Y_CENTER - SHIELD_H / 2;
  return {
    fireballX: CANVAS_W / 2,
    fireballY: CANVAS_H / 2,
    fireballVX: 0,
    fireballVY: 0,
    fireballSpeed: INITIAL_BALL_SPEED,
    shield1Y: shieldStartY,
    shield2Y: shieldStartY,
    p1Bricks: createCastleBricks("left"),
    p2Bricks: createCastleBricks("right"),
    p1Lives: INITIAL_LIVES,
    p2Lives: INITIAL_LIVES,
    p1KingAlive: true,
    p2KingAlive: true,
    phase: PHASE.WAITING,
    countdown: 3,
    round: 1,
    caughtBy: 0, // 0=none, 1=P1, 2=P2
    particles: [],
  };
}

/**
 * Create brick grid for one castle.
 * @param {"left"|"right"} side
 * @returns {Array<{row: number, col: number, x: number, y: number, w: number, h: number, alive: boolean, color: string}>}
 */
export function createCastleBricks(side) {
  const bricks = [];
  const baseX = side === "left" ? P1_CASTLE_X : P2_CASTLE_X;
  const baseY = side === "left" ? P1_CASTLE_Y : P2_CASTLE_Y;

  for (let row = 0; row < BRICKS_ROWS; row++) {
    for (let col = 0; col < BRICKS_COLS; col++) {
      // Color by distance from king (inner columns closer to king)
      // P1 (left): col 0 is innermost, col 3 is outermost
      // P2 (right): col 3 is innermost, col 0 is outermost
      const distFromKing = side === "left" ? col : BRICKS_COLS - 1 - col;
      const colorIndex = Math.min(distFromKing, BRICK_COLORS_OUTER_TO_INNER.length - 1);

      bricks.push({
        row,
        col,
        x: baseX + col * (BRICK_W + BRICK_GAP),
        y: baseY + row * (BRICK_H + BRICK_GAP),
        w: BRICK_W,
        h: BRICK_H,
        alive: true,
        color: BRICK_COLORS_OUTER_TO_INNER[colorIndex],
      });
    }
  }
  return bricks;
}

/**
 * Update a shield position based on inputs.
 * @param {object} state
 * @param {number} player - 1 or 2
 * @param {{ up: boolean, down: boolean }} inputs
 * @returns {object} new state
 */
export function updateShield(state, player, inputs) {
  const key = player === 1 ? "shield1Y" : "shield2Y";
  let y = state[key];

  if (inputs.up) y -= SHIELD_SPEED;
  if (inputs.down) y += SHIELD_SPEED;

  y = Math.max(0, Math.min(CANVAS_H - SHIELD_H, y));

  return { ...state, [key]: y };
}

/**
 * Update fireball position (skip if caught).
 * @param {object} state
 * @returns {object} new state
 */
export function updateFireball(state) {
  if (state.phase !== PHASE.PLAYING || state.caughtBy !== 0) return state;
  return {
    ...state,
    fireballX: state.fireballX + state.fireballVX,
    fireballY: state.fireballY + state.fireballVY,
  };
}

/**
 * Update fireball position to follow the catching shield.
 * @param {object} state
 * @returns {object} new state
 */
export function updateCaughtFireball(state) {
  if (state.caughtBy === 0) return state;

  const shieldY = state.caughtBy === 1 ? state.shield1Y : state.shield2Y;
  const shieldX = state.caughtBy === 1 ? P1_SHIELD_X : P2_SHIELD_X;
  // Position fireball at shield center, offset toward opponent
  const offsetX = state.caughtBy === 1 ? SHIELD_W + FIREBALL_SIZE : -FIREBALL_SIZE;

  return {
    ...state,
    fireballX: shieldX + offsetX,
    fireballY: shieldY + SHIELD_H / 2,
  };
}

/**
 * Check and handle fireball bouncing off top/bottom walls.
 * @param {object} state
 * @returns {object} new state with wallBounced flag
 */
export function checkWallBounce(state) {
  if (state.phase !== PHASE.PLAYING || state.caughtBy !== 0) return state;

  let { fireballY, fireballVY } = state;
  let wallBounced = false;
  const halfBall = FIREBALL_SIZE / 2;

  if (fireballY - halfBall <= 0) {
    fireballY = halfBall;
    fireballVY = Math.abs(fireballVY);
    wallBounced = true;
  } else if (fireballY + halfBall >= CANVAS_H) {
    fireballY = CANVAS_H - halfBall;
    fireballVY = -Math.abs(fireballVY);
    wallBounced = true;
  }

  // Also bounce off left/right edges (safety net — normally bricks/kings stop the ball)
  let { fireballX, fireballVX } = state;
  if (fireballX - halfBall <= 0) {
    fireballX = halfBall;
    fireballVX = Math.abs(fireballVX);
    wallBounced = true;
  } else if (fireballX + halfBall >= CANVAS_W) {
    fireballX = CANVAS_W - halfBall;
    fireballVX = -Math.abs(fireballVX);
    wallBounced = true;
  }

  return { ...state, fireballX, fireballY, fireballVX, fireballVY, wallBounced };
}

/**
 * Check fireball collision with shields (deflection).
 * @param {object} state
 * @returns {object} new state with shieldHit flag
 */
export function checkShieldCollision(state) {
  if (state.phase !== PHASE.PLAYING || state.caughtBy !== 0) return state;

  const halfBall = FIREBALL_SIZE / 2;
  const { fireballX, fireballY } = state;
  let { fireballVX, fireballVY, fireballSpeed } = state;
  let shieldHit = false;
  let shieldHitPlayer = 0;

  // P1 shield (right side of P1 castle, deflects rightward)
  const s1Left = P1_SHIELD_X;
  const s1Right = P1_SHIELD_X + SHIELD_W;
  const s1Top = state.shield1Y;
  const s1Bottom = state.shield1Y + SHIELD_H;

  if (
    fireballVX < 0 &&
    fireballX - halfBall <= s1Right &&
    fireballX + halfBall >= s1Left &&
    fireballY + halfBall >= s1Top &&
    fireballY - halfBall <= s1Bottom
  ) {
    const hitPos = (fireballY - (s1Top + SHIELD_H / 2)) / (SHIELD_H / 2);
    const clampedHit = Math.max(-1, Math.min(1, hitPos));
    const angle = clampedHit * MAX_BOUNCE_ANGLE;

    fireballSpeed = Math.min(fireballSpeed + SPEED_INCREMENT, MAX_BALL_SPEED);
    fireballVX = fireballSpeed * Math.cos(angle);
    fireballVY = fireballSpeed * Math.sin(angle);
    shieldHit = true;
    shieldHitPlayer = 1;
  }

  // P2 shield (left side of P2 castle, deflects leftward)
  const s2Left = P2_SHIELD_X;
  const s2Right = P2_SHIELD_X + SHIELD_W;
  const s2Top = state.shield2Y;
  const s2Bottom = state.shield2Y + SHIELD_H;

  if (
    !shieldHit &&
    fireballVX > 0 &&
    fireballX + halfBall >= s2Left &&
    fireballX - halfBall <= s2Right &&
    fireballY + halfBall >= s2Top &&
    fireballY - halfBall <= s2Bottom
  ) {
    const hitPos = (fireballY - (s2Top + SHIELD_H / 2)) / (SHIELD_H / 2);
    const clampedHit = Math.max(-1, Math.min(1, hitPos));
    const angle = clampedHit * MAX_BOUNCE_ANGLE;

    fireballSpeed = Math.min(fireballSpeed + SPEED_INCREMENT, MAX_BALL_SPEED);
    fireballVX = -(fireballSpeed * Math.cos(angle));
    fireballVY = fireballSpeed * Math.sin(angle);
    shieldHit = true;
    shieldHitPlayer = 2;
  }

  return { ...state, fireballVX, fireballVY, fireballSpeed, shieldHit, shieldHitPlayer };
}

/**
 * Check if catch conditions are met (Space held + fireball touches shield).
 * @param {object} state
 * @param {{ space: boolean }} inputs1 - P1 inputs
 * @param {{ space: boolean }} inputs2 - P2 inputs
 * @returns {object} new state with caught flag
 */
export function checkCatch(state, inputs1, inputs2) {
  if (state.phase !== PHASE.PLAYING || state.caughtBy !== 0) return state;
  if (!state.shieldHit) return state;

  // Only catch if the player whose shield was hit is holding Space
  if (state.shieldHitPlayer === 1 && inputs1.space) {
    return { ...state, caughtBy: 1, caught: true };
  }
  if (state.shieldHitPlayer === 2 && inputs2.space) {
    return { ...state, caughtBy: 2, caught: true };
  }

  return state;
}

/**
 * Release fireball from caught state (launch toward opponent).
 * @param {object} state
 * @param {number} player - 1 or 2
 * @returns {object} new state
 */
export function releaseBall(state, player) {
  if (state.caughtBy !== player) return state;

  const shieldY = player === 1 ? state.shield1Y : state.shield2Y;
  const shieldCenterY = shieldY + SHIELD_H / 2;
  // Aim angle based on shield Y position relative to canvas center
  const aimOffset = (shieldCenterY - CANVAS_H / 2) / (CANVAS_H / 2);
  const angle = aimOffset * MAX_BOUNCE_ANGLE;

  const speed = state.fireballSpeed;
  const dirX = player === 1 ? 1 : -1; // Launch toward opponent

  return {
    ...state,
    fireballVX: dirX * speed * Math.cos(angle),
    fireballVY: speed * Math.sin(angle),
    caughtBy: 0,
    released: true,
  };
}

/**
 * Check fireball collision with bricks.
 * @param {object} state
 * @returns {object} new state with brickHit flag
 */
export function checkBrickCollision(state) {
  if (state.phase !== PHASE.PLAYING || state.caughtBy !== 0) return state;

  const halfBall = FIREBALL_SIZE / 2;
  const bx = state.fireballX;
  const by = state.fireballY;

  // Check both castles
  for (const side of ["p1", "p2"]) {
    const bricksKey = `${side}Bricks`;
    const bricks = state[bricksKey];

    for (let i = 0; i < bricks.length; i++) {
      const brick = bricks[i];
      if (!brick.alive) continue;

      // AABB collision
      if (
        bx + halfBall >= brick.x &&
        bx - halfBall <= brick.x + brick.w &&
        by + halfBall >= brick.y &&
        by - halfBall <= brick.y + brick.h
      ) {
        // Destroy brick
        const newBricks = bricks.map((b, idx) => (idx === i ? { ...b, alive: false } : b));

        // Determine bounce direction
        let { fireballVX, fireballVY } = state;
        const overlapLeft = bx + halfBall - brick.x;
        const overlapRight = brick.x + brick.w - (bx - halfBall);
        const overlapTop = by + halfBall - brick.y;
        const overlapBottom = brick.y + brick.h - (by - halfBall);
        const minOverlap = Math.min(overlapLeft, overlapRight, overlapTop, overlapBottom);

        if (minOverlap === overlapTop || minOverlap === overlapBottom) {
          fireballVY = -fireballVY;
        } else {
          fireballVX = -fireballVX;
        }

        return {
          ...state,
          fireballVX,
          fireballVY,
          [bricksKey]: newBricks,
          brickHit: true,
          hitBrickX: brick.x + brick.w / 2,
          hitBrickY: brick.y + brick.h / 2,
          hitBrickColor: brick.color,
          hitCastle: side,
        };
      }
    }
  }

  return state;
}

/**
 * Check if fireball reaches a king (king is exposed when inner bricks destroyed).
 * @param {object} state
 * @returns {object} new state with kingHit flag
 */
export function checkKingHit(state) {
  if (state.phase !== PHASE.PLAYING || state.caughtBy !== 0) return state;

  const halfBall = FIREBALL_SIZE / 2;
  const halfKing = KING_SIZE / 2;

  // Check P1 king
  if (
    state.p1KingAlive &&
    state.fireballX - halfBall <= P1_KING_X + halfKing &&
    state.fireballX + halfBall >= P1_KING_X - halfKing &&
    state.fireballY - halfBall <= P1_KING_Y + halfKing &&
    state.fireballY + halfBall >= P1_KING_Y - halfKing
  ) {
    // Check if path to king is open (inner column bricks destroyed)
    const innerBricksAlive = state.p1Bricks.some(
      (b) => b.alive && b.col === 0 && Math.abs(b.y + b.h / 2 - state.fireballY) < b.h,
    );
    if (!innerBricksAlive) {
      return {
        ...state,
        kingHit: true,
        kingHitPlayer: 1,
        p1KingAlive: false,
        p1Lives: state.p1Lives - 1,
      };
    }
  }

  // Check P2 king
  if (
    state.p2KingAlive &&
    state.fireballX - halfBall <= P2_KING_X + halfKing &&
    state.fireballX + halfBall >= P2_KING_X - halfKing &&
    state.fireballY - halfBall <= P2_KING_Y + halfKing &&
    state.fireballY + halfBall >= P2_KING_Y - halfKing
  ) {
    const innerBricksAlive = state.p2Bricks.some(
      (b) =>
        b.alive && b.col === BRICKS_COLS - 1 && Math.abs(b.y + b.h / 2 - state.fireballY) < b.h,
    );
    if (!innerBricksAlive) {
      return {
        ...state,
        kingHit: true,
        kingHitPlayer: 2,
        p2KingAlive: false,
        p2Lives: state.p2Lives - 1,
      };
    }
  }

  return state;
}

/**
 * Rebuild castles and reset fireball for next round after king hit.
 * @param {object} state
 * @returns {object} new state
 */
export function rebuildCastles(state) {
  return {
    ...state,
    p1Bricks: createCastleBricks("left"),
    p2Bricks: createCastleBricks("right"),
    p1KingAlive: true,
    p2KingAlive: true,
    fireballX: CANVAS_W / 2,
    fireballY: CANVAS_H / 2,
    fireballVX: 0,
    fireballVY: 0,
    fireballSpeed: INITIAL_BALL_SPEED,
    caughtBy: 0,
    round: state.round + 1,
  };
}

/**
 * Serve fireball from center with random angle.
 * @param {object} state
 * @returns {object} new state
 */
export function serveFireball(state) {
  const angle = ((Math.random() * 60 - 30) * Math.PI) / 180;
  const speed = INITIAL_BALL_SPEED;
  // Alternate serve direction based on round
  const dirX = state.round % 2 === 1 ? 1 : -1;

  return {
    ...state,
    fireballX: CANVAS_W / 2,
    fireballY: CANVAS_H / 2,
    fireballVX: dirX * speed * Math.cos(angle),
    fireballVY: speed * Math.sin(angle),
    fireballSpeed: speed,
    phase: PHASE.PLAYING,
  };
}

/**
 * Check if game is finished (a player has 0 lives).
 * @param {object} state
 * @returns {object} new state
 */
export function checkGameOver(state) {
  if (state.p1Lives <= 0) {
    return { ...state, phase: PHASE.FINISHED, winner: 2 };
  }
  if (state.p2Lives <= 0) {
    return { ...state, phase: PHASE.FINISHED, winner: 1 };
  }
  return state;
}

/**
 * Generate brick destruction particles.
 * @param {number} x - origin x
 * @param {number} y - origin y
 * @param {string} color - particle color
 * @returns {Array} particle array
 */
export function createBrickParticles(x, y, color) {
  const particles = [];
  for (let i = 0; i < 8; i++) {
    const angle = Math.random() * Math.PI * 2;
    const speed = 2 + Math.random() * 3;
    particles.push({
      x,
      y,
      vx: Math.cos(angle) * speed,
      vy: Math.sin(angle) * speed,
      life: 1.0,
      color: color || "#ffaa00",
    });
  }
  return particles;
}

/**
 * Generate king destruction particles (larger explosion).
 * @param {number} x - origin x
 * @param {number} y - origin y
 * @returns {Array} particle array
 */
export function createKingParticles(x, y) {
  const particles = [];
  for (let i = 0; i < 16; i++) {
    const angle = Math.random() * Math.PI * 2;
    const speed = 3 + Math.random() * 5;
    particles.push({
      x,
      y,
      vx: Math.cos(angle) * speed,
      vy: Math.sin(angle) * speed,
      life: 1.0,
      color: i % 2 === 0 ? "#ff3366" : "#ffcc00",
    });
  }
  return particles;
}

/**
 * Update particles (decay + move).
 * @param {Array} particles
 * @returns {Array} updated particles (alive only)
 */
export function updateParticles(particles) {
  return particles
    .map((p) => ({
      ...p,
      x: p.x + p.vx,
      y: p.y + p.vy,
      vx: p.vx * 0.96,
      vy: p.vy * 0.96,
      life: p.life - 0.04,
    }))
    .filter((p) => p.life > 0);
}
