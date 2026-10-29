/**
 * Light Trails' sounds, as data the core's synthesizer plays.
 * @module games/surround/sounds
 */

import { LOSE_SWEEP, WIN_FANFARE, blip, notes, sweep } from "../core/synth.js";

export const SOUNDS = {
  /** A turn: 200 Hz square, 15 ms, very quiet. */
  move: blip("square", 200, 0.015, 0.05),
  /** Into a trail or wall: falling 800 → 50 Hz sawtooth, 500 ms. */
  crash: sweep("sawtooth", 800, 50, 0.5, 0.3),
  /** 600 Hz square blip, 80 ms. */
  countdown: blip("square", 600, 0.08, 0.12),
  /** Rising C5-G5. */
  roundWin: notes([523, 784], { wave: "square", note: 0.1, vol: 0.12 }),
  /** Rising C5-E5-G5-C6-E6. */
  matchWin: WIN_FANFARE,
  /** Falling 500 → 150 Hz sawtooth, 700 ms. */
  matchLose: LOSE_SWEEP,
};
