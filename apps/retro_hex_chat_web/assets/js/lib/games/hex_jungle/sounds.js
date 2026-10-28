/**
 * Hex Jungle's sounds, as data the core's synthesizer plays, and the buzz held
 * while a log rolls over the player.
 * @module games/hex_jungle/sounds
 */

import { fade, glide, notes } from "../core/synth.js";
import { DEATH_TICKS } from "./protocol.js";

export const MASTER_VOLUME = 0.3;

/** A run of square notes that ring out, each `step` seconds after the last. */
const run = (freqs, step, vol) =>
  notes(freqs, { wave: "square", note: step * 0.9, vol, gap: step * 0.1, fadeKind: "exp" });

const DEATH_TUNE = [523, 494, 440, 392, 349, 330, 294, 262, 247, 220, 196, 175];

export const SOUNDS = {
  /** A jump: a short rising blip. */
  jump: { wave: "square", freq: glide(300, 600, 0.08), vol: fade(0.15, 0.08, "exp"), dur: 0.08 },
  /** The vine caught: a yodelling call, up and down for nearly two seconds. */
  vine: run(
    [392, 523, 392, 659, 523, 784, 659, 523, 392, 523, 659, 784, 880, 784, 659, 523],
    0.12,
    0.12,
  ),
  /** A treasure: a bright four-note jingle. */
  treasure: run([784, 988, 1175, 1568], 0.08, 0.15),
  /** A fall through a hole: notes stepping down. */
  hole: run([660, 554, 440, 370, 294, 220], 0.07, 0.12),
  /** A death: a slow falling tune, as long as the wait before the next life. */
  death: run(DEATH_TUNE, DEATH_TICKS / 60 / DEATH_TUNE.length, 0.12),
  /** A wall: a dull thud. */
  wall: [
    { wave: "noise", vol: fade(0.15, 0.08, "exp"), dur: 0.08 },
    { wave: "sine", freq: 70, vol: fade(0.2, 0.1, "exp"), dur: 0.1 },
  ],
  /** The expedition over: three notes falling to rest. */
  finale: run([659, 523, 392], 0.18, 0.15),
};

/**
 * The buzz while a log rolls over the player: started when it touches, held,
 * and stopped when it has rolled past.
 * @param {ReturnType<import("../core/synth.js").createSynth>} synth
 */
export function extend(synth) {
  let buzz = null;
  const stopLogBuzz = () => {
    buzz?.stop();
    buzz = null;
  };
  return {
    startLogBuzz() {
      if (!buzz) buzz = synth.tone({ wave: "sawtooth", freq: 90, vol: 0.05 });
    },
    stopLogBuzz,
    dispose: stopLogBuzz,
  };
}
