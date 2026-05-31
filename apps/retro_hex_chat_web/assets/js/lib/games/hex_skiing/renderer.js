/**
 * Hex Skiing — Canvas renderer.
 *
 * Cyberpunk post-apocalyptic aesthetic: toxic snow, mutant pines,
 * radioactive avalanche, neon-lit slalom gates, CRT scanlines.
 */

import {
  CANVAS_W,
  CANVAS_H,
  SKIER_SCREEN_Y,
  SKIER_W,
  SKIER_H,
  TREE_W,
  TREE_H,
  ROCK_W,
  ROCK_H,
  ICE_PATCH_W,
  ICE_PATCH_H,
  ITEM_W,
  ITEM_H,
  COURSE_LENGTH,
} from "./physics.js";
import { PHASE, GAME_MODE, SKIER_STATE } from "./protocol.js";
import { t, jt } from "../../i18n.js";

/**
 * Read CSS custom properties from the canvas element.
 */
export function readColors(canvas) {
  const s = getComputedStyle(canvas);
  const get = (name) => s.getPropertyValue(name).trim() || null;
  return {
    bg: get("--game-bg-color") || "#0a0a14",
    fg: get("--game-fg-color") || "#39ff14",
    accent: get("--game-accent-color") || "#00e5ff",
    muted: get("--game-muted-color") || "#1a1a2a",
    glow: get("--game-glow-color") || "rgba(57,255,20,0.15)",
    warning: get("--game-warning-color") || "#ff4444",
    snow: get("--game-snow-color") || "#1a1a2e",
    tree: get("--game-tree-color") || "#1a3a1a",
    rock: get("--game-rock-color") || "#555566",
    avalanche: get("--game-avalanche-color") || "#2a2a3a",
    gateLeft: get("--game-gate-left") || "#4488ff",
    gateRight: get("--game-gate-right") || "#ff4444",
    boost: get("--game-boost-color") || "#ffee00",
    ice: get("--game-ice-color") || "#00ccff",
    trail: get("--game-trail-color") || "rgba(57,255,20,0.3)",
  };
}

/**
 * Generate static snow particle positions (visual-only, non-deterministic).
 */
function generateSnowParticles(count) {
  const particles = [];
  for (let i = 0; i < count; i++) {
    particles.push({
      x: Math.random() * CANVAS_W,
      y: Math.random() * CANVAS_H,
      size: 1 + Math.random() * 2,
      speed: 0.3 + Math.random() * 0.7,
      drift: (Math.random() - 0.5) * 0.5,
    });
  }
  return particles;
}

/**
 * Main render function.
 * @param {CanvasRenderingContext2D} ctx
 * @param {object} state - game state (nested format)
 * @param {object} colors - color palette
 * @param {number} frameCount - for animations
 * @param {Array} snowParticles - pre-generated snow
 */
export function render(ctx, state, colors, frameCount, snowParticles) {
  if (!state) return;

  switch (state.phase) {
    case PHASE.WAITING:
      drawWaitingScreen(ctx, colors, frameCount);
      return;
    case PHASE.COUNTDOWN:
      drawBackground(ctx, state, colors, frameCount, snowParticles);
      drawObstacles(ctx, state, colors);
      drawGates(ctx, state, colors, frameCount);
      drawItems(ctx, state, colors, frameCount);
      drawSkiers(ctx, state, colors, frameCount);
      drawAvalanche(ctx, state, colors, frameCount);
      drawBlizzard(ctx, state, colors, frameCount);
      drawHUD(ctx, state, colors);
      drawCountdown(ctx, state, colors, frameCount);
      drawCRT(ctx);
      return;
    case PHASE.RACING:
      drawBackground(ctx, state, colors, frameCount, snowParticles);
      drawObstacles(ctx, state, colors);
      drawGates(ctx, state, colors, frameCount);
      drawItems(ctx, state, colors, frameCount);
      drawSkiers(ctx, state, colors, frameCount);
      drawAvalanche(ctx, state, colors, frameCount);
      drawBlizzard(ctx, state, colors, frameCount);
      drawFinishLine(ctx, state, colors);
      drawHUD(ctx, state, colors);
      drawCRT(ctx);
      return;
    case PHASE.ROUND_END:
      drawBackground(ctx, state, colors, frameCount, snowParticles);
      drawObstacles(ctx, state, colors);
      drawSkiers(ctx, state, colors, frameCount);
      drawHUD(ctx, state, colors);
      drawRoundEnd(ctx, state, colors, frameCount);
      drawCRT(ctx);
      return;
    case PHASE.FINISHED:
      drawBackground(ctx, state, colors, frameCount, snowParticles);
      drawHUD(ctx, state, colors);
      drawFinished(ctx, state, colors, frameCount);
      drawCRT(ctx);
      return;
    default:
      break;
  }
}

// ── Background ─────────────────────────────────────────────────

function drawBackground(ctx, state, colors, frameCount, snowParticles) {
  // Dark toxic snow base
  ctx.fillStyle = colors.bg;
  ctx.fillRect(0, 0, CANVAS_W, CANVAS_H);

  // Subtle snow texture — scrolling dots
  ctx.fillStyle = colors.snow;
  const scrollOffset = state.scrollY % 20;
  for (let y = -20 + scrollOffset; y < CANVAS_H; y += 20) {
    for (let x = 0; x < CANVAS_W; x += 20) {
      const ox = ((x + y * 7) % 37) * 0.5;
      ctx.fillRect(x + ox, y, 1, 1);
    }
  }

  // Ambient snow particles (falling)
  if (snowParticles) {
    ctx.fillStyle = "rgba(57, 255, 20, 0.08)";
    for (const p of snowParticles) {
      const py = (p.y + frameCount * p.speed) % CANVAS_H;
      const px = p.x + Math.sin(frameCount * 0.02 + p.drift * 10) * 3;
      ctx.fillRect(px, py, p.size, p.size);
    }
  }
}

// ── Obstacles ──────────────────────────────────────────────────

function drawObstacles(ctx, state, colors) {
  const viewTop = state.scrollY;
  const viewBot = state.scrollY + CANVAS_H;

  for (const obs of state.obstacles || []) {
    if (obs.y < viewTop - 20 || obs.y > viewBot + 20) continue;

    const screenX = obs.x;
    const screenY = obs.y - state.scrollY;

    if (obs.type === "tree") {
      drawTree(ctx, screenX, screenY, colors);
    } else if (obs.type === "rock") {
      drawRock(ctx, screenX, screenY, colors);
    } else if (obs.type === "ice") {
      drawIcePatch(ctx, screenX, screenY, colors);
    }
  }
}

function drawTree(ctx, x, y, colors) {
  // Mutant pine tree — toxic green with dark trunk
  const hw = TREE_W / 2;

  // Trunk
  ctx.fillStyle = "#2a1a0a";
  ctx.fillRect(x - 1, y + 2, 3, TREE_H - 4);

  // Canopy layers (triangle)
  ctx.fillStyle = colors.tree;
  // Bottom layer
  ctx.fillRect(x - hw, y + 2, TREE_W, 4);
  // Middle layer
  ctx.fillRect(x - hw + 1, y - 1, TREE_W - 2, 4);
  // Top
  ctx.fillRect(x - 2, y - 4, 4, 3);
  ctx.fillRect(x - 1, y - 6, 2, 2);

  // Toxic glow tip
  ctx.fillStyle = "#39ff14";
  ctx.fillRect(x, y - 6, 1, 1);
}

function drawRock(ctx, x, y, colors) {
  const hw = ROCK_W / 2;
  const hh = ROCK_H / 2;

  // Rock body
  ctx.fillStyle = colors.rock;
  ctx.fillRect(x - hw, y - hh + 1, ROCK_W, ROCK_H - 2);
  ctx.fillRect(x - hw + 1, y - hh, ROCK_W - 2, ROCK_H);

  // Highlight
  ctx.fillStyle = "#777788";
  ctx.fillRect(x - hw + 1, y - hh + 1, 2, 2);
}

function drawIcePatch(ctx, x, y, _colors) {
  const hw = ICE_PATCH_W / 2;
  const hh = ICE_PATCH_H / 2;

  ctx.fillStyle = "rgba(0, 204, 255, 0.15)";
  ctx.fillRect(x - hw, y - hh, ICE_PATCH_W, ICE_PATCH_H);

  // Shimmer effect
  ctx.fillStyle = "rgba(0, 204, 255, 0.3)";
  ctx.fillRect(x - hw + 2, y - hh + 2, 4, 2);
  ctx.fillRect(x + hw - 6, y + hh - 4, 4, 2);
  ctx.fillRect(x - 2, y - 1, 3, 1);
}

// ── Gates ──────────────────────────────────────────────────────

function drawGates(ctx, state, colors, frameCount) {
  const viewTop = state.scrollY;
  const viewBot = state.scrollY + CANVAS_H;

  for (const gate of state.gates || []) {
    if (gate.y < viewTop - 10 || gate.y > viewBot + 10) continue;

    const screenY = gate.y - state.scrollY;
    const leftX = gate.x;
    const rightX = gate.x + gate.width;

    const cleared = gate.clearedP1 || gate.clearedP2;

    // Left flag (blue)
    ctx.fillStyle = cleared ? colors.boost : colors.gateLeft;
    ctx.fillRect(leftX - 3, screenY - 8, 2, 16);
    ctx.fillRect(leftX - 1, screenY - 8, 6, 4);

    // Right flag (red)
    ctx.fillStyle = cleared ? colors.boost : colors.gateRight;
    ctx.fillRect(rightX + 1, screenY - 8, 2, 16);
    ctx.fillRect(rightX - 5, screenY - 8, 6, 4);

    // Connecting bar (dashed)
    ctx.fillStyle = cleared ? "rgba(255, 238, 0, 0.3)" : "rgba(255, 255, 255, 0.15)";
    for (let dx = leftX + 4; dx < rightX - 4; dx += 6) {
      ctx.fillRect(dx, screenY - 1, 3, 2);
    }

    // Cleared flash
    if (cleared && frameCount % 10 < 5) {
      ctx.fillStyle = "rgba(255, 238, 0, 0.1)";
      ctx.fillRect(leftX, screenY - 10, gate.width, 20);
    }
  }
}

// ── Items ──────────────────────────────────────────────────────

function drawItems(ctx, state, colors, frameCount) {
  const viewTop = state.scrollY;
  const viewBot = state.scrollY + CANVAS_H;

  for (const item of state.items || []) {
    if (item.collected !== 0) continue;
    if (item.y < viewTop - 10 || item.y > viewBot + 10) continue;

    const screenY = item.y - state.scrollY;
    const x = item.x;

    // Speed boost: pulsing lightning bolt
    const pulse = Math.sin(frameCount * 0.15) * 0.3 + 0.7;
    ctx.globalAlpha = pulse;

    // Glow
    ctx.fillStyle = "rgba(255, 238, 0, 0.2)";
    ctx.fillRect(x - ITEM_W / 2 - 2, screenY - ITEM_H / 2 - 2, ITEM_W + 4, ITEM_H + 4);

    // Bolt shape
    ctx.fillStyle = colors.boost;
    ctx.fillRect(x - 1, screenY - 5, 4, 3);
    ctx.fillRect(x - 3, screenY - 2, 6, 2);
    ctx.fillRect(x - 1, screenY, 4, 3);
    ctx.fillRect(x + 1, screenY + 3, 2, 2);

    ctx.globalAlpha = 1;
  }
}

// ── Skiers ─────────────────────────────────────────────────────

function drawSkiers(ctx, state, colors, frameCount) {
  if (state.p1) drawSkier(ctx, state.p1, colors.fg, frameCount, state.scrollY);
  if (state.p2) drawSkier(ctx, state.p2, colors.accent, frameCount, state.scrollY);
}

function drawSkier(ctx, player, color, frameCount, _scrollY) {
  const x = player.x;
  const y = SKIER_SCREEN_Y;

  if (player.state === SKIER_STATE.CRASHED) {
    // Crash animation: scattered pixels
    ctx.fillStyle = color;
    const scatter = Math.sin(frameCount * 0.3) * 3;
    ctx.fillRect(x - 4 + scatter, y - 3, 3, 3);
    ctx.fillRect(x + 1 - scatter, y + 1, 3, 3);
    ctx.fillRect(x - 2, y - 5 + scatter, 2, 2);
    ctx.fillRect(x + 2, y + 3 - scatter, 2, 2);

    // Crash particles (snow burst)
    ctx.fillStyle = "rgba(255, 255, 255, 0.4)";
    for (let i = 0; i < 4; i++) {
      const angle = frameCount * 0.1 + i * 1.57;
      const dist = 5 + Math.sin(frameCount * 0.2) * 3;
      ctx.fillRect(x + Math.cos(angle) * dist, y + Math.sin(angle) * dist, 2, 2);
    }
    return;
  }

  // Normal/boosted skier
  const hw = SKIER_W / 2;
  const hh = SKIER_H / 2;

  // Ski trails behind
  ctx.fillStyle = "rgba(57, 255, 20, 0.12)";
  if (color.includes("e5ff")) ctx.fillStyle = "rgba(0, 229, 255, 0.12)";
  ctx.fillRect(x - hw + 1, y + hh, 2, 8);
  ctx.fillRect(x + hw - 3, y + hh, 2, 8);

  // Body
  ctx.fillStyle = color;
  // Head
  ctx.fillRect(x - 2, y - hh, 4, 3);
  // Torso
  ctx.fillRect(x - 3, y - hh + 3, 6, 4);
  // Legs
  ctx.fillRect(x - 3, y - hh + 7, 2, 3);
  ctx.fillRect(x + 1, y - hh + 7, 2, 3);
  // Skis
  ctx.fillRect(x - hw, y + hh - 2, 2, 4);
  ctx.fillRect(x + hw - 2, y + hh - 2, 2, 4);

  // Lean indicator (skis angle based on velocity)
  if (Math.abs(player.velX) > 1) {
    const lean = player.velX > 0 ? 1 : -1;
    ctx.fillRect(x + lean * 3, y + hh - 1, 2, 2);
  }

  // Boost effect: speed lines behind
  if (player.state === SKIER_STATE.BOOSTED) {
    ctx.fillStyle = "rgba(255, 238, 0, 0.4)";
    for (let i = 0; i < 3; i++) {
      const ly = y + hh + 4 + i * 5;
      const lx = x - 2 + ((frameCount + i * 7) % 5);
      ctx.fillRect(lx, ly, 1, 3);
    }
    // Glow around skier
    ctx.fillStyle = "rgba(255, 238, 0, 0.08)";
    ctx.fillRect(x - hw - 3, y - hh - 3, SKIER_W + 6, SKIER_H + 6);
  }

  // Ice effect: blue shimmer
  if (player.iceTimer > 0) {
    ctx.fillStyle = "rgba(0, 204, 255, 0.2)";
    ctx.fillRect(x - hw - 2, y - hh - 2, SKIER_W + 4, SKIER_H + 4);
  }
}

// ── Avalanche ──────────────────────────────────────────────────

function drawAvalanche(ctx, state, colors, frameCount) {
  if (state.mode === GAME_MODE.CLEAN_RUN) return;

  const screenY = state.avalancheY - state.scrollY;
  if (screenY > CANVAS_H) return; // Not visible yet

  const topY = Math.max(0, screenY - 60);
  const botY = Math.min(CANVAS_H, screenY);

  if (botY <= 0) {
    // Avalanche fills entire screen
    ctx.fillStyle = colors.avalanche;
    ctx.fillRect(0, 0, CANVAS_W, CANVAS_H);
    return;
  }

  // Dense body (above the edge)
  if (topY > 0) {
    ctx.fillStyle = colors.avalanche;
    ctx.fillRect(0, 0, CANVAS_W, topY);
  }

  // Gradient edge (the rolling front)
  const grad = ctx.createLinearGradient(0, topY, 0, botY);
  grad.addColorStop(0, colors.avalanche);
  grad.addColorStop(0.6, "rgba(42, 42, 58, 0.6)");
  grad.addColorStop(1, "rgba(42, 42, 58, 0)");
  ctx.fillStyle = grad;
  ctx.fillRect(0, topY, CANVAS_W, botY - topY);

  // Toxic green glow at the edge
  const edgeGrad = ctx.createLinearGradient(0, botY - 15, 0, botY + 5);
  edgeGrad.addColorStop(0, "rgba(57, 255, 20, 0)");
  edgeGrad.addColorStop(0.5, "rgba(57, 255, 20, 0.15)");
  edgeGrad.addColorStop(1, "rgba(57, 255, 20, 0)");
  ctx.fillStyle = edgeGrad;
  ctx.fillRect(0, botY - 15, CANVAS_W, 20);

  // Debris particles at the edge
  ctx.fillStyle = "rgba(255, 255, 255, 0.3)";
  for (let i = 0; i < 12; i++) {
    const px = (i * 53 + frameCount * 2) % CANVAS_W;
    const py = botY - 5 + Math.sin(frameCount * 0.1 + i) * 8;
    ctx.fillRect(px, py, 2, 2);
  }
}

// ── Blizzard ───────────────────────────────────────────────────

function drawBlizzard(ctx, state, colors, frameCount) {
  if (!state.blizzardActive) return;

  // Dark overlay (reduced visibility)
  ctx.fillStyle = "rgba(10, 10, 20, 0.55)";
  ctx.fillRect(0, 0, CANVAS_W, CANVAS_H);

  // Dense snow particles
  ctx.fillStyle = "rgba(57, 255, 20, 0.15)";
  for (let i = 0; i < 60; i++) {
    const px = ((i * 47 + frameCount * 3) % (CANVAS_W + 40)) - 20;
    const py = ((i * 31 + frameCount * 4) % (CANVAS_H + 40)) - 20;
    const size = 1 + (i % 3);
    ctx.fillRect(px, py, size, size);
  }

  // White particles
  ctx.fillStyle = "rgba(255, 255, 255, 0.1)";
  for (let i = 0; i < 30; i++) {
    const px = (i * 73 + frameCount * 2) % CANVAS_W;
    const py = (i * 59 + frameCount * 5) % CANVAS_H;
    ctx.fillRect(px, py, 2, 1);
  }
}

// ── Finish Line ────────────────────────────────────────────────

function drawFinishLine(ctx, state, colors) {
  if (state.mode === GAME_MODE.AVALANCHE_ESCAPE) return;

  const finishWorldY = COURSE_LENGTH;
  const screenY = finishWorldY - state.scrollY;
  if (screenY < -10 || screenY > CANVAS_H + 10) return;

  // Checkered pattern
  const squareSize = 8;
  for (let x = 0; x < CANVAS_W; x += squareSize) {
    const row = Math.floor(x / squareSize);
    ctx.fillStyle = row % 2 === 0 ? colors.fg : colors.bg;
    ctx.fillRect(x, screenY - 2, squareSize, 4);
    ctx.fillStyle = row % 2 === 0 ? colors.bg : colors.fg;
    ctx.fillRect(x, screenY + 2, squareSize, 4);
  }

  // "FINISH" text
  ctx.fillStyle = colors.fg;
  ctx.font = "bold 10px monospace";
  ctx.textAlign = "center";
  ctx.fillText("FINISH", CANVAS_W / 2, screenY - 8);
}

// ── HUD ────────────────────────────────────────────────────────

function drawHUD(ctx, state, colors) {
  if (!state.p1 || !state.p2) return;

  // Top bar
  ctx.fillStyle = "rgba(0, 0, 0, 0.6)";
  ctx.fillRect(0, 0, CANVAS_W, 24);

  ctx.font = "bold 11px monospace";
  ctx.textBaseline = "middle";

  // P1 timer (left)
  ctx.fillStyle = colors.fg;
  ctx.textAlign = "left";
  ctx.fillText(jt`P1 ${formatTime(state.p1.timer)}`, 8, 12);

  // Game title + round (center)
  ctx.fillStyle = "#aaaaaa";
  ctx.textAlign = "center";
  const modeLabel = getModeLabel(state.mode);
  if (state.mode === GAME_MODE.ALPINE_RACE) {
    ctx.fillText(jt`${modeLabel} R${state.round + 1}/3`, CANVAS_W / 2, 12);
  } else {
    ctx.fillText(modeLabel, CANVAS_W / 2, 12);
  }

  // P2 timer (right)
  ctx.fillStyle = colors.accent;
  ctx.textAlign = "right";
  ctx.fillText(jt`P2 ${formatTime(state.p2.timer)}`, CANVAS_W - 8, 12);

  // Round wins indicators
  if (state.mode === GAME_MODE.ALPINE_RACE) {
    drawRoundWins(ctx, state, colors);
  }

  // Avalanche proximity bar (bottom)
  if (state.mode !== GAME_MODE.CLEAN_RUN) {
    drawAvalancheBar(ctx, state, colors);
  }

  // Distance progress (bottom right, non-escape modes)
  if (state.mode !== GAME_MODE.AVALANCHE_ESCAPE) {
    const progress = Math.min(1, Math.max(state.p1.distance, state.p2.distance) / COURSE_LENGTH);
    ctx.fillStyle = "rgba(0, 0, 0, 0.5)";
    ctx.fillRect(CANVAS_W - 110, CANVAS_H - 16, 102, 10);
    ctx.fillStyle = colors.muted;
    ctx.fillRect(CANVAS_W - 109, CANVAS_H - 15, 100, 8);
    ctx.fillStyle = colors.fg;
    ctx.fillRect(CANVAS_W - 109, CANVAS_H - 15, Math.round(progress * 100), 8);
    ctx.font = "8px monospace";
    ctx.fillStyle = "#aaaaaa";
    ctx.textAlign = "right";
    ctx.fillText(`${Math.round(progress * 100)}%`, CANVAS_W - 4, CANVAS_H - 6);
  }
}

function drawRoundWins(ctx, state, colors) {
  const y = 12;
  // P1 wins (left side)
  for (let i = 0; i < state.p1RoundWins; i++) {
    ctx.fillStyle = colors.fg;
    ctx.fillRect(100 + i * 10, y - 3, 6, 6);
  }
  // P2 wins (right side)
  for (let i = 0; i < state.p2RoundWins; i++) {
    ctx.fillStyle = colors.accent;
    ctx.fillRect(CANVAS_W - 120 + i * 10, y - 3, 6, 6);
  }
}

function drawAvalancheBar(ctx, state, colors) {
  const avalancheScreenY = state.avalancheY - state.scrollY;
  // Proximity: 0 = far (top of screen), 1 = at skier
  const proximity = Math.max(0, Math.min(1, avalancheScreenY / SKIER_SCREEN_Y));

  ctx.fillStyle = "rgba(0, 0, 0, 0.5)";
  ctx.fillRect(4, CANVAS_H - 16, 102, 10);
  ctx.fillStyle = colors.muted;
  ctx.fillRect(5, CANVAS_H - 15, 100, 8);

  // Color changes based on proximity
  if (proximity > 0.7) {
    ctx.fillStyle = colors.warning;
  } else if (proximity > 0.4) {
    ctx.fillStyle = colors.boost;
  } else {
    ctx.fillStyle = colors.fg;
  }
  ctx.fillRect(5, CANVAS_H - 15, Math.round(proximity * 100), 8);

  ctx.font = "8px monospace";
  ctx.fillStyle = "#aaaaaa";
  ctx.textAlign = "left";
  ctx.fillText("AVL", 6, CANVAS_H - 6);
}

// ── Phase overlays ─────────────────────────────────────────────

function drawWaitingScreen(ctx, colors, frameCount) {
  ctx.fillStyle = colors.bg;
  ctx.fillRect(0, 0, CANVAS_W, CANVAS_H);

  // Title
  ctx.fillStyle = colors.fg;
  ctx.font = "bold 28px monospace";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText(t("HEX SKIING"), CANVAS_W / 2, CANVAS_H / 2 - 40);

  // Subtitle
  ctx.fillStyle = colors.accent;
  ctx.font = "12px monospace";
  ctx.fillText(t("TOXIC DESCENT"), CANVAS_W / 2, CANVAS_H / 2 - 10);

  // Waiting text
  ctx.fillStyle = colors.muted;
  ctx.font = "11px monospace";
  const dots = ".".repeat((Math.floor(frameCount / 30) % 3) + 1);
  ctx.fillText(jt`Waiting for opponent${dots}`, CANVAS_W / 2, CANVAS_H / 2 + 30);

  // Decorative mountains
  ctx.fillStyle = "#151525";
  ctx.beginPath();
  ctx.moveTo(0, CANVAS_H);
  ctx.lineTo(80, CANVAS_H - 100);
  ctx.lineTo(160, CANVAS_H);
  ctx.fill();
  ctx.beginPath();
  ctx.moveTo(200, CANVAS_H);
  ctx.lineTo(320, CANVAS_H - 140);
  ctx.lineTo(440, CANVAS_H);
  ctx.fill();
  ctx.beginPath();
  ctx.moveTo(400, CANVAS_H);
  ctx.lineTo(540, CANVAS_H - 90);
  ctx.lineTo(640, CANVAS_H);
  ctx.fill();

  drawCRT(ctx);
}

function drawCountdown(ctx, state, colors, frameCount) {
  ctx.fillStyle = "rgba(0, 0, 0, 0.4)";
  ctx.fillRect(0, 0, CANVAS_W, CANVAS_H);

  const num = state.countdown;
  const scale = 1 + Math.sin(frameCount * 0.3) * 0.1;
  ctx.save();
  ctx.translate(CANVAS_W / 2, CANVAS_H / 2);
  ctx.scale(scale, scale);
  ctx.fillStyle = colors.fg;
  ctx.font = "bold 64px monospace";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText(num > 0 ? String(num) : t("GO!"), 0, 0);
  ctx.restore();
}

function drawRoundEnd(ctx, state, colors, frameCount) {
  ctx.fillStyle = "rgba(0, 0, 0, 0.6)";
  ctx.fillRect(0, 0, CANVAS_W, CANVAS_H);

  ctx.textAlign = "center";
  ctx.textBaseline = "middle";

  // Round result
  ctx.fillStyle = colors.fg;
  ctx.font = "bold 20px monospace";
  ctx.fillText(jt`ROUND ${state.round + 1} COMPLETE`, CANVAS_W / 2, CANVAS_H / 2 - 40);

  // Times
  ctx.font = "14px monospace";
  ctx.fillStyle = colors.fg;
  ctx.fillText(jt`P1: ${formatTime(state.p1.timer)}`, CANVAS_W / 2, CANVAS_H / 2 - 10);
  ctx.fillStyle = colors.accent;
  ctx.fillText(jt`P2: ${formatTime(state.p2.timer)}`, CANVAS_W / 2, CANVAS_H / 2 + 10);

  // Score
  ctx.fillStyle = "#aaaaaa";
  ctx.font = "12px monospace";
  ctx.fillText(
    jt`Score: ${state.p1RoundWins} - ${state.p2RoundWins}`,
    CANVAS_W / 2,
    CANVAS_H / 2 + 40,
  );

  // Next round hint
  if (frameCount % 60 < 40) {
    ctx.fillStyle = colors.muted;
    ctx.font = "10px monospace";
    ctx.fillText(t("Next round starting..."), CANVAS_W / 2, CANVAS_H / 2 + 70);
  }
}

function drawFinished(ctx, state, colors, frameCount) {
  ctx.fillStyle = "rgba(0, 0, 0, 0.7)";
  ctx.fillRect(0, 0, CANVAS_W, CANVAS_H);

  ctx.textAlign = "center";
  ctx.textBaseline = "middle";

  // Winner announcement
  const winner =
    state.p1RoundWins > state.p2RoundWins ? 1 : state.p2RoundWins > state.p1RoundWins ? 2 : 0;

  ctx.font = "bold 24px monospace";
  if (winner === 1) {
    ctx.fillStyle = colors.fg;
    ctx.fillText(t("PLAYER 1 WINS!"), CANVAS_W / 2, CANVAS_H / 2 - 40);
  } else if (winner === 2) {
    ctx.fillStyle = colors.accent;
    ctx.fillText(t("PLAYER 2 WINS!"), CANVAS_W / 2, CANVAS_H / 2 - 40);
  } else {
    ctx.fillStyle = "#aaaaaa";
    ctx.fillText(t("DRAW!"), CANVAS_W / 2, CANVAS_H / 2 - 40);
  }

  // Final score
  ctx.font = "16px monospace";
  ctx.fillStyle = "#aaaaaa";
  ctx.fillText(`${state.p1RoundWins} - ${state.p2RoundWins}`, CANVAS_W / 2, CANVAS_H / 2);

  // Celebration particles
  if (winner > 0) {
    const winColor = winner === 1 ? colors.fg : colors.accent;
    ctx.fillStyle = winColor;
    for (let i = 0; i < 8; i++) {
      const angle = frameCount * 0.05 + i * 0.785;
      const dist = 40 + Math.sin(frameCount * 0.1 + i) * 20;
      ctx.fillRect(
        CANVAS_W / 2 + Math.cos(angle) * dist - 2,
        CANVAS_H / 2 - 40 + Math.sin(angle) * dist - 2,
        4,
        4,
      );
    }
  }
}

// ── CRT effect ─────────────────────────────────────────────────

function drawCRT(ctx) {
  // Scanlines
  ctx.fillStyle = "rgba(0, 0, 0, 0.08)";
  for (let y = 0; y < CANVAS_H; y += 3) {
    ctx.fillRect(0, y, CANVAS_W, 1);
  }

  // Vignette
  const vignette = ctx.createRadialGradient(
    CANVAS_W / 2,
    CANVAS_H / 2,
    CANVAS_W * 0.35,
    CANVAS_W / 2,
    CANVAS_H / 2,
    CANVAS_W * 0.7,
  );
  vignette.addColorStop(0, "rgba(0,0,0,0)");
  vignette.addColorStop(1, "rgba(0,0,0,0.3)");
  ctx.fillStyle = vignette;
  ctx.fillRect(0, 0, CANVAS_W, CANVAS_H);
}

// ── Helpers ────────────────────────────────────────────────────

function formatTime(seconds) {
  const mins = Math.floor(seconds / 60);
  const secs = seconds % 60;
  return `${mins}:${secs.toFixed(1).padStart(4, "0")}`;
}

function getModeLabel(mode) {
  switch (mode) {
    case GAME_MODE.ALPINE_RACE:
      return t("ALPINE RACE");
    case GAME_MODE.AVALANCHE_ESCAPE:
      return t("AVALANCHE ESCAPE");
    case GAME_MODE.CLEAN_RUN:
      return t("CLEAN RUN");
    default:
      return "SKIING";
  }
}

export { generateSnowParticles };
