/**
 * The neon look of the bat-and-ball games (Pong and Block Breakers): their
 * palette, the glowing paddle and the ball with its motion trail. Each game
 * passes its own sizes, since one paddle stands and the other lies down.
 * @module games/core/neon
 */

import { gameColor, readGameColors } from "../../game_colors.js";

/**
 * Read the palette from the canvas's CSS custom properties.
 * @param {HTMLCanvasElement} canvas
 * @returns {object} color palette
 */
export function neonColors(canvas) {
  return readGameColors(canvas, {
    bg: ["--game-bg-color", "0a0a1a"],
    fg: ["--game-fg-color", "00ffcc"],
    accent: ["--game-accent-color", "ff0066"],
    muted: ["--game-muted-color", "1a3a4a"],
    glow: ["--game-glow-color", "rgba(0,255,204,0.2)"],
    warning: ["--game-warning-color", "ffaa00"],
  });
}

/**
 * A paddle with a glow, an inner highlight and a frame.
 * @param {CanvasRenderingContext2D} ctx
 * @param {number} x
 * @param {number} y
 * @param {number} width
 * @param {number} height
 * @param {string} color
 */
export function drawNeonPaddle(ctx, x, y, width, height, color) {
  // Glow
  ctx.shadowColor = color;
  ctx.shadowBlur = 15;
  ctx.fillStyle = color;
  ctx.fillRect(x, y, width, height);

  // Inner highlight
  ctx.shadowBlur = 0;
  ctx.fillStyle = "rgba(255,255,255,0.3)";
  ctx.fillRect(x + 2, y + 2, width - 4, height - 4);

  // Border frame
  ctx.strokeStyle = color;
  ctx.lineWidth = 1;
  ctx.strokeRect(x - 1, y - 1, width + 2, height + 2);

  ctx.shadowColor = "transparent";
}

/**
 * The ball with a pulsing glow, a bright core and four fading copies behind
 * it along its velocity.
 * @param {CanvasRenderingContext2D} ctx
 * @param {{ballX: number, ballY: number, ballVX: number, ballVY: number}} state
 * @param {number} size - the ball's side
 * @param {string} color
 * @param {number} time - timestamp for the pulse
 */
export function drawNeonBall(ctx, state, size, color, time) {
  const { ballX, ballY, ballVX, ballVY } = state;
  const half = size / 2;

  // Trail ghosts (4 positions fading back)
  const trailAlphas = [0.15, 0.1, 0.06, 0.03];
  for (let i = trailAlphas.length - 1; i >= 0; i--) {
    const factor = (i + 1) * 2;
    const tx = ballX - ballVX * factor;
    const ty = ballY - ballVY * factor;
    ctx.globalAlpha = trailAlphas[i];
    ctx.fillStyle = color;
    ctx.fillRect(tx - half, ty - half, size, size);
  }
  ctx.globalAlpha = 1.0;

  // Main ball with glow
  ctx.shadowColor = color;
  ctx.shadowBlur = 12 + 4 * Math.sin(time * 0.01);
  ctx.fillStyle = color;
  ctx.fillRect(ballX - half, ballY - half, size, size);

  // Bright core
  ctx.shadowBlur = 0;
  ctx.fillStyle = gameColor("ffffff");
  ctx.fillRect(ballX - half + 2, ballY - half + 2, size - 4, size - 4);

  ctx.shadowColor = "transparent";
}
