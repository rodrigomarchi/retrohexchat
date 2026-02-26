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
} from "../../../../js/lib/games/hex_invaders/protocol.js";
import {
  createInitialState,
  createWave,
  CANVAS_W,
  CANVAS_H,
  INITIAL_LIVES,
} from "../../../../js/lib/games/hex_invaders/physics.js";

// Must mock audio BEFORE importing engine
vi.mock("../../../../js/lib/games/hex_invaders/audio.js", () => ({
  HexInvadersAudio: function () {
    return {
      playCountdown: vi.fn(),
      playFire: vi.fn(),
      playMarch: vi.fn(),
      playAlienDestroyed: vi.fn(),
      playArmoredClang: vi.fn(),
      playCannonHit: vi.fn(),
      playShieldHit: vi.fn(),
      playUFOAppear: vi.fn(),
      playUFODestroyed: vi.fn(),
      playCombo: vi.fn(),
      playDropWarning: vi.fn(),
      playDropLand: vi.fn(),
      playWaveClear: vi.fn(),
      playInvaded: vi.fn(),
      playVictory: vi.fn(),
      playBombFall: vi.fn(),
    };
  },
}));

// Must mock renderer
vi.mock("../../../../js/lib/games/hex_invaders/renderer.js", () => ({
  getColors: vi.fn(() => ({
    bg: "#000033",
    fg: "#00ff00",
    muted: "#006600",
    p1: "#39ff14",
    p2: "#00e5ff",
  })),
  render: vi.fn(),
}));

const { HexInvadersEngine } = await import("../../../../js/lib/games/hex_invaders/engine.js");
const { render, getColors } = await import("../../../../js/lib/games/hex_invaders/renderer.js");

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
    closePath: vi.fn(),
    setLineDash: vi.fn(),
    save: vi.fn(),
    restore: vi.fn(),
    translate: vi.fn(),
    rotate: vi.fn(),
    createRadialGradient: vi.fn(() => ({
      addColorStop: vi.fn(),
    })),
    drawImage: vi.fn(),
    clearRect: vi.fn(),
  };
  canvas.getContext = vi.fn(() => mockCtx);

  return canvas;
}

describe("HexInvadersEngine", () => {
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

  // ── Constructor ──

  describe("constructor", () => {
    it("creates with host role", () => {
      engine = new HexInvadersEngine(canvas, channel, "hex_invaders", true, null);
      expect(engine.isHost).toBe(true);
      expect(engine.gameState.phase).toBe(PHASE.WAITING);
      expect(engine.mode).toBe(GAME_MODE.INVASION_WAR);
    });

    it("creates with peer role and seed 0", () => {
      engine = new HexInvadersEngine(canvas, channel, "hex_invaders", false, null);
      expect(engine.isHost).toBe(false);
      expect(engine.seed).toBe(0);
    });

    it("host generates a non-zero seed", () => {
      engine = new HexInvadersEngine(canvas, channel, "hex_invaders", true, null);
      expect(engine.seed).toBeGreaterThan(0);
    });

    it("maps hex_invaders to INVASION_WAR mode", () => {
      engine = new HexInvadersEngine(canvas, channel, "hex_invaders", true, null);
      expect(engine.mode).toBe(GAME_MODE.INVASION_WAR);
    });

    it("maps hex_invaders_coop to COOP mode", () => {
      engine = new HexInvadersEngine(canvas, channel, "hex_invaders_coop", true, null);
      expect(engine.mode).toBe(GAME_MODE.COOP);
    });

    it("maps hex_invaders_blitz to BLITZ mode", () => {
      engine = new HexInvadersEngine(canvas, channel, "hex_invaders_blitz", true, null);
      expect(engine.mode).toBe(GAME_MODE.BLITZ);
    });

    it("falls back to INVASION_WAR for unknown gameId", () => {
      engine = new HexInvadersEngine(canvas, channel, "hex_invaders_unknown", true, null);
      expect(engine.mode).toBe(GAME_MODE.INVASION_WAR);
    });

    it("initializes localInputs and remoteInputs", () => {
      engine = new HexInvadersEngine(canvas, channel, "hex_invaders", true, null);
      expect(engine.localInputs).toEqual({ left: false, right: false, fire: false });
      expect(engine.remoteInputs).toEqual({ left: false, right: false, fire: false });
    });

    it("initializes fire edge-trigger flags to false", () => {
      engine = new HexInvadersEngine(canvas, channel, "hex_invaders", true, null);
      expect(engine._localFirePressed).toBe(false);
      expect(engine._remoteFirePressed).toBe(false);
    });

    it("stores onGameEnd callback", () => {
      const cb = vi.fn();
      engine = new HexInvadersEngine(canvas, channel, "hex_invaders", true, cb);
      expect(engine.onGameEnd).toBe(cb);
    });

    it("initializes game state with correct lives", () => {
      engine = new HexInvadersEngine(canvas, channel, "hex_invaders", true, null);
      expect(engine.gameState.lives1).toBe(INITIAL_LIVES);
      expect(engine.gameState.lives2).toBe(INITIAL_LIVES);
    });

    it("initializes with no active missiles", () => {
      engine = new HexInvadersEngine(canvas, channel, "hex_invaders", true, null);
      expect(engine.gameState.m1Active).toBe(false);
      expect(engine.gameState.m2Active).toBe(false);
    });
  });

  // ── Start ──

  describe("start", () => {
    it("sets running to true", () => {
      engine = new HexInvadersEngine(canvas, channel, "hex_invaders", true, null);
      engine.start();
      expect(engine.running).toBe(true);
    });

    it("host does NOT send GAME_READY", () => {
      engine = new HexInvadersEngine(canvas, channel, "hex_invaders", true, null);
      engine.start();
      expect(channel.send).not.toHaveBeenCalled();
    });

    it("peer sends GAME_READY on start", () => {
      engine = new HexInvadersEngine(canvas, channel, "hex_invaders", false, null);
      engine.start();
      expect(channel.send).toHaveBeenCalledTimes(1);
      const sent = channel.send.mock.calls[0][0];
      const view = new DataView(sent);
      expect(view.getUint8(0)).toBe(MSG_TYPE.GAME_READY);
    });

    it("reads colors from canvas", () => {
      engine = new HexInvadersEngine(canvas, channel, "hex_invaders", true, null);
      engine.start();
      expect(getColors).toHaveBeenCalledWith(canvas);
      expect(engine.colors).not.toBeNull();
    });

    it("renders initial state on start (host)", () => {
      engine = new HexInvadersEngine(canvas, channel, "hex_invaders", true, null);
      engine.start();
      expect(render).toHaveBeenCalled();
    });

    it("renders initial state on start (peer)", () => {
      engine = new HexInvadersEngine(canvas, channel, "hex_invaders", false, null);
      engine.start();
      expect(render).toHaveBeenCalled();
    });

    it("double-start guard prevents duplicate initialization", () => {
      engine = new HexInvadersEngine(canvas, channel, "hex_invaders", false, null);
      engine.start();
      const sendCount = channel.send.mock.calls.length;
      engine.start(); // second call should be no-op
      expect(channel.send.mock.calls.length).toBe(sendCount);
    });

    it("adds blur listener on start", () => {
      engine = new HexInvadersEngine(canvas, channel, "hex_invaders", true, null);
      const addSpy = vi.spyOn(window, "addEventListener");
      engine.start();
      expect(addSpy).toHaveBeenCalledWith("blur", engine._boundBlur);
      addSpy.mockRestore();
    });

    it("adds channel close listener on start", () => {
      engine = new HexInvadersEngine(canvas, channel, "hex_invaders", true, null);
      engine.start();
      expect(channel.addEventListener).toHaveBeenCalledWith("close", engine._boundChannelClose);
    });
  });

  // ── Stop ──

  describe("stop", () => {
    it("sets running to false", () => {
      engine = new HexInvadersEngine(canvas, channel, "hex_invaders", true, null);
      engine.start();
      engine.stop();
      expect(engine.running).toBe(false);
    });

    it("clears phaseTimer", () => {
      vi.useFakeTimers();
      engine = new HexInvadersEngine(canvas, channel, "hex_invaders", true, null);
      engine.start();
      engine.phaseTimer = setTimeout(() => {}, 5000);
      engine.stop();
      expect(engine.phaseTimer).toBeNull();
    });

    it("cancels animFrame", () => {
      engine = new HexInvadersEngine(canvas, channel, "hex_invaders", true, null);
      engine.start();
      engine.animFrame = 42;
      engine.stop();
      expect(globalThis.cancelAnimationFrame).toHaveBeenCalledWith(42);
      expect(engine.animFrame).toBeNull();
    });

    it("resets fire edge-trigger flags", () => {
      engine = new HexInvadersEngine(canvas, channel, "hex_invaders", true, null);
      engine.start();
      engine._localFirePressed = true;
      engine._remoteFirePressed = true;
      engine.stop();
      expect(engine._localFirePressed).toBe(false);
      expect(engine._remoteFirePressed).toBe(false);
    });

    it("removes event listeners", () => {
      engine = new HexInvadersEngine(canvas, channel, "hex_invaders", true, null);
      engine.start();
      const removeSpy = vi.spyOn(document, "removeEventListener");
      engine.stop();
      expect(removeSpy).toHaveBeenCalledWith("keydown", engine._boundOnKeyDown);
      expect(removeSpy).toHaveBeenCalledWith("keyup", engine._boundOnKeyUp);
      expect(channel.removeEventListener).toHaveBeenCalledWith("message", engine._boundOnMessage);
      removeSpy.mockRestore();
    });

    it("removes blur and channel close listeners", () => {
      engine = new HexInvadersEngine(canvas, channel, "hex_invaders", true, null);
      engine.start();
      const removeSpy = vi.spyOn(window, "removeEventListener");
      engine.stop();
      expect(removeSpy).toHaveBeenCalledWith("blur", engine._boundBlur);
      expect(channel.removeEventListener).toHaveBeenCalledWith("close", engine._boundChannelClose);
      removeSpy.mockRestore();
    });
  });

  // ── Input Handling ──

  describe("input handling", () => {
    describe("_mapKey", () => {
      it("maps ArrowLeft to LEFT", () => {
        engine = new HexInvadersEngine(canvas, channel, "hex_invaders", true, null);
        expect(engine._mapKey("ArrowLeft")).toBe(INPUT_KEY.LEFT);
      });

      it("maps 'a' and 'A' to LEFT", () => {
        engine = new HexInvadersEngine(canvas, channel, "hex_invaders", true, null);
        expect(engine._mapKey("a")).toBe(INPUT_KEY.LEFT);
        expect(engine._mapKey("A")).toBe(INPUT_KEY.LEFT);
      });

      it("maps ArrowRight to RIGHT", () => {
        engine = new HexInvadersEngine(canvas, channel, "hex_invaders", true, null);
        expect(engine._mapKey("ArrowRight")).toBe(INPUT_KEY.RIGHT);
      });

      it("maps 'd' and 'D' to RIGHT", () => {
        engine = new HexInvadersEngine(canvas, channel, "hex_invaders", true, null);
        expect(engine._mapKey("d")).toBe(INPUT_KEY.RIGHT);
        expect(engine._mapKey("D")).toBe(INPUT_KEY.RIGHT);
      });

      it("maps Space to FIRE", () => {
        engine = new HexInvadersEngine(canvas, channel, "hex_invaders", true, null);
        expect(engine._mapKey(" ")).toBe(INPUT_KEY.FIRE);
      });

      it("returns null for unrecognized keys", () => {
        engine = new HexInvadersEngine(canvas, channel, "hex_invaders", true, null);
        expect(engine._mapKey("x")).toBeNull();
        expect(engine._mapKey("Enter")).toBeNull();
        expect(engine._mapKey("Shift")).toBeNull();
      });
    });

    describe("_handleKeyDown (host)", () => {
      beforeEach(() => {
        engine = new HexInvadersEngine(canvas, channel, "hex_invaders", true, null);
        engine.start();
      });

      it("sets localInputs.left on ArrowLeft", () => {
        engine._handleKeyDown({ key: "ArrowLeft", preventDefault: vi.fn() });
        expect(engine.localInputs.left).toBe(true);
      });

      it("sets localInputs.right on ArrowRight", () => {
        engine._handleKeyDown({ key: "ArrowRight", preventDefault: vi.fn() });
        expect(engine.localInputs.right).toBe(true);
      });

      it("sets localInputs.fire on Space", () => {
        engine._handleKeyDown({ key: " ", preventDefault: vi.fn() });
        expect(engine.localInputs.fire).toBe(true);
      });

      it("calls preventDefault for recognized keys", () => {
        const e = { key: "ArrowLeft", preventDefault: vi.fn() };
        engine._handleKeyDown(e);
        expect(e.preventDefault).toHaveBeenCalled();
      });

      it("does not call preventDefault for unrecognized keys", () => {
        const e = { key: "x", preventDefault: vi.fn() };
        engine._handleKeyDown(e);
        expect(e.preventDefault).not.toHaveBeenCalled();
      });

      it("does not send anything over channel (host handles locally)", () => {
        engine._handleKeyDown({ key: "ArrowLeft", preventDefault: vi.fn() });
        expect(channel.send).not.toHaveBeenCalled();
      });
    });

    describe("_handleKeyDown (peer)", () => {
      beforeEach(() => {
        engine = new HexInvadersEngine(canvas, channel, "hex_invaders", false, null);
        engine.start();
        channel.send.mockClear(); // clear GAME_READY send
      });

      it("sends encodePlayerInput for left key", () => {
        engine._handleKeyDown({ key: "ArrowLeft", preventDefault: vi.fn() });
        expect(channel.send).toHaveBeenCalledTimes(1);
        const buf = channel.send.mock.calls[0][0];
        const view = new DataView(buf);
        expect(view.getUint8(0)).toBe(MSG_TYPE.PLAYER_INPUT);
        expect(view.getUint8(1)).toBe(INPUT_KEY.LEFT);
        expect(view.getUint8(2)).toBe(1); // pressed = true
      });

      it("sends encodePlayerInput for fire key", () => {
        engine._handleKeyDown({ key: " ", preventDefault: vi.fn() });
        expect(channel.send).toHaveBeenCalledTimes(1);
        const buf = channel.send.mock.calls[0][0];
        const view = new DataView(buf);
        expect(view.getUint8(1)).toBe(INPUT_KEY.FIRE);
        expect(view.getUint8(2)).toBe(1);
      });

      it("does not modify localInputs (peer sends over network)", () => {
        engine._handleKeyDown({ key: "ArrowLeft", preventDefault: vi.fn() });
        expect(engine.localInputs.left).toBe(false);
      });
    });

    describe("_handleKeyUp (host)", () => {
      beforeEach(() => {
        engine = new HexInvadersEngine(canvas, channel, "hex_invaders", true, null);
        engine.start();
        engine.localInputs.left = true;
        engine.localInputs.right = true;
        engine.localInputs.fire = true;
      });

      it("clears localInputs.left on ArrowLeft release", () => {
        engine._handleKeyUp({ key: "ArrowLeft", preventDefault: vi.fn() });
        expect(engine.localInputs.left).toBe(false);
      });

      it("clears localInputs.right on ArrowRight release", () => {
        engine._handleKeyUp({ key: "ArrowRight", preventDefault: vi.fn() });
        expect(engine.localInputs.right).toBe(false);
      });

      it("clears localInputs.fire on Space release", () => {
        engine._handleKeyUp({ key: " ", preventDefault: vi.fn() });
        expect(engine.localInputs.fire).toBe(false);
      });

      it("calls preventDefault for recognized keys", () => {
        const e = { key: " ", preventDefault: vi.fn() };
        engine._handleKeyUp(e);
        expect(e.preventDefault).toHaveBeenCalled();
      });
    });

    describe("_handleKeyUp (peer)", () => {
      beforeEach(() => {
        engine = new HexInvadersEngine(canvas, channel, "hex_invaders", false, null);
        engine.start();
        channel.send.mockClear();
      });

      it("sends release input over channel", () => {
        engine._handleKeyUp({ key: "ArrowRight", preventDefault: vi.fn() });
        expect(channel.send).toHaveBeenCalledTimes(1);
        const buf = channel.send.mock.calls[0][0];
        const view = new DataView(buf);
        expect(view.getUint8(0)).toBe(MSG_TYPE.PLAYER_INPUT);
        expect(view.getUint8(1)).toBe(INPUT_KEY.RIGHT);
        expect(view.getUint8(2)).toBe(0); // pressed = false
      });
    });
  });

  // ── Network Messages ──

  describe("network messages (_handleMessage)", () => {
    it("ignores non-ArrayBuffer data", () => {
      engine = new HexInvadersEngine(canvas, channel, "hex_invaders", true, null);
      engine.start();
      // Should not throw
      engine._handleMessage({ data: "not a buffer" });
      engine._handleMessage({ data: 123 });
      engine._handleMessage({ data: null });
    });

    describe("host receiving messages", () => {
      beforeEach(() => {
        engine = new HexInvadersEngine(canvas, channel, "hex_invaders", true, null);
        engine.start();
      });

      it("PLAYER_INPUT sets remoteInputs.left", () => {
        const buf = encodePlayerInput(INPUT_KEY.LEFT, true);
        engine._handleMessage({ data: buf });
        expect(engine.remoteInputs.left).toBe(true);
      });

      it("PLAYER_INPUT sets remoteInputs.right", () => {
        const buf = encodePlayerInput(INPUT_KEY.RIGHT, true);
        engine._handleMessage({ data: buf });
        expect(engine.remoteInputs.right).toBe(true);
      });

      it("PLAYER_INPUT sets remoteInputs.fire", () => {
        const buf = encodePlayerInput(INPUT_KEY.FIRE, true);
        engine._handleMessage({ data: buf });
        expect(engine.remoteInputs.fire).toBe(true);
      });

      it("PLAYER_INPUT release clears remoteInputs", () => {
        engine.remoteInputs.left = true;
        const buf = encodePlayerInput(INPUT_KEY.LEFT, false);
        engine._handleMessage({ data: buf });
        expect(engine.remoteInputs.left).toBe(false);
      });

      it("GAME_READY sets peerReady and starts countdown", () => {
        vi.useFakeTimers();
        const buf = encodeGameReady();
        engine._handleMessage({ data: buf });
        expect(engine.peerReady).toBe(true);
        expect(engine.gameState.phase).toBe(PHASE.COUNTDOWN);
        expect(engine.gameState.countdown).toBe(3);
      });

      it("GAME_READY duplicate is ignored", () => {
        vi.useFakeTimers();
        const buf = encodeGameReady();
        engine._handleMessage({ data: buf });
        const countdown1 = engine.gameState.countdown;
        // second ready should be no-op
        engine._handleMessage({ data: buf });
        expect(engine.gameState.countdown).toBe(countdown1);
      });

      it("host ignores GAME_STATE messages", () => {
        const state = createInitialState(GAME_MODE.INVASION_WAR, 12345);
        state.score1 = 999;
        const buf = encodeGameState(state);
        const prevScore = engine.gameState.score1;
        engine._handleMessage({ data: buf });
        expect(engine.gameState.score1).toBe(prevScore);
      });

      it("host ignores GAME_END messages", () => {
        const buf = encodeGameEnd({ score1: 100, score2: 200, winner: 2 });
        engine._handleMessage({ data: buf });
        expect(engine.gameState.phase).toBe(PHASE.WAITING);
      });
    });

    describe("peer receiving messages", () => {
      let onGameEnd;

      beforeEach(() => {
        onGameEnd = vi.fn();
        engine = new HexInvadersEngine(canvas, channel, "hex_invaders", false, onGameEnd);
        engine.start();
        channel.send.mockClear();
        render.mockClear();
      });

      it("GAME_STATE applies state and renders", () => {
        const state = createInitialState(GAME_MODE.INVASION_WAR, 12345);
        state.phase = PHASE.PLAYING;
        state.score1 = 42;
        const buf = encodeGameState(state);
        engine._handleMessage({ data: buf });
        expect(engine.gameState.score1).toBe(42);
        expect(engine.gameState.phase).toBe(PHASE.PLAYING);
        expect(render).toHaveBeenCalled();
      });

      it("GAME_STATE bootstraps seed from first state", () => {
        expect(engine.seed).toBe(0);
        const state = createInitialState(GAME_MODE.INVASION_WAR, 54321);
        const buf = encodeGameState(state);
        engine._handleMessage({ data: buf });
        expect(engine.seed).toBe(54321);
      });

      it("GAME_STATE preserves _shieldPositions", () => {
        const originalPositions = engine.gameState._shieldPositions;
        const state = createInitialState(GAME_MODE.INVASION_WAR, 12345);
        const buf = encodeGameState(state);
        engine._handleMessage({ data: buf });
        expect(engine.gameState._shieldPositions).toStrictEqual(originalPositions);
      });

      it("GAME_END sets FINISHED phase and calls onGameEnd", () => {
        const buf = encodeGameEnd({ score1: 100, score2: 50, winner: 1 });
        engine._handleMessage({ data: buf });
        expect(engine.gameState.phase).toBe(PHASE.FINISHED);
        expect(onGameEnd).toHaveBeenCalledWith({
          score: { p1: 100, p2: 50 },
          winner: 1,
        });
      });

      it("GAME_END renders after setting FINISHED", () => {
        const buf = encodeGameEnd({ score1: 0, score2: 0, winner: 0 });
        engine._handleMessage({ data: buf });
        expect(render).toHaveBeenCalled();
      });

      it("GAME_END swallows callback errors", () => {
        const badCb = vi.fn(() => {
          throw new Error("callback exploded");
        });
        engine.onGameEnd = badCb;
        const buf = encodeGameEnd({ score1: 0, score2: 0, winner: 1 });
        // Should not throw
        engine._handleMessage({ data: buf });
        expect(badCb).toHaveBeenCalled();
      });

      it("peer ignores PLAYER_INPUT messages", () => {
        const buf = encodePlayerInput(INPUT_KEY.LEFT, true);
        engine._handleMessage({ data: buf });
        expect(engine.remoteInputs.left).toBe(false);
      });

      it("peer ignores GAME_READY messages", () => {
        const buf = encodeGameReady();
        engine._handleMessage({ data: buf });
        expect(engine.peerReady).toBe(false);
      });
    });
  });

  // ── _applyPeerState ──

  describe("_applyPeerState", () => {
    beforeEach(() => {
      engine = new HexInvadersEngine(canvas, channel, "hex_invaders", false, null);
      engine.start();
      render.mockClear();
    });

    it("ignores null decoded state", () => {
      engine._applyPeerState(null);
      expect(render).not.toHaveBeenCalled();
    });

    it("copies decoded fields to gameState", () => {
      const decoded = {
        phase: PHASE.PLAYING,
        wave: 2,
        countdown: 0,
        mode: GAME_MODE.INVASION_WAR,
        seed: 99999,
        score1: 150,
        score2: 80,
        lives1: 2,
        lives2: 3,
        combo1Count: 1,
        combo2Count: 0,
        cannon1X: 100,
        cannon2X: 400,
        m1X: 50,
        m1Y: 200,
        m1Active: true,
        m2X: 0,
        m2Y: 0,
        m2Active: false,
        aliens1: [],
        aliens2: [],
        alien1Count: 0,
        alien2Count: 0,
        alien1DirRight: true,
        alien2DirRight: false,
        bombs: [],
        bombCount: 0,
        shields: [4, 4, 3, 2],
        ufoX: 100,
        ufoActive: true,
        ufoDir: 1,
        drops: [],
        dropCount: 0,
      };
      engine._applyPeerState(decoded);
      expect(engine.gameState.score1).toBe(150);
      expect(engine.gameState.score2).toBe(80);
      expect(engine.gameState.phase).toBe(PHASE.PLAYING);
      expect(engine.gameState.m1Active).toBe(true);
    });

    it("preserves _shieldPositions across state updates", () => {
      const originalPositions = [...engine.gameState._shieldPositions];
      const decoded = {
        phase: PHASE.PLAYING,
        seed: 12345,
        _shieldPositions: [{ x: 0, y: 0 }], // try to overwrite
      };
      engine._applyPeerState(decoded);
      expect(engine.gameState._shieldPositions).toStrictEqual(originalPositions);
    });

    it("bootstraps seed and re-creates state on first non-zero seed", () => {
      expect(engine.seed).toBe(0);
      const decoded = { seed: 77777, phase: PHASE.COUNTDOWN };
      engine._applyPeerState(decoded);
      expect(engine.seed).toBe(77777);
    });

    it("does not re-bootstrap seed on subsequent states", () => {
      engine.seed = 11111;
      const decoded = { seed: 22222, phase: PHASE.PLAYING, score1: 50 };
      engine._applyPeerState(decoded);
      // seed stays, but the decoded fields (including seed) overwrite via Object.assign
      expect(engine.seed).toBe(11111); // engine.seed not changed
      expect(engine.gameState.score1).toBe(50);
    });

    it("renders after applying state", () => {
      const decoded = { seed: 12345, phase: PHASE.PLAYING };
      engine._applyPeerState(decoded);
      expect(render).toHaveBeenCalled();
    });
  });

  // ── Countdown ──

  describe("countdown (_startCountdown)", () => {
    beforeEach(() => {
      vi.useFakeTimers();
      engine = new HexInvadersEngine(canvas, channel, "hex_invaders", true, null);
      engine.start();
      channel.send.mockClear();
      render.mockClear();
    });

    it("sets phase to COUNTDOWN with count 3", () => {
      engine._startCountdown();
      expect(engine.gameState.phase).toBe(PHASE.COUNTDOWN);
      expect(engine.gameState.countdown).toBe(3);
    });

    it("broadcasts and renders immediately", () => {
      engine._startCountdown();
      expect(channel.send).toHaveBeenCalled();
      expect(render).toHaveBeenCalled();
    });

    it("decrements countdown on each tick", () => {
      engine._startCountdown();
      vi.advanceTimersByTime(1000);
      expect(engine.gameState.countdown).toBe(2);
      expect(engine.audio.playCountdown).toHaveBeenCalledTimes(1);

      vi.advanceTimersByTime(1000);
      expect(engine.gameState.countdown).toBe(1);
      expect(engine.audio.playCountdown).toHaveBeenCalledTimes(2);
    });

    it("transitions to PLAYING after full countdown", () => {
      engine._startCountdown();
      // Tick 1: count 3→2
      vi.advanceTimersByTime(1000);
      // Tick 2: count 2→1
      vi.advanceTimersByTime(1000);
      // Tick 3: count 1→0 → PLAYING
      vi.advanceTimersByTime(1000);
      expect(engine.gameState.phase).toBe(PHASE.PLAYING);
      expect(engine.audio.playCountdown).toHaveBeenCalledTimes(3);
    });

    it("creates wave 1 when countdown finishes", () => {
      engine._startCountdown();
      vi.advanceTimersByTime(3000);
      expect(engine.gameState.wave).toBe(1);
      expect(engine.gameState.aliens1.length).toBeGreaterThan(0);
    });

    it("starts game loop after countdown finishes", () => {
      engine._startCountdown();
      vi.advanceTimersByTime(3000);
      // After countdown finishes, _startGameLoop sets animFrame
      expect(engine.animFrame).not.toBeNull();
    });

    it("guards against !this.running in tick", () => {
      engine._startCountdown();
      engine.running = false;
      vi.advanceTimersByTime(1000);
      // countdown should NOT have changed since running is false
      expect(engine.gameState.countdown).toBe(3);
    });
  });

  // ── Game Loop ──

  describe("game loop (_gameLoop)", () => {
    beforeEach(() => {
      engine = new HexInvadersEngine(canvas, channel, "hex_invaders", true, null);
      engine.start();
      // Set up a playing state with aliens
      engine.gameState = createWave(createInitialState(GAME_MODE.INVASION_WAR, 12345), 1);
      engine.gameState.phase = PHASE.PLAYING;
      engine.gameState.seed = 12345;
      engine.frameCount = 0;
      render.mockClear();
      channel.send.mockClear();
    });

    it("exits early if not running", () => {
      engine.running = false;
      engine._gameLoop();
      expect(render).not.toHaveBeenCalled();
    });

    it("applies left input for cannon movement", () => {
      const prevX = engine.gameState.cannon1X;
      engine.localInputs.left = true;
      engine._gameLoop();
      expect(engine.gameState.cannon1X).toBeLessThan(prevX);
    });

    it("applies right input for cannon movement", () => {
      const prevX = engine.gameState.cannon1X;
      engine.localInputs.right = true;
      engine._gameLoop();
      expect(engine.gameState.cannon1X).toBeGreaterThan(prevX);
    });

    it("applies remote inputs for player 2 cannon", () => {
      const prevX = engine.gameState.cannon2X;
      engine.remoteInputs.left = true;
      engine._gameLoop();
      expect(engine.gameState.cannon2X).toBeLessThan(prevX);
    });

    it("edge-triggers fire: only fires on false→true transition", () => {
      engine._localFirePressed = false;
      engine.localInputs.fire = true;
      engine._gameLoop();
      expect(engine.audio.playFire).toHaveBeenCalledTimes(1);
      expect(engine._localFirePressed).toBe(true);

      // Second frame with fire still held: should NOT fire again
      engine.audio.playFire.mockClear();
      engine._gameLoop();
      expect(engine.audio.playFire).not.toHaveBeenCalled();
    });

    it("edge-triggers remote fire for player 2", () => {
      engine._remoteFirePressed = false;
      engine.remoteInputs.fire = true;
      engine._gameLoop();
      expect(engine.audio.playFire).toHaveBeenCalled();
      expect(engine._remoteFirePressed).toBe(true);
    });

    it("does not fire when fire input is false", () => {
      engine.localInputs.fire = false;
      engine._localFirePressed = false;
      engine._gameLoop();
      expect(engine.audio.playFire).not.toHaveBeenCalled();
      expect(engine._localFirePressed).toBe(false);
    });

    it("renders every frame", () => {
      engine._gameLoop();
      expect(render).toHaveBeenCalled();
    });

    it("broadcasts every STATE_SEND_INTERVAL frames", () => {
      // Game loop: render, frameCount += 1, then check frameCount % 2 === 0
      // Frame 0: frameCount becomes 1, 1%2 !== 0 → no broadcast
      engine.frameCount = 0;
      engine._gameLoop();
      expect(channel.send).not.toHaveBeenCalled();

      channel.send.mockClear();
      // Frame 1: frameCount becomes 2, 2%2 === 0 → broadcast
      engine._gameLoop();
      expect(channel.send).toHaveBeenCalled();

      channel.send.mockClear();
      // Frame 2: frameCount becomes 3, 3%2 !== 0 → no broadcast
      engine._gameLoop();
      expect(channel.send).not.toHaveBeenCalled();
    });

    it("schedules next frame via requestAnimationFrame", () => {
      globalThis.requestAnimationFrame.mockClear();
      engine._gameLoop();
      expect(globalThis.requestAnimationFrame).toHaveBeenCalledWith(engine._boundGameLoop);
    });

    it("clears events at start of each frame", () => {
      engine.gameState.events.alienKill = 1;
      engine._gameLoop();
      // After clearEvents at top of loop, events should be reset
      // (but new events may be set during collision checks)
      // The key test: alienKill from previous frame is cleared
      // We can verify by checking that playAlienDestroyed is not called
      // unless a collision actually happens this frame
    });

    it("detects game over and enters FINISHED phase", () => {
      const onGameEnd = vi.fn();
      engine.onGameEnd = onGameEnd;
      // Kill all lives for P1
      engine.gameState.lives1 = 0;
      engine._gameLoop();
      expect(engine.gameState.phase).toBe(PHASE.FINISHED);
      expect(onGameEnd).toHaveBeenCalled();
    });

    it("detects wave clear and enters WAVE_CLEAR phase", () => {
      // Kill all aliens on both sides
      engine.gameState.aliens1 = engine.gameState.aliens1.map((a) => ({
        ...a,
        type: 0,
      }));
      engine.gameState.aliens2 = engine.gameState.aliens2.map((a) => ({
        ...a,
        type: 0,
      }));
      engine._gameLoop();
      expect(engine.gameState.phase).toBe(PHASE.WAVE_CLEAR);
      expect(engine.audio.playWaveClear).toHaveBeenCalled();
    });

    it("does not run physics when phase is not PLAYING", () => {
      engine.gameState.phase = PHASE.WAVE_CLEAR;
      const prevCannon = engine.gameState.cannon1X;
      engine.localInputs.left = true;
      engine._gameLoop();
      // Cannon should not move since phase is not PLAYING
      expect(engine.gameState.cannon1X).toBe(prevCannon);
    });
  });

  // ── Wave Transitions ──

  describe("wave transitions (_handleWaveClear)", () => {
    beforeEach(() => {
      vi.useFakeTimers();
      engine = new HexInvadersEngine(canvas, channel, "hex_invaders", true, null);
      engine.start();
      engine.gameState = createWave(createInitialState(GAME_MODE.INVASION_WAR, 12345), 1);
      engine.gameState.phase = PHASE.WAVE_CLEAR;
      engine.gameState.seed = 12345;
      render.mockClear();
      channel.send.mockClear();
    });

    it("transitions to WAVE_START after WAVE_CLEAR_FRAMES delay", () => {
      engine._handleWaveClear();
      // WAVE_CLEAR_FRAMES = 120 → 120/60 * 1000 = 2000ms
      vi.advanceTimersByTime(2000);
      expect(engine.gameState.phase).toBe(PHASE.WAVE_START);
      expect(engine.gameState.wave).toBe(2);
    });

    it("transitions to PLAYING after WAVE_START_FRAMES delay", () => {
      engine._handleWaveClear();
      // 2000ms for WAVE_CLEAR, then 1000ms for WAVE_START (60/60 * 1000)
      vi.advanceTimersByTime(2000);
      expect(engine.gameState.phase).toBe(PHASE.WAVE_START);
      vi.advanceTimersByTime(1000);
      expect(engine.gameState.phase).toBe(PHASE.PLAYING);
    });

    it("starts game loop after WAVE_START phase", () => {
      engine._handleWaveClear();
      vi.advanceTimersByTime(3000); // 2000 + 1000
      // After WAVE_START delay, animFrame should be set
      expect(engine.animFrame).not.toBeNull();
    });

    it("finishes game when exceeding max waves (INVASION_WAR: 10)", () => {
      const onGameEnd = vi.fn();
      engine.onGameEnd = onGameEnd;
      engine.gameState.wave = 10; // current wave is 10, next would be 11
      engine._handleWaveClear();
      vi.advanceTimersByTime(2000);
      expect(engine.gameState.phase).toBe(PHASE.FINISHED);
      expect(onGameEnd).toHaveBeenCalled();
    });

    it("finishes game when exceeding max waves (BLITZ: 5)", () => {
      const onGameEnd = vi.fn();
      engine.onGameEnd = onGameEnd;
      engine.gameState.mode = GAME_MODE.BLITZ;
      engine.gameState.wave = 5;
      engine._handleWaveClear();
      vi.advanceTimersByTime(2000);
      expect(engine.gameState.phase).toBe(PHASE.FINISHED);
    });

    it("guards against !this.running in wave clear timeout", () => {
      engine._handleWaveClear();
      engine.running = false;
      vi.advanceTimersByTime(2000);
      // Should not transition since running is false
      expect(engine.gameState.phase).toBe(PHASE.WAVE_CLEAR);
    });

    it("guards against !this.running in wave start timeout", () => {
      engine._handleWaveClear();
      vi.advanceTimersByTime(2000); // enter WAVE_START
      engine.running = false;
      vi.advanceTimersByTime(1000);
      // Should stay in WAVE_START since running was set to false
      expect(engine.gameState.phase).toBe(PHASE.WAVE_START);
    });
  });

  // ── Game End ──

  describe("game end (_handleGameFinished)", () => {
    let onGameEnd;

    beforeEach(() => {
      onGameEnd = vi.fn();
      engine = new HexInvadersEngine(canvas, channel, "hex_invaders", true, onGameEnd);
      engine.start();
      engine.gameState = createWave(createInitialState(GAME_MODE.INVASION_WAR, 12345), 1);
      engine.gameState.phase = PHASE.FINISHED;
      engine.gameState.score1 = 100;
      engine.gameState.score2 = 50;
      render.mockClear();
      channel.send.mockClear();
    });

    it("broadcasts final state", () => {
      engine._handleGameFinished({ ended: true, winner: 1 });
      expect(channel.send).toHaveBeenCalled();
    });

    it("sends GAME_END to peer", () => {
      engine._handleGameFinished({ ended: true, winner: 1 });
      // First call is broadcast, second is GAME_END
      const calls = channel.send.mock.calls;
      const lastBuf = calls[calls.length - 1][0];
      const view = new DataView(lastBuf);
      expect(view.getUint8(0)).toBe(MSG_TYPE.GAME_END);
    });

    it("plays victory audio when winner > 0", () => {
      engine._handleGameFinished({ ended: true, winner: 1 });
      expect(engine.audio.playVictory).toHaveBeenCalled();
      expect(engine.audio.playInvaded).not.toHaveBeenCalled();
    });

    it("plays invaded audio when winner is 0", () => {
      engine._handleGameFinished({ ended: true, winner: 0 });
      expect(engine.audio.playInvaded).toHaveBeenCalled();
      expect(engine.audio.playVictory).not.toHaveBeenCalled();
    });

    it("calls onGameEnd with score and winner", () => {
      engine._handleGameFinished({ ended: true, winner: 2 });
      expect(onGameEnd).toHaveBeenCalledWith({
        score: { p1: 100, p2: 50 },
        winner: 2,
      });
    });

    it("renders the final state", () => {
      engine._handleGameFinished({ ended: true, winner: 1 });
      expect(render).toHaveBeenCalled();
    });

    it("swallows onGameEnd callback errors", () => {
      engine.onGameEnd = vi.fn(() => {
        throw new Error("boom");
      });
      // Should not throw
      engine._handleGameFinished({ ended: true, winner: 1 });
      expect(engine.onGameEnd).toHaveBeenCalled();
    });

    it("handles null onGameEnd gracefully", () => {
      engine.onGameEnd = null;
      // Should not throw
      engine._handleGameFinished({ ended: true, winner: 1 });
      expect(channel.send).toHaveBeenCalled();
    });
  });

  // ── Connection Resilience ──

  describe("connection resilience", () => {
    describe("_handleBlur", () => {
      it("clears all local inputs (host)", () => {
        engine = new HexInvadersEngine(canvas, channel, "hex_invaders", true, null);
        engine.start();
        engine.localInputs = { left: true, right: true, fire: true };
        engine._handleBlur();
        expect(engine.localInputs).toEqual({
          left: false,
          right: false,
          fire: false,
        });
      });

      it("clears local inputs and sends release messages (peer)", () => {
        engine = new HexInvadersEngine(canvas, channel, "hex_invaders", false, null);
        engine.start();
        channel.send.mockClear();
        engine.localInputs = { left: true, right: true, fire: true };
        engine._handleBlur();
        expect(engine.localInputs).toEqual({
          left: false,
          right: false,
          fire: false,
        });
        // Should send 3 release messages (left, right, fire)
        expect(channel.send).toHaveBeenCalledTimes(3);
      });

      it("host does NOT send release messages on blur", () => {
        engine = new HexInvadersEngine(canvas, channel, "hex_invaders", true, null);
        engine.start();
        engine._handleBlur();
        expect(channel.send).not.toHaveBeenCalled();
      });
    });

    describe("_handleChannelClose", () => {
      it("sets phase to FINISHED and calls onGameEnd with winner 0", () => {
        const onGameEnd = vi.fn();
        engine = new HexInvadersEngine(canvas, channel, "hex_invaders", true, onGameEnd);
        engine.start();
        engine.gameState.score1 = 50;
        engine.gameState.score2 = 30;
        engine._handleChannelClose();
        expect(engine.gameState.phase).toBe(PHASE.FINISHED);
        expect(onGameEnd).toHaveBeenCalledWith({
          score: { p1: 50, p2: 30 },
          winner: 0,
        });
      });

      it("renders after setting FINISHED", () => {
        engine = new HexInvadersEngine(canvas, channel, "hex_invaders", true, null);
        engine.start();
        render.mockClear();
        engine._handleChannelClose();
        expect(render).toHaveBeenCalled();
      });

      it("no-op if already FINISHED", () => {
        const onGameEnd = vi.fn();
        engine = new HexInvadersEngine(canvas, channel, "hex_invaders", true, onGameEnd);
        engine.start();
        engine.gameState.phase = PHASE.FINISHED;
        engine._handleChannelClose();
        expect(onGameEnd).not.toHaveBeenCalled();
      });

      it("swallows onGameEnd callback errors", () => {
        const badCb = vi.fn(() => {
          throw new Error("channel close callback error");
        });
        engine = new HexInvadersEngine(canvas, channel, "hex_invaders", true, badCb);
        engine.start();
        // Should not throw
        engine._handleChannelClose();
        expect(badCb).toHaveBeenCalled();
      });

      it("handles null onGameEnd gracefully", () => {
        engine = new HexInvadersEngine(canvas, channel, "hex_invaders", true, null);
        engine.start();
        // Should not throw
        engine._handleChannelClose();
        expect(engine.gameState.phase).toBe(PHASE.FINISHED);
      });
    });

    describe("_safeSend", () => {
      it("does not send when channel is not open", () => {
        engine = new HexInvadersEngine(canvas, channel, "hex_invaders", true, null);
        channel.readyState = "closed";
        engine._safeSend(new ArrayBuffer(1));
        expect(channel.send).not.toHaveBeenCalled();
      });

      it("catches send errors gracefully", () => {
        engine = new HexInvadersEngine(canvas, channel, "hex_invaders", true, null);
        channel.send.mockImplementation(() => {
          throw new Error("channel died");
        });
        // Should not throw
        engine._safeSend(new ArrayBuffer(1));
      });
    });
  });

  // ── Event Sounds ──

  describe("_playEventSounds", () => {
    beforeEach(() => {
      engine = new HexInvadersEngine(canvas, channel, "hex_invaders", true, null);
      engine.start();
    });

    it("plays alienDestroyed on alienKill event", () => {
      engine._playEventSounds({ events: { alienKill: 1 } });
      expect(engine.audio.playAlienDestroyed).toHaveBeenCalled();
    });

    it("plays armoredClang on armoredHit event", () => {
      engine._playEventSounds({ events: { armoredHit: 1 } });
      expect(engine.audio.playArmoredClang).toHaveBeenCalled();
    });

    it("plays cannonHit on cannonHit event", () => {
      engine._playEventSounds({ events: { cannonHit: 1 } });
      expect(engine.audio.playCannonHit).toHaveBeenCalled();
    });

    it("plays shieldHit on shieldHit event", () => {
      engine._playEventSounds({ events: { shieldHit: true } });
      expect(engine.audio.playShieldHit).toHaveBeenCalled();
    });

    it("plays ufoDestroyed on ufoKill event", () => {
      engine._playEventSounds({ events: { ufoKill: 1 } });
      expect(engine.audio.playUFODestroyed).toHaveBeenCalled();
    });

    it("plays ufoAppear on ufoAppear event", () => {
      engine._playEventSounds({ events: { ufoAppear: true } });
      expect(engine.audio.playUFOAppear).toHaveBeenCalled();
    });

    it("plays combo on combo event", () => {
      engine._playEventSounds({ events: { combo: 2 } });
      expect(engine.audio.playCombo).toHaveBeenCalledWith(2);
    });

    it("plays dropLand on dropLand event", () => {
      engine._playEventSounds({ events: { dropLand: true } });
      expect(engine.audio.playDropLand).toHaveBeenCalled();
    });

    it("plays invaded on invaded event", () => {
      engine._playEventSounds({ events: { invaded: 1 } });
      expect(engine.audio.playInvaded).toHaveBeenCalled();
    });

    it("does not play sounds for zero/false events", () => {
      engine._playEventSounds({
        events: {
          alienKill: 0,
          armoredHit: 0,
          cannonHit: 0,
          shieldHit: false,
          ufoKill: 0,
          ufoAppear: false,
          combo: 0,
          dropLand: false,
          invaded: 0,
        },
      });
      expect(engine.audio.playAlienDestroyed).not.toHaveBeenCalled();
      expect(engine.audio.playCannonHit).not.toHaveBeenCalled();
      expect(engine.audio.playCombo).not.toHaveBeenCalled();
    });
  });

  // ── Rendering ──

  describe("_renderState", () => {
    it("calls render with ctx, gameState, colors, and timestamp", () => {
      engine = new HexInvadersEngine(canvas, channel, "hex_invaders", true, null);
      engine.start();
      render.mockClear();
      engine._renderState();
      expect(render).toHaveBeenCalledWith(
        engine.ctx,
        engine.gameState,
        engine.colors,
        expect.any(Number),
      );
    });

    it("does not render if colors is null", () => {
      engine = new HexInvadersEngine(canvas, channel, "hex_invaders", true, null);
      engine.colors = null;
      render.mockClear();
      engine._renderState();
      expect(render).not.toHaveBeenCalled();
    });
  });

  // ── Broadcasting ──

  describe("_broadcastState", () => {
    it("sends encoded game state over channel", () => {
      engine = new HexInvadersEngine(canvas, channel, "hex_invaders", true, null);
      engine.start();
      channel.send.mockClear();
      engine._broadcastState();
      expect(channel.send).toHaveBeenCalledTimes(1);
      const buf = channel.send.mock.calls[0][0];
      expect(buf).toBeInstanceOf(ArrayBuffer);
      const view = new DataView(buf);
      expect(view.getUint8(0)).toBe(MSG_TYPE.GAME_STATE);
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

    it("COOP mode skips P2 aliens (only moveAliens for P1)", () => {
      engine = new HexInvadersEngine(canvas, channel, "hex_invaders_coop", true, null);
      engine.start();
      // Set up playing state
      engine.gameState = createWave(createInitialState(GAME_MODE.COOP, 12345), 1);
      engine.gameState.phase = PHASE.PLAYING;
      engine.gameState.seed = 12345;

      // In COOP mode, aliens2 should remain empty/unused
      // The game loop only calls moveAliens(s, 1) — not moveAliens(s, 2)
      const aliens2Before = engine.gameState.aliens2 ? [...engine.gameState.aliens2] : [];
      engine._gameLoop();
      const aliens2After = engine.gameState.aliens2 || [];
      // aliens2 should be unchanged (empty) in COOP mode
      expect(aliens2After.length).toBe(aliens2Before.length);
    });

    it("_startGameLoop has no duplicate guard — calling twice creates two RAF loops", () => {
      vi.useRealTimers(); // restore real timers so our mock RAF works
      globalThis.requestAnimationFrame = vi.fn(() => 42);
      engine = new HexInvadersEngine(canvas, channel, "hex_invaders", true, null);
      engine.start();
      engine.gameState.phase = PHASE.PLAYING;
      globalThis.requestAnimationFrame.mockClear();

      engine._startGameLoop();
      expect(globalThis.requestAnimationFrame).toHaveBeenCalledTimes(1);

      // Calling again overwrites animFrame, creating a new RAF
      engine._startGameLoop();
      expect(globalThis.requestAnimationFrame).toHaveBeenCalledTimes(2);
    });

    it("alien march audio fires when alien1MoveTimer rolls over (timer diff > 5)", () => {
      engine = new HexInvadersEngine(canvas, channel, "hex_invaders", true, null);
      engine.start();
      engine.gameState = createWave(createInitialState(GAME_MODE.INVASION_WAR, 12345), 1);
      engine.gameState.phase = PHASE.PLAYING;
      engine.gameState.seed = 12345;
      engine.audio.playMarch.mockClear();

      // Set alien1MoveTimer to a high value so it will reset low after moveAliens
      // The condition: s.alien1MoveTimer > this.gameState.alien1MoveTimer + 5
      // This means the NEW timer must be > OLD timer + 5 (happens on timer reset/rollover)
      // Run many frames to trigger at least one alien march rollover
      let marchCalled = false;
      for (let i = 0; i < 120; i++) {
        engine.audio.playMarch.mockClear();
        engine._gameLoop();
        if (engine.audio.playMarch.mock.calls.length > 0) {
          marchCalled = true;
          break;
        }
      }
      expect(marchCalled).toBe(true);
    });
  });
});
