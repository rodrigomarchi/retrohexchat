import { describe, it, expect, vi, beforeEach } from "vitest";
import { HexEnduroAudio } from "../../../../js/lib/games/hex_enduro/audio.js";

// Mock AudioContext for jsdom (must use function, not arrow)
const mockOscillator = {
  type: "",
  frequency: {
    setValueAtTime: vi.fn(),
    linearRampToValueAtTime: vi.fn(),
    setTargetAtTime: vi.fn(),
  },
  connect: vi.fn(),
  start: vi.fn(),
  stop: vi.fn(),
};

globalThis.AudioContext = function () {
  this.state = "running";
  this.currentTime = 0;
  this.destination = {};
  this.resume = vi.fn();
  this.close = vi.fn();
  this.createOscillator = vi.fn(() => ({ ...mockOscillator }));
  this.createGain = vi.fn(() => ({
    gain: {
      setValueAtTime: vi.fn(),
      linearRampToValueAtTime: vi.fn(),
      setTargetAtTime: vi.fn(),
    },
    connect: vi.fn(),
  }));
};

describe("Hex Enduro Audio", () => {
  let audio;

  beforeEach(() => {
    audio = new HexEnduroAudio();
  });

  it("instantiates without error", () => {
    expect(audio).toBeDefined();
    expect(audio._ctx).toBeNull();
  });

  describe("sound methods exist and are callable", () => {
    const methods = [
      "playLaneChange",
      "playTurbo",
      "playOvertakeAI",
      "playOvertakePlayer",
      "playCollision",
      "playFuelPickup",
      "playWeatherChange",
      "playCountdown",
      "playVictory",
      "playGameOver",
      "playFuelWarning",
    ];

    for (const method of methods) {
      it(`${method}() does not throw`, () => {
        expect(() => audio[method]()).not.toThrow();
      });
    }
  });

  describe("engine drone", () => {
    it("startEngineDrone does not throw", () => {
      expect(() => audio.startEngineDrone()).not.toThrow();
    });

    it("updateEnginePitch does not throw", () => {
      audio.startEngineDrone();
      expect(() => audio.updateEnginePitch(500)).not.toThrow();
    });

    it("stopEngineDrone does not throw", () => {
      audio.startEngineDrone();
      expect(() => audio.stopEngineDrone()).not.toThrow();
    });

    it("stopEngineDrone is safe to call without start", () => {
      expect(() => audio.stopEngineDrone()).not.toThrow();
    });
  });

  describe("destroy", () => {
    it("cleans up without error", () => {
      audio.startEngineDrone();
      expect(() => audio.destroy()).not.toThrow();
      expect(audio._ctx).toBeNull();
    });

    it("is safe to call multiple times", () => {
      expect(() => audio.destroy()).not.toThrow();
      expect(() => audio.destroy()).not.toThrow();
    });
  });
});
