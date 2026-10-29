/**
 * Hex Raid's sounds, as data the core's synthesizer plays.
 * @module games/hex_raid/sounds
 */

import { LOSE_SWEEP, WIN_FANFARE, blip, notes, sweep } from "../core/synth.js";

export const SOUNDS = {
  /** River Raid's pew: falling 1200 → 800 Hz sine, 60 ms. */
  fire: sweep("sine", 1200, 800, 0.06, 0.12),
  /** A quick explosion: falling 400 → 80 Hz sawtooth, 150 ms. */
  enemyDestroyed: sweep("sawtooth", 400, 80, 0.15, 0.15),
  /** A metallic clang: 800 Hz triangle, 80 ms. */
  bridgeHit: blip("triangle", 800, 0.08, 0.12),
  /** A big explosion: falling 300 → 40 Hz sawtooth, 500 ms. */
  bridgeDestroyed: sweep("sawtooth", 300, 40, 0.5, 0.2),
  /** A rising pling: 400 → 600 Hz sine, 200 ms. */
  fuelCapture: sweep("sine", 400, 600, 0.2, 0.12),
  /** An explosion, and a falling tone for the fuel missed. */
  fuelDestroyed: [
    sweep("sawtooth", 300, 100, 0.15, 0.12),
    { ...sweep("sine", 600, 300, 0.2, 0.08), delay: 0.1 },
  ],
  /** A splash: falling 150 → 80 Hz square, 100 ms. */
  mineDeploy: sweep("square", 150, 80, 0.1, 0.1),
  /** An aquatic boom: falling 200 → 40 Hz sawtooth, 400 ms. */
  mineHit: sweep("sawtooth", 200, 40, 0.4, 0.18),
  /** A crash: falling 500 → 100 Hz sawtooth, 500 ms. */
  death: sweep("sawtooth", 500, 100, 0.5, 0.2),
  /** A rising whoosh: 200 → 800 Hz sine, 200 ms. */
  respawn: sweep("sine", 200, 800, 0.2, 0.1),
  /** A section cleared: C5-E5-G5. */
  sectionClear: notes([523, 659, 784], { wave: "square", note: 0.1, vol: 0.1 }),
  /** The low-fuel alarm's pulse: 600 Hz square, 50 ms. */
  fuelLow: blip("square", 600, 0.05, 0.08),
  /** A kill stolen: three 1000 Hz blips, 30 ms each, 60 ms apart. */
  killSteal: notes([1000, 1000, 1000], { wave: "sine", note: 0.03, gap: 0.03, vol: 0.1 }),
  /** 600 Hz square blip, 80 ms. */
  countdown: blip("square", 600, 0.08, 0.12),
  /** A military fanfare: rising C5-E5-G5-C6-E6. */
  win: WIN_FANFARE,
  /** Falling 500 → 150 Hz sawtooth, 700 ms. */
  lose: LOSE_SWEEP,
};
