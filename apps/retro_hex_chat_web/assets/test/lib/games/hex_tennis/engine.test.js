import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import {
  PHASE,
  GAME_MODE,
  INPUT_KEY,
  MSG_TYPE,
  encodeGameState,
  encodePlayerInput,
  encodeGameReady,
  encodeGameEnd,
} from "../../../../js/lib/games/hex_tennis/protocol.js";
import { createInitialState } from "../../../../js/lib/games/hex_tennis/physics.js";

// Stub Web Audio API
class MockAudioContext {
  constructor() {
    this.state = "running";
    this.currentTime = 0;
    this.destination = {};
  }
  resume() {
    return Promise.resolve();
  }
  close() {
    return Promise.resolve();
  }
  createOscillator() {
    return {
      type: "sine",
      frequency: { value: 0, setValueAtTime: vi.fn(), linearRampToValueAtTime: vi.fn() },
      connect: vi.fn(function () {
        return this._gain;
      }),
      start: vi.fn(),
      stop: vi.fn(),
      _gain: {
        gain: { value: 1, setValueAtTime: vi.fn(), linearRampToValueAtTime: vi.fn() },
        connect: vi.fn(),
      },
    };
  }
  createGain() {
    return {
      gain: { value: 1, setValueAtTime: vi.fn(), linearRampToValueAtTime: vi.fn() },
      connect: vi.fn(),
    };
  }
}

function createMockCanvas() {
  const ctx = {
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
    fill: vi.fn(),
    arc: vi.fn(),
    ellipse: vi.fn(),
    setLineDash: vi.fn(),
    createRadialGradient: vi.fn(() => ({ addColorStop: vi.fn() })),
    save: vi.fn(),
    restore: vi.fn(),
  };
  return {
    width: 640,
    height: 480,
    getContext: vi.fn(() => ctx),
    style: { getPropertyValue: vi.fn(() => "") },
    _ctx: ctx,
  };
}

function createMockChannel() {
  return {
    readyState: "open",
    send: vi.fn(),
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
  };
}

// Dynamic import so we can set up globals first
let TennisEngine;

beforeEach(async () => {
  globalThis.AudioContext = MockAudioContext;
  globalThis.requestAnimationFrame = vi.fn((cb) => {
    const id = setTimeout(cb, 0);
    return id;
  });
  globalThis.cancelAnimationFrame = vi.fn((id) => clearTimeout(id));
  globalThis.performance = { now: vi.fn(() => 0) };
  globalThis.getComputedStyle = vi.fn(() => ({
    getPropertyValue: vi.fn(() => ""),
  }));

  const mod = await import("../../../../js/lib/games/hex_tennis/engine.js");
  TennisEngine = mod.TennisEngine;
});

afterEach(() => {
  vi.restoreAllMocks();
});

describe("TennisEngine", () => {
  describe("constructor", () => {
    it("sets gameMode from MODE_MAP based on gameId", () => {
      const e = new TennisEngine(
        createMockCanvas(),
        createMockChannel(),
        "hex_tennis",
        true,
        vi.fn(),
      );
      expect(e.mode).toBe(GAME_MODE.CLASSIC);
    });

    it("sets QUICK for hex_tennis_quick", () => {
      const e = new TennisEngine(
        createMockCanvas(),
        createMockChannel(),
        "hex_tennis_quick",
        true,
        vi.fn(),
      );
      expect(e.mode).toBe(GAME_MODE.QUICK);
    });

    it("sets SUDDEN_DEATH for hex_tennis_sudden", () => {
      const e = new TennisEngine(
        createMockCanvas(),
        createMockChannel(),
        "hex_tennis_sudden",
        true,
        vi.fn(),
      );
      expect(e.mode).toBe(GAME_MODE.SUDDEN_DEATH);
    });

    it("creates initial game state", () => {
      const e = new TennisEngine(
        createMockCanvas(),
        createMockChannel(),
        "hex_tennis",
        true,
        vi.fn(),
      );
      expect(e.gameState.phase).toBe(PHASE.WAITING);
      expect(e.gameState.p1Points).toBe(0);
    });

    it("initializes local and remote inputs", () => {
      const e = new TennisEngine(
        createMockCanvas(),
        createMockChannel(),
        "hex_tennis",
        true,
        vi.fn(),
      );
      expect(e.localInputs).toEqual({
        up: false,
        down: false,
        left: false,
        right: false,
        serve: false,
      });
      expect(e.remoteInputs).toEqual({
        up: false,
        down: false,
        left: false,
        right: false,
        serve: false,
      });
    });
  });

  describe("start", () => {
    it("host renders initial state and waits", () => {
      const canvas = createMockCanvas();
      const channel = createMockChannel();
      const e = new TennisEngine(canvas, channel, "hex_tennis", true, vi.fn());
      e.start();
      // Should have rendered (fillRect called for background)
      expect(canvas._ctx.fillRect).toHaveBeenCalled();
      // Should NOT have sent game ready (host waits)
      expect(channel.send).not.toHaveBeenCalled();
      e.stop();
    });

    it("peer sends GAME_READY and renders", () => {
      const canvas = createMockCanvas();
      const channel = createMockChannel();
      const e = new TennisEngine(canvas, channel, "hex_tennis", false, vi.fn());
      e.start();
      expect(channel.send).toHaveBeenCalledTimes(1);
      const sent = channel.send.mock.calls[0][0];
      expect(new DataView(sent).getUint8(0)).toBe(MSG_TYPE.GAME_READY);
      expect(canvas._ctx.fillRect).toHaveBeenCalled();
      e.stop();
    });

    it("registers channel close listener", () => {
      const channel = createMockChannel();
      const e = new TennisEngine(createMockCanvas(), channel, "hex_tennis", true, vi.fn());
      e.start();
      expect(channel.addEventListener).toHaveBeenCalledWith("close", expect.any(Function));
      e.stop();
    });
  });

  describe("stop", () => {
    it("clears phase timer and removes listeners", () => {
      const channel = createMockChannel();
      const e = new TennisEngine(createMockCanvas(), channel, "hex_tennis", true, vi.fn());
      e.start();
      e.phaseTimer = setTimeout(() => {}, 10000);
      e.stop();
      expect(e.running).toBe(false);
      expect(channel.removeEventListener).toHaveBeenCalledWith("close", expect.any(Function));
    });
  });

  describe("_handleMessage (host)", () => {
    it("GAME_READY from peer starts countdown", () => {
      const e = new TennisEngine(
        createMockCanvas(),
        createMockChannel(),
        "hex_tennis",
        true,
        vi.fn(),
      );
      e.start();
      const readyBuf = encodeGameReady();
      e._handleMessage({ data: readyBuf });
      expect(e.peerReady).toBe(true);
      expect(e.gameState.phase).toBe(PHASE.COUNTDOWN);
      e.stop();
    });

    it("PLAYER_INPUT updates remoteInputs", () => {
      const e = new TennisEngine(
        createMockCanvas(),
        createMockChannel(),
        "hex_tennis",
        true,
        vi.fn(),
      );
      e.start();
      const inputBuf = encodePlayerInput(INPUT_KEY.UP, true);
      e._handleMessage({ data: inputBuf });
      expect(e.remoteInputs.up).toBe(true);
      e.stop();
    });

    it("PLAYER_INPUT maps all 5 keys", () => {
      const e = new TennisEngine(
        createMockCanvas(),
        createMockChannel(),
        "hex_tennis",
        true,
        vi.fn(),
      );
      e.start();
      const keys = [
        [INPUT_KEY.UP, "up"],
        [INPUT_KEY.DOWN, "down"],
        [INPUT_KEY.LEFT, "left"],
        [INPUT_KEY.RIGHT, "right"],
        [INPUT_KEY.SERVE, "serve"],
      ];
      for (const [keyCode, prop] of keys) {
        e._handleMessage({ data: encodePlayerInput(keyCode, true) });
        expect(e.remoteInputs[prop]).toBe(true);
        e._handleMessage({ data: encodePlayerInput(keyCode, false) });
        expect(e.remoteInputs[prop]).toBe(false);
      }
      e.stop();
    });

    it("ignores GAME_STATE (host does not receive state)", () => {
      const e = new TennisEngine(
        createMockCanvas(),
        createMockChannel(),
        "hex_tennis",
        true,
        vi.fn(),
      );
      e.start();
      const origPhase = e.gameState.phase;
      const stateBuf = encodeGameState({
        ...createInitialState(0),
        phase: PHASE.RALLY,
        ball: { x: 320, y: 240, vx: 3, vy: -2, speed: 4, height: 0.3, heightVel: 0 },
      });
      e._handleMessage({ data: stateBuf });
      expect(e.gameState.phase).toBe(origPhase);
      e.stop();
    });

    it("ignores non-ArrayBuffer data", () => {
      const e = new TennisEngine(
        createMockCanvas(),
        createMockChannel(),
        "hex_tennis",
        true,
        vi.fn(),
      );
      e.start();
      expect(() => e._handleMessage({ data: "hello" })).not.toThrow();
      expect(() => e._handleMessage({ data: null })).not.toThrow();
      e.stop();
    });

    it("ignores corrupt buffer", () => {
      const e = new TennisEngine(
        createMockCanvas(),
        createMockChannel(),
        "hex_tennis",
        true,
        vi.fn(),
      );
      e.start();
      expect(() => e._handleMessage({ data: new ArrayBuffer(0) })).not.toThrow();
      e.stop();
    });
  });

  describe("_handleMessage (peer)", () => {
    it("GAME_STATE updates gameState and renders", () => {
      const canvas = createMockCanvas();
      const e = new TennisEngine(canvas, createMockChannel(), "hex_tennis", false, vi.fn());
      e.start();
      canvas._ctx.fillRect.mockClear();

      const state = {
        ...createInitialState(0),
        phase: PHASE.RALLY,
        p1x: 100,
        p1y: 400,
        p2x: 200,
        p2y: 80,
        ball: { x: 320, y: 240, vx: 3, vy: -2, speed: 4, height: 0.3, heightVel: 0 },
      };
      // Flatten ball into state for encoding
      const flat = {
        ...state,
        ballX: state.ball.x,
        ballY: state.ball.y,
        ballVX: state.ball.vx,
        ballVY: state.ball.vy,
        ballHeight: state.ball.height,
      };
      const stateBuf = encodeGameState(flat);
      e._handleMessage({ data: stateBuf });
      expect(e.gameState.phase).toBe(PHASE.RALLY);
      expect(canvas._ctx.fillRect).toHaveBeenCalled();
      e.stop();
    });

    it("GAME_END calls onGameEnd", () => {
      const onEnd = vi.fn();
      const e = new TennisEngine(
        createMockCanvas(),
        createMockChannel(),
        "hex_tennis",
        false,
        onEnd,
      );
      e.start();
      const endBuf = encodeGameEnd(6, 4, 1, GAME_MODE.CLASSIC, false);
      e._handleMessage({ data: endBuf });
      expect(e.gameState.phase).toBe(PHASE.GAME_OVER);
      expect(onEnd).toHaveBeenCalledWith(expect.objectContaining({ winner: 1 }));
      e.stop();
    });

    it("ignores PLAYER_INPUT on peer side", () => {
      const e = new TennisEngine(
        createMockCanvas(),
        createMockChannel(),
        "hex_tennis",
        false,
        vi.fn(),
      );
      e.start();
      const inputBuf = encodePlayerInput(INPUT_KEY.UP, true);
      e._handleMessage({ data: inputBuf });
      // Peer should not process inputs
      expect(e.remoteInputs.up).toBe(false);
      e.stop();
    });
  });

  describe("key handling", () => {
    it("Arrow keys update local inputs on host", () => {
      const e = new TennisEngine(
        createMockCanvas(),
        createMockChannel(),
        "hex_tennis",
        true,
        vi.fn(),
      );
      e.start();
      e._handleKeyDown({ key: "ArrowUp", preventDefault: vi.fn() });
      expect(e.localInputs.up).toBe(true);
      e._handleKeyDown({ key: "ArrowDown", preventDefault: vi.fn() });
      expect(e.localInputs.down).toBe(true);
      e._handleKeyDown({ key: "ArrowLeft", preventDefault: vi.fn() });
      expect(e.localInputs.left).toBe(true);
      e._handleKeyDown({ key: "ArrowRight", preventDefault: vi.fn() });
      expect(e.localInputs.right).toBe(true);
      e.stop();
    });

    it("WASD maps same as arrows", () => {
      const e = new TennisEngine(
        createMockCanvas(),
        createMockChannel(),
        "hex_tennis",
        true,
        vi.fn(),
      );
      e.start();
      e._handleKeyDown({ key: "w", preventDefault: vi.fn() });
      expect(e.localInputs.up).toBe(true);
      e._handleKeyDown({ key: "s", preventDefault: vi.fn() });
      expect(e.localInputs.down).toBe(true);
      e._handleKeyDown({ key: "a", preventDefault: vi.fn() });
      expect(e.localInputs.left).toBe(true);
      e._handleKeyDown({ key: "d", preventDefault: vi.fn() });
      expect(e.localInputs.right).toBe(true);
      e.stop();
    });

    it("Space triggers serve input", () => {
      const e = new TennisEngine(
        createMockCanvas(),
        createMockChannel(),
        "hex_tennis",
        true,
        vi.fn(),
      );
      e.start();
      e._handleKeyDown({ key: " ", preventDefault: vi.fn() });
      expect(e.localInputs.serve).toBe(true);
      e.stop();
    });

    it("Shift triggers serve input", () => {
      const e = new TennisEngine(
        createMockCanvas(),
        createMockChannel(),
        "hex_tennis",
        true,
        vi.fn(),
      );
      e.start();
      e._handleKeyDown({ key: "Shift", preventDefault: vi.fn() });
      expect(e.localInputs.serve).toBe(true);
      e.stop();
    });

    it("peer sends PLAYER_INPUT on keydown/keyup", () => {
      const channel = createMockChannel();
      const e = new TennisEngine(createMockCanvas(), channel, "hex_tennis", false, vi.fn());
      e.start();
      channel.send.mockClear(); // clear GAME_READY

      e._handleKeyDown({ key: "ArrowUp", preventDefault: vi.fn() });
      expect(channel.send).toHaveBeenCalledTimes(1);
      const sent = channel.send.mock.calls[0][0];
      expect(new DataView(sent).getUint8(0)).toBe(MSG_TYPE.PLAYER_INPUT);

      e._handleKeyUp({ key: "ArrowUp", preventDefault: vi.fn() });
      expect(channel.send).toHaveBeenCalledTimes(2);
      e.stop();
    });

    it("prevents default for game keys", () => {
      const e = new TennisEngine(
        createMockCanvas(),
        createMockChannel(),
        "hex_tennis",
        true,
        vi.fn(),
      );
      e.start();
      const event = { key: "ArrowUp", preventDefault: vi.fn() };
      e._handleKeyDown(event);
      expect(event.preventDefault).toHaveBeenCalled();
      e.stop();
    });

    it("ignores non-game keys", () => {
      const e = new TennisEngine(
        createMockCanvas(),
        createMockChannel(),
        "hex_tennis",
        true,
        vi.fn(),
      );
      e.start();
      const event = { key: "z", preventDefault: vi.fn() };
      e._handleKeyDown(event);
      expect(event.preventDefault).not.toHaveBeenCalled();
      e.stop();
    });

    it("keyUp releases local inputs", () => {
      const e = new TennisEngine(
        createMockCanvas(),
        createMockChannel(),
        "hex_tennis",
        true,
        vi.fn(),
      );
      e.start();
      e._handleKeyDown({ key: "ArrowUp", preventDefault: vi.fn() });
      expect(e.localInputs.up).toBe(true);
      e._handleKeyUp({ key: "ArrowUp", preventDefault: vi.fn() });
      expect(e.localInputs.up).toBe(false);
      e.stop();
    });
  });

  describe("_handleBlur", () => {
    it("clears all local inputs", () => {
      const e = new TennisEngine(
        createMockCanvas(),
        createMockChannel(),
        "hex_tennis",
        true,
        vi.fn(),
      );
      e.start();
      e.localInputs = { up: true, down: true, left: true, right: true, serve: true };
      e._handleBlur();
      expect(e.localInputs).toEqual({
        up: false,
        down: false,
        left: false,
        right: false,
        serve: false,
      });
      e.stop();
    });

    it("peer sends release for all 5 keys", () => {
      const channel = createMockChannel();
      const e = new TennisEngine(createMockCanvas(), channel, "hex_tennis", false, vi.fn());
      e.start();
      channel.send.mockClear();
      e._handleBlur();
      expect(channel.send).toHaveBeenCalledTimes(5);
      e.stop();
    });
  });

  describe("_handleChannelClose", () => {
    it("sets phase to GAME_OVER and calls onGameEnd with winner=0", () => {
      const onEnd = vi.fn();
      const e = new TennisEngine(
        createMockCanvas(),
        createMockChannel(),
        "hex_tennis",
        true,
        onEnd,
      );
      e.start();
      e._handleChannelClose();
      expect(e.gameState.phase).toBe(PHASE.GAME_OVER);
      expect(onEnd).toHaveBeenCalledWith(expect.objectContaining({ winner: 0 }));
      e.stop();
    });

    it("does not crash if already in GAME_OVER", () => {
      const e = new TennisEngine(
        createMockCanvas(),
        createMockChannel(),
        "hex_tennis",
        true,
        vi.fn(),
      );
      e.start();
      e.gameState.phase = PHASE.GAME_OVER;
      expect(() => e._handleChannelClose()).not.toThrow();
      e.stop();
    });
  });

  describe("countdown flow", () => {
    it("starts at 3 and ticks down", () => {
      vi.useFakeTimers();
      const channel = createMockChannel();
      const e = new TennisEngine(createMockCanvas(), channel, "hex_tennis", true, vi.fn());
      e.start();

      // Trigger countdown via GAME_READY
      e._handleMessage({ data: encodeGameReady() });
      expect(e.gameState.countdown).toBe(3);
      expect(e.gameState.phase).toBe(PHASE.COUNTDOWN);

      vi.advanceTimersByTime(1000);
      expect(e.gameState.countdown).toBe(2);

      vi.advanceTimersByTime(1000);
      expect(e.gameState.countdown).toBe(1);

      vi.advanceTimersByTime(1000);
      expect(e.gameState.phase).toBe(PHASE.SERVING);

      e.stop();
      vi.useRealTimers();
    });

    it("broadcasts state on each tick", () => {
      vi.useFakeTimers();
      const channel = createMockChannel();
      const e = new TennisEngine(createMockCanvas(), channel, "hex_tennis", true, vi.fn());
      e.start();

      e._handleMessage({ data: encodeGameReady() });
      const initialSends = channel.send.mock.calls.length;

      vi.advanceTimersByTime(1000);
      expect(channel.send.mock.calls.length).toBeGreaterThan(initialSends);

      e.stop();
      vi.useRealTimers();
    });
  });

  describe("_broadcastState", () => {
    it("sends encoded state via _safeSend", () => {
      const channel = createMockChannel();
      const e = new TennisEngine(createMockCanvas(), channel, "hex_tennis", true, vi.fn());
      e.start();
      channel.send.mockClear();
      e._broadcastState();
      expect(channel.send).toHaveBeenCalledTimes(1);
      const buf = channel.send.mock.calls[0][0];
      expect(buf.byteLength).toBe(32);
      expect(new DataView(buf).getUint8(0)).toBe(MSG_TYPE.GAME_STATE);
      e.stop();
    });

    it("does not throw on closed channel", () => {
      const channel = createMockChannel();
      channel.readyState = "closed";
      const e = new TennisEngine(createMockCanvas(), channel, "hex_tennis", true, vi.fn());
      e.start();
      expect(() => e._broadcastState()).not.toThrow();
      expect(channel.send).not.toHaveBeenCalled();
      e.stop();
    });
  });

  describe("_handleGameFinished", () => {
    it("sends GAME_END and calls onGameEnd", () => {
      const onEnd = vi.fn();
      const channel = createMockChannel();
      const e = new TennisEngine(createMockCanvas(), channel, "hex_tennis", true, onEnd);
      e.start();
      e.gameState.p1Games = 6;
      e.gameState.p2Games = 4;
      e.gameState.winner = 1;
      e.gameState.phase = PHASE.GAME_OVER;
      channel.send.mockClear();

      e._handleGameFinished();

      // Should send GAME_END
      const endBufs = channel.send.mock.calls.filter(
        (c) => new DataView(c[0]).getUint8(0) === MSG_TYPE.GAME_END,
      );
      expect(endBufs.length).toBe(1);

      // Should call onGameEnd
      expect(onEnd).toHaveBeenCalledWith({
        score: { p1: 6, p2: 4 },
        winner: 1,
      });
      e.stop();
    });

    it("does not crash if onGameEnd is null", () => {
      const e = new TennisEngine(createMockCanvas(), createMockChannel(), "hex_tennis", true, null);
      e.start();
      e.gameState.phase = PHASE.GAME_OVER;
      e.gameState.winner = 1;
      expect(() => e._handleGameFinished()).not.toThrow();
      e.stop();
    });
  });

  describe("serve timer", () => {
    it("auto-serves after timeout", () => {
      vi.useFakeTimers();
      const e = new TennisEngine(
        createMockCanvas(),
        createMockChannel(),
        "hex_tennis",
        true,
        vi.fn(),
      );
      e.start();

      // Start countdown, let it finish
      e._handleMessage({ data: encodeGameReady() });
      vi.advanceTimersByTime(3000); // countdown done → SERVING

      expect(e.gameState.phase).toBe(PHASE.SERVING);

      // serveTimer should be initialized
      expect(e.gameState.serveTimer).toBeGreaterThan(0);

      e.stop();
      vi.useRealTimers();
    });
  });

  describe("host serve restriction", () => {
    it("host cannot serve when server is P2", () => {
      vi.useFakeTimers();
      const e = new TennisEngine(
        createMockCanvas(),
        createMockChannel(),
        "hex_tennis",
        true,
        vi.fn(),
      );
      e.start();
      e._handleMessage({ data: encodeGameReady() });
      vi.advanceTimersByTime(3000); // countdown → SERVING

      e.gameState.server = 2;
      e.localInputs.serve = true;
      const prevPhase = e.gameState.phase;
      e._gameLoop();

      // Should still be in SERVING (not RALLY) — host serve was blocked
      expect(e.gameState.phase).toBe(prevPhase);
      e.stop();
      vi.useRealTimers();
    });

    it("host can serve when server is P1", () => {
      vi.useFakeTimers();
      const e = new TennisEngine(
        createMockCanvas(),
        createMockChannel(),
        "hex_tennis",
        true,
        vi.fn(),
      );
      e.start();
      e._handleMessage({ data: encodeGameReady() });
      vi.advanceTimersByTime(3000);

      e.gameState.server = 1;
      e.localInputs.serve = true;
      e._gameLoop();

      expect(e.gameState.phase).toBe(PHASE.RALLY);
      e.stop();
      vi.useRealTimers();
    });
  });

  describe("peer audio events", () => {
    it("plays hit sound on hitEvent flag", () => {
      const e = new TennisEngine(
        createMockCanvas(),
        createMockChannel(),
        "hex_tennis",
        false,
        vi.fn(),
      );
      e.start();

      const flat = {
        ...createInitialState(0),
        phase: PHASE.RALLY,
        hitEvent: true,
        ballX: 320,
        ballY: 240,
        ballVX: 3,
        ballVY: -2,
        ballHeight: 0.3,
      };
      const stateBuf = encodeGameState(flat);
      // Spy on audio
      const hitSpy = vi.spyOn(e.audio, "playHit");
      e._handleMessage({ data: stateBuf });
      expect(hitSpy).toHaveBeenCalled();
      e.stop();
    });

    it("plays serve sound on serveEvent flag", () => {
      const e = new TennisEngine(
        createMockCanvas(),
        createMockChannel(),
        "hex_tennis",
        false,
        vi.fn(),
      );
      e.start();

      const flat = {
        ...createInitialState(0),
        phase: PHASE.RALLY,
        serveEvent: true,
        ballX: 320,
        ballY: 240,
        ballVX: 3,
        ballVY: -2,
        ballHeight: 0.3,
      };
      const serveSpy = vi.spyOn(e.audio, "playServe");
      e._handleMessage({ data: encodeGameState(flat) });
      expect(serveSpy).toHaveBeenCalled();
      e.stop();
    });

    it("plays fault sound on faultEvent flag", () => {
      const e = new TennisEngine(
        createMockCanvas(),
        createMockChannel(),
        "hex_tennis",
        false,
        vi.fn(),
      );
      e.start();

      const flat = {
        ...createInitialState(0),
        phase: PHASE.RALLY,
        faultEvent: true,
        ballX: 320,
        ballY: 240,
        ballVX: 0,
        ballVY: 0,
        ballHeight: 0,
      };
      const faultSpy = vi.spyOn(e.audio, "playFault");
      e._handleMessage({ data: encodeGameState(flat) });
      expect(faultSpy).toHaveBeenCalled();
      e.stop();
    });

    it("plays net hit sound on netFault flag", () => {
      const e = new TennisEngine(
        createMockCanvas(),
        createMockChannel(),
        "hex_tennis",
        false,
        vi.fn(),
      );
      e.start();

      const flat = {
        ...createInitialState(0),
        phase: PHASE.RALLY,
        netFault: true,
        ballX: 320,
        ballY: 240,
        ballVX: 0,
        ballVY: 0,
        ballHeight: 0,
      };
      const netSpy = vi.spyOn(e.audio, "playNetHit");
      e._handleMessage({ data: encodeGameState(flat) });
      expect(netSpy).toHaveBeenCalled();
      e.stop();
    });

    it("plays out sound on outOfBounds flag", () => {
      const e = new TennisEngine(
        createMockCanvas(),
        createMockChannel(),
        "hex_tennis",
        false,
        vi.fn(),
      );
      e.start();

      const flat = {
        ...createInitialState(0),
        phase: PHASE.RALLY,
        outOfBounds: true,
        outType: 1, // WIDE
        ballX: 320,
        ballY: 240,
        ballVX: 0,
        ballVY: 0,
        ballHeight: 0,
      };
      const outSpy = vi.spyOn(e.audio, "playOut");
      e._handleMessage({ data: encodeGameState(flat) });
      expect(outSpy).toHaveBeenCalled();
      e.stop();
    });

    it("plays ace sound when outType is ACE (3)", () => {
      const e = new TennisEngine(
        createMockCanvas(),
        createMockChannel(),
        "hex_tennis",
        false,
        vi.fn(),
      );
      e.start();

      const flat = {
        ...createInitialState(0),
        phase: PHASE.RALLY,
        outOfBounds: true,
        outType: 3, // ACE
        ballX: 320,
        ballY: 240,
        ballVX: 0,
        ballVY: 0,
        ballHeight: 0,
      };
      const aceSpy = vi.spyOn(e.audio, "playAce");
      e._handleMessage({ data: encodeGameState(flat) });
      expect(aceSpy).toHaveBeenCalled();
      e.stop();
    });

    it("plays point sound on phase transition to POINT", () => {
      const e = new TennisEngine(
        createMockCanvas(),
        createMockChannel(),
        "hex_tennis",
        false,
        vi.fn(),
      );
      e.start();
      e.gameState.phase = PHASE.RALLY; // set previous phase

      const flat = {
        ...createInitialState(0),
        phase: PHASE.POINT,
        ballX: 320,
        ballY: 240,
        ballVX: 0,
        ballVY: 0,
        ballHeight: 0,
      };
      const pointSpy = vi.spyOn(e.audio, "playPoint");
      e._handleMessage({ data: encodeGameState(flat) });
      expect(pointSpy).toHaveBeenCalled();
      e.stop();
    });
  });

  describe("_flattenStateForEncode", () => {
    it("flattens ball object into top-level keys", () => {
      const e = new TennisEngine(
        createMockCanvas(),
        createMockChannel(),
        "hex_tennis",
        true,
        vi.fn(),
      );
      e.start();
      e.gameState.ball = {
        x: 100,
        y: 200,
        vx: 3.5,
        vy: -2.1,
        speed: 5,
        height: 0.4,
        heightVel: 0.06,
      };
      const flat = e._flattenStateForEncode();
      expect(flat.ballX).toBe(100);
      expect(flat.ballY).toBe(200);
      expect(flat.ballVX).toBe(3.5);
      expect(flat.ballVY).toBe(-2.1);
      expect(flat.ballHeight).toBe(0.4);
      e.stop();
    });
  });
});
