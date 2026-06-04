/**
 * Canvas renderer for Hex Outlaw.
 * Reads game state and draws to a 640x480 canvas.
 * All colors come from CSS custom properties.
 * @module games/hex_outlaw_renderer
 */

import {
  CANVAS_W,
  CANVAS_H,
  ARENA_BOTTOM,
  ARENA_LEFT,
  ARENA_RIGHT,
  GUNSLINGER_W,
  GUNSLINGER_H,
  BULLET_RADIUS,
  SCORE_TO_WIN,
  getObstacleRect,
} from "./physics.js";
import { PHASE, GAME_MODE } from "./protocol.js";
import { t, jt } from "../../i18n.js";
import { gameColor } from "../../game_colors.js";

/**
 * Read CSS custom properties from the canvas element.
 * @param {HTMLCanvasElement} canvas
 * @returns {object}
 */
export function getColors(canvas) {
  const s = getComputedStyle(canvas);
  return {
    bg: s.getPropertyValue("--game-bg-color").trim() || gameColor("1a0a1e"),
    fg: s.getPropertyValue("--game-fg-color").trim() || gameColor("39ff14"),
    accent: s.getPropertyValue("--game-accent-color").trim() || gameColor("00e5ff"),
    muted: s.getPropertyValue("--game-muted-color").trim() || gameColor("3d1f0a"),
    glow: s.getPropertyValue("--game-glow-color").trim() || "rgba(255, 140, 0, 0.15)",
    warning: s.getPropertyValue("--game-warning-color").trim() || gameColor("ff4444"),
    rope: s.getPropertyValue("--game-rope-color").trim() || gameColor("c4956a"),
    ring: s.getPropertyValue("--game-ring-color").trim() || gameColor("2a1508"),
    hit: s.getPropertyValue("--game-hit-color").trim() || gameColor("ffffff"),
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
export function render(ctx, state, colors, frameCount, particles) {
  drawBackground(ctx, colors);
  drawGround(ctx, colors);
  drawObstacle(ctx, state, colors, frameCount);
  drawGunslinger(ctx, state, 1, colors.fg, colors, frameCount);
  drawGunslinger(ctx, state, 2, colors.accent, colors, frameCount);
  drawBullet(ctx, state, "b1", colors);
  drawBullet(ctx, state, "b2", colors);
  drawParticles(ctx, particles);
  drawHUD(ctx, state, colors);
  drawPhaseOverlay(ctx, state, colors, frameCount);
}

// --- Background ---

function drawBackground(ctx, colors) {
  // Desert sky gradient: deep purple at top → burnt orange at horizon
  const grad = ctx.createLinearGradient(0, 0, 0, CANVAS_H);
  grad.addColorStop(0, colors.bg);
  grad.addColorStop(0.45, gameColor("2a0f2e"));
  grad.addColorStop(0.65, gameColor("3d1a0a"));
  grad.addColorStop(0.75, colors.muted);
  grad.addColorStop(1, colors.ring);
  ctx.fillStyle = grad;
  ctx.fillRect(0, 0, CANVAS_W, CANVAS_H);

  // Horizon glow
  ctx.fillStyle = colors.glow;
  ctx.fillRect(0, CANVAS_H * 0.6, CANVAS_W, CANVAS_H * 0.15);
}

function drawGround(ctx, colors) {
  // Ground line
  ctx.strokeStyle = colors.rope;
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(ARENA_LEFT, ARENA_BOTTOM);
  ctx.lineTo(ARENA_RIGHT, ARENA_BOTTOM);
  ctx.stroke();

  // Cracked earth marks
  ctx.strokeStyle = adjustAlpha(colors.rope, 0.3);
  ctx.lineWidth = 1;
  for (let i = 0; i < 8; i++) {
    const x = ARENA_LEFT + 40 + i * 72;
    const y = ARENA_BOTTOM + 3;
    ctx.beginPath();
    ctx.moveTo(x, y);
    ctx.lineTo(x + 8, y + 6);
    ctx.moveTo(x + 4, y);
    ctx.lineTo(x - 3, y + 8);
    ctx.stroke();
  }
}

// --- Obstacle ---

function drawObstacle(ctx, state, colors, frameCount) {
  const rect = getObstacleRect(state);
  if (!rect) return;

  switch (state.gameMode) {
    case GAME_MODE.QUICK_DRAW:
      drawCactus(ctx, rect, colors);
      break;
    case GAME_MODE.RICOCHET:
      drawWall(ctx, rect, colors);
      break;
    case GAME_MODE.STAGECOACH:
      drawStagecoach(ctx, rect, colors, frameCount);
      break;
  }
}

function drawCactus(ctx, rect, colors) {
  const cx = rect.x + rect.w / 2;
  const bottom = rect.y + rect.h;
  const top = rect.y;

  // Main trunk
  ctx.fillStyle = gameColor("1a6b1a");
  ctx.fillRect(cx - 3, top, 6, rect.h);

  // Left arm
  const armY = top + rect.h * 0.35;
  ctx.fillRect(cx - 3 - 10, armY, 10, 5);
  ctx.fillRect(cx - 3 - 10, armY - 12, 5, 12);

  // Right arm
  const armY2 = top + rect.h * 0.55;
  ctx.fillRect(cx + 3, armY2, 10, 5);
  ctx.fillRect(cx + 3 + 5, armY2 - 10, 5, 10);

  // Neon glow outline
  ctx.strokeStyle = "rgba(57, 255, 20, 0.3)";
  ctx.lineWidth = 1;
  ctx.strokeRect(cx - 4, top - 1, 8, rect.h + 2);

  // Base/pot
  ctx.fillStyle = colors.muted;
  ctx.fillRect(cx - 5, bottom - 4, 10, 4);
}

function drawWall(ctx, rect, _colors) {
  // Adobe wall with brick pattern
  ctx.fillStyle = gameColor("4a2a0a");
  ctx.fillRect(rect.x, rect.y, rect.w, rect.h);

  // Brick lines
  ctx.strokeStyle = gameColor("5a3a1a");
  ctx.lineWidth = 1;
  const brickH = 8;
  for (let row = 0; row < rect.h / brickH; row++) {
    const y = rect.y + row * brickH;
    ctx.beginPath();
    ctx.moveTo(rect.x, y);
    ctx.lineTo(rect.x + rect.w, y);
    ctx.stroke();

    // Alternate brick offset
    const offsetX = row % 2 === 0 ? rect.w / 2 : 0;
    if (offsetX > 0) {
      ctx.beginPath();
      ctx.moveTo(rect.x + offsetX, y);
      ctx.lineTo(rect.x + offsetX, y + brickH);
      ctx.stroke();
    }
  }

  // Neon edge glow
  ctx.strokeStyle = "rgba(255, 140, 0, 0.3)";
  ctx.lineWidth = 1;
  ctx.strokeRect(rect.x - 1, rect.y - 1, rect.w + 2, rect.h + 2);
}

function drawStagecoach(ctx, rect, colors, frameCount) {
  const cx = rect.x + rect.w / 2;
  const top = rect.y;
  const bottom = rect.y + rect.h;

  // Coach body
  ctx.fillStyle = gameColor("5a3010");
  ctx.fillRect(rect.x + 4, top + 8, rect.w - 8, rect.h - 24);

  // Roof
  ctx.fillStyle = gameColor("3a2008");
  ctx.fillRect(rect.x + 2, top + 4, rect.w - 4, 8);

  // Window
  ctx.fillStyle = gameColor("c4956a");
  ctx.fillRect(cx - 4, top + 14, 8, 6);

  // Wheels (animated rotation)
  const wheelY = bottom - 8;
  const spokeAngle = (frameCount * 0.1) % (Math.PI * 2);
  drawWheel(ctx, rect.x + 8, wheelY, 6, spokeAngle);
  drawWheel(ctx, rect.x + rect.w - 8, wheelY, 6, spokeAngle);

  // Horse outline (front)
  ctx.fillStyle = gameColor("4a2a0a");
  ctx.fillRect(rect.x - 6, top + rect.h * 0.3, 6, 10);
  ctx.fillRect(rect.x - 8, top + rect.h * 0.2, 4, 8);
}

function drawWheel(ctx, x, y, r, angle) {
  ctx.strokeStyle = gameColor("8a6a3a");
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.arc(x, y, r, 0, Math.PI * 2);
  ctx.stroke();

  // Spokes
  ctx.lineWidth = 1;
  for (let i = 0; i < 4; i++) {
    const a = angle + (i * Math.PI) / 2;
    ctx.beginPath();
    ctx.moveTo(x, y);
    ctx.lineTo(x + Math.cos(a) * r, y + Math.sin(a) * r);
    ctx.stroke();
  }
}

// --- Gunslinger ---

function drawGunslinger(ctx, state, player, color, colors, frameCount) {
  const prefix = player === 1 ? "p1" : "p2";
  const gx = state[`${prefix}x`];
  const gy = state[`${prefix}y`];
  const shooting = state[`${prefix}shooting`];
  const facingRight = player === 1;

  // Hit flash
  const wasHit = state.lastHitPlayer !== 0 && state.lastHitPlayer !== player;
  const bodyColor = wasHit ? colors.hit : color;

  // Draw gunslinger sprite
  const dir = facingRight ? 1 : -1;
  const halfW = GUNSLINGER_W / 2;
  const halfH = GUNSLINGER_H / 2;

  // Hat
  ctx.fillStyle = bodyColor;
  ctx.fillRect(gx - halfW * dir * 0.2, gy - halfH - 4, 10 * dir, 4);
  ctx.fillRect(gx - halfW * 0.6, gy - halfH, GUNSLINGER_W * 0.6, 3);

  // Head
  ctx.fillStyle = bodyColor;
  ctx.fillRect(gx - 3, gy - halfH + 3, 6, 6);

  // Body (torso)
  ctx.fillStyle = bodyColor;
  ctx.fillRect(gx - 4, gy - halfH + 9, 8, 8);

  // Gun arm
  const armY = gy - halfH + 12;
  const armBaseX = gx + dir * 4;
  const armLen = shooting ? 10 : 7;
  ctx.strokeStyle = bodyColor;
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(armBaseX, armY);
  ctx.lineTo(armBaseX + dir * armLen, armY);
  ctx.stroke();

  // Gun
  const gunX = armBaseX + dir * armLen;
  ctx.fillStyle = gameColor("888888");
  ctx.fillRect(gunX, armY - 1, dir * 4, 2);

  // Muzzle flash when shooting
  if (shooting) {
    ctx.fillStyle = gameColor("ffff44");
    ctx.beginPath();
    ctx.arc(gunX + dir * 5, armY, 3, 0, Math.PI * 2);
    ctx.fill();
  }

  // Legs (walking animation)
  const legY = gy - halfH + 17;
  const legOffset = Math.sin(frameCount * 0.15) * 2;
  ctx.strokeStyle = bodyColor;
  ctx.lineWidth = 2;
  // Left leg
  ctx.beginPath();
  ctx.moveTo(gx - 2, legY);
  ctx.lineTo(gx - 2 + legOffset, legY + 7);
  ctx.stroke();
  // Right leg
  ctx.beginPath();
  ctx.moveTo(gx + 2, legY);
  ctx.lineTo(gx + 2 - legOffset, legY + 7);
  ctx.stroke();

  // Neon glow effect (subtle)
  if (!wasHit) {
    ctx.strokeStyle = adjustAlpha(color, 0.2);
    ctx.lineWidth = 1;
    ctx.strokeRect(gx - halfW - 2, gy - halfH - 6, GUNSLINGER_W + 4, GUNSLINGER_H + 10);
  }
}

// --- Bullet ---

function drawBullet(ctx, state, prefix, colors) {
  if (!state[`${prefix}active`]) return;

  const x = state[`${prefix}x`];
  const y = state[`${prefix}y`];
  const vx = state[`${prefix}vx`];

  // Trail (3 dots behind bullet)
  const trailDir = vx > 0 ? -1 : 1;
  for (let i = 1; i <= 3; i++) {
    const alpha = 0.6 - i * 0.15;
    ctx.beginPath();
    ctx.arc(
      x + trailDir * i * 4,
      y + (state[`${prefix}vy`] !== 0 ? -state[`${prefix}vy`] * i * 0.3 : 0),
      BULLET_RADIUS - 1,
      0,
      Math.PI * 2,
    );
    ctx.fillStyle = `rgba(255, 255, 255, ${alpha})`;
    ctx.fill();
  }

  // Main bullet (bright white with glow)
  ctx.beginPath();
  ctx.arc(x, y, BULLET_RADIUS, 0, Math.PI * 2);
  ctx.fillStyle = colors.hit;
  ctx.fill();

  // Glow
  ctx.beginPath();
  ctx.arc(x, y, BULLET_RADIUS + 2, 0, Math.PI * 2);
  ctx.fillStyle = "rgba(255, 255, 200, 0.3)";
  ctx.fill();
}

// --- Particles ---

/**
 * Create hit particles at the given position.
 * @param {number} x
 * @param {number} y
 * @returns {Array}
 */
export function createHitParticles(x, y) {
  const particles = [];
  for (let i = 0; i < 8; i++) {
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
  // Hat particle (flies upward)
  particles.push({
    x,
    y: y - 12,
    vx: (Math.random() - 0.5) * 3,
    vy: -3 - Math.random() * 2,
    life: 30,
    maxLife: 30,
    isHat: true,
  });
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
      vy: p.isHat ? p.vy + 0.15 : p.vy, // Gravity on hat
      vx: p.isHat ? p.vx : p.vx * 0.95,
      life: p.life - 1,
    }))
    .filter((p) => p.life > 0);
}

function drawParticles(ctx, particles) {
  for (const p of particles) {
    const alpha = p.life / p.maxLife;
    if (p.isHat) {
      // Draw hat as small rectangle
      ctx.fillStyle = `rgba(200, 150, 100, ${alpha})`;
      ctx.fillRect(p.x - 4, p.y - 2, 8, 4);
    } else {
      // Spark
      ctx.beginPath();
      ctx.arc(p.x, p.y, 2, 0, Math.PI * 2);
      ctx.fillStyle = `rgba(255, 200, 100, ${alpha})`;
      ctx.fill();
    }
  }
}

// --- HUD ---

function drawHUD(ctx, state, colors) {
  const hudY = 10;

  ctx.font = "bold 14px monospace";
  ctx.textBaseline = "top";

  // P1 score (left)
  ctx.textAlign = "left";
  ctx.fillStyle = colors.fg;
  ctx.fillText(jt`P1: ${state.score1}`, ARENA_LEFT + 4, hudY);

  // P2 score (right)
  ctx.textAlign = "right";
  ctx.fillStyle = colors.accent;
  ctx.fillText(jt`P2: ${state.score2}`, ARENA_RIGHT - 4, hudY);

  // Game title (center)
  ctx.textAlign = "center";
  ctx.fillStyle = colors.rope;
  ctx.fillText("OUTLAW", CANVAS_W / 2, hudY);

  // Game mode indicator
  ctx.font = "10px monospace";
  ctx.fillStyle = adjustAlpha(colors.rope, 0.6);
  const modeNames = [t("Quick Draw"), "Ricochet", "Stagecoach", t("No Man's Land")];
  ctx.fillText(modeNames[state.gameMode] || "", CANVAS_W / 2, hudY + 16);

  // Score progress (small dots under P1/P2)
  const dotY = hudY + 20;
  for (let i = 0; i < SCORE_TO_WIN; i++) {
    const dx = ARENA_LEFT + 8 + i * 10;
    ctx.beginPath();
    ctx.arc(dx, dotY, 2, 0, Math.PI * 2);
    ctx.fillStyle = i < state.score1 ? colors.fg : adjustAlpha(colors.fg, 0.2);
    ctx.fill();
  }
  for (let i = 0; i < SCORE_TO_WIN; i++) {
    const dx = ARENA_RIGHT - 8 - i * 10;
    ctx.beginPath();
    ctx.arc(dx, dotY, 2, 0, Math.PI * 2);
    ctx.fillStyle = i < state.score2 ? colors.accent : adjustAlpha(colors.accent, 0.2);
    ctx.fill();
  }

  // Round win dots (bottom)
  const bottomY = CANVAS_H - 12;
  ctx.font = "10px monospace";
  ctx.textAlign = "center";
  ctx.fillStyle = colors.muted;
  ctx.fillText(jt`Round ${state.round}`, CANVAS_W / 2, bottomY - 4);

  for (let i = 0; i < 3; i++) {
    const dx = CANVAS_W / 2 - 20 + i * 20;
    ctx.beginPath();
    ctx.arc(dx, bottomY + 8, 3, 0, Math.PI * 2);
    ctx.fillStyle = i < state.roundWins1 ? colors.fg : colors.muted;
    ctx.fill();
  }
  for (let i = 0; i < 3; i++) {
    const dx = CANVAS_W / 2 + 40 + i * 20;
    ctx.beginPath();
    ctx.arc(dx, bottomY + 8, 3, 0, Math.PI * 2);
    ctx.fillStyle = i < state.roundWins2 ? colors.accent : colors.muted;
    ctx.fill();
  }
}

// --- Phase Overlays ---

function drawPhaseOverlay(ctx, state, colors, frameCount) {
  switch (state.phase) {
    case PHASE.WAITING:
      drawCenterText(ctx, t("WAITING FOR OPPONENT"), 16, colors.rope);
      break;
    case PHASE.COUNTDOWN:
      drawCenterText(ctx, `${state.countdown}`, 48, colors.hit);
      break;
    case PHASE.SPAWNING:
      drawCenterText(ctx, t("DRAW!"), 36, colors.warning);
      break;
    case PHASE.HIT_PAUSE: {
      const scorer = state.lastHitPlayer;
      const scorerColor = scorer === 1 ? colors.fg : colors.accent;
      const flash = frameCount % 8 < 4;
      if (flash) {
        ctx.fillStyle = "rgba(255, 0, 0, 0.1)";
        ctx.fillRect(0, 0, CANVAS_W, CANVAS_H);
      }
      drawCenterText(ctx, jt`P${scorer} SCORES!`, 28, scorerColor);
      break;
    }
    case PHASE.ROUND_OVER: {
      const winner = state.score1 >= state.score2 ? "P1" : "P2";
      const winColor = winner === "P1" ? colors.fg : colors.accent;
      drawCenterText(ctx, jt`ROUND ${state.round}`, 24, colors.rope);
      drawCenterTextOffset(ctx, `${winner} WINS`, 28, winColor, 30);
      break;
    }
    case PHASE.MATCH_OVER: {
      const matchWinner = state.roundWins1 >= state.roundWins2 ? "P1" : "P2";
      const mColor = matchWinner === "P1" ? colors.fg : colors.accent;
      drawCenterText(ctx, t("MATCH OVER"), 24, colors.rope);
      drawCenterTextOffset(ctx, jt`${matchWinner} WINS!`, 36, mColor, 35);
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

function adjustAlpha(color, alpha) {
  // Handle hex colors
  if (color.startsWith("#")) {
    const clean = color.replace("#", "");
    const r = parseInt(clean.substring(0, 2), 16);
    const g = parseInt(clean.substring(2, 4), 16);
    const b = parseInt(clean.substring(4, 6), 16);
    return `rgba(${r}, ${g}, ${b}, ${alpha})`;
  }
  // Handle rgba colors — replace alpha
  if (color.startsWith("rgba")) {
    return color.replace(/[\d.]+\)$/, `${alpha})`);
  }
  return color;
}
