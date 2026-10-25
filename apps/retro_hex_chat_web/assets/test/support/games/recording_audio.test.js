import { describe, it, expect, afterEach, beforeEach, vi } from "vitest";
import { recordingAudio } from "./recording_audio.js";
import { blip, createSynth } from "../../../js/lib/games/core/synth.js";

describe("recording audio", () => {
  beforeEach(() => vi.useFakeTimers({ now: 0, toFake: ["Date", "performance"] }));
  afterEach(() => {
    vi.useRealTimers();
    vi.unstubAllGlobals();
  });

  it("records one plain tone as the calls that build it", () => {
    const audio = recordingAudio();
    createSynth().play(blip("sawtooth", 800, 0.06, 0.15));

    expect(audio.log).toEqual([
      ["context", "new"],
      ["n1", "createOscillator"],
      ["n1", "type", "sawtooth"],
      ["n1.frequency", "setValueAtTime", 800, 0],
      ["n2", "createGain"],
      ["n2.gain", "setValueAtTime", 0.15, 0],
      ["n2.gain", "linearRampToValueAtTime", 0, 0.06],
      ["n1", "connect", "n2"],
      ["n2", "connect", "destination"],
      ["n1", "start", 0],
      ["n1", "stop", 0.06],
    ]);
  });

  it("reads the audio clock from the test clock", () => {
    const audio = recordingAudio();
    vi.advanceTimersByTime(1500);
    createSynth().play(blip("square", 400, 0.1, 0.1));

    expect(audio.log).toContainEqual(["n1", "start", 1.5]);
  });

  it("keeps one log across every context a page opens", () => {
    const audio = recordingAudio();
    createSynth().play(blip("sine", 1, 1, 1));
    createSynth().play(blip("sine", 2, 1, 1));

    expect(audio.log.filter(([, op]) => op === "new")).toHaveLength(2);
    expect(audio.log).toContainEqual(["n3", "createOscillator"]);
  });

  it("records closing a context", () => {
    const audio = recordingAudio();
    const synth = createSynth();
    synth.play(blip("sine", 1, 1, 1));
    synth.dispose();

    expect(audio.log.at(-1)).toEqual(["context", "close"]);
  });
});
