/**
 * Canvas renderer for Hex Boxing.
 * Reads game state and draws to a 640×480 canvas.
 * All colors come from CSS custom properties.
 * @module games/hex_boxing_renderer
 */

import {
  CANVAS_W,
  CANVAS_H,
  RING_LEFT,
  RING_RIGHT,
  RING_TOP,
  RING_BOTTOM,
  BOXER_BODY_RADIUS,
  PUNCH_RANGE,
  PUNCH_DURATION,
  FIST_RADIUS,
  KO_SCORE,
  DIR_DX,
  DIR_DY,
} from "./physics.js";
import { PHASE, PUNCH_STATE } from "./protocol.js";

/**
 * Read CSS custom properties from the canvas element.
 * @param {HTMLCanvasElement} canvas
 * @returns {object}
 */
export function getColors(canvas) {
  const s = getComputedStyle(canvas);
  return {
    bg: s.getPropertyValue("--game-bg-color").trim() || "#0a0808",
    fg: s.getPropertyValue("--game-fg-color").trim() || "#39ff14",
    accent: s.getPropertyValue("--game-accent-color").trim() || "#00e5ff",
    muted: s.getPropertyValue("--game-muted-color").trim() || "#2a1a1a",
    glow: s.getPropertyValue("--game-glow-color").trim() || "rgba(57, 255, 20, 0.15)",
    warning: s.getPropertyValue("--game-warning-color").trim() || "#ff4444",
    rope: s.getPropertyValue("--game-rope-color").trim() || "#aaaaaa",
    ring: s.getPropertyValue("--game-ring-color").trim() || "#1a1208",
    hit: s.getPropertyValue("--game-hit-color").trim() || "#ffffff",
  };
}

/**
 * Main render function.
 * @param {CanvasRenderingContext2D} ctx
 * @param {object} state
 * @param {object} colors
 * @param {number} frameCount
 * @param {Array} particles
 */
export function render(ctx, state, colors, _frameCount, particles) {
  drawBackground(ctx, colors);
  drawRing(ctx, colors);
  drawBoxer(ctx, state, 1, colors.fg, colors);
  drawBoxer(ctx, state, 2, colors.accent, colors);
  drawParticles(ctx, particles);
  drawHUD(ctx, state, colors, _frameCount);
  drawPhaseOverlay(ctx, state, colors, _frameCount);
}

// --- Background & Ring ---

function drawBackground(ctx, colors) {
  ctx.fillStyle = colors.bg;
  ctx.fillRect(0, 0, CANVAS_W, CANVAS_H);
}

function drawRing(ctx, colors) {
  // Ring floor
  ctx.fillStyle = colors.ring;
  ctx.fillRect(RING_LEFT, RING_TOP, RING_RIGHT - RING_LEFT, RING_BOTTOM - RING_TOP);

  // Ring ropes (double border)
  ctx.strokeStyle = colors.rope;
  ctx.lineWidth = 2;
  ctx.strokeRect(RING_LEFT, RING_TOP, RING_RIGHT - RING_LEFT, RING_BOTTOM - RING_TOP);
  ctx.lineWidth = 1;
  ctx.strokeRect(
    RING_LEFT - 4,
    RING_TOP - 4,
    RING_RIGHT - RING_LEFT + 8,
    RING_BOTTOM - RING_TOP + 8,
  );

  // Corner posts
  const postSize = 6;
  ctx.fillStyle = colors.rope;
  ctx.fillRect(RING_LEFT - postSize / 2, RING_TOP - postSize / 2, postSize, postSize);
  ctx.fillRect(RING_RIGHT - postSize / 2, RING_TOP - postSize / 2, postSize, postSize);
  ctx.fillRect(RING_LEFT - postSize / 2, RING_BOTTOM - postSize / 2, postSize, postSize);
  ctx.fillRect(RING_RIGHT - postSize / 2, RING_BOTTOM - postSize / 2, postSize, postSize);
}

// --- Boxer rendering ---

function drawBoxer(ctx, state, player, color, colors) {
  const prefix = player === 1 ? "b1" : "b2";
  const bx = state[`${prefix}x`];
  const by = state[`${prefix}y`];
  const dir = state[`${prefix}dir`];
  const punchState = state[`${prefix}punchState`];
  const punchTimer = state[`${prefix}punchTimer`];
  const arm = state[`${prefix}arm`];

  // Hit flash: white overlay briefly when this boxer was just hit by opponent
  const wasHit = state.lastHitPlayer !== 0 && state.lastHitPlayer !== player;
  const bodyColor = wasHit ? colors.hit : color;

  // Body (filled circle)
  ctx.beginPath();
  ctx.arc(bx, by, BOXER_BODY_RADIUS, 0, Math.PI * 2);
  ctx.fillStyle = bodyColor;
  ctx.fill();

  // Body outline
  ctx.strokeStyle = wasHit ? colors.hit : darkenColor(color);
  ctx.lineWidth = 1;
  ctx.stroke();

  // Arms
  const armColor = lightenColor(color);
  drawArms(ctx, bx, by, dir, punchState, punchTimer, arm, armColor, colors);

  // Facing indicator (small dot on facing edge)
  const dotX = bx + DIR_DX[dir] * (BOXER_BODY_RADIUS - 2);
  const dotY = by + DIR_DY[dir] * (BOXER_BODY_RADIUS - 2);
  ctx.beginPath();
  ctx.arc(dotX, dotY, 2, 0, Math.PI * 2);
  ctx.fillStyle = wasHit ? colors.hit : "#ffffff";
  ctx.fill();
}

function drawArms(ctx, bx, by, dir, punchState, punchTimer, arm, armColor, _colors) {
  // Perpendicular direction for arm offsets
  const perpDirLeft = (dir + 6) % 8; // 90 degrees counter-clockwise
  const perpDirRight = (dir + 2) % 8; // 90 degrees clockwise

  const armOffset = BOXER_BODY_RADIUS * 0.7;
  const restLength = BOXER_BODY_RADIUS * 0.8;

  // Left arm base position
  const lArmBaseX = bx + DIR_DX[perpDirLeft] * armOffset;
  const lArmBaseY = by + DIR_DY[perpDirLeft] * armOffset;

  // Right arm base position
  const rArmBaseX = bx + DIR_DX[perpDirRight] * armOffset;
  const rArmBaseY = by + DIR_DY[perpDirRight] * armOffset;

  // Calculate punch extension
  let punchExtension = 0;
  if (punchState === PUNCH_STATE.PUNCHING && punchTimer > 0) {
    const progress = 1 - (punchTimer - 1) / (PUNCH_DURATION - 1);
    const ext = progress <= 0.5 ? progress * 2 : (1 - progress) * 2;
    punchExtension = ext * PUNCH_RANGE;
  }

  // Draw left arm
  const lLength =
    arm === 0 && punchState === PUNCH_STATE.PUNCHING ? restLength + punchExtension : restLength;
  const lEndX = lArmBaseX + DIR_DX[dir] * lLength;
  const lEndY = lArmBaseY + DIR_DY[dir] * lLength;

  ctx.beginPath();
  ctx.moveTo(lArmBaseX, lArmBaseY);
  ctx.lineTo(lEndX, lEndY);
  ctx.strokeStyle = armColor;
  ctx.lineWidth = 3;
  ctx.lineCap = "round";
  ctx.stroke();

  // Left fist
  ctx.beginPath();
  ctx.arc(lEndX, lEndY, FIST_RADIUS, 0, Math.PI * 2);
  ctx.fillStyle = armColor;
  ctx.fill();

  // Draw right arm
  const rLength =
    arm === 1 && punchState === PUNCH_STATE.PUNCHING ? restLength + punchExtension : restLength;
  const rEndX = rArmBaseX + DIR_DX[dir] * rLength;
  const rEndY = rArmBaseY + DIR_DY[dir] * rLength;

  ctx.beginPath();
  ctx.moveTo(rArmBaseX, rArmBaseY);
  ctx.lineTo(rEndX, rEndY);
  ctx.strokeStyle = armColor;
  ctx.lineWidth = 3;
  ctx.lineCap = "round";
  ctx.stroke();

  // Right fist
  ctx.beginPath();
  ctx.arc(rEndX, rEndY, FIST_RADIUS, 0, Math.PI * 2);
  ctx.fillStyle = armColor;
  ctx.fill();

  // Hit flash on fist when connecting
  if (punchState === PUNCH_STATE.PUNCHING && punchExtension > PUNCH_RANGE * 0.3) {
    const fistX = arm === 0 ? lEndX : rEndX;
    const fistY = arm === 0 ? lEndY : rEndY;
    ctx.beginPath();
    ctx.arc(fistX, fistY, FIST_RADIUS + 2, 0, Math.PI * 2);
    ctx.fillStyle = "rgba(255, 255, 255, 0.3)";
    ctx.fill();
  }
}

// --- Particles ---

/**
 * Create hit particles at the given position.
 * @param {number} x
 * @param {number} y
 * @param {number} points
 * @returns {Array}
 */
export function createHitParticles(x, y, points) {
  const count = points * 3;
  const particles = [];
  for (let i = 0; i < count; i++) {
    const angle = Math.random() * Math.PI * 2;
    const speed = 1 + Math.random() * 3;
    particles.push({
      x,
      y,
      vx: Math.cos(angle) * speed,
      vy: Math.sin(angle) * speed,
      life: 15 + Math.floor(Math.random() * 10),
      maxLife: 25,
    });
  }
  return particles;
}

/**
 * Update particles (tick + remove dead).
 * @param {Array} particles
 * @returns {Array}
 */
export function updateParticles(particles) {
  return particles
    .map((p) => ({
      ...p,
      x: p.x + p.vx,
      y: p.y + p.vy,
      vx: p.vx * 0.95,
      vy: p.vy * 0.95,
      life: p.life - 1,
    }))
    .filter((p) => p.life > 0);
}

function drawParticles(ctx, particles) {
  for (const p of particles) {
    const alpha = p.life / p.maxLife;
    ctx.beginPath();
    ctx.arc(p.x, p.y, 2, 0, Math.PI * 2);
    ctx.fillStyle = `rgba(255, 255, 255, ${alpha})`;
    ctx.fill();
  }
}

// --- HUD ---

function drawHUD(ctx, state, colors, frameCount) {
  const hudY = 16;

  // Score labels
  ctx.font = "bold 14px monospace";
  ctx.textBaseline = "top";

  // P1 score (left)
  ctx.textAlign = "left";
  ctx.fillStyle = colors.fg;
  ctx.fillText(`P1: ${state.score1}`, RING_LEFT + 4, hudY);

  // P2 score (right)
  ctx.textAlign = "right";
  ctx.fillStyle = colors.accent;
  ctx.fillText(`P2: ${state.score2}`, RING_RIGHT - 4, hudY);

  // Game title (center)
  ctx.textAlign = "center";
  ctx.fillStyle = colors.rope;
  ctx.fillText("BOXING", CANVAS_W / 2, hudY);

  // Timer (right of center)
  if (state.phase === PHASE.FIGHTING || state.phase === PHASE.ROUND_OVER) {
    const totalSec = Math.ceil(state.roundTimer / 60);
    const min = Math.floor(totalSec / 60);
    const sec = totalSec % 60;
    const timerStr = `${min}:${sec.toString().padStart(2, "0")}`;

    // Flash timer when low
    const timerWarning = state.roundTimer <= 900 && state.roundTimer > 0;
    const visible = !timerWarning || frameCount % 30 < 20;
    if (visible) {
      ctx.fillStyle = timerWarning ? colors.warning : colors.rope;
      ctx.fillText(timerStr, CANVAS_W / 2 + 80, hudY);
    }
  }

  // Score progress bars (bottom)
  const barY = CANVAS_H - 20;
  const barHeight = 8;
  const barWidth = (RING_RIGHT - RING_LEFT - 20) / 2;

  // P1 bar (left half)
  const bar1X = RING_LEFT + 4;
  ctx.fillStyle = colors.muted;
  ctx.fillRect(bar1X, barY, barWidth, barHeight);
  const p1Fill = Math.min(state.score1 / KO_SCORE, 1) * barWidth;
  ctx.fillStyle = colors.fg;
  ctx.fillRect(bar1X, barY, p1Fill, barHeight);

  // P2 bar (right half)
  const bar2X = RING_RIGHT - 4 - barWidth;
  ctx.fillStyle = colors.muted;
  ctx.fillRect(bar2X, barY, barWidth, barHeight);
  const p2Fill = Math.min(state.score2 / KO_SCORE, 1) * barWidth;
  ctx.fillStyle = colors.accent;
  ctx.fillRect(bar2X + barWidth - p2Fill, barY, p2Fill, barHeight);

  // Round indicators (dots)
  const dotY = CANVAS_H - 34;
  ctx.textAlign = "center";
  ctx.font = "10px monospace";
  ctx.fillStyle = colors.muted;
  ctx.fillText(`Round ${state.round}`, CANVAS_W / 2, dotY);

  // Round win dots
  for (let i = 0; i < 3; i++) {
    const dx = CANVAS_W / 2 - 20 + i * 20;
    ctx.beginPath();
    ctx.arc(dx, dotY + 12, 3, 0, Math.PI * 2);
    if (i < state.roundWins1) ctx.fillStyle = colors.fg;
    else ctx.fillStyle = colors.muted;
    ctx.fill();
  }
  for (let i = 0; i < 3; i++) {
    const dx = CANVAS_W / 2 + 40 + i * 20;
    ctx.beginPath();
    ctx.arc(dx, dotY + 12, 3, 0, Math.PI * 2);
    if (i < state.roundWins2) ctx.fillStyle = colors.accent;
    else ctx.fillStyle = colors.muted;
    ctx.fill();
  }
}

// --- Phase Overlays ---

function drawPhaseOverlay(ctx, state, colors, frameCount) {
  switch (state.phase) {
    case PHASE.COUNTDOWN:
      drawCenterText(ctx, `${state.countdown}`, 48, colors.hit);
      break;
    case PHASE.SPAWNING:
      drawCenterText(ctx, "FIGHT!", 36, colors.warning);
      break;
    case PHASE.ROUND_OVER: {
      // Derive round winner from current scores (not yet reset at this phase)
      const winner = state.score1 >= state.score2 ? "P1" : "P2";
      const winColor = winner === "P1" ? colors.fg : colors.accent;
      if (state.koPlayer > 0) {
        // KO flash effect
        const flash = frameCount % 10 < 5;
        if (flash) {
          ctx.fillStyle = "rgba(255, 255, 255, 0.1)";
          ctx.fillRect(0, 0, CANVAS_W, CANVAS_H);
        }
        drawCenterText(ctx, "KO!", 48, colors.warning);
      } else {
        drawCenterText(ctx, `ROUND ${state.round}`, 24, colors.rope);
        drawCenterTextOffset(ctx, `${winner} WINS`, 28, winColor, 30);
      }
      break;
    }
    case PHASE.MATCH_OVER: {
      const matchWinner = state.roundWins1 >= state.roundWins2 ? "P1" : "P2";
      const mColor = matchWinner === "P1" ? colors.fg : colors.accent;
      drawCenterText(ctx, "MATCH OVER", 24, colors.rope);
      drawCenterTextOffset(ctx, `${matchWinner} WINS!`, 36, mColor, 35);
      break;
    }
    default:
      break;
  }
}

function drawCenterText(ctx, text, size, color) {
  ctx.font = `bold ${size}px monospace`;
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillStyle = color;
  ctx.fillText(text, CANVAS_W / 2, CANVAS_H / 2);
}

function drawCenterTextOffset(ctx, text, size, color, yOffset) {
  ctx.font = `bold ${size}px monospace`;
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillStyle = color;
  ctx.fillText(text, CANVAS_W / 2, CANVAS_H / 2 + yOffset);
}

// --- Color Utilities ---

function darkenColor(hex) {
  return adjustBrightness(hex, -40);
}

function lightenColor(hex) {
  return adjustBrightness(hex, 40);
}

function adjustBrightness(hex, amount) {
  const clean = hex.replace("#", "");
  const r = Math.max(0, Math.min(255, parseInt(clean.substring(0, 2), 16) + amount));
  const g = Math.max(0, Math.min(255, parseInt(clean.substring(2, 4), 16) + amount));
  const b = Math.max(0, Math.min(255, parseInt(clean.substring(4, 6), 16) + amount));
  return `#${r.toString(16).padStart(2, "0")}${g.toString(16).padStart(2, "0")}${b.toString(16).padStart(2, "0")}`;
}
