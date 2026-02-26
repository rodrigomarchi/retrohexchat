import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import {
  PHASE,
  MSG_TYPE,
  INPUT_KEY,
  GAME_MODE,
  encodeGameState,
  encodePlayerInput,
  encodeGameEnd,
  encodeGameReady,
  encodeShipFlags,
} from "../../../../js/lib/games/star_duel/protocol.js";
import {
  createInitialState,
  CANVAS_W,
  CANVAS_H,
  WIN_SCORE,
  STAR_X,
  STAR_Y,
  generateAsteroids,
} from "../../../../js/lib/games/star_duel/physics.js";

// Must mock audio before importing StarDuelEngine
vi.mock("../../../../js/lib/games/star_duel/audio.js", () => ({
  StarDuelAudio: function () {
    return {
      playThrust: vi.fn(),
      stopThrust: vi.fn(),
      playFire: vi.fn(),
      playHit: vi.fn(),
      playDeath: vi.fn(),
      playWarp: vi.fn(),
      playStarProximity: vi.fn(),
      stopStarProximity: vi.fn(),
      playCountdown: vi.fn(),
      playWin: vi.fn(),
      playSpawn: vi.fn(),
    };
  },
}));

// Must mock renderer
vi.mock("../../../../js/lib/games/star_duel/renderer.js", () => ({
  getColors: vi.fn(() => ({
    bg: "#0a0a1a",
    p1: "#39ff14",
    p2: "#00e5ff",
    muted: "#1a3a4a",
    glow: "rgba(57,255,20,0.2)",
    warning: "#ffaa00",
    star: "#ff8c00",
    asteroid: "#8b4513",
    missile: "#ffffff",
    explosion: "#ff4444",
  })),
  render: vi.fn(),
}));

const { StarDuelEngine } = await import("../../../../js/lib/games/star_duel/engine.js");
const { render, getColors } = await import("../../../../js/lib/games/star_duel/renderer.js");

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
    arc: vi.fn(),
    closePath: vi.fn(),
    fill: vi.fn(),
    translate: vi.fn(),
    rotate: vi.fn(),
    createRadialGradient: vi.fn(() => ({
      addColorStop: vi.fn(),
    })),
  };
  canvas.getContext = vi.fn(() => mockCtx);

  return canvas;
}

/**
 * Helper to build a valid encoded game state for peer-side tests.
 * @param {object} overrides - fields to override on the default state
 * @returns {ArrayBuffer}
 */
function buildEncodedState(overrides = {}) {
  const base = createInitialState(overrides.mode ?? 0);
  const ship1Flags = overrides.ship1Flags || {
    alive: true,
    thrustActive: false,
    exploding: false,
    warping: false,
    invulnerable: true,
  };
  const ship2Flags = overrides.ship2Flags || {
    alive: true,
    thrustActive: false,
    exploding: false,
    warping: false,
    invulnerable: true,
  };
  const state = {
    ...base,
    ...overrides,
    ship1: {
      ...base.ship1,
      ...(overrides.ship1 || {}),
      flags: encodeShipFlags(overrides.ship1Flags || ship1Flags),
    },
    ship2: {
      ...base.ship2,
      ...(overrides.ship2 || {}),
      flags: encodeShipFlags(overrides.ship2Flags || ship2Flags),
    },
  };
  return encodeGameState(state);
}

describe("StarDuelEngine", () => {
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
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      expect(engine.gameState).toBeDefined();
      expect(engine.gameState.phase).toBe(PHASE.WAITING);
    });

    it("sets mode from gameId (star_duel=0)", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      expect(engine.mode).toBe(0);
    });

    it("sets mode from gameId (gravity_well=1)", () => {
      engine = new StarDuelEngine(canvas, channel, "gravity_well", true, null);
      expect(engine.mode).toBe(1);
    });

    it("sets mode from gameId (debris_field=2)", () => {
      engine = new StarDuelEngine(canvas, channel, "debris_field", true, null);
      expect(engine.mode).toBe(2);
    });

    it("stores onGameEnd callback", () => {
      const cb = vi.fn();
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, cb);
      expect(engine.onGameEnd).toBe(cb);
    });

    it("initializes remote inputs", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      expect(engine.remoteInputs).toEqual({
        rotateLeft: false,
        rotateRight: false,
        thrust: false,
        fire: false,
        warp: false,
      });
    });

    it("initializes local inputs", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      expect(engine.localInputs).toEqual({
        rotateLeft: false,
        rotateRight: false,
        thrust: false,
        fire: false,
        warp: false,
      });
    });

    it("initializes lastScorer to 0", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      expect(engine.gameState.lastScorer).toBe(0);
    });
  });

  describe("start", () => {
    it("sets running to true", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      engine.start();
      expect(engine.running).toBe(true);
    });

    it("host does not send GAME_READY", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
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
      engine = new StarDuelEngine(canvas, channel, "star_duel", false, null);
      engine.start();
      // Find the GAME_READY message among sent messages
      const readyCall = channel.send.mock.calls.find((call) => {
        const buf = call[0];
        if (buf instanceof ArrayBuffer) {
          const view = new Uint8Array(buf);
          return view[0] === MSG_TYPE.GAME_READY;
        }
        return false;
      });
      expect(readyCall).toBeDefined();
    });

    it("reads colors from canvas", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      engine.start();
      expect(getColors).toHaveBeenCalledWith(canvas);
      expect(engine.colors).toBeDefined();
    });

    it("renders initial state", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      engine.start();
      expect(render).toHaveBeenCalled();
    });
  });

  describe("stop", () => {
    it("sets running to false", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      engine.start();
      engine.stop();
      expect(engine.running).toBe(false);
    });

    it("clears phase timer", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      engine.start();
      engine.phaseTimer = setTimeout(() => {}, 10000);
      engine.stop();
      expect(engine.phaseTimer).toBeNull();
    });

    it("cancels animation frame", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      engine.start();
      engine.animFrame = 99;
      engine.stop();
      expect(engine.animFrame).toBeNull();
      expect(globalThis.cancelAnimationFrame).toHaveBeenCalledWith(99);
    });

    it("calls super.stop() — removes event listeners and sets running false", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      engine.start();
      engine.stop();
      // super.stop() sets running=false and nulls animFrame
      expect(engine.running).toBe(false);
      expect(engine.animFrame).toBeNull();
      // super.stop() removes keydown/keyup listeners
      expect(channel.removeEventListener).toHaveBeenCalledWith("message", expect.any(Function));
    });

    it("stops thrust and star proximity audio", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      engine.start();
      engine.stop();
      expect(engine.audio.stopThrust).toHaveBeenCalled();
      expect(engine.audio.stopStarProximity).toHaveBeenCalled();
    });
  });

  describe("_handleMessage (host)", () => {
    it("processes GAME_READY from peer and starts countdown", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      engine.start();
      expect(engine.peerReady).toBe(false);

      const buf = encodeGameReady();
      engine._handleMessage({ data: buf });

      expect(engine.peerReady).toBe(true);
      expect(engine.gameState.phase).toBe(PHASE.COUNTDOWN);
    });

    it("ignores duplicate GAME_READY", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      engine.start();

      const buf = encodeGameReady();
      engine._handleMessage({ data: buf });
      const countdownCalls1 = engine.audio.playCountdown.mock.calls.length;

      engine._handleMessage({ data: buf });
      const countdownCalls2 = engine.audio.playCountdown.mock.calls.length;

      expect(countdownCalls2).toBe(countdownCalls1);
    });

    it("processes PLAYER_INPUT ROTATE_LEFT", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      engine.start();

      const buf = encodePlayerInput(INPUT_KEY.ROTATE_LEFT, true);
      engine._handleMessage({ data: buf });
      expect(engine.remoteInputs.rotateLeft).toBe(true);
    });

    it("processes PLAYER_INPUT ROTATE_RIGHT", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      engine.start();

      const buf = encodePlayerInput(INPUT_KEY.ROTATE_RIGHT, true);
      engine._handleMessage({ data: buf });
      expect(engine.remoteInputs.rotateRight).toBe(true);
    });

    it("processes PLAYER_INPUT THRUST", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      engine.start();

      const buf = encodePlayerInput(INPUT_KEY.THRUST, true);
      engine._handleMessage({ data: buf });
      expect(engine.remoteInputs.thrust).toBe(true);
    });

    it("processes PLAYER_INPUT FIRE", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      engine.start();

      const buf = encodePlayerInput(INPUT_KEY.FIRE, true);
      engine._handleMessage({ data: buf });
      expect(engine.remoteInputs.fire).toBe(true);
    });

    it("processes PLAYER_INPUT WARP", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      engine.start();

      const buf = encodePlayerInput(INPUT_KEY.WARP, true);
      engine._handleMessage({ data: buf });
      expect(engine.remoteInputs.warp).toBe(true);
    });

    it("ignores GAME_STATE when host", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      engine.start();
      const originalScore = engine.gameState.score1;

      const fakeState = {
        ...createInitialState(0),
        score1: 99,
        ship1: {
          ...createInitialState(0).ship1,
          flags: encodeShipFlags({
            alive: true,
            thrustActive: false,
            exploding: false,
            warping: false,
            invulnerable: true,
          }),
        },
        ship2: {
          ...createInitialState(0).ship2,
          flags: encodeShipFlags({
            alive: true,
            thrustActive: false,
            exploding: false,
            warping: false,
            invulnerable: true,
          }),
        },
      };
      const buf = encodeGameState(fakeState);
      engine._handleMessage({ data: buf });

      expect(engine.gameState.score1).toBe(originalScore);
    });
  });

  describe("_handleMessage (peer)", () => {
    it("applies GAME_STATE from host", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", false, null);
      engine.start();

      const buf = buildEncodedState({
        score1: 5,
        score2: 3,
        phase: PHASE.PLAYING,
        ship1: { x: 100, y: 200 },
        ship2: { x: 300, y: 400 },
      });
      engine._handleMessage({ data: buf });

      expect(engine.gameState.score1).toBe(5);
      expect(engine.gameState.score2).toBe(3);
      expect(engine.gameState.phase).toBe(PHASE.PLAYING);
    });

    it("processes GAME_END", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", false, null);
      engine.start();

      const buf = encodeGameEnd(7, 3, 1);
      engine._handleMessage({ data: buf });

      expect(engine.gameState.phase).toBe(PHASE.FINISHED);
      expect(engine.gameState.winner).toBe(1);
      expect(engine.gameState.score1).toBe(7);
      expect(engine.gameState.score2).toBe(3);
    });

    it("GAME_END stops thrust and star proximity audio", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", false, null);
      engine.start();

      const buf = encodeGameEnd(7, 3, 1);
      engine._handleMessage({ data: buf });

      expect(engine.audio.playWin).toHaveBeenCalled();
      expect(engine.audio.stopThrust).toHaveBeenCalled();
      expect(engine.audio.stopStarProximity).toHaveBeenCalled();
    });

    it("GAME_END clears _peerThrustAudioPlaying flag", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", false, null);
      engine.start();
      engine._peerThrustAudioPlaying = true;

      const buf = encodeGameEnd(7, 3, 1);
      engine._handleMessage({ data: buf });

      expect(engine._peerThrustAudioPlaying).toBe(false);
    });
  });

  describe("_handleMessage (non-ArrayBuffer)", () => {
    it("ignores non-ArrayBuffer data", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      engine.start();
      expect(() => {
        engine._handleMessage({ data: "not binary" });
      }).not.toThrow();
    });
  });

  describe("key handling", () => {
    it("maps ArrowLeft to ROTATE_LEFT", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      engine.start();
      engine._handleKeyDown({ key: "ArrowLeft", preventDefault: vi.fn() });
      expect(engine.localInputs.rotateLeft).toBe(true);
    });

    it("maps ArrowRight to ROTATE_RIGHT", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      engine.start();
      engine._handleKeyDown({ key: "ArrowRight", preventDefault: vi.fn() });
      expect(engine.localInputs.rotateRight).toBe(true);
    });

    it("maps ArrowUp to THRUST", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      engine.start();
      engine._handleKeyDown({ key: "ArrowUp", preventDefault: vi.fn() });
      expect(engine.localInputs.thrust).toBe(true);
    });

    it("maps Space to FIRE", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      engine.start();
      engine._handleKeyDown({ key: " ", preventDefault: vi.fn() });
      expect(engine.localInputs.fire).toBe(true);
    });

    it("maps ArrowDown to WARP", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      engine.start();
      engine._handleKeyDown({ key: "ArrowDown", preventDefault: vi.fn() });
      expect(engine.localInputs.warp).toBe(true);
    });

    it("maps a to ROTATE_LEFT", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      engine.start();
      engine._handleKeyDown({ key: "a", preventDefault: vi.fn() });
      expect(engine.localInputs.rotateLeft).toBe(true);
    });

    it("maps d to ROTATE_RIGHT", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      engine.start();
      engine._handleKeyDown({ key: "d", preventDefault: vi.fn() });
      expect(engine.localInputs.rotateRight).toBe(true);
    });

    it("maps w to THRUST", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      engine.start();
      engine._handleKeyDown({ key: "w", preventDefault: vi.fn() });
      expect(engine.localInputs.thrust).toBe(true);
    });

    it("maps s to WARP", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      engine.start();
      engine._handleKeyDown({ key: "s", preventDefault: vi.fn() });
      expect(engine.localInputs.warp).toBe(true);
    });

    it("key release clears local input", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      engine.start();
      engine._handleKeyDown({ key: "ArrowLeft", preventDefault: vi.fn() });
      engine._handleKeyUp({ key: "ArrowLeft" });
      expect(engine.localInputs.rotateLeft).toBe(false);
    });

    it("ignores unmapped keys", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      engine.start();
      const e = { key: "x", preventDefault: vi.fn() };
      engine._handleKeyDown(e);
      expect(e.preventDefault).not.toHaveBeenCalled();
    });

    it("peer sends binary input on keydown", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", false, null);
      engine.start();
      channel.send.mockClear();

      engine._handleKeyDown({ key: "ArrowLeft", preventDefault: vi.fn() });

      const lastCall = channel.send.mock.calls[channel.send.mock.calls.length - 1];
      const buf = lastCall[0];
      expect(buf).toBeInstanceOf(ArrayBuffer);
      const view = new Uint8Array(buf);
      expect(view[0]).toBe(MSG_TYPE.PLAYER_INPUT);
      expect(view[1]).toBe(INPUT_KEY.ROTATE_LEFT);
      expect(view[2]).toBe(1); // pressed
    });

    it("peer sends binary input on keyup", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", false, null);
      engine.start();

      engine._handleKeyDown({ key: "ArrowUp", preventDefault: vi.fn() });
      channel.send.mockClear();
      engine._handleKeyUp({ key: "ArrowUp" });

      const lastCall = channel.send.mock.calls[channel.send.mock.calls.length - 1];
      const buf = lastCall[0];
      const view = new Uint8Array(buf);
      expect(view[0]).toBe(MSG_TYPE.PLAYER_INPUT);
      expect(view[1]).toBe(INPUT_KEY.THRUST);
      expect(view[2]).toBe(0); // released
    });

    it("host does not send input over channel", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      engine.start();
      channel.send.mockClear();

      engine._handleKeyDown({ key: "ArrowLeft", preventDefault: vi.fn() });
      expect(channel.send).not.toHaveBeenCalled();
    });
  });

  describe("_handleBlur", () => {
    it("clears all local inputs", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      engine.start();
      engine.localInputs = {
        rotateLeft: true,
        rotateRight: true,
        thrust: true,
        fire: true,
        warp: true,
      };

      engine._handleBlur();

      expect(engine.localInputs.rotateLeft).toBe(false);
      expect(engine.localInputs.rotateRight).toBe(false);
      expect(engine.localInputs.thrust).toBe(false);
      expect(engine.localInputs.fire).toBe(false);
      expect(engine.localInputs.warp).toBe(false);
    });

    it("peer sends release for all 5 keys on blur", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", false, null);
      engine.start();
      channel.send.mockClear();

      engine._handleBlur();

      // Should have sent 5 release messages (ROTATE_LEFT + ROTATE_RIGHT + THRUST + FIRE + WARP)
      expect(channel.send).toHaveBeenCalledTimes(5);
    });

    it("stops thrust audio", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      engine.start();

      engine._handleBlur();

      expect(engine.audio.stopThrust).toHaveBeenCalled();
    });
  });

  describe("_broadcastState", () => {
    it("sends encoded state when channel is open", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      engine.start();
      channel.send.mockClear();

      engine._broadcastState();

      expect(channel.send).toHaveBeenCalledTimes(1);
      const buf = channel.send.mock.calls[0][0];
      expect(buf).toBeInstanceOf(ArrayBuffer);
    });

    it("does not send when channel is closed", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      engine.start();
      channel.readyState = "closed";
      channel.send.mockClear();

      engine._broadcastState();

      expect(channel.send).not.toHaveBeenCalled();
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
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      engine.start();

      engine._handleMessage({ data: encodeGameReady() });

      expect(engine.gameState.phase).toBe(PHASE.COUNTDOWN);
      expect(engine.gameState.countdown).toBe(3);
      expect(engine.audio.playCountdown).toHaveBeenCalled();
    });

    it("_startCountdown calls _renderState immediately", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      engine.start();
      render.mockClear();

      engine._handleMessage({ data: encodeGameReady() });

      // _startCountdown calls _broadcastState + _renderState at the start
      expect(render).toHaveBeenCalled();
      expect(engine.gameState.phase).toBe(PHASE.COUNTDOWN);
    });

    it("counts down from 3 to 1", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      engine.start();
      engine._handleMessage({ data: encodeGameReady() });

      vi.advanceTimersByTime(1000);
      expect(engine.gameState.countdown).toBe(2);

      vi.advanceTimersByTime(1000);
      expect(engine.gameState.countdown).toBe(1);
    });

    it("transitions to SPAWNING after countdown", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      engine.start();
      engine._handleMessage({ data: encodeGameReady() });

      vi.advanceTimersByTime(3000);

      expect(engine.gameState.phase).toBe(PHASE.SPAWNING);
    });

    it("phase timer is nulled after countdown completes", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      engine.start();
      engine._handleMessage({ data: encodeGameReady() });

      // After all 3 ticks, the countdown is done and _startSpawning is called
      vi.advanceTimersByTime(2000);
      // count goes to 0, phaseTimer is set to null before calling _startSpawning
      // But _startSpawning sets a new phaseTimer for SPAWN_DELAY
      // At 2000ms: count=1 (tick 2), then at 3000ms: count=0, phaseTimer=null, then _startSpawning sets new phaseTimer
      vi.advanceTimersByTime(1000);
      expect(engine.gameState.phase).toBe(PHASE.SPAWNING);
      // _startSpawning sets a new phaseTimer; after SPAWN_DELAY it's nulled
      expect(engine.phaseTimer).not.toBeNull();

      // After SPAWN_DELAY (1500ms), phaseTimer is nulled and game starts
      vi.advanceTimersByTime(1500);
      expect(engine.phaseTimer).toBeNull();
      expect(engine.gameState.phase).toBe(PHASE.PLAYING);
    });
  });

  describe("game loop — death handling", () => {
    beforeEach(() => {
      vi.useFakeTimers();
    });

    afterEach(() => {
      vi.useRealTimers();
    });

    /**
     * Helper: set up an engine in PLAYING phase with both ships alive.
     */
    function setupPlayingEngine(gameId = "star_duel") {
      engine = new StarDuelEngine(canvas, channel, gameId, true, null);
      engine.start();
      engine._handleMessage({ data: encodeGameReady() });

      // Fast-forward through countdown (3s) + spawning (1.5s)
      vi.advanceTimersByTime(4500);
      expect(engine.gameState.phase).toBe(PHASE.PLAYING);
      return engine;
    }

    it("P1 dies from missile — score2 increments, lastScorer=2", () => {
      setupPlayingEngine();

      // Force ship1 to be hit: set it non-alive and exploding on next frame
      // We achieve this by manipulating the state so collision detection will trigger
      // Simpler: directly manipulate and call _gameLoop
      const ship1 = engine.gameState.ship1;
      const ship2 = engine.gameState.ship2;

      // Add a missile from P2 at ship1's exact location
      engine.gameState.missiles = [
        {
          x: ship1.x,
          y: ship1.y,
          vx: 0,
          vy: 0,
          owner: 2,
          age: 0,
        },
      ];
      // Make ships not invulnerable so collision can happen
      engine.gameState.ship1 = { ...ship1, invulnerable: false, invulnTimer: 0 };
      engine.gameState.ship2 = { ...ship2, invulnerable: false, invulnTimer: 0 };

      const prevScore2 = engine.gameState.score2;
      engine._gameLoop(performance.now());

      expect(engine.gameState.score2).toBe(prevScore2 + 1);
      expect(engine.gameState.lastScorer).toBe(2);
      expect(engine.audio.playHit).toHaveBeenCalled();
      expect(engine.audio.playDeath).toHaveBeenCalled();
    });

    it("P2 dies from missile — score1 increments, lastScorer=1", () => {
      setupPlayingEngine();

      const ship1 = engine.gameState.ship1;
      const ship2 = engine.gameState.ship2;

      engine.gameState.missiles = [
        {
          x: ship2.x,
          y: ship2.y,
          vx: 0,
          vy: 0,
          owner: 1,
          age: 0,
        },
      ];
      engine.gameState.ship1 = { ...ship1, invulnerable: false, invulnTimer: 0 };
      engine.gameState.ship2 = { ...ship2, invulnerable: false, invulnTimer: 0 };

      const prevScore1 = engine.gameState.score1;
      engine._gameLoop(performance.now());

      expect(engine.gameState.score1).toBe(prevScore1 + 1);
      expect(engine.gameState.lastScorer).toBe(1);
    });

    it("simultaneous death — no score change, lastScorer=0", () => {
      setupPlayingEngine();

      const ship1 = engine.gameState.ship1;
      const ship2 = engine.gameState.ship2;

      // Position ships right on top of each other for ship-ship collision
      engine.gameState.ship1 = { ...ship1, x: 200, y: 200, invulnerable: false, invulnTimer: 0 };
      engine.gameState.ship2 = { ...ship2, x: 200, y: 200, invulnerable: false, invulnTimer: 0 };
      engine.gameState.missiles = [];

      const prevScore1 = engine.gameState.score1;
      const prevScore2 = engine.gameState.score2;

      engine._gameLoop(performance.now());

      // Simultaneous death: no score change, lastScorer = 0
      expect(engine.gameState.score1).toBe(prevScore1);
      expect(engine.gameState.score2).toBe(prevScore2);
      expect(engine.gameState.lastScorer).toBe(0);
      expect(engine.audio.playDeath).toHaveBeenCalled();
    });
  });

  describe("_handleRoundOver", () => {
    beforeEach(() => {
      vi.useFakeTimers();
    });

    afterEach(() => {
      vi.useRealTimers();
    });

    it("stops thrust audio on ROUND_OVER", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      engine.start();
      engine.gameState.phase = PHASE.PLAYING;

      engine._handleRoundOver();

      expect(engine.audio.stopThrust).toHaveBeenCalled();
      expect(engine._thrustAudioPlaying).toBe(false);
    });

    it("stops star proximity on ROUND_OVER in gravity well mode", () => {
      engine = new StarDuelEngine(canvas, channel, "gravity_well", true, null);
      engine.start();
      engine.gameState.phase = PHASE.PLAYING;
      engine.gameState.mode = GAME_MODE.GRAVITY_WELL;

      engine._handleRoundOver();

      expect(engine.audio.stopStarProximity).toHaveBeenCalled();
    });

    it("transitions to SPAWNING after ROUND_OVER_DELAY", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      engine.start();
      engine.gameState.phase = PHASE.PLAYING;

      engine._handleRoundOver();

      expect(engine.gameState.phase).toBe(PHASE.ROUND_OVER);

      vi.advanceTimersByTime(2000); // ROUND_OVER_DELAY
      expect(engine.gameState.phase).toBe(PHASE.SPAWNING);
    });
  });

  describe("_handleGameFinished (host)", () => {
    it("sends GAME_END to peer", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      engine.start();
      engine.gameState.score1 = WIN_SCORE;
      engine.gameState.score2 = 3;
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
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, onEnd);
      engine.start();
      engine.gameState.score1 = WIN_SCORE;
      engine.gameState.score2 = 3;

      engine._handleGameFinished();

      expect(onEnd).toHaveBeenCalledWith({
        score: { p1: WIN_SCORE, p2: 3 },
        winner: 1,
      });
    });

    it("plays win audio and stops thrust/proximity", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      engine.start();
      engine.gameState.score1 = WIN_SCORE;
      engine.gameState.score2 = 3;

      engine._handleGameFinished();

      expect(engine.audio.playWin).toHaveBeenCalled();
      expect(engine.audio.stopThrust).toHaveBeenCalled();
    });

    it("stops star proximity in gravity well mode", () => {
      engine = new StarDuelEngine(canvas, channel, "gravity_well", true, null);
      engine.start();
      engine.gameState.score1 = WIN_SCORE;
      engine.gameState.score2 = 3;
      engine.gameState.mode = GAME_MODE.GRAVITY_WELL;

      engine._handleGameFinished();

      expect(engine.audio.stopStarProximity).toHaveBeenCalled();
    });

    it("sets phase to FINISHED with correct winner", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      engine.start();
      engine.gameState.score1 = 3;
      engine.gameState.score2 = WIN_SCORE;

      engine._handleGameFinished();

      expect(engine.gameState.phase).toBe(PHASE.FINISHED);
      expect(engine.gameState.winner).toBe(2);
    });
  });

  describe("peer state application (_applyPeerState)", () => {
    it("generates particles when ship1 transitions to exploding", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", false, null);
      engine.start();

      // Ship1 was not exploding before
      engine.gameState.ship1 = { ...engine.gameState.ship1, exploding: false };
      engine.gameState.particles = [];

      // Send state where ship1 is now exploding
      const buf = buildEncodedState({
        ship1: { x: 100, y: 200 },
        ship1Flags: {
          alive: false,
          thrustActive: false,
          exploding: true,
          warping: false,
          invulnerable: false,
        },
      });
      engine._handleMessage({ data: buf });

      expect(engine.gameState.particles.length).toBeGreaterThan(0);
    });

    it("generates particles when ship2 transitions to exploding", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", false, null);
      engine.start();

      engine.gameState.ship2 = { ...engine.gameState.ship2, exploding: false };
      engine.gameState.particles = [];

      const buf = buildEncodedState({
        ship2: { x: 300, y: 400 },
        ship2Flags: {
          alive: false,
          thrustActive: false,
          exploding: true,
          warping: false,
          invulnerable: false,
        },
      });
      engine._handleMessage({ data: buf });

      expect(engine.gameState.particles.length).toBeGreaterThan(0);
    });

    it("infers lastScorer=1 when score1 increases", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", false, null);
      engine.start();
      engine.gameState.score1 = 0;
      engine.gameState.score2 = 0;

      const buf = buildEncodedState({ score1: 1, score2: 0 });
      engine._handleMessage({ data: buf });

      expect(engine.gameState.lastScorer).toBe(1);
    });

    it("infers lastScorer=2 when score2 increases", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", false, null);
      engine.start();
      engine.gameState.score1 = 0;
      engine.gameState.score2 = 0;

      const buf = buildEncodedState({ score1: 0, score2: 1 });
      engine._handleMessage({ data: buf });

      expect(engine.gameState.lastScorer).toBe(2);
    });

    it("infers lastScorer=0 (draw) when both scores increase", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", false, null);
      engine.start();
      engine.gameState.score1 = 0;
      engine.gameState.score2 = 0;

      const buf = buildEncodedState({ score1: 1, score2: 1 });
      engine._handleMessage({ data: buf });

      expect(engine.gameState.lastScorer).toBe(0);
    });

    it("uses decoded.asteroidSeed to generate asteroids in debris field", () => {
      engine = new StarDuelEngine(canvas, channel, "debris_field", false, null);
      engine.start();
      // Ensure asteroids are empty initially
      engine.gameState.asteroids = [];

      const buf = buildEncodedState({
        mode: GAME_MODE.DEBRIS_FIELD,
        asteroidSeed: 12345,
      });
      engine._handleMessage({ data: buf });

      // Peer should have generated asteroids from the seed
      expect(engine.gameState.asteroids.length).toBeGreaterThan(0);
      // Verify they match what generateAsteroids produces
      const expected = generateAsteroids(12345);
      expect(engine.gameState.asteroids.length).toBe(expected.length);
    });

    it("toggles peer thrust audio when ship2 starts thrusting", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", false, null);
      engine.start();
      engine._peerThrustAudioPlaying = false;

      const buf = buildEncodedState({
        ship2Flags: {
          alive: true,
          thrustActive: true,
          exploding: false,
          warping: false,
          invulnerable: false,
        },
      });
      engine._handleMessage({ data: buf });

      expect(engine.audio.playThrust).toHaveBeenCalled();
      expect(engine._peerThrustAudioPlaying).toBe(true);
    });

    it("stops peer thrust audio when ship2 stops thrusting", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", false, null);
      engine.start();
      engine._peerThrustAudioPlaying = true;

      const buf = buildEncodedState({
        ship2Flags: {
          alive: true,
          thrustActive: false,
          exploding: false,
          warping: false,
          invulnerable: false,
        },
      });
      engine._handleMessage({ data: buf });

      expect(engine.audio.stopThrust).toHaveBeenCalled();
      expect(engine._peerThrustAudioPlaying).toBe(false);
    });
  });

  describe("_playPhaseAudio (peer side)", () => {
    it("plays countdown audio on COUNTDOWN transition", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", false, null);
      engine.start();
      engine.gameState.phase = PHASE.WAITING;

      const buf = buildEncodedState({ phase: PHASE.COUNTDOWN, countdown: 3 });
      engine._handleMessage({ data: buf });

      expect(engine.audio.playCountdown).toHaveBeenCalled();
    });

    it("plays spawn audio on SPAWNING transition", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", false, null);
      engine.start();
      engine.gameState.phase = PHASE.COUNTDOWN;

      const buf = buildEncodedState({ phase: PHASE.SPAWNING });
      engine._handleMessage({ data: buf });

      expect(engine.audio.playSpawn).toHaveBeenCalled();
    });

    it("plays win audio on FINISHED transition", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", false, null);
      engine.start();
      engine.gameState.phase = PHASE.PLAYING;

      const buf = buildEncodedState({ phase: PHASE.FINISHED });
      engine._handleMessage({ data: buf });

      expect(engine.audio.playWin).toHaveBeenCalled();
    });

    it("stops thrust on ROUND_OVER transition and clears peer flag", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", false, null);
      engine.start();
      engine.gameState.phase = PHASE.PLAYING;
      engine._peerThrustAudioPlaying = true;

      const buf = buildEncodedState({ phase: PHASE.ROUND_OVER });
      engine._handleMessage({ data: buf });

      expect(engine.audio.stopThrust).toHaveBeenCalled();
      expect(engine._peerThrustAudioPlaying).toBe(false);
    });

    it("stops thrust on FINISHED transition", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", false, null);
      engine.start();
      engine.gameState.phase = PHASE.PLAYING;
      engine._peerThrustAudioPlaying = true;

      const buf = buildEncodedState({ phase: PHASE.FINISHED });
      engine._handleMessage({ data: buf });

      expect(engine.audio.stopThrust).toHaveBeenCalled();
      expect(engine._peerThrustAudioPlaying).toBe(false);
    });

    it("plays death audio on score change", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", false, null);
      engine.start();
      engine.gameState.score1 = 0;

      const buf = buildEncodedState({ score1: 1 });
      engine._handleMessage({ data: buf });

      expect(engine.audio.playDeath).toHaveBeenCalled();
    });
  });

  describe("gravity well mode specifics (host game loop)", () => {
    beforeEach(() => {
      vi.useFakeTimers();
    });

    afterEach(() => {
      vi.useRealTimers();
    });

    it("plays star proximity audio using min distance of both ships", () => {
      engine = new StarDuelEngine(canvas, channel, "gravity_well", true, null);
      engine.start();
      engine._handleMessage({ data: encodeGameReady() });
      vi.advanceTimersByTime(4500); // countdown + spawn

      expect(engine.gameState.phase).toBe(PHASE.PLAYING);

      // Run one game loop frame
      engine._gameLoop(performance.now());

      // In gravity well mode, playStarProximity should be called
      expect(engine.audio.playStarProximity).toHaveBeenCalled();

      // The argument should be the min of two distances
      const callArg = engine.audio.playStarProximity.mock.calls[0][0];
      expect(typeof callArg).toBe("number");
      expect(callArg).toBeGreaterThanOrEqual(0);
    });
  });

  describe("warp handling (host game loop)", () => {
    beforeEach(() => {
      vi.useFakeTimers();
    });

    afterEach(() => {
      vi.useRealTimers();
    });

    it("attemptWarp assigns result ship directly from physics", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      engine.start();
      engine._handleMessage({ data: encodeGameReady() });
      vi.advanceTimersByTime(4500);
      expect(engine.gameState.phase).toBe(PHASE.PLAYING);

      // Make ship1 alive, no cooldown, press warp
      engine.gameState.ship1 = {
        ...engine.gameState.ship1,
        warpCooldown: 0,
        invulnerable: false,
        invulnTimer: 0,
      };
      engine.localInputs.warp = true;

      // Mock Math.random so warp succeeds (no death: need random >= 0.2)
      const originalRandom = Math.random;
      Math.random = () => 0.5; // > WARP_DEATH_CHANCE

      engine._gameLoop(performance.now());

      expect(engine.audio.playWarp).toHaveBeenCalled();

      Math.random = originalRandom;
    });
  });

  // ── Connection Resilience ──

  describe("connection resilience", () => {
    it("double-start is a no-op", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      engine.start();
      const firstState = engine.gameState;
      engine.start(); // should not reset
      expect(engine.gameState).toBe(firstState);
    });

    it("blur clears local inputs", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      engine.start();
      engine.localInputs = {
        rotateLeft: true,
        rotateRight: true,
        thrust: true,
        fire: true,
        warp: true,
      };
      engine._handleBlur();
      expect(engine.localInputs.rotateLeft).toBe(false);
      expect(engine.localInputs.rotateRight).toBe(false);
      expect(engine.localInputs.thrust).toBe(false);
      expect(engine.localInputs.fire).toBe(false);
      expect(engine.localInputs.warp).toBe(false);
    });

    it("channel close ends game with disconnect flag", () => {
      const onEnd = vi.fn();
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, onEnd);
      engine.start();
      engine.gameState.phase = PHASE.PLAYING;
      engine._handleChannelClose();
      expect(engine.gameState.phase).toBe(PHASE.FINISHED);
      expect(onEnd).toHaveBeenCalledWith(expect.objectContaining({ disconnected: true }));
    });

    it("channel close is no-op when game already finished", () => {
      const onEnd = vi.fn();
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, onEnd);
      engine.start();
      engine.gameState.phase = PHASE.FINISHED;
      engine._handleChannelClose();
      expect(onEnd).not.toHaveBeenCalled();
    });
  });

  // ── Additional edge-case coverage ──

  describe("additional edge cases", () => {
    beforeEach(() => {
      vi.useFakeTimers();
    });

    afterEach(() => {
      vi.useRealTimers();
    });

    it("P2 remote fire edge-trigger: false→true fires missile", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      engine.start();
      engine._handleMessage({ data: encodeGameReady() });
      vi.advanceTimersByTime(4500); // countdown + spawn
      expect(engine.gameState.phase).toBe(PHASE.PLAYING);

      // Ensure P2 fire was off
      engine._p2FirePrev = false;
      engine.remoteInputs.fire = true;
      engine.audio.playFire.mockClear();

      engine._gameLoop(performance.now());

      expect(engine.audio.playFire).toHaveBeenCalled();
      expect(engine._p2FirePrev).toBe(true);
    });

    it("P2 remote warp edge-trigger: false→true attempts warp", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      engine.start();
      engine._handleMessage({ data: encodeGameReady() });
      vi.advanceTimersByTime(4500);
      expect(engine.gameState.phase).toBe(PHASE.PLAYING);

      // Make ship2 alive with no cooldown
      engine.gameState.ship2 = {
        ...engine.gameState.ship2,
        warpCooldown: 0,
        invulnerable: false,
        invulnTimer: 0,
      };
      engine._p2WarpPrev = false;
      engine.remoteInputs.warp = true;
      engine.audio.playWarp.mockClear();

      const originalRandom = Math.random;
      Math.random = () => 0.5; // ensure warp succeeds

      engine._gameLoop(performance.now());

      expect(engine.audio.playWarp).toHaveBeenCalled();
      expect(engine._p2WarpPrev).toBe(true);

      Math.random = originalRandom;
    });

    it("debris field mode: asteroid collision kills ship", () => {
      engine = new StarDuelEngine(canvas, channel, "debris_field", true, null);
      engine.start();
      engine._handleMessage({ data: encodeGameReady() });
      vi.advanceTimersByTime(4500);
      expect(engine.gameState.phase).toBe(PHASE.PLAYING);

      // Place ship1 directly on an asteroid, clearing invulnerability
      if (engine.gameState.asteroids.length > 0) {
        const ast = engine.gameState.asteroids[0];
        engine.gameState.ship1 = {
          ...engine.gameState.ship1,
          x: ast.x,
          y: ast.y,
          alive: true,
          exploding: false,
          invulnerable: false,
          invulnTimer: 0,
        };
        engine.audio.playDeath.mockClear();
        engine._gameLoop(performance.now());

        // Ship should have been killed by asteroid collision
        expect(engine.gameState.ship1.exploding).toBe(true);
        expect(engine.gameState.ship1.alive).toBe(false);
      }
    });

    it("gravity well mode: star collision kills ship", () => {
      engine = new StarDuelEngine(canvas, channel, "gravity_well", true, null);
      engine.start();
      engine._handleMessage({ data: encodeGameReady() });
      vi.advanceTimersByTime(4500);
      expect(engine.gameState.phase).toBe(PHASE.PLAYING);

      // Place ship1 at the star position, clearing invulnerability
      engine.gameState.ship1 = {
        ...engine.gameState.ship1,
        x: STAR_X,
        y: STAR_Y,
        vx: 0,
        vy: 0,
        alive: true,
        exploding: false,
        invulnerable: false,
        invulnTimer: 0,
      };
      engine._gameLoop(performance.now());

      // Ship should have been killed by star collision
      expect(engine.gameState.ship1.alive).toBe(false);
      expect(engine.gameState.ship1.exploding).toBe(true);
    });

    it("onGameEnd null callback safety in _handleGameFinished", () => {
      engine = new StarDuelEngine(canvas, channel, "star_duel", true, null);
      engine.start();
      engine._handleMessage({ data: encodeGameReady() });
      vi.advanceTimersByTime(4500);
      expect(engine.gameState.phase).toBe(PHASE.PLAYING);

      // Set score to trigger game finished
      engine.gameState.score1 = WIN_SCORE;
      engine.onGameEnd = null;

      expect(() => engine._handleGameFinished()).not.toThrow();
      expect(engine.gameState.phase).toBe(PHASE.FINISHED);
    });
  });
});
