import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { HexInvadersAudio } from "../../../../js/lib/games/hex_invaders/audio.js";

function createMockAudioContext() {
  const mockOsc = {
    type: "sine",
    frequency: { value: 0, setValueAtTime: vi.fn(), linearRampToValueAtTime: vi.fn() },
    connect: vi.fn(),
    start: vi.fn(),
    stop: vi.fn(),
    disconnect: vi.fn(),
  };
  const mockGain = {
    gain: { value: 0, setValueAtTime: vi.fn(), linearRampToValueAtTime: vi.fn() },
    connect: vi.fn(),
    disconnect: vi.fn(),
  };
  return {
    createOscillator: vi.fn(() => ({ ...mockOsc })),
    createGain: vi.fn(() => ({ ...mockGain })),
    resume: vi.fn(() => Promise.resolve()),
    currentTime: 0,
    destination: {},
    state: "running",
  };
}

describe("HexInvadersAudio", () => {
  let savedAudioContext;

  beforeEach(() => {
    savedAudioContext = globalThis.AudioContext;
    // Must use function (not arrow) for Vitest
    globalThis.AudioContext = function () {
      return createMockAudioContext();
    };
  });

  afterEach(() => {
    globalThis.AudioContext = savedAudioContext;
  });

  it("does not create AudioContext in constructor (lazy init)", () => {
    const audio = new HexInvadersAudio();
    expect(audio._ctx).toBeNull();
  });

  it("creates AudioContext on first sound call", () => {
    const audio = new HexInvadersAudio();
    audio.playFire();
    expect(audio._ctx).not.toBeNull();
  });

  it("handles suspended context by calling resume", () => {
    const mockCtx = createMockAudioContext();
    mockCtx.state = "suspended";
    globalThis.AudioContext = function () {
      return mockCtx;
    };

    const audio = new HexInvadersAudio();
    audio.playFire();
    expect(mockCtx.resume).toHaveBeenCalled();
  });

  it("handles missing AudioContext gracefully", () => {
    globalThis.AudioContext = undefined;
    const audio = new HexInvadersAudio();
    // Should not throw
    expect(() => audio.playFire()).not.toThrow();
    expect(() => audio.playAlienDestroyed()).not.toThrow();
  });

  describe("all sound methods are callable", () => {
    const methods = [
      "playMarch",
      "playFire",
      "playAlienDestroyed",
      "playBombFall",
      "playCannonHit",
      "playShieldHit",
      "playUFOAppear",
      "playUFODestroyed",
      "playCombo",
      "playDropWarning",
      "playDropLand",
      "playArmoredClang",
      "playWaveClear",
      "playInvaded",
      "playVictory",
      "playCountdown",
    ];

    for (const method of methods) {
      it(`${method}() does not throw`, () => {
        const audio = new HexInvadersAudio();
        expect(() => audio[method]()).not.toThrow();
      });
    }
  });

  it("playMarch creates oscillator", () => {
    const audio = new HexInvadersAudio();
    audio.playMarch();
    expect(audio._ctx.createOscillator).toHaveBeenCalled();
  });

  it("playCombo creates oscillator", () => {
    const audio = new HexInvadersAudio();
    audio.playCombo(2);
    expect(audio._ctx.createOscillator).toHaveBeenCalled();
  });
});
