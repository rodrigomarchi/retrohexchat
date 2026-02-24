/**
 * Pure physics and game logic for Block Breakers.
 * All functions are pure — no side effects, no DOM, no network.
 * @module games/breakout_physics
 */

import { PHASE, BLOCK_ROWS, BLOCK_COLS, TOTAL_BLOCKS } from "./protocol.js";

// --- Constants ---

export const CANVAS_W = 640;
export const CANVAS_H = 480;
export const PADDLE_W = 80;
export const PADDLE_H = 12;
export const PADDLE_MARGIN = 20;
export const BALL_SIZE = 8;
export const INITIAL_BALL_SPEED = 2.5;
export const SPEED_INCREMENT = 0.12;
export const MAX_BALL_SPEED = 5.5;
export const PADDLE_SPEED = 7;
export const INITIAL_LIVES = 3;
export const MAX_BOUNCE_ANGLE = (60 * Math.PI) / 180;

// Block grid layout
export const BLOCK_W = 56;
export const BLOCK_H = 16;
export const BLOCK_GAP = 4;
export const BLOCK_OFFSET_X = (CANVAS_W - BLOCK_COLS * (BLOCK_W + BLOCK_GAP) + BLOCK_GAP) / 2;
export const BLOCK_OFFSET_Y = 140;

// Row colors and points (top row = hardest to reach = most points)
export const ROW_COLORS = ["#ff0066", "#ff6600", "#ffcc00", "#00ff66", "#00ccff"];
export const ROW_POINTS = [50, 40, 30, 20, 10];

// Speed increases every N blocks destroyed
const SPEED_UP_INTERVAL = 5;

/**
 * Create the block grid.
 * @returns {Array<{row: number, col: number, x: number, y: number, w: number, h: number, alive: boolean, color: string, points: number}>}
 */
export function createBlockGrid() {
  const blocks = [];
  for (let row = 0; row < BLOCK_ROWS; row++) {
    for (let col = 0; col < BLOCK_COLS; col++) {
      blocks.push({
        row,
        col,
        x: BLOCK_OFFSET_X + col * (BLOCK_W + BLOCK_GAP),
        y: BLOCK_OFFSET_Y + row * (BLOCK_H + BLOCK_GAP),
        w: BLOCK_W,
        h: BLOCK_H,
        alive: true,
        color: ROW_COLORS[row],
        points: ROW_POINTS[row],
      });
    }
  }
  return blocks;
}

/**
 * Create the initial game state.
 * @returns {object}
 */
export function createInitialState() {
  const paddleStartX = (CANVAS_W - PADDLE_W) / 2;
  return {
    ballX: CANVAS_W / 2,
    ballY: CANVAS_H / 2,
    ballVX: 0,
    ballVY: 0,
    paddle1X: paddleStartX,
    paddle2X: paddleStartX,
    score: 0,
    lives: INITIAL_LIVES,
    phase: PHASE.WAITING,
    countdown: 3,
    ballSpeed: INITIAL_BALL_SPEED,
    blocks: createBlockGrid(),
    blocksRemaining: TOTAL_BLOCKS,
    blocksDestroyed: 0,
    particles: [],
    won: false,
  };
}

/**
 * Update a paddle position based on inputs.
 * @param {object} state
 * @param {number} player - 1 (bottom) or 2 (top)
 * @param {{ left: boolean, right: boolean }} inputs
 * @returns {object} new state
 */
export function updatePaddle(state, player, inputs) {
  const key = player === 1 ? "paddle1X" : "paddle2X";
  let x = state[key];

  if (inputs.left) x -= PADDLE_SPEED;
  if (inputs.right) x += PADDLE_SPEED;

  x = Math.max(0, Math.min(CANVAS_W - PADDLE_W, x));

  return { ...state, [key]: x };
}

/**
 * Update ball position.
 * @param {object} state
 * @returns {object} new state
 */
export function updateBall(state) {
  if (state.phase !== PHASE.PLAYING) return state;
  return {
    ...state,
    ballX: state.ballX + state.ballVX,
    ballY: state.ballY + state.ballVY,
  };
}

/**
 * Check and handle ball bouncing off left/right walls.
 * Top/bottom are NOT walls — they cause life loss.
 * @param {object} state
 * @returns {object} new state with wallBounced flag
 */
export function checkWallBounce(state) {
  if (state.phase !== PHASE.PLAYING) return state;

  let ballX = state.ballX;
  let ballVX = state.ballVX;
  let wallBounced = false;
  const halfBall = BALL_SIZE / 2;

  if (ballX - halfBall <= 0) {
    ballX = halfBall;
    ballVX = Math.abs(ballVX);
    wallBounced = true;
  } else if (ballX + halfBall >= CANVAS_W) {
    ballX = CANVAS_W - halfBall;
    ballVX = -Math.abs(ballVX);
    wallBounced = true;
  }

  return { ...state, ballX, ballVX, wallBounced };
}

/**
 * Check and handle ball collision with paddles.
 * Paddle 1 = bottom, Paddle 2 = top.
 * @param {object} state
 * @returns {object} new state with paddleHit flag
 */
export function checkPaddleCollision(state) {
  if (state.phase !== PHASE.PLAYING) return state;

  const halfBall = BALL_SIZE / 2;
  const { ballX } = state;
  let { ballY, ballVX, ballVY, ballSpeed } = state;
  let paddleHit = false;

  // Paddle 1 (bottom)
  const p1Top = CANVAS_H - PADDLE_MARGIN - PADDLE_H;
  const p1Bottom = CANVAS_H - PADDLE_MARGIN;
  const p1Left = state.paddle1X;
  const p1Right = state.paddle1X + PADDLE_W;

  if (
    ballVY > 0 &&
    ballY + halfBall >= p1Top &&
    ballY - halfBall <= p1Bottom &&
    ballX + halfBall >= p1Left &&
    ballX - halfBall <= p1Right
  ) {
    const hitPos = (ballX - (p1Left + PADDLE_W / 2)) / (PADDLE_W / 2);
    const clampedHit = Math.max(-1, Math.min(1, hitPos));
    const angle = clampedHit * MAX_BOUNCE_ANGLE;

    ballSpeed = Math.min(ballSpeed + SPEED_INCREMENT, MAX_BALL_SPEED);
    ballVX = ballSpeed * Math.sin(angle);
    ballVY = -(ballSpeed * Math.cos(angle));
    ballY = p1Top - halfBall;
    paddleHit = true;
  }

  // Paddle 2 (top)
  const p2Top = PADDLE_MARGIN;
  const p2Bottom = PADDLE_MARGIN + PADDLE_H;
  const p2Left = state.paddle2X;
  const p2Right = state.paddle2X + PADDLE_W;

  if (
    ballVY < 0 &&
    ballY - halfBall <= p2Bottom &&
    ballY + halfBall >= p2Top &&
    ballX + halfBall >= p2Left &&
    ballX - halfBall <= p2Right
  ) {
    const hitPos = (ballX - (p2Left + PADDLE_W / 2)) / (PADDLE_W / 2);
    const clampedHit = Math.max(-1, Math.min(1, hitPos));
    const angle = clampedHit * MAX_BOUNCE_ANGLE;

    ballSpeed = Math.min(ballSpeed + SPEED_INCREMENT, MAX_BALL_SPEED);
    ballVX = ballSpeed * Math.sin(angle);
    ballVY = ballSpeed * Math.cos(angle);
    ballY = p2Bottom + halfBall;
    paddleHit = true;
  }

  return { ...state, ballX, ballY, ballVX, ballVY, ballSpeed, paddleHit };
}

/**
 * Check ball collision with blocks.
 * @param {object} state
 * @returns {object} new state with blockHit flag and hitBlockRow
 */
export function checkBlockCollision(state) {
  if (state.phase !== PHASE.PLAYING) return state;

  const halfBall = BALL_SIZE / 2;
  const bx = state.ballX;
  const by = state.ballY;

  for (let i = 0; i < state.blocks.length; i++) {
    const block = state.blocks[i];
    if (!block.alive) continue;

    // AABB collision
    if (
      bx + halfBall >= block.x &&
      bx - halfBall <= block.x + block.w &&
      by + halfBall >= block.y &&
      by - halfBall <= block.y + block.h
    ) {
      // Destroy block
      const newBlocks = state.blocks.map((b, idx) => (idx === i ? { ...b, alive: false } : b));
      const newDestroyed = state.blocksDestroyed + 1;
      const newRemaining = state.blocksRemaining - 1;

      // Speed up every N blocks
      let { ballSpeed } = state;
      if (newDestroyed % SPEED_UP_INTERVAL === 0) {
        ballSpeed = Math.min(ballSpeed + SPEED_INCREMENT, MAX_BALL_SPEED);
      }

      // Determine bounce direction based on collision side
      let { ballVX, ballVY } = state;
      const overlapLeft = bx + halfBall - block.x;
      const overlapRight = block.x + block.w - (bx - halfBall);
      const overlapTop = by + halfBall - block.y;
      const overlapBottom = block.y + block.h - (by - halfBall);
      const minOverlap = Math.min(overlapLeft, overlapRight, overlapTop, overlapBottom);

      if (minOverlap === overlapTop || minOverlap === overlapBottom) {
        ballVY = -ballVY;
      } else {
        ballVX = -ballVX;
      }

      return {
        ...state,
        ballVX,
        ballVY,
        ballSpeed,
        blocks: newBlocks,
        blocksDestroyed: newDestroyed,
        blocksRemaining: newRemaining,
        score: state.score + block.points,
        blockHit: true,
        hitBlockRow: block.row,
        hitBlockX: block.x + block.w / 2,
        hitBlockY: block.y + block.h / 2,
        hitBlockColor: block.color,
      };
    }
  }

  return state;
}

/**
 * Check if ball exited top or bottom (life lost).
 * @param {object} state
 * @returns {object} new state
 */
export function checkLifeLost(state) {
  if (state.phase !== PHASE.PLAYING) return state;

  const halfBall = BALL_SIZE / 2;

  if (state.ballY - halfBall <= 0 || state.ballY + halfBall >= CANVAS_H) {
    return {
      ...state,
      lives: state.lives - 1,
      phase: PHASE.LIFE_LOST,
      lifeLost: true,
    };
  }

  return state;
}

/**
 * Check win/lose conditions.
 * Win: all blocks destroyed. Lose: no lives remaining.
 * @param {object} state
 * @returns {object} new state
 */
export function checkWin(state) {
  if (state.phase !== PHASE.LIFE_LOST && state.phase !== PHASE.PLAYING) return state;

  if (state.blocksRemaining <= 0) {
    return {
      ...state,
      phase: PHASE.FINISHED,
      won: true,
    };
  }

  if (state.phase === PHASE.LIFE_LOST && state.lives <= 0) {
    return {
      ...state,
      phase: PHASE.FINISHED,
      won: false,
    };
  }

  return state;
}

/**
 * Serve the ball from center in the given direction.
 * @param {object} state
 * @param {number} direction - 1 = downward (toward P1), -1 = upward (toward P2)
 * @returns {object} new state
 */
export function serveBall(state, direction = 1) {
  const angle = ((Math.random() * 60 - 30) * Math.PI) / 180;
  const speed = INITIAL_BALL_SPEED;

  return {
    ...state,
    ballX: CANVAS_W / 2,
    ballY: CANVAS_H / 2,
    ballVX: speed * Math.sin(angle),
    ballVY: direction * speed * Math.cos(angle),
    ballSpeed: speed,
    phase: PHASE.PLAYING,
  };
}

/**
 * Generate block destruction particles.
 * @param {number} x - origin x
 * @param {number} y - origin y
 * @param {string} color - particle color
 * @returns {Array} particle array
 */
export function createBlockParticles(x, y, color) {
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
