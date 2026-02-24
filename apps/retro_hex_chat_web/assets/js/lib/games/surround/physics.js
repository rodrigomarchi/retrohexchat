/**
 * Pure physics functions for Light Trails (Tron Surround).
 * All functions are pure — no DOM, no network, no side effects.
 * @module games/surround_physics
 */

import { PHASE, DIR, GRID_W, GRID_H } from "./protocol.js";

// Canvas dimensions
export const CANVAS_W = 640;
export const CANVAS_H = 480;

// Cell size to fit grid in canvas
export const CELL_SIZE = Math.floor(Math.min(CANVAS_W / GRID_W, CANVAS_H / GRID_H));
// Offsets to center grid on canvas
export const GRID_OFFSET_X = Math.floor((CANVAS_W - GRID_W * CELL_SIZE) / 2);
export const GRID_OFFSET_Y = Math.floor((CANVAS_H - GRID_H * CELL_SIZE) / 2);

// Grid cell values
export const CELL = {
  EMPTY: 0,
  P1_TRAIL: 1,
  P2_TRAIL: 2,
};

// Opposite direction pairs (for 180° reversal prevention)
const OPPOSITE = {
  [DIR.UP]: DIR.DOWN,
  [DIR.DOWN]: DIR.UP,
  [DIR.LEFT]: DIR.RIGHT,
  [DIR.RIGHT]: DIR.LEFT,
};

/**
 * Create a fresh grid (2D Uint8Array).
 * @returns {Uint8Array[]}
 */
function createGrid() {
  return Array.from({ length: GRID_H }, () => new Uint8Array(GRID_W));
}

/**
 * Create initial game state for a round.
 * Players swap starting sides on odd rounds.
 * @param {number} round - 0-based round number
 * @returns {object}
 */
export function createInitialState(round = 0) {
  const grid = createGrid();
  const swap = round % 2 === 1;
  const midY = Math.floor(GRID_H / 2);

  const p1 = swap ? { x: GRID_W - 6, y: midY, dir: DIR.LEFT } : { x: 5, y: midY, dir: DIR.RIGHT };

  const p2 = swap ? { x: 5, y: midY, dir: DIR.RIGHT } : { x: GRID_W - 6, y: midY, dir: DIR.LEFT };

  // Place initial trail at starting positions
  grid[p1.y][p1.x] = CELL.P1_TRAIL;
  grid[p2.y][p2.x] = CELL.P2_TRAIL;

  return {
    grid,
    p1: { ...p1 },
    p2: { ...p2 },
    score1: 0,
    score2: 0,
    phase: PHASE.WAITING,
    countdown: 3,
    round,
    particles: [],
  };
}

/**
 * Apply direction change with 180° reversal prevention.
 * @param {number} currentDir - current DIR value
 * @param {number} requestedDir - requested DIR value
 * @returns {number} effective direction
 */
export function applyDirection(currentDir, requestedDir) {
  if (OPPOSITE[currentDir] === requestedDir) return currentDir;
  return requestedDir;
}

/**
 * Advance a position one cell in the given direction.
 * @param {number} x
 * @param {number} y
 * @param {number} dir
 * @returns {{x: number, y: number}}
 */
function advance(x, y, dir) {
  switch (dir) {
    case DIR.UP:
      return { x, y: y - 1 };
    case DIR.DOWN:
      return { x, y: y + 1 };
    case DIR.LEFT:
      return { x: x - 1, y };
    case DIR.RIGHT:
      return { x: x + 1, y };
    default:
      return { x, y };
  }
}

/**
 * Check if a position is out of bounds.
 * @param {{x: number, y: number}} pos
 * @returns {boolean}
 */
function isOOB(pos) {
  return pos.x < 0 || pos.x >= GRID_W || pos.y < 0 || pos.y >= GRID_H;
}

/**
 * Move both players one tick and check collisions.
 * Collision is checked BEFORE placing new trail cells.
 * Returns new state with p1Dead/p2Dead flags.
 *
 * Only runs during PLAYING phase — returns unchanged state otherwise.
 *
 * @param {object} state
 * @param {number} p1Dir - pending direction for P1
 * @param {number} p2Dir - pending direction for P2
 * @returns {object} new state with p1Dead, p2Dead flags
 */
export function moveAndCheck(state, p1Dir, p2Dir) {
  if (state.phase !== PHASE.PLAYING) {
    return { ...state, p1Dead: false, p2Dead: false };
  }

  // Apply directions with reversal prevention
  const p1EffDir = applyDirection(state.p1.dir, p1Dir);
  const p2EffDir = applyDirection(state.p2.dir, p2Dir);

  // Compute next positions
  const p1Next = advance(state.p1.x, state.p1.y, p1EffDir);
  const p2Next = advance(state.p2.x, state.p2.y, p2EffDir);

  // Check border collisions
  const p1OOB = isOOB(p1Next);
  const p2OOB = isOOB(p2Next);

  // Check trail collisions (against current grid BEFORE this tick's moves)
  const p1TrailHit = !p1OOB && state.grid[p1Next.y][p1Next.x] !== CELL.EMPTY;
  const p2TrailHit = !p2OOB && state.grid[p2Next.y][p2Next.x] !== CELL.EMPTY;

  // Head-on: both move to the same cell
  const headOn = !p1OOB && !p2OOB && p1Next.x === p2Next.x && p1Next.y === p2Next.y;

  const p1Dead = p1OOB || p1TrailHit || headOn;
  const p2Dead = p2OOB || p2TrailHit || headOn;

  // Deep copy grid and place trails only for survivors
  const newGrid = state.grid.map((row) => new Uint8Array(row));
  if (!p1Dead) newGrid[p1Next.y][p1Next.x] = CELL.P1_TRAIL;
  if (!p2Dead) newGrid[p2Next.y][p2Next.x] = CELL.P2_TRAIL;

  return {
    ...state,
    grid: newGrid,
    p1: p1Dead ? { ...state.p1, dir: p1EffDir } : { ...p1Next, dir: p1EffDir },
    p2: p2Dead ? { ...state.p2, dir: p2EffDir } : { ...p2Next, dir: p2EffDir },
    p1Dead,
    p2Dead,
  };
}

/**
 * Generate crash particles at a grid position.
 * @param {number} gridX - grid cell x
 * @param {number} gridY - grid cell y
 * @param {string} color - particle color
 * @returns {Array} particle array
 */
export function createCrashParticles(gridX, gridY, color) {
  const px = GRID_OFFSET_X + gridX * CELL_SIZE + CELL_SIZE / 2;
  const py = GRID_OFFSET_Y + gridY * CELL_SIZE + CELL_SIZE / 2;
  const particles = [];
  for (let i = 0; i < 12; i++) {
    const angle = Math.random() * Math.PI * 2;
    const speed = 2 + Math.random() * 4;
    particles.push({
      x: px,
      y: py,
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
