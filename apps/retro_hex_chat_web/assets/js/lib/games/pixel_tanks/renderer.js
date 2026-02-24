/**
 * Canvas renderer for Pixel Tanks — cyberpunk wasteland combat aesthetic.
 * Pure rendering functions, no side effects beyond canvas drawing.
 * @module games/pixel_tanks_renderer
 */

import { PHASE } from "./protocol.js";
import {
  CANVAS_W,
  CANVAS_H,
  WALL_SIZE,
  GRID_COLS,
  GRID_ROWS,
  TANK_RADIUS,
  MISSILE_RADIUS,
  ROUNDS_TO_WIN,
  formatTimer,
} from "./physics.js";

/**
 * Read CSS custom properties from canvas computed style.
 * @param {HTMLCanvasElement} canvas
 * @returns {object} color palette
 */
export function getColors(canvas) {
  const s = getComputedStyle(canvas);
  return {
    bg: s.getPropertyValue("--game-bg-color").trim() || "#0a0e0a",
    fg: s.getPropertyValue("--game-fg-color").trim() || "#39ff14",
    accent: s.getPropertyValue("--game-accent-color").trim() || "#00e5ff",
    muted: s.getPropertyValue("--game-muted-color").trim() || "#1a2a1a",
    glow: s.getPropertyValue("--game-glow-color").trim() || "rgba(57,255,20,0.15)",
    warning: s.getPropertyValue("--game-warning-color").trim() || "#ff8c00",
    wall: s.getPropertyValue("--game-wall-color").trim() || "#2a2a2a",
    wallHi: s.getPropertyValue("--game-wall-highlight").trim() || "#3a3a3a",
    missile: s.getPropertyValue("--game-missile-color").trim() || "#ffee00",
    explosion: s.getPropertyValue("--game-explosion-color").trim() || "#ff4444",
  };
}

/**
 * Render a full frame of the game.
 * @param {CanvasRenderingContext2D} ctx
 * @param {object} state - game state
 * @param {object} colors - color palette
 * @param {Uint8Array} walls - maze wall data
 * @param {number} time - timestamp for animations
 * @param {Array} particles - particle array
 */
export function render(ctx, state, colors, walls, time, particles) {
  drawBackground(ctx, colors);
  drawGrid(ctx, colors);
  drawWalls(ctx, walls, colors);

  // Missiles (draw before tanks so tanks are on top)
  if (state.m1Active) {
    drawMissile(ctx, state.m1X, state.m1Y, state.m1VX, state.m1VY, colors.missile, time);
  }
  if (state.m2Active) {
    drawMissile(ctx, state.m2X, state.m2Y, state.m2VX, state.m2VY, colors.missile, time);
  }

  // Tanks
  if (state.tank1Alive) {
    drawTank(ctx, state.tank1X, state.tank1Y, state.tank1Rot, colors.fg, state.tank1Invuln, time);
  }
  if (state.tank2Alive) {
    drawTank(
      ctx,
      state.tank2X,
      state.tank2Y,
      state.tank2Rot,
      colors.accent,
      state.tank2Invuln,
      time,
    );
  }

  // Particles
  if (particles && particles.length > 0) {
    drawParticles(ctx, particles, colors);
  }

  // HUD
  drawHUD(ctx, state, colors, time);

  // Phase overlays
  if (state.phase === PHASE.WAITING) {
    drawWaiting(ctx, colors);
  } else if (state.phase === PHASE.COUNTDOWN) {
    drawCountdown(ctx, state.countdown, colors);
  } else if (state.phase === PHASE.SPAWNING) {
    drawSpawning(ctx, colors);
  } else if (state.phase === PHASE.ROUND_OVER) {
    drawRoundOver(ctx, state, colors);
  } else if (state.phase === PHASE.MATCH_OVER) {
    drawMatchOver(ctx, state, colors);
  }

  // CRT effects
  drawScanlines(ctx);
  drawVignette(ctx);
}

// --- Drawing functions ---

function drawBackground(ctx, colors) {
  ctx.fillStyle = colors.bg;
  ctx.fillRect(0, 0, CANVAS_W, CANVAS_H);
}

function drawGrid(ctx, colors) {
  ctx.strokeStyle = colors.muted;
  ctx.lineWidth = 0.5;
  ctx.globalAlpha = 0.3;
  for (let x = 0; x <= CANVAS_W; x += WALL_SIZE) {
    ctx.beginPath();
    ctx.moveTo(x, 0);
    ctx.lineTo(x, CANVAS_H);
    ctx.stroke();
  }
  for (let y = 0; y <= CANVAS_H; y += WALL_SIZE) {
    ctx.beginPath();
    ctx.moveTo(0, y);
    ctx.lineTo(CANVAS_W, y);
    ctx.stroke();
  }
  ctx.globalAlpha = 1;
}

function drawWalls(ctx, walls, colors) {
  for (let row = 0; row < GRID_ROWS; row++) {
    for (let col = 0; col < GRID_COLS; col++) {
      if (!walls[row * GRID_COLS + col]) continue;
      const x = col * WALL_SIZE;
      const y = row * WALL_SIZE;
      ctx.fillStyle = colors.wall;
      ctx.fillRect(x, y, WALL_SIZE, WALL_SIZE);
      // Top-left edge highlight
      ctx.fillStyle = colors.wallHi;
      ctx.fillRect(x, y, WALL_SIZE, 1);
      ctx.fillRect(x, y, 1, WALL_SIZE);
    }
  }
}

function drawTank(ctx, x, y, rotation, color, invuln, time) {
  // Invulnerability flash: skip drawing every other 133ms
  if (invuln && Math.floor(time / 133) % 2 === 0) return;

  ctx.save();
  ctx.translate(x, y);
  ctx.rotate(rotation);

  // Glow
  ctx.shadowColor = color;
  ctx.shadowBlur = 8;

  // Tank body: chunky angular top-down shape
  ctx.fillStyle = color;
  ctx.beginPath();
  ctx.moveTo(TANK_RADIUS, 0); // nose
  ctx.lineTo(-TANK_RADIUS * 0.7, -TANK_RADIUS * 0.7); // left rear
  ctx.lineTo(-TANK_RADIUS * 0.5, -TANK_RADIUS * 0.3); // left inner notch
  ctx.lineTo(-TANK_RADIUS * 0.5, TANK_RADIUS * 0.3); // right inner notch
  ctx.lineTo(-TANK_RADIUS * 0.7, TANK_RADIUS * 0.7); // right rear
  ctx.closePath();
  ctx.fill();

  // Barrel
  ctx.strokeStyle = color;
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(2, 0);
  ctx.lineTo(TANK_RADIUS + 3, 0);
  ctx.stroke();

  ctx.shadowBlur = 0;
  ctx.restore();
}

function drawMissile(ctx, x, y, vx, vy, color, _time) {
  ctx.save();

  // Trail (3 fading dots behind missile)
  const speed = Math.sqrt(vx * vx + vy * vy);
  if (speed > 0) {
    const nx = vx / speed;
    const ny = vy / speed;
    ctx.globalAlpha = 0.2;
    ctx.fillStyle = color;
    for (let i = 1; i <= 3; i++) {
      const tx = x - nx * i * 4;
      const ty = y - ny * i * 4;
      ctx.beginPath();
      ctx.arc(tx, ty, MISSILE_RADIUS * (1 - i * 0.2), 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.globalAlpha = 1;
  }

  // Main dot with glow
  ctx.shadowColor = color;
  ctx.shadowBlur = 6;
  ctx.fillStyle = color;
  ctx.beginPath();
  ctx.arc(x, y, MISSILE_RADIUS, 0, Math.PI * 2);
  ctx.fill();

  // Bright core
  ctx.fillStyle = "#ffffff";
  ctx.beginPath();
  ctx.arc(x, y, MISSILE_RADIUS * 0.5, 0, Math.PI * 2);
  ctx.fill();

  ctx.restore();
}

function drawParticles(ctx, particles, colors) {
  for (const p of particles) {
    const alpha = p.life / p.maxLife;
    ctx.globalAlpha = alpha;
    ctx.fillStyle = p.spark ? colors.missile : colors.explosion;
    const size = p.spark ? 2 : 2 + alpha * 2;
    ctx.fillRect(p.x - size / 2, p.y - size / 2, size, size);
  }
  ctx.globalAlpha = 1;
}

function drawHUD(ctx, state, colors, time) {
  ctx.save();
  ctx.font = "bold 14px monospace";
  ctx.textBaseline = "top";

  // P1 score (left)
  ctx.fillStyle = colors.fg;
  ctx.shadowColor = colors.fg;
  ctx.shadowBlur = 4;
  ctx.textAlign = "left";
  ctx.fillText(`P1: ${state.score1}`, 8, 6);

  // P2 score (right)
  ctx.fillStyle = colors.accent;
  ctx.shadowColor = colors.accent;
  ctx.textAlign = "right";
  ctx.fillText(`P2: ${state.score2}`, CANVAS_W - 8, 6);

  ctx.shadowBlur = 0;

  // Round + timer (center)
  ctx.fillStyle = colors.warning;
  ctx.textAlign = "center";

  const timerStr = formatTimer(state.roundTimer);
  // Flash timer warning when < 15s (900 frames)
  if (state.roundTimer < 900 && state.phase === PHASE.PLAYING) {
    if (Math.floor(time / 500) % 2 === 0) {
      ctx.fillStyle = colors.explosion;
    }
  }
  ctx.fillText(`R${state.round}  ${timerStr}`, CANVAS_W / 2, 6);

  // Round wins dots (below scores)
  ctx.font = "12px monospace";
  drawRoundDots(ctx, 8, 24, state.roundWins1, colors.fg);
  drawRoundDots(ctx, CANVAS_W - 8, 24, state.roundWins2, colors.accent, "right");
  ctx.restore();
}

function drawRoundDots(ctx, x, y, wins, color, align) {
  ctx.textAlign = align || "left";
  let dots = "";
  for (let i = 0; i < ROUNDS_TO_WIN; i++) {
    dots += i < wins ? "\u25C9 " : "\u25CB ";
  }
  ctx.fillStyle = color;
  ctx.fillText(dots.trim(), x, y);
}

function drawWaiting(ctx, colors) {
  drawOverlay(ctx, 0.6);
  ctx.fillStyle = colors.fg;
  ctx.font = "bold 16px monospace";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText("WAITING FOR OPPONENT...", CANVAS_W / 2, CANVAS_H / 2);
}

function drawCountdown(ctx, countdown, colors) {
  drawOverlay(ctx, 0.5);
  ctx.save();
  ctx.fillStyle = colors.warning;
  ctx.shadowColor = colors.warning;
  ctx.shadowBlur = 10;
  ctx.font = "bold 64px monospace";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText(String(countdown), CANVAS_W / 2, CANVAS_H / 2);
  ctx.restore();
}

function drawSpawning(ctx, colors) {
  drawOverlay(ctx, 0.3);
  ctx.fillStyle = colors.fg;
  ctx.font = "bold 20px monospace";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText("ENGAGE!", CANVAS_W / 2, CANVAS_H / 2);
}

function drawRoundOver(ctx, state, colors) {
  drawOverlay(ctx, 0.6);
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";

  ctx.fillStyle = colors.warning;
  ctx.font = "bold 24px monospace";
  ctx.fillText("ROUND OVER", CANVAS_W / 2, CANVAS_H / 2 - 20);

  ctx.font = "bold 16px monospace";
  const s1 = state.score1;
  const s2 = state.score2;
  let result;
  if (s1 > s2) result = "P1 WINS ROUND";
  else if (s2 > s1) result = "P2 WINS ROUND";
  else result = "DRAW";

  ctx.fillStyle = s1 > s2 ? colors.fg : s2 > s1 ? colors.accent : colors.warning;
  ctx.fillText(`${result}  (${s1} - ${s2})`, CANVAS_W / 2, CANVAS_H / 2 + 10);
}

function drawMatchOver(ctx, state, colors) {
  drawOverlay(ctx, 0.7);
  ctx.save();
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";

  const winner = state.roundWins1 >= ROUNDS_TO_WIN ? 1 : 2;
  const winColor = winner === 1 ? colors.fg : colors.accent;

  ctx.fillStyle = winColor;
  ctx.shadowColor = winColor;
  ctx.shadowBlur = 10;
  ctx.font = "bold 28px monospace";
  ctx.fillText(`PLAYER ${winner} WINS!`, CANVAS_W / 2, CANVAS_H / 2 - 20);

  ctx.shadowBlur = 0;
  ctx.font = "bold 16px monospace";
  ctx.fillStyle = colors.warning;
  ctx.fillText(
    `ROUNDS: ${state.roundWins1} - ${state.roundWins2}`,
    CANVAS_W / 2,
    CANVAS_H / 2 + 15,
  );
  ctx.restore();
}

function drawOverlay(ctx, alpha) {
  ctx.fillStyle = `rgba(0, 0, 0, ${alpha})`;
  ctx.fillRect(0, 0, CANVAS_W, CANVAS_H);
}

function drawScanlines(ctx) {
  ctx.fillStyle = "rgba(0, 0, 0, 0.06)";
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
  gradient.addColorStop(0, "rgba(0, 0, 0, 0)");
  gradient.addColorStop(1, "rgba(0, 0, 0, 0.3)");
  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, CANVAS_W, CANVAS_H);
}
