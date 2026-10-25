/**
 * Canvas renderer for Hex Pong — cyberpunk post-apocalyptic aesthetic.
 * Pure rendering functions, no side effects beyond canvas drawing.
 * @module games/pong_renderer
 */

import { PHASE } from "./protocol.js";
import { CANVAS_W, CANVAS_H, PADDLE_W, PADDLE_H, PADDLE_MARGIN, BALL_SIZE } from "./physics.js";
import { t, jt } from "../../i18n.js";
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
 * @param {object} [options]
 * @param {"p2p_host"|"p2p_guest"|"solo"} [options.mode]
 */
export function render(ctx, state, colors, time, options = {}) {
  drawBackground(ctx, colors, CANVAS_W, CANVAS_H);
  drawGrid(ctx, colors);
  drawCenterLine(ctx, colors, time);

  if (state.particles && state.particles.length > 0) {
    drawParticles(ctx, state.particles, colors);
  }

  drawPaddle(ctx, PADDLE_MARGIN, state.paddle1Y, colors.fg, colors);
  drawPaddle(ctx, CANVAS_W - PADDLE_MARGIN - PADDLE_W, state.paddle2Y, colors.accent, colors);

  if (state.phase === PHASE.PLAYING || state.phase === PHASE.SCORED) {
    drawBall(ctx, state, colors, time);
  }

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
 * Draw subtle perspective grid lines for cyberpunk floor effect.
 */
export function drawGrid(ctx, colors) {
  ctx.strokeStyle = colors.muted;
  ctx.lineWidth = 0.5;
  ctx.globalAlpha = 0.3;

  // Vertical lines
  for (let x = 0; x <= CANVAS_W; x += 40) {
    ctx.beginPath();
    ctx.moveTo(x, 0);
    ctx.lineTo(x, CANVAS_H);
    ctx.stroke();
  }

  // Horizontal lines
  for (let y = 0; y <= CANVAS_H; y += 40) {
    ctx.beginPath();
    ctx.moveTo(0, y);
    ctx.lineTo(CANVAS_W, y);
    ctx.stroke();
  }

  ctx.globalAlpha = 1.0;
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
 * Draw a paddle with neon glow effect.
 */
export function drawPaddle(ctx, x, y, color, _colors) {
  // Glow
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

  // Trail ghosts (4 positions fading back)
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
