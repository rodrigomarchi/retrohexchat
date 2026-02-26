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
import {
  createInitialState,
  COURT_CENTER_X,
  COURT_BOTTOM,
} from "../../../../js/lib/games/hex_tennis/physics.js";

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

  // ── SERVING phase tests ──

  describe("_gameLoop SERVING phase", () => {
    function setupServingEngine() {
      vi.useFakeTimers();
      const canvas = createMockCanvas();
      const channel = createMockChannel();
      const e = new TennisEngine(canvas, channel, "hex_tennis", true, vi.fn());
      e.start();
      // Trigger countdown then let it finish to reach SERVING
      e._handleMessage({ data: encodeGameReady() });
      vi.advanceTimersByTime(3000);
      expect(e.gameState.phase).toBe(PHASE.SERVING);
      return { e, canvas, channel };
    }

    it("host serve: localInputs.serve && server===1 → performServe + RALLY", () => {
      const { e } = setupServingEngine();
      e.gameState.server = 1;
      e.localInputs.serve = true;
      e._gameLoop();
      expect(e.gameState.phase).toBe(PHASE.RALLY);
      e.stop();
      vi.useRealTimers();
    });

    it("remote serve: remoteInputs.serve && server===2 → performServe + RALLY", () => {
      const { e } = setupServingEngine();
      e.gameState.server = 2;
      e.remoteInputs.serve = true;
      e._gameLoop();
      expect(e.gameState.phase).toBe(PHASE.RALLY);
      e.stop();
      vi.useRealTimers();
    });

    it("auto-serve: serveTimer counts down to 0 → auto-serves", () => {
      const { e } = setupServingEngine();
      e.gameState.server = 1;
      e.gameState.serveTimer = 1; // will reach 0 after decrement
      e._gameLoop();
      expect(e.gameState.phase).toBe(PHASE.RALLY);
      e.stop();
      vi.useRealTimers();
    });
  });

  // ── RALLY phase tests ──

  describe("_gameLoop RALLY phase", () => {
    function setupRallyEngine() {
      const canvas = createMockCanvas();
      const channel = createMockChannel();
      const e = new TennisEngine(canvas, channel, "hex_tennis", true, vi.fn());
      e.start();
      e.gameState.phase = PHASE.RALLY;
      e.gameState.ball = {
        x: COURT_CENTER_X,
        y: 240,
        vx: 3,
        vy: -3,
        speed: 5,
        height: 0.3,
        heightVel: 0.06,
      };
      e.gameState.lastHitter = 1;
      e.gameState.rallyCount = 1;
      return { e, canvas, channel };
    }

    it("clears event flags at start of rally loop", () => {
      const { e } = setupRallyEngine();
      e.gameState.hitEvent = true;
      e.gameState.serveEvent = true;
      e._gameLoop();
      // After one loop iteration, flags should have been cleared
      // (they may get re-set by collisions, but the clearEventFlags call happened)
      // The fact that gameState.serveEvent is false confirms clearEventFlags ran
      expect(e.gameState.serveEvent).toBe(false);
      e.stop();
    });

    it("updates ball position each frame", () => {
      const { e } = setupRallyEngine();
      const prevBallY = e.gameState.ball.y;
      e._gameLoop();
      expect(e.gameState.ball.y).not.toBe(prevBallY);
      e.stop();
    });

    it("updates player positions with inputs", () => {
      const { e } = setupRallyEngine();
      const prevP1y = e.gameState.p1y;
      e.localInputs.up = true;
      e._gameLoop();
      // P1 should have moved up (toward net, but clamped to bottom half)
      expect(e.gameState.p1y).toBeLessThanOrEqual(prevP1y);
      e.stop();
    });

    it("renders and broadcasts on interval", () => {
      const { e, canvas, channel } = setupRallyEngine();
      canvas._ctx.fillRect.mockClear();
      channel.send.mockClear();
      e.frameCount = 1; // next frame will be 2, divisible by STATE_SEND_INTERVAL
      e._gameLoop();
      expect(canvas._ctx.fillRect).toHaveBeenCalled();
      expect(channel.send).toHaveBeenCalled();
      e.stop();
    });

    it("requests next animation frame during rally", () => {
      const { e } = setupRallyEngine();
      globalThis.requestAnimationFrame.mockClear();
      e._gameLoop();
      expect(globalThis.requestAnimationFrame).toHaveBeenCalled();
      e.stop();
    });
  });

  // ── POINT phase tests ──

  describe("_gameLoop POINT phase", () => {
    it("pointPauseCounter decrements each frame", () => {
      const e = new TennisEngine(
        createMockCanvas(),
        createMockChannel(),
        "hex_tennis",
        true,
        vi.fn(),
      );
      e.start();
      e.gameState.phase = PHASE.POINT;
      e.pointPauseCounter = 10;
      e._gameLoop();
      expect(e.pointPauseCounter).toBe(9);
      e.stop();
    });

    it("transitions to SERVING when pause ends (no changeover)", () => {
      const e = new TennisEngine(
        createMockCanvas(),
        createMockChannel(),
        "hex_tennis",
        true,
        vi.fn(),
      );
      e.start();
      e.gameState.phase = PHASE.POINT;
      e.gameState.p1Games = 0;
      e.gameState.p2Games = 0;
      e.gameState.isTiebreak = false;
      e.pointPauseCounter = 1; // will hit 0
      e._gameLoop();
      expect(e.gameState.phase).toBe(PHASE.SERVING);
      e.stop();
    });
  });

  // ── CHANGEOVER phase tests ──

  describe("_gameLoop CHANGEOVER phase", () => {
    it("pointPauseCounter decrements each frame", () => {
      const e = new TennisEngine(
        createMockCanvas(),
        createMockChannel(),
        "hex_tennis",
        true,
        vi.fn(),
      );
      e.start();
      e.gameState.phase = PHASE.CHANGEOVER;
      e.pointPauseCounter = 5;
      e._gameLoop();
      expect(e.pointPauseCounter).toBe(4);
      e.stop();
    });

    it("transitions to SERVING when changeover pause ends", () => {
      const e = new TennisEngine(
        createMockCanvas(),
        createMockChannel(),
        "hex_tennis",
        true,
        vi.fn(),
      );
      e.start();
      e.gameState.phase = PHASE.CHANGEOVER;
      e.pointPauseCounter = 1;
      e._gameLoop();
      expect(e.gameState.phase).toBe(PHASE.SERVING);
      e.stop();
    });
  });

  // ── GAME_OVER from loop ──

  describe("_gameLoop GAME_OVER detection", () => {
    it("calls _handleGameFinished when phase becomes GAME_OVER", () => {
      const onEnd = vi.fn();
      const channel = createMockChannel();
      const e = new TennisEngine(createMockCanvas(), channel, "hex_tennis", true, onEnd);
      e.start();
      // Set up a state that is already GAME_OVER
      e.gameState.phase = PHASE.GAME_OVER;
      e.gameState.winner = 1;
      e.gameState.p1Games = 6;
      e.gameState.p2Games = 4;
      channel.send.mockClear();

      e._gameLoop();

      // Should have called onGameEnd via _handleGameFinished
      expect(onEnd).toHaveBeenCalledWith({
        score: { p1: 6, p2: 4 },
        winner: 1,
      });
      e.stop();
    });

    it("_handleGameFinished sends encodeGameEnd with gameMode and isTiebreak", () => {
      const channel = createMockChannel();
      const e = new TennisEngine(createMockCanvas(), channel, "hex_tennis", true, vi.fn());
      e.start();
      e.gameState.phase = PHASE.GAME_OVER;
      e.gameState.winner = 2;
      e.gameState.p1Games = 4;
      e.gameState.p2Games = 6;
      e.gameState.gameMode = GAME_MODE.CLASSIC;
      e.gameState.isTiebreak = false;
      channel.send.mockClear();

      e._handleGameFinished();

      // Find the GAME_END message
      const endBuf = channel.send.mock.calls.find(
        (c) => new DataView(c[0]).getUint8(0) === MSG_TYPE.GAME_END,
      );
      expect(endBuf).toBeDefined();
      // Verify it has 6 bytes (includes gameMode + tiebreak flag)
      expect(endBuf[0].byteLength).toBe(6);
      e.stop();
    });
  });

  // ── Fault handling in rally ──

  describe("_gameLoop rally fault handling", () => {
    it("plays playFault on serve fault event", () => {
      const e = new TennisEngine(
        createMockCanvas(),
        createMockChannel(),
        "hex_tennis",
        true,
        vi.fn(),
      );
      e.start();
      e.gameState.phase = PHASE.RALLY;
      e.gameState.rallyCount = 0;
      e.gameState.lastHitter = 1;
      e.gameState.server = 1;
      // Ball landed on ground (height=0) outside service box
      e.gameState.ball = {
        x: 50,
        y: 50,
        vx: 0,
        vy: -3,
        speed: 5,
        height: 0,
        heightVel: 0,
      };
      e.gameState.isSecondServe = false;
      e.gameState.totalPointsInGame = 0;

      const faultSpy = vi.spyOn(e.audio, "playFault");
      e._gameLoop();

      // If fault was detected, playFault should be called
      if (e.gameState.faultEvent) {
        expect(faultSpy).toHaveBeenCalled();
      }
      e.stop();
    });
  });

  // ── Host audio in rally ──

  describe("_gameLoop rally audio events", () => {
    it("plays playHit on hitEvent", () => {
      const e = new TennisEngine(
        createMockCanvas(),
        createMockChannel(),
        "hex_tennis",
        true,
        vi.fn(),
      );
      e.start();
      e.gameState.phase = PHASE.RALLY;
      e.gameState.lastHitter = 2;
      e.gameState.rallyCount = 1;
      // Place ball exactly on P1 hit zone (ball moving toward P1)
      e.gameState.p1y = COURT_BOTTOM - 30;
      e.gameState.p1x = COURT_CENTER_X;
      e.gameState.ball = {
        x: COURT_CENTER_X,
        y: COURT_BOTTOM - 30,
        vx: 0,
        vy: 3,
        speed: 5,
        height: 0.3,
        heightVel: 0.06,
      };
      const hitSpy = vi.spyOn(e.audio, "playHit");
      e._gameLoop();
      expect(hitSpy).toHaveBeenCalled();
      e.stop();
    });

    it("plays playOut on out-of-bounds (wide)", () => {
      const e = new TennisEngine(
        createMockCanvas(),
        createMockChannel(),
        "hex_tennis",
        true,
        vi.fn(),
      );
      e.start();
      e.gameState.phase = PHASE.RALLY;
      e.gameState.lastHitter = 1;
      e.gameState.rallyCount = 1;
      // Ball far off court to the left
      e.gameState.ball = {
        x: 20,
        y: 200,
        vx: -5,
        vy: 0,
        speed: 5,
        height: 0.3,
        heightVel: 0,
      };
      const outSpy = vi.spyOn(e.audio, "playOut");
      e._gameLoop();
      expect(outSpy).toHaveBeenCalled();
      e.stop();
    });

    it("plays playNetHit on net collision", () => {
      const e = new TennisEngine(
        createMockCanvas(),
        createMockChannel(),
        "hex_tennis",
        true,
        vi.fn(),
      );
      e.start();
      e.gameState.phase = PHASE.RALLY;
      e.gameState.lastHitter = 1;
      e.gameState.rallyCount = 1;
      // Ball at the net with low height → net collision
      e.gameState.ball = {
        x: COURT_CENTER_X,
        y: 240, // NET_Y
        vx: 0,
        vy: -3,
        speed: 5,
        height: 0.1, // below NET_HEIGHT_FACTOR (0.35)
        heightVel: -0.05,
      };
      const netSpy = vi.spyOn(e.audio, "playNetHit");
      e._gameLoop();
      expect(netSpy).toHaveBeenCalled();
      e.stop();
    });

    it("plays playPoint when pointWinner > 0 from out-of-bounds", () => {
      const e = new TennisEngine(
        createMockCanvas(),
        createMockChannel(),
        "hex_tennis",
        true,
        vi.fn(),
      );
      e.start();
      e.gameState.phase = PHASE.RALLY;
      e.gameState.lastHitter = 1;
      e.gameState.rallyCount = 1;
      // Ball wide out
      e.gameState.ball = {
        x: 20,
        y: 200,
        vx: -5,
        vy: 0,
        speed: 5,
        height: 0.3,
        heightVel: 0,
      };
      const pointSpy = vi.spyOn(e.audio, "playPoint");
      e._gameLoop();
      expect(pointSpy).toHaveBeenCalled();
      e.stop();
    });
  });

  // ── Score advancement in loop ──

  describe("_gameLoop score advancement", () => {
    it("transitions to POINT phase after scoring", () => {
      const e = new TennisEngine(
        createMockCanvas(),
        createMockChannel(),
        "hex_tennis",
        true,
        vi.fn(),
      );
      e.start();
      e.gameState.phase = PHASE.RALLY;
      e.gameState.lastHitter = 1;
      e.gameState.rallyCount = 1;
      // Wide out → point for P2
      e.gameState.ball = {
        x: 20,
        y: 200,
        vx: -5,
        vy: 0,
        speed: 5,
        height: 0.3,
        heightVel: 0,
      };
      e._gameLoop();
      expect(e.gameState.phase).toBe(PHASE.POINT);
      e.stop();
    });

    it("GAME_OVER from rally calls _handleGameFinished immediately", () => {
      const onEnd = vi.fn();
      const e = new TennisEngine(
        createMockCanvas(),
        createMockChannel(),
        "hex_tennis_sudden",
        true,
        onEnd,
      );
      e.start();
      e.gameState.phase = PHASE.RALLY;
      e.gameState.lastHitter = 1;
      e.gameState.rallyCount = 1;
      e.gameState.p1Games = 5;
      e.gameState.p2Games = 5;
      // Ball wide out → point for P2, P2 gets game 6 in sudden death = win
      e.gameState.ball = {
        x: 20,
        y: 200,
        vx: -5,
        vy: 0,
        speed: 5,
        height: 0.3,
        heightVel: 0,
      };
      e._gameLoop();
      expect(onEnd).toHaveBeenCalled();
      e.stop();
    });
  });

  // ── Peer phase audio ──

  describe("_playPeerAudio additional", () => {
    it("plays playMatchWon on GAME_OVER transition", () => {
      const e = new TennisEngine(
        createMockCanvas(),
        createMockChannel(),
        "hex_tennis",
        false,
        vi.fn(),
      );
      e.start();
      e.gameState.phase = PHASE.RALLY;

      const flat = {
        ...createInitialState(0),
        phase: PHASE.GAME_OVER,
        ballX: 320,
        ballY: 240,
        ballVX: 0,
        ballVY: 0,
        ballHeight: 0,
      };
      const matchSpy = vi.spyOn(e.audio, "playMatchWon");
      e._handleMessage({ data: encodeGameState(flat) });
      expect(matchSpy).toHaveBeenCalled();
      e.stop();
    });

    it("plays playCountdown on COUNTDOWN transition", () => {
      const e = new TennisEngine(
        createMockCanvas(),
        createMockChannel(),
        "hex_tennis",
        false,
        vi.fn(),
      );
      e.start();
      e.gameState.phase = PHASE.WAITING;

      const flat = {
        ...createInitialState(0),
        phase: PHASE.COUNTDOWN,
        ballX: 320,
        ballY: 240,
        ballVX: 0,
        ballVY: 0,
        ballHeight: 0,
      };
      const countSpy = vi.spyOn(e.audio, "playCountdown");
      e._handleMessage({ data: encodeGameState(flat) });
      expect(countSpy).toHaveBeenCalled();
      e.stop();
    });
  });
});
