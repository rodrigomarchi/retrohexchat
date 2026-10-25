/**
 * Hex Enduro's sounds, as data the core's synthesizer plays, and its held
 * engine drone.
 * @module games/hex_enduro/sounds
 */

import { blip, notes, sweep } from "../core/synth.js";

export const SOUNDS = {
  /** A quick sine sweep, 400 → 600 Hz, 60 ms. */
  laneChange: sweep("sine", 400, 600, 0.06, 0.1),
  /** A sawtooth ramp, 200 → 800 Hz, 300 ms. */
  turbo: sweep("sawtooth", 200, 800, 0.3, 0.12),
  /** A car overtaken: a two-note chirp. */
  overtakeAI: notes([500, 700], { wave: "square", note: 0.05, gap: 0.01, vol: 0.08 }),
  /** The rival overtaken: a three-note fanfare. */
  overtakePlayer: notes([500, 700, 900], { wave: "square", note: 0.07, gap: 0.01, vol: 0.1 }),
  /** A crash: falling 300 → 50 Hz sawtooth, 300 ms. */
  collision: sweep("sawtooth", 300, 50, 0.3, 0.15),
  /** Fuel picked up: C5-E5-G5, each note ringing into the next. */
  fuelPickup: notes([523, 659, 784], { wave: "sine", note: 0.08, gap: -0.02, vol: 0.1 }),
  /** A low triangle rumble, 80 Hz, 500 ms. */
  weatherChange: blip("triangle", 80, 0.5, 0.08),
  /** 600 Hz square blip, 80 ms. */
  countdown: blip("square", 600, 0.08, 0.1),
  /** Rising C5-E5-G5-C6-E6. */
  victory: notes([523, 659, 784, 1047, 1319], { wave: "square", note: 0.1, gap: 0.02, vol: 0.1 }),
  /** Falling 200 → 30 Hz sawtooth, 800 ms. */
  gameOver: sweep("sawtooth", 200, 30, 0.8, 0.12),
  /** A rapid pulse: 800 Hz square, 30 ms. */
  fuelWarning: blip("square", 800, 0.03, 0.06),
};

/**
 * The engine's drone: a sawtooth whose pitch and loudness follow the speed.
 * @param {ReturnType<import("../core/synth.js").createSynth>} synth
 */
export function extend(synth) {
  let drone = null;
  const stopEngineDrone = () => {
    drone?.stop();
    drone = null;
  };
  return {
    startEngineDrone() {
      if (!drone) drone = synth.tone({ wave: "sawtooth", freq: 80, vol: 0.04 });
    },
    /** @param {number} speed - 0 to 1000: 80 → 350 Hz, louder as it rises */
    updateEnginePitch(speed) {
      drone?.set(
        { freq: 80 + (speed / 1000) * 270, vol: 0.02 + (speed / 1000) * 0.06 },
        { smooth: 0.1 },
      );
    },
    stopEngineDrone,
    dispose: stopEngineDrone,
  };
}
