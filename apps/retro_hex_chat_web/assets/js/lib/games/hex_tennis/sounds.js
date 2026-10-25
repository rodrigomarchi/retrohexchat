/**
 * Hex Tennis' sounds, as data the core's synthesizer plays.
 * @module games/hex_tennis/sounds
 */

import { blip, notes, sweep } from "../core/synth.js";

export const SOUNDS = {
  /** A racket's twang: falling 1200 → 600 Hz sawtooth, 80 ms. */
  hit: sweep("sawtooth", 1200, 600, 0.08, 0.12),
  /** A rising swoosh: 200 → 800 Hz sawtooth, 150 ms. */
  serve: sweep("sawtooth", 200, 800, 0.15, 0.15),
  /** A dull thud: 150 Hz square, 100 ms. */
  netHit: blip("square", 150, 0.1, 0.1),
  /** A falling buzz: 500 → 200 Hz sawtooth, 200 ms. */
  out: sweep("sawtooth", 500, 200, 0.2, 0.12),
  /** A point: 600-800-600 Hz triangle. */
  point: notes([600, 800, 600], { wave: "triangle", note: 0.1, vol: 0.1 }),
  /** A game won: rising 400-500-600-800 Hz square. */
  gameWon: notes([400, 500, 600, 800], { wave: "square", note: 0.1, vol: 0.12 }),
  /** The match won: rising 400 → 1200 Hz square fanfare. */
  matchWon: notes([400, 600, 800, 1000, 1200], { wave: "square", note: 0.12, vol: 0.14 }),
  /** The match lost: the fanfare falling, 600 → 200 Hz. */
  matchLost: notes([600, 450, 300, 200], { wave: "square", note: 0.12, vol: 0.14 }),
  /** A short buzz: 300 Hz square, 60 ms. */
  fault: blip("square", 300, 0.06, 0.1),
  /** 600 Hz square blip, 80 ms. */
  countdown: blip("square", 600, 0.08, 0.12),
  /** A soft tap: 500 Hz triangle, 30 ms. */
  bounce: blip("triangle", 500, 0.03, 0.06),
  /** A rising tone: 800 → 1200 Hz sawtooth, 200 ms. */
  ace: sweep("sawtooth", 800, 1200, 0.2, 0.15),
};
