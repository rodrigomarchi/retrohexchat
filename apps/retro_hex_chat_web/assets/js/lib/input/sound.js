/**
 * The notification sounds: one tone each, played through the games' synth,
 * which opens the AudioContext on the first sound, resumes it when the
 * browser has suspended it, and closes it on dispose.
 */

import { createSynth, fade } from "../games/core/synth.js";

/** A steady tone dying away exponentially over `dur` seconds. */
const tone = (wave, freq, dur, vol) => ({ wave, freq, vol: fade(vol, dur, "exp", 0.01), dur });

export const SOUND_CATALOG = {
  none: null,
  beep: tone("sine", 520, 0.1, 0.2),
  ding_low: tone("sine", 440, 0.15, 0.2),
  ding_high: tone("sine", 880, 0.15, 0.25),
  chime_short: tone("sine", 660, 0.12, 0.2),
  chime_long: tone("sine", 660, 0.3, 0.2),
  chime_high: tone("sine", 880, 0.25, 0.25),
  chime_low: tone("sine", 330, 0.25, 0.2),
  alert: tone("square", 880, 0.3, 0.35),
  buzz: tone("sawtooth", 220, 0.2, 0.2),
  click: tone("square", 1200, 0.05, 0.15),
  ring: tone("sine", 740, 0.4, 0.25),
  notify: tone("triangle", 600, 0.15, 0.2),
  blip: tone("sine", 480, 0.08, 0.15),
  whoosh: tone("triangle", 300, 0.25, 0.15),
};

/**
 * @returns {{ play: (name: string) => void, dispose: () => void }}
 */
export function createNotificationSounds() {
  const synth = createSynth();
  return {
    /** Play a sound by its catalog name; "none" and unknown names are silent. */
    play(name) {
      const sound = Object.hasOwn(SOUND_CATALOG, name) ? SOUND_CATALOG[name] : null;
      if (!sound) return;
      try {
        synth.play(sound);
      } catch {
        // Best-effort audio: a notification that cannot sound is not an error.
      }
    },
    dispose: () => synth.dispose(),
  };
}
