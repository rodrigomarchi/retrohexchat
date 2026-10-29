/**
 * Pixel Tanks' sounds, as data the core's synthesizer plays.
 * @module games/pixel_tanks/sounds
 */

import { LOSE_SWEEP, WIN_FANFARE, blip, notes, sweep } from "../core/synth.js";

export const SOUNDS = {
  /** A heavy blast: falling 400 → 100 Hz sawtooth, 150 ms. */
  fire: sweep("sawtooth", 400, 100, 0.15, 0.15),
  /** An explosion: falling 300 → 60 Hz sawtooth, 300 ms. */
  hit: sweep("sawtooth", 300, 60, 0.3, 0.2),
  /** A bright ping: 2000 Hz sine, 50 ms. */
  ricochet: blip("sine", 2000, 0.05, 0.12),
  /** 600 Hz square blip, 80 ms. */
  countdown: blip("square", 600, 0.08, 0.12),
  /** Charging: rising 200 → 800 Hz sine, 150 ms. */
  spawn: sweep("sine", 200, 800, 0.15, 0.1),
  /** A subtle click in the last 15 s: 800 Hz square, 30 ms. */
  timerTick: blip("square", 800, 0.03, 0.06),
  /** A three-note fanfare: A4-C♯5-E5. */
  roundEnd: notes([440, 554, 659], { wave: "square", note: 0.15, vol: 0.1 }),
  /** Rising C5-E5-G5-C6-E6. */
  win: WIN_FANFARE,
  /** Falling 500 → 150 Hz sawtooth, 700 ms. */
  lose: LOSE_SWEEP,
};
