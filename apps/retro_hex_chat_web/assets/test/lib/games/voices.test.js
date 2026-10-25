import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { recordingAudio } from "../../support/games/recording_audio.js";
import { voices } from "../../support/games/voices.js";

let audio;
let ctx;
beforeEach(() => {
  vi.useFakeTimers({ now: 0, toFake: ["setTimeout", "clearTimeout", "performance"] });
  audio = recordingAudio();
  ctx = new AudioContext();
});
afterEach(() => {
  vi.useRealTimers();
  vi.unstubAllGlobals();
});

/** A note built the way most games build one, with the variations they use. */
function note(freq, { direct = false, chained = false } = {}) {
  const osc = ctx.createOscillator();
  const gain = ctx.createGain();
  osc.type = "square";
  if (direct) osc.frequency.value = freq;
  else osc.frequency.setValueAtTime(freq, ctx.currentTime);
  gain.gain.setValueAtTime(0.1, ctx.currentTime);
  gain.gain.linearRampToValueAtTime(0, ctx.currentTime + 0.1);
  if (chained) osc.connect(gain).connect(ctx.destination);
  else {
    osc.connect(gain);
    gain.connect(ctx.destination);
  }
  osc.start(ctx.currentTime);
  osc.stop(ctx.currentTime + 0.1);
}

const heard = () => voices(audio.log);
const fresh = () => {
  audio.log.length = 0;
};

describe("voices", () => {
  it("describes a note: its wave, curves, path to the speakers, start and stop", () => {
    note(440);
    expect(heard()).toEqual([
      {
        source: { kind: "Oscillator", type: "square", params: { frequency: [["set", 440, 0]] } },
        path: [
          {
            kind: "Gain",
            params: {
              gain: [
                ["set", 0.1, 0],
                ["linear", 0, 0.1],
              ],
            },
          },
        ],
        out: "speakers",
        start: 0,
        stop: 0.1,
      },
    ]);
  });

  it("hears a value set directly as the same as one set at the current time", () => {
    note(440, { direct: true });
    const direct = heard();
    fresh();
    note(440);
    expect(heard()).toEqual(direct);
  });

  it("hears a chained connect as the same as two", () => {
    note(440, { chained: true });
    const chained = heard();
    fresh();
    note(440);
    expect(heard()).toEqual(chained);
  });

  it("hears a note a timer starts later as the same as one scheduled that far ahead", () => {
    setTimeout(() => note(660), 40);
    vi.advanceTimersByTime(40);
    const timed = heard();
    fresh();
    vi.setSystemTime(0);

    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = "square";
    osc.frequency.setValueAtTime(660, 0.04);
    gain.gain.setValueAtTime(0.1, 0.04);
    gain.gain.linearRampToValueAtTime(0, 0.14);
    osc.connect(gain).connect(ctx.destination);
    osc.start(0.04);
    osc.stop(0.14);

    expect(heard()).toEqual(timed);
  });

  it("tells apart notes that sound different", () => {
    note(440);
    const a = heard();
    fresh();
    note(441);
    expect(heard()).not.toEqual(a);
  });

  it("follows a voice through a filter and a shared master gain", () => {
    const master = ctx.createGain();
    master.gain.value = 0.3;
    master.connect(ctx.destination);
    const src = ctx.createBufferSource();
    src.buffer = ctx.createBuffer(1, 4800, 48000);
    const filter = ctx.createBiquadFilter();
    filter.type = "bandpass";
    src.connect(filter);
    filter.connect(master);
    src.start(0);

    expect(heard()).toEqual([
      {
        source: { kind: "BufferSource", seconds: 0.1 },
        path: [
          { kind: "BiquadFilter", type: "bandpass" },
          { kind: "Gain", params: { gain: [["set", 0.3, 0]] } },
        ],
        out: "speakers",
        start: 0,
        stop: null,
      },
    ]);
  });
});
