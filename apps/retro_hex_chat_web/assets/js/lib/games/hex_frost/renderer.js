/**
 * Hex Frost — Canvas renderer.
 *
 * Cyberpunk post-apocalyptic arctic aesthetic: frozen wastelands,
 * neon-lit ice blocks, aurora borealis, CRT scanlines.
 */

import {
  CANVAS_W,
  CANVAS_H,
  SHORE_Y,
  SHORE_H,
  SHORE_BOTTOM,
  ROW_Y,
  ROW_SPACING,
  WATER_Y,
  BLOCK_W,
  BLOCK_H,
  BAILEY_W,
  BAILEY_H,
  IGLOO_W,
  IGLOO_H,
  BEAR_W,
  BEAR_H,
  CRAB_W,
  CRAB_H,
  GOOSE_W,
  GOOSE_H,
  CLAM_W,
  CLAM_H,
  FISH_W,
  getBaileyY,
  getBlockAbsX,
} from "./physics.js";
import { PHASE, GAME_MODE, BAILEY_STATE, ENEMY_TYPE, BLOCK_STATE } from "./protocol.js";
import { t, jt } from "../../i18n.js";
import { gameColor } from "../../game_colors.js";

// ── Color reading ──────────────────────────────────────────────

/**
 * Read CSS custom properties from the canvas element.
 */
export function readColors(canvas) {
  const s = getComputedStyle(canvas);
  const get = (name) => s.getPropertyValue(name).trim() || null;
  return {
    bg: get("--game-bg-color") || gameColor("060818"),
    fg: get("--game-fg-color") || gameColor("39ff14"),
    accent: get("--game-accent-color") || gameColor("00e5ff"),
    muted: get("--game-muted-color") || gameColor("0e1a2e"),
    glow: get("--game-glow-color") || "rgba(57,255,20,0.15)",
    warning: get("--game-warning-color") || gameColor("ff4444"),
    shore: get("--game-shore-color") || gameColor("2a3040"),
    water: get("--game-water-color") || gameColor("0a1020"),
    blockWhite: get("--game-block-white") || gameColor("c0d8e8"),
    blockP1: get("--game-block-p1") || gameColor("40ff80"),
    blockP2: get("--game-block-p2") || gameColor("40d0ff"),
    iglooP1: get("--game-igloo-p1") || gameColor("30cc60"),
    iglooP2: get("--game-igloo-p2") || gameColor("30a0cc"),
    bear: get("--game-bear-color") || gameColor("e0e0e0"),
    crab: get("--game-crab-color") || gameColor("ff4040"),
    fish: get("--game-fish-color") || gameColor("ff8800"),
  };
}

/**
 * Generate snow particles for visual effects.
 */
export function generateSnowParticles(count) {
  const particles = [];
  for (let i = 0; i < count; i++) {
    particles.push({
      x: Math.random() * CANVAS_W,
      y: Math.random() * CANVAS_H,
      size: 1 + Math.random() * 2,
      speed: 0.2 + Math.random() * 0.5,
      drift: (Math.random() - 0.5) * 0.3,
    });
  }
  return particles;
}

// ── Main render ────────────────────────────────────────────────

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
      drawGameScene(ctx, state, colors, frameCount, snowParticles);
      drawCountdown(ctx, state, colors, frameCount);
      drawCRT(ctx);
      return;
    case PHASE.BUILDING:
      drawGameScene(ctx, state, colors, frameCount, snowParticles);
      drawCRT(ctx);
      return;
    case PHASE.ROUND_END:
      drawGameScene(ctx, state, colors, frameCount, snowParticles);
      drawRoundEnd(ctx, state, colors, frameCount);
      drawCRT(ctx);
      return;
    case PHASE.FINISHED:
      drawGameScene(ctx, state, colors, frameCount, snowParticles);
      drawFinished(ctx, state, colors, frameCount);
      drawCRT(ctx);
      return;
  }
}

function drawGameScene(ctx, state, colors, frameCount, snowParticles) {
  drawBackground(ctx, colors, frameCount);
  drawAuroraBorealis(ctx, colors, frameCount);
  drawSnowParticles(ctx, snowParticles, colors, frameCount);
  drawWater(ctx, colors, frameCount);
  drawShore(ctx, colors);
  drawBlockRows(ctx, state, colors, frameCount);
  drawEnemies(ctx, state, colors, frameCount);
  drawFish(ctx, state, colors, frameCount);
  drawBaileys(ctx, state, colors, frameCount);
  drawIgloos(ctx, state, colors, frameCount);
  drawHUD(ctx, state, colors);
  drawTemperature(ctx, state, colors);
}

// ── Background ─────────────────────────────────────────────────

function drawWaitingScreen(ctx, colors, frameCount) {
  ctx.fillStyle = colors.bg;
  ctx.fillRect(0, 0, CANVAS_W, CANVAS_H);

  const pulse = Math.sin(frameCount * 0.05) * 0.3 + 0.7;
  ctx.fillStyle = colors.accent;
  ctx.globalAlpha = pulse;
  ctx.font = "bold 16px monospace";
  ctx.textAlign = "center";
  ctx.fillText(t("WAITING FOR OPPONENT..."), CANVAS_W / 2, CANVAS_H / 2);
  ctx.globalAlpha = 1;
}

function drawBackground(ctx, colors, frameCount) {
  // Dark arctic sky gradient
  const gradient = ctx.createLinearGradient(0, 0, 0, CANVAS_H);
  gradient.addColorStop(0, gameColor("020410"));
  gradient.addColorStop(0.3, colors.bg);
  gradient.addColorStop(1, colors.muted);
  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, CANVAS_W, CANVAS_H);

  // Distant stars
  ctx.fillStyle = gameColor("ffffff");
  for (let i = 0; i < 30; i++) {
    const sx = (i * 73 + 17) % CANVAS_W;
    const sy = (i * 43 + 7) % 40;
    const twinkle = Math.sin(frameCount * 0.03 + i) > 0.7 ? 1 : 0.3;
    ctx.globalAlpha = twinkle;
    ctx.fillRect(sx, sy, 1, 1);
  }
  ctx.globalAlpha = 1;
}

function drawAuroraBorealis(ctx, colors, frameCount) {
  // Subtle aurora waves in the sky
  ctx.globalAlpha = 0.08;
  for (let wave = 0; wave < 3; wave++) {
    const hue = wave === 0 ? colors.fg : wave === 1 ? colors.accent : gameColor("8040ff");
    ctx.strokeStyle = hue;
    ctx.lineWidth = 3;
    ctx.beginPath();
    for (let x = 0; x < CANVAS_W; x += 4) {
      const y =
        15 +
        wave * 8 +
        Math.sin(x * 0.01 + frameCount * 0.02 + wave * 2) * 8 +
        Math.sin(x * 0.005 + frameCount * 0.01) * 4;
      if (x === 0) ctx.moveTo(x, y);
      else ctx.lineTo(x, y);
    }
    ctx.stroke();
  }
  ctx.globalAlpha = 1;
}

function drawSnowParticles(ctx, particles, colors, frameCount) {
  if (!particles) return;
  ctx.fillStyle = colors.blockWhite;
  ctx.globalAlpha = 0.5;
  for (const p of particles) {
    const y = (p.y + frameCount * p.speed) % CANVAS_H;
    const x = p.x + Math.sin(frameCount * 0.02 + p.drift * 10) * 3;
    ctx.fillRect(x, y, p.size, p.size);
  }
  ctx.globalAlpha = 1;
}

// ── Water ──────────────────────────────────────────────────────

function drawWater(ctx, colors, frameCount) {
  ctx.fillStyle = colors.water;
  ctx.fillRect(0, WATER_Y, CANVAS_W, CANVAS_H - WATER_Y);

  // Animated wave ripples
  ctx.strokeStyle = colors.accent;
  ctx.globalAlpha = 0.15;
  ctx.lineWidth = 1;
  for (let wave = 0; wave < 3; wave++) {
    ctx.beginPath();
    const wy = WATER_Y + 8 + wave * 12;
    for (let x = 0; x < CANVAS_W; x += 4) {
      const y = wy + Math.sin(x * 0.03 + frameCount * 0.04 + wave) * 3;
      if (x === 0) ctx.moveTo(x, y);
      else ctx.lineTo(x, y);
    }
    ctx.stroke();
  }
  ctx.globalAlpha = 1;
}

// ── Shore ──────────────────────────────────────────────────────

function drawShore(ctx, colors) {
  // Main platform
  ctx.fillStyle = colors.shore;
  ctx.fillRect(0, SHORE_Y, CANVAS_W, SHORE_H);

  // Snow texture on top edge
  ctx.fillStyle = colors.blockWhite;
  ctx.globalAlpha = 0.3;
  for (let x = 0; x < CANVAS_W; x += 6) {
    const h = 2 + ((x * 7) % 3);
    ctx.fillRect(x, SHORE_Y, 4, h);
  }
  ctx.globalAlpha = 1;

  // Bottom edge highlight
  ctx.fillStyle = colors.muted;
  ctx.fillRect(0, SHORE_BOTTOM - 2, CANVAS_W, 2);
}

// ── Ice block rows ─────────────────────────────────────────────

function drawBlockRows(ctx, state, colors, frameCount) {
  if (!state.blockRows) return;

  for (let r = 0; r < state.blockRows.length; r++) {
    const row = state.blockRows[r];
    // Row water line
    ctx.fillStyle = colors.water;
    ctx.globalAlpha = 0.3;
    ctx.fillRect(0, ROW_Y[r] - 4, CANVAS_W, ROW_SPACING);
    ctx.globalAlpha = 1;

    for (const block of row.blocks) {
      const x =
        row.offset === 0
          ? block.x // Peer: absolute positions
          : getBlockAbsX(block, row);

      // Skip offscreen blocks
      if (x < -BLOCK_W || x > CANVAS_W + BLOCK_W) continue;

      let color;
      let glowColor;
      switch (block.state) {
        case BLOCK_STATE.BLUE_P1:
          color = colors.blockP1;
          glowColor = colors.fg;
          break;
        case BLOCK_STATE.BLUE_P2:
          color = colors.blockP2;
          glowColor = colors.accent;
          break;
        default:
          color = colors.blockWhite;
          glowColor = null;
      }

      // Glow effect for owned blocks
      if (glowColor) {
        ctx.fillStyle = glowColor;
        ctx.globalAlpha = 0.15 + Math.sin(frameCount * 0.1) * 0.05;
        ctx.fillRect(x - 2, ROW_Y[r] - BLOCK_H / 2 - 2, BLOCK_W + 4, BLOCK_H + 4);
        ctx.globalAlpha = 1;
      }

      // Block body
      ctx.fillStyle = color;
      ctx.fillRect(x, ROW_Y[r] - BLOCK_H / 2, BLOCK_W, BLOCK_H);

      // Ice crystal texture
      ctx.fillStyle = gameColor("ffffff");
      ctx.globalAlpha = 0.2;
      ctx.fillRect(x + 4, ROW_Y[r] - BLOCK_H / 2 + 2, 2, 2);
      ctx.fillRect(x + BLOCK_W - 8, ROW_Y[r] - BLOCK_H / 2 + 4, 2, 2);
      ctx.fillRect(x + BLOCK_W / 2, ROW_Y[r] - BLOCK_H / 2 + 1, 1, 1);
      ctx.globalAlpha = 1;

      // Top highlight
      ctx.fillStyle = gameColor("ffffff");
      ctx.globalAlpha = 0.3;
      ctx.fillRect(x, ROW_Y[r] - BLOCK_H / 2, BLOCK_W, 1);
      ctx.globalAlpha = 1;

      // Bottom shadow
      ctx.fillStyle = gameColor("000000");
      ctx.globalAlpha = 0.2;
      ctx.fillRect(x, ROW_Y[r] + BLOCK_H / 2 - 1, BLOCK_W, 1);
      ctx.globalAlpha = 1;
    }
  }
}

// ── Igloos ─────────────────────────────────────────────────────

function drawIgloos(ctx, state, colors, frameCount) {
  drawIgloo(
    ctx,
    state.p1,
    40,
    colors.iglooP1,
    colors.fg,
    state.p1IglooFlash,
    state.piecesNeeded || 15,
    frameCount,
  );
  drawIgloo(
    ctx,
    state.p2,
    CANVAS_W - IGLOO_W - 40,
    colors.iglooP2,
    colors.accent,
    state.p2IglooFlash,
    state.piecesNeeded || 15,
    frameCount,
  );
}

function drawIgloo(ctx, player, x, color, glowColor, flash, piecesNeeded, frameCount) {
  const pieces = player.iglooPieces;
  const progress = Math.min(pieces / piecesNeeded, 1);
  const iglooY = SHORE_Y + 2;

  // Foundation outline
  ctx.strokeStyle = color;
  ctx.globalAlpha = 0.3;
  ctx.strokeRect(x, iglooY, IGLOO_W, IGLOO_H);
  ctx.globalAlpha = 1;

  // Build blocks row by row from bottom
  const blockSize = 6;
  const blocksPerRow = Math.floor(IGLOO_W / blockSize);
  const totalBlocks = Math.floor(progress * (blocksPerRow * 5));
  let drawn = 0;

  for (let row = 4; row >= 0 && drawn < totalBlocks; row--) {
    const rowWidth = row < 2 ? blocksPerRow - (2 - row) * 2 : blocksPerRow;
    const offsetX = row < 2 ? (2 - row) * blockSize : 0;
    for (let col = 0; col < rowWidth && drawn < totalBlocks; col++) {
      ctx.fillStyle = color;
      ctx.fillRect(
        x + offsetX + col * blockSize,
        iglooY + IGLOO_H - (5 - row) * (blockSize + 1),
        blockSize - 1,
        blockSize,
      );
      drawn++;
    }
  }

  // Door when complete
  if (player.iglooComplete) {
    ctx.fillStyle = gameColor("000000");
    ctx.fillRect(x + IGLOO_W / 2 - 4, iglooY + IGLOO_H - 12, 8, 12);

    // Glow around igloo
    ctx.strokeStyle = glowColor;
    ctx.globalAlpha = 0.4 + Math.sin(frameCount * 0.1) * 0.2;
    ctx.lineWidth = 2;
    ctx.strokeRect(x - 2, iglooY - 2, IGLOO_W + 4, IGLOO_H + 4);
    ctx.lineWidth = 1;
    ctx.globalAlpha = 1;
  }

  // Flash animation (gain)
  if (flash > 0) {
    ctx.fillStyle = gameColor("ffdd00");
    ctx.globalAlpha = (flash / 15) * 0.4;
    ctx.fillRect(x - 3, iglooY - 3, IGLOO_W + 6, IGLOO_H + 6);
    ctx.globalAlpha = 1;
  }

  // Piece counter below igloo
  ctx.fillStyle = color;
  ctx.font = "bold 8px monospace";
  ctx.textAlign = "center";
  ctx.fillText(`${pieces}/${piecesNeeded}`, x + IGLOO_W / 2, iglooY + IGLOO_H + 10);
}

// ── Baileys (player characters) ────────────────────────────────

function drawBaileys(ctx, state, colors, frameCount) {
  drawBailey(ctx, state.p1, colors.fg, frameCount);
  drawBailey(ctx, state.p2, colors.accent, frameCount);
}

function drawBailey(ctx, player, color, frameCount) {
  if (player.state === BAILEY_STATE.DEAD && !player.lives) return;

  const x = player.x - BAILEY_W / 2;
  const y = getBaileyY(player) - BAILEY_H;

  if (player.state === BAILEY_STATE.DEAD || player.state === BAILEY_STATE.FALLING) {
    // Blink while dead
    if (Math.floor(frameCount / 8) % 2 === 0) return;
  }

  if (player.state === BAILEY_STATE.ENTERING_IGLOO) {
    // Shrinking into igloo
    ctx.globalAlpha = 0.5;
  }

  // Body (coat)
  ctx.fillStyle = color;
  ctx.fillRect(x + 2, y + 5, BAILEY_W - 4, 7);

  // Head
  ctx.fillStyle = gameColor("ffe0b0");
  ctx.fillRect(x + 3, y + 1, BAILEY_W - 6, 4);

  // Hat/gorro
  ctx.fillStyle = color;
  ctx.fillRect(x + 2, y, BAILEY_W - 4, 2);

  // Eyes
  ctx.fillStyle = gameColor("000000");
  if (player.facing === 1) {
    ctx.fillRect(x + 6, y + 2, 1, 1);
  } else {
    ctx.fillRect(x + 5, y + 2, 1, 1);
  }

  // Legs (walking animation)
  ctx.fillStyle = color;
  if (player.state === BAILEY_STATE.WALKING) {
    const legPhase = Math.floor(frameCount / 6) % 2;
    if (legPhase === 0) {
      ctx.fillRect(x + 3, y + 12, 2, 4);
      ctx.fillRect(x + 7, y + 12, 2, 3);
    } else {
      ctx.fillRect(x + 3, y + 12, 2, 3);
      ctx.fillRect(x + 7, y + 12, 2, 4);
    }
  } else if (player.state === BAILEY_STATE.JUMPING) {
    // Legs spread during jump
    ctx.fillRect(x + 2, y + 12, 2, 3);
    ctx.fillRect(x + 8, y + 12, 2, 3);
  } else {
    // Idle legs
    ctx.fillRect(x + 4, y + 12, 2, 4);
    ctx.fillRect(x + 6, y + 12, 2, 4);
  }

  // Splash effect
  if (player.state === BAILEY_STATE.FALLING) {
    ctx.fillStyle = gameColor("40b0ff");
    ctx.globalAlpha = 0.6;
    for (let i = 0; i < 4; i++) {
      const sx = x + BAILEY_W / 2 + (i - 2) * 5;
      const sy = y + BAILEY_H + 2 - Math.abs(i - 1.5) * 3;
      ctx.fillRect(sx, sy, 2, 2);
    }
  }

  ctx.globalAlpha = 1;

  // Player label
  ctx.fillStyle = color;
  ctx.font = "bold 7px monospace";
  ctx.textAlign = "center";
  ctx.fillText(`P${player.playerNum}`, player.x, y - 2);
}

// ── Enemies ────────────────────────────────────────────────────

function drawEnemies(ctx, state, colors, frameCount) {
  for (const enemy of state.enemies) {
    switch (enemy.type) {
      case ENEMY_TYPE.BEAR:
        drawBear(ctx, enemy, colors, frameCount);
        break;
      case ENEMY_TYPE.CRAB:
        drawCrab(ctx, enemy, colors, frameCount);
        break;
      case ENEMY_TYPE.GOOSE:
        drawGoose(ctx, enemy, colors, frameCount);
        break;
      case ENEMY_TYPE.CLAM:
        drawClam(ctx, enemy, colors, frameCount);
        break;
    }
  }
}

function drawBear(ctx, enemy, colors, frameCount) {
  const x = enemy.x;
  const y = SHORE_Y + SHORE_H / 2 - BEAR_H / 2;

  // Body
  ctx.fillStyle = colors.bear;
  ctx.fillRect(x + 2, y + 4, BEAR_W - 4, BEAR_H - 6);

  // Head
  ctx.fillRect(x + 4, y, BEAR_W - 8, 6);

  // Ears
  ctx.fillRect(x + 3, y - 1, 3, 3);
  ctx.fillRect(x + BEAR_W - 6, y - 1, 3, 3);

  // Eyes
  ctx.fillStyle = gameColor("000000");
  ctx.fillRect(x + 7, y + 2, 2, 2);
  ctx.fillRect(x + 12, y + 2, 2, 2);

  // Nose
  ctx.fillRect(x + 9, y + 4, 2, 1);

  // Legs (walking)
  ctx.fillStyle = colors.bear;
  const legPhase = Math.floor(frameCount / 10) % 2;
  ctx.fillRect(x + 4, y + BEAR_H - 4, 3, 4);
  ctx.fillRect(x + BEAR_W - 7, y + BEAR_H - 4, 3, 4);
  if (legPhase) {
    ctx.fillRect(x + 4, y + BEAR_H - 2, 3, 2);
  } else {
    ctx.fillRect(x + BEAR_W - 7, y + BEAR_H - 2, 3, 2);
  }
}

function drawCrab(ctx, enemy, colors, frameCount) {
  const x = enemy.x;
  const y = ROW_Y[enemy.row] - CRAB_H / 2;

  // Body
  ctx.fillStyle = colors.crab;
  ctx.fillRect(x + 2, y + 2, CRAB_W - 4, CRAB_H - 4);

  // Claws (animated)
  const clawPhase = Math.floor(frameCount / 8) % 2;
  const clawOffset = clawPhase ? 1 : 0;
  ctx.fillRect(x, y + 2 - clawOffset, 3, 3);
  ctx.fillRect(x + CRAB_W - 3, y + 2 - clawOffset, 3, 3);

  // Eyes
  ctx.fillStyle = gameColor("ffffff");
  ctx.fillRect(x + 4, y + 1, 2, 2);
  ctx.fillRect(x + 8, y + 1, 2, 2);
  ctx.fillStyle = gameColor("000000");
  ctx.fillRect(x + 5, y + 1, 1, 1);
  ctx.fillRect(x + 9, y + 1, 1, 1);

  // Legs
  ctx.fillStyle = colors.crab;
  for (let i = 0; i < 3; i++) {
    ctx.fillRect(x + 1 + i * 4, y + CRAB_H - 3, 1, 3);
  }
}

function drawGoose(ctx, enemy, colors, frameCount) {
  const x = enemy.x;
  const y = ROW_Y[enemy.row] + ROW_SPACING / 2 - GOOSE_H / 2;

  // Body
  ctx.fillStyle = gameColor("e0e0e0");
  ctx.fillRect(x + 4, y + 3, GOOSE_W - 8, GOOSE_H - 4);

  // Wings (animated)
  const wingPhase = Math.floor(frameCount / 6) % 3;
  const wingY = wingPhase === 0 ? -2 : wingPhase === 1 ? 0 : 1;
  ctx.fillRect(x, y + 4 + wingY, 5, 3);
  ctx.fillRect(x + GOOSE_W - 5, y + 4 + wingY, 5, 3);

  // Head/neck
  const dir = enemy.state;
  if (dir > 0) {
    ctx.fillRect(x + GOOSE_W - 4, y, 4, 4);
    // Beak
    ctx.fillStyle = gameColor("ffaa00");
    ctx.fillRect(x + GOOSE_W, y + 1, 2, 2);
    // Eye
    ctx.fillStyle = gameColor("000000");
    ctx.fillRect(x + GOOSE_W - 2, y + 1, 1, 1);
  } else {
    ctx.fillStyle = gameColor("e0e0e0");
    ctx.fillRect(x, y, 4, 4);
    ctx.fillStyle = gameColor("ffaa00");
    ctx.fillRect(x - 2, y + 1, 2, 2);
    ctx.fillStyle = gameColor("000000");
    ctx.fillRect(x + 1, y + 1, 1, 1);
  }
}

function drawClam(ctx, enemy, colors, frameCount) {
  const x = enemy.x;
  const y = ROW_Y[enemy.row] - CLAM_H / 2;
  const isOpen = enemy.state === 1;

  if (isOpen) {
    // Open clam — dangerous
    ctx.fillStyle = gameColor("9040c0");
    ctx.fillRect(x, y, CLAM_W, CLAM_H);
    // Shell halves
    ctx.fillStyle = gameColor("7030a0");
    ctx.fillRect(x, y, CLAM_W, 3);
    ctx.fillRect(x, y + CLAM_H - 3, CLAM_W, 3);
    // Inner pearl/danger
    ctx.fillStyle = gameColor("ff60ff");
    ctx.fillRect(x + 4, y + 4, 4, 3);
    // Warning glow
    ctx.fillStyle = gameColor("ff60ff");
    ctx.globalAlpha = 0.2 + Math.sin(frameCount * 0.15) * 0.1;
    ctx.fillRect(x - 1, y - 1, CLAM_W + 2, CLAM_H + 2);
    ctx.globalAlpha = 1;
  } else {
    // Closed clam — safe
    ctx.fillStyle = gameColor("7030a0");
    ctx.fillRect(x + 2, y + 2, CLAM_W - 4, CLAM_H - 4);
    // Shell line
    ctx.fillStyle = gameColor("502080");
    ctx.fillRect(x + 2, y + CLAM_H / 2, CLAM_W - 4, 1);
  }
}

// ── Fish ───────────────────────────────────────────────────────

function drawFish(ctx, state, colors, frameCount) {
  for (const fish of state.fish) {
    if (fish.collected > 0) continue;
    const x = fish.x;
    const y = ROW_Y[fish.row] + ROW_SPACING / 2;

    // Body
    ctx.fillStyle = colors.fish;
    ctx.fillRect(x + 2, y - 3, FISH_W - 4, 6);

    // Tail
    ctx.fillRect(x, y - 2, 3, 4);

    // Eye
    ctx.fillStyle = gameColor("000000");
    ctx.fillRect(x + FISH_W - 4, y - 1, 1, 1);

    // Sparkle
    ctx.fillStyle = gameColor("ffffff");
    ctx.globalAlpha = 0.5 + Math.sin(frameCount * 0.2 + fish.x) * 0.3;
    ctx.fillRect(x + FISH_W - 2, y - 3, 1, 1);
    ctx.globalAlpha = 1;
  }
}

// ── Temperature thermometer ────────────────────────────────────

function drawTemperature(ctx, state, colors) {
  const temp = state.temperature || 0;
  const maxTemp = state.mode === GAME_MODE.BLIZZARD ? 60 : 45;
  const ratio = Math.max(0, Math.min(1, temp / maxTemp));

  const tx = CANVAS_W - 22;
  const ty = SHORE_Y + SHORE_H + 10;
  const th = WATER_Y - ty - 20;

  // Thermometer outline
  ctx.fillStyle = colors.muted;
  ctx.fillRect(tx - 1, ty - 1, 12, th + 2);

  // Fill (color gradient: green → yellow → red)
  const fillH = Math.round(th * ratio);
  let fillColor;
  if (ratio > 0.5) fillColor = colors.fg;
  else if (ratio > 0.2) fillColor = gameColor("ffaa00");
  else fillColor = colors.warning;

  ctx.fillStyle = gameColor("000000");
  ctx.fillRect(tx, ty, 10, th);
  ctx.fillStyle = fillColor;
  ctx.fillRect(tx, ty + th - fillH, 10, fillH);

  // Bulb at bottom
  ctx.fillStyle = fillColor;
  ctx.fillRect(tx - 1, ty + th, 12, 6);

  // Temperature text
  ctx.fillStyle = fillColor;
  ctx.font = "bold 8px monospace";
  ctx.textAlign = "center";
  ctx.fillText(`${Math.ceil(temp)}°`, tx + 5, ty - 4);
}

// ── HUD ────────────────────────────────────────────────────────

function drawHUD(ctx, state, colors) {
  const p1 = state.p1;
  const p2 = state.p2;

  // Top bar background
  ctx.fillStyle = gameColor("000000");
  ctx.globalAlpha = 0.6;
  ctx.fillRect(0, 0, CANVAS_W, SHORE_Y);
  ctx.globalAlpha = 1;

  // P1 info (left)
  ctx.fillStyle = colors.fg;
  ctx.font = "bold 10px monospace";
  ctx.textAlign = "left";
  ctx.fillText(jt`P1: ${p1.score}`, 8, 14);

  // P1 lives
  for (let i = 0; i < p1.lives; i++) {
    ctx.fillStyle = colors.fg;
    ctx.fillRect(8 + i * 10, 20, 6, 6);
  }

  // P1 igloo progress bar
  const progressW = 60;
  const piecesNeeded = state.piecesNeeded || 15;
  ctx.fillStyle = colors.muted;
  ctx.fillRect(8, 30, progressW, 5);
  ctx.fillStyle = colors.fg;
  ctx.fillRect(8, 30, progressW * Math.min(p1.iglooPieces / piecesNeeded, 1), 5);

  // Game title (center)
  ctx.fillStyle = colors.blockWhite;
  ctx.font = "bold 11px monospace";
  ctx.textAlign = "center";

  const modeLabel =
    state.mode === GAME_MODE.BLIZZARD
      ? "BLIZZARD"
      : state.mode === GAME_MODE.PEACEFUL
        ? "PEACEFUL"
        : jt`R${state.round}/5`;
  ctx.fillText(jt`FROSTBITE  ${modeLabel}`, CANVAS_W / 2, 14);

  // Round wins
  ctx.font = "9px monospace";
  ctx.fillStyle = colors.fg;
  ctx.textAlign = "center";
  ctx.fillText(`${p1.roundWins} - ${p2.roundWins}`, CANVAS_W / 2, 28);

  // P2 info (right)
  ctx.fillStyle = colors.accent;
  ctx.font = "bold 10px monospace";
  ctx.textAlign = "right";
  ctx.fillText(jt`P2: ${p2.score}`, CANVAS_W - 8, 14);

  // P2 lives
  for (let i = 0; i < p2.lives; i++) {
    ctx.fillStyle = colors.accent;
    ctx.fillRect(CANVAS_W - 8 - (i + 1) * 10, 20, 6, 6);
  }

  // P2 igloo progress bar
  ctx.fillStyle = colors.muted;
  ctx.fillRect(CANVAS_W - 8 - progressW, 30, progressW, 5);
  ctx.fillStyle = colors.accent;
  const p2Progress = progressW * Math.min(p2.iglooPieces / piecesNeeded, 1);
  ctx.fillRect(CANVAS_W - 8 - p2Progress, 30, p2Progress, 5);
}

// ── Countdown overlay ──────────────────────────────────────────

function drawCountdown(ctx, state, colors, frameCount) {
  ctx.fillStyle = gameColor("000000");
  ctx.globalAlpha = 0.4;
  ctx.fillRect(0, CANVAS_H / 2 - 40, CANVAS_W, 80);
  ctx.globalAlpha = 1;

  const text = state.countdown > 0 ? `${state.countdown}` : t("BUILD!");
  const pulse = 1 + Math.sin(frameCount * 0.15) * 0.1;

  ctx.save();
  ctx.translate(CANVAS_W / 2, CANVAS_H / 2);
  ctx.scale(pulse, pulse);
  ctx.fillStyle = state.countdown > 0 ? colors.blockWhite : colors.fg;
  ctx.font = "bold 36px monospace";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText(text, 0, 0);
  ctx.restore();
}

// ── Round end overlay ──────────────────────────────────────────

function drawRoundEnd(ctx, state, colors, _frameCount) {
  ctx.fillStyle = gameColor("000000");
  ctx.globalAlpha = 0.5;
  ctx.fillRect(0, CANVAS_H / 2 - 60, CANVAS_W, 120);
  ctx.globalAlpha = 1;

  ctx.font = "bold 14px monospace";
  ctx.textAlign = "center";

  if (state.roundWinner > 0) {
    const winColor = state.roundWinner === 1 ? colors.fg : colors.accent;
    ctx.fillStyle = winColor;
    ctx.fillText(jt`PLAYER ${state.roundWinner} WINS THE ROUND!`, CANVAS_W / 2, CANVAS_H / 2 - 20);
  } else {
    ctx.fillStyle = colors.blockWhite;
    ctx.fillText(t("ROUND DRAW!"), CANVAS_W / 2, CANVAS_H / 2 - 20);
  }

  // Igloo comparison
  ctx.font = "10px monospace";
  ctx.fillStyle = colors.fg;
  ctx.fillText(jt`P1: ${state.p1.iglooPieces} pieces`, CANVAS_W / 2 - 80, CANVAS_H / 2 + 10);
  ctx.fillStyle = colors.accent;
  ctx.fillText(jt`P2: ${state.p2.iglooPieces} pieces`, CANVAS_W / 2 + 80, CANVAS_H / 2 + 10);

  // Score
  ctx.fillStyle = colors.blockWhite;
  ctx.fillText(jt`Score: ${state.p1.score} - ${state.p2.score}`, CANVAS_W / 2, CANVAS_H / 2 + 30);
}

// ── Finished overlay ───────────────────────────────────────────

function drawFinished(ctx, state, colors, frameCount) {
  // Enhanced aurora borealis celebration
  ctx.globalAlpha = 0.15;
  for (let wave = 0; wave < 6; wave++) {
    const hues = [
      colors.fg,
      colors.accent,
      gameColor("ff40ff"),
      gameColor("ffdd00"),
      gameColor("40ff80"),
      gameColor("4080ff"),
    ];
    ctx.strokeStyle = hues[wave];
    ctx.lineWidth = 4;
    ctx.beginPath();
    for (let x = 0; x < CANVAS_W; x += 3) {
      const y =
        CANVAS_H / 4 +
        Math.sin(x * 0.008 + frameCount * 0.03 + wave * 1.5) * 30 +
        Math.cos(x * 0.012 + frameCount * 0.02) * 15;
      if (x === 0) ctx.moveTo(x, y);
      else ctx.lineTo(x, y);
    }
    ctx.stroke();
  }
  ctx.globalAlpha = 1;

  // Overlay
  ctx.fillStyle = gameColor("000000");
  ctx.globalAlpha = 0.6;
  ctx.fillRect(CANVAS_W / 2 - 150, CANVAS_H / 2 - 60, 300, 120);
  ctx.globalAlpha = 1;

  const p1Wins = state.p1.roundWins;
  const p2Wins = state.p2.roundWins;
  let winner = 0;
  if (p1Wins > p2Wins) winner = 1;
  else if (p2Wins > p1Wins) winner = 2;

  ctx.font = "bold 18px monospace";
  ctx.textAlign = "center";

  if (winner > 0) {
    const winColor = winner === 1 ? colors.fg : colors.accent;
    ctx.fillStyle = winColor;
    ctx.fillText(jt`PLAYER ${winner} WINS!`, CANVAS_W / 2, CANVAS_H / 2 - 20);
  } else {
    ctx.fillStyle = colors.blockWhite;
    ctx.fillText(t("DRAW!"), CANVAS_W / 2, CANVAS_H / 2 - 20);
  }

  ctx.font = "12px monospace";
  ctx.fillStyle = colors.blockWhite;
  ctx.fillText(
    jt`Rounds: ${p1Wins} - ${p2Wins}  |  Score: ${state.p1.score} - ${state.p2.score}`,
    CANVAS_W / 2,
    CANVAS_H / 2 + 15,
  );

  // Flashing "GAME OVER"
  if (Math.floor(frameCount / 30) % 2 === 0) {
    ctx.font = "bold 10px monospace";
    ctx.fillStyle = colors.muted;
    ctx.fillText(t("GAME OVER"), CANVAS_W / 2, CANVAS_H / 2 + 40);
  }
}

// ── CRT scanlines ──────────────────────────────────────────────

function drawCRT(ctx) {
  ctx.fillStyle = "rgba(0,0,0,0.08)";
  for (let y = 0; y < CANVAS_H; y += 3) {
    ctx.fillRect(0, y, CANVAS_W, 1);
  }

  // Vignette
  const vignette = ctx.createRadialGradient(
    CANVAS_W / 2,
    CANVAS_H / 2,
    CANVAS_W * 0.3,
    CANVAS_W / 2,
    CANVAS_H / 2,
    CANVAS_W * 0.7,
  );
  vignette.addColorStop(0, "rgba(0,0,0,0)");
  vignette.addColorStop(1, "rgba(0,0,0,0.3)");
  ctx.fillStyle = vignette;
  ctx.fillRect(0, 0, CANVAS_W, CANVAS_H);
}
