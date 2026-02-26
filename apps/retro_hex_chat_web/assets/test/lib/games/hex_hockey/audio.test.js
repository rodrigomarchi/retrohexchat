import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { HexHockeyAudio } from "../../../../js/lib/games/hex_hockey/audio.js";

function createMockAudioContext() {
  return {
    state: "running",
    currentTime: 0,
    sampleRate: 44100,
    destination: {},
    resume: vi.fn(() => Promise.resolve()),
    close: vi.fn(() => Promise.resolve()),
    createOscillator: vi.fn(() => ({
      type: "sine",
      frequency: {
        value: 0,
        setValueAtTime: vi.fn(),
        exponentialRampToValueAtTime: vi.fn(),
        linearRampToValueAtTime: vi.fn(),
      },
      connect: vi.fn(),
      start: vi.fn(),
      stop: vi.fn(),
    })),
    createGain: vi.fn(() => ({
      gain: {
        value: 1,
        setValueAtTime: vi.fn(),
        exponentialRampToValueAtTime: vi.fn(),
        linearRampToValueAtTime: vi.fn(),
      },
      connect: vi.fn(),
    })),
    createBuffer: vi.fn((_channels, length, _sampleRate) => ({
      getChannelData: vi.fn(() => new Float32Array(length)),
    })),
    createBufferSource: vi.fn(() => ({
      buffer: null,
      connect: vi.fn(),
      start: vi.fn(),
    })),
  };
}

describe("HexHockeyAudio", () => {
  let originalAudioContext;

  beforeEach(() => {
    vi.useFakeTimers();
    originalAudioContext = globalThis.AudioContext;
    const MockAudioCtx = function () {
      return createMockAudioContext();
    };
    globalThis.AudioContext = MockAudioCtx;
    // HexHockeyAudio uses window.AudioContext
    if (typeof window === "undefined") {
      globalThis.window = { AudioContext: MockAudioCtx };
    } else {
      window.AudioContext = MockAudioCtx;
    }
  });

  afterEach(() => {
    vi.useRealTimers();
    globalThis.AudioContext = originalAudioContext;
    if (globalThis.window && !originalAudioContext) {
      delete globalThis.window;
    }
  });

  it("creates with audio context", () => {
    const audio = new HexHockeyAudio();
    expect(audio.ctx).not.toBeNull();
    expect(audio.master).not.toBeNull();
  });

  it("handles missing AudioContext gracefully", () => {
    globalThis.AudioContext = undefined;
    globalThis.webkitAudioContext = undefined;
    if (globalThis.window) {
      globalThis.window.AudioContext = undefined;
      globalThis.window.webkitAudioContext = undefined;
    }
    const audio = new HexHockeyAudio();
    expect(audio.ctx).toBeNull();
    // All sound methods should be safe to call
    audio.playShot();
    audio.playWallBounce();
    audio.playGoalieBlock();
    audio.playGoal();
    audio.playTackleSuccess();
    audio.playTackleFail();
    audio.playFaceoffWhistle();
    audio.playPeriodBuzzer();
    audio.playSuddenDeath();
    audio.stopSuddenDeath();
    audio.playVictory();
    audio.playCapture();
    audio.playCountdownTick();
    audio.playGo();
    audio.destroy();
  });

  it("playShot creates noise + tone", () => {
    const audio = new HexHockeyAudio();
    audio.playShot();
    expect(audio.ctx.createOscillator).toHaveBeenCalled();
    expect(audio.ctx.createBuffer).toHaveBeenCalled();
  });

  it("playWallBounce creates tone + noise", () => {
    const audio = new HexHockeyAudio();
    audio.playWallBounce();
    expect(audio.ctx.createOscillator).toHaveBeenCalled();
  });

  it("playGoalieBlock creates deeper tone", () => {
    const audio = new HexHockeyAudio();
    audio.playGoalieBlock();
    expect(audio.ctx.createOscillator).toHaveBeenCalled();
  });

  it("playGoal creates dual-oscillator horn", () => {
    const audio = new HexHockeyAudio();
    audio.playGoal();
    // 2 oscillators for the horn
    expect(audio.ctx.createOscillator).toHaveBeenCalledTimes(2);
  });

  it("playGoal schedules crowd noise after delay", () => {
    const audio = new HexHockeyAudio();
    audio.playGoal();
    expect(audio._timers.length).toBe(1);
    vi.advanceTimersByTime(300);
    expect(audio.ctx.createBuffer).toHaveBeenCalled();
  });

  it("playTackleSuccess creates impact sound", () => {
    const audio = new HexHockeyAudio();
    audio.playTackleSuccess();
    expect(audio.ctx.createOscillator).toHaveBeenCalled();
  });

  it("playTackleFail creates sweep sound", () => {
    const audio = new HexHockeyAudio();
    audio.playTackleFail();
    expect(audio.ctx.createOscillator).toHaveBeenCalled();
  });

  it("playFaceoffWhistle creates double-tap whistle", () => {
    const audio = new HexHockeyAudio();
    audio.playFaceoffWhistle();
    expect(audio._timers.length).toBe(1);
    vi.advanceTimersByTime(200);
    expect(audio.ctx.createOscillator).toHaveBeenCalledTimes(2);
  });

  it("playPeriodBuzzer creates sawtooth drone", () => {
    const audio = new HexHockeyAudio();
    audio.playPeriodBuzzer();
    expect(audio.ctx.createOscillator).toHaveBeenCalled();
  });

  it("playSuddenDeath starts continuous drone", () => {
    const audio = new HexHockeyAudio();
    audio.playSuddenDeath();
    expect(audio._droneOsc).not.toBeNull();
    expect(audio._droneGain).not.toBeNull();
  });

  it("playSuddenDeath does not create duplicate drone", () => {
    const audio = new HexHockeyAudio();
    audio.playSuddenDeath();
    const firstOsc = audio._droneOsc;
    audio.playSuddenDeath(); // should be no-op
    expect(audio._droneOsc).toBe(firstOsc);
  });

  it("stopSuddenDeath stops the drone", () => {
    const audio = new HexHockeyAudio();
    audio.playSuddenDeath();
    const osc = audio._droneOsc;
    audio.stopSuddenDeath();
    expect(osc.stop).toHaveBeenCalled();
    expect(audio._droneOsc).toBeNull();
  });

  it("stopSuddenDeath is safe when no drone exists", () => {
    const audio = new HexHockeyAudio();
    audio.stopSuddenDeath(); // no-op, no error
    expect(audio._droneOsc).toBeNull();
  });

  it("playVictory plays 4-note fanfare", () => {
    const audio = new HexHockeyAudio();
    audio.playVictory();
    expect(audio.ctx.createOscillator).toHaveBeenCalledTimes(4);
  });

  it("playVictory stops sudden death drone first", () => {
    const audio = new HexHockeyAudio();
    audio.playSuddenDeath();
    const osc = audio._droneOsc;
    audio.playVictory();
    expect(osc.stop).toHaveBeenCalled();
    expect(audio._droneOsc).toBeNull();
  });

  it("playCapture creates short click", () => {
    const audio = new HexHockeyAudio();
    audio.playCapture();
    expect(audio.ctx.createOscillator).toHaveBeenCalled();
  });

  it("playCountdownTick creates tick tone", () => {
    const audio = new HexHockeyAudio();
    audio.playCountdownTick();
    expect(audio.ctx.createOscillator).toHaveBeenCalled();
  });

  it("playGo creates higher-pitched tone", () => {
    const audio = new HexHockeyAudio();
    audio.playGo();
    expect(audio.ctx.createOscillator).toHaveBeenCalled();
  });

  it("destroy cleans up all resources", () => {
    const audio = new HexHockeyAudio();
    audio.playSuddenDeath();
    audio.playGoal(); // creates timer
    vi.advanceTimersByTime(0); // flush

    audio.destroy();
    expect(audio._droneOsc).toBeNull();
    expect(audio._timers).toEqual([]);
    expect(audio.ctx.close).toHaveBeenCalled();
  });

  it("destroy handles already-stopped drone", () => {
    const audio = new HexHockeyAudio();
    audio.playSuddenDeath();
    audio._droneOsc.stop = vi.fn(() => {
      throw new Error("already stopped");
    });
    audio.destroy(); // should not throw
    expect(audio._droneOsc).toBeNull();
  });
});
