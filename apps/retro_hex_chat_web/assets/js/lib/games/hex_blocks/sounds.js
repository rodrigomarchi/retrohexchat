/**
 * Hex Blocks' sounds, as data the core's synthesizer plays: soft ticks for
 * a move and a turn, a thud for a piece locking, a swoop for a drop, a run
 * up for rows cleared (higher for four), a fanfare for a level, the count's
 * beeps, and the end's — one for each `EVENT`, by name.
 *
 * @module games/hex_blocks/sounds
 */

import { fade, glide, notes } from "../core/synth.js";

export const MASTER_VOLUME = 0.25;

export const SOUNDS = {
  /** A step sideways: a dry tick. */
  move: { wave: "square", freq: 880, vol: fade(0.025, 0.025, "exp"), dur: 0.025 },
  /** A turn: a lighter, higher tick. */
  turn: { wave: "triangle", freq: 1320, vol: fade(0.05, 0.04, "exp"), dur: 0.04 },
  /** A piece set in the well: a low thud. */
  lock: { wave: "triangle", freq: glide(220, 120, 0.06), vol: fade(0.1, 0.07, "exp"), dur: 0.07 },
  /** A drop: a swoop down. */
  drop: { wave: "square", freq: glide(900, 200, 0.08), vol: fade(0.05, 0.08, "exp"), dur: 0.08 },
  /** Rows cleared: a short run up. */
  line: notes([523, 659, 784], {
    wave: "square",
    note: 0.05,
    vol: 0.07,
    gap: -0.01,
    fadeKind: "exp",
  }),
  /** Four rows at once: the run up, an octave higher, and on to the top. */
  quad: notes([784, 988, 1175, 1568], {
    wave: "square",
    note: 0.06,
    vol: 0.08,
    gap: -0.01,
    fadeKind: "exp",
  }),
  /** A level up: a bright little fanfare. */
  level: notes([659, 784, 1046], { wave: "triangle", note: 0.09, vol: 0.09, gap: -0.02 }),
  /** A piece put aside: a soft blip. */
  hold: { wave: "triangle", freq: glide(500, 750, 0.05), vol: fade(0.06, 0.05, "exp"), dur: 0.05 },
  /** The Sprint run: a fanfare, up, a step back, and up to the top. */
  // ex_dna:disable-for-lines:7 this game's own sound table
  win: notes([392, 523, 659, 784, 659, 1046], {
    wave: "square",
    note: 0.14,
    vol: 0.09,
    gap: -0.03,
  }),
  /** The stack over the top: a slide down. */
  over: notes([392, 330, 262, 196], { wave: "triangle", note: 0.16, vol: 0.08, gap: -0.02 }),
  /** A second of the count. */
  count: { wave: "square", freq: 660, vol: fade(0.06, 0.08, "exp"), dur: 0.08 },
  /** The count over: the first piece. */
  go: { wave: "square", freq: 1320, vol: fade(0.07, 0.16, "exp"), dur: 0.16 },
};
