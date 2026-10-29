/**
 * Canvas pieces the games' renderers draw the same way: the background, the
 * CRT scanlines and vignette, the pulsing countdown, the waiting and "get
 * ready" messages, bitmap score digits, centred text and particle dots — and
 * the step that moves particles. Each takes the canvas size, since the games
 * draw at different sizes.
 * @module games/core/render
 */

import { gameColor } from "../../game_colors.js";
import { t, jt } from "../../i18n.js";

/**
 * @param {CanvasRenderingContext2D} ctx
 * @param {{bg: string}} colors
 * @param {number} width
 * @param {number} height
 */
export function drawBackground(ctx, colors, width, height) {
  ctx.fillStyle = colors.bg;
  ctx.fillRect(0, 0, width, height);
}

/**
 * Dark one-pixel lines across the canvas, like a CRT.
 * @param {CanvasRenderingContext2D} ctx
 * @param {number} width
 * @param {number} height
 * @param {{alpha?: number, step?: number}} [options] - line darkness, and the
 *   distance between lines in pixels.
 */
export function drawScanlines(ctx, width, height, { alpha = 0.08, step = 2 } = {}) {
  ctx.fillStyle = `rgba(0,0,0,${alpha})`;
  for (let y = 0; y < height; y += step) {
    ctx.fillRect(0, y, width, 1);
  }
}

/**
 * The countdown number, centred and gently pulsing.
 * @param {CanvasRenderingContext2D} ctx
 * @param {number} count
 * @param {{warning: string}} colors
 * @param {number} time - ms, drives the pulse
 * @param {number} width
 * @param {number} height
 */
export function drawCountdown(ctx, count, colors, time, width, height) {
  const pulse = 1.0 + 0.15 * Math.sin(time * 0.015);
  const size = Math.floor(80 * pulse);

  ctx.save();
  ctx.shadowColor = colors.warning;
  ctx.shadowBlur = 20;
  ctx.fillStyle = colors.warning;
  ctx.font = `bold ${size}px monospace`;
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText(String(count), width / 2, height / 2);
  ctx.restore();
}

/**
 * Dots that count up once every half second, for a message that is waiting.
 * @param {number} time - ms
 * @returns {string}
 */
export function waitingDots(time) {
  return ".".repeat(Math.floor((time / 500) % 4));
}

/**
 * The one waiting-for-the-other-player message every game shows.
 * @param {string} [dots]
 * @returns {string}
 */
export function waitingText(dots = "...") {
  return jt`WAITING FOR OPPONENT${dots}`;
}

/**
 * The waiting message, centred, with animated dots. Solo play has nobody to
 * wait for, so it reads "GET READY" instead; a co-op game waits for a partner.
 * @param {CanvasRenderingContext2D} ctx
 * @param {{fg: string, muted: string}} colors
 * @param {number} time - ms, drives the dots
 * @param {number} width
 * @param {number} height
 * @param {{solo?: boolean, partner?: boolean}} [options]
 */
export function drawWaiting(ctx, colors, time, width, height, options = {}) {
  const dots = waitingDots(time);
  const solo = options.solo === true;
  let text = waitingText(dots);
  if (solo) text = t("GET READY");
  else if (options.partner) text = jt`WAITING FOR PARTNER${dots}`;

  ctx.save();
  ctx.shadowColor = solo ? colors.fg : colors.muted;
  ctx.shadowBlur = solo ? 12 : 8;
  ctx.fillStyle = solo ? colors.fg : colors.muted;
  ctx.font = `${solo ? "bold " : ""}18px monospace`;
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText(text, width / 2, height / 2);
  ctx.restore();
}

/**
 * Darkened edges, like an old screen's: a radial gradient from clear at
 * `from` to `edge` darkness at `to`, both fractions of the canvas height or
 * width (`of`).
 * @param {CanvasRenderingContext2D} ctx
 * @param {number} width
 * @param {number} height
 * @param {{ from?: number, to?: number, of?: "height"|"width", edge?: number }} [options]
 */
export function drawVignette(
  ctx,
  width,
  height,
  { from = 0.4, to = 0.8, of = "height", edge = 0.4 } = {},
) {
  const size = of === "height" ? height : width;
  const gradient = ctx.createRadialGradient(
    width / 2,
    height / 2,
    size * from,
    width / 2,
    height / 2,
    size * to,
  );
  gradient.addColorStop(0, "rgba(0,0,0,0)");
  gradient.addColorStop(1, `rgba(0,0,0,${edge})`);
  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, width, height);
}

/** The digits 0-9 as 5x7 bitmaps, a row per number, the left pixel the high bit. */
const DIGITS = [
  [0x1f, 0x11, 0x11, 0x11, 0x11, 0x11, 0x1f],
  [0x04, 0x0c, 0x04, 0x04, 0x04, 0x04, 0x0e],
  [0x1f, 0x01, 0x01, 0x1f, 0x10, 0x10, 0x1f],
  [0x1f, 0x01, 0x01, 0x1f, 0x01, 0x01, 0x1f],
  [0x11, 0x11, 0x11, 0x1f, 0x01, 0x01, 0x01],
  [0x1f, 0x10, 0x10, 0x1f, 0x01, 0x01, 0x1f],
  [0x1f, 0x10, 0x10, 0x1f, 0x11, 0x11, 0x1f],
  [0x1f, 0x01, 0x01, 0x02, 0x04, 0x04, 0x04],
  [0x1f, 0x11, 0x11, 0x1f, 0x11, 0x11, 0x1f],
  [0x1f, 0x11, 0x11, 0x1f, 0x01, 0x01, 0x1f],
];

/**
 * One bitmap digit, in the current fill style; anything but 0-9 draws nothing.
 * @param {CanvasRenderingContext2D} ctx
 * @param {number} digit
 * @param {number} x - left
 * @param {number} y - top
 * @param {number} pixelSize
 */
export function drawDigit(ctx, digit, x, y, pixelSize) {
  const rows = DIGITS[digit];
  if (!rows) return;
  for (let row = 0; row < 7; row++) {
    for (let col = 0; col < 5; col++) {
      if (rows[row] & (0x10 >> col)) {
        ctx.fillRect(x + col * pixelSize, y + row * pixelSize, pixelSize, pixelSize);
      }
    }
  }
}

/**
 * A pixel-art sprite from rows of characters: each character a cell, coloured
 * by its entry in `palette`; a character the palette lacks (".") is left blank.
 * @param {CanvasRenderingContext2D} ctx
 * @param {string[]} rows
 * @param {Record<string, string>} palette
 * @param {number} x - left
 * @param {number} y - top
 * @param {number} sx - a cell's width
 * @param {number} sy - a cell's height
 * @param {{ flip?: boolean }} [options] - `flip` mirrors it left to right
 */
export function drawPixelSprite(ctx, rows, palette, x, y, sx, sy, { flip = false } = {}) {
  for (let row = 0; row < rows.length; row++) {
    const line = rows[row];
    for (let col = 0; col < line.length; col++) {
      const color = palette[line[col]];
      if (!color) continue;
      const cell = flip ? line.length - 1 - col : col;
      ctx.fillStyle = color;
      ctx.fillRect(x + cell * sx, y + row * sy, sx, sy);
    }
  }
}

/**
 * Bold monospace text at the centre of the canvas, lowered by `yOffset`.
 * @param {CanvasRenderingContext2D} ctx
 * @param {string} text
 * @param {number} size - px
 * @param {string} color
 * @param {number} width
 * @param {number} height
 * @param {number} [yOffset]
 */
export function drawCenterText(ctx, text, size, color, width, height, yOffset = 0) {
  ctx.font = `bold ${size}px monospace`;
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillStyle = color;
  ctx.fillText(text, width / 2, height / 2 + yOffset);
}

/**
 * "GET READY" at the centre, flickering, while a serve waits.
 * @param {CanvasRenderingContext2D} ctx
 * @param {{ fg: string }} colors
 * @param {number} time
 * @param {number} width
 * @param {number} height
 */
export function drawGetReady(ctx, colors, time, width, height) {
  const flicker = Math.sin(time * 0.02) > -0.3 ? 1.0 : 0.3;
  ctx.save();
  ctx.globalAlpha = flicker;
  ctx.shadowColor = colors.fg;
  ctx.shadowBlur = 12;
  ctx.fillStyle = colors.fg;
  ctx.font = "bold 24px monospace";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText(t("GET READY"), width / 2, height / 2);
  ctx.restore();
}

/**
 * Particles as 4-pixel dots, each fading with its life, in its own colour
 * or amber.
 * @param {CanvasRenderingContext2D} ctx
 * @param {Array<{ x: number, y: number, life: number, color?: string }>} particles
 */
export function drawParticleDots(ctx, particles) {
  for (const p of particles) {
    ctx.globalAlpha = p.life;
    ctx.fillStyle = p.color || gameColor("ffaa00");
    ctx.fillRect(p.x - 2, p.y - 2, 4, 4);
  }
  ctx.globalAlpha = 1.0;
}

/**
 * Particles flying out of one point in random directions. Each draws its
 * angle, then its speed — `base` plus up to `spread` — then whatever `extra`
 * adds (a colour, a life drawn after the speed), so a seeded match draws in
 * the same order every time.
 * @param {number} x
 * @param {number} y
 * @param {number} count
 * @param {{ speed: [number, number], extra?: (i: number, random: () => number) => object }} shape
 * @param {() => number} [random=Math.random] - draws in [0, 1)
 * @returns {Array<object>}
 */
export function burst(
  x,
  y,
  count,
  { speed: [base, spread], extra = () => ({}) },
  random = Math.random,
) {
  const particles = [];
  for (let i = 0; i < count; i++) {
    const angle = random() * Math.PI * 2;
    const speed = base + random() * spread;
    particles.push({
      x,
      y,
      vx: Math.cos(angle) * speed,
      vy: Math.sin(angle) * speed,
      ...extra(i, random),
    });
  }
  return particles;
}

/**
 * One step of particles: each moves by its velocity, slows by `drag` and
 * loses `fade` of its life; the spent ones are dropped. A game whose
 * particles move otherwise gives `velocity`, a particle's next velocity.
 * @param {Array<{ x: number, y: number, vx: number, vy: number, life: number }>} particles
 * @param {{ drag?: number, fade: number, velocity?: (p: object) => { vx: number, vy: number } }} options
 */
export function stepParticles(
  particles,
  { drag, fade, velocity = (p) => ({ vx: p.vx * drag, vy: p.vy * drag }) },
) {
  return particles
    .map((p) => ({
      ...p,
      x: p.x + p.vx,
      y: p.y + p.vy,
      ...velocity(p),
      life: p.life - fade,
    }))
    .filter((p) => p.life > 0);
}

/**
 * The occasional shake of a glitching screen: now and then (a draw over
 * `over`) a shift of up to half of `x` sideways, and of `y` up or down. The
 * y shift is drawn only when the text can shake that way.
 * @param {() => number} [random]
 * @param {{ over?: number, x?: number, y?: number }} [options]
 * @returns {[number, number]}
 */
export function glitchJitter(random = Math.random, { over = 0.9, x = 4, y = 2 } = {}) {
  const dx = random() > over ? (random() - 0.5) * x : 0;
  const dy = y && random() > over ? (random() - 0.5) * y : 0;
  return [dx, dy];
}

/**
 * Text with a glitch: a red copy and a blue copy split apart by `spread`
 * and shifted by `offset`, then the text itself in its colour, glowing.
 * Font and alignment are the caller's.
 * @param {CanvasRenderingContext2D} ctx
 * @param {string} text
 * @param {number} x
 * @param {number} y
 * @param {string} color
 * @param {{ offset?: [number, number], spread?: number, channelAlpha?: number, alpha?: number, blur?: number }} [options]
 */
export function drawGlitchText(
  ctx,
  text,
  x,
  y,
  color,
  { offset = [0, 0], spread = 2, channelAlpha = 0.5, alpha = 1.0, blur = 20 } = {},
) {
  const [dx, dy] = offset;
  ctx.globalAlpha = channelAlpha;
  ctx.fillStyle = gameColor("ff0000");
  ctx.fillText(text, x + dx - spread, y + dy);
  ctx.fillStyle = gameColor("0000ff");
  ctx.fillText(text, x + dx + spread, y + dy);
  ctx.globalAlpha = alpha;
  ctx.shadowColor = color;
  ctx.shadowBlur = blur;
  ctx.fillStyle = color;
  ctx.fillText(text, x, y);
}

/**
 * A faint grid of lines `step` pixels apart over the whole screen.
 * @param {CanvasRenderingContext2D} ctx
 * @param {{ muted: string }} colors
 * @param {number} width
 * @param {number} height
 * @param {{ alpha: number, step?: number }} options
 */
export function drawGrid(ctx, colors, width, height, { alpha, step = 40 }) {
  ctx.strokeStyle = colors.muted;
  ctx.lineWidth = 0.5;
  ctx.globalAlpha = alpha;
  for (let x = 0; x <= width; x += step) {
    ctx.beginPath();
    ctx.moveTo(x, 0);
    ctx.lineTo(x, height);
    ctx.stroke();
  }
  for (let y = 0; y <= height; y += step) {
    ctx.beginPath();
    ctx.moveTo(0, y);
    ctx.lineTo(width, y);
    ctx.stroke();
  }
  ctx.globalAlpha = 1.0;
}

/**
 * A closing banner: the title glitched in the middle of the screen and, when
 * there is one, a line under it that pulses.
 * @param {CanvasRenderingContext2D} ctx
 * @param {{ text: string, color: string, size?: number, sub?: string|null, subFont?: string, subColor?: string }} banner
 * @param {number} time
 * @param {number} width
 * @param {number} height
 */
export function drawGlitchBanner(
  ctx,
  { text, color, size = 36, sub = null, subFont = "16px monospace", subColor },
  time,
  width,
  height,
) {
  ctx.save();
  ctx.font = `bold ${size}px monospace`;
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  drawGlitchText(ctx, text, width / 2, height / 2, color, { offset: glitchJitter() });

  if (sub !== null) {
    ctx.font = subFont;
    ctx.shadowBlur = 8;
    ctx.fillStyle = subColor;
    ctx.globalAlpha = 0.5 + 0.5 * Math.sin(time * 0.005);
    ctx.fillText(sub, width / 2, height / 2 + 40);
  }
  ctx.restore();
}

/**
 * An `idle` hook for a game whose particles keep settling while its
 * simulation stands still (a round-over pause): one `update` step a tick.
 * @param {(particles: Array<object>) => Array<object>} update
 * @returns {(game: { particles: Array<object>, invalidate: () => void }) => void}
 */
export function settleParticles(update) {
  return (game) => {
    if (!game.particles.length) return;
    game.particles = update(game.particles);
    game.invalidate();
  };
}

/**
 * Snowflakes over the whole screen, each drawn at random: where, how big,
 * how fast it falls (`base` plus up to `spread`) and how far it drifts.
 * Decoration only: no replay depends on it.
 * @param {number} count
 * @param {number} width
 * @param {number} height
 * @param {{ speed: [number, number], drift: number }} fall
 * @returns {Array<{ x: number, y: number, size: number, speed: number, drift: number }>}
 */
export function snowfall(count, width, height, { speed: [base, spread], drift }) {
  const flakes = [];
  for (let i = 0; i < count; i++) {
    flakes.push({
      x: Math.random() * width,
      y: Math.random() * height,
      size: 1 + Math.random() * 2,
      speed: base + Math.random() * spread,
      drift: (Math.random() - 0.5) * drift,
    });
  }
  return flakes;
}

/**
 * The end of a match played in rounds: "MATCH OVER" and the side with more
 * rounds (P1 on a tie) as the winner.
 * @param {CanvasRenderingContext2D} ctx
 * @param {{ roundWins1: number, roundWins2: number }} state
 * @param {{ fg: string, accent: string, rope: string }} colors
 * @param {number} width
 * @param {number} height
 */
export function drawMatchOver(ctx, state, colors, width, height) {
  const winner = state.roundWins1 >= state.roundWins2 ? "P1" : "P2";
  const color = winner === "P1" ? colors.fg : colors.accent;
  drawCenterText(ctx, t("MATCH OVER"), 24, colors.rope, width, height);
  drawCenterText(ctx, jt`${winner} WINS!`, 36, color, width, height, 35);
}

/**
 * A duel's two scores along the top: player one's at `left`, in the
 * foreground colour, player two's ending at `right`, in the accent.
 * @param {CanvasRenderingContext2D} ctx
 * @param {{ score1: number, score2: number }} state
 * @param {{ fg: string, accent: string }} colors
 * @param {number} left
 * @param {number} right
 * @param {number} y
 */
export function drawScoreLabels(ctx, state, colors, left, right, y) {
  ctx.font = "bold 14px monospace";
  ctx.textBaseline = "top";
  ctx.textAlign = "left";
  ctx.fillStyle = colors.fg;
  ctx.fillText(jt`P1: ${state.score1}`, left, y);
  ctx.textAlign = "right";
  ctx.fillStyle = colors.accent;
  ctx.fillText(jt`P2: ${state.score2}`, right, y);
}

/**
 * A dot for each of the three rounds a side can take, lit for those it took:
 * player one's to the left of the middle, player two's to the right, at `y`.
 * @param {CanvasRenderingContext2D} ctx
 * @param {{ roundWins1: number, roundWins2: number }} state
 * @param {{ fg: string, accent: string, muted: string }} colors
 * @param {number} width - the canvas width
 * @param {number} y
 */
export function drawRoundDots(ctx, state, colors, width, y) {
  const rows = [
    [width / 2 - 20, state.roundWins1, colors.fg],
    [width / 2 + 40, state.roundWins2, colors.accent],
  ];
  for (const [left, wins, lit] of rows) {
    for (let i = 0; i < 3; i++) {
      ctx.beginPath();
      ctx.arc(left + i * 20, y, 3, 0, Math.PI * 2);
      ctx.fillStyle = i < wins ? lit : colors.muted;
      ctx.fill();
    }
  }
}

/**
 * Square particles, each in the colour and size `look` gives it and faded
 * by the alpha it says.
 * @param {CanvasRenderingContext2D} ctx
 * @param {Array<{ x: number, y: number }>} particles
 * @param {(p: object) => { alpha: number, color: string, size: number }} look
 */
export function drawSquareParticles(ctx, particles, look) {
  for (const p of particles) {
    const { alpha, color, size } = look(p);
    ctx.globalAlpha = alpha;
    ctx.fillStyle = color;
    ctx.fillRect(p.x - size / 2, p.y - size / 2, size, size);
  }
  ctx.globalAlpha = 1;
}

/**
 * A shot's trail: three fading dots behind it, four pixels apart, along the
 * direction (`nx`, `ny`) it flies, each smaller than the one before.
 * @param {CanvasRenderingContext2D} ctx
 * @param {number} x
 * @param {number} y
 * @param {number} nx - the unit direction it flies, across
 * @param {number} ny - and down
 * @param {number} radius - the shot's own
 * @param {string} color
 */
export function drawShotTrail(ctx, x, y, nx, ny, radius, color) {
  ctx.globalAlpha = 0.2;
  ctx.fillStyle = color;
  for (let i = 1; i <= 3; i++) {
    ctx.beginPath();
    ctx.arc(x - nx * i * 4, y - ny * i * 4, radius * (1 - i * 0.2), 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.globalAlpha = 1;
}

/**
 * A shot: a dot of `radius` in `color`, and a bright core half its size.
 * @param {CanvasRenderingContext2D} ctx
 * @param {number} x
 * @param {number} y
 * @param {number} radius
 * @param {string} color
 * @param {string} core
 */
export function drawShotDot(ctx, x, y, radius, color, core) {
  ctx.fillStyle = color;
  ctx.beginPath();
  ctx.arc(x, y, radius, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = core;
  ctx.beginPath();
  ctx.arc(x, y, radius * 0.5, 0, Math.PI * 2);
  ctx.fill();
}

/**
 * A small glowing label centred at the top, `y` down — the round being played.
 * @param {CanvasRenderingContext2D} ctx
 * @param {string} text
 * @param {string} color
 * @param {number} width - the canvas width
 * @param {number} y
 */
export function drawTopLabel(ctx, text, color, width, y) {
  ctx.shadowColor = color;
  ctx.shadowBlur = 4;
  ctx.fillStyle = color;
  ctx.font = "12px monospace";
  ctx.textAlign = "center";
  ctx.textBaseline = "top";
  ctx.fillText(text, width / 2, y);
}

/**
 * The page's colours the green-on-black sports games read first, each with
 * the colour it falls back to: a `readGameColors` table to spread into a
 * game's own.
 */
export const GREEN_ON_BLACK = Object.freeze({
  bg: ["--game-bg-color", "0a0a14"],
  fg: ["--game-fg-color", "39ff14"],
  accent: ["--game-accent-color", "00e5ff"],
  muted: ["--game-muted-color", "1a1a2a"],
  glow: ["--game-glow-color", "rgba(57,255,20,0.15)"],
});
