import { describe, it, expect, vi, beforeEach } from "vitest";
import {
  GAME_MODE,
  INPUT_KEY,
  encodeGameReady,
  encodePlayerInput,
  encodeGameEnd,
} from "../../../../js/lib/games/hex_skiing/protocol.js";

// Mock AudioContext
class MockAudioContext {
  constructor() {
    this.state = "running";
  }
  createOscillator() {
    return {
      type: "",
      frequency: { value: 0, setTargetAtTime: vi.fn(), linearRampToValueAtTime: vi.fn() },
      connect: vi.fn().mockReturnThis(),
      start: vi.fn(),
      stop: vi.fn(),
    };
  }
  createGain() {
    return {
      gain: { value: 0, setTargetAtTime: vi.fn(), linearRampToValueAtTime: vi.fn() },
      connect: vi.fn().mockReturnThis(),
    };
  }
  resume() {
    return Promise.resolve();
  }
  close() {
    return Promise.resolve();
  }
}

// Mock canvas
function createMockCanvas() {
  const ctx = {
    fillStyle: "",
    strokeStyle: "",
    lineWidth: 0,
    font: "",
    textAlign: "",
    textBaseline: "",
    globalAlpha: 1,
    fillRect: vi.fn(),
    strokeRect: vi.fn(),
    fillText: vi.fn(),
    beginPath: vi.fn(),
    moveTo: vi.fn(),
    lineTo: vi.fn(),
    fill: vi.fn(),
    save: vi.fn(),
    restore: vi.fn(),
    translate: vi.fn(),
    scale: vi.fn(),
    createLinearGradient: vi.fn(() => ({
      addColorStop: vi.fn(),
    })),
    createRadialGradient: vi.fn(() => ({
      addColorStop: vi.fn(),
    })),
  };
  return {
    width: 640,
    height: 480,
    getContext: vi.fn(() => ctx),
    _ctx: ctx,
  };
}

// Mock channel
function createMockChannel() {
  return {
    readyState: "open",
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
    send: vi.fn(),
  };
}

describe("Hex Skiing Engine", () => {
  let HexSkiingEngine;

  beforeEach(async () => {
    globalThis.AudioContext = MockAudioContext;
    globalThis.getComputedStyle = vi.fn(() => ({
      getPropertyValue: vi.fn(() => "#39ff14"),
    }));

    const mod = await import("../../../../js/lib/games/hex_skiing/engine.js");
    HexSkiingEngine = mod.HexSkiingEngine;
  });

  it("resolves mode from gameId", () => {
    const canvas = createMockCanvas();
    const channel = createMockChannel();

    const alpine = new HexSkiingEngine(canvas, channel, "hex_skiing", true, null);
    expect(alpine.mode).toBe(GAME_MODE.ALPINE_RACE);

    const escape = new HexSkiingEngine(canvas, channel, "hex_skiing_escape", true, null);
    expect(escape.mode).toBe(GAME_MODE.AVALANCHE_ESCAPE);

    const clean = new HexSkiingEngine(canvas, channel, "hex_skiing_clean", true, null);
    expect(clean.mode).toBe(GAME_MODE.CLEAN_RUN);
  });

  it("creates with correct default state", () => {
    const canvas = createMockCanvas();
    const channel = createMockChannel();
    const engine = new HexSkiingEngine(canvas, channel, "hex_skiing", true, null);

    expect(engine.isHost).toBe(true);
    expect(engine.gameState).toBeNull();
    expect(engine.localInputs).toEqual({ left: false, right: false });
    expect(engine.remoteInputs).toEqual({ left: false, right: false });
    expect(engine.frameCount).toBe(0);
    expect(engine.peerReady).toBe(false);
  });

  it("initializes game state on start (host)", () => {
    const canvas = createMockCanvas();
    const channel = createMockChannel();
    const engine = new HexSkiingEngine(canvas, channel, "hex_skiing", true, null);

    // Stub document event listeners
    const origAdd = document.addEventListener;
    const origRemove = document.removeEventListener;
    document.addEventListener = vi.fn();
    document.removeEventListener = vi.fn();

    engine.start();

    expect(engine.gameState).not.toBeNull();
    expect(engine.colors).not.toBeNull();
    expect(engine.snowParticles).not.toBeNull();

    engine.stop();
    document.addEventListener = origAdd;
    document.removeEventListener = origRemove;
  });

  it("sends GAME_READY on start (peer)", () => {
    const canvas = createMockCanvas();
    const channel = createMockChannel();
    const engine = new HexSkiingEngine(canvas, channel, "hex_skiing", false, null);

    const origAdd = document.addEventListener;
    const origRemove = document.removeEventListener;
    document.addEventListener = vi.fn();
    document.removeEventListener = vi.fn();

    engine.start();

    // Peer should send GAME_READY
    expect(channel.send).toHaveBeenCalled();
    const sentData = channel.send.mock.calls[0][0];
    expect(sentData.byteLength).toBe(1); // GAME_READY is 1 byte

    engine.stop();
    document.addEventListener = origAdd;
    document.removeEventListener = origRemove;
  });

  it("maps arrow keys correctly", () => {
    const canvas = createMockCanvas();
    const channel = createMockChannel();
    const engine = new HexSkiingEngine(canvas, channel, "hex_skiing", true, null);

    // Test key mapping
    expect(engine._mapKey({ key: "ArrowLeft" })).toBe(0); // INPUT_KEY.LEFT
    expect(engine._mapKey({ key: "ArrowRight" })).toBe(1); // INPUT_KEY.RIGHT
    expect(engine._mapKey({ key: "a" })).toBe(0);
    expect(engine._mapKey({ key: "d" })).toBe(1);
    expect(engine._mapKey({ key: "ArrowUp" })).toBeNull();
    expect(engine._mapKey({ key: " " })).toBeNull();
  });

  it("guards against duplicate GAME_READY", () => {
    const canvas = createMockCanvas();
    const channel = createMockChannel();
    const engine = new HexSkiingEngine(canvas, channel, "hex_skiing", true, null);

    const origAdd = document.addEventListener;
    const origRemove = document.removeEventListener;
    document.addEventListener = vi.fn();
    document.removeEventListener = vi.fn();

    engine.start();

    // First GAME_READY should work
    const buf = encodeGameReady();
    engine._handleMessage({ data: buf });
    expect(engine.peerReady).toBe(true);

    // Second GAME_READY should be ignored (no duplicate loop)
    engine._handleMessage({ data: encodeGameReady() });
    // Should still be peerReady without creating a second loop
    expect(engine.peerReady).toBe(true);

    engine.stop();
    document.addEventListener = origAdd;
    document.removeEventListener = origRemove;
  });

  it("handles PLAYER_INPUT messages on host", () => {
    const canvas = createMockCanvas();
    const channel = createMockChannel();
    const engine = new HexSkiingEngine(canvas, channel, "hex_skiing", true, null);

    const buf = encodePlayerInput(INPUT_KEY.LEFT, true);
    engine._handleMessage({ data: buf });
    expect(engine.remoteInputs.left).toBe(true);

    const buf2 = encodePlayerInput(INPUT_KEY.LEFT, false);
    engine._handleMessage({ data: buf2 });
    expect(engine.remoteInputs.left).toBe(false);
  });

  it("peer calls onGameEnd when receiving GAME_END", () => {
    const canvas = createMockCanvas();
    const channel = createMockChannel();
    const onGameEnd = vi.fn();
    const engine = new HexSkiingEngine(canvas, channel, "hex_skiing", false, onGameEnd);

    const buf = encodeGameEnd({ score1: 2, score2: 1, winner: 1 });
    engine._handleMessage({ data: buf });
    expect(onGameEnd).toHaveBeenCalledWith({
      score1: 2,
      score2: 1,
      winner: 1,
    });
  });

  it("stop() resets session state", () => {
    const canvas = createMockCanvas();
    const channel = createMockChannel();
    const engine = new HexSkiingEngine(canvas, channel, "hex_skiing", true, null);

    const origAdd = document.addEventListener;
    const origRemove = document.removeEventListener;
    document.addEventListener = vi.fn();
    document.removeEventListener = vi.fn();

    engine.start();
    engine.peerReady = true;
    engine.localInputs.left = true;
    engine.frameCount = 100;

    engine.stop();

    expect(engine.peerReady).toBe(false);
    expect(engine.localInputs).toEqual({ left: false, right: false });
    expect(engine.remoteInputs).toEqual({ left: false, right: false });
    expect(engine.frameCount).toBe(0);

    document.addEventListener = origAdd;
    document.removeEventListener = origRemove;
  });

  it("ignores non-ArrayBuffer messages", () => {
    const canvas = createMockCanvas();
    const channel = createMockChannel();
    const engine = new HexSkiingEngine(canvas, channel, "hex_skiing", true, null);

    // Should not throw for string data
    expect(() => engine._handleMessage({ data: "hello" })).not.toThrow();
    // Should not throw for null data
    expect(() => engine._handleMessage({ data: null })).not.toThrow();
  });
});
