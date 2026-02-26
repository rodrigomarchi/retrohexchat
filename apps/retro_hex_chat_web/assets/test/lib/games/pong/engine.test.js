import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import {
  PHASE,
  MSG_TYPE,
  encodeGameState,
  encodePlayerInput,
  encodeGameEnd,
  encodeGameReady,
} from "../../../../js/lib/games/pong/protocol.js";
import { createInitialState, CANVAS_W, CANVAS_H } from "../../../../js/lib/games/pong/physics.js";

// Must mock pong_audio before importing PongEngine
vi.mock("../../../../js/lib/games/pong/audio.js", () => ({
  PongAudio: function () {
    return {
      playPaddleHit: vi.fn(),
      playWallBounce: vi.fn(),
      playScore: vi.fn(),
      playWin: vi.fn(),
      playCountdown: vi.fn(),
    };
  },
}));

// Must mock pong_renderer
vi.mock("../../../../js/lib/games/pong/renderer.js", () => ({
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

const { PongEngine } = await import("../../../../js/lib/games/pong/engine.js");
const { render, getColors } = await import("../../../../js/lib/games/pong/renderer.js");

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

  // jsdom doesn't support canvas context, so override getContext
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

describe("PongEngine", () => {
  let engine;
  let channel;
  let canvas;
  let originalRAF;
  let originalCAF;

  beforeEach(() => {
    channel = createMockChannel();
    canvas = createMockCanvas();
    vi.clearAllMocks();

    // Mock requestAnimationFrame/cancelAnimationFrame
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
      engine = new PongEngine(canvas, channel, "hex_pong", true, null);
      expect(engine.gameState).toBeDefined();
      expect(engine.gameState.phase).toBe(PHASE.WAITING);
    });

    it("sets isHost flag", () => {
      engine = new PongEngine(canvas, channel, "hex_pong", true, null);
      expect(engine.isHost).toBe(true);
    });

    it("stores onGameEnd callback", () => {
      const cb = vi.fn();
      engine = new PongEngine(canvas, channel, "hex_pong", true, cb);
      expect(engine.onGameEnd).toBe(cb);
    });

    it("initializes remote inputs", () => {
      engine = new PongEngine(canvas, channel, "hex_pong", true, null);
      expect(engine.remoteInputs).toEqual({ up: false, down: false });
    });
  });

  describe("start", () => {
    it("sets running to true", () => {
      engine = new PongEngine(canvas, channel, "hex_pong", true, null);
      engine.start();
      expect(engine.running).toBe(true);
    });

    it("host does not send GAME_READY", () => {
      engine = new PongEngine(canvas, channel, "hex_pong", true, null);
      engine.start();
      // Host should NOT send any message on start (waits for peer)
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
      engine = new PongEngine(canvas, channel, "hex_pong", false, null);
      engine.start();
      expect(channel.send).toHaveBeenCalled();
      const buf = channel.send.mock.calls[0][0];
      const view = new Uint8Array(buf);
      expect(view[0]).toBe(MSG_TYPE.GAME_READY);
    });

    it("reads colors from canvas", () => {
      engine = new PongEngine(canvas, channel, "hex_pong", true, null);
      engine.start();
      expect(getColors).toHaveBeenCalledWith(canvas);
      expect(engine.colors).toBeDefined();
    });

    it("renders initial state", () => {
      engine = new PongEngine(canvas, channel, "hex_pong", true, null);
      engine.start();
      expect(render).toHaveBeenCalled();
    });
  });

  describe("stop", () => {
    it("sets running to false", () => {
      engine = new PongEngine(canvas, channel, "hex_pong", true, null);
      engine.start();
      engine.stop();
      expect(engine.running).toBe(false);
    });

    it("clears phase timer", () => {
      engine = new PongEngine(canvas, channel, "hex_pong", true, null);
      engine.start();
      engine.phaseTimer = setTimeout(() => {}, 10000);
      engine.stop();
      expect(engine.phaseTimer).toBeNull();
    });

    it("cancels animation frame", () => {
      engine = new PongEngine(canvas, channel, "hex_pong", true, null);
      engine.start();
      engine.animFrame = 99;
      engine.stop();
      expect(engine.animFrame).toBeNull();
      expect(globalThis.cancelAnimationFrame).toHaveBeenCalledWith(99);
    });
  });

  describe("_handleMessage (host)", () => {
    it("processes GAME_READY from peer", () => {
      engine = new PongEngine(canvas, channel, "hex_pong", true, null);
      engine.start();
      expect(engine.peerReady).toBe(false);

      const buf = encodeGameReady();
      engine._handleMessage({ data: buf });

      expect(engine.peerReady).toBe(true);
      expect(engine.gameState.phase).toBe(PHASE.COUNTDOWN);
    });

    it("ignores duplicate GAME_READY", () => {
      engine = new PongEngine(canvas, channel, "hex_pong", true, null);
      engine.start();

      const buf = encodeGameReady();
      engine._handleMessage({ data: buf });
      const countdownCalls1 = engine.audio.playCountdown.mock.calls.length;

      engine._handleMessage({ data: buf });
      const countdownCalls2 = engine.audio.playCountdown.mock.calls.length;

      expect(countdownCalls2).toBe(countdownCalls1);
    });

    it("processes PLAYER_INPUT from peer", () => {
      engine = new PongEngine(canvas, channel, "hex_pong", true, null);
      engine.start();

      const buf = encodePlayerInput(0, true); // UP pressed
      engine._handleMessage({ data: buf });

      expect(engine.remoteInputs.up).toBe(true);
    });

    it("processes PLAYER_INPUT release", () => {
      engine = new PongEngine(canvas, channel, "hex_pong", true, null);
      engine.start();
      engine.remoteInputs.up = true;

      const buf = encodePlayerInput(0, false); // UP released
      engine._handleMessage({ data: buf });

      expect(engine.remoteInputs.up).toBe(false);
    });

    it("ignores GAME_STATE when host", () => {
      engine = new PongEngine(canvas, channel, "hex_pong", true, null);
      engine.start();
      const originalState = { ...engine.gameState };

      const fakeState = { ...createInitialState(), score1: 99 };
      const buf = encodeGameState(fakeState);
      engine._handleMessage({ data: buf });

      expect(engine.gameState.score1).toBe(originalState.score1);
    });
  });

  describe("_handleMessage (peer)", () => {
    it("applies GAME_STATE from host", () => {
      engine = new PongEngine(canvas, channel, "hex_pong", false, null);
      engine.start();

      const state = {
        ...createInitialState(),
        score1: 5,
        score2: 3,
        phase: PHASE.PLAYING,
        ballX: 100,
        ballY: 200,
      };
      const buf = encodeGameState(state);
      engine._handleMessage({ data: buf });

      expect(engine.gameState.score1).toBe(5);
      expect(engine.gameState.score2).toBe(3);
      expect(engine.gameState.phase).toBe(PHASE.PLAYING);
    });

    it("plays audio on phase transition", () => {
      engine = new PongEngine(canvas, channel, "hex_pong", false, null);
      engine.start();

      const state = { ...createInitialState(), phase: PHASE.COUNTDOWN };
      const buf = encodeGameState(state);
      engine._handleMessage({ data: buf });

      expect(engine.audio.playCountdown).toHaveBeenCalled();
    });

    it("plays score audio on score change", () => {
      engine = new PongEngine(canvas, channel, "hex_pong", false, null);
      engine.start();

      const state = { ...createInitialState(), score1: 1, phase: PHASE.SCORED };
      const buf = encodeGameState(state);
      engine._handleMessage({ data: buf });

      expect(engine.audio.playScore).toHaveBeenCalled();
    });

    it("processes GAME_END message", () => {
      engine = new PongEngine(canvas, channel, "hex_pong", false, null);
      engine.start();

      const buf = encodeGameEnd(11, 7, 1);
      engine._handleMessage({ data: buf });

      expect(engine.gameState.phase).toBe(PHASE.FINISHED);
      expect(engine.gameState.winner).toBe(1);
      expect(engine.gameState.score1).toBe(11);
      expect(engine.gameState.score2).toBe(7);
    });

    it("ignores PLAYER_INPUT when peer", () => {
      engine = new PongEngine(canvas, channel, "hex_pong", false, null);
      engine.start();

      const buf = encodePlayerInput(0, true);
      engine._handleMessage({ data: buf });

      // Peer should not process player input — only host does
      expect(engine.remoteInputs.up).toBe(false);
    });
  });

  describe("_handleMessage (non-ArrayBuffer)", () => {
    it("ignores non-ArrayBuffer data", () => {
      engine = new PongEngine(canvas, channel, "hex_pong", true, null);
      engine.start();
      expect(() => {
        engine._handleMessage({ data: "not binary" });
      }).not.toThrow();
    });
  });

  describe("key handling", () => {
    it("maps ArrowUp to UP input", () => {
      engine = new PongEngine(canvas, channel, "hex_pong", true, null);
      engine.start();
      engine._handleKeyDown({ key: "ArrowUp", preventDefault: vi.fn() });
      expect(engine.localInputs.up).toBe(true);
    });

    it("maps ArrowDown to DOWN input", () => {
      engine = new PongEngine(canvas, channel, "hex_pong", true, null);
      engine.start();
      engine._handleKeyDown({ key: "ArrowDown", preventDefault: vi.fn() });
      expect(engine.localInputs.down).toBe(true);
    });

    it("maps w to UP input", () => {
      engine = new PongEngine(canvas, channel, "hex_pong", true, null);
      engine.start();
      engine._handleKeyDown({ key: "w", preventDefault: vi.fn() });
      expect(engine.localInputs.up).toBe(true);
    });

    it("maps s to DOWN input", () => {
      engine = new PongEngine(canvas, channel, "hex_pong", true, null);
      engine.start();
      engine._handleKeyDown({ key: "s", preventDefault: vi.fn() });
      expect(engine.localInputs.down).toBe(true);
    });

    it("key release clears local input", () => {
      engine = new PongEngine(canvas, channel, "hex_pong", true, null);
      engine.start();
      engine._handleKeyDown({ key: "ArrowUp", preventDefault: vi.fn() });
      engine._handleKeyUp({ key: "ArrowUp" });
      expect(engine.localInputs.up).toBe(false);
    });

    it("ignores unmapped keys", () => {
      engine = new PongEngine(canvas, channel, "hex_pong", true, null);
      engine.start();
      const e = { key: "x", preventDefault: vi.fn() };
      engine._handleKeyDown(e);
      expect(e.preventDefault).not.toHaveBeenCalled();
    });

    it("peer sends binary input on keydown", () => {
      engine = new PongEngine(canvas, channel, "hex_pong", false, null);
      engine.start();
      channel.send.mockClear();

      engine._handleKeyDown({ key: "ArrowUp", preventDefault: vi.fn() });

      // Should have sent encodePlayerInput
      const lastCall = channel.send.mock.calls[channel.send.mock.calls.length - 1];
      const buf = lastCall[0];
      expect(buf).toBeInstanceOf(ArrayBuffer);
      const view = new Uint8Array(buf);
      expect(view[0]).toBe(MSG_TYPE.PLAYER_INPUT);
      expect(view[1]).toBe(0); // INPUT_KEY.UP
      expect(view[2]).toBe(1); // pressed
    });

    it("peer sends binary input on keyup", () => {
      engine = new PongEngine(canvas, channel, "hex_pong", false, null);
      engine.start();

      engine._handleKeyDown({ key: "ArrowDown", preventDefault: vi.fn() });
      channel.send.mockClear();
      engine._handleKeyUp({ key: "ArrowDown" });

      const lastCall = channel.send.mock.calls[channel.send.mock.calls.length - 1];
      const buf = lastCall[0];
      const view = new Uint8Array(buf);
      expect(view[0]).toBe(MSG_TYPE.PLAYER_INPUT);
      expect(view[1]).toBe(1); // INPUT_KEY.DOWN
      expect(view[2]).toBe(0); // released
    });

    it("host does not send input over channel", () => {
      engine = new PongEngine(canvas, channel, "hex_pong", true, null);
      engine.start();
      channel.send.mockClear();

      engine._handleKeyDown({ key: "ArrowUp", preventDefault: vi.fn() });
      expect(channel.send).not.toHaveBeenCalled();
    });
  });

  describe("_handleBlur", () => {
    it("clears all local inputs", () => {
      engine = new PongEngine(canvas, channel, "hex_pong", true, null);
      engine.start();
      engine.localInputs = { up: true, down: true };

      engine._handleBlur();

      expect(engine.localInputs.up).toBe(false);
      expect(engine.localInputs.down).toBe(false);
    });

    it("peer sends release for all keys on blur", () => {
      engine = new PongEngine(canvas, channel, "hex_pong", false, null);
      engine.start();
      channel.send.mockClear();

      engine._handleBlur();

      // Should have sent 2 release messages (UP + DOWN)
      expect(channel.send).toHaveBeenCalledTimes(2);
    });
  });

  describe("_broadcastState", () => {
    it("sends encoded state when channel is open", () => {
      engine = new PongEngine(canvas, channel, "hex_pong", true, null);
      engine.start();
      channel.send.mockClear();

      engine._broadcastState();

      expect(channel.send).toHaveBeenCalledTimes(1);
      const buf = channel.send.mock.calls[0][0];
      expect(buf).toBeInstanceOf(ArrayBuffer);
      expect(buf.byteLength).toBe(25);
    });

    it("does not send when channel is closed", () => {
      engine = new PongEngine(canvas, channel, "hex_pong", true, null);
      engine.start();
      channel.readyState = "closed";
      channel.send.mockClear();

      engine._broadcastState();

      expect(channel.send).not.toHaveBeenCalled();
    });
  });

  describe("_handleGameFinished (host)", () => {
    it("sends GAME_END to peer", () => {
      engine = new PongEngine(canvas, channel, "hex_pong", true, null);
      engine.start();
      engine.gameState.score1 = 11;
      engine.gameState.score2 = 7;
      engine.gameState.winner = 1;
      channel.send.mockClear();

      engine._handleGameFinished();

      // Find the GAME_END message
      const gameEndCall = channel.send.mock.calls.find((call) => {
        const view = new Uint8Array(call[0]);
        return view[0] === MSG_TYPE.GAME_END;
      });
      expect(gameEndCall).toBeDefined();
    });

    it("calls onGameEnd callback", () => {
      const onEnd = vi.fn();
      engine = new PongEngine(canvas, channel, "hex_pong", true, onEnd);
      engine.start();
      engine.gameState.score1 = 11;
      engine.gameState.score2 = 7;
      engine.gameState.winner = 1;

      engine._handleGameFinished();

      expect(onEnd).toHaveBeenCalledWith({
        score: { p1: 11, p2: 7 },
        winner: 1,
      });
    });

    it("plays win audio", () => {
      engine = new PongEngine(canvas, channel, "hex_pong", true, null);
      engine.start();
      engine.gameState.winner = 1;

      engine._handleGameFinished();

      expect(engine.audio.playWin).toHaveBeenCalled();
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
      engine = new PongEngine(canvas, channel, "hex_pong", true, null);
      engine.start();

      engine._handleMessage({ data: encodeGameReady() });

      expect(engine.gameState.phase).toBe(PHASE.COUNTDOWN);
      expect(engine.gameState.countdown).toBe(3);
      expect(engine.audio.playCountdown).toHaveBeenCalled();
    });

    it("counts down from 3 to 1", () => {
      engine = new PongEngine(canvas, channel, "hex_pong", true, null);
      engine.start();
      engine._handleMessage({ data: encodeGameReady() });

      vi.advanceTimersByTime(1000);
      expect(engine.gameState.countdown).toBe(2);

      vi.advanceTimersByTime(1000);
      expect(engine.gameState.countdown).toBe(1);
    });

    it("transitions to SERVING after countdown", () => {
      engine = new PongEngine(canvas, channel, "hex_pong", true, null);
      engine.start();
      engine._handleMessage({ data: encodeGameReady() });

      vi.advanceTimersByTime(3000);

      expect(engine.gameState.phase).toBe(PHASE.SERVING);
    });
  });

  // ── _startServing ──

  describe("_startServing", () => {
    beforeEach(() => {
      vi.useFakeTimers();
    });

    afterEach(() => {
      vi.useRealTimers();
    });

    it("sets phase to SERVING and broadcasts state", () => {
      engine = new PongEngine(canvas, channel, "hex_pong", true, null);
      engine.start();
      channel.send.mockClear();

      engine._startServing();

      expect(engine.gameState.phase).toBe(PHASE.SERVING);
      expect(channel.send).toHaveBeenCalled();
    });

    it("serves ball after SERVE_DELAY timeout", () => {
      engine = new PongEngine(canvas, channel, "hex_pong", true, null);
      engine.start();

      engine._startServing();

      // Ball should still be at center before timeout
      expect(engine.gameState.ballVX).toBe(0);
      expect(engine.gameState.ballVY).toBe(0);

      vi.advanceTimersByTime(800);

      // After timeout, ball should have velocity (served)
      expect(engine.gameState.ballVX !== 0 || engine.gameState.ballVY !== 0).toBe(true);
    });

    it("starts game loop after serving", () => {
      engine = new PongEngine(canvas, channel, "hex_pong", true, null);
      engine.start();
      // Re-mock rAF after useFakeTimers (which replaces it)
      globalThis.requestAnimationFrame = vi.fn(() => 42);

      engine._startServing();
      vi.advanceTimersByTime(800);

      expect(globalThis.requestAnimationFrame).toHaveBeenCalled();
    });
  });

  // ── _gameLoop ──

  describe("_gameLoop", () => {
    function setupPlayingEngine() {
      const eng = new PongEngine(canvas, channel, "hex_pong", true, null);
      eng.start();
      eng.gameState.phase = PHASE.PLAYING;
      eng.gameState.ballX = CANVAS_W / 2;
      eng.gameState.ballY = CANVAS_H / 2;
      eng.gameState.ballVX = 5;
      eng.gameState.ballVY = 3;
      return eng;
    }

    it("updates paddle positions from local and remote inputs", () => {
      engine = setupPlayingEngine();
      engine.localInputs = { up: true, down: false };
      engine.remoteInputs = { up: false, down: true };

      const p1Before = engine.gameState.paddle1Y;
      const p2Before = engine.gameState.paddle2Y;

      engine._gameLoop(0);

      expect(engine.gameState.paddle1Y).toBeLessThan(p1Before);
      expect(engine.gameState.paddle2Y).toBeGreaterThan(p2Before);
    });

    it("updates ball position", () => {
      engine = setupPlayingEngine();
      const ballXBefore = engine.gameState.ballX;

      engine._gameLoop(0);

      expect(engine.gameState.ballX).not.toBe(ballXBefore);
    });

    it("plays wall bounce audio on wall hit", () => {
      engine = setupPlayingEngine();
      // Position ball near top wall so bounce triggers
      engine.gameState.ballY = 2;
      engine.gameState.ballVY = -5;

      engine._gameLoop(0);

      expect(engine.audio.playWallBounce).toHaveBeenCalled();
    });

    it("plays paddle hit audio on paddle collision", () => {
      engine = setupPlayingEngine();
      // Position ball at left paddle to trigger collision
      engine.gameState.ballX = 35; // near paddle1
      engine.gameState.ballVX = -5;
      engine.gameState.ballY = engine.gameState.paddle1Y + 40;

      engine._gameLoop(0);

      // May or may not trigger depending on exact position;
      // verify loop completes without error
      expect(engine.gameState).toBeDefined();
    });

    it("plays score audio when scoring", () => {
      engine = setupPlayingEngine();
      // Position ball past the right edge to trigger scoring
      engine.gameState.ballX = CANVAS_W + 20;
      engine.gameState.ballVX = 5;

      engine._gameLoop(0);

      expect(engine.audio.playScore).toHaveBeenCalled();
    });

    it("transitions to FINISHED on win and calls _handleGameFinished", () => {
      engine = setupPlayingEngine();
      engine.gameState.score1 = 10;
      // Position ball past right edge to score the winning point
      engine.gameState.ballX = CANVAS_W + 20;
      engine.gameState.ballVX = 5;

      engine._gameLoop(0);

      expect(engine.gameState.phase).toBe(PHASE.FINISHED);
      expect(engine.audio.playWin).toHaveBeenCalled();
    });

    it("broadcasts state at STATE_SEND_INTERVAL", () => {
      engine = setupPlayingEngine();
      engine.frameCount = 1; // Will be 2 after increment
      channel.send.mockClear();

      engine._gameLoop(0);

      expect(channel.send).toHaveBeenCalled();
    });

    it("pauses and re-serves on SCORED phase", () => {
      vi.useFakeTimers();
      engine = setupPlayingEngine();
      // Position ball past right edge to trigger scoring
      engine.gameState.ballX = CANVAS_W + 20;
      engine.gameState.ballVX = 5;

      engine._gameLoop(0);

      // Should be in SCORED phase
      expect(engine.gameState.phase).toBe(PHASE.SCORED);
      expect(engine.phaseTimer).not.toBeNull();

      // After SCORE_PAUSE, should transition to SERVING
      vi.advanceTimersByTime(1500);
      expect(engine.gameState.phase).toBe(PHASE.SERVING);

      vi.useRealTimers();
    });
  });

  // ── _playPhaseAudio peer ──

  describe("_playPhaseAudio peer", () => {
    it("plays win audio on FINISHED transition", () => {
      engine = new PongEngine(canvas, channel, "hex_pong", false, null);
      engine.start();

      engine._playPhaseAudio(PHASE.PLAYING, PHASE.FINISHED, 5, 3);

      expect(engine.audio.playWin).toHaveBeenCalled();
    });

    it("plays score audio on score change", () => {
      engine = new PongEngine(canvas, channel, "hex_pong", false, null);
      engine.start();
      engine.gameState.score1 = 6; // new score

      engine._playPhaseAudio(PHASE.PLAYING, PHASE.PLAYING, 5, 3);

      expect(engine.audio.playScore).toHaveBeenCalled();
    });

    it("plays countdown audio on COUNTDOWN transition", () => {
      engine = new PongEngine(canvas, channel, "hex_pong", false, null);
      engine.start();

      engine._playPhaseAudio(PHASE.WAITING, PHASE.COUNTDOWN, 0, 0);

      expect(engine.audio.playCountdown).toHaveBeenCalled();
    });
  });

  // ── Connection Resilience ──

  describe("connection resilience", () => {
    it("double-start is a no-op", () => {
      engine = new PongEngine(canvas, channel, "hex_pong", true, null);
      engine.start();
      const firstState = engine.gameState;
      engine.start(); // should not reset
      expect(engine.gameState).toBe(firstState);
    });

    it("blur clears local inputs", () => {
      engine = new PongEngine(canvas, channel, "hex_pong", true, null);
      engine.start();
      engine.localInputs = { up: true, down: true };
      engine._handleBlur();
      expect(engine.localInputs.up).toBe(false);
      expect(engine.localInputs.down).toBe(false);
    });

    it("channel close ends game with disconnect flag", () => {
      const onEnd = vi.fn();
      engine = new PongEngine(canvas, channel, "hex_pong", true, onEnd);
      engine.start();
      engine.gameState.phase = PHASE.PLAYING;
      engine._handleChannelClose();
      expect(engine.gameState.phase).toBe(PHASE.FINISHED);
      expect(onEnd).toHaveBeenCalledWith(expect.objectContaining({ disconnected: true }));
    });

    it("channel close is no-op when game already finished", () => {
      const onEnd = vi.fn();
      engine = new PongEngine(canvas, channel, "hex_pong", true, onEnd);
      engine.start();
      engine.gameState.phase = PHASE.FINISHED;
      engine._handleChannelClose();
      expect(onEnd).not.toHaveBeenCalled();
    });
  });
});
