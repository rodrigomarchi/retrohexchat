/**
 * Canvas renderer for Hex Pong — cyberpunk post-apocalyptic aesthetic.
 * Pure rendering functions, no side effects beyond canvas drawing.
 * @module games/pong_renderer
 */

import { PHASE } from "./protocol.js";
import { CANVAS_W, CANVAS_H, PADDLE_W, PADDLE_H, PADDLE_MARGIN, BALL_SIZE } from "./physics.js";
import { t, jt } from "../../i18n.js";
import {
  drawBackground,
  drawCountdown,
  drawDigit,
  drawGetReady,
  drawGlitchBanner,
  drawGrid,
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
 * @param {object} [options]
 * @param {"p2p_host"|"p2p_guest"|"solo"} [options.mode]
 */
export function render(ctx, state, colors, time, options = {}) {
  drawBackground(ctx, colors, CANVAS_W, CANVAS_H);
  drawGrid(ctx, colors, CANVAS_W, CANVAS_H, { alpha: 0.3 });
  drawCenterLine(ctx, colors, time);

  if (state.particles && state.particles.length > 0) {
    drawParticles(ctx, state.particles, colors);
  }

  drawNeonPaddle(ctx, PADDLE_MARGIN, state.paddle1Y, PADDLE_W, PADDLE_H, colors.fg);
  drawNeonPaddle(
    ctx,
    CANVAS_W - PADDLE_MARGIN - PADDLE_W,
    state.paddle2Y,
    PADDLE_W,
    PADDLE_H,
    colors.accent,
  );

  if (state.phase === PHASE.PLAYING || state.phase === PHASE.SCORED) {
    drawNeonBall(ctx, state, BALL_SIZE, colors.fg, time);
  }

  // ex_dna:disable-for-lines:8 this game's own drawing
  drawScore(ctx, state.score1, state.score2, colors);

  if (state.phase === PHASE.COUNTDOWN) {
    drawCountdown(ctx, state.countdown, colors, time, CANVAS_W, CANVAS_H);
  } else if (state.phase === PHASE.SERVING) {
    drawGetReady(ctx, colors, time, CANVAS_W, CANVAS_H);
  } else if (state.phase === PHASE.WAITING) {
    drawWaiting(ctx, colors, time, CANVAS_W, CANVAS_H, { solo: options.mode === "solo" });
  } else if (state.phase === PHASE.FINISHED) {
    drawWinner(ctx, state.winner, colors, time);
  }

  drawScanlines(ctx, CANVAS_W, CANVAS_H);
  drawVignette(ctx, CANVAS_W, CANVAS_H);
}

/**
 * Draw animated dashed center line with pulse glow.
 */
export function drawCenterLine(ctx, colors, time) {
  const centerX = CANVAS_W / 2;
  const pulse = 0.4 + 0.2 * Math.sin(time * 0.003);

  ctx.strokeStyle = colors.muted;
  ctx.lineWidth = 2;
  ctx.globalAlpha = pulse;
  ctx.setLineDash([12, 8]);

  ctx.beginPath();
  ctx.moveTo(centerX, 0);
  ctx.lineTo(centerX, CANVAS_H);
  ctx.stroke();

  ctx.setLineDash([]);
  ctx.globalAlpha = 1.0;
}

/**
 * Draw bitmap score digits with neon glow.
 */
export function drawScore(ctx, score1, score2, colors) {
  const pixelSize = 4;
  const digitW = 5 * pixelSize;
  const gap = 12;
  const topY = 20;

  // Player 1 score (left side, cyan)
  const s1str = String(score1).padStart(2, " ");
  const s1x = CANVAS_W / 2 - gap - digitW * 2 - 8;
  drawDigitString(ctx, s1str, s1x, topY, pixelSize, colors.fg);

  // Player 2 score (right side, pink)
  const s2str = String(score2).padStart(2, " ");
  const s2x = CANVAS_W / 2 + gap;
  drawDigitString(ctx, s2str, s2x, topY, pixelSize, colors.accent);
}

/**
 * Draw a string of digit characters using bitmap font.
 */
function drawDigitString(ctx, str, startX, startY, pixelSize, color) {
  ctx.shadowColor = color;
  ctx.shadowBlur = 8;
  ctx.fillStyle = color;

  let x = startX;
  for (const ch of str) {
    if (ch === " ") {
      x += 5 * pixelSize + 4;
      continue;
    }
    const digit = parseInt(ch, 10);
    if (isNaN(digit)) {
      x += 5 * pixelSize + 4;
      continue;
    }
    drawDigit(ctx, digit, x, startY, pixelSize);
    x += 5 * pixelSize + 4;
  }

  ctx.shadowBlur = 0;
  ctx.shadowColor = "transparent";
}

/**
 * Draw winner announcement with glitch text effect.
 */
export function drawWinner(ctx, winner, colors, time) {
  const text = jt`PLAYER ${winner} WINS!`;
  const color = winner === 1 ? colors.fg : colors.accent;

  drawGlitchBanner(
    ctx,
    { text, color, sub: t("GAME OVER"), subColor: colors.muted },
    time,
    CANVAS_W,
    CANVAS_H,
  );
}

/**
 * Draw score celebration particles.
 */
export function drawParticles(ctx, particles, colors) {
  for (const p of particles) {
    ctx.globalAlpha = p.life;
    ctx.fillStyle = p.life > 0.5 ? colors.warning : colors.fg;
    ctx.fillRect(p.x - 2, p.y - 2, 4, 4);
  }
  ctx.globalAlpha = 1.0;
}
