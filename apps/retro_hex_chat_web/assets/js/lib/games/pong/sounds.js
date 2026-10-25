/**
 * Hex Pong's sounds, as data the core's synthesizer plays.
 * @module games/pong/sounds
 */

import { blip, notes, sweep } from "../core/synth.js";

export const SOUNDS = {
  /** 800 Hz sawtooth, 60 ms. */
  paddleHit: blip("sawtooth", 800, 0.06, 0.15),
  /** 400 Hz square, 40 ms. */
  wallBounce: blip("square", 400, 0.04, 0.1),
  /** Falling 300 → 100 Hz sawtooth, 300 ms. */
  score: sweep("sawtooth", 300, 100, 0.3, 0.15),
  /** Rising arpeggio, 400 → 1000 Hz square. */
  win: notes([400, 600, 800, 1000], { wave: "square", note: 0.12, vol: 0.12 }),
  /** The win fanfare falling, 600 → 200 Hz. */
  lose: notes([600, 450, 300, 200], { wave: "square", note: 0.12, vol: 0.12 }),
  /** 600 Hz square blip, 80 ms. */
  countdown: blip("square", 600, 0.08, 0.12),
};
