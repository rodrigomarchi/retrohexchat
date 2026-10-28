/**
 * Hex Blocks' picture: the well with its gems, the piece falling and its
 * shadow; the piece held (dim when it may not be swapped again) and the
 * pieces coming; the counts in lit digits (the level pulsing as it goes up,
 * the well's frame tinted by it) — the Marathon's score, level and
 * rows, the Sprint's time and the rows still to clear; the count before the
 * first piece; and what moves
 * over them. No words: the atlas's digits and pictures, so nothing here is
 * translated.
 *
 * @module games/hex_blocks/renderer
 */

import { gameColor, readGameColors } from "../../game_colors.js";
import { drawLed, drawPiece as piece } from "../core/atlas.js";
import { drawParticleDots } from "../core/render.js";
import { PHASE } from "../core/solo/phases.js";
import { blinkAt, fadeAt, flashAt, levelAt, settleAt, shakeAt, trailAt } from "./effects.js";
import { toOffset } from "./hex.js";
import { cellPlace } from "./layout.js";
import { PIECES, shape } from "./pieces.js";
import { COLS, HIDDEN, ROWS } from "./protocol.js";
import { cellsOf, landing } from "./rules.js";

/** The table's colours, from the canvas's custom properties. */
export function readColors(canvas) {
  return readGameColors(canvas, {
    back: ["--game-blocks-back-color", "0e101c"],
    panel: ["--game-blocks-panel-color", "181b2c"],
    edge: ["--game-blocks-edge-color", "3c4260"],
    well: ["--game-blocks-well-color", "0a0b14"],
    gem: ["--game-blocks-gem-color", "8aa0ff"],
    trail: ["--game-blocks-trail-color", "rgba(220,228,255,0.35)"],
    led: ["--game-blocks-led-color", "0c0606"],
    pulse: ["--game-blocks-pulse-color", "ffe45a"],
  });
}

/** The well's frame takes another tint with each level, five in turn; the first is the theme's. */
const TINTS = ["5a3c60", "3c5a60", "60503c", "3c6048"];
const edgeOf = (level, colors) =>
  (level - 1) % 5 === 0 ? colors.edge : gameColor(TINTS[((level - 1) % 5) - 1]);

const gemOf = (kind) => `gem_${PIECES[kind].colour}`;

/** Lit digits at the size the atlas draws them. */
const led = (ctx, atlas, text, place, colors) =>
  drawLed(ctx, atlas, text, place, colors.led, { digit: 11, colon: 5 });

/** A Sprint's time: minutes, seconds and tenths. */
function timeText(ticks) {
  const tenths = Math.floor(ticks / 6);
  const seconds = Math.floor(tenths / 10);
  const pad = (n) => String(n).padStart(2, "0");
  return `${pad(Math.min(99, Math.floor(seconds / 60)))}:${pad(seconds % 60)}.${tenths % 10}`;
}

function box(ctx, r, colors) {
  ctx.fillStyle = colors.edge;
  ctx.fillRect(r.x - 1, r.y - 1, r.w + 2, r.h + 2);
  ctx.fillStyle = colors.panel;
  ctx.fillRect(r.x, r.y, r.w, r.h);
}

/** A piece of `kind` at a size of its own, in the middle of `slot`. */
function drawMini(ctx, atlas, kind, slot, scale, colors, alpha = 1) {
  const cells = shape(kind, 0).map((cell) => toOffset(cell));
  const w = 24 * scale;
  const h = 20 * scale;
  const at = cells.map(([c, r]) => [c * 18 * scale, r * h + (c & 1 ? h / 2 : 0)]);
  const xs = at.map(([x]) => x);
  const ys = at.map(([, y]) => y);
  const left = Math.min(...xs);
  const top = Math.min(...ys);
  const ox = Math.round(slot.x + (slot.w - (Math.max(...xs) + w - left)) / 2 - left);
  const oy = Math.round(slot.y + (slot.h - (Math.max(...ys) + h - top)) / 2 - top);
  ctx.globalAlpha = alpha;
  for (const [x, y] of at) {
    piece(ctx, atlas, gemOf(kind), { x: ox + x, y: oy + y, w, h }, colors.gem);
  }
  ctx.globalAlpha = 1;
}

/** The squares of the well in sight, each drawn by `draw(c, r, place)`. */
function eachInSight(laid, draw) {
  for (let r = HIDDEN; r < ROWS; r++) {
    for (let c = 0; c < COLS; c++) draw(c, r, cellPlace(laid, c, r));
  }
}

function drawWell(ctx, { state, laid, fx, atlas, colors, now }) {
  const { well } = laid;
  const dx = shakeAt(fx, now, { amplitude: 2 });
  ctx.fillStyle = edgeOf(state.level, colors);
  ctx.fillRect(well.x - 5 + dx, well.y - 5, well.w + 10, well.h + 10);
  ctx.fillStyle = colors.well;
  ctx.fillRect(well.x - 4 + dx, well.y - 4, well.w + 8, well.h + 8);
  const shifted = (r, at) => ({ ...at, x: at.x + dx, y: at.y - settleAt(fx, r, now) * at.h });
  eachInSight(laid, (c, r, at) => piece(ctx, atlas, "empty", { ...at, x: at.x + dx }, colors.well));
  eachInSight(laid, (c, r, at) => {
    const cell = state.well.cells[r * COLS + c];
    if (cell) piece(ctx, atlas, gemOf(cell - 1), shifted(r, at), colors.gem);
  });
  const trail = trailAt(fx, now);
  if (trail) {
    ctx.globalAlpha = trail.glow;
    ctx.fillStyle = colors.trail;
    for (const [c, r] of trail.cells) {
      for (let k = 0; k < trail.rows; k++) {
        if (r + k < HIDDEN) continue;
        const at = cellPlace(laid, c, r + k);
        ctx.fillRect(at.x + dx + 8, at.y, at.w - 16, at.h);
      }
    }
    ctx.globalAlpha = 1;
  }
  const { piece: falling } = state;
  const each = (cells, name, fallback) => {
    for (const [c, r] of cells) {
      if (r < HIDDEN) continue;
      const at = cellPlace(laid, c, r);
      piece(ctx, atlas, name, { ...at, x: at.x + dx }, fallback);
    }
  };
  if (falling && state.phase === PHASE.PLAYING) {
    each(cellsOf(landing(state.well, falling)), "ghost", colors.well);
    each(cellsOf(falling), gemOf(falling.kind), colors.gem);
  }
  const lit = (cells, glow) => {
    ctx.globalAlpha = glow;
    for (const [c, r] of cells) {
      if (r >= HIDDEN) piece(ctx, atlas, "flash", cellPlace(laid, c, r), colors.gem);
    }
    ctx.globalAlpha = 1;
  };
  const blink = blinkAt(fx, now);
  if (blink) lit(blink.cells, blink.glow * 0.7);
  const flash = flashAt(fx, now);
  if (flash) {
    lit(
      flash.rows.flatMap((r) => Array.from({ length: COLS }, (_, c) => [c, r])),
      flash.glow,
    );
  }
}

/** At the end, the well dark from the bottom up. */
function drawDark(ctx, { state, laid, fx, colors, now }) {
  if (!state.over) return;
  const fading = fx.list.some((e) => e.kind === "fade");
  const dark = fading ? fadeAt(fx, now) : 1;
  const { well } = laid;
  const h = Math.round(well.h * dark);
  ctx.globalAlpha = 0.6;
  ctx.fillStyle = colors.well;
  ctx.fillRect(well.x, well.y + well.h - h, well.w, h);
  ctx.globalAlpha = 1;
}

function drawSide(ctx, { state, laid, fx, atlas, colors, now }) {
  box(ctx, laid.hold, colors);
  if (state.held !== null) {
    drawMini(ctx, atlas, state.held, laid.hold, laid.mini, colors, state.canHold ? 1 : 0.4);
  } else {
    // Nothing kept yet: the keep mark, faint, says what the box is for.
    const { x, y, w, h } = laid.hold;
    ctx.globalAlpha = 0.3;
    piece(
      ctx,
      atlas,
      "keep",
      { x: x + (w - 24) / 2, y: y + (h - 24) / 2, w: 24, h: 24 },
      colors.panel,
    );
    ctx.globalAlpha = 1;
  }
  box(ctx, laid.next, colors);
  laid.slots.forEach((slot, n) => drawMini(ctx, atlas, state.queue[n], slot, laid.mini, colors));
  box(ctx, laid.stats, colors);
  const { score, level, lines } = laid.counts;
  if (state.mode.sprint) {
    led(ctx, atlas, timeText(state.clock.ticks), score, colors);
    piece(ctx, atlas, "lines", lines.mark, colors.panel);
    led(
      ctx,
      atlas,
      String(Math.max(0, state.mode.goal - state.lines)).padStart(2, "0"),
      lines.digits,
      colors,
    );
  } else {
    led(ctx, atlas, String(Math.min(state.score, 9_999_999)).padStart(7, "0"), score, colors);
    const glow = levelAt(fx, now);
    if (glow > 0) {
      const { digits } = level;
      ctx.globalAlpha = glow;
      ctx.fillStyle = colors.pulse;
      ctx.fillRect(digits.x - 2, digits.y - 2, digits.w + 4, digits.h + 4);
      ctx.globalAlpha = 1;
    }
    piece(ctx, atlas, "level", level.mark, colors.panel);
    led(ctx, atlas, String(state.level).padStart(2, "0"), level.digits, colors);
    piece(ctx, atlas, "lines", lines.mark, colors.panel);
    led(ctx, atlas, String(Math.min(state.lines, 999)).padStart(3, "0"), lines.digits, colors);
  }
}

/** The count before the first piece: its second, big, over the well. */
function drawCount(ctx, { state, laid, atlas, colors }) {
  if (state.piece || state.phase !== PHASE.PLAYING || state.countdown <= 0) return;
  const second = Math.ceil(state.countdown / 60);
  const w = 33;
  const h = 51;
  const { well } = laid;
  piece(
    ctx,
    atlas,
    `digit_${second}`,
    { x: Math.round(well.x + (well.w - w) / 2), y: Math.round(well.y + (well.h - h) / 2), w, h },
    colors.led,
  );
}

/**
 * The whole picture.
 * @param {CanvasRenderingContext2D} ctx
 * @param {{ state: object, laid: object, fx: object, atlas: object | null, colors: object,
 *   now: number }} scene
 */
export function render(ctx, sceneOf) {
  const { laid, fx, colors } = sceneOf;
  ctx.fillStyle = colors.back;
  ctx.fillRect(0, 0, laid.view.width, laid.view.height);
  drawWell(ctx, sceneOf);
  drawDark(ctx, sceneOf);
  drawSide(ctx, sceneOf);
  drawCount(ctx, sceneOf);
  for (const effect of fx.list) {
    if (effect.particles) drawParticleDots(ctx, effect.particles);
  }
}
