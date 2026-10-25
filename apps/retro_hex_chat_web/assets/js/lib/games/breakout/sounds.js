/**
 * Block Breakers' sounds, as data the core's synthesizer plays.
 * @module games/breakout/sounds
 */

import { blip, notes, sweep } from "../core/synth.js";

export const SOUNDS = {
  /** 600 Hz triangle, 50 ms. */
  paddleHit: blip("triangle", 600, 0.05, 0.15),
  /** 300 Hz square, 30 ms. */
  wallBounce: blip("square", 300, 0.03, 0.1),
  /** Higher for higher rows: row 0 at 1200 Hz down to row 4 at 800 Hz. */
  blockHit: (row) => blip("sawtooth", 800 + (4 - row) * 100, 0.04, 0.12),
  /** Falling 400 → 100 Hz sawtooth, 400 ms. */
  lifeLost: sweep("sawtooth", 400, 100, 0.4, 0.15),
  /** 600 Hz square blip, 80 ms. */
  countdown: blip("square", 600, 0.08, 0.12),
  /** Rising C5-E5-G5-C6. */
  win: notes([523, 659, 784, 1047], { wave: "square", note: 0.15, vol: 0.12 }),
  /** Falling 500 → 200 Hz sawtooth, 600 ms. */
  lose: sweep("sawtooth", 500, 200, 0.6, 0.1),
};
