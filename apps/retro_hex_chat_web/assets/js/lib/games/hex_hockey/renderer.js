/**
 * Hex Hockey — Canvas renderer.
 *
 * Cyberpunk post-apocalyptic neon ice arena: dark background,
 * glowing rink lines, neon player sprites, puck trails, CRT scanlines.
 */

import {
  CANVAS_W,
  CANVAS_H,
  RINK_LEFT,
  RINK_RIGHT,
  RINK_TOP,
  RINK_BOTTOM,
  RINK_W,
  RINK_H,
  RINK_CX,
  RINK_CY,
  GOAL_DEPTH,
  GOAL_HEIGHT,
  GOAL_TOP,
  GOAL_BOTTOM,
  PLAYER_W,
  PLAYER_H,
  GOALIE_W,
  GOALIE_H,
  PUCK_R,
  CENTER_CIRCLE_R,
  CORNER_R,
  getGoalieXPositions,
  GOAL_CELEBRATION_FRAMES,
  SHOWDOWN_TARGET,
} from "./physics.js";
import { PHASE, GAME_MODE } from "./protocol.js";
import { t, jt } from "../../i18n.js";

// ── Direction vectors for stick drawing ────────────────────────
const SQRT2 = Math.SQRT1_2;
const DIR_VX = [1, SQRT2, 0, -SQRT2, -1, -SQRT2, 0, SQRT2];
const DIR_VY = [0, SQRT2, 1, SQRT2, 0, -SQRT2, -1, -SQRT2];

// ── Color reading ──────────────────────────────────────────────

/**
 * Read CSS custom properties from the canvas element.
 */
export function readColors(canvas) {
  const s = getComputedStyle(canvas);
  const get = (name) => s.getPropertyValue(name).trim() || null;
  return {
    bg: get("--game-bg-color") || "#060812",
    fg: get("--game-fg-color") || "#39ff14",
    accent: get("--game-accent-color") || "#00e5ff",
    muted: get("--game-muted-color") || "#0e1420",
    glow: get("--game-glow-color") || "rgba(57,255,20,0.15)",
    warning: get("--game-warning-color") || "#ff4444",
    rinkLine: get("--game-rink-line") || "#39ff1460",
    goalColor: get("--game-goal-color") || "#ff2222",
    goalieP1: get("--game-goalie-p1") || "#20aa0a",
    goalieP2: get("--game-goalie-p2") || "#0090aa",
    puck: get("--game-puck-color") || "#ffffff",
    puckTrail: get("--game-puck-trail") || "rgba(255,255,255,0.3)",
    iceScratch: get("--game-ice-scratch") || "#ffffff08",
  };
}

/**
 * Generate ice scratch particles (decorative).
 */
export function generateIceParticles(count) {
  const particles = [];
  for (let i = 0; i < count; i++) {
    particles.push({
      x: RINK_LEFT + Math.random() * RINK_W,
      y: RINK_TOP + Math.random() * RINK_H,
      angle: Math.random() * Math.PI,
      length: 8 + Math.random() * 20,
    });
  }
  return particles;
}

// ── Main render ────────────────────────────────────────────────

/**
 * Main render function.
 * @param {CanvasRenderingContext2D} ctx
 * @param {object} state - Game state (from physics or unpackState)
 * @param {object} colors - From readColors()
 * @param {number} frameCount
 * @param {object} fx - { iceParticles, puckTrail, goalFlash }
 */
export function render(ctx, state, colors, frameCount, fx) {
  // Clear
  ctx.fillStyle = colors.bg;
  ctx.fillRect(0, 0, CANVAS_W, CANVAS_H);

  if (!state) {
    drawWaitingScreen(ctx, colors, frameCount);
    return;
  }

  // Draw layers
  drawRink(ctx, colors, fx.iceParticles);
  drawGoals(ctx, state, colors, frameCount, fx.goalFlash);
  drawCenterLine(ctx, colors);
  drawCenterCircle(ctx, colors);
  drawGoalies(ctx, state, colors, frameCount);
  drawPlayers(ctx, state, colors, frameCount);
  drawPuck(ctx, state, colors, frameCount, fx.puckTrail);
  drawHUD(ctx, state, colors);

  // Overlay states
  if (state.phase === PHASE.COUNTDOWN || state.phase === PHASE.FACE_OFF) {
    drawFaceoff(ctx, state, colors, frameCount);
  }
  if (state.phase === PHASE.GOAL_CELEBRATION) {
    drawGoalCelebration(ctx, state, colors, frameCount);
  }
  if (state.phase === PHASE.PERIOD_BREAK) {
    drawPeriodBreak(ctx, state, colors, frameCount);
  }
  const maxP = state.mode === GAME_MODE.BLITZ ? 1 : 3;
  if (
    state.phase === PHASE.SUDDEN_DEATH ||
    (state.mode !== GAME_MODE.SHOWDOWN && state.period > maxP)
  ) {
    drawSuddenDeathOverlay(ctx, colors, frameCount);
  }
  if (state.phase === PHASE.FINISHED) {
    drawGameOver(ctx, state, colors, frameCount);
  }

  // CRT scanlines
  drawCRT(ctx, frameCount);
}

// ── Rink ───────────────────────────────────────────────────────

function drawRink(ctx, colors, iceParticles) {
  // Rink background (slightly lighter than canvas bg)
  ctx.fillStyle = colors.muted;
  ctx.fillRect(RINK_LEFT, RINK_TOP, RINK_W, RINK_H);

  // Ice scratch marks (decorative)
  if (iceParticles) {
    ctx.strokeStyle = colors.iceScratch;
    ctx.lineWidth = 0.5;
    for (const p of iceParticles) {
      ctx.beginPath();
      ctx.moveTo(p.x, p.y);
      ctx.lineTo(p.x + Math.cos(p.angle) * p.length, p.y + Math.sin(p.angle) * p.length);
      ctx.stroke();
    }
  }

  // Rink border (neon glow)
  ctx.strokeStyle = colors.fg;
  ctx.lineWidth = 2;
  ctx.globalAlpha = 0.6;

  // Draw rounded rink border
  const r = CORNER_R;
  ctx.beginPath();
  ctx.moveTo(RINK_LEFT + r, RINK_TOP);
  ctx.lineTo(RINK_RIGHT - r, RINK_TOP);
  ctx.arcTo(RINK_RIGHT, RINK_TOP, RINK_RIGHT, RINK_TOP + r, r);
  ctx.lineTo(RINK_RIGHT, GOAL_TOP);
  // Right goal opening gap
  ctx.moveTo(RINK_RIGHT, GOAL_BOTTOM);
  ctx.lineTo(RINK_RIGHT, RINK_BOTTOM - r);
  ctx.arcTo(RINK_RIGHT, RINK_BOTTOM, RINK_RIGHT - r, RINK_BOTTOM, r);
  ctx.lineTo(RINK_LEFT + r, RINK_BOTTOM);
  ctx.arcTo(RINK_LEFT, RINK_BOTTOM, RINK_LEFT, RINK_BOTTOM - r, r);
  ctx.lineTo(RINK_LEFT, GOAL_BOTTOM);
  // Left goal opening gap
  ctx.moveTo(RINK_LEFT, GOAL_TOP);
  ctx.lineTo(RINK_LEFT, RINK_TOP + r);
  ctx.arcTo(RINK_LEFT, RINK_TOP, RINK_LEFT + r, RINK_TOP, r);
  ctx.stroke();

  ctx.globalAlpha = 1.0;
}

// ── Goals ──────────────────────────────────────────────────────

function drawGoals(ctx, state, colors, frameCount, goalFlash) {
  // Left goal pocket
  drawGoalPocket(ctx, RINK_LEFT - GOAL_DEPTH, GOAL_TOP, GOAL_DEPTH, GOAL_HEIGHT, colors, false);
  // Right goal pocket
  drawGoalPocket(ctx, RINK_RIGHT, GOAL_TOP, GOAL_DEPTH, GOAL_HEIGHT, colors, true);

  // Goal flash effect
  if (goalFlash > 0) {
    const alpha = (goalFlash / GOAL_CELEBRATION_FRAMES) * 0.5;
    ctx.fillStyle = colors.goalColor;
    ctx.globalAlpha = alpha * (0.5 + 0.5 * Math.sin(frameCount * 0.3));
    ctx.fillRect(RINK_LEFT - GOAL_DEPTH, GOAL_TOP, GOAL_DEPTH, GOAL_HEIGHT);
    ctx.fillRect(RINK_RIGHT, GOAL_TOP, GOAL_DEPTH, GOAL_HEIGHT);
    ctx.globalAlpha = 1.0;
  }
}

function drawGoalPocket(ctx, x, y, w, h, colors, isRight) {
  // Dark pocket
  ctx.fillStyle = "#0a0000";
  ctx.fillRect(x, y, w, h);

  // Neon red border on goal opening
  ctx.strokeStyle = colors.goalColor;
  ctx.lineWidth = 2;
  ctx.globalAlpha = 0.8;
  ctx.beginPath();
  ctx.moveTo(isRight ? x : x + w, y);
  ctx.lineTo(isRight ? x + w : x, y);
  ctx.lineTo(isRight ? x + w : x, y + h);
  ctx.lineTo(isRight ? x : x + w, y + h);
  ctx.stroke();
  ctx.globalAlpha = 1.0;

  // Glow effect
  ctx.strokeStyle = colors.goalColor;
  ctx.globalAlpha = 0.2;
  ctx.lineWidth = 4;
  ctx.beginPath();
  ctx.moveTo(isRight ? x : x + w, y);
  ctx.lineTo(isRight ? x : x + w, y + h);
  ctx.stroke();
  ctx.globalAlpha = 1.0;
}

// ── Center line ────────────────────────────────────────────────

function drawCenterLine(ctx, colors) {
  ctx.strokeStyle = colors.rinkLine;
  ctx.lineWidth = 1;
  ctx.setLineDash([8, 6]);
  ctx.beginPath();
  ctx.moveTo(RINK_CX, RINK_TOP);
  ctx.lineTo(RINK_CX, RINK_BOTTOM);
  ctx.stroke();
  ctx.setLineDash([]);
}

// ── Center circle ──────────────────────────────────────────────

function drawCenterCircle(ctx, colors) {
  ctx.strokeStyle = colors.rinkLine;
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.arc(RINK_CX, RINK_CY, CENTER_CIRCLE_R, 0, Math.PI * 2);
  ctx.stroke();

  // Center dot
  ctx.fillStyle = colors.rinkLine;
  ctx.beginPath();
  ctx.arc(RINK_CX, RINK_CY, 3, 0, Math.PI * 2);
  ctx.fill();
}

// ── Players ────────────────────────────────────────────────────

function drawPlayers(ctx, state, colors, frameCount) {
  drawFieldPlayer(ctx, state.p1, colors.fg, colors, frameCount, true);
  drawFieldPlayer(ctx, state.p2, colors.accent, colors, frameCount, false);
}

function drawFieldPlayer(ctx, player, color, colors, frameCount, isP1) {
  const { x, y, facing, hasPuck, stunTimer } = player;

  // Stun flicker effect
  if (stunTimer > 0 && frameCount % 4 < 2) {
    ctx.globalAlpha = 0.3;
  }

  // Player body (pixel rectangle)
  const hw = PLAYER_W / 2;
  const hh = PLAYER_H / 2;

  // Glow
  ctx.fillStyle = color;
  ctx.globalAlpha = Math.max(ctx.globalAlpha, 0) * 0.2;
  ctx.fillRect(x - hw - 2, y - hh - 2, PLAYER_W + 4, PLAYER_H + 4);
  ctx.globalAlpha = stunTimer > 0 && frameCount % 4 < 2 ? 0.3 : 1.0;

  // Body
  ctx.fillStyle = color;
  ctx.fillRect(x - hw, y - hh, PLAYER_W, PLAYER_H);

  // Stick (line extending in facing direction)
  const stickLen = 6;
  const sx = x + DIR_VX[facing] * (hw + 1);
  const sy = y + DIR_VY[facing] * (hh + 1);
  const ex = sx + DIR_VX[facing] * stickLen;
  const ey = sy + DIR_VY[facing] * stickLen;

  ctx.strokeStyle = color;
  ctx.lineWidth = 1.5;
  ctx.beginPath();
  ctx.moveTo(sx, sy);
  ctx.lineTo(ex, ey);
  ctx.stroke();

  // Puck indicator on stick
  if (hasPuck) {
    ctx.fillStyle = colors.puck;
    ctx.beginPath();
    ctx.arc(ex, ey, PUCK_R, 0, Math.PI * 2);
    ctx.fill();
  }

  // Player number label
  ctx.fillStyle = color;
  ctx.globalAlpha = 0.7;
  ctx.font = "bold 7px monospace";
  ctx.textAlign = "center";
  ctx.fillText(isP1 ? "1" : "2", x, y - hh - 3);

  ctx.globalAlpha = 1.0;
}

// ── Goalies ────────────────────────────────────────────────────

function drawGoalies(ctx, state, colors, frameCount) {
  const { g1x, g2x } = getGoalieXPositions(state);
  drawGoalie(ctx, g1x, state.g1.y, colors.goalieP1, frameCount);
  drawGoalie(ctx, g2x, state.g2.y, colors.goalieP2, frameCount);
}

function drawGoalie(ctx, x, y, color, _frameCount) {
  const hw = GOALIE_W / 2;
  const hh = GOALIE_H / 2;

  // Glow
  ctx.fillStyle = color;
  ctx.globalAlpha = 0.15;
  ctx.fillRect(x - hw - 2, y - hh - 2, GOALIE_W + 4, GOALIE_H + 4);
  ctx.globalAlpha = 1.0;

  // Body (wider than field player)
  ctx.fillStyle = color;
  ctx.fillRect(x - hw, y - hh, GOALIE_W, GOALIE_H);

  // Border highlight
  ctx.strokeStyle = "#ffffff";
  ctx.globalAlpha = 0.3;
  ctx.lineWidth = 1;
  ctx.strokeRect(x - hw, y - hh, GOALIE_W, GOALIE_H);
  ctx.globalAlpha = 1.0;
}

// ── Puck ───────────────────────────────────────────────────────

function drawPuck(ctx, state, colors, frameCount, puckTrail) {
  const { x, y, vx, vy, possessedBy } = state.puck;

  // Don't draw puck separately if possessed (drawn on player's stick)
  if (possessedBy !== 0) return;

  const speed = Math.sqrt(vx * vx + vy * vy);

  // Trail effect for fast puck
  if (puckTrail && puckTrail.length > 0 && speed > 1.5) {
    for (let i = 0; i < puckTrail.length; i++) {
      const t = puckTrail[i];
      const alpha = ((puckTrail.length - i) / puckTrail.length) * 0.3;
      ctx.fillStyle = colors.puckTrail;
      ctx.globalAlpha = alpha;
      ctx.beginPath();
      ctx.arc(t.x, t.y, PUCK_R * 0.8, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.globalAlpha = 1.0;
  }

  // Puck body
  ctx.fillStyle = colors.puck;
  ctx.beginPath();
  ctx.arc(x, y, PUCK_R, 0, Math.PI * 2);
  ctx.fill();

  // Puck glow when moving fast
  if (speed > 3) {
    ctx.fillStyle = colors.puck;
    ctx.globalAlpha = 0.3;
    ctx.beginPath();
    ctx.arc(x, y, PUCK_R + 2, 0, Math.PI * 2);
    ctx.fill();
    ctx.globalAlpha = 1.0;
  }
}

// ── HUD ────────────────────────────────────────────────────────

function drawHUD(ctx, state, colors) {
  const y = 15;

  ctx.font = "bold 14px monospace";
  ctx.textAlign = "center";

  // Scores
  ctx.fillStyle = colors.fg;
  ctx.textAlign = "left";
  ctx.fillText(jt`P1: ${state.scoreP1}`, 30, y);

  ctx.fillStyle = colors.accent;
  ctx.textAlign = "right";
  ctx.fillText(jt`P2: ${state.scoreP2}`, CANVAS_W - 30, y);

  // Game title
  ctx.fillStyle = colors.puck || "#ffffff";
  ctx.globalAlpha = 0.5;
  ctx.textAlign = "center";
  ctx.font = "bold 10px monospace";
  ctx.fillText(t("HEX HOCKEY"), RINK_CX, y - 2);
  ctx.globalAlpha = 1.0;

  // Period & Timer
  ctx.font = "11px monospace";
  ctx.fillStyle = colors.fg;
  ctx.globalAlpha = 0.8;

  if (state.mode === GAME_MODE.SHOWDOWN) {
    ctx.fillText(jt`First to ${SHOWDOWN_TARGET}`, RINK_CX, y + 14);
  } else {
    const hudMaxP = state.mode === GAME_MODE.BLITZ ? 1 : 3;
    const isSudden = state.period > hudMaxP || state.phase === PHASE.SUDDEN_DEATH;
    const periodText = isSudden ? "SD" : `P${state.period}`;
    const timerSec = Math.ceil(state.timerFrames / 60);
    const min = Math.floor(timerSec / 60);
    const sec = timerSec % 60;
    const timerText = state.timerFrames > 0 ? `${min}:${String(sec).padStart(2, "0")}` : "";
    ctx.fillText(`${periodText}  ${timerText}`, RINK_CX, y + 14);
  }

  ctx.globalAlpha = 1.0;
}

// ── Face-off overlay ───────────────────────────────────────────

function drawFaceoff(ctx, state, colors, frameCount) {
  // Highlight center circle
  ctx.strokeStyle = colors.fg;
  ctx.globalAlpha = 0.4 + 0.2 * Math.sin(frameCount * 0.1);
  ctx.lineWidth = 3;
  ctx.beginPath();
  ctx.arc(RINK_CX, RINK_CY, CENTER_CIRCLE_R, 0, Math.PI * 2);
  ctx.stroke();
  ctx.globalAlpha = 1.0;

  // Countdown text
  if (state.countdownValue > 0) {
    ctx.font = "bold 48px monospace";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillStyle = colors.fg;
    ctx.globalAlpha = 0.9;
    ctx.fillText(String(state.countdownValue), RINK_CX, RINK_CY);
    ctx.globalAlpha = 1.0;
    ctx.textBaseline = "alphabetic";
  } else if (state.phase === PHASE.FACE_OFF) {
    // "GO!" flash
    ctx.font = "bold 48px monospace";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillStyle = colors.warning;
    ctx.globalAlpha = 0.5 + 0.5 * Math.sin(frameCount * 0.3);
    ctx.fillText(t("GO!"), RINK_CX, RINK_CY);
    ctx.globalAlpha = 1.0;
    ctx.textBaseline = "alphabetic";
  }
}

// ── Goal celebration ───────────────────────────────────────────

function drawGoalCelebration(ctx, state, colors, frameCount) {
  // Big "GOAL!" text
  ctx.font = "bold 40px monospace";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";

  // Pulsing color
  const pulse = 0.6 + 0.4 * Math.sin(frameCount * 0.2);
  ctx.fillStyle = colors.goalColor;
  ctx.globalAlpha = pulse;
  ctx.fillText(t("GOAL!"), RINK_CX, RINK_CY - 20);

  // Score display
  ctx.font = "bold 24px monospace";
  ctx.fillStyle = colors.puck || "#ffffff";
  ctx.globalAlpha = 0.9;
  ctx.fillText(`${state.scoreP1} — ${state.scoreP2}`, RINK_CX, RINK_CY + 20);

  ctx.globalAlpha = 1.0;
  ctx.textBaseline = "alphabetic";

  // Particles burst (simple star effect)
  const numParticles = 12;
  const progress =
    (GOAL_CELEBRATION_FRAMES - (state.celebrationFrames || 0)) / GOAL_CELEBRATION_FRAMES;
  for (let i = 0; i < numParticles; i++) {
    const angle = (i / numParticles) * Math.PI * 2 + frameCount * 0.05;
    const dist = 20 + progress * 80;
    const px = RINK_CX + Math.cos(angle) * dist;
    const py = RINK_CY + Math.sin(angle) * dist;
    ctx.fillStyle = i % 2 === 0 ? colors.fg : colors.accent;
    ctx.globalAlpha = 1 - progress;
    ctx.fillRect(px - 2, py - 2, 4, 4);
  }
  ctx.globalAlpha = 1.0;
}

// ── Period break ───────────────────────────────────────────────

function drawPeriodBreak(ctx, state, colors, _frameCount) {
  // Dim overlay
  ctx.fillStyle = "#000000";
  ctx.globalAlpha = 0.6;
  ctx.fillRect(0, 0, CANVAS_W, CANVAS_H);
  ctx.globalAlpha = 1.0;

  ctx.font = "bold 24px monospace";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillStyle = colors.fg;

  const prevPeriod = state.period - 1;
  ctx.fillText(jt`END OF PERIOD ${prevPeriod}`, RINK_CX, RINK_CY - 30);

  ctx.font = "bold 32px monospace";
  ctx.fillStyle = colors.puck || "#ffffff";
  ctx.fillText(`${state.scoreP1} — ${state.scoreP2}`, RINK_CX, RINK_CY + 10);

  ctx.font = "14px monospace";
  ctx.fillStyle = colors.accent;
  ctx.globalAlpha = 0.6;
  ctx.fillText(t("Switching sides..."), RINK_CX, RINK_CY + 45);

  ctx.globalAlpha = 1.0;
  ctx.textBaseline = "alphabetic";
}

// ── Sudden death overlay ───────────────────────────────────────

function drawSuddenDeathOverlay(ctx, colors, frameCount) {
  // Pulsing red border
  const pulse = 0.15 + 0.1 * Math.sin(frameCount * 0.08);
  ctx.strokeStyle = colors.warning;
  ctx.globalAlpha = pulse;
  ctx.lineWidth = 4;
  ctx.strokeRect(RINK_LEFT - 4, RINK_TOP - 4, RINK_W + 8, RINK_H + 8);
  ctx.globalAlpha = 1.0;

  // "SUDDEN DEATH" text at top
  ctx.font = "bold 12px monospace";
  ctx.textAlign = "center";
  ctx.fillStyle = colors.warning;
  ctx.globalAlpha = 0.5 + 0.3 * Math.sin(frameCount * 0.1);
  ctx.fillText(t("SUDDEN DEATH"), RINK_CX, RINK_TOP + 15);
  ctx.globalAlpha = 1.0;
}

// ── Game over ──────────────────────────────────────────────────

function drawGameOver(ctx, state, colors, _frameCount) {
  // Dim overlay
  ctx.fillStyle = "#000000";
  ctx.globalAlpha = 0.7;
  ctx.fillRect(0, 0, CANVAS_W, CANVAS_H);
  ctx.globalAlpha = 1.0;

  ctx.textAlign = "center";
  ctx.textBaseline = "middle";

  // Winner text
  ctx.font = "bold 28px monospace";
  if (state.scoreP1 > state.scoreP2) {
    ctx.fillStyle = colors.fg;
    ctx.fillText(t("PLAYER 1 WINS!"), RINK_CX, RINK_CY - 40);
  } else if (state.scoreP2 > state.scoreP1) {
    ctx.fillStyle = colors.accent;
    ctx.fillText(t("PLAYER 2 WINS!"), RINK_CX, RINK_CY - 40);
  } else {
    ctx.fillStyle = colors.puck || "#ffffff";
    ctx.fillText(t("DRAW!"), RINK_CX, RINK_CY - 40);
  }

  // Final score
  ctx.font = "bold 40px monospace";
  ctx.fillStyle = colors.puck || "#ffffff";
  ctx.fillText(`${state.scoreP1} — ${state.scoreP2}`, RINK_CX, RINK_CY + 10);

  // Period info
  ctx.font = "14px monospace";
  ctx.fillStyle = colors.fg;
  ctx.globalAlpha = 0.6;
  const periodText = state.period > 3 ? t("After Sudden Death") : `${state.period} Periods`;
  ctx.fillText(periodText, RINK_CX, RINK_CY + 50);

  ctx.globalAlpha = 1.0;
  ctx.textBaseline = "alphabetic";
}

// ── Waiting screen ─────────────────────────────────────────────

function drawWaitingScreen(ctx, colors, frameCount) {
  ctx.font = "bold 18px monospace";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillStyle = colors.fg;
  ctx.globalAlpha = 0.5 + 0.3 * Math.sin(frameCount * 0.05);
  ctx.fillText(t("Waiting for opponent..."), RINK_CX, RINK_CY);
  ctx.globalAlpha = 1.0;
  ctx.textBaseline = "alphabetic";
}

// ── CRT scanlines ──────────────────────────────────────────────

function drawCRT(ctx, _frameCount) {
  ctx.fillStyle = "rgba(0,0,0,0.06)";
  for (let y = 0; y < CANVAS_H; y += 3) {
    ctx.fillRect(0, y, CANVAS_W, 1);
  }

  // Subtle vignette
  const grd = ctx.createRadialGradient(RINK_CX, RINK_CY, 100, RINK_CX, RINK_CY, 400);
  grd.addColorStop(0, "rgba(0,0,0,0)");
  grd.addColorStop(1, "rgba(0,0,0,0.15)");
  ctx.fillStyle = grd;
  ctx.fillRect(0, 0, CANVAS_W, CANVAS_H);
}
