import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { HexSkiingAudio } from "../../../../js/lib/games/hex_skiing/audio.js";

class MockOscillator {
  constructor() {
    this.type = "";
    this.frequency = {
      value: 0,
      setTargetAtTime: vi.fn(),
      linearRampToValueAtTime: vi.fn(),
    };
  }
  connect(node) {
    return node;
  }
  start() {}
  stop() {}
}

class MockGainNode {
  constructor() {
    this.gain = {
      value: 0,
      setTargetAtTime: vi.fn(),
      linearRampToValueAtTime: vi.fn(),
    };
  }
  connect(node) {
    return node;
  }
}

class MockAudioContext {
  constructor() {
    this.state = "running";
    this.currentTime = 0;
    this.destination = {};
  }
  createOscillator() {
    return new MockOscillator();
  }
  createGain() {
    return new MockGainNode();
  }
  resume() {
    return Promise.resolve();
  }
  close() {
    return Promise.resolve();
  }
}

describe("HexSkiingAudio", () => {
  beforeEach(() => {
    globalThis.AudioContext = MockAudioContext;
  });

  afterEach(() => {
    delete globalThis.AudioContext;
  });

  it("creates without errors", () => {
    const audio = new HexSkiingAudio();
    expect(audio).toBeTruthy();
  });

  it("starts and stops ski drone", () => {
    const audio = new HexSkiingAudio();
    audio.startSkiDrone();
    expect(audio._droneOsc).not.toBeNull();

    audio.stopSkiDrone();
    expect(audio._droneOsc).toBeNull();
  });

  it("does not create duplicate drones", () => {
    const audio = new HexSkiingAudio();
    audio.startSkiDrone();
    const firstOsc = audio._droneOsc;
    audio.startSkiDrone();
    expect(audio._droneOsc).toBe(firstOsc);
    audio.destroy();
  });

  it("updates ski pitch without crashing", () => {
    const audio = new HexSkiingAudio();
    audio.startSkiDrone();
    expect(() => audio.updateSkiPitch(3.0)).not.toThrow();
    audio.destroy();
  });

  it("plays sound effects without crashing", () => {
    const audio = new HexSkiingAudio();
    expect(() => audio.playTurn()).not.toThrow();
    expect(() => audio.playCollisionTree()).not.toThrow();
    expect(() => audio.playCollisionRock()).not.toThrow();
    expect(() => audio.playGateCleared()).not.toThrow();
    expect(() => audio.playSpeedBoost()).not.toThrow();
    expect(() => audio.playIcePatch()).not.toThrow();
    expect(() => audio.playBlizzardStart()).not.toThrow();
    expect(() => audio.playBlizzardEnd()).not.toThrow();
    expect(() => audio.playAvalancheRumble(0.5)).not.toThrow();
    expect(() => audio.playEngulfed()).not.toThrow();
    expect(() => audio.playCountdown()).not.toThrow();
    expect(() => audio.playCountdownGo()).not.toThrow();
    expect(() => audio.playRoundEnd()).not.toThrow();
    expect(() => audio.playVictory()).not.toThrow();
    expect(() => audio.playGameOver()).not.toThrow();
    audio.destroy();
  });

  it("destroys cleanly", () => {
    const audio = new HexSkiingAudio();
    audio.startSkiDrone();
    audio.destroy();
    expect(audio._droneOsc).toBeNull();
    expect(audio._ctx).toBeNull();
  });

  it("handles missing AudioContext gracefully", () => {
    delete globalThis.AudioContext;
    const audio = new HexSkiingAudio();
    expect(() => audio.playCountdown()).not.toThrow();
    expect(() => audio.startSkiDrone()).not.toThrow();
    expect(() => audio.destroy()).not.toThrow();
  });

  it("skips low-volume avalanche rumble", () => {
    const audio = new HexSkiingAudio();
    // proximity 0 should result in vol < 0.01, so no sound
    expect(() => audio.playAvalancheRumble(0)).not.toThrow();
    audio.destroy();
  });

  it("clears pending timers on destroy", () => {
    const audio = new HexSkiingAudio();
    audio.playCollisionTree(); // Creates a setTimeout
    audio.playGateCleared(); // Creates multiple setTimeouts
    audio.playVictory(); // Creates multiple setTimeouts
    expect(audio._timers.length).toBeGreaterThan(0);
    audio.destroy();
    expect(audio._timers).toEqual([]);
  });

  it("destroy is idempotent", () => {
    const audio = new HexSkiingAudio();
    audio.startSkiDrone();
    audio.destroy();
    expect(() => audio.destroy()).not.toThrow();
    expect(audio._ctx).toBeNull();
    expect(audio._droneOsc).toBeNull();
  });

  it("disconnects drone nodes on stop", () => {
    const disconnectFn = vi.fn();

    class MockOscWithDisconnect extends MockOscillator {
      disconnect = disconnectFn;
    }

    class MockGainWithDisconnect extends MockGainNode {
      disconnect = disconnectFn;
    }

    class MockCtx extends MockAudioContext {
      createOscillator() {
        return new MockOscWithDisconnect();
      }
      createGain() {
        return new MockGainWithDisconnect();
      }
    }

    globalThis.AudioContext = MockCtx;
    const audio = new HexSkiingAudio();
    audio.startSkiDrone();
    audio.stopSkiDrone();
    expect(disconnectFn).toHaveBeenCalled();
  });
});
