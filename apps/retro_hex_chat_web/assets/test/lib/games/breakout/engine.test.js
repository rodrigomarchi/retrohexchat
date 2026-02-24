import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import {
  PHASE,
  MSG_TYPE,
  TOTAL_BLOCKS,
  encodeGameState,
  encodePlayerInput,
  encodeGameEnd,
  encodeGameReady,
} from "../../../../js/lib/games/breakout/protocol.js";
import {
  createInitialState,
  CANVAS_W,
  CANVAS_H,
} from "../../../../js/lib/games/breakout/physics.js";

// Must mock breakout_audio before importing BreakoutEngine
vi.mock("../../../../js/lib/games/breakout/audio.js", () => ({
  BreakoutAudio: function () {
    return {
      playPaddleHit: vi.fn(),
      playWallBounce: vi.fn(),
      playBlockHit: vi.fn(),
      playLifeLost: vi.fn(),
      playCountdown: vi.fn(),
      playWin: vi.fn(),
      playLose: vi.fn(),
    };
  },
}));

// Must mock breakout_renderer
vi.mock("../../../../js/lib/games/breakout/renderer.js", () => ({
  getColors: vi.fn(() => ({
    bg: "#0a0a1a",
    fg: "#00ffcc",
    accent: "#ff0066",
    muted: "#1a3a4a",
    glow: "rgba(0,255,204,0.2)",
    warning: "#ffaa00",
  })),
  render: vi.fn(),
}));

const { BreakoutEngine } = await import("../../../../js/lib/games/breakout/engine.js");
const { render, getColors } = await import("../../../../js/lib/games/breakout/renderer.js");

function createMockChannel() {
  return {
    readyState: "open",
    send: vi.fn(),
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
  };
}

function createMockCanvas() {
  const canvas = document.createElement("canvas");
  canvas.width = CANVAS_W;
  canvas.height = CANVAS_H;

  const mockCtx = {
    fillStyle: "",
    strokeStyle: "",
    lineWidth: 0,
    globalAlpha: 1.0,
    font: "",
    textAlign: "",
    textBaseline: "",
    shadowColor: "transparent",
    shadowBlur: 0,
    fillRect: vi.fn(),
    strokeRect: vi.fn(),
    fillText: vi.fn(),
    beginPath: vi.fn(),
    moveTo: vi.fn(),
    lineTo: vi.fn(),
    stroke: vi.fn(),
    setLineDash: vi.fn(),
    save: vi.fn(),
    restore: vi.fn(),
    createRadialGradient: vi.fn(() => ({
      addColorStop: vi.fn(),
    })),
  };
  canvas.getContext = vi.fn(() => mockCtx);

  return canvas;
}

describe("BreakoutEngine", () => {
  let engine;
  let channel;
  let canvas;
  let originalRAF;
  let originalCAF;

  beforeEach(() => {
    channel = createMockChannel();
    canvas = createMockCanvas();
    vi.clearAllMocks();

    originalRAF = globalThis.requestAnimationFrame;
    originalCAF = globalThis.cancelAnimationFrame;
    globalThis.requestAnimationFrame = vi.fn(() => 42);
    globalThis.cancelAnimationFrame = vi.fn();
  });

  afterEach(() => {
    if (engine) {
      engine.stop();
      engine = null;
    }
    globalThis.requestAnimationFrame = originalRAF;
    globalThis.cancelAnimationFrame = originalCAF;
  });

  describe("constructor", () => {
    it("initializes with game state", () => {
      engine = new BreakoutEngine(canvas, channel, "block_breakers", true, null);
      expect(engine.gameState).toBeDefined();
      expect(engine.gameState.phase).toBe(PHASE.WAITING);
    });

    it("sets isHost flag", () => {
      engine = new BreakoutEngine(canvas, channel, "block_breakers", true, null);
      expect(engine.isHost).toBe(true);
    });

    it("stores onGameEnd callback", () => {
      const cb = vi.fn();
      engine = new BreakoutEngine(canvas, channel, "block_breakers", true, cb);
      expect(engine.onGameEnd).toBe(cb);
    });

    it("initializes remote inputs for left/right", () => {
      engine = new BreakoutEngine(canvas, channel, "block_breakers", true, null);
      expect(engine.remoteInputs).toEqual({ left: false, right: false });
    });

    it("initializes with all blocks", () => {
      engine = new BreakoutEngine(canvas, channel, "block_breakers", true, null);
      expect(engine.gameState.blocks).toHaveLength(TOTAL_BLOCKS);
      expect(engine.gameState.blocksRemaining).toBe(TOTAL_BLOCKS);
    });

    it("initializes with 3 lives", () => {
      engine = new BreakoutEngine(canvas, channel, "block_breakers", true, null);
      expect(engine.gameState.lives).toBe(3);
    });
  });

  describe("start", () => {
    it("sets running to true", () => {
      engine = new BreakoutEngine(canvas, channel, "block_breakers", true, null);
      engine.start();
      expect(engine.running).toBe(true);
    });

    it("host does not send GAME_READY", () => {
      engine = new BreakoutEngine(canvas, channel, "block_breakers", true, null);
      engine.start();
      const sentMessages = channel.send.mock.calls;
      for (const call of sentMessages) {
        const buf = call[0];
        if (buf instanceof ArrayBuffer) {
          const view = new Uint8Array(buf);
          expect(view[0]).not.toBe(MSG_TYPE.GAME_READY);
        }
      }
    });

    it("peer sends GAME_READY on start", () => {
      engine = new BreakoutEngine(canvas, channel, "block_breakers", false, null);
      engine.start();
      expect(channel.send).toHaveBeenCalled();
      const buf = channel.send.mock.calls[0][0];
      const view = new Uint8Array(buf);
      expect(view[0]).toBe(MSG_TYPE.GAME_READY);
    });

    it("reads colors from canvas", () => {
      engine = new BreakoutEngine(canvas, channel, "block_breakers", true, null);
      engine.start();
      expect(getColors).toHaveBeenCalledWith(canvas);
      expect(engine.colors).toBeDefined();
    });

    it("renders initial state", () => {
      engine = new BreakoutEngine(canvas, channel, "block_breakers", true, null);
      engine.start();
      expect(render).toHaveBeenCalled();
    });
  });

  describe("stop", () => {
    it("sets running to false", () => {
      engine = new BreakoutEngine(canvas, channel, "block_breakers", true, null);
      engine.start();
      engine.stop();
      expect(engine.running).toBe(false);
    });

    it("clears phase timer", () => {
      engine = new BreakoutEngine(canvas, channel, "block_breakers", true, null);
      engine.start();
      engine.phaseTimer = setTimeout(() => {}, 10000);
      engine.stop();
      expect(engine.phaseTimer).toBeNull();
    });

    it("cancels animation frame", () => {
      engine = new BreakoutEngine(canvas, channel, "block_breakers", true, null);
      engine.start();
      engine.animFrame = 99;
      engine.stop();
      expect(engine.animFrame).toBeNull();
      expect(globalThis.cancelAnimationFrame).toHaveBeenCalledWith(99);
    });
  });

  describe("_handleMessage (host)", () => {
    it("processes GAME_READY from peer", () => {
      engine = new BreakoutEngine(canvas, channel, "block_breakers", true, null);
      engine.start();
      expect(engine.peerReady).toBe(false);

      const buf = encodeGameReady();
      engine._handleMessage({ data: buf });

      expect(engine.peerReady).toBe(true);
      expect(engine.gameState.phase).toBe(PHASE.COUNTDOWN);
    });

    it("ignores duplicate GAME_READY", () => {
      engine = new BreakoutEngine(canvas, channel, "block_breakers", true, null);
      engine.start();

      const buf = encodeGameReady();
      engine._handleMessage({ data: buf });
      const countdownCalls1 = engine.audio.playCountdown.mock.calls.length;

      engine._handleMessage({ data: buf });
      const countdownCalls2 = engine.audio.playCountdown.mock.calls.length;

      expect(countdownCalls2).toBe(countdownCalls1);
    });

    it("processes PLAYER_INPUT LEFT pressed", () => {
      engine = new BreakoutEngine(canvas, channel, "block_breakers", true, null);
      engine.start();

      const buf = encodePlayerInput(0, true); // LEFT pressed
      engine._handleMessage({ data: buf });

      expect(engine.remoteInputs.left).toBe(true);
    });

    it("processes PLAYER_INPUT RIGHT released", () => {
      engine = new BreakoutEngine(canvas, channel, "block_breakers", true, null);
      engine.start();
      engine.remoteInputs.right = true;

      const buf = encodePlayerInput(1, false); // RIGHT released
      engine._handleMessage({ data: buf });

      expect(engine.remoteInputs.right).toBe(false);
    });
  });

  describe("_handleMessage (peer)", () => {
    it("applies GAME_STATE from host", () => {
      engine = new BreakoutEngine(canvas, channel, "block_breakers", false, null);
      engine.start();

      const state = {
        ...createInitialState(),
        score: 150,
        lives: 2,
        phase: PHASE.PLAYING,
        ballX: 100,
        ballY: 200,
      };
      const buf = encodeGameState(state);
      engine._handleMessage({ data: buf });

      expect(engine.gameState.score).toBe(150);
      expect(engine.gameState.lives).toBe(2);
      expect(engine.gameState.phase).toBe(PHASE.PLAYING);
    });

    it("processes GAME_END message (win)", () => {
      engine = new BreakoutEngine(canvas, channel, "block_breakers", false, null);
      engine.start();

      const buf = encodeGameEnd(2500, true);
      engine._handleMessage({ data: buf });

      expect(engine.gameState.phase).toBe(PHASE.FINISHED);
      expect(engine.gameState.won).toBe(true);
      expect(engine.gameState.score).toBe(2500);
    });

    it("processes GAME_END message (loss)", () => {
      engine = new BreakoutEngine(canvas, channel, "block_breakers", false, null);
      engine.start();

      const buf = encodeGameEnd(800, false);
      engine._handleMessage({ data: buf });

      expect(engine.gameState.phase).toBe(PHASE.FINISHED);
      expect(engine.gameState.won).toBe(false);
      expect(engine.audio.playLose).toHaveBeenCalled();
    });

    it("ignores PLAYER_INPUT when peer", () => {
      engine = new BreakoutEngine(canvas, channel, "block_breakers", false, null);
      engine.start();

      const buf = encodePlayerInput(0, true);
      engine._handleMessage({ data: buf });

      expect(engine.remoteInputs.left).toBe(false);
    });
  });

  describe("_handleMessage (non-ArrayBuffer)", () => {
    it("ignores non-ArrayBuffer data", () => {
      engine = new BreakoutEngine(canvas, channel, "block_breakers", true, null);
      engine.start();
      expect(() => {
        engine._handleMessage({ data: "not binary" });
      }).not.toThrow();
    });
  });

  describe("key handling", () => {
    it("maps ArrowLeft to LEFT input", () => {
      engine = new BreakoutEngine(canvas, channel, "block_breakers", true, null);
      engine.start();
      engine._handleKeyDown({ key: "ArrowLeft", preventDefault: vi.fn() });
      expect(engine.localInputs.left).toBe(true);
    });

    it("maps ArrowRight to RIGHT input", () => {
      engine = new BreakoutEngine(canvas, channel, "block_breakers", true, null);
      engine.start();
      engine._handleKeyDown({ key: "ArrowRight", preventDefault: vi.fn() });
      expect(engine.localInputs.right).toBe(true);
    });

    it("maps a to LEFT input", () => {
      engine = new BreakoutEngine(canvas, channel, "block_breakers", true, null);
      engine.start();
      engine._handleKeyDown({ key: "a", preventDefault: vi.fn() });
      expect(engine.localInputs.left).toBe(true);
    });

    it("maps d to RIGHT input", () => {
      engine = new BreakoutEngine(canvas, channel, "block_breakers", true, null);
      engine.start();
      engine._handleKeyDown({ key: "d", preventDefault: vi.fn() });
      expect(engine.localInputs.right).toBe(true);
    });

    it("key release clears local input", () => {
      engine = new BreakoutEngine(canvas, channel, "block_breakers", true, null);
      engine.start();
      engine._handleKeyDown({ key: "ArrowLeft", preventDefault: vi.fn() });
      engine._handleKeyUp({ key: "ArrowLeft" });
      expect(engine.localInputs.left).toBe(false);
    });

    it("ignores unmapped keys", () => {
      engine = new BreakoutEngine(canvas, channel, "block_breakers", true, null);
      engine.start();
      const e = { key: "x", preventDefault: vi.fn() };
      engine._handleKeyDown(e);
      expect(e.preventDefault).not.toHaveBeenCalled();
    });

    it("peer sends binary input on keydown", () => {
      engine = new BreakoutEngine(canvas, channel, "block_breakers", false, null);
      engine.start();
      channel.send.mockClear();

      engine._handleKeyDown({ key: "ArrowLeft", preventDefault: vi.fn() });

      const lastCall = channel.send.mock.calls[channel.send.mock.calls.length - 1];
      const buf = lastCall[0];
      expect(buf).toBeInstanceOf(ArrayBuffer);
      const view = new Uint8Array(buf);
      expect(view[0]).toBe(MSG_TYPE.PLAYER_INPUT);
      expect(view[1]).toBe(0); // INPUT_KEY.LEFT
      expect(view[2]).toBe(1); // pressed
    });

    it("peer sends binary input on keyup", () => {
      engine = new BreakoutEngine(canvas, channel, "block_breakers", false, null);
      engine.start();

      engine._handleKeyDown({ key: "ArrowRight", preventDefault: vi.fn() });
      channel.send.mockClear();
      engine._handleKeyUp({ key: "ArrowRight" });

      const lastCall = channel.send.mock.calls[channel.send.mock.calls.length - 1];
      const buf = lastCall[0];
      const view = new Uint8Array(buf);
      expect(view[0]).toBe(MSG_TYPE.PLAYER_INPUT);
      expect(view[1]).toBe(1); // INPUT_KEY.RIGHT
      expect(view[2]).toBe(0); // released
    });

    it("host does not send input over channel", () => {
      engine = new BreakoutEngine(canvas, channel, "block_breakers", true, null);
      engine.start();
      channel.send.mockClear();

      engine._handleKeyDown({ key: "ArrowLeft", preventDefault: vi.fn() });
      expect(channel.send).not.toHaveBeenCalled();
    });
  });

  describe("_handleBlur", () => {
    it("clears all local inputs", () => {
      engine = new BreakoutEngine(canvas, channel, "block_breakers", true, null);
      engine.start();
      engine.localInputs = { left: true, right: true };

      engine._handleBlur();

      expect(engine.localInputs.left).toBe(false);
      expect(engine.localInputs.right).toBe(false);
    });

    it("peer sends release for all keys on blur", () => {
      engine = new BreakoutEngine(canvas, channel, "block_breakers", false, null);
      engine.start();
      channel.send.mockClear();

      engine._handleBlur();

      expect(channel.send).toHaveBeenCalledTimes(2);
    });
  });

  describe("_broadcastState", () => {
    it("sends encoded state when channel is open", () => {
      engine = new BreakoutEngine(canvas, channel, "block_breakers", true, null);
      engine.start();
      channel.send.mockClear();

      engine._broadcastState();

      expect(channel.send).toHaveBeenCalledTimes(1);
      const buf = channel.send.mock.calls[0][0];
      expect(buf).toBeInstanceOf(ArrayBuffer);
      expect(buf.byteLength).toBe(34);
    });

    it("does not send when channel is closed", () => {
      engine = new BreakoutEngine(canvas, channel, "block_breakers", true, null);
      engine.start();
      channel.readyState = "closed";
      channel.send.mockClear();

      engine._broadcastState();

      expect(channel.send).not.toHaveBeenCalled();
    });
  });

  describe("_handleGameFinished (host)", () => {
    it("sends GAME_END to peer on win", () => {
      engine = new BreakoutEngine(canvas, channel, "block_breakers", true, null);
      engine.start();
      engine.gameState.score = 2500;
      engine.gameState.won = true;
      channel.send.mockClear();

      engine._handleGameFinished();

      const gameEndCall = channel.send.mock.calls.find((call) => {
        const view = new Uint8Array(call[0]);
        return view[0] === MSG_TYPE.GAME_END;
      });
      expect(gameEndCall).toBeDefined();
    });

    it("calls onGameEnd callback", () => {
      const onEnd = vi.fn();
      engine = new BreakoutEngine(canvas, channel, "block_breakers", true, onEnd);
      engine.start();
      engine.gameState.score = 2500;
      engine.gameState.won = true;

      engine._handleGameFinished();

      expect(onEnd).toHaveBeenCalledWith({
        score: { p1: 2500, p2: 2500 },
        winner: 0,
      });
    });

    it("calls onGameEnd with -1 winner on loss", () => {
      const onEnd = vi.fn();
      engine = new BreakoutEngine(canvas, channel, "block_breakers", true, onEnd);
      engine.start();
      engine.gameState.score = 800;
      engine.gameState.won = false;

      engine._handleGameFinished();

      expect(onEnd).toHaveBeenCalledWith({
        score: { p1: 800, p2: 800 },
        winner: -1,
      });
    });

    it("plays win audio on victory", () => {
      engine = new BreakoutEngine(canvas, channel, "block_breakers", true, null);
      engine.start();
      engine.gameState.won = true;

      engine._handleGameFinished();

      expect(engine.audio.playWin).toHaveBeenCalled();
    });

    it("plays lose audio on defeat", () => {
      engine = new BreakoutEngine(canvas, channel, "block_breakers", true, null);
      engine.start();
      engine.gameState.won = false;

      engine._handleGameFinished();

      expect(engine.audio.playLose).toHaveBeenCalled();
    });
  });

  describe("_gameLoop phases", () => {
    it("keeps rAF running during LIFE_LOST", () => {
      engine = new BreakoutEngine(canvas, channel, "block_breakers", true, null);
      engine.start();
      engine.running = true;
      engine.colors = getColors(canvas);
      engine.gameState.phase = PHASE.LIFE_LOST;
      engine.gameState.lives = 2;

      engine._gameLoop(0);

      expect(globalThis.requestAnimationFrame).toHaveBeenCalled();
    });

    it("schedules serve timeout only once during LIFE_LOST", () => {
      engine = new BreakoutEngine(canvas, channel, "block_breakers", true, null);
      engine.start();
      engine.running = true;
      engine.colors = getColors(canvas);
      engine.gameState.phase = PHASE.LIFE_LOST;
      engine.gameState.lives = 2;

      engine._gameLoop(0);
      const timer1 = engine.phaseTimer;

      // Second call should not create a new timer
      engine._gameLoop(0);
      const timer2 = engine.phaseTimer;

      expect(timer1).toBe(timer2);
    });

    it("does not schedule rAF when FINISHED", () => {
      engine = new BreakoutEngine(canvas, channel, "block_breakers", true, null);
      engine.start();
      engine.running = true;
      engine.colors = getColors(canvas);
      engine.gameState.phase = PHASE.FINISHED;
      engine.gameState.won = true;
      globalThis.requestAnimationFrame.mockClear();

      engine._gameLoop(0);

      expect(globalThis.requestAnimationFrame).not.toHaveBeenCalled();
    });

    it("tracks exit side as bottom when ball exits bottom", () => {
      engine = new BreakoutEngine(canvas, channel, "block_breakers", true, null);
      engine.start();
      engine.running = true;
      engine.colors = getColors(canvas);
      engine.gameState.phase = PHASE.PLAYING;
      engine.gameState.ballY = CANVAS_H + 10;
      engine.gameState.ballVY = 5;

      engine._gameLoop(0);

      expect(engine.lastExitSide).toBe("bottom");
    });

    it("tracks exit side as top when ball exits top", () => {
      engine = new BreakoutEngine(canvas, channel, "block_breakers", true, null);
      engine.start();
      engine.running = true;
      engine.colors = getColors(canvas);
      engine.gameState.phase = PHASE.PLAYING;
      engine.gameState.ballY = -10;
      engine.gameState.ballVY = -5;

      engine._gameLoop(0);

      expect(engine.lastExitSide).toBe("top");
    });
  });

  describe("countdown flow (host)", () => {
    beforeEach(() => {
      vi.useFakeTimers();
    });

    afterEach(() => {
      vi.useRealTimers();
    });

    it("starts countdown on peer ready", () => {
      engine = new BreakoutEngine(canvas, channel, "block_breakers", true, null);
      engine.start();

      engine._handleMessage({ data: encodeGameReady() });

      expect(engine.gameState.phase).toBe(PHASE.COUNTDOWN);
      expect(engine.gameState.countdown).toBe(3);
      expect(engine.audio.playCountdown).toHaveBeenCalled();
    });

    it("counts down from 3 to 1", () => {
      engine = new BreakoutEngine(canvas, channel, "block_breakers", true, null);
      engine.start();
      engine._handleMessage({ data: encodeGameReady() });

      vi.advanceTimersByTime(1000);
      expect(engine.gameState.countdown).toBe(2);

      vi.advanceTimersByTime(1000);
      expect(engine.gameState.countdown).toBe(1);
    });

    it("transitions to SERVING after countdown", () => {
      engine = new BreakoutEngine(canvas, channel, "block_breakers", true, null);
      engine.start();
      engine._handleMessage({ data: encodeGameReady() });

      vi.advanceTimersByTime(3000);

      expect(engine.gameState.phase).toBe(PHASE.SERVING);
    });
  });
});
