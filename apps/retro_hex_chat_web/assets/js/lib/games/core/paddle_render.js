/**
 * What the bat-and-ball games (Hex Pong, Block Breakers, Hex Warlords) share
 * in their drawing: the arena under the play, the screen glass over it, the
 * overlays before play, and lives as a row of squares.
 *
 * @module games/core/paddle_render
 */

import {
  drawBackground,
  drawCountdown,
  drawGetReady,
  drawGrid,
  drawScanlines,
  drawVignette,
  drawWaiting,
} from "./render.js";

const LIFE_SIZE = 6;
const LIFE_GAP = 12;

/**
 * The background and its grid.
 * @param {CanvasRenderingContext2D} ctx
 * @param {object} colors
 * @param {number} width
 * @param {number} height
 * @param {number} gridAlpha
 */
export function drawArena(ctx, colors, width, height, gridAlpha) {
  drawBackground(ctx, colors, width, height);
  drawGrid(ctx, colors, width, height, { alpha: gridAlpha });
}

/**
 * The screen's scanlines and vignette over everything.
 * @param {CanvasRenderingContext2D} ctx
 * @param {number} width
 * @param {number} height
 */
export function drawGlass(ctx, width, height) {
  drawScanlines(ctx, width, height);
  drawVignette(ctx, width, height);
}

/**
 * The overlay of a phase before play: the countdown, "get ready" while
 * serving, or the wait for the other player.
 * @param {CanvasRenderingContext2D} ctx
 * @param {object} state
 * @param {object} colors
 * @param {number} time
 * @param {{ COUNTDOWN: number, SERVING?: number, WAITING: number }} phases - the game's PHASE
 * @param {{ width: number, height: number, waiting?: object }} screen - the canvas and drawWaiting's options
 * @returns {boolean} whether the phase was one of these
 */
export function drawStartOverlay(ctx, state, colors, time, phases, { width, height, waiting }) {
  if (state.phase === phases.COUNTDOWN) {
    drawCountdown(ctx, state.countdown, colors, time, width, height);
  } else if (state.phase === phases.SERVING) {
    drawGetReady(ctx, colors, time, width, height);
  } else if (state.phase === phases.WAITING) {
    drawWaiting(ctx, colors, time, width, height, waiting);
  } else {
    return false;
  }
  return true;
}

/**
 * Lives as glowing squares in a row from (`x`, `y`), at most `max` of them.
 * @param {CanvasRenderingContext2D} ctx
 * @param {number} x
 * @param {number} y - the row's bottom edge
 * @param {number} lives
 * @param {number} max
 * @param {string} color
 */
export function drawLifeSquares(ctx, x, y, lives, max, color) {
  ctx.shadowColor = color;
  ctx.shadowBlur = 4;
  ctx.fillStyle = color;

  for (let i = 0; i < Math.min(lives, max); i++) {
    ctx.fillRect(x + i * LIFE_GAP, y - LIFE_SIZE, LIFE_SIZE, LIFE_SIZE);
  }

  ctx.shadowBlur = 0;
  ctx.shadowColor = "transparent";
}
