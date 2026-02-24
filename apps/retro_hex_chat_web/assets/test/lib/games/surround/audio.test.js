import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { SurroundAudio } from "../../../../js/lib/games/surround/audio.js";

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

describe("SurroundAudio", () => {
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
    const audio = new SurroundAudio();
    expect(audio._ctx).toBeNull();
  });

  it("lazy-inits AudioContext on first sound", () => {
    const audio = new SurroundAudio();
    audio.playMove();
    expect(audio._ctx).not.toBeNull();
  });

  it("plays move without throwing", () => {
    const audio = new SurroundAudio();
    expect(() => audio.playMove()).not.toThrow();
  });

  it("plays crash without throwing", () => {
    const audio = new SurroundAudio();
    expect(() => audio.playCrash()).not.toThrow();
  });

  it("plays countdown without throwing", () => {
    const audio = new SurroundAudio();
    expect(() => audio.playCountdown()).not.toThrow();
  });

  it("plays round win without throwing", () => {
    const audio = new SurroundAudio();
    expect(() => audio.playRoundWin()).not.toThrow();
  });

  it("plays match win without throwing", () => {
    const audio = new SurroundAudio();
    expect(() => audio.playMatchWin()).not.toThrow();
  });

  it("plays match lose without throwing", () => {
    const audio = new SurroundAudio();
    expect(() => audio.playMatchLose()).not.toThrow();
  });

  it("handles AudioContext creation failure gracefully", () => {
    const origWebkit = globalThis.webkitAudioContext;
    globalThis.AudioContext = undefined;
    globalThis.webkitAudioContext = undefined;

    const audio = new SurroundAudio();
    expect(() => audio.playMove()).not.toThrow();
    expect(() => audio.playCrash()).not.toThrow();
    expect(() => audio.playCountdown()).not.toThrow();
    expect(() => audio.playRoundWin()).not.toThrow();
    expect(() => audio.playMatchWin()).not.toThrow();
    expect(() => audio.playMatchLose()).not.toThrow();
    expect(audio._ctx).toBeNull();

    globalThis.webkitAudioContext = origWebkit;
  });

  it("resumes suspended context", () => {
    const mockCtx = createMockAudioContext();
    mockCtx.state = "suspended";
    globalThis.AudioContext = function () {
      return mockCtx;
    };

    const audio = new SurroundAudio();
    audio.playMove();
    expect(mockCtx.resume).toHaveBeenCalled();
  });

  it("creates oscillator and gain for each tone", () => {
    const mockCtx = createMockAudioContext();
    globalThis.AudioContext = function () {
      return mockCtx;
    };

    const audio = new SurroundAudio();
    audio.playMove();
    expect(mockCtx.createOscillator).toHaveBeenCalled();
    expect(mockCtx.createGain).toHaveBeenCalled();
  });
});
