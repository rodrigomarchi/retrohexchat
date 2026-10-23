/**
 * Canvas pieces every game's renderer draws the same way: the background,
 * the CRT scanlines, the pulsing countdown and the waiting message.
 * Each takes the canvas size, since the games draw at different sizes.
 * @module games/hud
 */

import { t, jt } from "../i18n.js";

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
