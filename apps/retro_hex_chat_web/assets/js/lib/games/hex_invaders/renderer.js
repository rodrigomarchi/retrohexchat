/**
 * Canvas renderer for Hex Invaders — cyberpunk post-apocalyptic space shooter.
 * Pure rendering functions, no side effects beyond canvas drawing.
 * @module games/hex_invaders_renderer
 */

import { PHASE, GAME_MODE, ALIEN_TYPE } from "./protocol.js";
import { CANVAS_W, CANVAS_H, INITIAL_LIVES, SHIELD_SEGMENTS } from "./physics.js";
import { t, jt } from "../../i18n.js";

const DIVIDER_X = 320;
const CANNON_Y = 450;
const CANNON_W = 20;
// const CANNON_H = 12; // reserved for future cannon sprite detail
const ALIEN_W = 10;
const ALIEN_H = 8;
const UFO_Y = 18;
const UFO_W = 24;
const SHIELD_W = 30;
const SHIELD_H = 12;
const UFO_TRAIL_COLORS = ["#ff0000", "#ff8800", "#ffff00", "#00ff00", "#0088ff", "#ff00ff"];

/**
 * Read CSS custom properties from canvas computed style.
 * @param {HTMLCanvasElement} canvas
 * @returns {object} color palette
 */
export function getColors(canvas) {
  const s = getComputedStyle(canvas);
  return {
    bg: s.getPropertyValue("--game-bg-color").trim() || "#000008",
    p1: s.getPropertyValue("--game-fg-color").trim() || "#39ff14",
    p2: s.getPropertyValue("--game-accent-color").trim() || "#00e5ff",
    muted: s.getPropertyValue("--game-muted-color").trim() || "#0a1a0a",
    glow: s.getPropertyValue("--game-glow-color").trim() || "rgba(57,255,20,0.2)",
    warning: s.getPropertyValue("--game-warning-color").trim() || "#ff4444",
    shield: s.getPropertyValue("--game-shield-color").trim() || "#39ff14",
    ufo: s.getPropertyValue("--game-ufo-color").trim() || "#ff00ff",
    drop: s.getPropertyValue("--game-drop-color").trim() || "#ff3333",
  };
}

/**
 * Render a full frame.
 * @param {CanvasRenderingContext2D} ctx
 * @param {object} state
 * @param {object} colors
 * @param {number} time - performance.now() for animations
 */
export function render(ctx, state, colors, time) {
  drawBackground(ctx, state, colors, time);

  if (state.mode !== GAME_MODE.COOP) {
    drawDivider(ctx, colors);
  }

  drawShields(ctx, state, colors);
  drawAliens(ctx, state, colors, time);
  drawDropPreviews(ctx, state, colors, time);
  drawBombs(ctx, state, colors, time);
  drawMissiles(ctx, state, colors);
  drawCannons(ctx, state, colors);
  drawUFO(ctx, state, colors, time);
  drawHUD(ctx, state, colors, time);

  // Phase overlays
  if (state.phase === PHASE.WAITING) {
    drawOverlayText(ctx, colors, t("WAITING FOR OPPONENT..."), colors.p1);
  } else if (state.phase === PHASE.COUNTDOWN) {
    drawOverlayText(ctx, colors, String(state.countdown), colors.warning, 64);
  } else if (state.phase === PHASE.WAVE_CLEAR) {
    drawOverlayText(ctx, colors, jt`WAVE ${state.wave} CLEARED`, colors.p1, 28);
  } else if (state.phase === PHASE.WAVE_START) {
    drawOverlayText(ctx, colors, jt`WAVE ${state.wave}`, colors.warning, 36);
  } else if (state.phase === PHASE.FINISHED) {
    drawGameOver(ctx, state, colors);
  }

  drawScanlines(ctx);
  drawVignette(ctx);
}

// ── Background ──

function drawBackground(ctx, state, colors, time) {
  ctx.fillStyle = colors.bg;
  ctx.fillRect(0, 0, CANVAS_W, CANVAS_H);

  // Starfield (sparse, parallax)
  ctx.fillStyle = "rgba(255,255,255,0.3)";
  const starSeed = state.seed || 42;
  for (let i = 0; i < 40; i++) {
    const sx = (starSeed * (i + 1) * 7919) % CANVAS_W;
    const sy = (starSeed * (i + 1) * 6271 + Math.floor(time * 0.005)) % CANVAS_H;
    const size = i % 3 === 0 ? 2 : 1;
    ctx.fillRect(sx, sy, size, size);
  }
}

// ── Divider ──

function drawDivider(ctx, _colors) {
  ctx.strokeStyle = "rgba(128,0,255,0.3)";
  ctx.lineWidth = 1;
  ctx.setLineDash([4, 4]);
  ctx.beginPath();
  ctx.moveTo(DIVIDER_X, 0);
  ctx.lineTo(DIVIDER_X, CANVAS_H);
  ctx.stroke();
  ctx.setLineDash([]);
}

// ── Aliens ──

function drawAliens(ctx, state, colors, time) {
  const frame = Math.floor(time / 500) % 2; // 2-frame animation

  const drawGrid = (aliens, count, side) => {
    for (let i = 0; i < count; i++) {
      const a = aliens[i];
      if (!a || a.type === ALIEN_TYPE.NONE) continue;
      drawAlienSprite(ctx, a, colors, frame, time, side);
    }
  };

  drawGrid(state.aliens1, state.alien1Count, 1);
  if (state.mode !== GAME_MODE.COOP) {
    drawGrid(state.aliens2, state.alien2Count, 2);
  }
}

function drawAlienSprite(ctx, alien, colors, frame, time, _side) {
  const x = alien.x;
  const y = alien.y;
  const hw = ALIEN_W / 2;
  const hh = ALIEN_H / 2;

  ctx.save();

  // Reinforcement: red glow
  if (alien.type === ALIEN_TYPE.REINFORCEMENT) {
    const pulse = 0.4 + Math.sin(time * 0.008) * 0.3;
    ctx.shadowColor = colors.drop;
    ctx.shadowBlur = 6 * pulse;
  }

  // Armored: silver outline
  if (alien.type === ALIEN_TYPE.ARMORED) {
    ctx.fillStyle = "#c0c0c0";
    ctx.fillRect(x - hw - 2, y - hh - 2, ALIEN_W + 4, ALIEN_H + 4);
    ctx.fillStyle = "#808080";
    ctx.fillRect(x - hw - 1, y - hh - 1, ALIEN_W + 2, ALIEN_H + 2);
    // HP indicator
    if (alien.hp === 2) {
      ctx.fillStyle = "#ffffff";
      ctx.fillRect(x - 1, y - hh - 4, 2, 2);
    }
  }

  // Color by type
  let color;
  switch (alien.type) {
    case ALIEN_TYPE.TOP:
      color = "#ffffff";
      break;
    case ALIEN_TYPE.MID:
      color = "#aaffaa";
      break;
    case ALIEN_TYPE.BASE:
      color = "#66ff66";
      break;
    case ALIEN_TYPE.REINFORCEMENT:
      color = colors.drop;
      break;
    case ALIEN_TYPE.ARMORED:
      color = "#e0e0e0";
      break;
    default:
      color = "#39ff14";
  }

  ctx.fillStyle = color;

  // Draw different shapes by type
  if (alien.type === ALIEN_TYPE.TOP || alien.type === ALIEN_TYPE.REINFORCEMENT) {
    // Octopus: rounded top, tentacles
    ctx.fillRect(x - hw + 2, y - hh, ALIEN_W - 4, 2);
    ctx.fillRect(x - hw, y - hh + 2, ALIEN_W, 3);
    ctx.fillRect(x - hw + 1, y - hh + 5, 2, 3);
    ctx.fillRect(x + hw - 3, y - hh + 5, 2, 3);
    if (frame === 0) {
      ctx.fillRect(x - hw + 3, y - hh + 5, 2, 2);
    } else {
      ctx.fillRect(x - hw + 4, y - hh + 6, 2, 2);
    }
  } else if (alien.type === ALIEN_TYPE.MID) {
    // Crab: wide body, claws
    ctx.fillRect(x - hw, y - hh + 1, ALIEN_W, 4);
    ctx.fillRect(x - hw + 2, y - hh, 6, 1);
    if (frame === 0) {
      ctx.fillRect(x - hw - 2, y - hh + 5, 2, 3);
      ctx.fillRect(x + hw, y - hh + 5, 2, 3);
    } else {
      ctx.fillRect(x - hw, y - hh + 5, 2, 3);
      ctx.fillRect(x + hw - 2, y - hh + 5, 2, 3);
    }
  } else if (alien.type === ALIEN_TYPE.ARMORED) {
    // Metallic block
    ctx.fillRect(x - hw, y - hh, ALIEN_W, ALIEN_H);
    // Eyes
    ctx.fillStyle = "#ff0000";
    ctx.fillRect(x - 3, y - 1, 2, 2);
    ctx.fillRect(x + 1, y - 1, 2, 2);
  } else {
    // Base: squid shape
    ctx.fillRect(x - hw + 1, y - hh, ALIEN_W - 2, 5);
    ctx.fillRect(x - hw, y - hh + 2, ALIEN_W, 2);
    if (frame === 0) {
      ctx.fillRect(x - hw, y - hh + 5, 3, 2);
      ctx.fillRect(x + hw - 3, y - hh + 5, 3, 2);
    } else {
      ctx.fillRect(x - hw + 1, y - hh + 5, 3, 2);
      ctx.fillRect(x + hw - 4, y - hh + 5, 3, 2);
    }
  }

  // Eyes (for non-armored)
  if (alien.type !== ALIEN_TYPE.ARMORED) {
    ctx.fillStyle = colors.bg;
    ctx.fillRect(x - 2, y - hh + 2, 1, 1);
    ctx.fillRect(x + 1, y - hh + 2, 1, 1);
  }

  ctx.restore();
}

// ── Drop Previews ──

function drawDropPreviews(ctx, state, colors, time) {
  if (!state.drops || state.drops.length === 0) return;

  ctx.save();
  ctx.globalAlpha = 0.3 + Math.sin(time * 0.01) * 0.15;
  for (const d of state.drops) {
    const progress = 1 - d.timer / 120;
    const previewY = progress * (CANVAS_H * 0.6);
    const previewX = d.targetSide === 1 ? 100 : DIVIDER_X + 100;
    ctx.fillStyle = colors.drop;
    ctx.fillRect(previewX - 4, previewY, 8, 8);
  }
  ctx.restore();
}

// ── Shields ──

function drawShields(ctx, state, colors) {
  const positions = state._shieldPositions;
  if (!positions) return;

  for (let i = 0; i < positions.length; i++) {
    const sp = positions[i];
    const hp = state.shields[i] || 0;
    if (hp <= 0) continue;

    // Determine color by side
    const isP2Side = state.mode !== GAME_MODE.COOP && i >= 2;
    const color = isP2Side ? colors.p2 : colors.p1;

    ctx.fillStyle = color;
    // Draw segments (each segment = 1/4 of shield width)
    const segW = SHIELD_W / SHIELD_SEGMENTS;
    for (let j = 0; j < hp; j++) {
      ctx.fillRect(sp.x - SHIELD_W / 2 + j * segW + 1, sp.y - SHIELD_H / 2, segW - 2, SHIELD_H);
    }

    // Arch cutout at bottom center
    ctx.fillStyle = colors.bg;
    ctx.fillRect(sp.x - 4, sp.y + SHIELD_H / 2 - 4, 8, 4);
  }
}

// ── Bombs ──

function drawBombs(ctx, state, colors, time) {
  for (let i = 0; i < state.bombCount; i++) {
    const b = state.bombs[i];
    if (!b) continue;

    // Zigzag lightning bolt
    ctx.strokeStyle = colors.warning;
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(b.x, b.y - 4);
    ctx.lineTo(b.x + 2, b.y - 1);
    ctx.lineTo(b.x - 2, b.y + 1);
    ctx.lineTo(b.x, b.y + 4);
    ctx.stroke();

    // Glow
    const pulse = 0.5 + Math.sin(time * 0.02 + i) * 0.3;
    ctx.fillStyle = `rgba(255,68,0,${pulse})`;
    ctx.fillRect(b.x - 1, b.y - 1, 2, 2);
  }
}

// ── Missiles ──

function drawMissiles(ctx, state, _colors) {
  const drawMissile = (x, y, active) => {
    if (!active) return;
    // Bright dot + trail
    ctx.fillStyle = "#ffffff";
    ctx.fillRect(x - 1, y - 3, 2, 6);
    ctx.fillStyle = "rgba(255,255,255,0.4)";
    ctx.fillRect(x - 1, y + 3, 2, 8);
  };

  drawMissile(state.m1X, state.m1Y, state.m1Active);
  drawMissile(state.m2X, state.m2Y, state.m2Active);
}

// ── Cannons ──

function drawCannons(ctx, state, colors) {
  drawCannon(ctx, state.cannon1X, colors.p1, state.lives1 > 0);
  drawCannon(ctx, state.cannon2X, colors.p2, state.lives2 > 0);
}

function drawCannon(ctx, x, color, alive) {
  if (!alive) return;

  ctx.fillStyle = color;
  // Turret
  ctx.fillRect(x - 1, CANNON_Y - 8, 2, 6);
  // Body
  ctx.fillRect(x - CANNON_W / 2, CANNON_Y - 2, CANNON_W, 6);
  // Base
  ctx.fillRect(x - CANNON_W / 2 + 2, CANNON_Y + 4, CANNON_W - 4, 3);

  // Cockpit detail
  ctx.fillStyle = "rgba(255,255,255,0.4)";
  ctx.fillRect(x - 2, CANNON_Y - 1, 4, 2);
}

// ── UFO ──

function drawUFO(ctx, state, colors, time) {
  if (!state.ufoActive) return;

  const x = state.ufoX;
  const y = UFO_Y;

  // Rainbow trail
  for (let i = 0; i < 6; i++) {
    const trailX = x - state.ufoDir * (i + 1) * 5;
    ctx.fillStyle = UFO_TRAIL_COLORS[i];
    ctx.globalAlpha = 0.3 - i * 0.04;
    ctx.fillRect(trailX - 2, y - 2, 4, 4);
  }
  ctx.globalAlpha = 1;

  // Body
  const pulse = 0.7 + Math.sin(time * 0.015) * 0.3;
  ctx.fillStyle = colors.ufo;
  ctx.globalAlpha = pulse;
  ctx.fillRect(x - UFO_W / 2 + 4, y - 5, UFO_W - 8, 4);
  ctx.fillRect(x - UFO_W / 2, y - 1, UFO_W, 4);
  ctx.fillRect(x - UFO_W / 2 + 2, y + 3, UFO_W - 4, 2);
  ctx.globalAlpha = 1;

  // Lights
  const lightPhase = Math.floor(time / 100) % 3;
  const lightPositions = [x - 6, x, x + 6];
  const lightColors = ["#ff0000", "#00ff00", "#0000ff"];
  for (let i = 0; i < 3; i++) {
    ctx.fillStyle = lightColors[(i + lightPhase) % 3];
    ctx.fillRect(lightPositions[i] - 1, y, 2, 2);
  }
}

// ── HUD ──

function drawHUD(ctx, state, colors, time) {
  const isCoop = state.mode === GAME_MODE.COOP;

  // Top bar background
  ctx.fillStyle = "rgba(0,0,0,0.6)";
  ctx.fillRect(0, 0, CANVAS_W, 22);

  ctx.font = "bold 11px monospace";
  ctx.textBaseline = "middle";

  // P1 score
  ctx.fillStyle = colors.p1;
  ctx.textAlign = "left";
  ctx.fillText(jt`P1: ${state.score1}`, 8, 11);

  // Center: wave + mode
  ctx.fillStyle = "#ffffff";
  ctx.textAlign = "center";
  const modeLabel =
    state.mode === GAME_MODE.BLITZ ? "BLITZ" : state.mode === GAME_MODE.COOP ? "CO-OP" : "WAR";
  ctx.fillText(jt`${modeLabel}  Wv:${state.wave}`, CANVAS_W / 2, 11);

  // P2 score
  ctx.fillStyle = colors.p2;
  ctx.textAlign = "right";
  ctx.fillText(jt`P2: ${state.score2}`, CANVAS_W - 8, 11);

  // Bottom bar
  ctx.fillStyle = "rgba(0,0,0,0.6)";
  ctx.fillRect(0, CANVAS_H - 22, CANVAS_W, 22);

  // P1 lives + combo
  ctx.textAlign = "left";
  ctx.font = "10px monospace";
  const lives1Str = drawLivesString(state.lives1);
  ctx.fillStyle = colors.p1;
  ctx.fillText(lives1Str, 8, CANVAS_H - 11);

  if (!isCoop && state.combo1Count >= 2) {
    const blink = Math.floor(time / 200) % 2 === 0;
    if (blink) {
      ctx.fillStyle = "#ffff00";
      ctx.fillText(`x${state.combo1Count}`, 60, CANVAS_H - 11);
    }
  }

  // P2 lives + combo
  ctx.textAlign = "right";
  const lives2Str = drawLivesString(state.lives2);
  ctx.fillStyle = colors.p2;
  ctx.fillText(lives2Str, CANVAS_W - 8, CANVAS_H - 11);

  if (!isCoop && state.combo2Count >= 2) {
    const blink = Math.floor(time / 200) % 2 === 0;
    if (blink) {
      ctx.fillStyle = "#ffff00";
      ctx.textAlign = "right";
      ctx.fillText(`x${state.combo2Count}`, CANVAS_W - 60, CANVAS_H - 11);
    }
  }
}

function drawLivesString(lives) {
  let s = "";
  for (let i = 0; i < INITIAL_LIVES; i++) {
    s += i < lives ? "\u2665 " : "\u2661 ";
  }
  return s.trim();
}

// ── Overlay Text ──

function drawOverlayText(ctx, colors, text, color, size) {
  const fontSize = size || 24;
  ctx.save();
  ctx.fillStyle = "rgba(0,0,0,0.5)";
  ctx.fillRect(0, CANVAS_H / 2 - fontSize, CANVAS_W, fontSize * 2);
  ctx.font = `bold ${fontSize}px monospace`;
  ctx.fillStyle = color;
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText(text, CANVAS_W / 2, CANVAS_H / 2);
  ctx.restore();
}

// ── Game Over ──

function drawGameOver(ctx, state, colors) {
  ctx.save();
  ctx.fillStyle = "rgba(0,0,0,0.7)";
  ctx.fillRect(0, 0, CANVAS_W, CANVAS_H);

  ctx.font = "bold 32px monospace";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";

  if (state.mode === GAME_MODE.COOP) {
    const survived = state.lives1 > 0 || state.lives2 > 0;
    ctx.fillStyle = survived ? colors.p1 : colors.warning;
    ctx.fillText(
      survived ? t("MISSION COMPLETE") : t("EARTH INVADED"),
      CANVAS_W / 2,
      CANVAS_H / 2 - 40,
    );
  } else {
    // Determine winner display
    const winner = state.score1 > state.score2 ? 1 : state.score2 > state.score1 ? 2 : 1;
    ctx.fillStyle = winner === 1 ? colors.p1 : colors.p2;
    ctx.fillText(jt`PLAYER ${winner} WINS`, CANVAS_W / 2, CANVAS_H / 2 - 40);
  }

  // Final scores
  ctx.font = "18px monospace";
  ctx.fillStyle = colors.p1;
  ctx.fillText(jt`P1: ${state.score1}`, CANVAS_W / 2 - 80, CANVAS_H / 2 + 10);
  ctx.fillStyle = colors.p2;
  ctx.fillText(jt`P2: ${state.score2}`, CANVAS_W / 2 + 80, CANVAS_H / 2 + 10);

  ctx.font = "12px monospace";
  ctx.fillStyle = "#888888";
  ctx.fillText(t("Game Over"), CANVAS_W / 2, CANVAS_H / 2 + 40);

  ctx.restore();
}

// ── CRT Effects ──

function drawScanlines(ctx) {
  ctx.fillStyle = "rgba(0,0,0,0.06)";
  for (let y = 0; y < CANVAS_H; y += 3) {
    ctx.fillRect(0, y, CANVAS_W, 1);
  }
}

function drawVignette(ctx) {
  const grd = ctx.createRadialGradient(
    CANVAS_W / 2,
    CANVAS_H / 2,
    CANVAS_W * 0.35,
    CANVAS_W / 2,
    CANVAS_H / 2,
    CANVAS_W * 0.7,
  );
  grd.addColorStop(0, "rgba(0,0,0,0)");
  grd.addColorStop(1, "rgba(0,0,0,0.4)");
  ctx.fillStyle = grd;
  ctx.fillRect(0, 0, CANVAS_W, CANVAS_H);
}
