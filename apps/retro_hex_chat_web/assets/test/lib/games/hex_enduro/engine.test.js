import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import {
  PHASE,
  MSG_TYPE,
  INPUT_KEY,
  GAME_MODE,
  EVENT,
  encodeGameState,
  encodePlayerInput,
  encodeGameEnd,
  encodeGameReady,
} from "../../../../js/lib/games/hex_enduro/protocol.js";
import { createInitialState, packState } from "../../../../js/lib/games/hex_enduro/physics.js";

// Must mock audio before importing engine
vi.mock("../../../../js/lib/games/hex_enduro/audio.js", () => ({
  HexEnduroAudio: function () {
    return {
      playLaneChange: vi.fn(),
      playTurbo: vi.fn(),
      playOvertakeAI: vi.fn(),
      playOvertakePlayer: vi.fn(),
      playCollision: vi.fn(),
      playFuelPickup: vi.fn(),
      playWeatherChange: vi.fn(),
      playCountdown: vi.fn(),
      playVictory: vi.fn(),
      playGameOver: vi.fn(),
      playFuelWarning: vi.fn(),
      startEngineDrone: vi.fn(),
      updateEnginePitch: vi.fn(),
      stopEngineDrone: vi.fn(),
      destroy: vi.fn(),
    };
  },
}));

// Must mock renderer
vi.mock("../../../../js/lib/games/hex_enduro/renderer.js", () => ({
  getColors: vi.fn(() => ({
    bg: "#0a0a1a",
    p1: "#39ff14",
    p2: "#00e5ff",
    muted: "#1a1a2a",
    glow: "rgba(57,255,20,0.15)",
    warning: "#ff4444",
    road1: "#2a2a3a",
    road2: "#1a1a2a",
    lane: "#555566",
    mountain: "#151525",
    carAi: "#ff8c00",
    fuel: "#ffee00",
  })),
  render: vi.fn(),
}));

const { HexEnduroEngine } = await import("../../../../js/lib/games/hex_enduro/engine.js");
const { render, getColors } = await import("../../../../js/lib/games/hex_enduro/renderer.js");

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
  canvas.width = 640;
  canvas.height = 480;

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
    closePath: vi.fn(),
    setLineDash: vi.fn(),
    save: vi.fn(),
    restore: vi.fn(),
    translate: vi.fn(),
    rotate: vi.fn(),
    measureText: vi.fn(() => ({ width: 50 })),
    createLinearGradient: vi.fn(() => ({
      addColorStop: vi.fn(),
    })),
    createRadialGradient: vi.fn(() => ({
      addColorStop: vi.fn(),
    })),
  };
  canvas.getContext = vi.fn(() => mockCtx);

  return canvas;
}

describe("HexEnduroEngine", () => {
  let engine;
  let channel;
  let canvas;
  let originalRAF;
  let originalCAF;

  beforeEach(() => {
    originalRAF = globalThis.requestAnimationFrame;
    originalCAF = globalThis.cancelAnimationFrame;
    globalThis.requestAnimationFrame = vi.fn(() => 42);
    globalThis.cancelAnimationFrame = vi.fn();

    canvas = createMockCanvas();
    channel = createMockChannel();
    render.mockClear();
    getColors.mockClear();
  });

  afterEach(() => {
    vi.useRealTimers();
    globalThis.requestAnimationFrame = vi.fn(() => 42);
    globalThis.cancelAnimationFrame = vi.fn();
    if (engine) engine.stop();
    globalThis.requestAnimationFrame = originalRAF;
    globalThis.cancelAnimationFrame = originalCAF;
  });

  describe("construction", () => {
    it("creates with host role", () => {
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro", true, null);
      expect(engine.isHost).toBe(true);
      expect(engine.gameState.phase).toBe(PHASE.WAITING);
      expect(engine.mode).toBe(GAME_MODE.CLASSIC_DUEL);
    });

    it("creates with peer role", () => {
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro", false, null);
      expect(engine.isHost).toBe(false);
      expect(engine.seed).toBe(0);
    });

    it("selects correct mode from gameId", () => {
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro_night", true, null);
      expect(engine.mode).toBe(GAME_MODE.NIGHT_RACE);

      engine.stop();
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro_sprint", true, null);
      expect(engine.mode).toBe(GAME_MODE.SPRINT);
    });

    it("initializes game state", () => {
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro", true, null);
      expect(engine.gameState.p1.lane).toBe(1);
      expect(engine.gameState.p2.lane).toBe(0);
      expect(engine.gameState.p1.fuel).toBeGreaterThan(0);
      expect(engine.gameState.p2.fuel).toBeGreaterThan(0);
      expect(engine.gameState.aiCars).toEqual([]);
    });

    it("host generates a seed", () => {
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro", true, null);
      expect(engine.seed).toBeGreaterThan(0);
    });

    it("initializes local and remote inputs", () => {
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro", true, null);
      expect(engine.localInputs).toEqual({
        left: false,
        right: false,
        accel: false,
        brake: false,
        turbo: false,
      });
      expect(engine.remoteInputs).toEqual({
        left: false,
        right: false,
        accel: false,
        brake: false,
        turbo: false,
      });
    });
  });

  describe("start", () => {
    it("host waits for peer ready", () => {
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro", true, null);
      engine.start();
      expect(channel.send).not.toHaveBeenCalled();
      expect(engine.gameState.phase).toBe(PHASE.WAITING);
    });

    it("peer sends GAME_READY on start", () => {
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro", false, null);
      engine.start();
      expect(channel.send).toHaveBeenCalledTimes(1);
      const sent = channel.send.mock.calls[0][0];
      const view = new DataView(sent);
      expect(view.getUint8(0)).toBe(MSG_TYPE.GAME_READY);
    });

    it("reads colors from canvas", () => {
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro", true, null);
      engine.start();
      expect(getColors).toHaveBeenCalledWith(canvas);
      expect(engine.colors).not.toBeNull();
    });

    it("renders initial state", () => {
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro", true, null);
      engine.start();
      expect(render).toHaveBeenCalled();
    });

    it("does not start twice", () => {
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro", true, null);
      engine.start();
      const callCount = render.mock.calls.length;
      engine.start();
      expect(render.mock.calls.length).toBe(callCount);
    });
  });

  describe("GAME_READY handshake", () => {
    it("host starts countdown on GAME_READY", () => {
      vi.useFakeTimers();
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro", true, null);
      engine.start();

      const readyBuf = encodeGameReady();
      const handler = channel.addEventListener.mock.calls.find((c) => c[0] === "message")[1];
      handler({ data: readyBuf });

      expect(engine.peerReady).toBe(true);
      expect(engine.gameState.phase).toBe(PHASE.COUNTDOWN);
      expect(engine.gameState.countdown).toBe(3);
      vi.useRealTimers();
    });

    it("ignores duplicate GAME_READY", () => {
      vi.useFakeTimers();
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro", true, null);
      engine.start();

      const readyBuf = encodeGameReady();
      const handler = channel.addEventListener.mock.calls.find((c) => c[0] === "message")[1];
      handler({ data: readyBuf });
      const sendCountAfterFirst = channel.send.mock.calls.length;

      handler({ data: readyBuf });
      expect(channel.send.mock.calls.length).toBe(sendCountAfterFirst);
      vi.useRealTimers();
    });
  });

  describe("countdown", () => {
    it("counts down from 3 to racing", () => {
      vi.useFakeTimers();
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro", true, null);
      engine.start();

      const handler = channel.addEventListener.mock.calls.find((c) => c[0] === "message")[1];
      handler({ data: encodeGameReady() });

      expect(engine.gameState.countdown).toBe(3);

      vi.advanceTimersByTime(1000);
      expect(engine.gameState.countdown).toBe(2);

      vi.advanceTimersByTime(1000);
      expect(engine.gameState.countdown).toBe(1);

      vi.advanceTimersByTime(1000);
      expect(engine.gameState.phase).toBe(PHASE.RACING);
      vi.useRealTimers();
    });

    it("starts engine drone when racing begins", () => {
      vi.useFakeTimers();
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro", true, null);
      engine.start();

      const handler = channel.addEventListener.mock.calls.find((c) => c[0] === "message")[1];
      handler({ data: encodeGameReady() });

      vi.advanceTimersByTime(3000);
      expect(engine.audio.startEngineDrone).toHaveBeenCalled();
      vi.useRealTimers();
    });
  });

  describe("input handling", () => {
    it("maps arrow keys to input codes", () => {
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro", true, null);
      expect(engine._mapKey("ArrowLeft")).toBe(INPUT_KEY.LEFT);
      expect(engine._mapKey("ArrowRight")).toBe(INPUT_KEY.RIGHT);
      expect(engine._mapKey("ArrowUp")).toBe(INPUT_KEY.ACCEL);
      expect(engine._mapKey("ArrowDown")).toBe(INPUT_KEY.BRAKE);
      expect(engine._mapKey(" ")).toBe(INPUT_KEY.TURBO);
      expect(engine._mapKey("Shift")).toBe(INPUT_KEY.TURBO);
    });

    it("maps WASD keys", () => {
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro", true, null);
      expect(engine._mapKey("a")).toBe(INPUT_KEY.LEFT);
      expect(engine._mapKey("A")).toBe(INPUT_KEY.LEFT);
      expect(engine._mapKey("d")).toBe(INPUT_KEY.RIGHT);
      expect(engine._mapKey("D")).toBe(INPUT_KEY.RIGHT);
      expect(engine._mapKey("w")).toBe(INPUT_KEY.ACCEL);
      expect(engine._mapKey("W")).toBe(INPUT_KEY.ACCEL);
      expect(engine._mapKey("s")).toBe(INPUT_KEY.BRAKE);
      expect(engine._mapKey("S")).toBe(INPUT_KEY.BRAKE);
    });

    it("returns null for unmapped keys", () => {
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro", true, null);
      expect(engine._mapKey("Enter")).toBeNull();
      expect(engine._mapKey("z")).toBeNull();
    });

    it("host sets local inputs on keydown", () => {
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro", true, null);
      engine.start();

      engine._handleKeyDown({ key: "ArrowLeft", preventDefault: vi.fn() });
      expect(engine.localInputs.left).toBe(true);

      engine._handleKeyUp({ key: "ArrowLeft", preventDefault: vi.fn() });
      expect(engine.localInputs.left).toBe(false);
    });

    it("peer sends input over channel", () => {
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro", false, null);
      engine.start();
      channel.send.mockClear();

      engine._handleKeyDown({ key: "ArrowLeft", preventDefault: vi.fn() });
      expect(channel.send).toHaveBeenCalled();
    });

    it("clears all inputs on blur", () => {
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro", false, null);
      engine.start();

      engine.localInputs.left = true;
      engine.localInputs.accel = true;
      engine.localInputs.turbo = true;
      engine._handleBlur();

      expect(engine.localInputs.left).toBe(false);
      expect(engine.localInputs.accel).toBe(false);
      expect(engine.localInputs.turbo).toBe(false);
    });
  });

  describe("peer state application", () => {
    it("applies decoded state from host", () => {
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro", false, null);
      engine.start();

      const state = packState(createInitialState(GAME_MODE.CLASSIC_DUEL, 42));
      state.phase = PHASE.RACING;
      state.p1Speed = 500;
      state.p1Score = 25;
      state.p2Score = 10;
      state.seed = 42;

      const buf = encodeGameState(state);
      const handler = channel.addEventListener.mock.calls.find((c) => c[0] === "message")[1];
      handler({ data: buf });

      expect(engine.gameState.phase).toBe(PHASE.RACING);
      expect(engine.gameState.p1.score).toBe(25);
      expect(engine.gameState.p2.score).toBe(10);
      expect(engine.seed).toBe(42);
    });

    it("bootstraps seed from first state", () => {
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro", false, null);
      engine.start();
      expect(engine.seed).toBe(0);

      const state = packState(createInitialState(GAME_MODE.CLASSIC_DUEL, 99999));
      state.seed = 99999;

      const handler = channel.addEventListener.mock.calls.find((c) => c[0] === "message")[1];
      handler({ data: encodeGameState(state) });

      expect(engine.seed).toBe(99999);
    });
  });

  describe("game end", () => {
    it("peer handles GAME_END message", () => {
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro", false, null);
      engine.start();

      const result = { score1: 100, score2: 80, winner: 1 };
      const buf = encodeGameEnd(result);
      const handler = channel.addEventListener.mock.calls.find((c) => c[0] === "message")[1];
      handler({ data: buf });

      expect(engine.gameState.phase).toBe(PHASE.FINISHED);
    });

    it("peer plays victory audio when winning", () => {
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro", false, null);
      engine.start();

      // Peer is P2, so winner=2 means peer wins
      const result = { score1: 80, score2: 100, winner: 2 };
      const buf = encodeGameEnd(result);
      const handler = channel.addEventListener.mock.calls.find((c) => c[0] === "message")[1];
      handler({ data: buf });

      expect(engine.audio.playVictory).toHaveBeenCalled();
    });

    it("peer plays game over audio when losing", () => {
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro", false, null);
      engine.start();

      // Peer is P2, so winner=1 means peer loses
      const result = { score1: 100, score2: 80, winner: 1 };
      const buf = encodeGameEnd(result);
      const handler = channel.addEventListener.mock.calls.find((c) => c[0] === "message")[1];
      handler({ data: buf });

      expect(engine.audio.playGameOver).toHaveBeenCalled();
    });

    it("host calls onGameEnd callback", () => {
      const onGameEnd = vi.fn();
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro", true, onGameEnd);
      engine.start();

      engine.gameState.p1.score = 50;
      engine.gameState.p2.score = 30;
      engine.gameState.phase = PHASE.FINISHED;

      engine._handleGameEnd();

      expect(onGameEnd).toHaveBeenCalledWith({
        score: { p1: 50, p2: 30 },
        winner: 1,
      });
    });

    it("peer calls onGameEnd callback from GAME_END message", () => {
      const onGameEnd = vi.fn();
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro", false, onGameEnd);
      engine.start();

      const result = { score1: 100, score2: 80, winner: 1 };
      const buf = encodeGameEnd(result);
      const handler = channel.addEventListener.mock.calls.find((c) => c[0] === "message")[1];
      handler({ data: buf });

      expect(onGameEnd).toHaveBeenCalledWith({
        score: { p1: 100, p2: 80 },
        winner: 1,
      });
    });
  });

  describe("stop", () => {
    it("cleans up timers and animation frames", () => {
      vi.useFakeTimers();
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro", true, null);
      engine.start();

      const handler = channel.addEventListener.mock.calls.find((c) => c[0] === "message")[1];
      handler({ data: encodeGameReady() });

      engine.stop();
      expect(engine.running).toBe(false);
      vi.useRealTimers();
    });

    it("stops engine drone on stop", () => {
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro", true, null);
      engine.start();
      engine.stop();
      expect(engine.audio.stopEngineDrone).toHaveBeenCalled();
    });

    it("destroys audio on stop", () => {
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro", true, null);
      engine.start();
      engine.stop();
      expect(engine.audio.destroy).toHaveBeenCalled();
    });

    it("guards phase callbacks after stop", () => {
      vi.useFakeTimers();
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro", true, null);
      engine.start();

      const handler = channel.addEventListener.mock.calls.find((c) => c[0] === "message")[1];
      handler({ data: encodeGameReady() });

      engine.stop();

      vi.advanceTimersByTime(3000);
      expect(engine.running).toBe(false);
      vi.useRealTimers();
    });
  });

  describe("host remote input", () => {
    it("applies remote player input", () => {
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro", true, null);
      engine.start();

      const inputBuf = encodePlayerInput(INPUT_KEY.LEFT, true);
      const handler = channel.addEventListener.mock.calls.find((c) => c[0] === "message")[1];
      handler({ data: inputBuf });

      expect(engine.remoteInputs.left).toBe(true);
    });

    it("applies remote turbo input", () => {
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro", true, null);
      engine.start();

      const handler = channel.addEventListener.mock.calls.find((c) => c[0] === "message")[1];
      handler({ data: encodePlayerInput(INPUT_KEY.TURBO, true) });
      expect(engine.remoteInputs.turbo).toBe(true);

      handler({ data: encodePlayerInput(INPUT_KEY.TURBO, false) });
      expect(engine.remoteInputs.turbo).toBe(false);
    });
  });

  describe("message filtering", () => {
    it("ignores non-ArrayBuffer messages", () => {
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro", true, null);
      engine.start();

      const handler = channel.addEventListener.mock.calls.find((c) => c[0] === "message")[1];
      handler({ data: "not binary" });
    });

    it("ignores empty buffers", () => {
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro", true, null);
      engine.start();

      const handler = channel.addEventListener.mock.calls.find((c) => c[0] === "message")[1];
      handler({ data: new ArrayBuffer(0) });
    });
  });

  describe("game loop", () => {
    function setupRacing(eng, chan) {
      vi.useFakeTimers();
      globalThis.requestAnimationFrame = vi.fn(() => 42);
      globalThis.cancelAnimationFrame = vi.fn();

      eng.start();
      const handler = chan.addEventListener.mock.calls.find((c) => c[0] === "message")[1];
      handler({ data: encodeGameReady() });
      vi.advanceTimersByTime(3000);
    }

    function getLoopFn() {
      return globalThis.requestAnimationFrame.mock.calls.at(-1)[0];
    }

    it("runs game loop and broadcasts state", () => {
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro", true, null);
      setupRacing(engine, channel);

      expect(engine.gameState.phase).toBe(PHASE.RACING);

      const loopFn = getLoopFn();
      channel.send.mockClear();
      loopFn(); // frame 1
      loopFn(); // frame 2 — should broadcast (STATE_SEND_INTERVAL = 2)

      expect(channel.send).toHaveBeenCalled();
      vi.useRealTimers();
    });

    it("renders each frame", () => {
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro", true, null);
      setupRacing(engine, channel);

      render.mockClear();
      const loopFn = getLoopFn();
      loopFn();

      expect(render).toHaveBeenCalled();
      vi.useRealTimers();
    });

    it("edge-triggers turbo on press not hold", () => {
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro", true, null);
      setupRacing(engine, channel);

      // Set P1 speed high enough and with turbo charges
      engine.gameState.p1.speed = 600;
      engine.gameState.p1.turboCharges = 3;

      engine.localInputs.turbo = true;
      const loopFn = getLoopFn();
      loopFn(); // should activate turbo

      expect(engine.gameState.p1.boost).toBeGreaterThan(0);

      // Second frame — still holding, should NOT re-trigger
      const boostAfterFirst = engine.gameState.p1.boost;
      engine.gameState.p1.turboCharges = 3;
      loopFn();
      // Boost should have decreased (tick), not reset from new activation
      expect(engine.gameState.p1.boost).toBeLessThanOrEqual(boostAfterFirst);

      vi.useRealTimers();
    });

    it("updates engine pitch based on speed", () => {
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro", true, null);
      setupRacing(engine, channel);

      engine.audio.updateEnginePitch.mockClear();
      getLoopFn()();

      expect(engine.audio.updateEnginePitch).toHaveBeenCalled();
      vi.useRealTimers();
    });
  });

  describe("audio events", () => {
    it("plays collision audio on collision event", () => {
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro", true, null);
      engine.start();

      engine._playEventsAudio(EVENT.COLLISION);
      expect(engine.audio.playCollision).toHaveBeenCalled();
    });

    it("plays overtake AI audio", () => {
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro", true, null);
      engine.start();

      engine._playEventsAudio(EVENT.OVERTAKE_AI);
      expect(engine.audio.playOvertakeAI).toHaveBeenCalled();
    });

    it("plays multiple events from bitmask", () => {
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro", true, null);
      engine.start();

      engine._playEventsAudio(EVENT.COLLISION | EVENT.FUEL_PICKUP);
      expect(engine.audio.playCollision).toHaveBeenCalled();
      expect(engine.audio.playFuelPickup).toHaveBeenCalled();
    });
  });

  describe("DataChannel resilience", () => {
    it("handles closed channel without throwing", () => {
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro", false, null);
      engine.start();

      channel.readyState = "closed";

      expect(() => {
        engine._safeSend(encodePlayerInput(INPUT_KEY.LEFT, true));
      }).not.toThrow();
    });

    it("handles channel send error without throwing", () => {
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro", true, null);
      engine.start();

      channel.send.mockImplementation(() => {
        throw new Error("send failed");
      });

      expect(() => {
        engine._safeSend(encodePlayerInput(INPUT_KEY.LEFT, true));
      }).not.toThrow();
    });
  });

  describe("channel close handling", () => {
    it("sets phase to FINISHED on channel close during racing", () => {
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro", true, null);
      engine.start();
      engine.gameState.phase = PHASE.RACING;

      const closeHandler = channel.addEventListener.mock.calls.find((c) => c[0] === "close")[1];
      closeHandler();

      expect(engine.gameState.phase).toBe(PHASE.FINISHED);
      expect(engine.audio.stopEngineDrone).toHaveBeenCalled();
    });

    it("does not change phase if already finished", () => {
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro", true, null);
      engine.start();
      engine.gameState.phase = PHASE.FINISHED;

      const closeHandler = channel.addEventListener.mock.calls.find((c) => c[0] === "close")[1];
      closeHandler();

      expect(engine.gameState.phase).toBe(PHASE.FINISHED);
    });

    it("stops game loop and clears countdown on close", () => {
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro", true, null);
      engine.start();
      engine.gameState.phase = PHASE.RACING;
      engine.animFrame = 999;
      engine.phaseTimer = setTimeout(() => {}, 10000);

      const closeHandler = channel.addEventListener.mock.calls.find((c) => c[0] === "close")[1];
      closeHandler();

      expect(engine.animFrame).toBeNull();
      expect(engine.phaseTimer).toBeNull();
      expect(engine.audio.playGameOver).toHaveBeenCalled();
    });

    it("calls onGameEnd with draw on channel close", () => {
      const onGameEnd = vi.fn();
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro", true, onGameEnd);
      engine.start();
      engine.gameState.phase = PHASE.RACING;
      engine.gameState.p1.score = 42;
      engine.gameState.p2.score = 38;

      const closeHandler = channel.addEventListener.mock.calls.find((c) => c[0] === "close")[1];
      closeHandler();

      expect(onGameEnd).toHaveBeenCalledWith({
        score: { p1: 42, p2: 38 },
        winner: 0,
      });
    });
  });

  describe("engine resilience", () => {
    it("_startGameLoop guards against double-call", () => {
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro", true, null);
      engine.start();
      engine.animFrame = 123;
      engine._startGameLoop();
      // Should not have overwritten — guard returns early
      expect(engine.animFrame).toBe(123);
    });

    it("_broadcastState does not crash on encoding error", () => {
      engine = new HexEnduroEngine(canvas, channel, "hex_enduro", true, null);
      engine.start();
      // Corrupt state to cause encoding error
      engine.gameState = null;
      expect(() => engine._broadcastState()).not.toThrow();
    });
  });
});
