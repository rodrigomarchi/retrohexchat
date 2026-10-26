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
import { gameColor } from "../../game_colors.js";
import {
  drawBackground,
  drawCountdown,
  drawDigit,
  drawGetReady,
  drawGlitchBanner,
  drawGrid,
  drawParticleDots,
  drawScanlines,
  drawVignette,
  drawWaiting,
} from "../core/render.js";
import { drawNeonBall, drawNeonPaddle } from "../core/neon.js";

export { neonColors as getColors } from "../core/neon.js";

/**
 * Render a full frame of the game.
 * @param {CanvasRenderingContext2D} ctx
 * @param {object} state - game state
 * @param {object} colors - color palette
 * @param {number} time - timestamp for animations
 */
export function render(ctx, state, colors, time) {
  drawBackground(ctx, colors, CANVAS_W, CANVAS_H);
  drawGrid(ctx, colors, CANVAS_W, CANVAS_H, { alpha: 0.2 });

  // Draw blocks
  if (state.blocks) {
    drawBlocks(ctx, state.blocks, colors, time);
  }

  if (state.particles && state.particles.length > 0) {
    drawParticleDots(ctx, state.particles);
  }

  // Bottom paddle (P1 — cyan)
  drawNeonPaddle(
    ctx,
    state.paddle1X,
    CANVAS_H - PADDLE_MARGIN - PADDLE_H,
    PADDLE_W,
    PADDLE_H,
    colors.fg,
  );
  // Top paddle (P2 — pink)
  drawNeonPaddle(ctx, state.paddle2X, PADDLE_MARGIN, PADDLE_W, PADDLE_H, colors.accent);

  if (state.phase === PHASE.PLAYING || state.phase === PHASE.LIFE_LOST) {
    drawNeonBall(ctx, state, BALL_SIZE, colors.fg, time);
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
