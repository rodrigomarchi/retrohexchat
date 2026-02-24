import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { StarDuelAudio } from "../../../../js/lib/games/star_duel/audio.js";

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
    gain: {
      value: 1,
      setValueAtTime: vi.fn(),
      linearRampToValueAtTime: vi.fn(),
      setTargetAtTime: vi.fn(),
    },
    connect: vi.fn(),
    disconnect: vi.fn(),
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
    createGain: vi.fn(() => ({
      ...mockGain,
      gain: { ...mockGain.gain },
    })),
  };
}

describe("StarDuelAudio", () => {
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
    const audio = new StarDuelAudio();
    expect(audio._ctx).toBeNull();
  });

  it("lazy-inits AudioContext on first sound", () => {
    const audio = new StarDuelAudio();
    audio.playFire();
    expect(audio._ctx).not.toBeNull();
  });

  it("playThrust/stopThrust without throwing", () => {
    const audio = new StarDuelAudio();
    expect(() => audio.playThrust()).not.toThrow();
    expect(() => audio.stopThrust()).not.toThrow();
  });

  it("playFire without throwing", () => {
    const audio = new StarDuelAudio();
    expect(() => audio.playFire()).not.toThrow();
  });

  it("playHit without throwing", () => {
    const audio = new StarDuelAudio();
    expect(() => audio.playHit()).not.toThrow();
  });

  it("playDeath without throwing", () => {
    const audio = new StarDuelAudio();
    expect(() => audio.playDeath()).not.toThrow();
  });

  it("playWarp without throwing", () => {
    const audio = new StarDuelAudio();
    expect(() => audio.playWarp()).not.toThrow();
  });

  it("playCountdown without throwing", () => {
    const audio = new StarDuelAudio();
    expect(() => audio.playCountdown()).not.toThrow();
  });

  it("playWin without throwing", () => {
    const audio = new StarDuelAudio();
    expect(() => audio.playWin()).not.toThrow();
  });

  it("playSpawn without throwing", () => {
    const audio = new StarDuelAudio();
    expect(() => audio.playSpawn()).not.toThrow();
  });

  it("playStarProximity(100) / stopStarProximity without throwing", () => {
    const audio = new StarDuelAudio();
    expect(() => audio.playStarProximity(100)).not.toThrow();
    expect(() => audio.stopStarProximity()).not.toThrow();
  });

  it("handles AudioContext creation failure gracefully", () => {
    const origWebkit = globalThis.webkitAudioContext;
    globalThis.AudioContext = undefined;
    globalThis.webkitAudioContext = undefined;

    const audio = new StarDuelAudio();
    expect(() => audio.playThrust()).not.toThrow();
    expect(() => audio.stopThrust()).not.toThrow();
    expect(() => audio.playFire()).not.toThrow();
    expect(() => audio.playHit()).not.toThrow();
    expect(() => audio.playDeath()).not.toThrow();
    expect(() => audio.playWarp()).not.toThrow();
    expect(() => audio.playCountdown()).not.toThrow();
    expect(() => audio.playWin()).not.toThrow();
    expect(() => audio.playSpawn()).not.toThrow();
    expect(() => audio.playStarProximity(100)).not.toThrow();
    expect(() => audio.stopStarProximity()).not.toThrow();
    expect(audio._ctx).toBeNull();

    globalThis.webkitAudioContext = origWebkit;
  });

  it("all sound methods callable without error when context is null", () => {
    // Force _ensureContext to return null by making AudioContext constructor throw
    globalThis.AudioContext = function () {
      throw new Error("Not allowed");
    };
    globalThis.webkitAudioContext = undefined;

    const audio = new StarDuelAudio();
    expect(audio._ctx).toBeNull();

    // All methods should be safe to call
    expect(() => audio.playThrust()).not.toThrow();
    expect(() => audio.stopThrust()).not.toThrow();
    expect(() => audio.playFire()).not.toThrow();
    expect(() => audio.playHit()).not.toThrow();
    expect(() => audio.playDeath()).not.toThrow();
    expect(() => audio.playWarp()).not.toThrow();
    expect(() => audio.playCountdown()).not.toThrow();
    expect(() => audio.playWin()).not.toThrow();
    expect(() => audio.playSpawn()).not.toThrow();
    expect(() => audio.playStarProximity(50)).not.toThrow();
    expect(() => audio.stopStarProximity()).not.toThrow();
  });

  it("resumes suspended context", () => {
    const mockCtx = createMockAudioContext();
    mockCtx.state = "suspended";
    globalThis.AudioContext = function () {
      return mockCtx;
    };

    const audio = new StarDuelAudio();
    audio.playFire();
    expect(mockCtx.resume).toHaveBeenCalled();
  });

  it("creates oscillator and gain for tone", () => {
    const mockCtx = createMockAudioContext();
    globalThis.AudioContext = function () {
      return mockCtx;
    };

    const audio = new StarDuelAudio();
    audio.playFire();
    expect(mockCtx.createOscillator).toHaveBeenCalled();
    expect(mockCtx.createGain).toHaveBeenCalled();
  });

  it("playThrust starts looping osc, stopThrust stops it", () => {
    const mockCtx = createMockAudioContext();
    globalThis.AudioContext = function () {
      return mockCtx;
    };

    const audio = new StarDuelAudio();
    audio.playThrust();

    // Thrust should create an oscillator
    expect(mockCtx.createOscillator).toHaveBeenCalled();
    expect(audio._thrustOsc).not.toBeNull();
    expect(audio._thrustGain).not.toBeNull();

    // Calling playThrust again should not create a second oscillator (already playing)
    const callCount = mockCtx.createOscillator.mock.calls.length;
    audio.playThrust();
    expect(mockCtx.createOscillator.mock.calls.length).toBe(callCount);

    // Stop should clear references
    audio.stopThrust();
    expect(audio._thrustOsc).toBeNull();
    expect(audio._thrustGain).toBeNull();
  });

  it("stopThrust disconnects gain node", () => {
    const mockCtx = createMockAudioContext();
    globalThis.AudioContext = function () {
      return mockCtx;
    };

    const audio = new StarDuelAudio();
    audio.playThrust();

    const gainNode = audio._thrustGain;
    audio.stopThrust();

    expect(gainNode.disconnect).toHaveBeenCalled();
  });

  it("stopStarProximity disconnects gain node", () => {
    const mockCtx = createMockAudioContext();
    globalThis.AudioContext = function () {
      return mockCtx;
    };

    const audio = new StarDuelAudio();
    audio.playStarProximity(100);

    const gainNode = audio._proximityGain;
    audio.stopStarProximity();

    expect(gainNode.disconnect).toHaveBeenCalled();
  });

  it("playStarProximity creates osc on first call, updates gain on subsequent", () => {
    const mockCtx = createMockAudioContext();
    globalThis.AudioContext = function () {
      return mockCtx;
    };

    const audio = new StarDuelAudio();

    // First call should create oscillator
    audio.playStarProximity(100);
    expect(mockCtx.createOscillator).toHaveBeenCalled();
    expect(audio._proximityOsc).not.toBeNull();
    expect(audio._proximityGain).not.toBeNull();

    const oscCallCount = mockCtx.createOscillator.mock.calls.length;

    // Second call should NOT create a new oscillator, only update gain
    audio.playStarProximity(50);
    expect(mockCtx.createOscillator.mock.calls.length).toBe(oscCallCount);

    // Stop should clear references
    audio.stopStarProximity();
    expect(audio._proximityOsc).toBeNull();
    expect(audio._proximityGain).toBeNull();
  });

  it("playStarProximity uses setTargetAtTime for smooth volume change", () => {
    const mockCtx = createMockAudioContext();
    globalThis.AudioContext = function () {
      return mockCtx;
    };

    const audio = new StarDuelAudio();

    // First call creates osc
    audio.playStarProximity(100);

    // Second call should use setTargetAtTime on gain
    audio.playStarProximity(50);

    expect(audio._proximityGain.gain.setTargetAtTime).toHaveBeenCalled();
    const call = audio._proximityGain.gain.setTargetAtTime.mock.calls[0];
    // First arg is the volume value, second is currentTime, third is time constant
    expect(typeof call[0]).toBe("number");
    expect(call[2]).toBe(0.02); // time constant from source
  });

  it("playStarProximity volume is inversely proportional to distance", () => {
    const mockCtx = createMockAudioContext();
    globalThis.AudioContext = function () {
      return mockCtx;
    };

    const audio = new StarDuelAudio();

    // Close distance = higher volume
    audio.playStarProximity(10);
    const closeGain = audio._proximityGain.gain.value;

    // Far distance (recreate to get fresh gain)
    audio.stopStarProximity();
    audio.playStarProximity(290);
    const farGain = audio._proximityGain.gain.value;

    expect(closeGain).toBeGreaterThan(farGain);
  });

  it("playStarProximity clamps volume for very far distances", () => {
    const mockCtx = createMockAudioContext();
    globalThis.AudioContext = function () {
      return mockCtx;
    };

    const audio = new StarDuelAudio();

    // Beyond maxDist (300), volume should be 0
    audio.playStarProximity(500);
    expect(audio._proximityGain.gain.value).toBe(0);
  });
});
