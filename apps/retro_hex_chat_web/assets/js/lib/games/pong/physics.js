/**
 * Pure physics and game logic for Hex Pong.
 * All functions are pure — no side effects, no DOM, no network.
 * @module games/pong_physics
 */

import { PHASE } from "./protocol.js";

// --- Constants ---

export const CANVAS_W = 640;
export const CANVAS_H = 480;
export const PADDLE_W = 12;
export const PADDLE_H = 80;
export const PADDLE_MARGIN = 30;
export const BALL_SIZE = 10;
export const INITIAL_BALL_SPEED = 5;
export const SPEED_INCREMENT = 0.3;
export const MAX_BALL_SPEED = 12;
export const PADDLE_SPEED = 6;
export const WIN_SCORE = 11;
export const MAX_BOUNCE_ANGLE = (60 * Math.PI) / 180; // 60 degrees in radians

/**
 * Create the initial game state.
 * @returns {object}
 */
export function createInitialState() {
  const paddleStartY = (CANVAS_H - PADDLE_H) / 2;
  return {
    ballX: CANVAS_W / 2,
    ballY: CANVAS_H / 2,
    ballVX: 0,
    ballVY: 0,
    paddle1Y: paddleStartY,
    paddle2Y: paddleStartY,
    score1: 0,
    score2: 0,
    phase: PHASE.WAITING,
    countdown: 3,
    lastScorer: 0,
    ballSpeed: INITIAL_BALL_SPEED,
    particles: [],
  };
}

/**
 * Update a paddle position based on inputs.
 * @param {object} state
 * @param {number} player - 1 or 2
 * @param {{ up: boolean, down: boolean }} inputs
 * @returns {object} new state
 */
export function updatePaddle(state, player, inputs) {
  const key = player === 1 ? "paddle1Y" : "paddle2Y";
  let y = state[key];

  if (inputs.up) y -= PADDLE_SPEED;
  if (inputs.down) y += PADDLE_SPEED;

  y = Math.max(0, Math.min(CANVAS_H - PADDLE_H, y));

  return { ...state, [key]: y };
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
 * Check and handle ball bouncing off top/bottom walls.
 * @param {object} state
 * @returns {object} new state with wallBounced flag
 */
export function checkWallBounce(state) {
  if (state.phase !== PHASE.PLAYING) return state;

  let { ballY, ballVY } = state;
  let wallBounced = false;
  const halfBall = BALL_SIZE / 2;

  if (ballY - halfBall <= 0) {
    ballY = halfBall;
    ballVY = Math.abs(ballVY);
    wallBounced = true;
  } else if (ballY + halfBall >= CANVAS_H) {
    ballY = CANVAS_H - halfBall;
    ballVY = -Math.abs(ballVY);
    wallBounced = true;
  }

  return { ...state, ballY, ballVY, wallBounced };
}

/**
 * Check and handle ball collision with paddles.
 * Ball angle depends on where it hits the paddle (center = shallow, edge = steep).
 * @param {object} state
 * @returns {object} new state with paddleHit flag
 */
export function checkPaddleCollision(state) {
  if (state.phase !== PHASE.PLAYING) return state;

  const halfBall = BALL_SIZE / 2;
  let { ballX, ballVX, ballVY, ballSpeed } = state;
  const { ballY } = state;
  let paddleHit = false;

  // Paddle 1 (left side)
  const p1Left = PADDLE_MARGIN;
  const p1Right = PADDLE_MARGIN + PADDLE_W;
  const p1Top = state.paddle1Y;
  const p1Bottom = state.paddle1Y + PADDLE_H;

  if (
    ballVX < 0 &&
    ballX - halfBall <= p1Right &&
    ballX + halfBall >= p1Left &&
    ballY + halfBall >= p1Top &&
    ballY - halfBall <= p1Bottom
  ) {
    const hitPos = (ballY - (p1Top + PADDLE_H / 2)) / (PADDLE_H / 2);
    const clampedHit = Math.max(-1, Math.min(1, hitPos));
    const angle = clampedHit * MAX_BOUNCE_ANGLE;

    ballSpeed = Math.min(ballSpeed + SPEED_INCREMENT, MAX_BALL_SPEED);
    ballVX = ballSpeed * Math.cos(angle);
    ballVY = ballSpeed * Math.sin(angle);
    ballX = p1Right + halfBall;
    paddleHit = true;
  }

  // Paddle 2 (right side)
  const p2Left = CANVAS_W - PADDLE_MARGIN - PADDLE_W;
  const p2Right = CANVAS_W - PADDLE_MARGIN;
  const p2Top = state.paddle2Y;
  const p2Bottom = state.paddle2Y + PADDLE_H;

  if (
    ballVX > 0 &&
    ballX + halfBall >= p2Left &&
    ballX - halfBall <= p2Right &&
    ballY + halfBall >= p2Top &&
    ballY - halfBall <= p2Bottom
  ) {
    const hitPos = (ballY - (p2Top + PADDLE_H / 2)) / (PADDLE_H / 2);
    const clampedHit = Math.max(-1, Math.min(1, hitPos));
    const angle = clampedHit * MAX_BOUNCE_ANGLE;

    ballSpeed = Math.min(ballSpeed + SPEED_INCREMENT, MAX_BALL_SPEED);
    ballVX = -(ballSpeed * Math.cos(angle));
    ballVY = ballSpeed * Math.sin(angle);
    ballX = p2Left - halfBall;
    paddleHit = true;
  }

  return { ...state, ballX, ballY, ballVX, ballVY, ballSpeed, paddleHit };
}

/**
 * Check if ball passed a paddle (score event).
 * @param {object} state
 * @returns {object} new state
 */
export function checkScore(state) {
  if (state.phase !== PHASE.PLAYING) return state;

  const halfBall = BALL_SIZE / 2;

  if (state.ballX - halfBall <= 0) {
    return {
      ...state,
      score2: state.score2 + 1,
      phase: PHASE.SCORED,
      lastScorer: 2,
      scored: true,
    };
  }

  if (state.ballX + halfBall >= CANVAS_W) {
    return {
      ...state,
      score1: state.score1 + 1,
      phase: PHASE.SCORED,
      lastScorer: 1,
      scored: true,
    };
  }

  return state;
}

/**
 * Check if a player has won.
 * Win condition: score >= WIN_SCORE AND lead >= 2 (deuce rule after 10-10).
 * @param {object} state
 * @returns {object} new state
 */
export function checkWin(state) {
  if (state.phase !== PHASE.SCORED) return state;

  const { score1, score2 } = state;
  const maxScore = Math.max(score1, score2);
  const diff = Math.abs(score1 - score2);

  if (maxScore >= WIN_SCORE && diff >= 2) {
    return {
      ...state,
      phase: PHASE.FINISHED,
      winner: score1 > score2 ? 1 : 2,
    };
  }

  return state;
}

/**
 * Serve the ball from center toward the opponent of the last scorer.
 * @param {object} state
 * @returns {object} new state
 */
export function serveBall(state) {
  const direction = state.lastScorer === 1 ? 1 : -1;
  const angle = ((Math.random() * 60 - 30) * Math.PI) / 180;
  const speed = INITIAL_BALL_SPEED;

  return {
    ...state,
    ballX: CANVAS_W / 2,
    ballY: CANVAS_H / 2,
    ballVX: speed * Math.cos(angle) * direction,
    ballVY: speed * Math.sin(angle),
    ballSpeed: speed,
    phase: PHASE.PLAYING,
  };
}

/**
 * Generate score celebration particles.
 * @param {number} x - origin x
 * @param {number} y - origin y
 * @returns {Array} particle array
 */
export function createScoreParticles(x, y) {
  const particles = [];
  for (let i = 0; i < 10; i++) {
    const angle = Math.random() * Math.PI * 2;
    const speed = 2 + Math.random() * 4;
    particles.push({
      x,
      y,
      vx: Math.cos(angle) * speed,
      vy: Math.sin(angle) * speed,
      life: 1.0,
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
      life: p.life - 0.03,
    }))
    .filter((p) => p.life > 0);
}
