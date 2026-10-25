/**
 * Canvas renderer for Light Trails — cyberpunk post-apocalyptic aesthetic.
 * Pure rendering functions, no side effects beyond canvas drawing.
 * @module games/surround_renderer
 */

import { PHASE, GRID_W, GRID_H } from "./protocol.js";
import { CANVAS_W, CANVAS_H, CELL_SIZE, GRID_OFFSET_X, GRID_OFFSET_Y, CELL } from "./physics.js";
import { t, jt } from "../../i18n.js";
import { gameColor, readGameColors } from "../../game_colors.js";
import {
  drawBackground,
  drawCountdown,
  drawDigit,
  drawGlitchText,
  drawParticleDots,
  drawScanlines,
  drawVignette,
  drawWaiting,
  glitchJitter,
} from "../core/render.js";

/**
 * Read CSS custom properties from canvas computed style.
 * @param {HTMLCanvasElement} canvas
 * @returns {object} color palette
 */
export function getColors(canvas) {
  return readGameColors(canvas, {
    bg: ["--game-bg-color", "050510"],
    fg: ["--game-fg-color", "00ff41"],
    accent: ["--game-accent-color", "00d4ff"],
    muted: ["--game-muted-color", "0a1628"],
    glow: ["--game-glow-color", "rgba(0,255,65,0.2)"],
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
  drawArena(ctx, colors);
  drawGrid(ctx, colors);
  drawTrails(ctx, state, colors, time);
  drawHeads(ctx, state, colors, time);

  if (state.particles && state.particles.length > 0) {
    drawParticleDots(ctx, state.particles);
  }

  drawHUD(ctx, state, colors);

  if (state.phase === PHASE.COUNTDOWN) {
    drawCountdown(ctx, state.countdown, colors, time, CANVAS_W, CANVAS_H);
  } else if (state.phase === PHASE.ROUND_OVER) {
    drawRoundOver(ctx, state, colors, time);
  } else if (state.phase === PHASE.MATCH_OVER) {
    drawMatchOver(ctx, state, colors, time);
  } else if (state.phase === PHASE.WAITING) {
    drawWaiting(ctx, colors, time, CANVAS_W, CANVAS_H);
  }

  drawScanlines(ctx, CANVAS_W, CANVAS_H);
  drawVignette(ctx, CANVAS_W, CANVAS_H);
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
  ctx.fillStyle = gameColor("ffffff");
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
  const [glitchX, glitchY] = glitchJitter();

  ctx.save();
  ctx.font = "bold 32px monospace";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";

  drawGlitchText(ctx, text, CANVAS_W / 2, CANVAS_H / 2, color, { offset: [glitchX, glitchY] });

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
  const [glitchX, glitchY] = glitchJitter();

  drawGlitchText(ctx, text, CANVAS_W / 2, CANVAS_H / 2, color, { offset: [glitchX, glitchY] });

  // Score sub text
  ctx.font = "18px monospace";
  ctx.shadowBlur = 8;
  ctx.fillStyle = colors.warning;
  const pulse = 0.5 + 0.5 * Math.sin(time * 0.005);
  ctx.globalAlpha = pulse;
  ctx.fillText(`${state.score1} - ${state.score2}`, CANVAS_W / 2, CANVAS_H / 2 + 40);

  ctx.restore();
}
