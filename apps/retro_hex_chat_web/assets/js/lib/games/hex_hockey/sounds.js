/**
 * Hex Hockey's sounds, as data the core's synthesizer plays through its
 * master gain, and its held sudden-death drone.
 * @module games/hex_hockey/sounds
 */

import { fade, glide, notes } from "../core/synth.js";

export const MASTER_VOLUME = 0.3;

/** A note that rings out exponentially. */
const ring = (wave, freq, dur, vol) => ({ wave, freq, vol: fade(vol, dur, "exp"), dur });

/** A burst of noise that rings out; its samples are scaled by its volume too. */
const burst = (dur, vol) => ({ wave: "noise", vol: fade(vol, dur, "exp"), dur, amplitude: vol });

/** A sound starting `delay` seconds later. */
const later = (delay, sound) => ({ ...sound, delay });

/** A horn's pitch: up a fifth over 300 ms, held, back down by 600 ms. */
const horn = (wave, low, high) => ({
  wave,
  freq: [
    ["set", low, 0],
    ["linear", high, 0.3],
    ["set", high, 0.3],
    ["linear", low, 0.6],
  ],
  vol: [
    ["set", 0.25, 0],
    ["set", 0.25, 0.5],
    ["exp", 0.001, 0.8],
  ],
  dur: 0.8,
});

const fanfare = (freqs) =>
  notes(freqs, { wave: "square", note: 0.3, gap: -0.15, vol: 0.2, fadeKind: "exp" });

export const SOUNDS = {
  /** A sharp slap: noise and an 800 Hz click. */
  shot: [burst(0.06, 0.4), ring("square", 800, 0.05, 0.25)],
  /** A thud off the boards. */
  wallBounce: [ring("triangle", 120, 0.1, 0.3), burst(0.04, 0.15)],
  /** A deeper thud: the goalie's block. */
  goalieBlock: [ring("triangle", 80, 0.15, 0.35), burst(0.06, 0.2)],
  /** The goal horn, and the crowd's cheer after it. */
  goal: [horn("sawtooth", 200, 400), horn("square", 204, 404), later(0.2, burst(0.4, 0.12))],
  /** A tackle's impact. */
  tackleSuccess: [ring("square", 150, 0.08, 0.3), burst(0.05, 0.25)],
  /** A stumble: falling 300 → 100 Hz triangle. */
  tackleFail: {
    wave: "triangle",
    freq: glide(300, 100, 0.2, "exp"),
    vol: fade(0.2, 0.2, "exp"),
    dur: 0.2,
  },
  /** The face-off whistle: two short 1200 Hz blasts. */
  faceoffWhistle: [ring("sine", 1200, 0.15, 0.2), later(0.18, ring("sine", 1200, 0.08, 0.15))],
  /** The period's buzzer: 180 Hz sawtooth, held, then ringing out. */
  periodBuzzer: {
    wave: "sawtooth",
    freq: 180,
    vol: [
      ["set", 0.3, 0],
      ["set", 0.3, 0.6],
      ["exp", 0.001, 1],
    ],
    dur: 1,
  },
  /** The puck taken: a 600 Hz click. */
  capture: ring("square", 600, 0.03, 0.15),
  /** A countdown beat: 880 Hz sine. */
  countdownTick: ring("sine", 880, 0.08, 0.2),
  /** GO: 1320 Hz square. */
  go: ring("square", 1320, 0.12, 0.25),
};

const VICTORY = fanfare([523, 659, 784, 1047]);
const DEFEAT = fanfare([523, 415, 330, 262]);

/**
 * The sudden-death drone, and the fanfares that end it.
 * @param {ReturnType<import("../core/synth.js").createSynth>} synth
 */
export function extend(synth) {
  let drone = null;
  const stopSuddenDeath = () => {
    drone?.stop();
    drone = null;
  };
  return {
    /** A low 55 Hz hum of tension, until stopped. */
    playSuddenDeath() {
      if (!drone) drone = synth.tone({ wave: "sine", freq: 55, vol: 0.08 });
    },
    stopSuddenDeath,
    /** C5-E5-G5-C6, each note ringing over the next; the drone stops first. */
    playVictory() {
      stopSuddenDeath();
      synth.play(VICTORY);
    },
    /** The victory falling, in minor: C5-A♭4-E4-C4. */
    playLose() {
      stopSuddenDeath();
      synth.play(DEFEAT);
    },
    dispose: stopSuddenDeath,
  };
}
