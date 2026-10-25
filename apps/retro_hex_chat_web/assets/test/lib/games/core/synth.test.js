import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import {
  createGameAudio,
  createSynth,
  fade,
  glide,
  notes,
} from "../../../../js/lib/games/core/synth.js";
import { recordingAudio } from "../../../support/games/recording_audio.js";
import { voices } from "../../../support/games/voices.js";

let audio;
beforeEach(() => {
  vi.useFakeTimers({ toFake: ["Date", "performance", "setTimeout"] });
  vi.advanceTimersByTime(1000);
  audio = recordingAudio();
});
afterEach(() => {
  vi.useRealTimers();
  vi.unstubAllGlobals();
});

const heard = () => voices(audio.log);
const at1 = (curve) => curve.map(([op, value, t, ...rest]) => [op, value, t + 1, ...rest]);

describe("createSynth", () => {
  it("plays a note: a wave at a pitch, fading to silence over its length", () => {
    createSynth().play({ wave: "square", freq: 600, vol: fade(0.12, 0.08), dur: 0.08 });
    expect(heard()).toEqual([
      {
        source: { kind: "Oscillator", type: "square", params: { frequency: [["set", 600, 1]] } },
        path: [
          {
            kind: "Gain",
            params: {
              gain: at1([
                ["set", 0.12, 0],
                ["linear", 0, 0.08],
              ]),
            },
          },
        ],
        out: "speakers",
        start: 1,
        stop: 1.08,
      },
    ]);
  });

  it("glides a pitch, linearly or exponentially, and fades exponentially", () => {
    createSynth().play({
      wave: "sine",
      freq: glide(200, 500, 0.12, "exp"),
      vol: fade(0.25, 0.12, "exp"),
      dur: 0.12,
    });
    const [voice] = heard();
    expect(voice.source.params.frequency).toEqual(
      at1([
        ["set", 200, 0],
        ["exp", 500, 0.12],
      ]),
    );
    expect(voice.path[0].params.gain).toEqual(
      at1([
        ["set", 0.25, 0],
        ["exp", 0.001, 0.12],
      ]),
    );
  });

  it("starts a voice later by its delay, curves and all", () => {
    createSynth().play({ wave: "square", freq: 660, vol: fade(0.1, 0.1), dur: 0.1, delay: 0.04 });
    const [voice] = heard();
    expect(voice.start).toBe(1.04);
    expect(voice.stop).toBe(1.14);
    expect(voice.source.params.frequency).toEqual([["set", 660, 1.04]]);
  });

  it("plays every voice of a sound, and a sequence of notes one after another", () => {
    createSynth().play(notes([400, 600], { wave: "square", note: 0.12, vol: 0.12 }));
    expect(heard().map((v) => [v.source.params.frequency[0][1], v.start, v.stop])).toEqual([
      [400, 1, 1.12],
      [600, 1.12, 1.24],
    ]);
    expect(heard()[1].path[0].params.gain).toEqual([
      ["set", 0.12, 1.12],
      ["linear", 0, 1.24],
    ]);
  });

  it("plays noise from a buffer as long as the sound, through a filter when asked", () => {
    createSynth().play({
      wave: "noise",
      vol: fade(0.1, 0.2, "exp"),
      dur: 0.2,
      filter: { type: "bandpass", freq: 800, Q: 2 },
    });
    expect(heard()).toEqual([
      {
        source: { kind: "BufferSource", seconds: 0.2 },
        path: [
          {
            kind: "BiquadFilter",
            type: "bandpass",
            params: { frequency: [["set", 800, 1]], Q: [["set", 2, 1]] },
          },
          {
            kind: "Gain",
            params: {
              gain: at1([
                ["set", 0.1, 0],
                ["exp", 0.001, 0.2],
              ]),
            },
          },
        ],
        out: "speakers",
        start: 1,
        stop: null,
      },
    ]);
  });

  it("sends every voice through one master gain when it has a master volume", () => {
    const synth = createSynth({ masterVolume: 0.3 });
    synth.play({ wave: "sine", freq: 80, vol: fade(0.15, 0.08, "exp"), dur: 0.08 });
    synth.play({ wave: "sine", freq: 90, vol: fade(0.15, 0.08, "exp"), dur: 0.08 });
    const [a, b] = heard();
    expect(a.path.at(-1)).toEqual({ kind: "Gain", params: { gain: [["set", 0.3, 1]] } });
    expect(b.path.at(-1)).toEqual(a.path.at(-1));
    expect(audio.log.filter(([, op]) => op === "createGain")).toHaveLength(3);
  });

  it("holds a tone until told otherwise: it moves smoothly or at once, and stops", () => {
    const synth = createSynth();
    const hum = synth.tone({ wave: "sawtooth", freq: 50, vol: 0.08 });
    vi.advanceTimersByTime(500);
    hum.set({ freq: 120 }, { smooth: 0.1 });
    hum.set({ vol: 0.04 });
    vi.advanceTimersByTime(500);
    hum.stop();
    const [voice] = heard();
    expect(voice.start).toBe(1);
    expect(voice.stop).toBe(2);
    expect(voice.source.params.frequency).toEqual([
      ["set", 50, 1],
      ["target", 120, 1.5, 0.1],
    ]);
    expect(voice.path[0].params.gain).toEqual([
      ["set", 0.08, 1],
      ["set", 0.04, 1.5],
    ]);
    expect(audio.log).toContainEqual([expect.stringMatching(/^n\d+$/), "disconnect"]);
  });

  it("opens no context until the first sound, and closes it on dispose", () => {
    const synth = createSynth();
    expect(synth.ctx).toBeNull();
    synth.play({ wave: "square", freq: 600, vol: 0.1, dur: 0.1 });
    expect(synth.ctx).not.toBeNull();
    synth.dispose();
    expect(audio.log.at(-1)).toEqual(["context", "close"]);
    expect(synth.ctx).toBeNull();
  });

  it("resumes a context the browser keeps suspended, at every sound", () => {
    const synth = createSynth();
    synth.play({ wave: "square", freq: 600, vol: 0.1, dur: 0.1 });
    synth.ctx.state = "suspended";
    const resume = vi.spyOn(synth.ctx, "resume");
    synth.play({ wave: "square", freq: 600, vol: 0.1, dur: 0.1 });
    expect(resume).toHaveBeenCalledOnce();
  });

  it("lets go of a context that will not close", () => {
    const synth = createSynth();
    synth.play({ wave: "square", freq: 600, vol: 0.1, dur: 0.1 });
    vi.spyOn(synth.ctx, "close").mockReturnValue(Promise.reject(new Error("busy")));
    expect(() => synth.dispose()).not.toThrow();
    expect(synth.ctx).toBeNull();
  });

  it("does nothing where the page has no audio", () => {
    vi.stubGlobal("AudioContext", undefined);
    vi.stubGlobal("webkitAudioContext", undefined);
    const synth = createSynth();
    expect(() => synth.play({ wave: "square", freq: 600, vol: 0.1, dur: 0.1 })).not.toThrow();
    expect(synth.tone({ wave: "sine", freq: 80, vol: 0.1 }).stop()).toBeUndefined();
  });
});

describe("createGameAudio", () => {
  const SOUNDS = {
    paddleHit: { wave: "sawtooth", freq: 800, vol: fade(0.15, 0.06), dur: 0.06 },
    blockHit: (row) => ({ wave: "square", freq: 400 + row * 100, vol: fade(0.1, 0.05), dur: 0.05 }),
  };

  it("plays each sound of the table by its name", () => {
    const sounds = createGameAudio({ sounds: SOUNDS });
    sounds.playPaddleHit();
    sounds.playBlockHit(2);
    expect(heard().map((v) => v.source.params.frequency[0][1])).toEqual([800, 600]);
  });

  it("adds the game's own held sounds, played on the same context", () => {
    const sounds = createGameAudio({
      sounds: SOUNDS,
      extend: (synth) => {
        let hum = null;
        return {
          startHum: () => (hum = synth.tone({ wave: "sine", freq: 80, vol: 0.05 })),
          stopHum: () => hum?.stop(),
        };
      },
    });
    sounds.playPaddleHit();
    sounds.startHum();
    sounds.stopHum();
    expect(audio.log.filter(([, op]) => op === "new")).toHaveLength(1);
    expect(heard()).toHaveLength(2);
  });

  it("closes its context on dispose", () => {
    const sounds = createGameAudio({ sounds: SOUNDS });
    sounds.playPaddleHit();
    expect(sounds.ctx).not.toBeNull();
    sounds.dispose();
    expect(sounds.ctx).toBeNull();
  });
});
