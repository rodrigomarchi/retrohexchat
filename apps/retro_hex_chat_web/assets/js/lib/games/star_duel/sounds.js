/**
 * Star Duel's sounds, as data the core's synthesizer plays, and its two held
 * sounds: the thrust and the star's drone.
 * @module games/star_duel/sounds
 */

import { blip, notes, sweep } from "../core/synth.js";

export const SOUNDS = {
  /** A laser zap: falling 1200 → 200 Hz sawtooth, 100 ms. */
  fire: sweep("sawtooth", 1200, 200, 0.1, 0.12),
  /** A short metallic impact: 600 Hz square, 80 ms. */
  hit: blip("square", 600, 0.08, 0.15),
  /** A heavy explosion: falling 200 → 50 Hz sawtooth, 400 ms. */
  death: sweep("sawtooth", 200, 50, 0.4, 0.2),
  /** A phaser sweep: 300 → 2000 → 300 Hz sine, 300 ms. */
  warp: {
    wave: "sine",
    freq: [
      ["set", 300, 0],
      ["linear", 2000, 0.15],
      ["linear", 300, 0.3],
    ],
    vol: [
      ["set", 0.1, 0],
      ["linear", 0, 0.3],
    ],
    dur: 0.3,
  },
  /** 600 Hz square blip, 80 ms. */
  countdown: blip("square", 600, 0.08, 0.12),
  /** Rising 400 → 1000 Hz square arpeggio. */
  win: notes([400, 600, 800, 1000], { wave: "square", note: 0.12, vol: 0.12 }),
  /** The win fanfare falling, 600 → 200 Hz. */
  lose: notes([600, 450, 300, 200], { wave: "square", note: 0.12, vol: 0.12 }),
  /** A rising blip: 200 → 800 Hz sine, 150 ms. */
  spawn: sweep("sine", 200, 800, 0.15, 0.1),
};

const STAR_DRONE_RANGE = 300; // px: beyond it the drone is silent
const STAR_DRONE_MAX = 0.15;

/**
 * The held sounds: the thrust's low buzz while the engine burns, and a drone
 * that swells as a ship nears the star.
 * @param {ReturnType<import("../core/synth.js").createSynth>} synth
 */
export function extend(synth) {
  let thrust = null;
  let drone = null;
  const stopThrust = () => {
    thrust?.stop();
    thrust = null;
  };
  const stopStarProximity = () => {
    drone?.stop();
    drone = null;
  };
  return {
    /** The thrust's 50 Hz sawtooth buzz, until stopped. */
    playThrust() {
      if (!thrust) thrust = synth.tone({ wave: "sawtooth", freq: 50, vol: 0.08 });
    },
    stopThrust,
    /** @param {number} distance - the nearer ship's distance from the star */
    playStarProximity(distance) {
      const vol = Math.max(
        0,
        Math.min(STAR_DRONE_MAX, (1 - distance / STAR_DRONE_RANGE) * STAR_DRONE_MAX),
      );
      if (!drone) drone = synth.tone({ wave: "sine", freq: 80, vol });
      else drone.set({ vol }, { smooth: 0.02 });
    },
    stopStarProximity,
    dispose() {
      stopThrust();
      stopStarProximity();
    },
  };
}
