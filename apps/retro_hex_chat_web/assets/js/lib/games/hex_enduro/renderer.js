/**
 * Canvas renderer for Hex Enduro — cyberpunk post-apocalyptic racing.
 * Pseudo-3D road with perspective, weather effects, day/night cycle.
 * Pure rendering functions, no side effects beyond canvas drawing.
 * @module games/hex_enduro_renderer
 */

import { PHASE, GAME_MODE, WEATHER } from "./protocol.js";
import {
  CANVAS_W,
  CANVAS_H,
  HORIZON_Y,
  ROAD_BOTTOM_Y,
  ROAD_BOTTOM_WIDTH,
  ROAD_TOP_WIDTH,
  NUM_SEGMENTS,
  MAX_Z,
  SPEED_MAX,
  FUEL_MAX,
  MAX_DAYS,
  LANE_COUNT,
} from "./physics.js";
import { t, jt } from "../../i18n.js";
import { gameColor } from "../../game_colors.js";

// ── Road colors (per weather) ──
const SKY_COLORS = {
  [WEATHER.DAY]: [gameColor("0a0520"), gameColor("1a0a40")],
  [WEATHER.SNOW]: [gameColor("1a1a2a"), gameColor("2a2a3a")],
  [WEATHER.FOG]: [gameColor("252530"), gameColor("353540")],
  [WEATHER.NIGHT]: [gameColor("000003"), gameColor("020208")],
  [WEATHER.DAWN]: [gameColor("150825"), gameColor("2a1040")],
};

const MOUNTAIN_COLORS = {
  [WEATHER.DAY]: gameColor("0f0f2a"),
  [WEATHER.SNOW]: gameColor("1a1a30"),
  [WEATHER.FOG]: gameColor("202030"),
  [WEATHER.NIGHT]: gameColor("040410"),
  [WEATHER.DAWN]: gameColor("150a25"),
};

const WEATHER_LABELS = {
  [WEATHER.DAY]: "DAY",
  [WEATHER.SNOW]: "SNOW",
  [WEATHER.FOG]: "FOG",
  [WEATHER.NIGHT]: "NIGHT",
  [WEATHER.DAWN]: "DAWN",
};

/**
 * Read CSS custom properties from canvas computed style.
 * @param {HTMLCanvasElement} canvas
 * @returns {object} color palette
 */
export function getColors(canvas) {
  const s = getComputedStyle(canvas);
  return {
    bg: s.getPropertyValue("--game-bg-color").trim() || gameColor("0a0a1a"),
    p1: s.getPropertyValue("--game-fg-color").trim() || gameColor("39ff14"),
    p2: s.getPropertyValue("--game-accent-color").trim() || gameColor("00e5ff"),
    muted: s.getPropertyValue("--game-muted-color").trim() || gameColor("1a1a2a"),
    glow: s.getPropertyValue("--game-glow-color").trim() || "rgba(57,255,20,0.15)",
    warning: s.getPropertyValue("--game-warning-color").trim() || gameColor("ff4444"),
    road1: s.getPropertyValue("--game-road-color-1").trim() || gameColor("2a2a3a"),
    road2: s.getPropertyValue("--game-road-color-2").trim() || gameColor("1a1a2a"),
    lane: s.getPropertyValue("--game-lane-color").trim() || gameColor("555566"),
    mountain: s.getPropertyValue("--game-mountain-color").trim() || gameColor("151525"),
    carAi: s.getPropertyValue("--game-car-ai").trim() || gameColor("ff8c00"),
    fuel: s.getPropertyValue("--game-fuel-color").trim() || gameColor("ffee00"),
  };
}

/**
 * Render a full frame.
 * @param {CanvasRenderingContext2D} ctx
 * @param {object} state - game state (nested p1/p2 or flat)
 * @param {object} colors
 * @param {number} time - performance.now()
 * @param {boolean} isHost - true if rendering from P1 perspective
 */
export function render(ctx, state, colors, time, isHost) {
  const p = isHost ? state.p1 : state.p2;
  const opp = isHost ? state.p2 : state.p1;
  const pColor = isHost ? colors.p1 : colors.p2;
  const oppColor = isHost ? colors.p2 : colors.p1;

  drawSky(ctx, state);
  drawMountains(ctx, state, time);
  drawRoad(ctx, state, colors, p);
  drawFuelStations(ctx, state, colors, p);
  drawAICars(ctx, state, colors, p, time);
  drawOpponentCar(ctx, state, colors, p, opp, oppColor, time);
  drawPlayerCar(ctx, colors, p, pColor, time);
  drawWeatherEffects(ctx, state, time);
  drawHUD(ctx, state, colors, p, opp, pColor, oppColor, isHost, time);
  drawPhaseOverlays(ctx, state, colors, time);
  drawCRT(ctx);
}

// ── Perspective Projection ──

function zToScreen(z) {
  const t = z / MAX_Z;
  const perspective = Math.pow(Math.max(0, Math.min(1, t)), 1.5);
  const y = ROAD_BOTTOM_Y - (ROAD_BOTTOM_Y - HORIZON_Y) * perspective;
  const scale = 1 - perspective;
  const roadWidth = ROAD_BOTTOM_WIDTH * scale + ROAD_TOP_WIDTH * perspective;
  return { y, scale, roadWidth };
}

function getLaneX(lane, laneTransition, targetLane, roadWidth) {
  const laneWidth = roadWidth / LANE_COUNT;
  let effectiveLane = lane;
  if (lane !== targetLane && laneTransition > 0) {
    const t = laneTransition / 255;
    effectiveLane = lane + (targetLane - lane) * t;
  }
  return (effectiveLane - 1) * laneWidth;
}

// ── Sky ──

function drawSky(ctx, state) {
  const skyColors = SKY_COLORS[state.weather] || SKY_COLORS[WEATHER.DAY];
  const grad = ctx.createLinearGradient(0, 0, 0, HORIZON_Y);
  grad.addColorStop(0, skyColors[0]);
  grad.addColorStop(1, skyColors[1]);
  ctx.fillStyle = grad;
  ctx.fillRect(0, 0, CANVAS_W, HORIZON_Y);

  // Stars (night/dawn only)
  if (state.weather === WEATHER.NIGHT || state.weather === WEATHER.DAWN) {
    ctx.fillStyle =
      state.weather === WEATHER.NIGHT ? "rgba(255,255,255,0.7)" : "rgba(255,255,255,0.3)";
    const seed = state.seed || 42;
    for (let i = 0; i < 40; i++) {
      const x = (((seed * (i + 1) * 7919) % CANVAS_W) + CANVAS_W) % CANVAS_W;
      const y = (((seed * (i + 1) * 6271) % HORIZON_Y) + HORIZON_Y) % HORIZON_Y;
      ctx.fillRect(x, y, 1, 1);
    }
  }
}

// ── Mountains ──

function drawMountains(ctx, state, _time) {
  const color = MOUNTAIN_COLORS[state.weather] || MOUNTAIN_COLORS[WEATHER.DAY];
  ctx.fillStyle = color;

  // Two mountain layers with simple triangles
  const mountainY = HORIZON_Y;
  const seed = state.seed || 42;

  ctx.beginPath();
  ctx.moveTo(0, mountainY);
  for (let x = 0; x <= CANVAS_W; x += 40) {
    const h = 15 + ((((seed + x * 137) % 30) + 30) % 30);
    ctx.lineTo(x, mountainY - h);
    ctx.lineTo(x + 20, mountainY - h * 0.6);
  }
  ctx.lineTo(CANVAS_W, mountainY);
  ctx.closePath();
  ctx.fill();
}

// ── Road ──

function drawRoad(ctx, state, colors, _player) {
  const segmentHeight = (ROAD_BOTTOM_Y - HORIZON_Y) / NUM_SEGMENTS;
  const scrollPhaseBase = state.scrollOffset || 0;
  const cx = CANVAS_W / 2;

  for (let i = 0; i < NUM_SEGMENTS; i++) {
    const t = i / NUM_SEGMENTS;
    const perspective = Math.pow(t, 1.5);
    const y = ROAD_BOTTOM_Y - i * segmentHeight;
    const width = ROAD_BOTTOM_WIDTH * (1 - perspective) + ROAD_TOP_WIDTH * perspective;

    const nextT = (i + 1) / NUM_SEGMENTS;
    const nextPerspective = Math.pow(nextT, 1.5);
    const nextY = ROAD_BOTTOM_Y - (i + 1) * segmentHeight;
    const nextWidth = ROAD_BOTTOM_WIDTH * (1 - nextPerspective) + ROAD_TOP_WIDTH * nextPerspective;

    // Alternating road stripes for speed effect
    const scrollPhase = (scrollPhaseBase + i * 4) % 20;
    const isStripe = scrollPhase < 10;

    // Road shoulder (darker)
    const shoulderWidth = width * 0.08;

    // Road surface
    ctx.fillStyle = isStripe ? colors.road1 : colors.road2;
    ctx.beginPath();
    ctx.moveTo(cx - width / 2, y);
    ctx.lineTo(cx + width / 2, y);
    ctx.lineTo(cx + nextWidth / 2, nextY);
    ctx.lineTo(cx - nextWidth / 2, nextY);
    ctx.closePath();
    ctx.fill();

    // Road edges (bright shoulder lines)
    if (isStripe) {
      ctx.fillStyle = colors.lane;
      // Left edge
      ctx.fillRect(cx - width / 2, y, shoulderWidth, -segmentHeight);
      // Right edge
      ctx.fillRect(cx + width / 2 - shoulderWidth, y, shoulderWidth, -segmentHeight);
    }

    // Lane dividers (dashed)
    if (isStripe && i < NUM_SEGMENTS - 2) {
      ctx.fillStyle = colors.lane;
      const laneWidth = width / 3;
      const dividerW = Math.max(1, 2 * (1 - perspective));
      // Left divider
      ctx.fillRect(cx - laneWidth / 2 - dividerW / 2, y, dividerW, -segmentHeight);
      // Right divider
      ctx.fillRect(cx + laneWidth / 2 - dividerW / 2, y, dividerW, -segmentHeight);
    }
  }
}

// ── Cars ──

function drawCarShape(ctx, x, y, scale, color, isNight) {
  const w = Math.max(4, 18 * scale);
  const h = Math.max(6, 28 * scale);

  if (isNight && scale < 0.5) {
    // At night, distant cars are just headlights (colored dots)
    ctx.fillStyle = color;
    ctx.fillRect(x - w * 0.3, y - h * 0.2, Math.max(2, w * 0.25), Math.max(2, h * 0.15));
    ctx.fillRect(x + w * 0.1, y - h * 0.2, Math.max(2, w * 0.25), Math.max(2, h * 0.15));
    return;
  }

  // Car body
  ctx.fillStyle = color;
  ctx.fillRect(x - w / 2, y - h, w, h);

  // Windshield
  ctx.fillStyle = isNight ? "rgba(100,100,120,0.6)" : "rgba(150,180,200,0.7)";
  ctx.fillRect(x - w * 0.35, y - h * 0.75, w * 0.7, h * 0.2);

  // Rear lights
  ctx.fillStyle = gameColor("ff2222");
  ctx.fillRect(x - w * 0.4, y - h * 0.05, w * 0.2, Math.max(1, h * 0.08));
  ctx.fillRect(x + w * 0.2, y - h * 0.05, w * 0.2, Math.max(1, h * 0.08));
}

function drawAICars(ctx, state, colors, _player, _time) {
  const isNight = state.weather === WEATHER.NIGHT;
  const cx = CANVAS_W / 2;
  const AI_COLORS = [colors.carAi, gameColor("cc4444"), gameColor("dddd44"), gameColor("cccccc")];

  for (const car of state.aiCars || []) {
    if (car.zPos < 0 || car.zPos > MAX_Z) continue;

    // Fog visibility: hide distant cars
    if (state.weather === WEATHER.FOG && car.zPos > MAX_Z * 0.4) continue;

    const { y, scale, roadWidth } = zToScreen(car.zPos);
    const laneWidth = roadWidth / LANE_COUNT;
    const laneX = cx + (car.lane - 1) * laneWidth;

    const carColor = isNight ? gameColor("ff3333") : AI_COLORS[car.type % AI_COLORS.length];
    drawCarShape(ctx, laneX, y, scale, carColor, isNight);
  }
}

function drawOpponentCar(ctx, state, colors, player, opp, oppColor, _time) {
  // Only render opponents ahead of us (behind = not visible on forward-facing road)
  const relativeZ = opp.zOffset - player.zOffset;
  if (relativeZ <= 0 || relativeZ > MAX_Z) return;

  const isNight = state.weather === WEATHER.NIGHT;
  const displayZ = relativeZ;

  const { y, scale, roadWidth } = zToScreen(displayZ);
  const cx = CANVAS_W / 2;
  const targetLane = opp.targetLane !== undefined ? opp.targetLane : opp.lane;
  const laneX = cx + getLaneX(opp.lane, opp.laneTransition, targetLane, roadWidth);

  drawCarShape(ctx, laneX, y, scale, oppColor, isNight);

  // Slipstream visual (speed lines behind front car)
  if (player.slipstream > 60) {
    ctx.save();
    ctx.globalAlpha = Math.min(0.6, player.slipstream / 255);
    ctx.strokeStyle = oppColor;
    ctx.lineWidth = 1;
    for (let i = 0; i < 4; i++) {
      const lineY = y + 5 + i * 4;
      const lineW = 8 + i * 3;
      ctx.beginPath();
      ctx.moveTo(laneX - lineW, lineY);
      ctx.lineTo(laneX + lineW, lineY);
      ctx.stroke();
    }
    ctx.restore();
  }
}

function drawPlayerCar(ctx, colors, player, pColor, time) {
  const cx = CANVAS_W / 2;
  const { roadWidth } = zToScreen(0);
  const targetLane = player.targetLane !== undefined ? player.targetLane : player.lane;
  const laneX = cx + getLaneX(player.lane, player.laneTransition, targetLane, roadWidth);
  const y = ROAD_BOTTOM_Y - 10;

  // Player car is always full scale
  drawCarShape(ctx, laneX, y, 1.0, pColor, false);

  // Boost flame effect
  if (player.boost > 0) {
    ctx.fillStyle = time % 100 < 50 ? gameColor("ff6600") : gameColor("ffaa00");
    ctx.fillRect(laneX - 3, y, 6, 6);
  }
}

// ── Fuel Stations ──

function drawFuelStations(ctx, state, colors, _player) {
  const cx = CANVAS_W / 2;
  const isNight = state.weather === WEATHER.NIGHT;

  for (const fs of state.fuelStations || []) {
    if (fs.zPos < 0 || fs.zPos > MAX_Z) continue;
    if (state.weather === WEATHER.FOG && fs.zPos > MAX_Z * 0.4) continue;

    const { y, scale, roadWidth } = zToScreen(fs.zPos);
    const laneWidth = roadWidth / LANE_COUNT;
    const laneX = cx + (fs.lane - 1) * laneWidth;

    const size = Math.max(4, 10 * scale);

    // Glowing fuel icon
    ctx.save();
    ctx.fillStyle = isNight ? "rgba(255,238,0,0.5)" : colors.fuel;
    ctx.shadowColor = colors.fuel;
    ctx.shadowBlur = isNight ? 12 : 6;
    ctx.fillRect(laneX - size / 2, y - size, size, size);
    ctx.restore();
  }
}

// ── Weather Effects ──

function drawWeatherEffects(ctx, state, time) {
  switch (state.weather) {
    case WEATHER.SNOW:
      drawSnow(ctx, state, time);
      break;
    case WEATHER.FOG:
      drawFog(ctx);
      break;
    case WEATHER.NIGHT:
      drawNight(ctx, state);
      break;
    case WEATHER.DAWN:
      drawDawn(ctx, state);
      break;
  }
}

function drawSnow(ctx, state, time) {
  ctx.fillStyle = "rgba(255,255,255,0.5)";
  const seed = state.seed || 42;
  for (let i = 0; i < 80; i++) {
    const baseX = (((seed * (i + 1) * 7919) % CANVAS_W) + CANVAS_W) % CANVAS_W;
    const baseY = (((seed * (i + 1) * 6271) % CANVAS_H) + CANVAS_H) % CANVAS_H;
    const drift = Math.sin(time * 0.001 + i) * 20;
    const fall = (time * 0.05 * (1 + (i % 3) * 0.3)) % CANVAS_H;
    const x = (((baseX + drift) % CANVAS_W) + CANVAS_W) % CANVAS_W;
    const y = (baseY + fall) % CANVAS_H;
    const size = i % 4 === 0 ? 3 : 2;
    ctx.fillRect(x, y, size, size);
  }
}

function drawFog(ctx) {
  const grad = ctx.createLinearGradient(0, HORIZON_Y, 0, ROAD_BOTTOM_Y);
  grad.addColorStop(0, "rgba(160,160,170,0.85)");
  grad.addColorStop(0.4, "rgba(160,160,170,0.45)");
  grad.addColorStop(0.8, "rgba(160,160,170,0.1)");
  grad.addColorStop(1, "rgba(160,160,170,0.0)");
  ctx.fillStyle = grad;
  ctx.fillRect(0, HORIZON_Y, CANVAS_W, ROAD_BOTTOM_Y - HORIZON_Y);
}

function drawNight(ctx, _state) {
  // Dark overlay
  ctx.fillStyle = "rgba(0,0,8,0.82)";
  ctx.fillRect(0, 0, CANVAS_W, CANVAS_H);

  // Headlight cone from player car
  const cx = CANVAS_W / 2;
  const carY = ROAD_BOTTOM_Y - 10;

  ctx.save();
  ctx.globalCompositeOperation = "lighter";
  const grad = ctx.createRadialGradient(cx, carY, 15, cx, carY - 200, 160);
  grad.addColorStop(0, "rgba(255,255,200,0.25)");
  grad.addColorStop(1, "rgba(255,255,200,0.0)");
  ctx.fillStyle = grad;
  ctx.beginPath();
  ctx.moveTo(cx - 25, carY);
  ctx.lineTo(cx - 120, carY - 260);
  ctx.lineTo(cx + 120, carY - 260);
  ctx.lineTo(cx + 25, carY);
  ctx.closePath();
  ctx.fill();
  ctx.restore();
}

function drawDawn(ctx, _state) {
  // Warm glow at horizon
  const grad = ctx.createLinearGradient(0, HORIZON_Y - 30, 0, HORIZON_Y + 60);
  grad.addColorStop(0, "rgba(255,100,50,0.0)");
  grad.addColorStop(0.5, "rgba(255,130,60,0.25)");
  grad.addColorStop(1, "rgba(255,80,40,0.0)");
  ctx.fillStyle = grad;
  ctx.fillRect(0, HORIZON_Y - 30, CANVAS_W, 90);
}

// ── HUD ──

function drawHUD(ctx, state, colors, player, opponent, pColor, oppColor, isHost, time) {
  ctx.save();
  ctx.font = "bold 11px monospace";

  // Top bar background
  ctx.fillStyle = "rgba(0,0,0,0.7)";
  ctx.fillRect(0, 0, CANVAS_W, 24);

  // Player label + score (left)
  const pLabel = isHost ? "P1" : "P2";
  const oLabel = isHost ? "P2" : "P1";
  ctx.fillStyle = pColor;
  ctx.fillText(jt`${pLabel}: ${player.score}pts`, 6, 16);

  // Opponent label + score (right)
  ctx.fillStyle = oppColor;
  const oppText = jt`${oLabel}: ${opponent.score}pts`;
  ctx.fillText(oppText, CANVAS_W - ctx.measureText(oppText).width - 6, 16);

  // Center: game info
  ctx.fillStyle = gameColor("aaaacc");
  const modeLabel =
    state.mode === GAME_MODE.CLASSIC_DUEL
      ? jt`Day ${Math.min(state.dayNumber, MAX_DAYS)}/${MAX_DAYS}`
      : state.mode === GAME_MODE.NIGHT_RACE
        ? t("NIGHT RACE")
        : "SPRINT";
  const weatherLabel =
    state.mode === GAME_MODE.CLASSIC_DUEL ? ` - ${WEATHER_LABELS[state.weather] || ""}` : "";
  const centerText = `${modeLabel}${weatherLabel}`;
  ctx.fillText(centerText, CANVAS_W / 2 - ctx.measureText(centerText).width / 2, 16);

  // Bottom bar
  ctx.fillStyle = "rgba(0,0,0,0.7)";
  ctx.fillRect(0, CANVAS_H - 28, CANVAS_W, 28);

  // Speed gauge (left)
  ctx.fillStyle = gameColor("888");
  ctx.fillText("SPD", 6, CANVAS_H - 10);
  drawBar(ctx, 36, CANVAS_H - 20, 80, 10, player.speed / SPEED_MAX, pColor);

  // Fuel gauge (center-left)
  if (state.mode !== GAME_MODE.SPRINT) {
    ctx.fillStyle = gameColor("888");
    ctx.fillText("FUEL", 130, CANVAS_H - 10);
    const fuelRatio = player.fuel / FUEL_MAX;
    const fuelColor =
      fuelRatio < 0.2 ? (time % 400 < 200 ? colors.warning : gameColor("660000")) : colors.fuel;
    drawBar(ctx, 168, CANVAS_H - 20, 80, 10, fuelRatio, fuelColor);
  }

  // Overtakes (center-right)
  ctx.fillStyle = gameColor("888");
  const overtakeText =
    state.mode === GAME_MODE.CLASSIC_DUEL
      ? `${player.overtakes}/${state.dayOvertakeTarget}`
      : `${player.overtakes}`;
  ctx.fillText(jt`OVT: ${overtakeText}`, 270, CANVAS_H - 10);

  // Timer (right) for timed modes
  if (state.mode !== GAME_MODE.CLASSIC_DUEL) {
    const secs = Math.ceil(state.gameTimer / 60);
    const min = Math.floor(secs / 60);
    const sec = secs % 60;
    ctx.fillStyle = secs < 10 ? colors.warning : gameColor("aaaacc");
    const timerText = `${min}:${sec.toString().padStart(2, "0")}`;
    ctx.fillText(timerText, CANVAS_W - ctx.measureText(timerText).width - 6, CANVAS_H - 10);
  }

  // Boost indicator (after overtakes, before timer)
  if (player.boost > 0) {
    ctx.fillStyle = gameColor("ff8800");
    ctx.fillText(t("TURBO!"), 350, CANVAS_H - 10);
  }

  ctx.restore();
}

function drawBar(ctx, x, y, w, h, ratio, color) {
  // Background
  ctx.fillStyle = "rgba(255,255,255,0.1)";
  ctx.fillRect(x, y, w, h);
  // Fill
  ctx.fillStyle = color;
  ctx.fillRect(x, y, w * Math.max(0, Math.min(1, ratio)), h);
  // Border
  ctx.strokeStyle = "rgba(255,255,255,0.3)";
  ctx.strokeRect(x, y, w, h);
}

// ── Phase Overlays ──

function drawPhaseOverlays(ctx, state, colors, time) {
  switch (state.phase) {
    case PHASE.COUNTDOWN:
      drawCountdown(ctx, state, colors);
      break;
    case PHASE.DAY_END:
      drawDayEnd(ctx, state, colors);
      break;
    case PHASE.FINISHED:
      drawFinished(ctx, state, colors, time);
      break;
  }
}

function drawCountdown(ctx, state, colors) {
  ctx.save();
  ctx.fillStyle = "rgba(0,0,0,0.5)";
  ctx.fillRect(0, 0, CANVAS_W, CANVAS_H);

  ctx.font = "bold 72px monospace";
  ctx.fillStyle = colors.p1;
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText(String(state.countdown), CANVAS_W / 2, CANVAS_H / 2);
  ctx.restore();
}

function drawDayEnd(ctx, state, colors) {
  ctx.save();
  ctx.fillStyle = "rgba(0,0,0,0.6)";
  ctx.fillRect(0, 0, CANVAS_W, CANVAS_H);

  ctx.textAlign = "center";
  ctx.textBaseline = "middle";

  ctx.font = "bold 28px monospace";
  ctx.fillStyle = gameColor("aaaacc");
  ctx.fillText(jt`Day ${state.dayNumber - 1} Complete`, CANVAS_W / 2, CANVAS_H / 2 - 30);

  ctx.font = "bold 16px monospace";
  ctx.fillStyle = colors.p1;
  ctx.fillText(jt`P1: ${state.p1.score}pts`, CANVAS_W / 2 - 80, CANVAS_H / 2 + 10);
  ctx.fillStyle = colors.p2;
  ctx.fillText(jt`P2: ${state.p2.score}pts`, CANVAS_W / 2 + 80, CANVAS_H / 2 + 10);
  ctx.restore();
}

function drawFinished(ctx, state, colors, time) {
  ctx.save();
  ctx.fillStyle = "rgba(0,0,0,0.75)";
  ctx.fillRect(0, 0, CANVAS_W, CANVAS_H);

  ctx.textAlign = "center";
  ctx.textBaseline = "middle";

  ctx.font = "bold 36px monospace";
  ctx.fillStyle = gameColor("aaaacc");
  ctx.fillText(t("RACE OVER"), CANVAS_W / 2, CANVAS_H / 2 - 60);

  ctx.font = "bold 20px monospace";
  ctx.fillStyle = colors.p1;
  ctx.fillText(
    jt`P1: ${state.p1.score}pts (${state.p1.overtakes} ovt)`,
    CANVAS_W / 2,
    CANVAS_H / 2 - 15,
  );
  ctx.fillStyle = colors.p2;
  ctx.fillText(
    jt`P2: ${state.p2.score}pts (${state.p2.overtakes} ovt)`,
    CANVAS_W / 2,
    CANVAS_H / 2 + 15,
  );

  // Winner announcement
  const p1Wins = state.p1.score > state.p2.score;
  const draw = state.p1.score === state.p2.score;
  ctx.font = "bold 28px monospace";

  if (draw) {
    ctx.fillStyle = gameColor("aaaacc");
    ctx.fillText(t("DRAW!"), CANVAS_W / 2, CANVAS_H / 2 + 55);
  } else {
    const winnerColor = p1Wins ? colors.p1 : colors.p2;
    const winnerLabel = p1Wins ? t("P1 WINS!") : t("P2 WINS!");
    ctx.fillStyle = time % 500 < 250 ? winnerColor : gameColor("ffffff");
    ctx.fillText(winnerLabel, CANVAS_W / 2, CANVAS_H / 2 + 55);
  }

  ctx.restore();
}

// ── CRT Effects ──

function drawCRT(ctx) {
  // Scanlines
  ctx.fillStyle = "rgba(0,0,0,0.08)";
  for (let y = 0; y < CANVAS_H; y += 3) {
    ctx.fillRect(0, y, CANVAS_W, 1);
  }

  // Vignette
  const grad = ctx.createRadialGradient(
    CANVAS_W / 2,
    CANVAS_H / 2,
    CANVAS_W * 0.3,
    CANVAS_W / 2,
    CANVAS_H / 2,
    CANVAS_W * 0.7,
  );
  grad.addColorStop(0, "rgba(0,0,0,0)");
  grad.addColorStop(1, "rgba(0,0,0,0.3)");
  ctx.fillStyle = grad;
  ctx.fillRect(0, 0, CANVAS_W, CANVAS_H);
}
