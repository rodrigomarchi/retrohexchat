/**
 * Hex Mines' sounds, as data the core's synthesizer plays: short 8-bit
 * clicks, a falling arpeggio for a flood, a thud for a flag, a burst of
 * noise for a mine, and a fanfare for a win — one for each `EVENT`, by name.
 *
 * @module games/hex_mines/sounds
 */

import { fade, glide, notes } from "../core/synth.js";

export const MASTER_VOLUME = 0.25;

export const SOUNDS = {
  /** A square opened: a dry click. */
  open: { wave: "triangle", freq: 420, vol: fade(0.09, 0.04, "exp"), dur: 0.04 },
  /** A field opened at once: a quick run of notes down. */
  flood: notes([880, 740, 660, 554, 440], {
    wave: "square",
    note: 0.05,
    vol: 0.05,
    gap: -0.02,
    fadeKind: "exp",
  }),
  /** A flag planted: a low knock and a flick. */
  flag: [
    { wave: "triangle", freq: 160, vol: fade(0.1, 0.06, "exp"), dur: 0.06 },
    { wave: "square", freq: 990, vol: fade(0.04, 0.04, "exp"), dur: 0.04, delay: 0.03 },
  ],
  /** A flag taken back. */
  unflag: { wave: "square", freq: glide(700, 400, 0.05), vol: fade(0.05, 0.05, "exp"), dur: 0.05 },
  /** A mine going off: noise and a falling growl. */
  boom: [
    { wave: "noise", vol: fade(0.22, 0.5, "exp"), dur: 0.5 },
    { wave: "square", freq: glide(160, 40, 0.45), vol: fade(0.12, 0.45, "exp"), dur: 0.45 },
  ],
  /** The board cleared: a fanfare climbing up. */
  win: notes([523, 659, 784, 1046, 1318, 1568], {
    wave: "square",
    note: 0.12,
    vol: 0.1,
    gap: -0.02,
    fadeKind: "exp",
  }),
};
