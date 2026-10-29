/**
 * Hex Frost's sounds, as data the core's synthesizer plays through its master
 * gain, and its held ambient wind.
 * @module games/hex_frost/sounds
 */

import { fade, glide, ring } from "../core/synth.js";

export const MASTER_VOLUME = 0.3;

/** A note gliding exponentially (never below 20 Hz) while it rings out. */
const slide = (wave, from, to, dur, vol) => ({
  wave,
  freq: glide(from, Math.max(to, 20), dur, "exp"),
  vol: fade(vol, dur, "exp"),
  dur,
});

/** A burst of noise that rings out. */
const burst = (dur, vol) => ({ wave: "noise", vol: fade(vol, dur, "exp"), dur });

/** A sound starting `delay` seconds later. */
const later = (delay, sound) => ({ ...sound, delay });

export const SOUNDS = {
  /** A hop: rising 200 → 500 Hz sine. */
  jump: slide("sine", 200, 500, 0.12, 0.25),
  /** A landing: a puff of noise and a low thump. */
  land: [burst(0.06, 0.1), ring("sine", 80, 0.08, 0.15)],
  /** A block claimed: a crystalline pling, rising. */
  blockClaim: [ring("sine", 800, 0.08, 0.2), later(0.04, ring("sine", 1200, 0.1, 0.15))],
  /** A block stolen: the pling, and an alarm. */
  blockSteal: [
    ring("sine", 1000, 0.08, 0.25),
    later(0.04, ring("sine", 1400, 0.1, 0.2)),
    later(0.08, slide("sawtooth", 600, 200, 0.15, 0.12)),
  ],
  /** An error buzz: falling 300 → 100 Hz sawtooth. */
  blockUndo: slide("sawtooth", 300, 100, 0.15, 0.2),
  /** An igloo piece set: two square notes. */
  iglooPiece: [ring("square", 440, 0.06, 0.15), later(0.05, ring("square", 660, 0.08, 0.12))],
  /** An igloo crumbling. */
  iglooLose: [slide("sawtooth", 400, 80, 0.2, 0.2), burst(0.15, 0.1)],
  /** An igloo complete: three rising notes. */
  iglooComplete: [
    ring("square", 523, 0.12, 0.2),
    later(0.12, ring("square", 659, 0.12, 0.2)),
    later(0.24, ring("square", 784, 0.2, 0.25)),
  ],
  /** Into the igloo: a door closing, and warmth. */
  iglooEnter: [
    burst(0.08, 0.12),
    ring("sine", 200, 0.15, 0.15),
    later(0.1, slide("sine", 300, 500, 0.3, 0.1)),
  ],
  /** A splash into the water. */
  splash: [burst(0.2, 0.2), slide("sine", 400, 100, 0.2, 0.15)],
  /** A fish caught: a splash and a bonus pling. */
  fishCollect: [
    burst(0.08, 0.08),
    ring("sine", 880, 0.06, 0.2),
    later(0.06, ring("sine", 1100, 0.1, 0.15)),
  ],
  /** An enemy's hit. */
  enemyHit: [burst(0.1, 0.2), slide("sawtooth", 500, 80, 0.25, 0.25)],
  /** A bear's low growl: 40 Hz sawtooth. */
  bearNear: ring("sawtooth", 40, 0.3, 0.08),
  /** A clam's sharp snap. */
  clamSnap: [burst(0.03, 0.2), ring("square", 1500, 0.04, 0.15)],
  /** The wind howling: noise through a 600 Hz band. */
  tempLow: { ...burst(0.5, 0.15), filter: { type: "bandpass", freq: 600, Q: 2 } },
  /** Frozen: a shatter. */
  tempZero: [slide("sawtooth", 1200, 60, 0.4, 0.25), burst(0.3, 0.2)],
  /** A countdown beat: 440 Hz square. */
  countdown: ring("square", 440, 0.1, 0.2),
  /** Go: 880 Hz square. */
  countdownGo: ring("square", 880, 0.2, 0.25),
  /** A round's end: 330 Hz, then 440 Hz. */
  roundEnd: [ring("square", 330, 0.15, 0.2), later(0.15, ring("square", 440, 0.2, 0.2))],
  /** An arctic fanfare: C5-E5-G5-C6. */
  victory: [523, 659, 784, 1047].map((freq, i) => later(i * 0.15, ring("square", freq, 0.2, 0.2))),
  /** Falling 440 → 110 Hz sawtooth. */
  gameOver: slide("sawtooth", 440, 110, 0.5, 0.2),
};

/**
 * The ambient wind: a soft 80 Hz hum under the whole match.
 * @param {ReturnType<import("../core/synth.js").createSynth>} synth
 */
export function extend(synth) {
  let wind = null;
  const stopAmbientWind = () => {
    wind?.stop();
    wind = null;
  };
  return {
    startAmbientWind() {
      if (!wind) wind = synth.tone({ wave: "sine", freq: 80, vol: 0.03 });
    },
    stopAmbientWind,
    dispose: stopAmbientWind,
  };
}
