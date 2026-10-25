/**
 * Hex Outlaw's sounds, as data the core's synthesizer plays.
 * @module games/hex_outlaw/sounds
 */

import { blip, fade, notes, sweep } from "../core/synth.js";

export const SOUNDS = {
  /** A bang: a burst of noise that dies away, over a low thud. */
  gunshot: [
    { wave: "noise", vol: fade(0.15, 0.08), dur: 0.08, decay: true, stop: true },
    sweep("sine", 150, 60, 0.12, 0.12),
  ],
  /** A metallic ping: rising 2000 → 3200 Hz sine, 100 ms. */
  ricochet: sweep("sine", 2000, 3200, 0.1, 0.12),
  /** An impact thud and a metallic sting. */
  hit: [sweep("sawtooth", 300, 80, 0.2, 0.18), sweep("sine", 1500, 800, 0.15, 0.08)],
  /** A bullet into an obstacle: a dry thud. */
  obstacleHit: sweep("sine", 150, 60, 0.1, 0.1),
  /** A church bell: 600 Hz with an overtone at 1200 Hz, ringing out. */
  bell: [
    { wave: "sine", freq: 600, vol: fade(0.15, 0.8, "exp"), dur: 0.8 },
    { wave: "sine", freq: 1200, vol: fade(0.06, 0.5, "exp"), dur: 0.5 },
  ],
  /** 500 Hz square blip, 80 ms. */
  countdown: blip("square", 500, 0.08, 0.08),
  /** A harmonica arpeggio: D4-F♯4-A4-D5. */
  win: notes([294, 370, 440, 587], { wave: "triangle", note: 0.15, vol: 0.1 }),
  /** Falling 500 → 150 Hz sawtooth, 700 ms. */
  lose: sweep("sawtooth", 500, 150, 0.7, 0.1),
};
