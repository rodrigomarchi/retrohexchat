import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import {
  PHASE,
  MSG_TYPE,
  INPUT_KEY,
  BRICKS_PER_CASTLE,
  encodeGameState,
  encodePlayerInput,
  encodeGameEnd,
  encodeGameReady,
} from "../../../../js/lib/games/warlords/protocol.js";
import {
  createInitialState,
  CANVAS_W,
  CANVAS_H,
} from "../../../../js/lib/games/warlords/physics.js";

// Must mock audio before importing WarlordEngine
vi.mock("../../../../js/lib/games/warlords/audio.js", () => ({
  WarlordAudio: function () {
    return {
      playBrickHit: vi.fn(),
      playShieldDeflect: vi.fn(),
      playKingHit: vi.fn(),
      playCatch: vi.fn(),
      playLaunch: vi.fn(),
      playWallBounce: vi.fn(),
      playCountdown: vi.fn(),
      playWin: vi.fn(),
      playLose: vi.fn(),
    };
  },
}));

// Must mock renderer
vi.mock("../../../../js/lib/games/warlords/renderer.js", () => ({
  getColors: vi.fn(() => ({
    bg: "#0a0a1a",
    fg: "#00ff66",
    accent: "#00ccff",
    muted: "#1a3a4a",
    glow: "rgba(0,255,102,0.2)",
    warning: "#ffaa00",
  })),
  render: vi.fn(),
}));

const { WarlordEngine } = await import("../../../../js/lib/games/warlords/engine.js");
const { render, getColors } = await import("../../../../js/lib/games/warlords/renderer.js");

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
    arc: vi.fn(),
    fill: vi.fn(),
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

describe("WarlordEngine", () => {
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
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, null);
      expect(engine.gameState).toBeDefined();
      expect(engine.gameState.phase).toBe(PHASE.WAITING);
    });

    it("sets isHost flag", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, null);
      expect(engine.isHost).toBe(true);
    });

    it("stores onGameEnd callback", () => {
      const cb = vi.fn();
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, cb);
      expect(engine.onGameEnd).toBe(cb);
    });

    it("initializes remote inputs for up/down/space", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, null);
      expect(engine.remoteInputs).toEqual({ up: false, down: false, space: false });
    });

    it("initializes with bricks for both castles", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, null);
      expect(engine.gameState.p1Bricks).toHaveLength(BRICKS_PER_CASTLE);
      expect(engine.gameState.p2Bricks).toHaveLength(BRICKS_PER_CASTLE);
    });

    it("initializes with 3 lives per player", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, null);
      expect(engine.gameState.p1Lives).toBe(3);
      expect(engine.gameState.p2Lives).toBe(3);
    });

    it("initializes with caughtBy 0", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, null);
      expect(engine.gameState.caughtBy).toBe(0);
    });
  });

  describe("start", () => {
    it("sets running to true", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, null);
      engine.start();
      expect(engine.running).toBe(true);
    });

    it("host does not send GAME_READY", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, null);
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
      engine = new WarlordEngine(canvas, channel, "hex_warlords", false, null);
      engine.start();
      expect(channel.send).toHaveBeenCalled();
      const buf = channel.send.mock.calls[0][0];
      const view = new Uint8Array(buf);
      expect(view[0]).toBe(MSG_TYPE.GAME_READY);
    });

    it("reads colors from canvas", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, null);
      engine.start();
      expect(getColors).toHaveBeenCalledWith(canvas);
      expect(engine.colors).toBeDefined();
    });

    it("renders initial state", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, null);
      engine.start();
      expect(render).toHaveBeenCalled();
    });
  });

  describe("stop", () => {
    it("sets running to false", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, null);
      engine.start();
      engine.stop();
      expect(engine.running).toBe(false);
    });

    it("clears phase timer", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, null);
      engine.start();
      engine.phaseTimer = setTimeout(() => {}, 10000);
      engine.stop();
      expect(engine.phaseTimer).toBeNull();
    });

    it("cancels animation frame", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, null);
      engine.start();
      engine.animFrame = 99;
      engine.stop();
      expect(engine.animFrame).toBeNull();
      expect(globalThis.cancelAnimationFrame).toHaveBeenCalledWith(99);
    });
  });

  describe("_handleMessage (host)", () => {
    it("processes GAME_READY from peer", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, null);
      engine.start();
      expect(engine.peerReady).toBe(false);

      const buf = encodeGameReady();
      engine._handleMessage({ data: buf });

      expect(engine.peerReady).toBe(true);
      expect(engine.gameState.phase).toBe(PHASE.COUNTDOWN);
    });

    it("ignores duplicate GAME_READY", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, null);
      engine.start();

      const buf = encodeGameReady();
      engine._handleMessage({ data: buf });
      const countdownCalls1 = engine.audio.playCountdown.mock.calls.length;

      engine._handleMessage({ data: buf });
      const countdownCalls2 = engine.audio.playCountdown.mock.calls.length;

      expect(countdownCalls2).toBe(countdownCalls1);
    });

    it("processes PLAYER_INPUT UP pressed", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, null);
      engine.start();

      const buf = encodePlayerInput(INPUT_KEY.UP, true);
      engine._handleMessage({ data: buf });

      expect(engine.remoteInputs.up).toBe(true);
    });

    it("processes PLAYER_INPUT DOWN released", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, null);
      engine.start();
      engine.remoteInputs.down = true;

      const buf = encodePlayerInput(INPUT_KEY.DOWN, false);
      engine._handleMessage({ data: buf });

      expect(engine.remoteInputs.down).toBe(false);
    });

    it("processes PLAYER_INPUT SPACE pressed", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, null);
      engine.start();

      const buf = encodePlayerInput(INPUT_KEY.SPACE, true);
      engine._handleMessage({ data: buf });

      expect(engine.remoteInputs.space).toBe(true);
    });
  });

  describe("_handleMessage (peer)", () => {
    it("applies GAME_STATE from host", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", false, null);
      engine.start();

      const state = {
        ...createInitialState(),
        p1Lives: 2,
        p2Lives: 3,
        phase: PHASE.PLAYING,
        fireballX: 100,
        fireballY: 200,
        fireballVX: 3,
        fireballVY: -2,
        shield1Y: 180,
        shield2Y: 220,
        countdown: 0,
        round: 2,
        caughtBy: 0,
      };
      const buf = encodeGameState(state);
      engine._handleMessage({ data: buf });

      expect(engine.gameState.p1Lives).toBe(2);
      expect(engine.gameState.p2Lives).toBe(3);
      expect(engine.gameState.phase).toBe(PHASE.PLAYING);
    });

    it("processes GAME_END message (P2 wins)", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", false, null);
      engine.start();

      const buf = encodeGameEnd(0, 2, 2);
      engine._handleMessage({ data: buf });

      expect(engine.gameState.phase).toBe(PHASE.FINISHED);
      expect(engine.gameState.winner).toBe(2);
      expect(engine.gameState.p1Lives).toBe(0);
      expect(engine.gameState.p2Lives).toBe(2);
    });

    it("plays win audio when peer wins", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", false, null);
      engine.start();

      const buf = encodeGameEnd(0, 2, 2);
      engine._handleMessage({ data: buf });

      expect(engine.audio.playWin).toHaveBeenCalled();
    });

    it("plays lose audio when peer loses", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", false, null);
      engine.start();

      const buf = encodeGameEnd(2, 0, 1);
      engine._handleMessage({ data: buf });

      expect(engine.audio.playLose).toHaveBeenCalled();
    });

    it("derives p1KingAlive from lives in KING_HIT phase", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", false, null);
      engine.start();

      // First state with 3 lives each
      const state1 = {
        ...createInitialState(),
        phase: PHASE.PLAYING,
      };
      engine._handleMessage({ data: encodeGameState(state1) });

      // Second state: KING_HIT, P1 lost a life
      const state2 = {
        ...createInitialState(),
        p1Lives: 2,
        p2Lives: 3,
        phase: PHASE.KING_HIT,
      };
      engine._handleMessage({ data: encodeGameState(state2) });

      expect(engine.gameState.kingHitPlayer).toBe(1);
      expect(engine.gameState.p1KingAlive).toBe(false);
    });

    it("ignores PLAYER_INPUT when peer", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", false, null);
      engine.start();

      const buf = encodePlayerInput(INPUT_KEY.UP, true);
      engine._handleMessage({ data: buf });

      expect(engine.remoteInputs.up).toBe(false);
    });
  });

  describe("_handleMessage (non-ArrayBuffer)", () => {
    it("ignores non-ArrayBuffer data", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, null);
      engine.start();
      expect(() => {
        engine._handleMessage({ data: "not binary" });
      }).not.toThrow();
    });
  });

  describe("key handling", () => {
    it("maps ArrowUp to UP input", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, null);
      engine.start();
      engine._handleKeyDown({ key: "ArrowUp", preventDefault: vi.fn() });
      expect(engine.localInputs.up).toBe(true);
    });

    it("maps ArrowDown to DOWN input", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, null);
      engine.start();
      engine._handleKeyDown({ key: "ArrowDown", preventDefault: vi.fn() });
      expect(engine.localInputs.down).toBe(true);
    });

    it("maps w to UP input", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, null);
      engine.start();
      engine._handleKeyDown({ key: "w", preventDefault: vi.fn() });
      expect(engine.localInputs.up).toBe(true);
    });

    it("maps s to DOWN input", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, null);
      engine.start();
      engine._handleKeyDown({ key: "s", preventDefault: vi.fn() });
      expect(engine.localInputs.down).toBe(true);
    });

    it("maps Space to SPACE input", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, null);
      engine.start();
      engine._handleKeyDown({ key: " ", preventDefault: vi.fn() });
      expect(engine.localInputs.space).toBe(true);
    });

    it("key release clears local input", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, null);
      engine.start();
      engine._handleKeyDown({ key: "ArrowUp", preventDefault: vi.fn() });
      engine._handleKeyUp({ key: "ArrowUp" });
      expect(engine.localInputs.up).toBe(false);
    });

    it("ignores unmapped keys", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, null);
      engine.start();
      const e = { key: "x", preventDefault: vi.fn() };
      engine._handleKeyDown(e);
      expect(e.preventDefault).not.toHaveBeenCalled();
    });

    it("peer sends binary input on keydown", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", false, null);
      engine.start();
      channel.send.mockClear();

      engine._handleKeyDown({ key: "ArrowUp", preventDefault: vi.fn() });

      const lastCall = channel.send.mock.calls[channel.send.mock.calls.length - 1];
      const buf = lastCall[0];
      expect(buf).toBeInstanceOf(ArrayBuffer);
      const view = new Uint8Array(buf);
      expect(view[0]).toBe(MSG_TYPE.PLAYER_INPUT);
      expect(view[1]).toBe(INPUT_KEY.UP);
      expect(view[2]).toBe(1); // pressed
    });

    it("peer sends binary input on keyup", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", false, null);
      engine.start();

      engine._handleKeyDown({ key: "ArrowDown", preventDefault: vi.fn() });
      channel.send.mockClear();
      engine._handleKeyUp({ key: "ArrowDown" });

      const lastCall = channel.send.mock.calls[channel.send.mock.calls.length - 1];
      const buf = lastCall[0];
      const view = new Uint8Array(buf);
      expect(view[0]).toBe(MSG_TYPE.PLAYER_INPUT);
      expect(view[1]).toBe(INPUT_KEY.DOWN);
      expect(view[2]).toBe(0); // released
    });

    it("host does not send input over channel", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, null);
      engine.start();
      channel.send.mockClear();

      engine._handleKeyDown({ key: "ArrowUp", preventDefault: vi.fn() });
      expect(channel.send).not.toHaveBeenCalled();
    });
  });

  describe("_handleBlur", () => {
    it("clears all local inputs", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, null);
      engine.start();
      engine.localInputs = { up: true, down: true, space: true };

      engine._handleBlur();

      expect(engine.localInputs.up).toBe(false);
      expect(engine.localInputs.down).toBe(false);
      expect(engine.localInputs.space).toBe(false);
    });

    it("peer sends release for all keys on blur", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", false, null);
      engine.start();
      channel.send.mockClear();

      engine._handleBlur();

      expect(channel.send).toHaveBeenCalledTimes(3);
    });

    it("host releases caught fireball on blur", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, null);
      engine.start();
      engine.gameState.caughtBy = 1;
      engine.gameState.phase = PHASE.PLAYING;
      engine.gameState.fireballSpeed = 3;

      engine._handleBlur();

      expect(engine.gameState.caughtBy).toBe(0);
      expect(engine.audio.playLaunch).toHaveBeenCalled();
    });
  });

  describe("_broadcastState", () => {
    it("sends encoded state when channel is open", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, null);
      engine.start();
      channel.send.mockClear();

      engine._broadcastState();

      expect(channel.send).toHaveBeenCalledTimes(1);
      const buf = channel.send.mock.calls[0][0];
      expect(buf).toBeInstanceOf(ArrayBuffer);
      expect(buf.byteLength).toBe(33);
    });

    it("does not send when channel is closed", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, null);
      engine.start();
      channel.readyState = "closed";
      channel.send.mockClear();

      engine._broadcastState();

      expect(channel.send).not.toHaveBeenCalled();
    });
  });

  describe("_handleGameFinished (host)", () => {
    it("sends GAME_END to peer when P1 wins", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, null);
      engine.start();
      engine.gameState.p1Lives = 2;
      engine.gameState.p2Lives = 0;
      engine.gameState.winner = 1;
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
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, onEnd);
      engine.start();
      engine.gameState.p1Lives = 2;
      engine.gameState.p2Lives = 0;
      engine.gameState.winner = 1;

      engine._handleGameFinished();

      expect(onEnd).toHaveBeenCalledWith({
        score: { p1: 2, p2: 0 },
        winner: 1,
      });
    });

    it("calls onGameEnd with winner=2 when P2 wins", () => {
      const onEnd = vi.fn();
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, onEnd);
      engine.start();
      engine.gameState.p1Lives = 0;
      engine.gameState.p2Lives = 1;
      engine.gameState.winner = 2;

      engine._handleGameFinished();

      expect(onEnd).toHaveBeenCalledWith({
        score: { p1: 0, p2: 1 },
        winner: 2,
      });
    });

    it("plays win audio for host when P1 wins", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, null);
      engine.start();
      engine.gameState.winner = 1;

      engine._handleGameFinished();

      expect(engine.audio.playWin).toHaveBeenCalled();
    });

    it("plays lose audio for host when P2 wins", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, null);
      engine.start();
      engine.gameState.winner = 2;

      engine._handleGameFinished();

      expect(engine.audio.playLose).toHaveBeenCalled();
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
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, null);
      engine.start();

      engine._handleMessage({ data: encodeGameReady() });

      expect(engine.gameState.phase).toBe(PHASE.COUNTDOWN);
      expect(engine.gameState.countdown).toBe(3);
      expect(engine.audio.playCountdown).toHaveBeenCalled();
    });

    it("counts down from 3 to 1", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, null);
      engine.start();
      engine._handleMessage({ data: encodeGameReady() });

      vi.advanceTimersByTime(1000);
      expect(engine.gameState.countdown).toBe(2);

      vi.advanceTimersByTime(1000);
      expect(engine.gameState.countdown).toBe(1);
    });

    it("transitions to PLAYING after countdown + serve delay", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, null);
      engine.start();
      engine._handleMessage({ data: encodeGameReady() });

      // 3 countdown ticks (3×1000ms) + serve delay (800ms)
      vi.advanceTimersByTime(3800);

      expect(engine.gameState.phase).toBe(PHASE.PLAYING);
    });
  });

  // ── Connection Resilience ──

  describe("connection resilience", () => {
    it("double-start is a no-op", () => {
      engine = new WarlordEngine(canvas, channel, "shield_wall", true, null);
      engine.start();
      const firstState = engine.gameState;
      engine.start(); // should not reset
      expect(engine.gameState).toBe(firstState);
    });

    it("blur clears local inputs", () => {
      engine = new WarlordEngine(canvas, channel, "shield_wall", true, null);
      engine.start();
      engine.localInputs = { up: true, down: true, space: true };
      engine._handleBlur();
      expect(engine.localInputs.up).toBe(false);
      expect(engine.localInputs.down).toBe(false);
      expect(engine.localInputs.space).toBe(false);
    });

    it("channel close ends game with disconnect flag", () => {
      const onEnd = vi.fn();
      engine = new WarlordEngine(canvas, channel, "shield_wall", true, onEnd);
      engine.start();
      engine.gameState.phase = PHASE.PLAYING;
      engine._handleChannelClose();
      expect(engine.gameState.phase).toBe(PHASE.FINISHED);
      expect(onEnd).toHaveBeenCalledWith(expect.objectContaining({ disconnected: true }));
    });

    it("channel close is no-op when game already finished", () => {
      const onEnd = vi.fn();
      engine = new WarlordEngine(canvas, channel, "shield_wall", true, onEnd);
      engine.start();
      engine.gameState.phase = PHASE.FINISHED;
      engine._handleChannelClose();
      expect(onEnd).not.toHaveBeenCalled();
    });
  });

  // ── SPACE / catch / release mechanic ──

  describe("_handleMessage host: SPACE release (catch mechanic)", () => {
    it("SPACE released while caughtBy===2 calls releaseBall for P2", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, null);
      engine.start();
      engine.gameState.phase = PHASE.PLAYING;
      engine.gameState.caughtBy = 2;
      engine.gameState.fireballSpeed = 3;

      // Peer presses space first
      engine._handleMessage({ data: encodePlayerInput(INPUT_KEY.SPACE, true) });
      expect(engine.remoteInputs.space).toBe(true);

      // Peer releases space → should release ball
      engine._handleMessage({ data: encodePlayerInput(INPUT_KEY.SPACE, false) });
      expect(engine.gameState.caughtBy).toBe(0);
    });

    it("SPACE released while caughtBy===2 plays playLaunch", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, null);
      engine.start();
      engine.gameState.phase = PHASE.PLAYING;
      engine.gameState.caughtBy = 2;
      engine.gameState.fireballSpeed = 3;

      engine.remoteInputs.space = true;
      engine._handleMessage({ data: encodePlayerInput(INPUT_KEY.SPACE, false) });

      expect(engine.audio.playLaunch).toHaveBeenCalled();
    });

    it("SPACE released while caughtBy===0 does NOT call playLaunch", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, null);
      engine.start();
      engine.gameState.phase = PHASE.PLAYING;
      engine.gameState.caughtBy = 0;

      engine.remoteInputs.space = true;
      engine._handleMessage({ data: encodePlayerInput(INPUT_KEY.SPACE, false) });

      expect(engine.audio.playLaunch).not.toHaveBeenCalled();
    });
  });

  describe("_handleKeyUp host: SPACE release (catch mechanic)", () => {
    it("SPACE released while caughtBy===1 calls releaseBall for P1", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, null);
      engine.start();
      engine.gameState.phase = PHASE.PLAYING;
      engine.gameState.caughtBy = 1;
      engine.gameState.fireballSpeed = 3;

      // Press space first
      engine._handleKeyDown({ key: " ", preventDefault: vi.fn() });
      // Release space
      engine._handleKeyUp({ key: " " });

      expect(engine.gameState.caughtBy).toBe(0);
      expect(engine.audio.playLaunch).toHaveBeenCalled();
    });

    it("SPACE released while caughtBy===0 does not release", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, null);
      engine.start();
      engine.gameState.phase = PHASE.PLAYING;
      engine.gameState.caughtBy = 0;

      engine._handleKeyDown({ key: " ", preventDefault: vi.fn() });
      engine._handleKeyUp({ key: " " });

      expect(engine.audio.playLaunch).not.toHaveBeenCalled();
    });
  });

  // ── Game loop tests ──

  describe("_gameLoop (host)", () => {
    function setupPlayingEngine() {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, null);
      engine.start();
      engine.gameState.phase = PHASE.PLAYING;
      engine.gameState.fireballX = CANVAS_W / 2;
      engine.gameState.fireballY = CANVAS_H / 2;
      engine.gameState.fireballVX = 3;
      engine.gameState.fireballVY = -2;
      engine.gameState.fireballSpeed = 3;
      engine.gameState.caughtBy = 0;
      engine.running = true;
      engine.colors = {
        bg: "#000",
        fg: "#0f0",
        accent: "#0cf",
        muted: "#333",
        glow: "#000",
        warning: "#f00",
      };
      return engine;
    }

    it("increments frameCount each frame", () => {
      setupPlayingEngine();
      const before = engine.frameCount;
      engine._gameLoop(0);
      expect(engine.frameCount).toBe(before + 1);
    });

    it("calls render each frame", () => {
      setupPlayingEngine();
      render.mockClear();
      engine._gameLoop(0);
      expect(render).toHaveBeenCalled();
    });

    it("requests next animation frame", () => {
      setupPlayingEngine();
      globalThis.requestAnimationFrame.mockClear();
      engine._gameLoop(0);
      expect(globalThis.requestAnimationFrame).toHaveBeenCalled();
    });

    it("plays playWallBounce on wall bounce", () => {
      setupPlayingEngine();
      // Place fireball at top edge to trigger bounce
      engine.gameState.fireballY = 2;
      engine.gameState.fireballVY = -3;
      engine._gameLoop(0);
      expect(engine.audio.playWallBounce).toHaveBeenCalled();
    });

    it("plays playBrickHit on brick collision", () => {
      setupPlayingEngine();
      // Place fireball directly on a P1 brick
      const brick = engine.gameState.p1Bricks[0];
      engine.gameState.fireballX = brick.x + brick.w / 2;
      engine.gameState.fireballY = brick.y + brick.h / 2;
      engine.gameState.fireballVX = -3;
      engine._gameLoop(0);
      expect(engine.audio.playBrickHit).toHaveBeenCalled();
    });

    it("does not run when running is false", () => {
      setupPlayingEngine();
      engine.running = false;
      render.mockClear();
      engine._gameLoop(0);
      expect(render).not.toHaveBeenCalled();
    });
  });

  // ── _handleKingHit ──

  describe("_handleKingHit (host)", () => {
    beforeEach(() => {
      vi.useFakeTimers();
    });

    afterEach(() => {
      vi.useRealTimers();
    });

    it("sets KING_HIT phase and broadcasts", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, null);
      engine.start();
      engine.gameState.phase = PHASE.PLAYING;
      engine.gameState.p1Lives = 3;
      engine.gameState.p2Lives = 3;
      engine.colors = {
        bg: "#000",
        fg: "#0f0",
        accent: "#0cf",
        muted: "#333",
        glow: "#000",
        warning: "#f00",
      };
      channel.send.mockClear();

      engine._handleKingHit();

      expect(engine.gameState.phase).toBe(PHASE.KING_HIT);
      expect(channel.send).toHaveBeenCalled();
    });

    it("after KING_HIT_PAUSE with 0 lives: game over → _handleGameFinished", () => {
      const onEnd = vi.fn();
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, onEnd);
      engine.start();
      engine.gameState.phase = PHASE.PLAYING;
      engine.gameState.p1Lives = 0;
      engine.gameState.p2Lives = 2;
      engine.colors = {
        bg: "#000",
        fg: "#0f0",
        accent: "#0cf",
        muted: "#333",
        glow: "#000",
        warning: "#f00",
      };

      engine._handleKingHit();
      // Advance past KING_HIT_PAUSE (2000ms)
      vi.advanceTimersByTime(2100);

      expect(engine.gameState.phase).toBe(PHASE.FINISHED);
      expect(onEnd).toHaveBeenCalled();
    });

    it("after KING_HIT_PAUSE with lives remaining: rebuilds castles + restarts countdown", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, null);
      engine.start();
      engine.gameState.phase = PHASE.PLAYING;
      engine.gameState.p1Lives = 2;
      engine.gameState.p2Lives = 3;
      engine.gameState.round = 1;
      engine.colors = {
        bg: "#000",
        fg: "#0f0",
        accent: "#0cf",
        muted: "#333",
        glow: "#000",
        warning: "#f00",
      };

      engine._handleKingHit();
      vi.advanceTimersByTime(2100);

      expect(engine.gameState.phase).toBe(PHASE.COUNTDOWN);
      // All bricks should be rebuilt (alive)
      const allP1Alive = engine.gameState.p1Bricks.every((b) => b.alive);
      expect(allP1Alive).toBe(true);
    });
  });

  // ── Custom stop() override ──

  describe("stop() custom override", () => {
    it("removes channel message listener", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, null);
      engine.start();
      engine.stop();
      expect(channel.removeEventListener).toHaveBeenCalledWith("message", expect.any(Function));
    });

    it("removes document keydown/keyup listeners", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, null);
      engine.start();

      const removeSpy = vi.spyOn(document, "removeEventListener");
      engine.stop();

      const keydownRemoved = removeSpy.mock.calls.some((call) => call[0] === "keydown");
      const keyupRemoved = removeSpy.mock.calls.some((call) => call[0] === "keyup");
      expect(keydownRemoved).toBe(true);
      expect(keyupRemoved).toBe(true);
      removeSpy.mockRestore();
    });

    it("removes channel close listener", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", true, null);
      engine.start();
      engine.stop();
      expect(channel.removeEventListener).toHaveBeenCalledWith("close", expect.any(Function));
    });
  });

  // ── _playPhaseAudio peer ──

  describe("_playPhaseAudio (peer)", () => {
    it("COUNTDOWN phase plays playCountdown", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", false, null);
      engine.start();

      // Simulate receiving state transition to COUNTDOWN
      const state = {
        ...createInitialState(),
        phase: PHASE.COUNTDOWN,
        countdown: 3,
      };
      // First set a WAITING state so prevPhase differs
      engine.gameState.phase = PHASE.WAITING;
      engine._handleMessage({ data: encodeGameState(state) });

      expect(engine.audio.playCountdown).toHaveBeenCalled();
    });

    it("KING_HIT phase plays playKingHit", () => {
      engine = new WarlordEngine(canvas, channel, "hex_warlords", false, null);
      engine.start();

      // Set previous phase to PLAYING
      const playingState = {
        ...createInitialState(),
        phase: PHASE.PLAYING,
      };
      engine._handleMessage({ data: encodeGameState(playingState) });
      engine.audio.playKingHit.mockClear();

      // Now transition to KING_HIT
      const kingHitState = {
        ...createInitialState(),
        phase: PHASE.KING_HIT,
        p1Lives: 2,
        p2Lives: 3,
      };
      engine._handleMessage({ data: encodeGameState(kingHitState) });

      expect(engine.audio.playKingHit).toHaveBeenCalled();
    });
  });
});
