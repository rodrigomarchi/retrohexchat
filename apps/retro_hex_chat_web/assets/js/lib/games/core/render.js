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
 * One step of particles: each moves by its velocity, slows by `drag` and
 * loses `fade` of its life; the spent ones are dropped.
 * @param {Array<{ x: number, y: number, vx: number, vy: number, life: number }>} particles
 * @param {{ drag: number, fade: number }} options
 */
export function stepParticles(particles, { drag, fade }) {
  return particles
    .map((p) => ({
      ...p,
      x: p.x + p.vx,
      y: p.y + p.vy,
      vx: p.vx * drag,
      vy: p.vy * drag,
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
