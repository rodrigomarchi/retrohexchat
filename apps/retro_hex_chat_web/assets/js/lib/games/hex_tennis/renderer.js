/**
 * Canvas renderer for Hex Tennis — cyberpunk post-apocalyptic aesthetic.
 * Pure rendering functions, no side effects beyond canvas drawing.
 * @module games/hex_tennis/renderer
 */

import { PHASE } from "./protocol.js";
import {
  CANVAS_W,
  CANVAS_H,
  COURT_LEFT,
  COURT_RIGHT,
  COURT_TOP,
  COURT_BOTTOM,
  COURT_W,
  COURT_H,
  NET_Y,
  SERVICE_LINE_TOP,
  SERVICE_LINE_BOTTOM,
  CENTER_LINE_X,
  BALL_RADIUS,
} from "./physics.js";
import { t, jt } from "../../i18n.js";
import { gameColor } from "../../game_colors.js";

// Point display names
const POINT_DISPLAY = ["LOVE", "15", "30", "40"];

// Announcement text
const ANN_MESSAGES = ["", "DEUCE", "ADVANTAGE P1", "ADVANTAGE P2", "GAME!", "TIEBREAK!"];

// Out type text
const OUT_MESSAGES = ["", "OUT!", "LONG!", "ACE!", "DEAD BALL"];

/**
 * Read CSS custom properties from canvas computed style.
 * @param {HTMLCanvasElement} canvas
 * @returns {object} color palette
 */
export function getColors(canvas) {
  const s = getComputedStyle(canvas);
  return {
    bg: s.getPropertyValue("--game-bg-color").trim() || gameColor("0a0a14"),
    fg: s.getPropertyValue("--game-fg-color").trim() || gameColor("39ff14"),
    accent: s.getPropertyValue("--game-accent-color").trim() || gameColor("00e5ff"),
    muted: s.getPropertyValue("--game-muted-color").trim() || gameColor("1a1a2a"),
    glow: s.getPropertyValue("--game-glow-color").trim() || "rgba(57,255,20,0.15)",
    warning: s.getPropertyValue("--game-warning-color").trim() || gameColor("ffaa00"),
    courtColor: s.getPropertyValue("--game-court-color").trim() || gameColor("0e1a0e"),
    lineColor: s.getPropertyValue("--game-line-color").trim() || gameColor("39ff1480"),
    netColor: s.getPropertyValue("--game-net-color").trim() || gameColor("ff006688"),
    ballColor: s.getPropertyValue("--game-ball-color").trim() || gameColor("ffee00"),
  };
}

/**
 * Get display text for a tennis point value.
 * @param {number} points
 * @param {number} opponentPoints
 * @param {boolean} isTiebreak
 * @returns {string}
 */
export function getPointText(points, opponentPoints, isTiebreak) {
  if (isTiebreak) return String(points);
  if (points <= 3) return POINT_DISPLAY[points];
  // Deuce/advantage territory
  if (points > opponentPoints) return "AD";
  return "40";
}

/**
 * Render a full frame of the game.
 * @param {CanvasRenderingContext2D} ctx
 * @param {object} state
 * @param {object} colors
 * @param {number} time
 */
export function render(ctx, state, colors, time) {
  drawBackground(ctx, colors);
  drawCourt(ctx, colors);
  drawNet(ctx, colors, time);

  // Draw players and ball during active phases
  if (state.phase !== PHASE.WAITING) {
    drawPlayer(
      ctx,
      state.p1x,
      state.p1y,
      colors.fg,
      state.server === 1 && state.phase === PHASE.SERVING,
      time,
    );
    drawPlayer(
      ctx,
      state.p2x,
      state.p2y,
      colors.accent,
      state.server === 2 && state.phase === PHASE.SERVING,
      time,
    );

    if (state.phase === PHASE.RALLY || state.phase === PHASE.POINT) {
      drawBall(ctx, state.ball, colors, time);
    }
  }

  drawScoreboard(ctx, state, colors);

  // Phase overlays
  if (state.phase === PHASE.WAITING) {
    drawWaiting(ctx, colors, time);
  } else if (state.phase === PHASE.COUNTDOWN) {
    drawCountdown(ctx, state.countdown, colors, time);
  } else if (state.phase === PHASE.SERVING) {
    drawServing(ctx, state, colors, time);
  } else if (state.phase === PHASE.GAME_OVER) {
    drawWinner(ctx, state, colors, time);
  }

  // Announcements (stacked with y-offset to avoid overlap)
  if (state.phase === PHASE.POINT || state.phase === PHASE.CHANGEOVER) {
    let annY = 0;
    if (state.announcement > 0) {
      drawAnnouncement(ctx, t(ANN_MESSAGES[state.announcement]), colors.warning, time, annY);
      annY += 36;
    }
    if (state.outOfBounds && state.outType > 0) {
      drawAnnouncement(ctx, t(OUT_MESSAGES[state.outType]), colors.accent, time, annY);
      annY += 36;
    }
    if (state.netFault) {
      drawAnnouncement(ctx, t("NET!"), colors.netColor || colors.accent, time, annY);
      annY += 36;
    }
    if (state.phase === PHASE.CHANGEOVER) {
      drawAnnouncement(ctx, "CHANGEOVER", colors.muted, time, annY);
    }
  }

  drawScanlines(ctx);
  drawVignette(ctx);
}

// --- Drawing functions ---

function drawBackground(ctx, colors) {
  ctx.fillStyle = colors.bg;
  ctx.fillRect(0, 0, CANVAS_W, CANVAS_H);
}

function drawCourt(ctx, colors) {
  // Court surface
  ctx.fillStyle = colors.courtColor;
  ctx.fillRect(COURT_LEFT, COURT_TOP, COURT_W, COURT_H);

  // Court boundary lines (neon glow)
  ctx.shadowColor = colors.lineColor;
  ctx.shadowBlur = 6;
  ctx.strokeStyle = colors.lineColor;
  ctx.lineWidth = 2;
  ctx.strokeRect(COURT_LEFT, COURT_TOP, COURT_W, COURT_H);

  // Service lines (dashed)
  ctx.lineWidth = 1;
  ctx.shadowBlur = 3;
  ctx.setLineDash([6, 4]);

  ctx.beginPath();
  ctx.moveTo(COURT_LEFT, SERVICE_LINE_TOP);
  ctx.lineTo(COURT_RIGHT, SERVICE_LINE_TOP);
  ctx.stroke();

  ctx.beginPath();
  ctx.moveTo(COURT_LEFT, SERVICE_LINE_BOTTOM);
  ctx.lineTo(COURT_RIGHT, SERVICE_LINE_BOTTOM);
  ctx.stroke();

  // Center service line (vertical)
  ctx.beginPath();
  ctx.moveTo(CENTER_LINE_X, SERVICE_LINE_TOP);
  ctx.lineTo(CENTER_LINE_X, SERVICE_LINE_BOTTOM);
  ctx.stroke();

  // Center marks on baselines
  ctx.beginPath();
  ctx.moveTo(CENTER_LINE_X, COURT_TOP);
  ctx.lineTo(CENTER_LINE_X, COURT_TOP + 10);
  ctx.stroke();

  ctx.beginPath();
  ctx.moveTo(CENTER_LINE_X, COURT_BOTTOM - 10);
  ctx.lineTo(CENTER_LINE_X, COURT_BOTTOM);
  ctx.stroke();

  ctx.setLineDash([]);
  ctx.shadowBlur = 0;
  ctx.shadowColor = "transparent";
}

function drawNet(ctx, colors, time) {
  const pulse = 0.7 + 0.3 * Math.sin(time * 0.003);

  // Net line
  ctx.strokeStyle = colors.netColor;
  ctx.lineWidth = 4;
  ctx.shadowColor = colors.netColor;
  ctx.shadowBlur = 8 * pulse;
  ctx.beginPath();
  ctx.moveTo(COURT_LEFT, NET_Y);
  ctx.lineTo(COURT_RIGHT, NET_Y);
  ctx.stroke();

  // Net posts
  ctx.fillStyle = colors.netColor;
  ctx.fillRect(COURT_LEFT - 4, NET_Y - 4, 8, 8);
  ctx.fillRect(COURT_RIGHT - 4, NET_Y - 4, 8, 8);

  ctx.shadowBlur = 0;
  ctx.shadowColor = "transparent";
}

function drawPlayer(ctx, x, y, color, isServing, time) {
  // Body glow
  ctx.shadowColor = color;
  ctx.shadowBlur = 12;

  // Main body
  ctx.fillStyle = color;
  ctx.fillRect(x - 8, y - 10, 16, 20);

  // Inner highlight
  ctx.shadowBlur = 0;
  ctx.fillStyle = "rgba(255,255,255,0.2)";
  ctx.fillRect(x - 6, y - 8, 12, 16);

  // Racket
  ctx.strokeStyle = color;
  ctx.lineWidth = 2;
  ctx.shadowColor = color;
  ctx.shadowBlur = 6;
  ctx.beginPath();
  ctx.moveTo(x + 8, y - 2);
  ctx.lineTo(x + 14, y - 6);
  ctx.stroke();

  // Serve indicator (pulsing)
  if (isServing) {
    ctx.globalAlpha = 0.5 + 0.5 * Math.sin(time * 0.008);
    ctx.fillStyle = color;
    ctx.beginPath();
    ctx.arc(x, y - 16, 4, 0, Math.PI * 2);
    ctx.fill();
    ctx.globalAlpha = 1.0;
  }

  ctx.shadowBlur = 0;
  ctx.shadowColor = "transparent";
}

function drawBall(ctx, ball, colors, time) {
  const { x, y, vx, vy, height } = ball;

  // Shadow on ground
  const shadowAlpha = 0.3 * (1 - height);
  const shadowOffset = height * 8;
  ctx.globalAlpha = shadowAlpha;
  ctx.fillStyle = gameColor("000000");
  ctx.beginPath();
  ctx.ellipse(x, y + shadowOffset, BALL_RADIUS + 1, BALL_RADIUS * 0.6, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.globalAlpha = 1.0;

  // Trail (4 ghosts)
  const trailAlphas = [0.12, 0.08, 0.05, 0.02];
  for (let i = trailAlphas.length - 1; i >= 0; i--) {
    const factor = (i + 1) * 2.5;
    const tx = x - vx * factor;
    const ty = y - vy * factor;
    ctx.globalAlpha = trailAlphas[i];
    ctx.fillStyle = colors.ballColor;
    ctx.beginPath();
    ctx.arc(tx, ty, BALL_RADIUS, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.globalAlpha = 1.0;

  // Ball with glow
  const sizeBonus = height * 2;
  ctx.shadowColor = colors.ballColor;
  ctx.shadowBlur = 10 + 4 * Math.sin(time * 0.01);
  ctx.fillStyle = colors.ballColor;
  ctx.beginPath();
  ctx.arc(x, y, BALL_RADIUS + sizeBonus, 0, Math.PI * 2);
  ctx.fill();

  // White core
  ctx.shadowBlur = 0;
  ctx.fillStyle = gameColor("ffffff");
  ctx.beginPath();
  ctx.arc(x, y, (BALL_RADIUS + sizeBonus) * 0.5, 0, Math.PI * 2);
  ctx.fill();

  ctx.shadowColor = "transparent";
}

function drawScoreboard(ctx, state, colors) {
  const y = 20;

  // P1 points (left)
  ctx.font = "bold 14px monospace";
  ctx.textAlign = "left";
  ctx.textBaseline = "middle";
  ctx.shadowColor = colors.fg;
  ctx.shadowBlur = 4;
  ctx.fillStyle = colors.fg;
  const p1Text = getPointText(state.p1Points, state.p2Points, state.isTiebreak);
  ctx.fillText(jt`P1: ${p1Text}`, 10, y);

  // P2 points (right)
  ctx.textAlign = "right";
  ctx.shadowColor = colors.accent;
  ctx.fillStyle = colors.accent;
  const p2Text = getPointText(state.p2Points, state.p1Points, state.isTiebreak);
  ctx.fillText(jt`P2: ${p2Text}`, CANVAS_W - 10, y);

  // Games score (center)
  ctx.textAlign = "center";
  ctx.shadowColor = colors.warning;
  ctx.fillStyle = colors.warning;
  ctx.font = "bold 16px monospace";
  ctx.fillText(`${state.p1Games} - ${state.p2Games}`, CANVAS_W / 2, y);

  // Serve indicator dot
  const serveX = state.server === 1 ? 6 : CANVAS_W - 6;
  ctx.fillStyle = colors.ballColor;
  ctx.shadowColor = colors.ballColor;
  ctx.shadowBlur = 6;
  ctx.beginPath();
  ctx.arc(serveX, y, 3, 0, Math.PI * 2);
  ctx.fill();

  // Tiebreak label
  if (state.isTiebreak) {
    ctx.font = "10px monospace";
    ctx.fillStyle = colors.warning;
    ctx.shadowBlur = 3;
    ctx.fillText("TIEBREAK", CANVAS_W / 2, y + 14);
  }

  ctx.shadowBlur = 0;
  ctx.shadowColor = "transparent";
}

function drawAnnouncement(ctx, text, color, time, yOffset) {
  const pulse = 1.0 + 0.1 * Math.sin(time * 0.01);
  const size = Math.floor(28 * pulse);
  const y = CANVAS_H / 2 + (yOffset || 0);

  ctx.save();
  ctx.font = `bold ${size}px monospace`;
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";

  // RGB glitch offset
  ctx.globalAlpha = 0.4;
  ctx.fillStyle = gameColor("ff0000");
  ctx.fillText(text, CANVAS_W / 2 - 1, y);
  ctx.fillStyle = gameColor("0000ff");
  ctx.fillText(text, CANVAS_W / 2 + 1, y);

  // Main text
  ctx.globalAlpha = 1.0;
  ctx.shadowColor = color;
  ctx.shadowBlur = 16;
  ctx.fillStyle = color;
  ctx.fillText(text, CANVAS_W / 2, y);
  ctx.restore();
}

function drawWaiting(ctx, colors, time) {
  const pulse = 0.6 + 0.4 * Math.sin(time * 0.004);
  ctx.save();
  ctx.font = "bold 20px monospace";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.globalAlpha = pulse;
  ctx.shadowColor = colors.fg;
  ctx.shadowBlur = 10;
  ctx.fillStyle = colors.fg;
  ctx.fillText(t("WAITING FOR OPPONENT"), CANVAS_W / 2, CANVAS_H / 2);
  ctx.restore();
}

function drawCountdown(ctx, count, colors, time) {
  const pulse = 1.0 + 0.2 * Math.sin(time * 0.015);
  const size = Math.floor(48 * pulse);

  ctx.save();
  ctx.font = `bold ${size}px monospace`;
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.shadowColor = colors.warning;
  ctx.shadowBlur = 20;
  ctx.fillStyle = colors.warning;
  ctx.fillText(String(count), CANVAS_W / 2, CANVAS_H / 2);
  ctx.restore();
}

function drawServing(ctx, state, colors, time) {
  const pulse = 0.5 + 0.5 * Math.sin(time * 0.006);
  const serverColor = state.server === 1 ? colors.fg : colors.accent;

  ctx.save();
  ctx.font = "bold 16px monospace";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.globalAlpha = pulse;
  ctx.shadowColor = serverColor;
  ctx.shadowBlur = 8;
  ctx.fillStyle = serverColor;

  const label = state.isSecondServe ? t("SECOND SERVE") : "SERVE";
  ctx.fillText(label, CANVAS_W / 2, CANVAS_H / 2);
  ctx.restore();
}

function drawWinner(ctx, state, colors, time) {
  const winnerColor = state.winner === 1 ? colors.fg : colors.accent;
  const pulse = 1.0 + 0.1 * Math.sin(time * 0.01);
  const size = Math.floor(24 * pulse);

  ctx.save();
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";

  // RGB glitch
  ctx.globalAlpha = 0.4;
  ctx.font = `bold ${size}px monospace`;
  ctx.fillStyle = gameColor("ff0000");
  ctx.fillText(jt`PLAYER ${state.winner} WINS!`, CANVAS_W / 2 - 1, CANVAS_H / 2 - 20);
  ctx.fillStyle = gameColor("0000ff");
  ctx.fillText(jt`PLAYER ${state.winner} WINS!`, CANVAS_W / 2 + 1, CANVAS_H / 2 - 20);

  // Main text
  ctx.globalAlpha = 1.0;
  ctx.shadowColor = winnerColor;
  ctx.shadowBlur = 16;
  ctx.fillStyle = winnerColor;
  ctx.fillText(jt`PLAYER ${state.winner} WINS!`, CANVAS_W / 2, CANVAS_H / 2 - 20);

  // Score
  ctx.font = "bold 18px monospace";
  ctx.shadowBlur = 8;
  ctx.fillStyle = colors.warning;
  ctx.fillText(`${state.p1Games} - ${state.p2Games}`, CANVAS_W / 2, CANVAS_H / 2 + 15);

  // Game over
  ctx.font = "14px monospace";
  ctx.fillStyle = colors.muted;
  ctx.shadowBlur = 4;
  ctx.fillText(t("GAME OVER"), CANVAS_W / 2, CANVAS_H / 2 + 40);

  ctx.restore();
}

function drawScanlines(ctx) {
  ctx.fillStyle = "rgba(0,0,0,0.08)";
  for (let y = 0; y < CANVAS_H; y += 3) {
    ctx.fillRect(0, y, CANVAS_W, 1);
  }
}

function drawVignette(ctx) {
  const gradient = ctx.createRadialGradient(
    CANVAS_W / 2,
    CANVAS_H / 2,
    CANVAS_W * 0.3,
    CANVAS_W / 2,
    CANVAS_H / 2,
    CANVAS_W * 0.7,
  );
  gradient.addColorStop(0, "rgba(0,0,0,0)");
  gradient.addColorStop(1, "rgba(0,0,0,0.4)");
  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, CANVAS_W, CANVAS_H);
}
