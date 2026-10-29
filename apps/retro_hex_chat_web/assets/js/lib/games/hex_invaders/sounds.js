/**
 * Hex Invaders' sounds, as data the core's synthesizer plays.
 * @module games/hex_invaders/sounds
 */

import { FANFARE, blip, fade, notes, sweep } from "../core/synth.js";

export const SOUNDS = {
  /** The march: four falling square notes. */
  march: notes([160, 140, 120, 100], { wave: "square", note: 0.06, gap: 0.02, vol: 0.08 }),
  /** A laser shot: falling 1200 → 600 Hz sine, 60 ms. */
  fire: sweep("sine", 1200, 600, 0.06, 0.12),
  /** An alien popped: falling 600 → 100 Hz sawtooth, 100 ms. */
  alienDestroyed: sweep("sawtooth", 600, 100, 0.1, 0.15),
  /** A bomb's whoosh: falling 400 → 200 Hz sine, 200 ms. */
  bombFall: sweep("sine", 400, 200, 0.2, 0.08),
  /** The cannon blown up: falling 300 → 50 Hz sawtooth, 400 ms. */
  cannonHit: sweep("sawtooth", 300, 50, 0.4, 0.2),
  /** A shield thud: 200 Hz triangle, 80 ms. */
  shieldHit: blip("triangle", 200, 0.08, 0.12),
  /** The UFO's wobble: 700 → 900 → 700 Hz sine, 500 ms. */
  UFOAppear: {
    wave: "sine",
    freq: [
      ["set", 700, 0],
      ["linear", 900, 0.25],
      ["linear", 700, 0.5],
    ],
    vol: fade(0.1, 0.5),
    dur: 0.5,
  },
  /** The UFO destroyed: a sparkle of C5-E5-G5-C6. */
  UFODestroyed: notes([523, 659, 784, 1047], { wave: "sine", note: 0.07, gap: 0.005, vol: 0.1 }),
  /** A combo: rising staccato, more notes for a higher level (up to six). */
  combo: (level) =>
    notes(
      Array.from({ length: Math.min((level || 1) + 2, 6) }, (_, i) => 400 + i * 100),
      { wave: "square", note: 0.05, gap: 0.01, vol: 0.08 },
    ),
  /** A drop coming: falling 1000 → 300 Hz whistle, 300 ms. */
  dropWarning: sweep("sine", 1000, 300, 0.3, 0.1),
  /** A drop landing: falling 100 → 40 Hz triangle thud, 150 ms. */
  dropLand: sweep("triangle", 100, 40, 0.15, 0.15),
  /** An armored alien hit: a metallic clang, 800 → 850 → 780 Hz square. */
  armoredClang: {
    wave: "square",
    freq: [
      ["set", 800, 0],
      ["linear", 850, 0.05],
      ["linear", 780, 0.1],
    ],
    vol: fade(0.1, 0.1),
    dur: 0.1,
  },
  /** A wave cleared: C5-E5-G5. */
  waveClear: notes([523, 659, 784], { wave: "square", note: 0.1, gap: 0.02, vol: 0.1 }),
  /** Invaded: a grave collapse, falling 200 → 30 Hz sawtooth, 800 ms. */
  invaded: sweep("sawtooth", 200, 30, 0.8, 0.2),
  /** Victory: rising C5-E5-G5-C6-E6. */
  victory: notes(FANFARE, { wave: "square", note: 0.1, gap: 0.02, vol: 0.12 }),
  /** 600 Hz square blip, 80 ms. */
  countdown: blip("square", 600, 0.08, 0.12),
};
