import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { GameSynth } from "../../../js/lib/games/synth.js";
import { HexFrostAudio } from "../../../js/lib/games/hex_frost/audio.js";

function param() {
  return {
    value: 0,
    setValueAtTime: vi.fn(),
    linearRampToValueAtTime: vi.fn(),
    exponentialRampToValueAtTime: vi.fn(),
  };
}

function mockContext(state) {
  return {
    state,
    currentTime: 0,
    destination: { name: "speakers" },
    resume: vi.fn(() => Promise.resolve()),
    close: vi.fn(() => Promise.resolve()),
    createOscillator: vi.fn(() => ({
      frequency: param(),
      connect: vi.fn(),
      start: vi.fn(),
      stop: vi.fn(),
    })),
    createGain: vi.fn(() => ({ gain: param(), connect: vi.fn() })),
  };
}

describe("GameSynth", () => {
  let original;
  let created;
  let startState;

  beforeEach(() => {
    original = globalThis.AudioContext;
    created = [];
    startState = "running";
    globalThis.AudioContext = function () {
      const ctx = mockContext(startState);
      created.push(ctx);
      return ctx;
    };
  });

  afterEach(() => {
    globalThis.AudioContext = original;
  });

  it("opens one context, on the first sound", () => {
    const synth = new GameSynth();
    expect(created).toHaveLength(0);
    synth._playTone(440, 0.1, "square", 0.2);
    synth._playTone(440, 0.1, "square", 0.2);
    expect(created).toHaveLength(1);
  });

  it("resumes a context that starts suspended", () => {
    startState = "suspended";
    const synth = new GameSynth();
    synth._playTone(440, 0.1, "square", 0.2);
    expect(created[0].resume).toHaveBeenCalled();
  });

  it("sends tones to the speakers, or through the master gain when asked", () => {
    const plain = new GameSynth();
    plain._playTone(440, 0.1, "square", 0.2);
    const toneGain = created[0].createGain.mock.results[0].value;
    expect(toneGain.connect).toHaveBeenCalledWith(created[0].destination);

    const mastered = new GameSynth({ masterVolume: 0.3 });
    mastered._playTone(440, 0.1, "square", 0.2);
    const [master, gain] = created[1].createGain.mock.results.map((r) => r.value);
    expect(master.gain.value).toBe(0.3);
    expect(master.connect).toHaveBeenCalledWith(created[1].destination);
    expect(gain.connect).toHaveBeenCalledWith(master);
  });

  it("stays silent where there is no Web Audio", () => {
    globalThis.AudioContext = undefined;
    const synth = new GameSynth();
    expect(() => synth._playTone(440, 0.1, "square", 0.2)).not.toThrow();
    expect(synth.ctx).toBeNull();
  });

  it("closes the context on dispose, even when closing rejects", async () => {
    const synth = new GameSynth();
    synth._playTone(440, 0.1, "square", 0.2);
    created[0].close.mockReturnValue(Promise.reject(new Error("closed")));
    synth.dispose();
    expect(created[0].close).toHaveBeenCalled();
    expect(synth.ctx).toBeNull();
    await Promise.resolve();
  });

  it("hex_frost opens its context on the first sound and resumes it", () => {
    startState = "suspended";
    const frost = new HexFrostAudio();
    expect(created).toHaveLength(0);
    frost.playJump();
    expect(created[0].resume).toHaveBeenCalled();
  });
});
