/**
 * Canvas renderer for Star Duel space combat — cyberpunk post-apocalyptic aesthetic.
 * Pure rendering functions, no side effects beyond canvas drawing.
 * @module games/star_duel_renderer
 */

import { PHASE, GAME_MODE } from "./protocol.js";
import {
  CANVAS_W,
  CANVAS_H,
  SHIP_RADIUS,
  MISSILE_RADIUS,
  STAR_RADIUS,
  STAR_DANGER_RADIUS,
  STAR_X,
  STAR_Y,
  WIN_SCORE,
  WARP_COOLDOWN,
} from "./physics.js";

// --- Deterministic starfield (golden ratio distribution, no flickering) ---

const STAR_COUNT = 50;
const _starfield = [];
for (let i = 0; i < STAR_COUNT; i++) {
  _starfield.push({
    x: (i * 0.6180339887 * CANVAS_W) % CANVAS_W,
    y: (i * 0.4155617497 * CANVAS_H) % CANVAS_H,
    brightness: 0.3 + (i % 3) * 0.25,
    size: i % 4 === 0 ? 2 : 1,
  });
}

// --- Color palette ---

/**
 * Read CSS custom properties from canvas computed style.
 * @param {HTMLCanvasElement} canvas
 * @returns {object} color palette
 */
export function getColors(canvas) {
  const s = getComputedStyle(canvas);
  return {
    bg: s.getPropertyValue("--game-bg-color").trim() || "#0a0a1a",
    p1: s.getPropertyValue("--game-fg-color").trim() || "#39ff14", // toxic green
    p2: s.getPropertyValue("--game-accent-color").trim() || "#00e5ff", // electric cyan
    muted: s.getPropertyValue("--game-muted-color").trim() || "#1a3a4a",
    glow: s.getPropertyValue("--game-glow-color").trim() || "rgba(57,255,20,0.2)",
    warning: s.getPropertyValue("--game-warning-color").trim() || "#ffaa00",
    star: s.getPropertyValue("--game-star-color").trim() || "#ff8c00",
    asteroid: s.getPropertyValue("--game-asteroid-color").trim() || "#8b4513",
    missile: s.getPropertyValue("--game-missile-color").trim() || "#ffffff",
    explosion: s.getPropertyValue("--game-explosion-color").trim() || "#ff4444",
  };
}

// --- Main render ---

/**
 * Render a full frame of the game.
 * @param {CanvasRenderingContext2D} ctx
 * @param {object} state - game state
 * @param {object} colors - color palette
 * @param {number} time - timestamp for animations
 */
export function render(ctx, state, colors, time) {
  drawBackground(ctx, colors);
  drawStarfield(ctx, colors, time);

  // Mode-specific elements
  if (state.mode === GAME_MODE.GRAVITY_WELL) {
    drawGravityStar(ctx, colors, time);
  }
  if (state.mode === GAME_MODE.DEBRIS_FIELD && state.asteroids) {
    drawAsteroids(ctx, state.asteroids, colors);
  }

  // Missiles (draw before ships so ships appear on top)
  if (state.missiles && state.missiles.length > 0) {
    drawMissiles(ctx, state.missiles, colors, time);
  }

  // Particles
  if (state.particles && state.particles.length > 0) {
    drawParticles(ctx, state.particles, colors);
  }

  // Ships
  if (state.ship1 && state.ship1.alive && !state.ship1.warping) {
    drawShip(ctx, state.ship1, colors.p1, colors, time, 1);
  }
  if (state.ship2 && state.ship2.alive && !state.ship2.warping) {
    drawShip(ctx, state.ship2, colors.p2, colors, time, 2);
  }

  // Warp effect
  if (state.ship1 && state.ship1.warping) drawWarpEffect(ctx, state.ship1, colors.p1, time);
  if (state.ship2 && state.ship2.warping) drawWarpEffect(ctx, state.ship2, colors.p2, time);

  // HUD
  drawHUD(ctx, state, colors, time);

  // Phase overlays
  if (state.phase === PHASE.WAITING) drawWaiting(ctx, colors, time);
  else if (state.phase === PHASE.COUNTDOWN) drawCountdown(ctx, state.countdown, colors, time);
  else if (state.phase === PHASE.SPAWNING) drawSpawning(ctx, colors, time);
  else if (state.phase === PHASE.ROUND_OVER) drawRoundOver(ctx, state, colors, time);
  else if (state.phase === PHASE.FINISHED) drawWinner(ctx, state, colors, time);

  drawScanlines(ctx);
  drawVignette(ctx);
}

// --- Individual draw functions ---

/**
 * Fill canvas with background color.
 * @param {CanvasRenderingContext2D} ctx
 * @param {object} colors
 */
export function drawBackground(ctx, colors) {
  ctx.fillStyle = colors.bg;
  ctx.fillRect(0, 0, CANVAS_W, CANVAS_H);
}

/**
 * Draw deterministic starfield with twinkling effect.
 * Uses golden-ratio distribution so stars never flicker between frames.
 * @param {CanvasRenderingContext2D} ctx
 * @param {object} colors
 * @param {number} time
 */
export function drawStarfield(ctx, colors, time) {
  for (let i = 0; i < _starfield.length; i++) {
    const s = _starfield[i];
    // Twinkle: vary brightness with a sin wave offset per star
    const twinkle = s.brightness + 0.15 * Math.sin(time * 0.002 + i * 1.7);
    const alpha = Math.max(0.1, Math.min(1.0, twinkle));

    ctx.globalAlpha = alpha;
    // Color tint: every 5th star has a slight blue tint
    if (i % 5 === 0) {
      ctx.fillStyle = "#aaccff";
    } else {
      ctx.fillStyle = "#ffffff";
    }
    ctx.fillRect(s.x, s.y, s.size, s.size);
  }
  ctx.globalAlpha = 1.0;
}

/**
 * Draw a ship as a triangle pointing in its rotation direction with neon glow.
 * Includes exhaust flame when thrusting and flash effect when invulnerable.
 * @param {CanvasRenderingContext2D} ctx
 * @param {object} ship - ship state {x, y, rotation, thrustActive, invulnerable, ...}
 * @param {string} color - player color
 * @param {object} colors - full palette
 * @param {number} time - timestamp for animations
 * @param {number} playerNum - 1 or 2
 */
export function drawShip(ctx, ship, color, colors, time, playerNum) {
  // Invulnerability flash: toggle visibility every ~8 frames
  if (ship.invulnerable && Math.floor(time / 133) % 2 === 0) {
    return;
  }

  ctx.save();
  ctx.translate(ship.x, ship.y);
  ctx.rotate(ship.rotation);

  // Exhaust flame when thrusting
  if (ship.thrustActive) {
    const flickerLen = 8 + 6 * Math.sin(time * 0.05 + playerNum);
    ctx.beginPath();
    ctx.moveTo(-SHIP_RADIUS * 0.7, -SHIP_RADIUS * 0.25);
    ctx.lineTo(-SHIP_RADIUS * 0.7 - flickerLen, 0);
    ctx.lineTo(-SHIP_RADIUS * 0.7, SHIP_RADIUS * 0.25);
    ctx.closePath();
    ctx.fillStyle = colors.warning;
    ctx.globalAlpha = 0.6 + 0.3 * Math.sin(time * 0.08);
    ctx.fill();
    ctx.globalAlpha = 1.0;
  }

  // Ship triangle with neon glow
  ctx.shadowColor = color;
  ctx.shadowBlur = 12;
  ctx.beginPath();
  ctx.moveTo(SHIP_RADIUS, 0); // nose
  ctx.lineTo(-SHIP_RADIUS * 0.7, -SHIP_RADIUS * 0.6); // left wing
  ctx.lineTo(-SHIP_RADIUS * 0.7, SHIP_RADIUS * 0.6); // right wing
  ctx.closePath();

  ctx.fillStyle = color;
  ctx.fill();

  // Inner highlight
  ctx.shadowBlur = 0;
  ctx.strokeStyle = "rgba(255,255,255,0.4)";
  ctx.lineWidth = 1;
  ctx.stroke();

  ctx.shadowColor = "transparent";
  ctx.restore();
}

/**
 * Draw missiles as bright dots with fading trails.
 * @param {CanvasRenderingContext2D} ctx
 * @param {Array} missiles - array of {x, y, vx, vy, owner, age}
 * @param {object} colors
 * @param {number} time
 */
export function drawMissiles(ctx, missiles, colors, time) {
  for (const m of missiles) {
    // 3-position fading trail going backwards
    const trailAlphas = [0.12, 0.06, 0.03];
    const speed = Math.sqrt(m.vx * m.vx + m.vy * m.vy);
    const dirX = speed > 0 ? m.vx / speed : 0;
    const dirY = speed > 0 ? m.vy / speed : 0;

    for (let i = trailAlphas.length - 1; i >= 0; i--) {
      const dist = (i + 1) * 4;
      const tx = m.x - dirX * dist;
      const ty = m.y - dirY * dist;
      ctx.globalAlpha = trailAlphas[i];
      ctx.fillStyle = m.owner === 1 ? colors.p1 : colors.p2;
      ctx.beginPath();
      ctx.arc(tx, ty, MISSILE_RADIUS, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.globalAlpha = 1.0;

    // Main missile dot
    const glow = 8 + 2 * Math.sin(time * 0.02 + m.age);
    ctx.shadowColor = colors.missile;
    ctx.shadowBlur = glow;
    ctx.fillStyle = colors.missile;
    ctx.beginPath();
    ctx.arc(m.x, m.y, MISSILE_RADIUS, 0, Math.PI * 2);
    ctx.fill();

    ctx.shadowBlur = 0;
    ctx.shadowColor = "transparent";
  }
}

/**
 * Draw explosion particles as colored squares (alias for drawParticles).
 * @param {CanvasRenderingContext2D} ctx
 * @param {Array} particles
 * @param {object} colors
 */
export function drawExplosion(ctx, particles, colors) {
  drawParticles(ctx, particles, colors);
}

/**
 * Draw particles as colored squares with alpha based on life.
 * Color fades from explosion red to warning amber.
 * @param {CanvasRenderingContext2D} ctx
 * @param {Array} particles - array of {x, y, life}
 * @param {object} colors
 */
export function drawParticles(ctx, particles, colors) {
  for (const p of particles) {
    ctx.globalAlpha = p.life;
    ctx.fillStyle = p.life > 0.5 ? colors.explosion : colors.warning;
    ctx.fillRect(p.x - 2, p.y - 2, 4, 4);
  }
  ctx.globalAlpha = 1.0;
}

/**
 * Draw the central gravity star with pulsing glow and danger zone ring.
 * Renders at STAR_X, STAR_Y with animated concentric radiation rings.
 * @param {CanvasRenderingContext2D} ctx
 * @param {object} colors
 * @param {number} time
 */
export function drawGravityStar(ctx, colors, time) {
  const pulse = 1.0 + 0.15 * Math.sin(time * 0.004);

  // Danger zone ring (subtle)
  ctx.beginPath();
  ctx.arc(STAR_X, STAR_Y, STAR_DANGER_RADIUS, 0, Math.PI * 2);
  ctx.strokeStyle = colors.star;
  ctx.lineWidth = 1;
  ctx.globalAlpha = 0.15 + 0.05 * Math.sin(time * 0.003);
  ctx.setLineDash([4, 6]);
  ctx.stroke();
  ctx.setLineDash([]);
  ctx.globalAlpha = 1.0;

  // Radiation glow rings (3 concentric)
  for (let i = 0; i < 3; i++) {
    const ringRadius = STAR_RADIUS + 4 + i * 6;
    const ringAlpha = (0.3 - i * 0.08) * (0.7 + 0.3 * Math.sin(time * 0.005 + i * 2.1));
    ctx.beginPath();
    ctx.arc(STAR_X, STAR_Y, ringRadius * pulse, 0, Math.PI * 2);
    ctx.strokeStyle = colors.star;
    ctx.lineWidth = 2;
    ctx.globalAlpha = Math.max(0, ringAlpha);
    ctx.stroke();
  }
  ctx.globalAlpha = 1.0;

  // Star core
  ctx.shadowColor = colors.star;
  ctx.shadowBlur = 20 * pulse;
  ctx.beginPath();
  ctx.arc(STAR_X, STAR_Y, STAR_RADIUS * pulse, 0, Math.PI * 2);
  ctx.fillStyle = colors.star;
  ctx.fill();

  // Bright inner core
  ctx.shadowBlur = 0;
  ctx.beginPath();
  ctx.arc(STAR_X, STAR_Y, STAR_RADIUS * 0.5 * pulse, 0, Math.PI * 2);
  ctx.fillStyle = colors.warning;
  ctx.fill();

  ctx.shadowColor = "transparent";
}

/**
 * Draw asteroids as jagged polygon outlines with rust-orange edge highlights.
 * @param {CanvasRenderingContext2D} ctx
 * @param {Array} asteroids - array of {x, y, radius, vertices: [{x, y}]}
 * @param {object} colors
 */
export function drawAsteroids(ctx, asteroids, colors) {
  for (const a of asteroids) {
    if (!a.vertices || a.vertices.length < 3) continue;

    ctx.beginPath();
    ctx.moveTo(a.x + a.vertices[0].x, a.y + a.vertices[0].y);
    for (let i = 1; i < a.vertices.length; i++) {
      ctx.lineTo(a.x + a.vertices[i].x, a.y + a.vertices[i].y);
    }
    ctx.closePath();

    // Very dark fill
    ctx.fillStyle = "rgba(30, 20, 10, 0.6)";
    ctx.fill();

    // Rust-orange edge highlight
    ctx.strokeStyle = colors.asteroid;
    ctx.lineWidth = 1.5;
    ctx.globalAlpha = 0.7;
    ctx.stroke();
    ctx.globalAlpha = 1.0;
  }
}

/**
 * Draw a warp effect as static noise/glitch rectangle at the ship position.
 * @param {CanvasRenderingContext2D} ctx
 * @param {object} ship - {x, y}
 * @param {string} color - player color
 * @param {number} time
 */
export function drawWarpEffect(ctx, ship, color, time) {
  const size = SHIP_RADIUS * 2.5;
  const halfSize = size / 2;
  const fade = 0.5 + 0.3 * Math.sin(time * 0.03);

  ctx.save();
  ctx.globalAlpha = fade;

  // Glitch lines
  for (let i = 0; i < 6; i++) {
    const offsetY = (i - 3) * 4;
    const width = size * (0.4 + 0.6 * Math.abs(Math.sin(time * 0.01 + i * 1.3)));
    ctx.fillStyle = color;
    ctx.globalAlpha = fade * (0.3 + 0.2 * Math.sin(time * 0.015 + i));
    ctx.fillRect(ship.x - width / 2, ship.y + offsetY - 1, width, 2);
  }

  // Central flash
  ctx.globalAlpha = fade * 0.4;
  ctx.fillStyle = "#ffffff";
  ctx.fillRect(ship.x - halfSize, ship.y - halfSize, size, size);

  ctx.restore();
}

/**
 * Draw the heads-up display: scores, mode name, and warp cooldown bars.
 * @param {CanvasRenderingContext2D} ctx
 * @param {object} state
 * @param {object} colors
 * @param {number} time
 */
export function drawHUD(ctx, state, colors, _time) {
  const score1 = state.score1 || 0;
  const score2 = state.score2 || 0;

  ctx.save();
  ctx.font = "bold 20px monospace";
  ctx.textBaseline = "top";

  // P1 score (left, green glow)
  ctx.textAlign = "left";
  ctx.shadowColor = colors.p1;
  ctx.shadowBlur = 10;
  ctx.fillStyle = colors.p1;
  ctx.fillText(`P1  ${score1}`, 16, 12);

  // P2 score (right side of center area, cyan glow)
  ctx.textAlign = "right";
  ctx.shadowColor = colors.p2;
  ctx.shadowBlur = 10;
  ctx.fillStyle = colors.p2;
  ctx.fillText(`${score2}  P2`, CANVAS_W - 16, 12);

  // Dash separator
  ctx.textAlign = "center";
  ctx.shadowColor = colors.muted;
  ctx.shadowBlur = 4;
  ctx.fillStyle = colors.muted;
  ctx.fillText("\u2014", CANVAS_W / 2, 12);

  ctx.shadowBlur = 0;
  ctx.shadowColor = "transparent";

  // Mode name (top-right corner)
  const modeNames = ["OPEN SPACE", "GRAVITY WELL", "DEBRIS FIELD"];
  const modeName = modeNames[state.mode] || "UNKNOWN";
  ctx.font = "10px monospace";
  ctx.textAlign = "right";
  ctx.fillStyle = colors.muted;
  ctx.globalAlpha = 0.6;
  ctx.fillText(modeName, CANVAS_W - 16, 36);
  ctx.globalAlpha = 1.0;

  // Warp cooldown bars
  const barW = 40;
  const barH = 4;
  const barY = 34;

  // P1 warp cooldown
  const cd1 = state.warpCooldown1 || 0;
  if (cd1 > 0) {
    const pct1 = cd1 / WARP_COOLDOWN;
    ctx.fillStyle = colors.muted;
    ctx.fillRect(16, barY, barW, barH);
    ctx.fillStyle = colors.p1;
    ctx.globalAlpha = 0.7;
    ctx.fillRect(16, barY, barW * (1 - pct1), barH);
    ctx.globalAlpha = 1.0;
  }

  // P2 warp cooldown
  const cd2 = state.warpCooldown2 || 0;
  if (cd2 > 0) {
    const pct2 = cd2 / WARP_COOLDOWN;
    const barX2 = CANVAS_W - 16 - barW;
    ctx.fillStyle = colors.muted;
    ctx.fillRect(barX2, barY, barW, barH);
    ctx.fillStyle = colors.p2;
    ctx.globalAlpha = 0.7;
    ctx.fillRect(barX2, barY, barW * (1 - pct2), barH);
    ctx.globalAlpha = 1.0;
  }

  ctx.restore();
}

/**
 * Draw countdown number with pulse animation.
 * @param {CanvasRenderingContext2D} ctx
 * @param {number} count - countdown value
 * @param {object} colors
 * @param {number} time
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
 * Draw "WAITING FOR OPPONENT..." with animated dots.
 * @param {CanvasRenderingContext2D} ctx
 * @param {object} colors
 * @param {number} time
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
 * Draw "GET READY" with flicker effect.
 * @param {CanvasRenderingContext2D} ctx
 * @param {object} colors
 * @param {number} time
 */
export function drawSpawning(ctx, colors, time) {
  const flicker = Math.sin(time * 0.02) > -0.3 ? 1.0 : 0.3;

  ctx.save();
  ctx.globalAlpha = flicker;
  ctx.shadowColor = colors.p1;
  ctx.shadowBlur = 12;
  ctx.fillStyle = colors.p1;
  ctx.font = "bold 24px monospace";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText("GET READY", CANVAS_W / 2, CANVAS_H / 2);
  ctx.restore();
}

/**
 * Draw round-over overlay showing which player scored with flash effect.
 * @param {CanvasRenderingContext2D} ctx
 * @param {object} state
 * @param {object} colors
 * @param {number} time
 */
export function drawRoundOver(ctx, state, colors, time) {
  const flash = 0.5 + 0.5 * Math.sin(time * 0.01);

  ctx.save();
  ctx.globalAlpha = flash;
  ctx.fillStyle = "rgba(255, 255, 255, 0.05)";
  ctx.fillRect(0, 0, CANVAS_W, CANVAS_H);
  ctx.globalAlpha = 1.0;

  const scorer = state.lastScorer || 1;
  const scorerColor = scorer === 1 ? colors.p1 : colors.p2;

  ctx.shadowColor = scorerColor;
  ctx.shadowBlur = 15;
  ctx.fillStyle = scorerColor;
  ctx.font = "bold 28px monospace";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";

  if (scorer === 0) {
    // Mutual kill — no scorer
    ctx.fillStyle = colors.warning;
    ctx.shadowColor = colors.warning;
    ctx.fillText("DRAW!", CANVAS_W / 2, CANVAS_H / 2);
  } else {
    ctx.fillText(`PLAYER ${scorer} SCORES!`, CANVAS_W / 2, CANVAS_H / 2);
  }

  ctx.restore();
}

/**
 * Draw winner announcement with glitch RGB offset effect.
 * @param {CanvasRenderingContext2D} ctx
 * @param {object} state
 * @param {object} colors
 * @param {number} time
 */
export function drawWinner(ctx, state, colors, time) {
  const s1 = state.score1 || 0;
  const winner = s1 >= WIN_SCORE ? 1 : 2;
  const text = `PLAYER ${winner} WINS!`;
  const color = winner === 1 ? colors.p1 : colors.p2;

  ctx.save();
  ctx.font = "bold 36px monospace";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";

  // Glitch effect: deterministic offset from time
  const glitchSeed = (time * 7.3) % 1;
  const glitchX = glitchSeed > 0.9 ? (((time * 13.7) % 1) - 0.5) * 4 : 0;
  const glitchY = glitchSeed > 0.9 ? (((time * 17.1) % 1) - 0.5) * 2 : 0;

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

  // Sub text: "FIRST TO 7"
  ctx.font = "16px monospace";
  ctx.shadowBlur = 8;
  ctx.fillStyle = colors.muted;
  const pulse = 0.5 + 0.5 * Math.sin(time * 0.005);
  ctx.globalAlpha = pulse;
  ctx.fillText(`FIRST TO ${WIN_SCORE}`, CANVAS_W / 2, CANVAS_H / 2 + 40);

  ctx.restore();
}

/**
 * Draw CRT scanline overlay.
 * @param {CanvasRenderingContext2D} ctx
 */
export function drawScanlines(ctx) {
  ctx.fillStyle = "rgba(0,0,0,0.08)";
  for (let y = 0; y < CANVAS_H; y += 2) {
    ctx.fillRect(0, y, CANVAS_W, 1);
  }
}

/**
 * Draw vignette (darkened edges).
 * @param {CanvasRenderingContext2D} ctx
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
