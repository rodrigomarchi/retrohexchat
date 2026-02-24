import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { PongAudio } from "../../../../js/lib/games/pong/audio.js";

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

describe("PongAudio", () => {
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
    const audio = new PongAudio();
    expect(audio._ctx).toBeNull();
  });

  it("lazy-inits AudioContext on first sound", () => {
    const audio = new PongAudio();
    audio.playPaddleHit();
    expect(audio._ctx).not.toBeNull();
  });

  it("plays paddle hit without throwing", () => {
    const audio = new PongAudio();
    expect(() => audio.playPaddleHit()).not.toThrow();
  });

  it("plays wall bounce without throwing", () => {
    const audio = new PongAudio();
    expect(() => audio.playWallBounce()).not.toThrow();
  });

  it("plays score sound without throwing", () => {
    const audio = new PongAudio();
    expect(() => audio.playScore()).not.toThrow();
  });

  it("plays win sound without throwing", () => {
    const audio = new PongAudio();
    expect(() => audio.playWin()).not.toThrow();
  });

  it("plays countdown sound without throwing", () => {
    const audio = new PongAudio();
    expect(() => audio.playCountdown()).not.toThrow();
  });

  it("resumes suspended context", () => {
    const mockCtx = createMockAudioContext();
    mockCtx.state = "suspended";
    globalThis.AudioContext = function () {
      return mockCtx;
    };

    const audio = new PongAudio();
    audio.playPaddleHit();
    expect(mockCtx.resume).toHaveBeenCalled();
  });

  it("creates oscillator and gain for each tone", () => {
    const mockCtx = createMockAudioContext();
    globalThis.AudioContext = function () {
      return mockCtx;
    };

    const audio = new PongAudio();
    audio.playPaddleHit();
    expect(mockCtx.createOscillator).toHaveBeenCalled();
    expect(mockCtx.createGain).toHaveBeenCalled();
  });
});
