/**
 * Hex Boxing's sounds, as data the core's synthesizer plays.
 * @module games/hex_boxing/sounds
 */

import { blip, notes, sweep } from "../core/synth.js";

const hitClose = sweep("sawtooth", 200, 60, 0.2, 0.2);
const hitMedium = sweep("triangle", 400, 150, 0.15, 0.15);
const hitFar = blip("sine", 600, 0.08, 0.1);

export const SOUNDS = {
  /** A quick swoosh: falling 800 → 200 Hz sine, 100 ms. */
  punchMiss: sweep("sine", 800, 200, 0.1, 0.08),
  /** A heavy thwack at close range. */
  hitClose,
  /** A hit at medium range. */
  hitMedium,
  /** A light tap from far. */
  hitFar,
  /** The hit a punch's points earn: 3 or more close, 2 medium, else far. */
  hit: (points) => (points >= 3 ? hitClose : points === 2 ? hitMedium : hitFar),
  /** Ding ding ding: three 1200 Hz rings, 150 ms each, 200 ms apart. */
  bellStart: notes([1200, 1200, 1200], { wave: "sine", note: 0.15, gap: 0.05, vol: 0.15 }),
  /** A long 800 Hz ring, 600 ms. */
  bellEnd: blip("sine", 800, 0.6, 0.15),
  /** A loud 1200 Hz ring, 500 ms. */
  KO: blip("sine", 1200, 0.5, 0.25),
  /** 600 Hz square blip, 80 ms. */
  countdown: blip("square", 600, 0.08, 0.1),
  /** A subtle click in the last 15 s: 800 Hz square, 30 ms. */
  timerTick: blip("square", 800, 0.03, 0.06),
  /** Rising C5-E5-G5-C6. */
  win: notes([523, 659, 784, 1047], { wave: "square", note: 0.12, vol: 0.1 }),
  /** Falling 500 → 150 Hz sawtooth, 700 ms. */
  lose: sweep("sawtooth", 500, 150, 0.7, 0.12),
};
