import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { TennisAudio } from "../../../../js/lib/games/hex_tennis/audio.js";

function createMockAudioContext() {
  const mockOsc = {
    type: "sine",
    frequency: { value: 0, setValueAtTime: vi.fn(), linearRampToValueAtTime: vi.fn() },
    connect: vi.fn(function () {
      return this._gain;
    }),
    start: vi.fn(),
    stop: vi.fn(),
    _gain: null,
  };

  const mockGain = {
    gain: { value: 1, setValueAtTime: vi.fn(), linearRampToValueAtTime: vi.fn() },
    connect: vi.fn(),
  };

  mockOsc._gain = mockGain;

  return {
    state: "running",
    currentTime: 0,
    destination: {},
    resume: vi.fn(() => Promise.resolve()),
    createOscillator: vi.fn(() => ({
      ...mockOsc,
      _gain: { ...mockGain, gain: { ...mockGain.gain } },
    })),
    createGain: vi.fn(() => ({ ...mockGain, gain: { ...mockGain.gain } })),
  };
}

describe("TennisAudio", () => {
  let originalAudioContext;

  beforeEach(() => {
    originalAudioContext = globalThis.AudioContext;
    globalThis.AudioContext = function () {
      return createMockAudioContext();
    };
  });

  afterEach(() => {
    globalThis.AudioContext = originalAudioContext;
  });

  it("creates instance without AudioContext", () => {
    const audio = new TennisAudio();
    expect(audio._ctx).toBeNull();
  });

  it("lazy-inits AudioContext on first sound", () => {
    const audio = new TennisAudio();
    audio.playHit();
    expect(audio._ctx).not.toBeNull();
  });

  const methods = [
    "playHit",
    "playServe",
    "playNetHit",
    "playOut",
    "playPoint",
    "playGameWon",
    "playMatchWon",
    "playFault",
    "playCountdown",
    "playBounce",
    "playAce",
  ];

  it("all 11 sound methods exist and are callable", () => {
    const audio = new TennisAudio();
    for (const method of methods) {
      expect(typeof audio[method]).toBe("function");
    }
  });

  for (const method of methods) {
    it(`${method} plays without throwing`, () => {
      const audio = new TennisAudio();
      expect(() => audio[method]()).not.toThrow();
    });
  }

  it("handles AudioContext creation failure gracefully", () => {
    const origWebkit = globalThis.webkitAudioContext;
    globalThis.AudioContext = undefined;
    globalThis.webkitAudioContext = undefined;

    const audio = new TennisAudio();
    for (const method of methods) {
      expect(() => audio[method]()).not.toThrow();
    }
    expect(audio._ctx).toBeNull();

    globalThis.webkitAudioContext = origWebkit;
  });

  it("resumes suspended context", () => {
    const mockCtx = createMockAudioContext();
    mockCtx.state = "suspended";
    globalThis.AudioContext = function () {
      return mockCtx;
    };

    const audio = new TennisAudio();
    audio.playHit();
    expect(mockCtx.resume).toHaveBeenCalled();
  });

  it("creates oscillator and gain for each tone", () => {
    const mockCtx = createMockAudioContext();
    globalThis.AudioContext = function () {
      return mockCtx;
    };

    const audio = new TennisAudio();
    audio.playHit();
    expect(mockCtx.createOscillator).toHaveBeenCalled();
    expect(mockCtx.createGain).toHaveBeenCalled();
  });
});
