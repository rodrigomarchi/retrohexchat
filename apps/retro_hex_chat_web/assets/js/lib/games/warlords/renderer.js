/**
 * Canvas renderer for Hex Warlords — cyberpunk castle battle aesthetic.
 * Pure rendering functions, no side effects beyond canvas drawing.
 * @module games/warlords_renderer
 */

import { PHASE } from "./protocol.js";
import {
  CANVAS_W,
  CANVAS_H,
  SHIELD_W,
  SHIELD_H,
  FIREBALL_SIZE,
  KING_SIZE,
  P1_SHIELD_X,
  P2_SHIELD_X,
  P1_KING_X,
  P1_KING_Y,
  P2_KING_X,
  P2_KING_Y,
  INITIAL_LIVES,
} from "./physics.js";

/**
 * Read CSS custom properties from canvas computed style.
 * @param {HTMLCanvasElement} canvas
 * @returns {object} color palette
 */
export function getColors(canvas) {
  const s = getComputedStyle(canvas);
  return {
    bg: s.getPropertyValue("--game-bg-color").trim() || "#0a0a1a",
    fg: s.getPropertyValue("--game-fg-color").trim() || "#00ff66",
    accent: s.getPropertyValue("--game-accent-color").trim() || "#00ccff",
    muted: s.getPropertyValue("--game-muted-color").trim() || "#1a3a4a",
    glow: s.getPropertyValue("--game-glow-color").trim() || "rgba(0,255,102,0.2)",
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

  // Draw castles
  if (state.p1Bricks) {
    drawBricks(ctx, state.p1Bricks, time);
  }
  if (state.p2Bricks) {
    drawBricks(ctx, state.p2Bricks, time);
  }

  // Draw kings
  drawKing(ctx, P1_KING_X, P1_KING_Y, state.p1KingAlive, colors.fg, time);
  drawKing(ctx, P2_KING_X, P2_KING_Y, state.p2KingAlive, colors.accent, time);

  // Draw shields
  drawShield(ctx, P1_SHIELD_X, state.shield1Y, colors.fg, time);
  drawShield(ctx, P2_SHIELD_X, state.shield2Y, colors.accent, time);

  // Draw particles
  if (state.particles && state.particles.length > 0) {
    drawParticles(ctx, state.particles);
  }

  // Draw fireball
  if (state.phase === PHASE.PLAYING || state.phase === PHASE.KING_HIT || state.caughtBy !== 0) {
    drawFireball(ctx, state, colors, time);
    if (state.caughtBy !== 0) {
      drawCatchIndicator(ctx, state, colors, time);
    }
  }

  // HUD
  drawHUD(ctx, state, colors, time);

  // Phase overlays
  if (state.phase === PHASE.COUNTDOWN) {
    drawCountdown(ctx, state.countdown, colors, time);
  } else if (state.phase === PHASE.WAITING) {
    drawWaiting(ctx, colors, time);
  } else if (state.phase === PHASE.KING_HIT) {
    drawKingHitOverlay(ctx, state, colors, time);
  } else if (state.phase === PHASE.FINISHED) {
    drawFinished(ctx, state, colors, time);
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
 * Draw subtle grid lines.
 */
export function drawGrid(ctx, colors) {
  ctx.strokeStyle = colors.muted;
  ctx.lineWidth = 0.5;
  ctx.globalAlpha = 0.15;

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
 * Draw bricks with neon glow effect.
 */
export function drawBricks(ctx, bricks, time) {
  for (const brick of bricks) {
    if (!brick.alive) continue;

    const pulse = 0.8 + 0.2 * Math.sin(time * 0.003 + brick.row * 0.5 + brick.col * 0.3);

    // Glow
    ctx.shadowColor = brick.color;
    ctx.shadowBlur = 6 * pulse;
    ctx.fillStyle = brick.color;
    ctx.globalAlpha = pulse;
    ctx.fillRect(brick.x, brick.y, brick.w, brick.h);

    // Inner highlight
    ctx.shadowBlur = 0;
    ctx.globalAlpha = 0.25;
    ctx.fillStyle = "#ffffff";
    ctx.fillRect(brick.x + 2, brick.y + 2, brick.w - 4, brick.h - 4);

    // Border
    ctx.globalAlpha = pulse;
    ctx.strokeStyle = brick.color;
    ctx.lineWidth = 1;
    ctx.strokeRect(brick.x - 0.5, brick.y - 0.5, brick.w + 1, brick.h + 1);

    ctx.globalAlpha = 1.0;
    ctx.shadowColor = "transparent";
  }
}

/**
 * Draw a king with pulsing glow.
 */
export function drawKing(ctx, x, y, alive, color, time) {
  const halfKing = KING_SIZE / 2;

  if (!alive) {
    // Dead king — faded outline
    ctx.globalAlpha = 0.2;
    ctx.strokeStyle = "#666666";
    ctx.lineWidth = 1;
    ctx.strokeRect(x - halfKing, y - halfKing, KING_SIZE, KING_SIZE);
    ctx.globalAlpha = 1.0;
    return;
  }

  const pulse = 0.7 + 0.3 * Math.sin(time * 0.004);

  // Glow
  ctx.shadowColor = color;
  ctx.shadowBlur = 12 * pulse;

  // Crown body
  ctx.fillStyle = color;
  ctx.globalAlpha = pulse;
  ctx.fillRect(x - halfKing, y - halfKing + 4, KING_SIZE, KING_SIZE - 4);

  // Crown points (3 triangles on top)
  ctx.beginPath();
  ctx.moveTo(x - halfKing, y - halfKing + 4);
  ctx.lineTo(x - halfKing + 2, y - halfKing);
  ctx.lineTo(x - halfKing + 4, y - halfKing + 4);
  ctx.moveTo(x - 2, y - halfKing + 4);
  ctx.lineTo(x, y - halfKing);
  ctx.lineTo(x + 2, y - halfKing + 4);
  ctx.moveTo(x + halfKing - 4, y - halfKing + 4);
  ctx.lineTo(x + halfKing - 2, y - halfKing);
  ctx.lineTo(x + halfKing, y - halfKing + 4);
  ctx.fill();

  // Bright core
  ctx.shadowBlur = 0;
  ctx.globalAlpha = 0.5;
  ctx.fillStyle = "#ffffff";
  ctx.fillRect(x - halfKing + 3, y - halfKing + 6, KING_SIZE - 6, KING_SIZE - 8);

  ctx.globalAlpha = 1.0;
  ctx.shadowColor = "transparent";
}

/**
 * Draw a vertical shield with neon glow.
 */
export function drawShield(ctx, x, y, color, _time) {
  ctx.shadowColor = color;
  ctx.shadowBlur = 15;
  ctx.fillStyle = color;
  ctx.fillRect(x, y, SHIELD_W, SHIELD_H);

  // Inner highlight
  ctx.shadowBlur = 0;
  ctx.fillStyle = "rgba(255,255,255,0.3)";
  ctx.fillRect(x + 2, y + 2, SHIELD_W - 4, SHIELD_H - 4);

  // Border frame
  ctx.strokeStyle = color;
  ctx.lineWidth = 1;
  ctx.strokeRect(x - 1, y - 1, SHIELD_W + 2, SHIELD_H + 2);

  ctx.shadowColor = "transparent";
}

/**
 * Draw fireball with glow bloom and motion trail.
 */
export function drawFireball(ctx, state, colors, time) {
  const { fireballX, fireballY, fireballVX, fireballVY } = state;
  const halfBall = FIREBALL_SIZE / 2;

  // Trail ghosts (only when moving)
  if (state.caughtBy === 0) {
    const trailAlphas = [0.15, 0.1, 0.06, 0.03];
    for (let i = trailAlphas.length - 1; i >= 0; i--) {
      const factor = (i + 1) * 2;
      const tx = fireballX - fireballVX * factor;
      const ty = fireballY - fireballVY * factor;
      ctx.globalAlpha = trailAlphas[i];
      ctx.fillStyle = colors.warning;
      ctx.fillRect(tx - halfBall, ty - halfBall, FIREBALL_SIZE, FIREBALL_SIZE);
    }
    ctx.globalAlpha = 1.0;
  }

  // Main fireball with glow
  ctx.shadowColor = "#ffffff";
  ctx.shadowBlur = 12 + 4 * Math.sin(time * 0.01);
  ctx.fillStyle = "#ffffff";
  ctx.fillRect(fireballX - halfBall, fireballY - halfBall, FIREBALL_SIZE, FIREBALL_SIZE);

  // Orange core
  ctx.shadowBlur = 0;
  ctx.fillStyle = colors.warning;
  ctx.fillRect(
    fireballX - halfBall + 2,
    fireballY - halfBall + 2,
    FIREBALL_SIZE - 4,
    FIREBALL_SIZE - 4,
  );

  ctx.shadowColor = "transparent";
}

/**
 * Draw catch indicator (pulsing ring around caught fireball).
 */
export function drawCatchIndicator(ctx, state, colors, time) {
  const color = state.caughtBy === 1 ? colors.fg : colors.accent;
  const pulse = 0.5 + 0.5 * Math.sin(time * 0.01);
  const radius = FIREBALL_SIZE + 4 + pulse * 4;

  ctx.save();
  ctx.strokeStyle = color;
  ctx.lineWidth = 2;
  ctx.globalAlpha = 0.6 + 0.4 * pulse;
  ctx.beginPath();
  ctx.arc(state.fireballX, state.fireballY, radius, 0, Math.PI * 2);
  ctx.stroke();
  ctx.restore();
}

/**
 * Draw HUD (lives and round indicator).
 */
export function drawHUD(ctx, state, colors, _time) {
  // P1 lives (left side)
  drawLives(ctx, 10, CANVAS_H - 14, state.p1Lives, colors.fg);

  // P2 lives (right side)
  drawLives(ctx, CANVAS_W - 10 - INITIAL_LIVES * 12, CANVAS_H - 14, state.p2Lives, colors.accent);

  // Round indicator (top center)
  ctx.save();
  ctx.shadowColor = colors.muted;
  ctx.shadowBlur = 4;
  ctx.fillStyle = colors.muted;
  ctx.font = "12px monospace";
  ctx.textAlign = "center";
  ctx.textBaseline = "top";
  ctx.fillText(`ROUND ${state.round}`, CANVAS_W / 2, 6);
  ctx.restore();

  // Title
  ctx.save();
  ctx.shadowColor = colors.warning;
  ctx.shadowBlur = 6;
  ctx.fillStyle = colors.warning;
  ctx.font = "bold 14px monospace";
  ctx.textAlign = "center";
  ctx.textBaseline = "top";
  ctx.fillText("HEX WARLORDS", CANVAS_W / 2, CANVAS_H - 18);
  ctx.restore();
}

/**
 * Draw lives as small squares.
 */
function drawLives(ctx, startX, y, lives, color) {
  const size = 6;
  const gap = 12;

  ctx.shadowColor = color;
  ctx.shadowBlur = 4;
  ctx.fillStyle = color;

  for (let i = 0; i < Math.min(lives, INITIAL_LIVES); i++) {
    ctx.fillRect(startX + i * gap, y - size, size, size);
  }

  ctx.shadowBlur = 0;
  ctx.shadowColor = "transparent";
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
  ctx.fillText(`WAITING FOR OPPONENT${dots}`, CANVAS_W / 2, CANVAS_H / 2);
  ctx.restore();
}

/**
 * Draw king hit overlay (brief flash).
 */
export function drawKingHitOverlay(ctx, state, colors, time) {
  const hitPlayer = state.kingHitPlayer || 0;
  const color = hitPlayer === 1 ? colors.fg : colors.accent;
  const text = hitPlayer === 1 ? "P1 KING HIT!" : "P2 KING HIT!";
  const pulse = 0.5 + 0.5 * Math.sin(time * 0.015);

  ctx.save();
  ctx.font = "bold 28px monospace";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";

  // Glitch offset
  const glitchX = Math.random() > 0.85 ? (Math.random() - 0.5) * 4 : 0;

  ctx.globalAlpha = 0.5;
  ctx.fillStyle = "#ff0000";
  ctx.fillText(text, CANVAS_W / 2 + glitchX - 2, CANVAS_H / 2);
  ctx.fillStyle = "#0000ff";
  ctx.fillText(text, CANVAS_W / 2 + glitchX + 2, CANVAS_H / 2);

  ctx.globalAlpha = pulse;
  ctx.shadowColor = color;
  ctx.shadowBlur = 20;
  ctx.fillStyle = color;
  ctx.fillText(text, CANVAS_W / 2, CANVAS_H / 2);
  ctx.restore();
}

/**
 * Draw victory or game over with glitch text effect.
 */
export function drawFinished(ctx, state, colors, time) {
  const winner = state.winner || 0;
  const isP1 = winner === 1;
  const text = isP1 ? "P1 WINS!" : "P2 WINS!";
  const color = isP1 ? colors.fg : colors.accent;

  ctx.save();
  ctx.font = "bold 36px monospace";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";

  // Glitch effect
  const glitchX = Math.random() > 0.9 ? (Math.random() - 0.5) * 4 : 0;
  const glitchY = Math.random() > 0.9 ? (Math.random() - 0.5) * 2 : 0;

  ctx.globalAlpha = 0.5;
  ctx.fillStyle = "#ff0000";
  ctx.fillText(text, CANVAS_W / 2 + glitchX - 2, CANVAS_H / 2 + glitchY);
  ctx.fillStyle = "#0000ff";
  ctx.fillText(text, CANVAS_W / 2 + glitchX + 2, CANVAS_H / 2 + glitchY);

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
  ctx.fillText(`${state.p1Lives} - ${state.p2Lives}`, CANVAS_W / 2, CANVAS_H / 2 + 40);

  ctx.restore();
}

/**
 * Draw destruction particles.
 */
export function drawParticles(ctx, particles) {
  for (const p of particles) {
    ctx.globalAlpha = p.life;
    ctx.fillStyle = p.color || "#ffaa00";
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
