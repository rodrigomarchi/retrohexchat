import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { BreakoutAudio } from "../../../../js/lib/games/breakout/audio.js";

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
    resume: vi.fn(),
    createOscillator: vi.fn(() => ({
      ...mockOsc,
      _gain: { ...mockGain, gain: { ...mockGain.gain } },
    })),
    createGain: vi.fn(() => ({ ...mockGain, gain: { ...mockGain.gain } })),
  };
}

describe("BreakoutAudio", () => {
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
    const audio = new BreakoutAudio();
    expect(audio._ctx).toBeNull();
  });

  it("lazy-inits AudioContext on first sound", () => {
    const audio = new BreakoutAudio();
    audio.playPaddleHit();
    expect(audio._ctx).not.toBeNull();
  });

  it("plays paddle hit without throwing", () => {
    const audio = new BreakoutAudio();
    expect(() => audio.playPaddleHit()).not.toThrow();
  });

  it("plays wall bounce without throwing", () => {
    const audio = new BreakoutAudio();
    expect(() => audio.playWallBounce()).not.toThrow();
  });

  it("plays block hit for each row without throwing", () => {
    const audio = new BreakoutAudio();
    for (let row = 0; row < 5; row++) {
      expect(() => audio.playBlockHit(row)).not.toThrow();
    }
  });

  it("plays life lost without throwing", () => {
    const audio = new BreakoutAudio();
    expect(() => audio.playLifeLost()).not.toThrow();
  });

  it("plays countdown without throwing", () => {
    const audio = new BreakoutAudio();
    expect(() => audio.playCountdown()).not.toThrow();
  });

  it("plays win without throwing", () => {
    const audio = new BreakoutAudio();
    expect(() => audio.playWin()).not.toThrow();
  });

  it("plays lose without throwing", () => {
    const audio = new BreakoutAudio();
    expect(() => audio.playLose()).not.toThrow();
  });

  it("resumes suspended context", () => {
    const mockCtx = createMockAudioContext();
    mockCtx.state = "suspended";
    globalThis.AudioContext = function () {
      return mockCtx;
    };

    const audio = new BreakoutAudio();
    audio.playPaddleHit();
    expect(mockCtx.resume).toHaveBeenCalled();
  });

  it("creates oscillator and gain for each tone", () => {
    const mockCtx = createMockAudioContext();
    globalThis.AudioContext = function () {
      return mockCtx;
    };

    const audio = new BreakoutAudio();
    audio.playPaddleHit();
    expect(mockCtx.createOscillator).toHaveBeenCalled();
    expect(mockCtx.createGain).toHaveBeenCalled();
  });
});
