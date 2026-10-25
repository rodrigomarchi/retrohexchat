/**
 * Hex Skiing's sounds, as data the core's synthesizer plays, and its held
 * ski drone.
 * @module games/hex_skiing/sounds
 */

import { blip, notes, sweep } from "../core/synth.js";

/** A sound starting `delay` seconds later. */
const later = (delay, sound) => ({ ...sound, delay });

export const SOUNDS = {
  /** A quick sine sweep, 400 → 600 Hz, 60 ms. */
  turn: sweep("sine", 400, 600, 0.06, 0.08),
  /** Into a tree: a crack, then a poof of snow. */
  collisionTree: [
    sweep("sawtooth", 500, 80, 0.2, 0.14),
    later(0.05, blip("triangle", 120, 0.15, 0.08)),
  ],
  /** Into a rock: a low thud, 250 → 40 Hz sawtooth. */
  collisionRock: sweep("sawtooth", 250, 40, 0.25, 0.12),
  /** A gate cleared: C5-E5-G5, each ringing into the next. */
  gateCleared: notes([523, 659, 784], { wave: "sine", note: 0.1, gap: -0.05, vol: 0.1 }),
  /** A rising whoosh: 200 → 800 Hz sawtooth, 300 ms. */
  speedBoost: sweep("sawtooth", 200, 800, 0.3, 0.1),
  /** A slide on ice: falling 600 → 200 Hz triangle, 300 ms. */
  icePatch: sweep("triangle", 600, 200, 0.3, 0.06),
  /** The wind rising: 80 → 300 Hz triangle, 800 ms. */
  blizzardStart: sweep("triangle", 80, 300, 0.8, 0.08),
  /** The wind dying: 300 → 60 Hz triangle, 600 ms. */
  blizzardEnd: sweep("triangle", 300, 60, 0.6, 0.06),
  /** A rumble, louder and higher the nearer the avalanche (0 to 1); unheard below 0.1. */
  avalancheRumble: (proximity) => {
    const vol = Math.min(0.1, proximity * 0.1);
    return vol < 0.01 ? [] : blip("sawtooth", 50 + proximity * 30, 0.3, vol);
  },
  /** Swallowed by the avalanche: falling 80 → 20 Hz sawtooth, 600 ms. */
  engulfed: sweep("sawtooth", 80, 20, 0.6, 0.15),
  /** 600 Hz square blip, 80 ms. */
  countdown: blip("square", 600, 0.08, 0.1),
  /** Go: 900 Hz square, 120 ms. */
  countdownGo: blip("square", 900, 0.12, 0.12),
  /** A bell: 880 Hz, then 1100 Hz ringing longer. */
  roundEnd: [blip("sine", 880, 0.3, 0.1), later(0.15, blip("sine", 1100, 0.4, 0.08))],
  /** Rising C5-E5-G5-C6-E6. */
  victory: notes([523, 659, 784, 1047, 1319], { wave: "square", note: 0.12, vol: 0.1 }),
  /** Falling 200 → 30 Hz sawtooth, 800 ms. */
  gameOver: sweep("sawtooth", 200, 30, 0.8, 0.12),
};

/**
 * The skis' drone: a sawtooth whose pitch and loudness follow the speed.
 * @param {ReturnType<import("../core/synth.js").createSynth>} synth
 */
export function extend(synth) {
  let drone = null;
  const stopSkiDrone = () => {
    drone?.stop();
    drone = null;
  };
  return {
    startSkiDrone() {
      if (!drone) drone = synth.tone({ wave: "sawtooth", freq: 60, vol: 0.03 });
    },
    /** @param {number} speed - 0 to 4.5 and beyond: 60 → 200 Hz, louder as it rises */
    updateSkiPitch(speed) {
      const t = Math.min(speed / 4.5, 1);
      drone?.set({ freq: 60 + t * 140, vol: 0.02 + t * 0.04 }, { smooth: 0.1 });
    },
    stopSkiDrone,
    dispose: stopSkiDrone,
  };
}
