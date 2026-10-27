/**
 * Hex Sudoku's picture: the bar with the mistakes, the clock and the hints;
 * the grid with its highlights (the chosen square, its row, column and box,
 * and every square showing its digit), digits and notes; the keypad, a key
 * spent once its digit is all placed; the tools, the pencil held down while
 * it is on; and what moves over them. No words: the atlas's digits and
 * pictures, so nothing here is translated.
 *
 * @module games/hex_sudoku/renderer
 */

import { readGameColors } from "../../game_colors.js";
import { drawPiece as piece } from "../core/atlas.js";
import { drawParticleDots } from "../core/render.js";
import { glowAt, hopAt, shakeAt } from "./effects.js";
import { digitsOf, sees } from "./grid.js";
import { squarePlace } from "./layout.js";
import { isWrong, left } from "./rules.js";

/** The grid's colours, from the canvas's custom properties. */
export function readColors(canvas) {
  return readGameColors(canvas, {
    back: ["--game-sudoku-back-color", "08786c"],
    bar: ["--game-sudoku-bar-color", "066358"],
    frame: ["--game-sudoku-frame-color", "023e3e"],
    paper: ["--game-sudoku-paper-color", "fafaf6"],
    thin: ["--game-sudoku-thin-color", "b0b2bc"],
    thick: ["--game-sudoku-thick-color", "24262e"],
    chosen: ["--game-sudoku-chosen-color", "ffe26e"],
    peer: ["--game-sudoku-peer-color", "dee8f8"],
    same: ["--game-sudoku-same-color", "b8cefa"],
    wrong: ["--game-sudoku-wrong-color", "ffd6d6"],
    glow: ["--game-sudoku-glow-color", "rgba(255,230,120,0.6)"],
    key: ["--game-sudoku-key-color", "ccced4"],
  });
}

/** Lit digits and colons, one cell each, as the bar shows its counts. */
function led(ctx, atlas, text, place, colors) {
  const cell = 22;
  let x = place.x;
  for (const char of text) {
    const w = char === ":" ? 10 : cell - 1;
    piece(ctx, atlas, char === ":" ? "colon" : `digit_${char}`, { ...place, x, w }, colors.frame);
    x += w + 1;
  }
}

/** The clock as minutes and seconds; past 99 minutes, three digits of minutes. */
function clockText(ticks) {
  const seconds = Math.floor(ticks / 60);
  const pad = (n) => String(n).padStart(2, "0");
  return `${pad(Math.floor(seconds / 60))}:${pad(seconds % 60)}`;
}

const count = (n) => String(Math.min(n, 99)).padStart(2, "0");

function drawBar(ctx, { state, laid, atlas, colors }) {
  const { bar } = laid;
  ctx.fillStyle = colors.bar;
  ctx.fillRect(bar.x, bar.y, bar.w, bar.h);
  piece(ctx, atlas, "cross", bar.mistakes.mark, colors.bar);
  led(ctx, atlas, count(state.mistakes), bar.mistakes.digits, colors);
  led(ctx, atlas, clockText(state.clock.ticks), bar.clock, colors);
  piece(ctx, atlas, "lamp", bar.hints.mark, colors.bar);
  led(ctx, atlas, count(state.hints), bar.hints.digits, colors);
}

/** A square's background: chosen, wrong, showing the chosen digit, in the chosen one's lines, or plain. */
function squareColor(board, i, selected, colors) {
  if (i === selected) return colors.chosen;
  if (!board) return colors.paper;
  if (isWrong(board, i)) return colors.wrong;
  if (selected === null) return colors.paper;
  const digit = board.values[selected];
  if (digit && board.values[i] === digit) return colors.same;
  return sees(i, selected) ? colors.peer : colors.paper;
}

/** The ink of a square's digit: given, hinted, wrong or the player's. */
function inkOf(board, i) {
  if (board.given[i]) return "given";
  if (board.hinted[i]) return "hint";
  return isWrong(board, i) ? "wrong" : "mine";
}

/** The grid's lines: thin between squares, thick between boxes and round the edge. */
function drawLines(ctx, { grid, cell }, colors) {
  for (let k = 0; k <= 9; k++) {
    const thick = k % 3 === 0;
    const w = thick ? 2 : 0.5;
    const at = k * cell - (thick ? 1 : 0);
    ctx.fillStyle = thick ? colors.thick : colors.thin;
    ctx.fillRect(grid.x + at, grid.y - 1, w, grid.h + 2);
    ctx.fillRect(grid.x - 1, grid.y + at, grid.w + 2, w);
  }
}

function drawGrid(ctx, { state, laid, fx, atlas, colors, now }) {
  const { board, selected } = state;
  const { grid } = laid;
  ctx.fillStyle = colors.frame;
  ctx.fillRect(grid.x - 4, grid.y - 4, grid.w + 8, grid.h + 8);
  for (let i = 0; i < 81; i++) {
    const at = squarePlace(laid, i);
    ctx.fillStyle = squareColor(board, i, selected, colors);
    ctx.fillRect(at.x, at.y, at.w, at.h);
    const glow = glowAt(fx, i, now);
    if (glow > 0) {
      ctx.globalAlpha = glow;
      ctx.fillStyle = colors.glow;
      ctx.fillRect(at.x, at.y, at.w, at.h);
      ctx.globalAlpha = 1;
    }
  }
  drawLines(ctx, laid, colors);
  if (!board) return;
  for (let i = 0; i < 81; i++) {
    const at = squarePlace(laid, i);
    const d = board.values[i];
    if (d) {
      const moved = {
        ...at,
        x: at.x + shakeAt(fx, now, { i, amplitude: 3 }),
        y: at.y + hopAt(fx, i, now),
      };
      piece(ctx, atlas, `${inkOf(board, i)}_${d}`, moved, colors.paper);
    } else {
      for (const n of digitsOf(board.notes[i])) piece(ctx, atlas, `note_${n}`, at, colors.paper);
    }
  }
}

function drawKeys(ctx, { state, laid, atlas, colors }) {
  laid.keys.forEach((r, n) => {
    const spent = state.board && left(state.board, n + 1) === 0;
    piece(ctx, atlas, `${spent ? "spent" : "key"}_${n + 1}`, r, colors.key);
  });
  for (const [name, r] of Object.entries(laid.tools)) {
    const art = name === "hint" ? "bulb" : name === "pencil" && state.pencil ? "pencil_on" : name;
    piece(ctx, atlas, art, r, colors.key);
  }
}

/**
 * The whole picture.
 * @param {CanvasRenderingContext2D} ctx
 * @param {{ state: object, laid: object, fx: object, atlas: object | null, colors: object,
 *   now: number }} scene
 */
export function render(ctx, scene) {
  const { laid, fx, colors } = scene;
  ctx.fillStyle = colors.back;
  ctx.fillRect(0, 0, laid.view.width, laid.view.height);
  drawBar(ctx, scene);
  drawGrid(ctx, scene);
  drawKeys(ctx, scene);
  for (const effect of fx.list) {
    if (effect.particles) drawParticleDots(ctx, effect.particles);
  }
}
