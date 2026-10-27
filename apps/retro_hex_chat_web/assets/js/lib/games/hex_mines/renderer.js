/**
 * Hex Mines' picture: the bar with the mines left, the face and the time (and
 * on a phone the dig/flag switch), the board's squares cut from the atlas,
 * and what moves over them. No words: the atlas's digits and pictures, so
 * nothing here is translated.
 *
 * @module games/hex_mines/renderer
 */

import { readGameColors } from "../../game_colors.js";
import { drawPiece as piece } from "../core/atlas.js";
import { drawParticleDots } from "../core/render.js";
import { glowAt, hopAt, shakeAt, waiting } from "./effects.js";
import { boardPlace } from "./layout.js";
import { CELL, countAround, flagsLeft } from "./rules.js";

/** The board's colours, from the canvas's custom properties. */
export function readColors(canvas) {
  return readGameColors(canvas, {
    back: ["--game-mines-back-color", "08786c"],
    bar: ["--game-mines-bar-color", "066358"],
    frame: ["--game-mines-frame-color", "023e3e"],
    glow: ["--game-mines-glow-color", "rgba(255,230,120,0.55)"],
    closed: ["--game-mines-closed-color", "ccced4"],
    open: ["--game-mines-open-color", "bdbfc5"],
  });
}

/** Three lit digits, a minus first below zero, as the counter and the clock show them. */
function digits(ctx, atlas, value, place, colors) {
  const clamped = Math.max(-99, Math.min(999, value));
  const text =
    clamped < 0 ? `-${String(-clamped).padStart(2, "0")}` : String(clamped).padStart(3, "0");
  const w = Math.floor(place.w / 3);
  [...text].forEach((char, k) => {
    const name = char === "-" ? "digit_minus" : `digit_${char}`;
    piece(ctx, atlas, name, { x: place.x + k * w, y: place.y, w: w - 1, h: place.h }, colors.frame);
  });
}

/** What a square shows: shut, flagged, open with its count, or — the match over — its mine. */
function squareOf(state, i, pressed) {
  const { board } = state;
  const c = board.cell[i];
  if (state.lost && board.mine[i]) {
    if (i === board.boom) return "boom";
    return c === CELL.FLAG ? "flag" : "mine";
  }
  if (state.lost && c === CELL.FLAG) return "wrong";
  if (c === CELL.FLAG) return "flag";
  if (c === CELL.OPEN) {
    const n = countAround(board, i);
    return n ? `n${n}` : "open";
  }
  return i === pressed ? "pressed" : "closed";
}

const faceOf = (state, pressed) => {
  if (state.lost) return "face_dead";
  if (state.won) return "face_cool";
  return pressed === null ? "face_smile" : "face_wow";
};

/**
 * The whole picture.
 * @param {CanvasRenderingContext2D} ctx
 * @param {{ state: object, laid: object, fx: object, atlas: object | null, colors: object,
 *   now: number, pressed: number | null }} scene - `pressed`, the square under a press
 */
export function render(ctx, { state, laid, fx, atlas, colors, now, pressed }) {
  const { view, board: area } = laid;
  ctx.fillStyle = colors.back;
  ctx.fillRect(0, 0, view.width, view.height);
  ctx.fillStyle = colors.bar;
  ctx.fillRect(laid.bar.x, laid.bar.y, laid.bar.w, laid.bar.h);

  digits(ctx, atlas, flagsLeft(state.board), laid.counter, colors);
  piece(ctx, atlas, faceOf(state, pressed), laid.face, colors.closed);
  digits(ctx, atlas, Math.floor(state.clock.ticks / 60), laid.clock, colors);
  if (laid.mode) piece(ctx, atlas, state.mode === "dig" ? "dig" : "mark", laid.mode, colors.closed);

  const dx = shakeAt(fx, now);
  ctx.fillStyle = colors.frame;
  ctx.fillRect(area.x - 2 + dx, area.y - 2, area.w + 4, area.h + 4);
  state.board.cell.forEach((c, i) => {
    const at = boardPlace(laid, i);
    const shut = waiting(fx, i, now);
    const name = shut ? "closed" : squareOf(state, i, pressed);
    const lift = name === "flag" ? hopAt(fx, i, now) : 0;
    if (lift) piece(ctx, atlas, "closed", { ...at, x: at.x + dx }, colors.closed);
    piece(ctx, atlas, name, { ...at, x: at.x + dx, y: at.y + lift }, colors.closed);
    const glow = name === "flag" ? glowAt(fx, i, now) : 0;
    if (glow > 0) {
      ctx.globalAlpha = glow;
      ctx.fillStyle = colors.glow;
      ctx.fillRect(at.x + dx, at.y, at.w, at.h);
      ctx.globalAlpha = 1;
    }
  });

  for (const effect of fx.list) {
    if (effect.kind === "fire") drawParticleDots(ctx, effect.particles);
  }
}
