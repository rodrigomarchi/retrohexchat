/**
 * Canvas renderer for Hex Raid — cyberpunk post-apocalyptic toxic canal aesthetic.
 * Pure rendering functions, no side effects beyond canvas drawing.
 * @module games/hex_raid_renderer
 */

import { PHASE, ENEMY_TYPE, GAME_MODE } from "./protocol.js";
import {
  CANVAS_W,
  CANVAS_H,
  JET_RADIUS,
  MISSILE_RADIUS,
  MINE_RADIUS,
  BRIDGE_HEIGHT,
  getBankAtWorld,
  formatFuel,
} from "./physics.js";

/**
 * Read CSS custom properties from canvas computed style.
 * @param {HTMLCanvasElement} canvas
 * @returns {object} color palette
 */
export function getColors(canvas) {
  const s = getComputedStyle(canvas);
  return {
    bg: s.getPropertyValue("--game-bg-color").trim() || "#0a0e14",
    p1: s.getPropertyValue("--game-fg-color").trim() || "#39ff14",
    p2: s.getPropertyValue("--game-accent-color").trim() || "#00e5ff",
    water: s.getPropertyValue("--game-muted-color").trim() || "#0a1a2a",
    glow: s.getPropertyValue("--game-glow-color").trim() || "rgba(57,255,20,0.15)",
    warning: s.getPropertyValue("--game-warning-color").trim() || "#ff8c00",
    bank: s.getPropertyValue("--game-wall-color").trim() || "#1a2a1a",
    bankHi: s.getPropertyValue("--game-wall-highlight").trim() || "#2a4a2a",
    missile: s.getPropertyValue("--game-missile-color").trim() || "#ffee00",
    explosion: s.getPropertyValue("--game-explosion-color").trim() || "#ff4444",
  };
}

/**
 * Render a full frame.
 * @param {CanvasRenderingContext2D} ctx
 * @param {object} state
 * @param {object} colors
 * @param {number} time - performance.now() for animations
 * @param {Array} particles
 */
export function render(ctx, state, colors, time, particles) {
  drawBackground(ctx, colors);
  drawWater(ctx, state, colors, time);
  drawBanks(ctx, state, colors);
  drawFuelStations(ctx, state, colors, time);
  drawEnemies(ctx, state, colors, time);
  drawBridge(ctx, state, colors);
  drawMines(ctx, state, colors, time);
  drawMissiles(ctx, state, colors);
  drawJets(ctx, state, colors, time);

  if (particles && particles.length > 0) {
    drawParticles(ctx, particles, colors);
  }

  drawHUD(ctx, state, colors, time);

  // Phase overlays
  if (state.phase === PHASE.WAITING) {
    drawOverlayText(ctx, colors, "WAITING FOR OPPONENT...", colors.p1);
  } else if (state.phase === PHASE.COUNTDOWN) {
    drawOverlayText(ctx, colors, String(state.countdown), colors.warning, 64);
  } else if (state.phase === PHASE.FINISHED) {
    drawGameOver(ctx, state, colors);
  }

  drawScanlines(ctx);
  drawVignette(ctx);
}

// --- Background layers ---

function drawBackground(ctx, colors) {
  ctx.fillStyle = colors.bg;
  ctx.fillRect(0, 0, CANVAS_W, CANVAS_H);
}

function drawWater(ctx, state, colors, time) {
  // Toxic water with subtle animated wave lines
  ctx.fillStyle = colors.water;

  // Draw water as the area between banks (computed on-the-fly)
  ctx.beginPath();
  for (let screenY = 0; screenY <= CANVAS_H; screenY += 4) {
    const worldY = state.scrollY + (CANVAS_H - screenY);
    const bank = getBankAtWorld(worldY, state.seed, state.mode);
    if (screenY === 0) {
      ctx.moveTo(bank.leftX, screenY);
    } else {
      ctx.lineTo(bank.leftX, screenY);
    }
  }
  for (let screenY = CANVAS_H; screenY >= 0; screenY -= 4) {
    const worldY = state.scrollY + (CANVAS_H - screenY);
    const bank = getBankAtWorld(worldY, state.seed, state.mode);
    ctx.lineTo(bank.rightX, screenY);
  }
  ctx.closePath();
  ctx.fill();

  // Animated wave lines
  ctx.strokeStyle = "rgba(20, 60, 80, 0.3)";
  ctx.lineWidth = 1;
  for (let i = 0; i < 8; i++) {
    const baseY = ((time * 0.02 + i * 60) % CANVAS_H) | 0;
    ctx.beginPath();
    for (let x = 100; x < CANVAS_W - 100; x += 20) {
      const wave = Math.sin(x * 0.05 + time * 0.003 + i) * 2;
      if (x === 100) ctx.moveTo(x, baseY + wave);
      else ctx.lineTo(x, baseY + wave);
    }
    ctx.stroke();
  }
}

function drawBanks(ctx, state, colors) {
  // Left bank (fills from 0 to leftX) — computed on-the-fly
  ctx.fillStyle = colors.bank;
  ctx.beginPath();
  ctx.moveTo(0, 0);
  for (let screenY = 0; screenY <= CANVAS_H; screenY += 4) {
    const worldY = state.scrollY + (CANVAS_H - screenY);
    const bank = getBankAtWorld(worldY, state.seed, state.mode);
    ctx.lineTo(bank.leftX, screenY);
  }
  ctx.lineTo(0, CANVAS_H);
  ctx.closePath();
  ctx.fill();

  // Right bank (fills from rightX to CANVAS_W)
  ctx.beginPath();
  ctx.moveTo(CANVAS_W, 0);
  for (let screenY = 0; screenY <= CANVAS_H; screenY += 4) {
    const worldY = state.scrollY + (CANVAS_H - screenY);
    const bank = getBankAtWorld(worldY, state.seed, state.mode);
    ctx.lineTo(bank.rightX, screenY);
  }
  ctx.lineTo(CANVAS_W, CANVAS_H);
  ctx.closePath();
  ctx.fill();

  // Bank edge highlights
  ctx.strokeStyle = colors.bankHi;
  ctx.lineWidth = 2;

  // Left edge
  ctx.beginPath();
  for (let screenY = 0; screenY <= CANVAS_H; screenY += 4) {
    const worldY = state.scrollY + (CANVAS_H - screenY);
    const bank = getBankAtWorld(worldY, state.seed, state.mode);
    if (screenY === 0) ctx.moveTo(bank.leftX, screenY);
    else ctx.lineTo(bank.leftX, screenY);
  }
  ctx.stroke();

  // Right edge
  ctx.beginPath();
  for (let screenY = 0; screenY <= CANVAS_H; screenY += 4) {
    const worldY = state.scrollY + (CANVAS_H - screenY);
    const bank = getBankAtWorld(worldY, state.seed, state.mode);
    if (screenY === 0) ctx.moveTo(bank.rightX, screenY);
    else ctx.lineTo(bank.rightX, screenY);
  }
  ctx.stroke();
}

// --- Entities ---

function drawJets(ctx, state, colors, time) {
  if (state.jet1Alive) {
    drawJet(ctx, state.jet1X, state.jet1Y, colors.p1, state.jet1Invuln, time, colors);
  }
  if (state.jet2Alive) {
    drawJet(ctx, state.jet2X, state.jet2Y, colors.p2, state.jet2Invuln, time, colors);
  }
}

function drawJet(ctx, x, y, color, invuln, time, colors) {
  // Invulnerability flash
  if (invuln && Math.floor(time / 133) % 2 === 0) return;

  const r = JET_RADIUS;
  ctx.save();
  ctx.translate(x, y);

  // --- Dual exhaust flames (animated, behind jet) ---
  ctx.shadowColor = colors.warning;
  ctx.shadowBlur = 6;
  const f1 = 4 + Math.sin(time * 0.025) * 2.5;
  const f2 = 4 + Math.sin(time * 0.025 + 1.5) * 2.5;
  // Outer flame glow
  ctx.globalAlpha = 0.4;
  ctx.fillStyle = colors.explosion;
  ctx.beginPath();
  ctx.moveTo(-r * 0.45, r * 0.7);
  ctx.lineTo(-r * 0.25, r * 0.7 + f1 + 2);
  ctx.lineTo(-r * 0.05, r * 0.7);
  ctx.closePath();
  ctx.fill();
  ctx.beginPath();
  ctx.moveTo(r * 0.05, r * 0.7);
  ctx.lineTo(r * 0.25, r * 0.7 + f2 + 2);
  ctx.lineTo(r * 0.45, r * 0.7);
  ctx.closePath();
  ctx.fill();
  ctx.globalAlpha = 1;
  // Inner hot flame
  ctx.fillStyle = colors.warning;
  ctx.beginPath();
  ctx.moveTo(-r * 0.38, r * 0.7);
  ctx.lineTo(-r * 0.25, r * 0.7 + f1);
  ctx.lineTo(-r * 0.12, r * 0.7);
  ctx.closePath();
  ctx.fill();
  ctx.beginPath();
  ctx.moveTo(r * 0.12, r * 0.7);
  ctx.lineTo(r * 0.25, r * 0.7 + f2);
  ctx.lineTo(r * 0.38, r * 0.7);
  ctx.closePath();
  ctx.fill();

  // --- Main body — delta-wing fighter pointing UP ---
  ctx.shadowColor = color;
  ctx.shadowBlur = 10;
  ctx.fillStyle = color;
  ctx.beginPath();
  ctx.moveTo(0, -r * 1.6); // sharp nose
  ctx.lineTo(-r * 0.25, -r * 0.6); // left fuselage
  ctx.lineTo(-r * 1.3, r * 0.3); // left wingtip (wide sweep)
  ctx.lineTo(-r * 1.1, r * 0.5); // left wing trailing edge
  ctx.lineTo(-r * 0.35, r * 0.4); // left engine nacelle
  ctx.lineTo(-r * 0.35, r * 0.7); // left tail
  ctx.lineTo(0, r * 0.55); // tail center notch
  ctx.lineTo(r * 0.35, r * 0.7); // right tail
  ctx.lineTo(r * 0.35, r * 0.4); // right engine nacelle
  ctx.lineTo(r * 1.1, r * 0.5); // right wing trailing edge
  ctx.lineTo(r * 1.3, r * 0.3); // right wingtip
  ctx.lineTo(r * 0.25, -r * 0.6); // right fuselage
  ctx.closePath();
  ctx.fill();

  // --- Cockpit canopy (darker center stripe) ---
  ctx.shadowBlur = 0;
  ctx.fillStyle = "rgba(0, 0, 0, 0.5)";
  ctx.beginPath();
  ctx.moveTo(0, -r * 1.2);
  ctx.lineTo(-r * 0.15, -r * 0.2);
  ctx.lineTo(0, 0);
  ctx.lineTo(r * 0.15, -r * 0.2);
  ctx.closePath();
  ctx.fill();

  // --- Wing stripes (panel lines) ---
  ctx.strokeStyle = "rgba(0, 0, 0, 0.3)";
  ctx.lineWidth = 0.5;
  ctx.beginPath();
  ctx.moveTo(-r * 0.35, -r * 0.1);
  ctx.lineTo(-r * 1.0, r * 0.35);
  ctx.stroke();
  ctx.beginPath();
  ctx.moveTo(r * 0.35, -r * 0.1);
  ctx.lineTo(r * 1.0, r * 0.35);
  ctx.stroke();

  // --- Wingtip neon dots (blinking) ---
  const tipPulse = 0.4 + Math.sin(time * 0.01) * 0.6;
  ctx.globalAlpha = tipPulse;
  ctx.fillStyle = "#fff";
  ctx.shadowColor = color;
  ctx.shadowBlur = 4;
  ctx.beginPath();
  ctx.arc(-r * 1.2, r * 0.4, 1, 0, Math.PI * 2);
  ctx.arc(r * 1.2, r * 0.4, 1, 0, Math.PI * 2);
  ctx.fill();
  ctx.globalAlpha = 1;

  ctx.shadowBlur = 0;
  ctx.restore();
}

function drawMissiles(ctx, state, colors) {
  if (state.m1Active) {
    drawMissile(ctx, state.m1X, state.m1Y, colors.missile);
  }
  if (state.m2Active) {
    drawMissile(ctx, state.m2X, state.m2Y, colors.missile);
  }
}

function drawMissile(ctx, x, y, color) {
  ctx.save();
  ctx.shadowColor = color;
  ctx.shadowBlur = 6;

  // Trail
  ctx.globalAlpha = 0.2;
  ctx.fillStyle = color;
  for (let i = 1; i <= 3; i++) {
    ctx.beginPath();
    ctx.arc(x, y + i * 4, MISSILE_RADIUS * (1 - i * 0.2), 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.globalAlpha = 1;

  // Main dot
  ctx.fillStyle = color;
  ctx.beginPath();
  ctx.arc(x, y, MISSILE_RADIUS, 0, Math.PI * 2);
  ctx.fill();

  // Bright core
  ctx.fillStyle = color;
  ctx.beginPath();
  ctx.arc(x, y, MISSILE_RADIUS * 0.5, 0, Math.PI * 2);
  ctx.fill();

  ctx.restore();
}

function drawEnemies(ctx, state, colors, time) {
  for (let i = 0; i < state.enemyCount; i++) {
    const e = state.enemies[i];
    if (!e || !e.alive) continue;
    if (e.y < -20 || e.y > CANVAS_H + 20) continue;
    drawEnemy(ctx, e.x, e.y, e.type, colors, time);
  }
}

function drawEnemy(ctx, x, y, type, colors, time) {
  ctx.save();
  ctx.translate(x, y);

  if (type === ENEMY_TYPE.BOAT) {
    // Patrol boat with hull, cabin, and wake
    ctx.shadowColor = colors.bankHi;
    ctx.shadowBlur = 5;
    // Hull
    ctx.fillStyle = colors.bank;
    ctx.beginPath();
    ctx.moveTo(-7, -3);
    ctx.lineTo(-5, -5);
    ctx.lineTo(5, -5);
    ctx.lineTo(7, -3);
    ctx.lineTo(6, 4);
    ctx.lineTo(-6, 4);
    ctx.closePath();
    ctx.fill();
    // Cabin
    ctx.fillStyle = colors.bankHi;
    ctx.fillRect(-3, -4, 6, 5);
    // Wake trail
    ctx.globalAlpha = 0.3;
    ctx.strokeStyle = colors.bankHi;
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(-4, 5);
    ctx.lineTo(-7, 12);
    ctx.moveTo(4, 5);
    ctx.lineTo(7, 12);
    ctx.stroke();
    ctx.globalAlpha = 1;
  } else if (type === ENEMY_TYPE.HELI) {
    // Attack helicopter with body, tail boom, rotor blades
    ctx.shadowColor = colors.warning;
    ctx.shadowBlur = 6;
    // Body
    ctx.fillStyle = colors.warning;
    ctx.beginPath();
    ctx.moveTo(0, -5);
    ctx.lineTo(-4, -2);
    ctx.lineTo(-4, 4);
    ctx.lineTo(-2, 6);
    ctx.lineTo(2, 6);
    ctx.lineTo(4, 4);
    ctx.lineTo(4, -2);
    ctx.closePath();
    ctx.fill();
    // Tail boom
    ctx.fillRect(-1, 6, 2, 5);
    ctx.fillRect(-3, 10, 6, 2);
    // Rotor blades (spinning)
    const angle = time * 0.02;
    ctx.strokeStyle = colors.missile;
    ctx.lineWidth = 1.5;
    ctx.shadowColor = colors.missile;
    ctx.shadowBlur = 3;
    ctx.beginPath();
    ctx.moveTo(Math.cos(angle) * -10, Math.sin(angle) * -3);
    ctx.lineTo(Math.cos(angle) * 10, Math.sin(angle) * 3);
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(Math.cos(angle + Math.PI / 2) * -10, Math.sin(angle + Math.PI / 2) * -3);
    ctx.lineTo(Math.cos(angle + Math.PI / 2) * 10, Math.sin(angle + Math.PI / 2) * 3);
    ctx.stroke();
    // Rotor hub
    ctx.fillStyle = colors.missile;
    ctx.beginPath();
    ctx.arc(0, 0, 1.5, 0, Math.PI * 2);
    ctx.fill();
    // Searchlight (pulsing)
    const beamPulse = 0.2 + Math.sin(time * 0.006) * 0.15;
    ctx.globalAlpha = beamPulse;
    ctx.fillStyle = colors.missile;
    ctx.beginPath();
    ctx.arc(0, -5, 3, 0, Math.PI * 2);
    ctx.fill();
    ctx.globalAlpha = 1;
  } else if (type === ENEMY_TYPE.JET) {
    // Enemy interceptor — inverted, flying TOWARD player, with trail
    ctx.shadowColor = colors.explosion;
    ctx.shadowBlur = 8;
    // Exhaust trail (going upward — the jet came from above)
    ctx.globalAlpha = 0.15;
    ctx.fillStyle = colors.explosion;
    for (let i = 1; i <= 4; i++) {
      ctx.beginPath();
      ctx.arc(0, -6 - i * 5, 2 + i * 0.5, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.globalAlpha = 1;
    // Body — inverted delta pointing DOWN
    ctx.fillStyle = colors.explosion;
    ctx.beginPath();
    ctx.moveTo(0, 8); // nose (pointing down toward player)
    ctx.lineTo(-7, -5); // left wing
    ctx.lineTo(-2, -3); // left inner
    ctx.lineTo(0, -6); // tail center
    ctx.lineTo(2, -3); // right inner
    ctx.lineTo(7, -5); // right wing
    ctx.closePath();
    ctx.fill();
    // Cockpit
    ctx.fillStyle = "rgba(0, 0, 0, 0.4)";
    ctx.beginPath();
    ctx.moveTo(0, 5);
    ctx.lineTo(-1.5, 1);
    ctx.lineTo(1.5, 1);
    ctx.closePath();
    ctx.fill();
    // Wingtip warning lights
    const blink = Math.floor(time / 200) % 2 === 0;
    if (blink) {
      ctx.fillStyle = colors.explosion;
      ctx.shadowBlur = 6;
      ctx.beginPath();
      ctx.arc(-6, -4, 1, 0, Math.PI * 2);
      ctx.arc(6, -4, 1, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  ctx.shadowBlur = 0;
  ctx.restore();
}

function drawFuelStations(ctx, state, colors, time) {
  for (let i = 0; i < state.fuelCount; i++) {
    const f = state.fuels[i];
    if (!f || !f.available) continue;
    if (f.y < -20 || f.y > CANVAS_H + 20) continue;

    const pulse = 0.7 + Math.sin(time * 0.005) * 0.3;

    ctx.save();
    ctx.translate(f.x, f.y);
    ctx.shadowColor = colors.warning;
    ctx.shadowBlur = 8 * pulse;
    ctx.globalAlpha = pulse;

    // Fuel station icon — diamond shape
    ctx.fillStyle = colors.warning;
    ctx.beginPath();
    ctx.moveTo(0, -8);
    ctx.lineTo(6, 0);
    ctx.lineTo(0, 8);
    ctx.lineTo(-6, 0);
    ctx.closePath();
    ctx.fill();

    // Inner cross
    ctx.fillStyle = colors.missile;
    ctx.fillRect(-1, -4, 2, 8);
    ctx.fillRect(-4, -1, 8, 2);

    ctx.globalAlpha = 1;
    ctx.shadowBlur = 0;
    ctx.restore();
  }
}

function drawBridge(ctx, state, colors) {
  if (!state.bridgeActive) return;

  const y = state.bridgeY;
  if (y < -20 || y > CANVAS_H + 20) return;

  // Industrial bridge bars spanning the canal
  ctx.save();
  ctx.fillStyle = colors.bank;
  ctx.fillRect(0, y - BRIDGE_HEIGHT / 2, CANVAS_W, BRIDGE_HEIGHT);

  // Rivet details
  ctx.fillStyle = colors.bankHi;
  for (let rx = 50; rx < CANVAS_W; rx += 40) {
    ctx.beginPath();
    ctx.arc(rx, y, 2, 0, Math.PI * 2);
    ctx.fill();
  }

  // HP indicator (colored bars)
  const hpColor =
    state.bridgeHp >= 3 ? colors.p1 : state.bridgeHp >= 2 ? colors.warning : colors.explosion;
  ctx.fillStyle = hpColor;
  ctx.shadowColor = hpColor;
  ctx.shadowBlur = 4;
  for (let i = 0; i < state.bridgeHp; i++) {
    ctx.fillRect(CANVAS_W / 2 - 15 + i * 12, y - BRIDGE_HEIGHT / 2 - 6, 8, 4);
  }

  ctx.shadowBlur = 0;
  ctx.restore();
}

function drawMines(ctx, state, colors, time) {
  for (let i = 0; i < state.mineCount; i++) {
    const m = state.mines[i];
    if (!m || !m.active) continue;

    const color = m.owner === 1 ? colors.p1 : colors.p2;
    const pulse = 0.6 + Math.sin(time * 0.008 + i) * 0.4;

    ctx.save();
    ctx.translate(m.x, m.y);
    ctx.shadowColor = color;
    ctx.shadowBlur = 6 * pulse;

    // Mine body — circle with spikes
    ctx.fillStyle = color;
    ctx.globalAlpha = pulse;
    ctx.beginPath();
    ctx.arc(0, 0, MINE_RADIUS, 0, Math.PI * 2);
    ctx.fill();

    // Spikes
    for (let s = 0; s < 6; s++) {
      const sAngle = (Math.PI * 2 * s) / 6;
      ctx.fillRect(Math.cos(sAngle) * MINE_RADIUS - 1, Math.sin(sAngle) * MINE_RADIUS - 1, 2, 2);
    }

    ctx.globalAlpha = 1;
    ctx.shadowBlur = 0;
    ctx.restore();
  }
}

function drawParticles(ctx, particles, colors) {
  for (const p of particles) {
    const alpha = p.life / p.maxLife;
    ctx.globalAlpha = alpha;
    ctx.fillStyle = colors.explosion;
    const size = 2 + alpha * 2;
    ctx.fillRect(p.x - size / 2, p.y - size / 2, size, size);
  }
  ctx.globalAlpha = 1;
}

// --- HUD ---

function drawHUD(ctx, state, colors, time) {
  ctx.save();

  // Top bar background
  ctx.fillStyle = "rgba(0, 0, 0, 0.6)";
  ctx.fillRect(0, 0, CANVAS_W, 22);

  // Bottom bar background
  ctx.fillRect(0, CANVAS_H - 26, CANVAS_W, 26);

  ctx.font = "bold 12px monospace";
  ctx.textBaseline = "top";

  // P1 score (top left)
  ctx.fillStyle = colors.p1;
  ctx.shadowColor = colors.p1;
  ctx.shadowBlur = 4;
  ctx.textAlign = "left";
  ctx.fillText(`P1: ${state.score1}`, 8, 5);

  // Distance / mode (top center)
  ctx.fillStyle = colors.warning;
  ctx.shadowColor = colors.warning;
  ctx.textAlign = "center";
  const modeName =
    state.mode === GAME_MODE.PACIFIST
      ? "PACIFIST"
      : state.mode === GAME_MODE.BLITZ
        ? "BLITZ"
        : "RAID";
  const dist = Math.floor(state.scrollY / 100);
  ctx.fillText(`${modeName} ${dist}m`, CANVAS_W / 2, 5);

  // P2 score (top right)
  ctx.fillStyle = colors.p2;
  ctx.shadowColor = colors.p2;
  ctx.textAlign = "right";
  ctx.fillText(`P2: ${state.score2}`, CANVAS_W - 8, 5);

  ctx.shadowBlur = 0;

  // Bottom bar: fuel + lives
  ctx.textBaseline = "top";
  const barY = CANVAS_H - 22;

  // P1 fuel bar
  drawFuelBar(ctx, 8, barY, 120, 10, state.jet1Fuel, colors.p1, time, colors);
  ctx.fillStyle = colors.p1;
  ctx.textAlign = "left";
  ctx.fillText(formatFuel(state.jet1Fuel), 132, barY);
  drawLives(ctx, 180, barY, state.jet1Lives, colors.p1);

  // P2 fuel bar
  drawFuelBar(ctx, CANVAS_W - 128, barY, 120, 10, state.jet2Fuel, colors.p2, time, colors);
  ctx.fillStyle = colors.p2;
  ctx.textAlign = "right";
  ctx.fillText(formatFuel(state.jet2Fuel), CANVAS_W - 132, barY);
  drawLives(ctx, CANVAS_W - 200, barY, state.jet2Lives, colors.p2);

  ctx.restore();
}

function drawFuelBar(ctx, x, y, w, h, fuel, color, time, colors) {
  const pct = fuel / 255;

  // Background
  ctx.fillStyle = "rgba(255, 255, 255, 0.1)";
  ctx.fillRect(x, y, w, h);

  // Fuel level
  const barColor = pct < 0.2 ? colors.explosion : color;

  // Blink when low
  if (pct < 0.2 && Math.floor(time / 300) % 2 === 0) {
    ctx.fillStyle = "rgba(255, 68, 68, 0.5)";
  } else {
    ctx.fillStyle = barColor;
  }
  ctx.fillRect(x, y, w * pct, h);

  // Border
  ctx.strokeStyle = color;
  ctx.lineWidth = 1;
  ctx.strokeRect(x, y, w, h);
}

function drawLives(ctx, x, y, lives, color) {
  ctx.fillStyle = color;
  ctx.font = "10px monospace";
  ctx.textAlign = "left";
  let text = "";
  for (let i = 0; i < 3; i++) {
    text += i < lives ? "\u2665 " : "\u2661 ";
  }
  ctx.fillText(text.trim(), x, y + 1);
}

// --- Overlays ---

function drawOverlayText(ctx, colors, text, color, fontSize) {
  ctx.fillStyle = "rgba(0, 0, 0, 0.5)";
  ctx.fillRect(0, 0, CANVAS_W, CANVAS_H);

  ctx.save();
  ctx.fillStyle = color;
  ctx.shadowColor = color;
  ctx.shadowBlur = 10;
  ctx.font = `bold ${fontSize || 20}px monospace`;
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText(text, CANVAS_W / 2, CANVAS_H / 2);
  ctx.restore();
}

function drawGameOver(ctx, state, colors) {
  ctx.fillStyle = "rgba(0, 0, 0, 0.7)";
  ctx.fillRect(0, 0, CANVAS_W, CANVAS_H);

  ctx.save();
  const winner = state.score1 >= state.score2 ? 1 : 2;
  const winColor = winner === 1 ? colors.p1 : colors.p2;

  ctx.fillStyle = winColor;
  ctx.shadowColor = winColor;
  ctx.shadowBlur = 10;
  ctx.font = "bold 28px monospace";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText(`PLAYER ${winner} WINS!`, CANVAS_W / 2, CANVAS_H / 2 - 25);

  ctx.shadowBlur = 0;
  ctx.font = "bold 16px monospace";
  ctx.fillStyle = colors.warning;
  ctx.fillText(`${state.score1} - ${state.score2}`, CANVAS_W / 2, CANVAS_H / 2 + 10);

  ctx.font = "12px monospace";
  ctx.fillStyle = colors.bankHi;
  const dist = Math.floor(state.scrollY / 100);
  ctx.fillText(`${dist}m reached`, CANVAS_W / 2, CANVAS_H / 2 + 35);
  ctx.restore();
}

// --- CRT effects ---

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
