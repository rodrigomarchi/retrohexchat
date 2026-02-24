import { describe, it, expect, vi, beforeEach } from "vitest";
import { OutlawEngine } from "../../../../js/lib/games/hex_outlaw/engine.js";
import {
  PHASE,
  GAME_MODE,
  encodeGameState,
  encodePlayerInput,
  encodeGameReady,
  encodeGameEnd,
  INPUT_KEY,
} from "../../../../js/lib/games/hex_outlaw/protocol.js";
import { createInitialState, BULLET_SPEED_X } from "../../../../js/lib/games/hex_outlaw/physics.js";

function createMockCanvas() {
  const ctx = {
    fillRect: vi.fn(),
    strokeRect: vi.fn(),
    fillText: vi.fn(),
    beginPath: vi.fn(),
    arc: vi.fn(),
    fill: vi.fn(),
    stroke: vi.fn(),
    moveTo: vi.fn(),
    lineTo: vi.fn(),
    clearRect: vi.fn(),
    save: vi.fn(),
    restore: vi.fn(),
    createLinearGradient: vi.fn(() => ({
      addColorStop: vi.fn(),
    })),
    fillStyle: "",
    strokeStyle: "",
    lineWidth: 1,
    lineCap: "butt",
    font: "",
    textAlign: "start",
    textBaseline: "alphabetic",
  };
  const canvas = {
    width: 640,
    height: 480,
    getContext: () => ctx,
  };
  vi.spyOn(window, "getComputedStyle").mockReturnValue({
    getPropertyValue: (prop) => {
      const map = {
        "--game-bg-color": "#1a0a1e",
        "--game-fg-color": "#39ff14",
        "--game-accent-color": "#00e5ff",
        "--game-muted-color": "#3d1f0a",
        "--game-glow-color": "rgba(255, 140, 0, 0.15)",
        "--game-warning-color": "#ff4444",
        "--game-rope-color": "#c4956a",
        "--game-ring-color": "#2a1508",
        "--game-hit-color": "#ffffff",
      };
      return map[prop] || "";
    },
  });
  return canvas;
}

function createMockChannel() {
  return {
    readyState: "open",
    send: vi.fn(),
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
  };
}

describe("OutlawEngine", () => {
  let canvas;
  let channel;

  beforeEach(() => {
    canvas = createMockCanvas();
    channel = createMockChannel();
    vi.spyOn(window, "addEventListener").mockImplementation(() => {});
    vi.spyOn(window, "removeEventListener").mockImplementation(() => {});

    // Mock AudioContext for engine tests that trigger audio
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
        createBuffer: vi.fn(() => ({ getChannelData: vi.fn(() => new Float32Array(4410)) })),
        createBufferSource: vi.fn(() => ({
          buffer: null,
          connect: vi.fn().mockReturnThis(),
          start: vi.fn(),
          stop: vi.fn(),
        })),
      };
    };
  });

  it("creates engine with correct initial state", () => {
    const engine = new OutlawEngine(canvas, channel, "hex_outlaw", true, null);
    expect(engine.isHost).toBe(true);
    expect(engine.gameState.phase).toBe(PHASE.WAITING);
    expect(engine.gameState.score1).toBe(0);
    expect(engine.gameState.score2).toBe(0);
  });

  it("host starts and renders initial state", () => {
    const engine = new OutlawEngine(canvas, channel, "hex_outlaw", true, null);
    engine.start();
    expect(channel.send).not.toHaveBeenCalled();
    engine.stop();
  });

  it("peer sends GAME_READY on start", () => {
    const engine = new OutlawEngine(canvas, channel, "hex_outlaw", false, null);
    engine.start();
    expect(channel.send).toHaveBeenCalledTimes(1);
    engine.stop();
  });

  it("stop cleans up", () => {
    const engine = new OutlawEngine(canvas, channel, "hex_outlaw", true, null);
    engine.start();
    engine.stop();
    expect(engine.running).toBe(false);
  });

  it("_mapKey maps arrow keys correctly", () => {
    const engine = new OutlawEngine(canvas, channel, "hex_outlaw", true, null);
    expect(engine._mapKey("ArrowUp")).toBe(0); // UP
    expect(engine._mapKey("ArrowDown")).toBe(1); // DOWN
    expect(engine._mapKey("ArrowLeft")).toBe(2); // LEFT
    expect(engine._mapKey("ArrowRight")).toBe(3); // RIGHT
    expect(engine._mapKey(" ")).toBe(4); // FIRE
    expect(engine._mapKey("Shift")).toBe(4); // FIRE
  });

  it("_mapKey maps WASD keys correctly", () => {
    const engine = new OutlawEngine(canvas, channel, "hex_outlaw", true, null);
    expect(engine._mapKey("w")).toBe(0);
    expect(engine._mapKey("s")).toBe(1);
    expect(engine._mapKey("a")).toBe(2);
    expect(engine._mapKey("d")).toBe(3);
  });

  it("_mapKey maps uppercase WASD keys", () => {
    const engine = new OutlawEngine(canvas, channel, "hex_outlaw", true, null);
    expect(engine._mapKey("W")).toBe(0);
    expect(engine._mapKey("S")).toBe(1);
    expect(engine._mapKey("A")).toBe(2);
    expect(engine._mapKey("D")).toBe(3);
  });

  it("_mapKey returns null for unmapped keys", () => {
    const engine = new OutlawEngine(canvas, channel, "hex_outlaw", true, null);
    expect(engine._mapKey("q")).toBeNull();
    expect(engine._mapKey("z")).toBeNull();
  });

  it("_safeSend handles closed channel gracefully", () => {
    const closedChannel = { ...createMockChannel(), readyState: "closed" };
    const engine = new OutlawEngine(canvas, closedChannel, "hex_outlaw", true, null);
    engine._safeSend(new ArrayBuffer(10));
    expect(closedChannel.send).not.toHaveBeenCalled();
  });

  it("_handleBlur resets all local inputs", () => {
    const engine = new OutlawEngine(canvas, channel, "hex_outlaw", true, null);
    engine.localInputs = {
      up: true,
      down: true,
      left: true,
      right: true,
      fire: true,
    };
    engine._handleBlur();
    expect(engine.localInputs.up).toBe(false);
    expect(engine.localInputs.down).toBe(false);
    expect(engine.localInputs.left).toBe(false);
    expect(engine.localInputs.right).toBe(false);
    expect(engine.localInputs.fire).toBe(false);
  });

  it("_handleBlur on peer sends key releases", () => {
    const engine = new OutlawEngine(canvas, channel, "hex_outlaw", false, null);
    engine.localInputs = {
      up: true,
      down: true,
      left: true,
      right: true,
      fire: true,
    };
    engine._handleBlur();
    expect(channel.send).toHaveBeenCalledTimes(5);
  });

  it("_handleBlur on host does not send key releases", () => {
    const engine = new OutlawEngine(canvas, channel, "hex_outlaw", true, null);
    engine.localInputs = {
      up: true,
      down: true,
      left: true,
      right: true,
      fire: true,
    };
    engine._handleBlur();
    expect(channel.send).not.toHaveBeenCalled();
  });

  it("stop is safe to call multiple times", () => {
    const engine = new OutlawEngine(canvas, channel, "hex_outlaw", true, null);
    engine.start();
    engine.stop();
    expect(() => engine.stop()).not.toThrow();
  });

  // ====== EDGE CASES ======

  describe("gameModeFromId", () => {
    it("selects QUICK_DRAW for hex_outlaw", () => {
      const engine = new OutlawEngine(canvas, channel, "hex_outlaw", true, null);
      expect(engine.gameState.gameMode).toBe(GAME_MODE.QUICK_DRAW);
    });

    it("selects RICOCHET for hex_outlaw_ricochet", () => {
      const engine = new OutlawEngine(canvas, channel, "hex_outlaw_ricochet", true, null);
      expect(engine.gameState.gameMode).toBe(GAME_MODE.RICOCHET);
    });

    it("selects STAGECOACH for hex_outlaw_stagecoach", () => {
      const engine = new OutlawEngine(canvas, channel, "hex_outlaw_stagecoach", true, null);
      expect(engine.gameState.gameMode).toBe(GAME_MODE.STAGECOACH);
    });

    it("selects NO_MANS_LAND for hex_outlaw_nml", () => {
      const engine = new OutlawEngine(canvas, channel, "hex_outlaw_nml", true, null);
      expect(engine.gameState.gameMode).toBe(GAME_MODE.NO_MANS_LAND);
    });
  });

  describe("_handleBlur edge cases", () => {
    it("resets fire edge trigger flags", () => {
      const engine = new OutlawEngine(canvas, channel, "hex_outlaw", true, null);
      engine._localFirePressed = true;
      engine._remoteFirePressed = true;
      engine._handleBlur();
      expect(engine._localFirePressed).toBe(false);
      expect(engine._remoteFirePressed).toBe(false);
    });
  });

  describe("_applyRemoteInput", () => {
    it("sets up input from remote", () => {
      const engine = new OutlawEngine(canvas, channel, "hex_outlaw", true, null);
      engine._applyRemoteInput({ keyCode: INPUT_KEY.UP, pressed: true });
      expect(engine.remoteInputs.up).toBe(true);
    });

    it("sets down input from remote", () => {
      const engine = new OutlawEngine(canvas, channel, "hex_outlaw", true, null);
      engine._applyRemoteInput({ keyCode: INPUT_KEY.DOWN, pressed: true });
      expect(engine.remoteInputs.down).toBe(true);
    });

    it("sets left input from remote", () => {
      const engine = new OutlawEngine(canvas, channel, "hex_outlaw", true, null);
      engine._applyRemoteInput({ keyCode: INPUT_KEY.LEFT, pressed: true });
      expect(engine.remoteInputs.left).toBe(true);
    });

    it("sets right input from remote", () => {
      const engine = new OutlawEngine(canvas, channel, "hex_outlaw", true, null);
      engine._applyRemoteInput({ keyCode: INPUT_KEY.RIGHT, pressed: true });
      expect(engine.remoteInputs.right).toBe(true);
    });

    it("sets fire input from remote", () => {
      const engine = new OutlawEngine(canvas, channel, "hex_outlaw", true, null);
      engine._applyRemoteInput({ keyCode: INPUT_KEY.FIRE, pressed: true });
      expect(engine.remoteInputs.fire).toBe(true);
    });

    it("releases input from remote", () => {
      const engine = new OutlawEngine(canvas, channel, "hex_outlaw", true, null);
      engine.remoteInputs.fire = true;
      engine._applyRemoteInput({ keyCode: INPUT_KEY.FIRE, pressed: false });
      expect(engine.remoteInputs.fire).toBe(false);
    });

    it("ignores unknown keyCode", () => {
      const engine = new OutlawEngine(canvas, channel, "hex_outlaw", true, null);
      expect(() => engine._applyRemoteInput({ keyCode: 99, pressed: true })).not.toThrow();
      // All inputs should remain false
      expect(engine.remoteInputs.up).toBe(false);
      expect(engine.remoteInputs.fire).toBe(false);
    });
  });

  describe("_handleMessage dispatch", () => {
    it("host ignores GAME_STATE messages", () => {
      const engine = new OutlawEngine(canvas, channel, "hex_outlaw", true, null);
      const state = createInitialState(GAME_MODE.QUICK_DRAW);
      state.score1 = 5;
      const buf = encodeGameState(state, BULLET_SPEED_X);
      engine._handleMessage({ data: buf });
      expect(engine.gameState.score1).toBe(0); // Not applied
    });

    it("peer applies GAME_STATE messages", () => {
      const engine = new OutlawEngine(canvas, channel, "hex_outlaw", false, null);
      engine.colors = {
        bg: "#000",
        fg: "#fff",
        accent: "#0ff",
        muted: "#333",
        glow: "rgba(0,0,0,0)",
        warning: "#f00",
        rope: "#a80",
        ring: "#110",
        hit: "#fff",
      };
      const state = createInitialState(GAME_MODE.QUICK_DRAW);
      state.score1 = 7;
      state.phase = PHASE.PLAYING;
      const buf = encodeGameState(state, BULLET_SPEED_X);
      engine._handleMessage({ data: buf });
      expect(engine.gameState.score1).toBe(7);
      expect(engine.gameState.phase).toBe(PHASE.PLAYING);
    });

    it("host handles PLAYER_INPUT messages", () => {
      const engine = new OutlawEngine(canvas, channel, "hex_outlaw", true, null);
      const buf = encodePlayerInput(INPUT_KEY.FIRE, true);
      engine._handleMessage({ data: buf });
      expect(engine.remoteInputs.fire).toBe(true);
    });

    it("peer ignores PLAYER_INPUT messages", () => {
      const engine = new OutlawEngine(canvas, channel, "hex_outlaw", false, null);
      const buf = encodePlayerInput(INPUT_KEY.FIRE, true);
      engine._handleMessage({ data: buf });
      expect(engine.remoteInputs.fire).toBe(false);
    });

    it("host handles GAME_READY and starts countdown", () => {
      const engine = new OutlawEngine(canvas, channel, "hex_outlaw", true, null);
      engine.start();
      engine.colors = {
        bg: "#000",
        fg: "#fff",
        accent: "#0ff",
        muted: "#333",
        glow: "rgba(0,0,0,0)",
        warning: "#f00",
        rope: "#a80",
        ring: "#110",
        hit: "#fff",
      };
      const buf = encodeGameReady();
      engine._handleMessage({ data: buf });
      expect(engine.peerReady).toBe(true);
      expect(engine.gameState.phase).toBe(PHASE.COUNTDOWN);
      engine.stop();
    });

    it("host ignores duplicate GAME_READY", () => {
      const engine = new OutlawEngine(canvas, channel, "hex_outlaw", true, null);
      engine.start();
      engine.colors = {
        bg: "#000",
        fg: "#fff",
        accent: "#0ff",
        muted: "#333",
        glow: "rgba(0,0,0,0)",
        warning: "#f00",
        rope: "#a80",
        ring: "#110",
        hit: "#fff",
      };
      const buf = encodeGameReady();
      engine._handleMessage({ data: buf });
      expect(engine.peerReady).toBe(true);
      // Send again — should not start another countdown
      engine._handleMessage({ data: buf });
      expect(engine.gameState.phase).toBe(PHASE.COUNTDOWN);
      engine.stop();
    });

    it("peer handles GAME_END message", () => {
      const engine = new OutlawEngine(canvas, channel, "hex_outlaw", false, null);
      engine.colors = {
        bg: "#000",
        fg: "#fff",
        accent: "#0ff",
        muted: "#333",
        glow: "rgba(0,0,0,0)",
        warning: "#f00",
        rope: "#a80",
        ring: "#110",
        hit: "#fff",
      };
      const buf = encodeGameEnd({
        score1: 10,
        score2: 5,
        winner: 1,
        roundWins1: 2,
        roundWins2: 1,
      });
      engine._handleMessage({ data: buf });
      expect(engine.gameState.phase).toBe(PHASE.MATCH_OVER);
      expect(engine.gameState.roundWins1).toBe(2);
    });

    it("ignores non-ArrayBuffer messages", () => {
      const engine = new OutlawEngine(canvas, channel, "hex_outlaw", true, null);
      expect(() => engine._handleMessage({ data: "not a buffer" })).not.toThrow();
    });

    it("ignores empty ArrayBuffer", () => {
      const engine = new OutlawEngine(canvas, channel, "hex_outlaw", true, null);
      expect(() => engine._handleMessage({ data: new ArrayBuffer(0) })).not.toThrow();
    });
  });

  describe("_setLocalInput", () => {
    it("sets all input types", () => {
      const engine = new OutlawEngine(canvas, channel, "hex_outlaw", true, null);
      engine._setLocalInput(INPUT_KEY.UP, true);
      engine._setLocalInput(INPUT_KEY.DOWN, true);
      engine._setLocalInput(INPUT_KEY.LEFT, true);
      engine._setLocalInput(INPUT_KEY.RIGHT, true);
      engine._setLocalInput(INPUT_KEY.FIRE, true);
      expect(engine.localInputs.up).toBe(true);
      expect(engine.localInputs.down).toBe(true);
      expect(engine.localInputs.left).toBe(true);
      expect(engine.localInputs.right).toBe(true);
      expect(engine.localInputs.fire).toBe(true);
    });
  });

  describe("stop cleanup", () => {
    it("disposes audio context on stop", () => {
      const engine = new OutlawEngine(canvas, channel, "hex_outlaw", true, null);
      engine.start();
      // Trigger audio context creation
      engine.audio.playCountdown();
      expect(engine.audio._ctx).not.toBeNull();
      engine.stop();
      expect(engine.audio._ctx).toBeNull();
    });

    it("clears phaseTimer on stop", () => {
      const engine = new OutlawEngine(canvas, channel, "hex_outlaw", true, null);
      engine.start();
      engine.phaseTimer = setTimeout(() => {}, 10000);
      engine.stop();
      expect(engine.phaseTimer).toBeNull();
    });
  });
});
