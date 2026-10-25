/**
 * Canvas renderer for Block Breakers — cyberpunk post-apocalyptic aesthetic.
 * Pure rendering functions, no side effects beyond canvas drawing.
 * @module games/breakout_renderer
 */

import { PHASE } from "./protocol.js";
import {
  CANVAS_W,
  CANVAS_H,
  PADDLE_W,
  PADDLE_H,
  PADDLE_MARGIN,
  BALL_SIZE,
  INITIAL_LIVES,
} from "./physics.js";
import { t } from "../../i18n.js";
import { gameColor, readGameColors } from "../../game_colors.js";
import {
  drawBackground,
  drawCountdown,
  drawDigit,
  drawGetReady,
  drawGlitchBanner,
  drawScanlines,
  drawVignette,
  drawWaiting,
} from "../core/render.js";

/**
 * Read CSS custom properties from canvas computed style.
 * @param {HTMLCanvasElement} canvas
 * @returns {object} color palette
 */
export function getColors(canvas) {
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
 * Render a full frame of the game.
 * @param {CanvasRenderingContext2D} ctx
 * @param {object} state - game state
 * @param {object} colors - color palette
 * @param {number} time - timestamp for animations
 */
export function render(ctx, state, colors, time) {
  drawBackground(ctx, colors, CANVAS_W, CANVAS_H);
  drawGrid(ctx, colors);

  // Draw blocks
  if (state.blocks) {
    drawBlocks(ctx, state.blocks, colors, time);
  }

  if (state.particles && state.particles.length > 0) {
    drawParticles(ctx, state.particles, colors);
  }

  // Bottom paddle (P1 — cyan)
  drawPaddle(ctx, state.paddle1X, CANVAS_H - PADDLE_MARGIN - PADDLE_H, colors.fg);
  // Top paddle (P2 — pink)
  drawPaddle(ctx, state.paddle2X, PADDLE_MARGIN, colors.accent);

  if (state.phase === PHASE.PLAYING || state.phase === PHASE.LIFE_LOST) {
    drawBall(ctx, state, colors, time);
  }

  drawScore(ctx, state.score, colors);
  drawLives(ctx, state.lives, colors);

  if (state.phase === PHASE.COUNTDOWN) {
    drawCountdown(ctx, state.countdown, colors, time, CANVAS_W, CANVAS_H);
  } else if (state.phase === PHASE.SERVING) {
    drawGetReady(ctx, colors, time, CANVAS_W, CANVAS_H);
  } else if (state.phase === PHASE.WAITING) {
    drawWaiting(ctx, colors, time, CANVAS_W, CANVAS_H, { partner: true });
  } else if (state.phase === PHASE.FINISHED) {
    drawFinished(ctx, state.won, colors, time);
  }

  drawScanlines(ctx, CANVAS_W, CANVAS_H);
  drawVignette(ctx, CANVAS_W, CANVAS_H);
}

/**
 * Draw subtle perspective grid lines.
 */
export function drawGrid(ctx, colors) {
  ctx.strokeStyle = colors.muted;
  ctx.lineWidth = 0.5;
  ctx.globalAlpha = 0.2;

  for (let x = 0; x <= CANVAS_W; x += 40) {
    ctx.beginPath();
    ctx.moveTo(x, 0);
    ctx.lineTo(x, CANVAS_H);
    ctx.stroke();
  }

  for (let y = 0; y <= CANVAS_H; y += 40) {
    ctx.beginPath();
    ctx.moveTo(0, y);
    ctx.lineTo(CANVAS_W, y);
    ctx.stroke();
  }

  ctx.globalAlpha = 1.0;
}

/**
 * Draw blocks with neon glow effect.
 */
export function drawBlocks(ctx, blocks, _colors, time) {
  for (const block of blocks) {
    if (!block.alive) continue;

    const pulse = 0.8 + 0.2 * Math.sin(time * 0.003 + block.row * 0.5);

    // Glow
    ctx.shadowColor = block.color;
    ctx.shadowBlur = 8 * pulse;
    ctx.fillStyle = block.color;
    ctx.globalAlpha = pulse;
    ctx.fillRect(block.x, block.y, block.w, block.h);

    // Inner highlight
    ctx.shadowBlur = 0;
    ctx.globalAlpha = 0.3;
    ctx.fillStyle = gameColor("ffffff");
    ctx.fillRect(block.x + 2, block.y + 2, block.w - 4, block.h - 4);

    // Border
    ctx.globalAlpha = pulse;
    ctx.strokeStyle = block.color;
    ctx.lineWidth = 1;
    ctx.strokeRect(block.x - 0.5, block.y - 0.5, block.w + 1, block.h + 1);

    ctx.globalAlpha = 1.0;
    ctx.shadowColor = "transparent";
  }
}

/**
 * Draw a horizontal paddle with neon glow effect.
 */
export function drawPaddle(ctx, x, y, color) {
  ctx.shadowColor = color;
  ctx.shadowBlur = 15;
  ctx.fillStyle = color;
  ctx.fillRect(x, y, PADDLE_W, PADDLE_H);

  // Inner highlight
  ctx.shadowBlur = 0;
  ctx.fillStyle = "rgba(255,255,255,0.3)";
  ctx.fillRect(x + 2, y + 2, PADDLE_W - 4, PADDLE_H - 4);

  // Border frame
  ctx.strokeStyle = color;
  ctx.lineWidth = 1;
  ctx.strokeRect(x - 1, y - 1, PADDLE_W + 2, PADDLE_H + 2);

  ctx.shadowColor = "transparent";
}

/**
 * Draw ball with glow bloom and motion trail.
 */
export function drawBall(ctx, state, colors, time) {
  const { ballX, ballY, ballVX, ballVY } = state;
  const halfBall = BALL_SIZE / 2;

  // Trail ghosts
  const trailAlphas = [0.15, 0.1, 0.06, 0.03];
  for (let i = trailAlphas.length - 1; i >= 0; i--) {
    const factor = (i + 1) * 2;
    const tx = ballX - ballVX * factor;
    const ty = ballY - ballVY * factor;
    ctx.globalAlpha = trailAlphas[i];
    ctx.fillStyle = colors.fg;
    ctx.fillRect(tx - halfBall, ty - halfBall, BALL_SIZE, BALL_SIZE);
  }
  ctx.globalAlpha = 1.0;

  // Main ball with glow
  ctx.shadowColor = colors.fg;
  ctx.shadowBlur = 12 + 4 * Math.sin(time * 0.01);
  ctx.fillStyle = colors.fg;
  ctx.fillRect(ballX - halfBall, ballY - halfBall, BALL_SIZE, BALL_SIZE);

  // Bright core
  ctx.shadowBlur = 0;
  ctx.fillStyle = gameColor("ffffff");
  ctx.fillRect(ballX - halfBall + 2, ballY - halfBall + 2, BALL_SIZE - 4, BALL_SIZE - 4);

  ctx.shadowColor = "transparent";
}

/**
 * Draw bitmap score centered at top.
 */
export function drawScore(ctx, score, colors) {
  const pixelSize = 3;
  const str = String(score).padStart(5, " ");
  const digitW = 5 * pixelSize;
  const totalW = str.length * (digitW + 3);
  const startX = (CANVAS_W - totalW) / 2;
  const topY = 8;

  ctx.shadowColor = colors.fg;
  ctx.shadowBlur = 6;
  ctx.fillStyle = colors.fg;

  let x = startX;
  for (const ch of str) {
    if (ch === " ") {
      x += digitW + 3;
      continue;
    }
    const digit = parseInt(ch, 10);
    if (!isNaN(digit)) {
      drawDigit(ctx, digit, x, topY, pixelSize);
    }
    x += digitW + 3;
  }

  ctx.shadowBlur = 0;
  ctx.shadowColor = "transparent";
}

/**
 * Draw lives as small ball icons in bottom-left corner.
 */
export function drawLives(ctx, lives, colors) {
  const startX = 10;
  const y = CANVAS_H - 10;
  const size = 6;
  const gap = 12;

  ctx.shadowColor = colors.warning;
  ctx.shadowBlur = 4;
  ctx.fillStyle = colors.warning;

  for (let i = 0; i < Math.min(lives, INITIAL_LIVES); i++) {
    ctx.fillRect(startX + i * gap, y - size, size, size);
  }

  ctx.shadowBlur = 0;
  ctx.shadowColor = "transparent";
}

/**
 * Draw victory or game over with glitch text effect.
 */
export function drawFinished(ctx, won, colors, time) {
  const text = won ? t("VICTORY!") : t("GAME OVER");
  const color = won ? colors.fg : colors.accent;

  const sub = won ? t("ALL BLOCKS CLEARED") : t("NO LIVES REMAINING");
  drawGlitchBanner(ctx, { text, color, sub, subColor: colors.muted }, time, CANVAS_W, CANVAS_H);
}

/**
 * Draw block destruction particles.
 */
export function drawParticles(ctx, particles, _colors) {
  for (const p of particles) {
    ctx.globalAlpha = p.life;
    ctx.fillStyle = p.color || gameColor("ffaa00");
    ctx.fillRect(p.x - 2, p.y - 2, 4, 4);
  }
  ctx.globalAlpha = 1.0;
}
