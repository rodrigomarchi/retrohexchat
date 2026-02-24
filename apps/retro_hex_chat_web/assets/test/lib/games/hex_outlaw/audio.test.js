import { describe, it, expect, vi, beforeEach } from "vitest";
import { OutlawAudio } from "../../../../js/lib/games/hex_outlaw/audio.js";

describe("OutlawAudio", () => {
  let audio;

  beforeEach(() => {
    // Mock AudioContext
    const mockOsc = {
      type: "sine",
      frequency: { setValueAtTime: vi.fn(), linearRampToValueAtTime: vi.fn() },
      connect: vi.fn().mockReturnThis(),
      start: vi.fn(),
      stop: vi.fn(),
    };
    const mockGain = {
      gain: {
        setValueAtTime: vi.fn(),
        linearRampToValueAtTime: vi.fn(),
        exponentialRampToValueAtTime: vi.fn(),
      },
      connect: vi.fn().mockReturnThis(),
    };
    const mockBuffer = { getChannelData: vi.fn(() => new Float32Array(4410)) };
    const mockBufferSource = {
      buffer: null,
      connect: vi.fn().mockReturnThis(),
      start: vi.fn(),
      stop: vi.fn(),
    };

    window.AudioContext = function () {
      return {
        currentTime: 0,
        state: "running",
        sampleRate: 44100,
        destination: {},
        resume: vi.fn().mockResolvedValue(undefined),
        close: vi.fn().mockResolvedValue(undefined),
        createOscillator: vi.fn(() => ({ ...mockOsc })),
        createGain: vi.fn(() => ({
          ...mockGain,
          gain: { ...mockGain.gain },
        })),
        createBuffer: vi.fn(() => mockBuffer),
        createBufferSource: vi.fn(() => ({ ...mockBufferSource })),
      };
    };

    audio = new OutlawAudio();
  });

  it("constructor does not create AudioContext", () => {
    expect(audio._ctx).toBeNull();
  });

  it("playGunshot does not throw", () => {
    expect(() => audio.playGunshot()).not.toThrow();
  });

  it("playRicochet does not throw", () => {
    expect(() => audio.playRicochet()).not.toThrow();
  });

  it("playHit does not throw", () => {
    expect(() => audio.playHit()).not.toThrow();
  });

  it("playObstacleHit does not throw", () => {
    expect(() => audio.playObstacleHit()).not.toThrow();
  });

  it("playBell does not throw", () => {
    expect(() => audio.playBell()).not.toThrow();
  });

  it("playCountdown does not throw", () => {
    expect(() => audio.playCountdown()).not.toThrow();
  });

  it("playWin does not throw", () => {
    expect(() => audio.playWin()).not.toThrow();
  });

  it("playLose does not throw", () => {
    expect(() => audio.playLose()).not.toThrow();
  });

  it("lazily creates AudioContext on first sound", () => {
    expect(audio._ctx).toBeNull();
    audio.playCountdown();
    expect(audio._ctx).not.toBeNull();
  });

  it("reuses same AudioContext across calls", () => {
    audio.playGunshot();
    const ctx1 = audio._ctx;
    audio.playHit();
    expect(audio._ctx).toBe(ctx1);
  });

  it("resumes suspended AudioContext", () => {
    audio.playGunshot(); // Creates context
    audio._ctx.state = "suspended";
    audio.playHit(); // Should call resume
    expect(audio._ctx.resume).toHaveBeenCalled();
  });

  describe("dispose", () => {
    it("closes AudioContext and sets to null", () => {
      audio.playGunshot(); // Creates context
      const ctx = audio._ctx;
      ctx.close = vi.fn().mockResolvedValue(undefined);
      audio.dispose();
      expect(ctx.close).toHaveBeenCalled();
      expect(audio._ctx).toBeNull();
    });

    it("is safe to call without context", () => {
      expect(() => audio.dispose()).not.toThrow();
    });

    it("allows recreating context after dispose", () => {
      audio.playGunshot();
      audio.dispose();
      expect(audio._ctx).toBeNull();
      audio.playGunshot(); // Should create new context
      expect(audio._ctx).not.toBeNull();
    });
  });
});
