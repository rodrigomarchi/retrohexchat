/**
 * Hex Sudoku's sounds, as data the core's synthesizer plays: soft 8-bit
 * ticks for a digit, a note and the pencil, a low buzz for a mistake, a
 * short run up for a completed row, column or box, a chime for a hint, and a
 * fanfare for a win — one for each `EVENT`, by name.
 *
 * @module games/hex_sudoku/sounds
 */

import { fade, glide, notes } from "../core/synth.js";

export const MASTER_VOLUME = 0.25;

export const SOUNDS = {
  /** A digit put: a dry click. */
  place: { wave: "triangle", freq: 520, vol: fade(0.09, 0.05, "exp"), dur: 0.05 },
  /** A note pencilled: a lighter tick. */
  note: { wave: "square", freq: 1200, vol: fade(0.03, 0.03, "exp"), dur: 0.03 },
  /** A square erased: a quick slide down. */
  erase: { wave: "square", freq: glide(600, 300, 0.05), vol: fade(0.04, 0.05, "exp"), dur: 0.05 },
  /** A wrong digit: a low buzz. */
  mistake: [
    { wave: "square", freq: 110, vol: fade(0.08, 0.18, "exp"), dur: 0.18 },
    { wave: "square", freq: 104, vol: fade(0.06, 0.18, "exp"), dur: 0.18 },
  ],
  /** A row, column or box done: a short run up. */
  complete: notes([660, 784, 988], {
    wave: "square",
    note: 0.06,
    vol: 0.06,
    gap: -0.01,
    fadeKind: "exp",
  }),
  /** A hint: a chime. */
  hint: [
    { wave: "triangle", freq: 1318, vol: fade(0.08, 0.3, "exp"), dur: 0.3 },
    { wave: "triangle", freq: 1976, vol: fade(0.04, 0.3, "exp"), dur: 0.3, delay: 0.05 },
  ],
  /** An undo: a slide back up. */
  undo: { wave: "triangle", freq: glide(300, 600, 0.06), vol: fade(0.06, 0.06, "exp"), dur: 0.06 },
  /** The pencil switched. */
  pencil: { wave: "square", freq: 880, vol: fade(0.03, 0.03, "exp"), dur: 0.03 },
  /** The grid solved: a fanfare, up, a step back, and up to the top. */
  win: notes([392, 523, 659, 784, 659, 1046], {
    wave: "square",
    note: 0.14,
    vol: 0.09,
    gap: -0.03,
  }),
};
