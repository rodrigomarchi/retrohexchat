/**
 * Canvas renderer for Light Trails — cyberpunk post-apocalyptic aesthetic.
 * Pure rendering functions, no side effects beyond canvas drawing.
 * @module games/surround_renderer
 */

import { PHASE, GRID_W, GRID_H } from "./protocol.js";
import { CANVAS_W, CANVAS_H, CELL_SIZE, GRID_OFFSET_X, GRID_OFFSET_Y, CELL } from "./physics.js";
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
    bg: s.getPropertyValue("--game-bg-color").trim() || "#050510",
    fg: s.getPropertyValue("--game-fg-color").trim() || "#00ff41",
    accent: s.getPropertyValue("--game-accent-color").trim() || "#00d4ff",
    muted: s.getPropertyValue("--game-muted-color").trim() || "#0a1628",
    glow: s.getPropertyValue("--game-glow-color").trim() || "rgba(0,255,65,0.2)",
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
  drawArena(ctx, colors);
  drawGrid(ctx, colors);
  drawTrails(ctx, state, colors, time);
  drawHeads(ctx, state, colors, time);

  if (state.particles && state.particles.length > 0) {
    drawParticles(ctx, state.particles);
  }

  drawHUD(ctx, state, colors);

  if (state.phase === PHASE.COUNTDOWN) {
    drawCountdown(ctx, state.countdown, colors, time);
  } else if (state.phase === PHASE.ROUND_OVER) {
    drawRoundOver(ctx, state, colors, time);
  } else if (state.phase === PHASE.MATCH_OVER) {
    drawMatchOver(ctx, state, colors, time);
  } else if (state.phase === PHASE.WAITING) {
    drawWaiting(ctx, colors, time);
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
 * Draw the arena border with neon glow.
 */
export function drawArena(ctx, colors) {
  const x = GRID_OFFSET_X - 1;
  const y = GRID_OFFSET_Y - 1;
  const w = GRID_W * CELL_SIZE + 2;
  const h = GRID_H * CELL_SIZE + 2;

  ctx.shadowColor = colors.fg;
  ctx.shadowBlur = 10;
  ctx.strokeStyle = colors.fg;
  ctx.lineWidth = 2;
  ctx.strokeRect(x, y, w, h);

  ctx.shadowBlur = 0;
  ctx.shadowColor = "transparent";
}

/**
 * Draw subtle grid lines inside the arena.
 */
export function drawGrid(ctx, colors) {
  ctx.strokeStyle = colors.muted;
  ctx.lineWidth = 0.5;
  ctx.globalAlpha = 0.08;

  for (let gx = 0; gx <= GRID_W; gx++) {
    const px = GRID_OFFSET_X + gx * CELL_SIZE;
    ctx.beginPath();
    ctx.moveTo(px, GRID_OFFSET_Y);
    ctx.lineTo(px, GRID_OFFSET_Y + GRID_H * CELL_SIZE);
    ctx.stroke();
  }

  for (let gy = 0; gy <= GRID_H; gy++) {
    const py = GRID_OFFSET_Y + gy * CELL_SIZE;
    ctx.beginPath();
    ctx.moveTo(GRID_OFFSET_X, py);
    ctx.lineTo(GRID_OFFSET_X + GRID_W * CELL_SIZE, py);
    ctx.stroke();
  }

  ctx.globalAlpha = 1.0;
}

/**
 * Draw trail cells on the grid.
 * P1 trails are neon green (colors.fg), P2 trails are neon cyan (colors.accent).
 */
export function drawTrails(ctx, state, colors, time) {
  const pulse = 0.85 + 0.15 * Math.sin(time * 0.002);

  for (let gy = 0; gy < GRID_H; gy++) {
    for (let gx = 0; gx < GRID_W; gx++) {
      const cell = state.grid[gy][gx];
      if (cell === CELL.EMPTY) continue;

      // Skip head positions — they're drawn by drawHeads
      if (cell === CELL.P1_TRAIL && gx === state.p1.x && gy === state.p1.y) {
        continue;
      }
      if (cell === CELL.P2_TRAIL && gx === state.p2.x && gy === state.p2.y) {
        continue;
      }

      const color = cell === CELL.P1_TRAIL ? colors.fg : colors.accent;
      const px = GRID_OFFSET_X + gx * CELL_SIZE;
      const py = GRID_OFFSET_Y + gy * CELL_SIZE;

      ctx.shadowColor = color;
      ctx.shadowBlur = 6 * pulse;
      ctx.fillStyle = color;
      ctx.globalAlpha = 0.8 * pulse;
      ctx.fillRect(px + 1, py + 1, CELL_SIZE - 2, CELL_SIZE - 2);
    }
  }

  ctx.globalAlpha = 1.0;
  ctx.shadowBlur = 0;
  ctx.shadowColor = "transparent";
}

/**
 * Draw player heads with direction chevron and strong glow.
 */
export function drawHeads(ctx, state, colors, time) {
  const headPulse = 0.7 + 0.3 * Math.sin(time * 0.01);
  drawHead(ctx, state.p1.x, state.p1.y, state.p1.dir, colors.fg, headPulse);
  drawHead(ctx, state.p2.x, state.p2.y, state.p2.dir, colors.accent, headPulse);
}

/**
 * Draw a single player head.
 */
function drawHead(ctx, gx, gy, dir, color, pulse) {
  const px = GRID_OFFSET_X + gx * CELL_SIZE;
  const py = GRID_OFFSET_Y + gy * CELL_SIZE;
  const cx = px + CELL_SIZE / 2;
  const cy = py + CELL_SIZE / 2;

  // Bright glow
  ctx.shadowColor = color;
  ctx.shadowBlur = 14 * pulse;
  ctx.fillStyle = color;
  ctx.fillRect(px, py, CELL_SIZE, CELL_SIZE);

  // White bright core
  ctx.shadowBlur = 0;
  ctx.fillStyle = "#ffffff";
  ctx.fillRect(px + 2, py + 2, CELL_SIZE - 4, CELL_SIZE - 4);

  // Direction chevron
  ctx.fillStyle = color;
  ctx.beginPath();
  const s = CELL_SIZE * 0.3;
  switch (dir) {
    case 0: // UP
      ctx.moveTo(cx - s, cy + s * 0.5);
      ctx.lineTo(cx, cy - s);
      ctx.lineTo(cx + s, cy + s * 0.5);
      break;
    case 1: // DOWN
      ctx.moveTo(cx - s, cy - s * 0.5);
      ctx.lineTo(cx, cy + s);
      ctx.lineTo(cx + s, cy - s * 0.5);
      break;
    case 2: // LEFT
      ctx.moveTo(cx + s * 0.5, cy - s);
      ctx.lineTo(cx - s, cy);
      ctx.lineTo(cx + s * 0.5, cy + s);
      break;
    case 3: // RIGHT
      ctx.moveTo(cx - s * 0.5, cy - s);
      ctx.lineTo(cx + s, cy);
      ctx.lineTo(cx - s * 0.5, cy + s);
      break;
    default:
      break;
  }
  ctx.fill();

  ctx.shadowColor = "transparent";
}

/**
 * Draw particles from crash explosions.
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
 * Draw HUD: scores and round indicator.
 */
export function drawHUD(ctx, state, colors) {
  const pixelSize = 3;

  // P1 score (left, green)
  ctx.shadowColor = colors.fg;
  ctx.shadowBlur = 6;
  ctx.fillStyle = colors.fg;
  drawDigit(ctx, state.score1, 20, 8, pixelSize);

  // P2 score (right, cyan)
  ctx.shadowColor = colors.accent;
  ctx.fillStyle = colors.accent;
  drawDigit(ctx, state.score2, CANVAS_W - 40, 8, pixelSize);

  // Round indicator (center top)
  ctx.shadowColor = colors.muted;
  ctx.shadowBlur = 4;
  ctx.fillStyle = colors.muted;
  ctx.font = "12px monospace";
  ctx.textAlign = "center";
  ctx.textBaseline = "top";
  ctx.fillText(jt`ROUND ${state.round + 1}`, CANVAS_W / 2, 8);

  ctx.shadowBlur = 0;
  ctx.shadowColor = "transparent";
  ctx.textAlign = "start";
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
 * Draw round over overlay with winner indication.
 */
export function drawRoundOver(ctx, state, colors, _time) {
  const p1Won = state.p2Dead && !state.p1Dead;
  const draw = state.p1Dead && state.p2Dead;

  let text, color;
  if (draw) {
    text = "DRAW";
    color = colors.warning;
  } else if (p1Won) {
    text = t("P1 WINS ROUND");
    color = colors.fg;
  } else {
    text = t("P2 WINS ROUND");
    color = colors.accent;
  }

  // Glitch effect
  const glitchX = Math.random() > 0.9 ? (Math.random() - 0.5) * 4 : 0;
  const glitchY = Math.random() > 0.9 ? (Math.random() - 0.5) * 2 : 0;

  ctx.save();
  ctx.font = "bold 32px monospace";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";

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

  ctx.restore();
}

/**
 * Draw match over with glitch text effect.
 */
export function drawMatchOver(ctx, state, colors, time) {
  const p1Won = state.score1 >= state.score2;
  const text = p1Won ? t("P1 VICTORY!") : t("P2 VICTORY!");
  const color = p1Won ? colors.fg : colors.accent;

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

  // Score sub text
  ctx.font = "18px monospace";
  ctx.shadowBlur = 8;
  ctx.fillStyle = colors.warning;
  const pulse = 0.5 + 0.5 * Math.sin(time * 0.005);
  ctx.globalAlpha = pulse;
  ctx.fillText(`${state.score1} - ${state.score2}`, CANVAS_W / 2, CANVAS_H / 2 + 40);

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
  ctx.fillText(jt`WAITING FOR PARTNER${dots}`, CANVAS_W / 2, CANVAS_H / 2);
  ctx.restore();
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
