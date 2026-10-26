/**
 * Hex Warlords' sounds, as data the core's synthesizer plays.
 * @module games/warlords/sounds
 */

import { blip, notes, sweep } from "../core/synth.js";

export const SOUNDS = {
  /** A crisp break: 800 Hz triangle, 40 ms. */
  brickHit: blip("triangle", 800, 0.04, 0.12),
  /** A metallic ping: 1200 Hz sine, 30 ms. */
  shieldDeflect: blip("sine", 1200, 0.03, 0.15),
  /** An explosion: falling 200 → 50 Hz sawtooth, 500 ms. */
  kingHit: sweep("sawtooth", 200, 50, 0.5, 0.2),
  /** Charging: rising 400 → 800 Hz sine, 200 ms. */
  catch: sweep("sine", 400, 800, 0.2, 0.12),
  /** A whoosh: falling 800 → 400 Hz sine, 150 ms. */
  launch: sweep("sine", 800, 400, 0.15, 0.12),
  /** 300 Hz square, 30 ms. */
  wallBounce: blip("square", 300, 0.03, 0.1),
  /** 600 Hz square blip, 80 ms. */
  // ex_dna:disable-for-lines:6 this game's own sound table
  countdown: blip("square", 600, 0.08, 0.12),
  /** Rising C5-E5-G5-C6-E6. */
  win: notes([523, 659, 784, 1047, 1319], { wave: "square", note: 0.12, vol: 0.12 }),
  /** Falling 500 → 150 Hz sawtooth, 700 ms. */
  lose: sweep("sawtooth", 500, 150, 0.7, 0.1),
};
