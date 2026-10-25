import { vi } from "vitest";

/**
 * A game's audio with every sound a silent spy, for engine tests that check
 * which sounds play. Use from a vi.mock of core/synth.js:
 *
 *   vi.mock("…/core/synth.js", async (importOriginal) => {
 *     const synth = await importOriginal();
 *     const { spySounds } = await import("…/helpers/spy_sounds.js");
 *     return { ...synth, createGameAudio: (spec) => spySounds(synth.createGameAudio(spec)) };
 *   });
 *
 * @param {object} audio - what createGameAudio built
 * @returns {object}
 */
export function spySounds(audio) {
  for (const name of Object.keys(audio)) {
    if (typeof audio[name] === "function") audio[name] = vi.fn();
  }
  return audio;
}
