/**
 * Light Trails' sounds, as data the core's synthesizer plays.
 * @module games/surround/sounds
 */

import { fade, glide, notes } from "../core/synth.js";

const blip = (wave, freq, dur, vol) => ({ wave, freq, vol: fade(vol, dur), dur });
const sweep = (from, to, dur, vol) => ({
  wave: "sawtooth",
  freq: glide(from, to, dur),
  vol: fade(vol, dur),
  dur,
});

export const SOUNDS = {
  /** A turn: 200 Hz square, 15 ms, very quiet. */
  move: blip("square", 200, 0.015, 0.05),
  /** Into a trail or wall: falling 800 → 50 Hz sawtooth, 500 ms. */
  crash: sweep(800, 50, 0.5, 0.3),
  /** 600 Hz square blip, 80 ms. */
  countdown: blip("square", 600, 0.08, 0.12),
  /** Rising C5-G5. */
  roundWin: notes([523, 784], { wave: "square", note: 0.1, vol: 0.12 }),
  /** Rising C5-E5-G5-C6-E6. */
  matchWin: notes([523, 659, 784, 1047, 1319], { wave: "square", note: 0.12, vol: 0.12 }),
  /** Falling 500 → 150 Hz sawtooth, 700 ms. */
  matchLose: sweep(500, 150, 0.7, 0.1),
};
