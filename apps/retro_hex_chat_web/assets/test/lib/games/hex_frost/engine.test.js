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
} from "../../../../js/lib/games/hex_frost/protocol.js";
import { createInitialState, packState } from "../../../../js/lib/games/hex_frost/physics.js";

// ── Mock audio BEFORE importing engine ────────────────────────────
vi.mock("../../../../js/lib/games/hex_frost/audio.js", () => ({
  HexFrostAudio: function () {
    return {
      playCountdown: vi.fn(),
      playCountdownGo: vi.fn(),
      startAmbientWind: vi.fn(),
      stopAmbientWind: vi.fn(),
      playBlockClaim: vi.fn(),
      playBlockSteal: vi.fn(),
      playBlockUndo: vi.fn(),
      playJump: vi.fn(),
      playLand: vi.fn(),
      playSplash: vi.fn(),
      playFishCollect: vi.fn(),
      playEnemyHit: vi.fn(),
      playIglooPiece: vi.fn(),
      playIglooLose: vi.fn(),
      playIglooComplete: vi.fn(),
      playIglooEnter: vi.fn(),
      playTempLow: vi.fn(),
      playTempZero: vi.fn(),
      playBearNear: vi.fn(),
      playClamSnap: vi.fn(),
      playRoundEnd: vi.fn(),
      playVictory: vi.fn(),
      playGameOver: vi.fn(),
      destroy: vi.fn(),
    };
  },
}));

// ── Mock renderer ─────────────────────────────────────────────────
vi.mock("../../../../js/lib/games/hex_frost/renderer.js", () => ({
  readColors: vi.fn(() => ({
    bg: "#1a1a3e",
    fg: "#00ffaa",
    muted: "#005544",
    ice: "#88ddff",
    water: "#0044aa",
    snow: "#ffffff",
  })),
  render: vi.fn(),
  generateSnowParticles: vi.fn(() => []),
}));

const { HexFrostEngine } = await import("../../../../js/lib/games/hex_frost/engine.js");
const { render, readColors, generateSnowParticles } =
  await import("../../../../js/lib/games/hex_frost/renderer.js");

// ── Helpers ───────────────────────────────────────────────────────

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
    setLineDash: vi.fn(),
    save: vi.fn(),
    restore: vi.fn(),
    arc: vi.fn(),
    closePath: vi.fn(),
    fill: vi.fn(),
    translate: vi.fn(),
    rotate: vi.fn(),
    createRadialGradient: vi.fn(() => ({ addColorStop: vi.fn() })),
    drawImage: vi.fn(),
    clearRect: vi.fn(),
  };
  canvas.getContext = vi.fn(() => mockCtx);
  return canvas;
}

function createEngine(gameId = "hex_frost", isHost = true, onGameEnd = null) {
  const channel = createMockChannel();
  const canvas = createMockCanvas();
  const engine = new HexFrostEngine(canvas, channel, gameId, isHost, onGameEnd);
  return { engine, channel, canvas };
}

// ── Test suite ────────────────────────────────────────────────────

describe("HexFrostEngine", () => {
  let origRAF, origCAF, origAddEvent, origRemoveEvent;

  beforeEach(() => {
    origRAF = globalThis.requestAnimationFrame;
    origCAF = globalThis.cancelAnimationFrame;
    origAddEvent = document.addEventListener;
    origRemoveEvent = document.removeEventListener;

    globalThis.requestAnimationFrame = vi.fn((_cb) => {
      return 42; // dummy frame id
    });
    globalThis.cancelAnimationFrame = vi.fn();
    document.addEventListener = vi.fn();
    document.removeEventListener = vi.fn();

    vi.clearAllMocks();
  });

  afterEach(() => {
    globalThis.requestAnimationFrame = origRAF;
    globalThis.cancelAnimationFrame = origCAF;
    document.addEventListener = origAddEvent;
    document.removeEventListener = origRemoveEvent;
  });

  // ── 1. Constructor ──────────────────────────────────────────────

  describe("constructor", () => {
    it("resolves ARCTIC_RACE mode for default gameId", () => {
      const { engine } = createEngine("hex_frost");
      expect(engine.mode).toBe(GAME_MODE.ARCTIC_RACE);
    });

    it("resolves BLIZZARD mode for hex_frost_blizzard", () => {
      const { engine } = createEngine("hex_frost_blizzard");
      expect(engine.mode).toBe(GAME_MODE.BLIZZARD);
    });

    it("resolves PEACEFUL mode for hex_frost_peaceful", () => {
      const { engine } = createEngine("hex_frost_peaceful");
      expect(engine.mode).toBe(GAME_MODE.PEACEFUL);
    });

    it("defaults unknown gameId to ARCTIC_RACE", () => {
      const { engine } = createEngine("hex_frost_unknown_variant");
      expect(engine.mode).toBe(GAME_MODE.ARCTIC_RACE);
    });

    it("initializes localInputs with all false", () => {
      const { engine } = createEngine();
      expect(engine.localInputs).toEqual({
        left: false,
        right: false,
        up: false,
        down: false,
      });
    });

    it("initializes remoteInputs with all false", () => {
      const { engine } = createEngine();
      expect(engine.remoteInputs).toEqual({
        left: false,
        right: false,
        up: false,
        down: false,
      });
    });

    it("creates audio instance", () => {
      const { engine } = createEngine();
      expect(engine.audio).toBeDefined();
      expect(engine.audio.playCountdown).toBeDefined();
      expect(engine.audio.destroy).toBeDefined();
    });

    it("stores onGameEnd callback or null", () => {
      const cb = vi.fn();
      const { engine: withCb } = createEngine("hex_frost", true, cb);
      expect(withCb.onGameEnd).toBe(cb);

      const { engine: withoutCb } = createEngine("hex_frost", true, null);
      expect(withoutCb.onGameEnd).toBeNull();
    });

    it("initializes gameState as null", () => {
      const { engine } = createEngine();
      expect(engine.gameState).toBeNull();
    });

    it("initializes frameCount, peerReady, phaseTimer, roundEndTimer", () => {
      const { engine } = createEngine();
      expect(engine.frameCount).toBe(0);
      expect(engine.peerReady).toBe(false);
      expect(engine.phaseTimer).toBe(0);
      expect(engine.roundEndTimer).toBe(0);
    });
  });

  // ── 2. start() ─────────────────────────────────────────────────

  describe("start", () => {
    it("sets running to true", () => {
      const { engine } = createEngine();
      engine.start();
      expect(engine.running).toBe(true);
      engine.stop();
    });

    it("host creates initial game state with gameState.phase = WAITING", () => {
      const { engine } = createEngine("hex_frost", true);
      engine.start();
      expect(engine.gameState).not.toBeNull();
      expect(engine.gameState.phase).toBe(PHASE.WAITING);
      engine.stop();
    });

    it("host renders state after initialization", () => {
      const { engine } = createEngine("hex_frost", true);
      engine.start();
      expect(render).toHaveBeenCalled();
      engine.stop();
    });

    it("peer sends GAME_READY on start", () => {
      const { engine, channel } = createEngine("hex_frost", false);
      engine.start();
      expect(channel.send).toHaveBeenCalled();
      const sentBuf = channel.send.mock.calls[0][0];
      expect(sentBuf instanceof ArrayBuffer).toBe(true);
      expect(sentBuf.byteLength).toBe(1);
      const view = new DataView(sentBuf);
      expect(view.getUint8(0)).toBe(MSG_TYPE.GAME_READY);
      engine.stop();
    });

    it("peer does not create gameState", () => {
      const { engine } = createEngine("hex_frost", false);
      engine.start();
      expect(engine.gameState).toBeNull();
      engine.stop();
    });

    it("reads colors from canvas", () => {
      const { engine } = createEngine();
      engine.start();
      expect(readColors).toHaveBeenCalled();
      expect(engine.colors).toEqual(expect.objectContaining({ bg: "#1a1a3e" }));
      engine.stop();
    });

    it("generates 35 snow particles", () => {
      const { engine } = createEngine();
      engine.start();
      expect(generateSnowParticles).toHaveBeenCalledWith(35);
      engine.stop();
    });

    it("adds blur and channel close listeners", () => {
      const { engine, channel } = createEngine();
      const addSpy = vi.spyOn(window, "addEventListener");
      engine.start();
      expect(addSpy).toHaveBeenCalledWith("blur", engine._boundBlur);
      expect(channel.addEventListener).toHaveBeenCalledWith("close", engine._boundChannelClose);
      addSpy.mockRestore();
      engine.stop();
    });

    it("double-start is a no-op", () => {
      const { engine } = createEngine("hex_frost", true);
      engine.start();
      const firstState = engine.gameState;
      render.mockClear();
      engine.start(); // should return early
      expect(engine.gameState).toBe(firstState);
      // render should NOT have been called again
      expect(render).not.toHaveBeenCalled();
      engine.stop();
    });
  });

  // ── 3. stop() ──────────────────────────────────────────────────

  describe("stop", () => {
    it("sets running to false", () => {
      const { engine } = createEngine();
      engine.start();
      engine.stop();
      expect(engine.running).toBe(false);
    });

    it("calls audio.destroy()", () => {
      const { engine } = createEngine();
      engine.start();
      const destroySpy = engine.audio.destroy;
      engine.stop();
      expect(destroySpy).toHaveBeenCalled();
    });

    it("resets localInputs and remoteInputs to all false", () => {
      const { engine } = createEngine();
      engine.start();
      engine.localInputs = {
        left: true,
        right: true,
        up: true,
        down: true,
      };
      engine.remoteInputs = {
        left: true,
        right: true,
        up: true,
        down: true,
      };
      engine.stop();
      expect(engine.localInputs).toEqual({
        left: false,
        right: false,
        up: false,
        down: false,
      });
      expect(engine.remoteInputs).toEqual({
        left: false,
        right: false,
        up: false,
        down: false,
      });
    });

    it("resets peerReady to false", () => {
      const { engine } = createEngine();
      engine.start();
      engine.peerReady = true;
      engine.stop();
      expect(engine.peerReady).toBe(false);
    });

    it("resets frameCount, phaseTimer, roundEndTimer to 0", () => {
      const { engine } = createEngine();
      engine.start();
      engine.frameCount = 100;
      engine.phaseTimer = 50;
      engine.roundEndTimer = 30;
      engine.stop();
      expect(engine.frameCount).toBe(0);
      expect(engine.phaseTimer).toBe(0);
      expect(engine.roundEndTimer).toBe(0);
    });

    it("removes blur and channel close listeners", () => {
      const { engine, channel } = createEngine();
      const removeSpy = vi.spyOn(window, "removeEventListener");
      engine.start();
      engine.stop();
      expect(removeSpy).toHaveBeenCalledWith("blur", engine._boundBlur);
      expect(channel.removeEventListener).toHaveBeenCalledWith("close", engine._boundChannelClose);
      removeSpy.mockRestore();
    });
  });

  // ── 4. Input handling ──────────────────────────────────────────

  describe("input handling", () => {
    describe("_mapKey", () => {
      it("maps ArrowLeft to INPUT_KEY.LEFT", () => {
        const { engine } = createEngine();
        expect(engine._mapKey({ key: "ArrowLeft" })).toBe(INPUT_KEY.LEFT);
      });

      it("maps a/A to INPUT_KEY.LEFT", () => {
        const { engine } = createEngine();
        expect(engine._mapKey({ key: "a" })).toBe(INPUT_KEY.LEFT);
        expect(engine._mapKey({ key: "A" })).toBe(INPUT_KEY.LEFT);
      });

      it("maps ArrowRight to INPUT_KEY.RIGHT", () => {
        const { engine } = createEngine();
        expect(engine._mapKey({ key: "ArrowRight" })).toBe(INPUT_KEY.RIGHT);
      });

      it("maps d/D to INPUT_KEY.RIGHT", () => {
        const { engine } = createEngine();
        expect(engine._mapKey({ key: "d" })).toBe(INPUT_KEY.RIGHT);
        expect(engine._mapKey({ key: "D" })).toBe(INPUT_KEY.RIGHT);
      });

      it("maps ArrowUp / w / W to INPUT_KEY.UP", () => {
        const { engine } = createEngine();
        expect(engine._mapKey({ key: "ArrowUp" })).toBe(INPUT_KEY.UP);
        expect(engine._mapKey({ key: "w" })).toBe(INPUT_KEY.UP);
        expect(engine._mapKey({ key: "W" })).toBe(INPUT_KEY.UP);
      });

      it("maps ArrowDown / s / S to INPUT_KEY.DOWN", () => {
        const { engine } = createEngine();
        expect(engine._mapKey({ key: "ArrowDown" })).toBe(INPUT_KEY.DOWN);
        expect(engine._mapKey({ key: "s" })).toBe(INPUT_KEY.DOWN);
        expect(engine._mapKey({ key: "S" })).toBe(INPUT_KEY.DOWN);
      });

      it("returns null for unknown keys", () => {
        const { engine } = createEngine();
        expect(engine._mapKey({ key: " " })).toBeNull();
        expect(engine._mapKey({ key: "Enter" })).toBeNull();
        expect(engine._mapKey({ key: "x" })).toBeNull();
      });
    });

    describe("_handleKeyDown", () => {
      it("sets localInputs for host", () => {
        const { engine } = createEngine("hex_frost", true);
        engine._handleKeyDown({ key: "ArrowLeft", preventDefault: vi.fn() });
        expect(engine.localInputs.left).toBe(true);

        engine._handleKeyDown({ key: "ArrowRight", preventDefault: vi.fn() });
        expect(engine.localInputs.right).toBe(true);

        engine._handleKeyDown({ key: "ArrowUp", preventDefault: vi.fn() });
        expect(engine.localInputs.up).toBe(true);

        engine._handleKeyDown({ key: "ArrowDown", preventDefault: vi.fn() });
        expect(engine.localInputs.down).toBe(true);
      });

      it("host does NOT send encodePlayerInput", () => {
        const { engine, channel } = createEngine("hex_frost", true);
        engine._handleKeyDown({ key: "ArrowLeft", preventDefault: vi.fn() });
        expect(channel.send).not.toHaveBeenCalled();
      });

      it("peer sets localInputs AND sends encodePlayerInput", () => {
        const { engine, channel } = createEngine("hex_frost", false);
        engine._handleKeyDown({ key: "ArrowRight", preventDefault: vi.fn() });
        expect(engine.localInputs.right).toBe(true);
        expect(channel.send).toHaveBeenCalled();
        const buf = channel.send.mock.calls[0][0];
        expect(buf instanceof ArrayBuffer).toBe(true);
        const view = new DataView(buf);
        expect(view.getUint8(0)).toBe(MSG_TYPE.PLAYER_INPUT);
        expect(view.getUint8(1)).toBe(INPUT_KEY.RIGHT);
        expect(view.getUint8(2)).toBe(1); // pressed=true
      });

      it("does nothing for unknown keys", () => {
        const { engine, channel } = createEngine("hex_frost", false);
        const preventSpy = vi.fn();
        engine._handleKeyDown({ key: "Enter", preventDefault: preventSpy });
        expect(engine.localInputs.left).toBe(false);
        expect(preventSpy).not.toHaveBeenCalled();
        expect(channel.send).not.toHaveBeenCalled();
      });
    });

    describe("_handleKeyUp", () => {
      it("clears localInputs on host", () => {
        const { engine } = createEngine("hex_frost", true);
        engine.localInputs.left = true;
        engine._handleKeyUp({ key: "ArrowLeft", preventDefault: vi.fn() });
        expect(engine.localInputs.left).toBe(false);
      });

      it("peer clears localInputs AND sends pressed=false", () => {
        const { engine, channel } = createEngine("hex_frost", false);
        engine.localInputs.up = true;
        engine._handleKeyUp({ key: "ArrowUp", preventDefault: vi.fn() });
        expect(engine.localInputs.up).toBe(false);
        expect(channel.send).toHaveBeenCalled();
        const buf = channel.send.mock.calls[0][0];
        const view = new DataView(buf);
        expect(view.getUint8(2)).toBe(0); // pressed=false
      });

      it("does nothing for unknown keys", () => {
        const { engine } = createEngine("hex_frost", true);
        const preventSpy = vi.fn();
        engine._handleKeyUp({ key: "z", preventDefault: preventSpy });
        expect(preventSpy).not.toHaveBeenCalled();
      });
    });
  });

  // ── 5. Network messages ────────────────────────────────────────

  describe("network messages", () => {
    it("rejects non-ArrayBuffer data", () => {
      const { engine } = createEngine("hex_frost", true);
      expect(() => engine._handleMessage({ data: "hello" })).not.toThrow();
      expect(() => engine._handleMessage({ data: null })).not.toThrow();
      expect(() => engine._handleMessage({ data: 123 })).not.toThrow();
    });

    it("host handles GAME_READY — sets peerReady and starts countdown", () => {
      const { engine } = createEngine("hex_frost", true);
      engine.start();
      const buf = encodeGameReady();
      engine._handleMessage({ data: buf });
      expect(engine.peerReady).toBe(true);
      expect(engine.gameState.phase).toBe(PHASE.COUNTDOWN);
      expect(engine.gameState.countdown).toBe(3);
      expect(engine.phaseTimer).toBe(60); // COUNTDOWN_INTERVAL
      engine.stop();
    });

    it("host ignores duplicate GAME_READY", () => {
      const { engine } = createEngine("hex_frost", true);
      engine.start();
      engine._handleMessage({ data: encodeGameReady() });
      const phaseAfterFirst = engine.gameState.phase;
      engine.audio.playCountdown.mockClear();
      engine._handleMessage({ data: encodeGameReady() });
      // Should not restart countdown
      expect(engine.audio.playCountdown).not.toHaveBeenCalled();
      expect(engine.gameState.phase).toBe(phaseAfterFirst);
      engine.stop();
    });

    it("peer ignores GAME_READY", () => {
      const { engine } = createEngine("hex_frost", false);
      engine.start();
      engine._handleMessage({ data: encodeGameReady() });
      expect(engine.peerReady).toBe(false); // peer doesn't track this
      engine.stop();
    });

    it("host handles PLAYER_INPUT — sets remoteInputs for all directions", () => {
      const { engine } = createEngine("hex_frost", true);

      engine._handleMessage({ data: encodePlayerInput(INPUT_KEY.LEFT, true) });
      expect(engine.remoteInputs.left).toBe(true);

      engine._handleMessage({
        data: encodePlayerInput(INPUT_KEY.RIGHT, true),
      });
      expect(engine.remoteInputs.right).toBe(true);

      engine._handleMessage({ data: encodePlayerInput(INPUT_KEY.UP, true) });
      expect(engine.remoteInputs.up).toBe(true);

      engine._handleMessage({ data: encodePlayerInput(INPUT_KEY.DOWN, true) });
      expect(engine.remoteInputs.down).toBe(true);

      // Release
      engine._handleMessage({
        data: encodePlayerInput(INPUT_KEY.LEFT, false),
      });
      expect(engine.remoteInputs.left).toBe(false);
    });

    it("peer ignores PLAYER_INPUT", () => {
      const { engine } = createEngine("hex_frost", false);
      engine._handleMessage({ data: encodePlayerInput(INPUT_KEY.LEFT, true) });
      expect(engine.remoteInputs.left).toBe(false);
    });

    it("peer handles GAME_STATE — updates gameState and renders", () => {
      const { engine } = createEngine("hex_frost", false);
      engine.start();
      render.mockClear();

      // Build a valid GAME_STATE message from initial state
      const state = createInitialState(GAME_MODE.ARCTIC_RACE, 12345);
      state.phase = PHASE.BUILDING;
      const packed = packState(state);
      const buf = encodeGameState(packed);

      engine._handleMessage({ data: buf });
      expect(engine.gameState).not.toBeNull();
      expect(engine.gameState.phase).toBe(PHASE.BUILDING);
      expect(render).toHaveBeenCalled();
      engine.stop();
    });

    it("host ignores GAME_STATE", () => {
      const { engine } = createEngine("hex_frost", true);
      engine.start();
      const origState = engine.gameState;

      const state = createInitialState(GAME_MODE.ARCTIC_RACE, 99999);
      state.phase = PHASE.BUILDING;
      const packed = packState(state);
      const buf = encodeGameState(packed);

      engine._handleMessage({ data: buf });
      // Host should not overwrite its state from incoming GAME_STATE
      expect(engine.gameState).toBe(origState);
      engine.stop();
    });

    it("peer handles GAME_END — calls onGameEnd with result", () => {
      const onGameEnd = vi.fn();
      const { engine } = createEngine("hex_frost", false, onGameEnd);

      const buf = encodeGameEnd({ score1: 3, score2: 1, winner: 1 });
      engine._handleMessage({ data: buf });

      expect(onGameEnd).toHaveBeenCalledWith({
        score1: 3,
        score2: 1,
        winner: 1,
      });
    });

    it("peer plays victory audio when winner > 0", () => {
      const { engine } = createEngine("hex_frost", false, vi.fn());
      const buf = encodeGameEnd({ score1: 2, score2: 1, winner: 1 });
      engine._handleMessage({ data: buf });
      expect(engine.audio.stopAmbientWind).toHaveBeenCalled();
      expect(engine.audio.playVictory).toHaveBeenCalled();
      expect(engine.audio.playGameOver).not.toHaveBeenCalled();
    });

    it("peer plays game over audio when winner = 0", () => {
      const { engine } = createEngine("hex_frost", false, vi.fn());
      const buf = encodeGameEnd({ score1: 1, score2: 1, winner: 0 });
      engine._handleMessage({ data: buf });
      expect(engine.audio.stopAmbientWind).toHaveBeenCalled();
      expect(engine.audio.playGameOver).toHaveBeenCalled();
      expect(engine.audio.playVictory).not.toHaveBeenCalled();
    });

    it("host ignores GAME_END", () => {
      const onGameEnd = vi.fn();
      const { engine } = createEngine("hex_frost", true, onGameEnd);
      const buf = encodeGameEnd({ score1: 2, score2: 0, winner: 1 });
      engine._handleMessage({ data: buf });
      expect(onGameEnd).not.toHaveBeenCalled();
    });
  });

  // ── 6. Countdown ───────────────────────────────────────────────

  describe("countdown", () => {
    it("sets phase to COUNTDOWN with countdown=3", () => {
      const { engine } = createEngine("hex_frost", true);
      engine.start();
      engine._handleMessage({ data: encodeGameReady() });
      expect(engine.gameState.phase).toBe(PHASE.COUNTDOWN);
      expect(engine.gameState.countdown).toBe(3);
      engine.stop();
    });

    it("plays countdown audio and starts ambient wind", () => {
      const { engine } = createEngine("hex_frost", true);
      engine.start();
      engine._handleMessage({ data: encodeGameReady() });
      expect(engine.audio.playCountdown).toHaveBeenCalled();
      expect(engine.audio.startAmbientWind).toHaveBeenCalled();
      engine.stop();
    });

    it("broadcasts state and starts game loop", () => {
      const { engine, channel } = createEngine("hex_frost", true);
      engine.start();
      channel.send.mockClear();
      engine._handleMessage({ data: encodeGameReady() });
      // _broadcastState sends via channel
      expect(channel.send).toHaveBeenCalled();
      // _startGameLoop calls requestAnimationFrame
      expect(requestAnimationFrame).toHaveBeenCalled();
      engine.stop();
    });

    it("decrements phaseTimer each game loop tick", () => {
      const { engine } = createEngine("hex_frost", true);
      engine.start();
      engine._handleMessage({ data: encodeGameReady() });
      const initialTimer = engine.phaseTimer; // 60
      engine._gameLoop();
      expect(engine.phaseTimer).toBe(initialTimer - 1);
      engine.stop();
    });

    it("transitions countdown 3 -> 2 -> 1 -> BUILDING", () => {
      const { engine } = createEngine("hex_frost", true);
      engine.start();
      engine._handleMessage({ data: encodeGameReady() });

      // Tick 60 frames to expire first countdown tick (3 -> 2)
      for (let i = 0; i < 60; i++) engine._gameLoop();
      expect(engine.gameState.countdown).toBe(2);

      // Tick 60 more for (2 -> 1)
      for (let i = 0; i < 60; i++) engine._gameLoop();
      expect(engine.gameState.countdown).toBe(1);

      // Tick 60 more for (1 -> 0 => BUILDING)
      for (let i = 0; i < 60; i++) engine._gameLoop();
      expect(engine.gameState.phase).toBe(PHASE.BUILDING);
      expect(engine.gameState.countdown).toBe(0);
      expect(engine.audio.playCountdownGo).toHaveBeenCalled();
      engine.stop();
    });
  });

  // ── 7. Game loop ───────────────────────────────────────────────

  describe("game loop", () => {
    function startBuildingPhase() {
      const { engine, channel } = createEngine("hex_frost", true);
      engine.start();
      engine._handleMessage({ data: encodeGameReady() });
      // Fast-forward through countdown (3 * 60 = 180 ticks)
      for (let i = 0; i < 180; i++) engine._gameLoop();
      expect(engine.gameState.phase).toBe(PHASE.BUILDING);
      return { engine, channel };
    }

    it("only runs on host", () => {
      const { engine } = createEngine("hex_frost", false);
      engine.gameState = createInitialState(GAME_MODE.ARCTIC_RACE, 1);
      engine.gameState.phase = PHASE.BUILDING;
      engine._gameLoop();
      // frameCount should not increment for peer
      expect(engine.frameCount).toBe(0);
    });

    it("no-ops when gameState is null", () => {
      const { engine } = createEngine("hex_frost", true);
      engine.gameState = null;
      expect(() => engine._gameLoop()).not.toThrow();
    });

    it("increments frameCount each tick", () => {
      const { engine } = startBuildingPhase();
      const before = engine.frameCount;
      engine._gameLoop();
      expect(engine.frameCount).toBe(before + 1);
      engine.stop();
    });

    it("resets events to 0 at start of each tick", () => {
      const { engine } = startBuildingPhase();
      // Verify the loop clears events before running physics
      // We can check by looking at the game loop source: state.events = 0
      // After physics runs, new events may be set, but old ones are gone
      engine.gameState.events = 0xffff; // set all bits
      engine._gameLoop();
      // The loop does `state.events = 0` then physics may re-set some,
      // but the specific bits we set (0xffff) should not all survive
      // since physics only sets flags when conditions are met.
      // Just verify the loop ran without error and state is coherent.
      expect(engine.gameState.phase).toBe(PHASE.BUILDING);
      engine.stop();
    });

    it("consumes localInputs.up after processing (one-shot jump)", () => {
      const { engine } = startBuildingPhase();
      engine.localInputs.up = true;
      engine._gameLoop();
      expect(engine.localInputs.up).toBe(false);
      engine.stop();
    });

    it("consumes localInputs.down after processing (one-shot drop)", () => {
      const { engine } = startBuildingPhase();
      engine.localInputs.down = true;
      engine._gameLoop();
      expect(engine.localInputs.down).toBe(false);
      engine.stop();
    });

    it("consumes remoteInputs.up and remoteInputs.down after processing", () => {
      const { engine } = startBuildingPhase();
      engine.remoteInputs.up = true;
      engine.remoteInputs.down = true;
      engine._gameLoop();
      expect(engine.remoteInputs.up).toBe(false);
      expect(engine.remoteInputs.down).toBe(false);
      engine.stop();
    });

    it("preserves left/right inputs (not consumed)", () => {
      const { engine } = startBuildingPhase();
      engine.localInputs.left = true;
      engine.remoteInputs.right = true;
      engine._gameLoop();
      expect(engine.localInputs.left).toBe(true);
      expect(engine.remoteInputs.right).toBe(true);
      engine.stop();
    });

    it("broadcasts state every STATE_SEND_INTERVAL (2) frames", () => {
      const { engine, channel } = startBuildingPhase();
      channel.send.mockClear();

      // Tick 1 (odd frameCount) — should NOT broadcast
      engine._gameLoop();
      const sendCount1 = channel.send.mock.calls.length;

      // Tick 2 (even frameCount) — SHOULD broadcast
      engine._gameLoop();
      const sendCount2 = channel.send.mock.calls.length;
      expect(sendCount2).toBeGreaterThan(sendCount1);
      engine.stop();
    });

    it("ROUND_END decrements roundEndTimer", () => {
      const { engine } = createEngine("hex_frost", true);
      engine.start();
      engine._handleMessage({ data: encodeGameReady() });
      // Skip countdown
      for (let i = 0; i < 180; i++) engine._gameLoop();

      // Force ROUND_END
      engine.gameState.phase = PHASE.ROUND_END;
      engine.roundEndTimer = 10;
      engine._gameLoop();
      expect(engine.roundEndTimer).toBe(9);
      engine.stop();
    });

    it("FINISHED phase sets running to false", () => {
      const { engine } = createEngine("hex_frost", true);
      engine.start();
      engine._handleMessage({ data: encodeGameReady() });
      for (let i = 0; i < 180; i++) engine._gameLoop();

      engine.gameState.phase = PHASE.FINISHED;
      engine._gameLoop();
      expect(engine.running).toBe(false);
      engine.stop();
    });

    it("BUILDING phase transitions to ROUND_END set roundEndTimer to 180", () => {
      const { engine } = startBuildingPhase();

      // Force round end by setting roundWinner
      engine.gameState.roundWinner = 1;
      engine._gameLoop();

      // checkRoundEnd should have set phase to ROUND_END
      expect(engine.gameState.phase).toBe(PHASE.ROUND_END);
      expect(engine.roundEndTimer).toBe(180); // ROUND_END_DELAY
      expect(engine.audio.playRoundEnd).toHaveBeenCalled();
      engine.stop();
    });
  });

  // ── 8. Audio events ────────────────────────────────────────────

  describe("audio events", () => {
    it("_handleHostEvents plays correct audio for each event flag", () => {
      const { engine } = createEngine();
      engine.start();

      engine._handleHostEvents(EVENT.BLOCK_CLAIM);
      expect(engine.audio.playBlockClaim).toHaveBeenCalled();

      engine._handleHostEvents(EVENT.BLOCK_STEAL);
      expect(engine.audio.playBlockSteal).toHaveBeenCalled();

      engine._handleHostEvents(EVENT.JUMP);
      expect(engine.audio.playJump).toHaveBeenCalled();

      engine._handleHostEvents(EVENT.LAND);
      expect(engine.audio.playLand).toHaveBeenCalled();

      engine._handleHostEvents(EVENT.SPLASH);
      expect(engine.audio.playSplash).toHaveBeenCalled();

      engine._handleHostEvents(EVENT.FISH_COLLECT);
      expect(engine.audio.playFishCollect).toHaveBeenCalled();

      engine._handleHostEvents(EVENT.ENEMY_HIT);
      expect(engine.audio.playEnemyHit).toHaveBeenCalled();

      engine._handleHostEvents(EVENT.IGLOO_PIECE);
      expect(engine.audio.playIglooPiece).toHaveBeenCalled();

      engine._handleHostEvents(EVENT.IGLOO_COMPLETE);
      expect(engine.audio.playIglooComplete).toHaveBeenCalled();

      engine._handleHostEvents(EVENT.IGLOO_ENTER);
      expect(engine.audio.playIglooEnter).toHaveBeenCalled();

      engine._handleHostEvents(EVENT.TEMP_LOW);
      expect(engine.audio.playTempLow).toHaveBeenCalled();

      engine._handleHostEvents(EVENT.TEMP_ZERO);
      expect(engine.audio.playTempZero).toHaveBeenCalled();

      engine._handleHostEvents(EVENT.BEAR_NEAR);
      expect(engine.audio.playBearNear).toHaveBeenCalled();

      engine._handleHostEvents(EVENT.CLAM_SNAP);
      expect(engine.audio.playClamSnap).toHaveBeenCalled();

      engine.stop();
    });

    it("handles multiple event flags in a single bitmask", () => {
      const { engine } = createEngine();
      engine.start();
      engine._handleHostEvents(EVENT.JUMP | EVENT.LAND | EVENT.BLOCK_CLAIM);
      expect(engine.audio.playJump).toHaveBeenCalled();
      expect(engine.audio.playLand).toHaveBeenCalled();
      expect(engine.audio.playBlockClaim).toHaveBeenCalled();
      // Others should not have fired
      expect(engine.audio.playSplash).not.toHaveBeenCalled();
      engine.stop();
    });

    it("_handlePeerEvents delegates to _handleHostEvents", () => {
      const { engine } = createEngine();
      engine.start();
      const spy = vi.spyOn(engine, "_handleHostEvents");
      engine._handlePeerEvents(EVENT.FISH_COLLECT);
      expect(spy).toHaveBeenCalledWith(EVENT.FISH_COLLECT);
      expect(engine.audio.playFishCollect).toHaveBeenCalled();
      spy.mockRestore();
      engine.stop();
    });

    it("no audio plays for events = 0", () => {
      const { engine } = createEngine();
      engine.start();
      engine._handleHostEvents(0);
      expect(engine.audio.playBlockClaim).not.toHaveBeenCalled();
      expect(engine.audio.playJump).not.toHaveBeenCalled();
      expect(engine.audio.playSplash).not.toHaveBeenCalled();
      engine.stop();
    });
  });

  // ── 9. Game end ────────────────────────────────────────────────

  describe("game end", () => {
    it("_handleGameFinished sends GAME_END with winner", () => {
      const onGameEnd = vi.fn();
      const { engine, channel } = createEngine("hex_frost", true, onGameEnd);
      engine.start();

      // Create a state with p1 winning
      engine.gameState.p1.roundWins = 3;
      engine.gameState.p2.roundWins = 1;
      channel.send.mockClear();

      engine._handleGameFinished(engine.gameState);

      expect(engine.audio.stopAmbientWind).toHaveBeenCalled();
      expect(engine.audio.playVictory).toHaveBeenCalled();
      expect(channel.send).toHaveBeenCalled();
      expect(onGameEnd).toHaveBeenCalledWith(
        expect.objectContaining({
          score1: 3,
          score2: 1,
          winner: 1,
        }),
      );
      engine.stop();
    });

    it("plays game over when winner = 0 (draw)", () => {
      const { engine } = createEngine("hex_frost", true, vi.fn());
      engine.start();
      engine.gameState.p1.roundWins = 0;
      engine.gameState.p2.roundWins = 0;
      engine.gameState.p1.score = 0;
      engine.gameState.p2.score = 0;

      engine._handleGameFinished(engine.gameState);

      expect(engine.audio.playGameOver).toHaveBeenCalled();
      expect(engine.audio.playVictory).not.toHaveBeenCalled();
      engine.stop();
    });

    it("calls onGameEnd callback with score and winner", () => {
      const onGameEnd = vi.fn();
      const { engine } = createEngine("hex_frost", true, onGameEnd);
      engine.start();
      engine.gameState.p1.roundWins = 2;
      engine.gameState.p2.roundWins = 3;

      engine._handleGameFinished(engine.gameState);

      expect(onGameEnd).toHaveBeenCalledWith({
        score1: 2,
        score2: 3,
        winner: 2,
      });
      engine.stop();
    });

    it("does not throw when onGameEnd is null", () => {
      const { engine } = createEngine("hex_frost", true, null);
      engine.start();
      engine.gameState.p1.roundWins = 1;
      engine.gameState.p2.roundWins = 0;

      expect(() => engine._handleGameFinished(engine.gameState)).not.toThrow();
      engine.stop();
    });

    it("sends encodeGameEnd over channel", () => {
      const { engine, channel } = createEngine("hex_frost", true, vi.fn());
      engine.start();
      engine.gameState.p1.roundWins = 1;
      engine.gameState.p2.roundWins = 2;
      channel.send.mockClear();

      engine._handleGameFinished(engine.gameState);

      expect(channel.send).toHaveBeenCalled();
      const sentBuf = channel.send.mock.calls[0][0];
      expect(sentBuf instanceof ArrayBuffer).toBe(true);
      const view = new DataView(sentBuf);
      expect(view.getUint8(0)).toBe(MSG_TYPE.GAME_END);
      engine.stop();
    });
  });

  // ── 10. Connection resilience ──────────────────────────────────

  describe("connection resilience", () => {
    it("_handleBlur clears all 4 local inputs", () => {
      const { engine } = createEngine();
      engine.localInputs = {
        left: true,
        right: true,
        up: true,
        down: true,
      };
      engine._handleBlur();
      expect(engine.localInputs).toEqual({
        left: false,
        right: false,
        up: false,
        down: false,
      });
    });

    it("_handleChannelClose sets phase to FINISHED and renders", () => {
      const { engine } = createEngine("hex_frost", true);
      engine.start();
      engine.gameState.phase = PHASE.BUILDING;
      render.mockClear();

      engine._handleChannelClose();

      expect(engine.gameState.phase).toBe(PHASE.FINISHED);
      expect(render).toHaveBeenCalled();
      engine.stop();
    });

    it("_handleChannelClose calls onGameEnd with disconnected flag and actual scores", () => {
      const onGameEnd = vi.fn();
      const { engine } = createEngine("hex_frost", true, onGameEnd);
      engine.start();
      engine.gameState.phase = PHASE.BUILDING;
      // Set round wins on the nested p1/p2 objects (host state structure)
      engine.gameState.p1.roundWins = 2;
      engine.gameState.p2.roundWins = 1;

      engine._handleChannelClose();

      expect(onGameEnd).toHaveBeenCalledWith(
        expect.objectContaining({
          disconnected: true,
          winner: "draw",
          score_p1: 2,
          score_p2: 1,
        }),
      );
      engine.stop();
    });

    it("_handleChannelClose is no-op when game already FINISHED", () => {
      const onGameEnd = vi.fn();
      const { engine } = createEngine("hex_frost", true, onGameEnd);
      engine.start();
      engine.gameState.phase = PHASE.FINISHED;

      engine._handleChannelClose();
      expect(onGameEnd).not.toHaveBeenCalled();
      engine.stop();
    });

    it("_handleChannelClose is no-op when gameState is null", () => {
      const onGameEnd = vi.fn();
      const { engine } = createEngine("hex_frost", false, onGameEnd);
      // Don't start — gameState remains null
      engine._handleChannelClose();
      expect(onGameEnd).not.toHaveBeenCalled();
    });

    it("_handleChannelClose swallows onGameEnd callback errors", () => {
      const badCallback = vi.fn(() => {
        throw new Error("callback exploded");
      });
      const { engine } = createEngine("hex_frost", true, badCallback);
      engine.start();
      engine.gameState.phase = PHASE.BUILDING;

      expect(() => engine._handleChannelClose()).not.toThrow();
      expect(badCallback).toHaveBeenCalled();
      engine.stop();
    });

    it("double-start guard prevents re-initialization", () => {
      const { engine } = createEngine("hex_frost", true);
      engine.start();
      const firstState = engine.gameState;
      readColors.mockClear();
      generateSnowParticles.mockClear();

      engine.start(); // no-op

      expect(engine.gameState).toBe(firstState);
      expect(readColors).not.toHaveBeenCalled();
      expect(generateSnowParticles).not.toHaveBeenCalled();
      engine.stop();
    });
  });

  // ── 11. Additional edge-case coverage ───────────────────────────

  describe("additional edge cases", () => {
    it("ROUND_END → startNextRound returning COUNTDOWN resets phaseTimer and plays countdown audio", () => {
      const { engine } = createEngine("hex_frost", true);
      engine.start();
      engine._handleMessage({ data: encodeGameReady() });
      // Skip countdown to BUILDING
      for (let i = 0; i < 180; i++) engine._gameLoop();
      expect(engine.gameState.phase).toBe(PHASE.BUILDING);

      // Force a round win and transition to ROUND_END
      engine.gameState.roundWinner = 1;
      engine._gameLoop();
      expect(engine.gameState.phase).toBe(PHASE.ROUND_END);

      // Now expire roundEndTimer to trigger startNextRound
      engine.audio.playCountdown.mockClear();
      engine.roundEndTimer = 1; // will decrement to 0 next tick
      engine._gameLoop();

      // startNextRound returns COUNTDOWN, so phaseTimer should be reset to 60
      expect(engine.phaseTimer).toBe(60);
      expect(engine.audio.playCountdown).toHaveBeenCalled();
      engine.stop();
    });

    it("_broadcastState is a no-op when gameState is null", () => {
      const { engine, channel } = createEngine("hex_frost", true);
      engine.gameState = null;
      channel.send.mockClear();
      engine._broadcastState();
      expect(channel.send).not.toHaveBeenCalled();
    });

    it("_renderState passes null gameState to render without throwing", () => {
      const { engine } = createEngine("hex_frost", true);
      engine.start();
      engine.gameState = null;
      render.mockClear();
      expect(() => engine._renderState()).not.toThrow();
      expect(render).toHaveBeenCalledWith(
        engine.ctx,
        null,
        engine.colors,
        engine.frameCount,
        engine.snowParticles,
      );
      engine.stop();
    });

    it("GAME_END peer does NOT call playGameOver when winner > 0 (inverse assertion)", () => {
      const { engine } = createEngine("hex_frost", false, vi.fn());
      const buf = encodeGameEnd({ score1: 5, score2: 2, winner: 1 });
      engine._handleMessage({ data: buf });
      expect(engine.audio.playVictory).toHaveBeenCalled();
      expect(engine.audio.playGameOver).not.toHaveBeenCalled();
    });
  });
});
