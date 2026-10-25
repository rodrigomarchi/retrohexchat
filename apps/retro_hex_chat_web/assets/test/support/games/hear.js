import { vi } from "vitest";
import { recordingAudio } from "./recording_audio.js";
import { voices } from "./voices.js";

/**
 * Play a script of sound calls on a game's audio and return the voices they
 * make. A step is `["playScore"]`, `["playHit", 3]` (a method and its
 * arguments) or `{ wait: 120 }` (milliseconds on the audio clock).
 *
 * @param {() => object} makeAudio - builds the game's audio object
 * @param {Array<Array<unknown> | { wait: number }>} script
 * @returns {Array<object>}
 */
export function hear(makeAudio, script) {
  vi.useFakeTimers({ toFake: ["Date", "performance", "setTimeout", "clearTimeout"] });
  vi.advanceTimersByTime(1000);
  try {
    const audio = recordingAudio();
    const sounds = makeAudio();
    for (const step of script) {
      if (Array.isArray(step)) {
        const [method, ...args] = step;
        sounds[method](...args);
      } else {
        vi.advanceTimersByTime(step.wait);
      }
    }
    // Sounds a game scheduled on timers play out.
    vi.advanceTimersByTime(5000);
    sounds.dispose?.();
    return voices(audio.log);
  } finally {
    vi.useRealTimers();
    vi.unstubAllGlobals();
  }
}
