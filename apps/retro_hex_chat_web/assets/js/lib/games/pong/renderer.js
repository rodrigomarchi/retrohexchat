/**
 * Canvas renderer for Hex Pong — cyberpunk post-apocalyptic aesthetic.
 * Pure rendering functions, no side effects beyond canvas drawing.
 * @module games/pong_renderer
 */

import { PHASE } from "./protocol.js";
import { CANVAS_W, CANVAS_H, PADDLE_W, PADDLE_H, PADDLE_MARGIN, BALL_SIZE } from "./physics.js";
import { t, jt } from "../../i18n.js";

// Bitmap digits 5x7 for retro score display (each row is a 5-bit mask)
const DIGITS = [
  [0x1f, 0x11, 0x11, 0x11, 0x11, 0x11, 0x1f], // 0
  [0x04, 0x0c, 0x04, 0x04, 0x04, 0x04, 0x0e], // 1
  [0x1f, 0x01, 0x01, 0x1f, 0x10, 0x10, 0x1f], // 2
  [0x1f, 0x01, 0x01, 0x1f, 0x01, 0x01, 0x1f], // 3
  [0x11, 0x11, 0x11, 0x1f, 0x01, 0x01, 0x01], // 4
  [0x1f, 0x10, 0x10, 0x1f, 0x01, 0x01, 0x1f], // 5
  [0x1f, 0x10, 0x10, 0x1f, 0x11, 0x11, 0x1f], // 6
  [0x1f, 0x01, 0x01, 0x02, 0x04, 0x04, 0x04], // 7
  [0x1f, 0x11, 0x11, 0x1f, 0x11, 0x11, 0x1f], // 8
  [0x1f, 0x11, 0x11, 0x1f, 0x01, 0x01, 0x1f], // 9
];

/**
 * Read CSS custom properties from canvas computed style.
 * @param {HTMLCanvasElement} canvas
 * @returns {object} color palette
 */
export function getColors(canvas) {
  const s = getComputedStyle(canvas);
  return {
    bg: s.getPropertyValue("--game-bg-color").trim() || "#0a0a1a",
    fg: s.getPropertyValue("--game-fg-color").trim() || "#00ffcc",
    accent: s.getPropertyValue("--game-accent-color").trim() || "#ff0066",
    muted: s.getPropertyValue("--game-muted-color").trim() || "#1a3a4a",
    glow: s.getPropertyValue("--game-glow-color").trim() || "rgba(0,255,204,0.2)",
    warning: s.getPropertyValue("--game-warning-color").trim() || "#ffaa00",
  };
}

/**
 * Render a full frame of the game.
 * @param {CanvasRenderingContext2D} ctx
 * @param {object} state - game state
 * @param {object} colors - color palette
 * @param {number} time - timestamp for animations
 */
export function render(ctx, state, colors, time) {
  drawBackground(ctx, colors);
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
    drawCountdown(ctx, state.countdown, colors, time);
  } else if (state.phase === PHASE.SERVING) {
    drawServing(ctx, colors, time);
  } else if (state.phase === PHASE.WAITING) {
    drawWaiting(ctx, colors, time);
  } else if (state.phase === PHASE.FINISHED) {
    drawWinner(ctx, state.winner, colors, time);
  }

  drawScanlines(ctx);
  drawVignette(ctx);
}

/**
 * Fill background.
 */
export function drawBackground(ctx, colors) {
  ctx.fillStyle = colors.bg;
  ctx.fillRect(0, 0, CANVAS_W, CANVAS_H);
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
  ctx.fillStyle = "#ffffff";
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
 * Draw a single bitmap digit.
 */
function drawDigit(ctx, digit, x, y, pixelSize) {
  const rows = DIGITS[digit];
  if (!rows) return;

  for (let row = 0; row < 7; row++) {
    for (let col = 0; col < 5; col++) {
      if (rows[row] & (0x10 >> col)) {
        ctx.fillRect(x + col * pixelSize, y + row * pixelSize, pixelSize, pixelSize);
      }
    }
  }
}

/**
 * Draw countdown number with pulse animation.
 */
export function drawCountdown(ctx, count, colors, time) {
  const pulse = 1.0 + 0.15 * Math.sin(time * 0.015);
  const size = Math.floor(80 * pulse);

  ctx.save();
  ctx.shadowColor = colors.warning;
  ctx.shadowBlur = 20;
  ctx.fillStyle = colors.warning;
  ctx.font = `bold ${size}px monospace`;
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText(String(count), CANVAS_W / 2, CANVAS_H / 2);
  ctx.restore();
}

/**
 * Draw "GET READY" with flicker effect.
 */
export function drawServing(ctx, colors, time) {
  const flicker = Math.sin(time * 0.02) > -0.3 ? 1.0 : 0.3;

  ctx.save();
  ctx.globalAlpha = flicker;
  ctx.shadowColor = colors.fg;
  ctx.shadowBlur = 12;
  ctx.fillStyle = colors.fg;
  ctx.font = "bold 24px monospace";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText(t("GET READY"), CANVAS_W / 2, CANVAS_H / 2);
  ctx.restore();
}

/**
 * Draw waiting message.
 */
export function drawWaiting(ctx, colors, time) {
  const dots = ".".repeat(Math.floor((time / 500) % 4));

  ctx.save();
  ctx.shadowColor = colors.muted;
  ctx.shadowBlur = 8;
  ctx.fillStyle = colors.muted;
  ctx.font = "18px monospace";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText(jt`WAITING FOR OPPONENT${dots}`, CANVAS_W / 2, CANVAS_H / 2);
  ctx.restore();
}

/**
 * Draw winner announcement with glitch text effect.
 */
export function drawWinner(ctx, winner, colors, time) {
  const text = jt`PLAYER ${winner} WINS!`;
  const color = winner === 1 ? colors.fg : colors.accent;

  ctx.save();
  ctx.font = "bold 36px monospace";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";

  // Glitch effect: offset RGB channels
  const glitchX = Math.random() > 0.9 ? (Math.random() - 0.5) * 4 : 0;
  const glitchY = Math.random() > 0.9 ? (Math.random() - 0.5) * 2 : 0;

  // Red channel offset
  ctx.globalAlpha = 0.5;
  ctx.fillStyle = "#ff0000";
  ctx.fillText(text, CANVAS_W / 2 + glitchX - 2, CANVAS_H / 2 + glitchY);

  // Blue channel offset
  ctx.fillStyle = "#0000ff";
  ctx.fillText(text, CANVAS_W / 2 + glitchX + 2, CANVAS_H / 2 + glitchY);

  // Main text
  ctx.globalAlpha = 1.0;
  ctx.shadowColor = color;
  ctx.shadowBlur = 20;
  ctx.fillStyle = color;
  ctx.fillText(text, CANVAS_W / 2, CANVAS_H / 2);

  // Sub text
  ctx.font = "16px monospace";
  ctx.shadowBlur = 8;
  ctx.fillStyle = colors.muted;
  const pulse = 0.5 + 0.5 * Math.sin(time * 0.005);
  ctx.globalAlpha = pulse;
  ctx.fillText(t("GAME OVER"), CANVAS_W / 2, CANVAS_H / 2 + 40);

  ctx.restore();
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

/**
 * Draw CRT scanline overlay.
 */
export function drawScanlines(ctx) {
  ctx.fillStyle = "rgba(0,0,0,0.08)";
  for (let y = 0; y < CANVAS_H; y += 2) {
    ctx.fillRect(0, y, CANVAS_W, 1);
  }
}

/**
 * Draw vignette (darkened edges).
 */
export function drawVignette(ctx) {
  const gradient = ctx.createRadialGradient(
    CANVAS_W / 2,
    CANVAS_H / 2,
    CANVAS_H * 0.4,
    CANVAS_W / 2,
    CANVAS_H / 2,
    CANVAS_H * 0.8,
  );
  gradient.addColorStop(0, "rgba(0,0,0,0)");
  gradient.addColorStop(1, "rgba(0,0,0,0.4)");
  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, CANVAS_W, CANVAS_H);
}
