import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import {
  PHASE,
  DIR,
  MSG_TYPE,
  INPUT_KEY,
  WINS_NEEDED,
  encodeGameState,
  encodePlayerInput,
  encodeGameEnd,
  encodeGameReady,
} from "../../../../js/lib/games/surround/protocol.js";
import {
  createInitialState,
  CANVAS_W,
  CANVAS_H,
} from "../../../../js/lib/games/surround/physics.js";

// Must mock audio before importing SurroundEngine
vi.mock("../../../../js/lib/games/surround/audio.js", () => ({
  SurroundAudio: function () {
    return {
      playMove: vi.fn(),
      playCrash: vi.fn(),
      playCountdown: vi.fn(),
      playRoundWin: vi.fn(),
      playMatchWin: vi.fn(),
      playMatchLose: vi.fn(),
    };
  },
}));

// Must mock renderer
vi.mock("../../../../js/lib/games/surround/renderer.js", () => ({
  getColors: vi.fn(() => ({
    bg: "#050510",
    fg: "#00ff41",
    accent: "#00d4ff",
    muted: "#0a1628",
    glow: "rgba(0,255,65,0.2)",
    warning: "#ffaa00",
  })),
  render: vi.fn(),
}));

const { SurroundEngine } = await import("../../../../js/lib/games/surround/engine.js");
const { getColors } = await import("../../../../js/lib/games/surround/renderer.js");

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

describe("SurroundEngine", () => {
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
    it("initializes with game state in WAITING phase", () => {
      engine = new SurroundEngine(canvas, channel, "light_trails", true, null);
      expect(engine.gameState).toBeDefined();
      expect(engine.gameState.phase).toBe(PHASE.WAITING);
    });

    it("sets isHost flag", () => {
      engine = new SurroundEngine(canvas, channel, "light_trails", true, null);
      expect(engine.isHost).toBe(true);
    });

    it("stores onGameEnd callback", () => {
      const cb = vi.fn();
      engine = new SurroundEngine(canvas, channel, "light_trails", true, cb);
      expect(engine.onGameEnd).toBe(cb);
    });

    it("initializes pending directions to initial facing", () => {
      engine = new SurroundEngine(canvas, channel, "light_trails", true, null);
      expect(engine.p1PendingDir).toBe(DIR.RIGHT);
      expect(engine.p2PendingDir).toBe(DIR.LEFT);
    });

    it("initializes peerReady as false", () => {
      engine = new SurroundEngine(canvas, channel, "light_trails", true, null);
      expect(engine.peerReady).toBe(false);
    });

    it("initializes tick and phase timers as null", () => {
      engine = new SurroundEngine(canvas, channel, "light_trails", true, null);
      expect(engine.tickInterval).toBeNull();
      expect(engine.phaseTimer).toBeNull();
    });
  });

  describe("start", () => {
    it("sets running to true", () => {
      engine = new SurroundEngine(canvas, channel, "light_trails", true, null);
      engine.start();
      expect(engine.running).toBe(true);
    });

    it("host does not send GAME_READY", () => {
      engine = new SurroundEngine(canvas, channel, "light_trails", true, null);
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
      engine = new SurroundEngine(canvas, channel, "light_trails", false, null);
      engine.start();
      expect(channel.send).toHaveBeenCalled();
      const buf = channel.send.mock.calls[0][0];
      const view = new Uint8Array(buf);
      expect(view[0]).toBe(MSG_TYPE.GAME_READY);
    });

    it("reads colors from canvas", () => {
      engine = new SurroundEngine(canvas, channel, "light_trails", true, null);
      engine.start();
      expect(getColors).toHaveBeenCalledWith(canvas);
      expect(engine.colors).toBeDefined();
    });

    it("starts render loop", () => {
      engine = new SurroundEngine(canvas, channel, "light_trails", true, null);
      engine.start();
      expect(globalThis.requestAnimationFrame).toHaveBeenCalled();
    });
  });

  describe("stop", () => {
    it("sets running to false", () => {
      engine = new SurroundEngine(canvas, channel, "light_trails", true, null);
      engine.start();
      engine.stop();
      expect(engine.running).toBe(false);
    });

    it("clears phase timer", () => {
      engine = new SurroundEngine(canvas, channel, "light_trails", true, null);
      engine.start();
      engine.phaseTimer = setTimeout(() => {}, 10000);
      engine.stop();
      expect(engine.phaseTimer).toBeNull();
    });

    it("cancels animation frame", () => {
      engine = new SurroundEngine(canvas, channel, "light_trails", true, null);
      engine.start();
      engine.animFrame = 99;
      engine.stop();
      expect(engine.animFrame).toBeNull();
      expect(globalThis.cancelAnimationFrame).toHaveBeenCalledWith(99);
    });

    it("clears tick interval", () => {
      engine = new SurroundEngine(canvas, channel, "light_trails", true, null);
      engine.start();
      engine.tickInterval = setInterval(() => {}, 10000);
      engine.stop();
      expect(engine.tickInterval).toBeNull();
    });
  });

  describe("_handleMessage (host)", () => {
    it("processes GAME_READY from peer", () => {
      engine = new SurroundEngine(canvas, channel, "light_trails", true, null);
      engine.start();
      expect(engine.peerReady).toBe(false);

      engine._handleMessage({ data: encodeGameReady() });

      expect(engine.peerReady).toBe(true);
      expect(engine.gameState.phase).toBe(PHASE.COUNTDOWN);
    });

    it("ignores duplicate GAME_READY", () => {
      engine = new SurroundEngine(canvas, channel, "light_trails", true, null);
      engine.start();

      engine._handleMessage({ data: encodeGameReady() });
      const countdownCalls1 = engine.audio.playCountdown.mock.calls.length;

      engine._handleMessage({ data: encodeGameReady() });
      const countdownCalls2 = engine.audio.playCountdown.mock.calls.length;

      expect(countdownCalls2).toBe(countdownCalls1);
    });

    it("processes PLAYER_INPUT direction", () => {
      engine = new SurroundEngine(canvas, channel, "light_trails", true, null);
      engine.start();

      const buf = encodePlayerInput(INPUT_KEY.UP, true);
      engine._handleMessage({ data: buf });

      expect(engine.p2PendingDir).toBe(DIR.UP);
    });

    it("ignores PLAYER_INPUT with invalid keyCode", () => {
      engine = new SurroundEngine(canvas, channel, "light_trails", true, null);
      engine.start();
      engine.p2PendingDir = DIR.LEFT;

      // Craft a binary input with keyCode=99
      const buf = new ArrayBuffer(3);
      const view = new DataView(buf);
      view.setUint8(0, MSG_TYPE.PLAYER_INPUT);
      view.setUint8(1, 99);
      view.setUint8(2, 1); // pressed=true
      engine._handleMessage({ data: buf });

      expect(engine.p2PendingDir).toBe(DIR.LEFT); // unchanged
    });

    it("ignores PLAYER_INPUT when pressed=false", () => {
      engine = new SurroundEngine(canvas, channel, "light_trails", true, null);
      engine.start();
      engine.p2PendingDir = DIR.LEFT;

      const buf = encodePlayerInput(INPUT_KEY.UP, false);
      engine._handleMessage({ data: buf });

      expect(engine.p2PendingDir).toBe(DIR.LEFT);
    });
  });

  describe("_handleMessage (peer)", () => {
    it("applies GAME_STATE from host", () => {
      engine = new SurroundEngine(canvas, channel, "light_trails", false, null);
      engine.start();

      const state = {
        ...createInitialState(0),
        score1: 2,
        score2: 1,
        phase: PHASE.PLAYING,
      };
      state.p1 = { x: 15, y: 20, dir: DIR.RIGHT };
      const buf = encodeGameState(state);
      engine._handleMessage({ data: buf });

      expect(engine.gameState.score1).toBe(2);
      expect(engine.gameState.score2).toBe(1);
      expect(engine.gameState.phase).toBe(PHASE.PLAYING);
    });

    it("processes GAME_END message (P2 wins)", () => {
      engine = new SurroundEngine(canvas, channel, "light_trails", false, null);
      engine.start();

      const buf = encodeGameEnd(1, 3, 2);
      engine._handleMessage({ data: buf });

      expect(engine.gameState.phase).toBe(PHASE.MATCH_OVER);
      expect(engine.gameState.score1).toBe(1);
      expect(engine.gameState.score2).toBe(3);
      expect(engine.audio.playMatchWin).toHaveBeenCalled();
    });

    it("processes GAME_END message (P1 wins — peer loses)", () => {
      engine = new SurroundEngine(canvas, channel, "light_trails", false, null);
      engine.start();

      const buf = encodeGameEnd(3, 1, 1);
      engine._handleMessage({ data: buf });

      expect(engine.gameState.phase).toBe(PHASE.MATCH_OVER);
      expect(engine.audio.playMatchLose).toHaveBeenCalled();
    });

    it("resets grid on COUNTDOWN phase transition", () => {
      engine = new SurroundEngine(canvas, channel, "light_trails", false, null);
      engine.start();
      engine.gameState.phase = PHASE.ROUND_OVER;

      // Send a state with COUNTDOWN phase
      const state = {
        ...createInitialState(1),
        score1: 1,
        score2: 0,
        phase: PHASE.COUNTDOWN,
        countdown: 3,
      };
      const buf = encodeGameState(state);
      engine._handleMessage({ data: buf });

      expect(engine.gameState.phase).toBe(PHASE.COUNTDOWN);
      expect(engine.gameState.round).toBe(1);
      expect(engine.audio.playCountdown).toHaveBeenCalled();
    });
  });

  describe("_handleMessage (non-ArrayBuffer)", () => {
    it("ignores non-ArrayBuffer data", () => {
      engine = new SurroundEngine(canvas, channel, "light_trails", true, null);
      engine.start();
      expect(() => {
        engine._handleMessage({ data: "not binary" });
      }).not.toThrow();
    });
  });

  describe("key handling", () => {
    it("maps ArrowUp to UP direction", () => {
      engine = new SurroundEngine(canvas, channel, "light_trails", true, null);
      engine.start();
      engine._handleKeyDown({ key: "ArrowUp", preventDefault: vi.fn() });
      expect(engine.p1PendingDir).toBe(DIR.UP);
    });

    it("maps ArrowDown to DOWN direction", () => {
      engine = new SurroundEngine(canvas, channel, "light_trails", true, null);
      engine.start();
      engine._handleKeyDown({ key: "ArrowDown", preventDefault: vi.fn() });
      expect(engine.p1PendingDir).toBe(DIR.DOWN);
    });

    it("maps ArrowLeft to LEFT direction", () => {
      engine = new SurroundEngine(canvas, channel, "light_trails", true, null);
      engine.start();
      engine._handleKeyDown({ key: "ArrowLeft", preventDefault: vi.fn() });
      expect(engine.p1PendingDir).toBe(DIR.LEFT);
    });

    it("maps w to UP direction", () => {
      engine = new SurroundEngine(canvas, channel, "light_trails", true, null);
      engine.start();
      engine._handleKeyDown({ key: "w", preventDefault: vi.fn() });
      expect(engine.p1PendingDir).toBe(DIR.UP);
    });

    it("maps d to RIGHT direction", () => {
      engine = new SurroundEngine(canvas, channel, "light_trails", true, null);
      engine.start();
      engine._handleKeyDown({ key: "d", preventDefault: vi.fn() });
      expect(engine.p1PendingDir).toBe(DIR.RIGHT);
    });

    it("ignores unmapped keys", () => {
      engine = new SurroundEngine(canvas, channel, "light_trails", true, null);
      engine.start();
      const origDir = engine.p1PendingDir;
      const e = { key: "x", preventDefault: vi.fn() };
      engine._handleKeyDown(e);
      expect(e.preventDefault).not.toHaveBeenCalled();
      expect(engine.p1PendingDir).toBe(origDir);
    });

    it("peer does not set p1PendingDir locally", () => {
      engine = new SurroundEngine(canvas, channel, "light_trails", false, null);
      engine.start();
      const origDir = engine.p1PendingDir;
      engine._handleKeyDown({ key: "ArrowUp", preventDefault: vi.fn() });
      expect(engine.p1PendingDir).toBe(origDir);
    });

    it("peer sends binary input on keydown", () => {
      engine = new SurroundEngine(canvas, channel, "light_trails", false, null);
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

    it("host does not send input over channel", () => {
      engine = new SurroundEngine(canvas, channel, "light_trails", true, null);
      engine.start();
      channel.send.mockClear();

      engine._handleKeyDown({ key: "ArrowUp", preventDefault: vi.fn() });
      expect(channel.send).not.toHaveBeenCalled();
    });

    it("plays move audio on direction change", () => {
      engine = new SurroundEngine(canvas, channel, "light_trails", true, null);
      engine.start();
      engine._handleKeyDown({ key: "ArrowUp", preventDefault: vi.fn() });
      expect(engine.audio.playMove).toHaveBeenCalled();
    });
  });

  describe("_handleBlur", () => {
    it("does not throw (no-op)", () => {
      engine = new SurroundEngine(canvas, channel, "light_trails", true, null);
      engine.start();
      expect(() => engine._handleBlur()).not.toThrow();
    });
  });

  describe("timer safety", () => {
    beforeEach(() => {
      vi.useFakeTimers();
    });

    afterEach(() => {
      vi.useRealTimers();
    });

    it("_startTickLoop clears existing interval before creating new one", () => {
      engine = new SurroundEngine(canvas, channel, "light_trails", true, null);
      engine.start();
      engine.gameState.phase = PHASE.PLAYING;

      engine._startTickLoop();
      const firstInterval = engine.tickInterval;
      expect(firstInterval).not.toBeNull();

      engine._startTickLoop();
      const secondInterval = engine.tickInterval;
      expect(secondInterval).not.toBeNull();
      expect(secondInterval).not.toBe(firstInterval);
    });

    it("_startCountdown clears existing phaseTimer", () => {
      engine = new SurroundEngine(canvas, channel, "light_trails", true, null);
      engine.start();
      engine._savedScores = { score1: 0, score2: 0 };

      engine._startCountdown(0);
      expect(engine.phaseTimer).not.toBeNull();

      // Calling again should not orphan the timer
      engine._startCountdown(1);
      expect(engine.gameState.round).toBe(1);
      expect(engine.gameState.phase).toBe(PHASE.COUNTDOWN);
    });
  });

  describe("_broadcastState", () => {
    it("sends 12-byte encoded state when channel is open", () => {
      engine = new SurroundEngine(canvas, channel, "light_trails", true, null);
      engine.start();
      channel.send.mockClear();

      engine._broadcastState();

      expect(channel.send).toHaveBeenCalledTimes(1);
      const buf = channel.send.mock.calls[0][0];
      expect(buf).toBeInstanceOf(ArrayBuffer);
      expect(buf.byteLength).toBe(12);
    });

    it("does not send when channel is closed", () => {
      engine = new SurroundEngine(canvas, channel, "light_trails", true, null);
      engine.start();
      channel.readyState = "closed";
      channel.send.mockClear();

      engine._broadcastState();

      expect(channel.send).not.toHaveBeenCalled();
    });
  });

  describe("_handleMatchOver (host)", () => {
    it("sends GAME_END to peer", () => {
      const onEnd = vi.fn();
      engine = new SurroundEngine(canvas, channel, "light_trails", true, onEnd);
      engine.start();
      engine.gameState.score1 = WINS_NEEDED;
      engine.gameState.score2 = 1;
      channel.send.mockClear();

      engine._handleMatchOver();

      const gameEndCall = channel.send.mock.calls.find((call) => {
        const view = new Uint8Array(call[0]);
        return view[0] === MSG_TYPE.GAME_END;
      });
      expect(gameEndCall).toBeDefined();
    });

    it("calls onGameEnd with correct winner", () => {
      const onEnd = vi.fn();
      engine = new SurroundEngine(canvas, channel, "light_trails", true, onEnd);
      engine.start();
      engine.gameState.score1 = WINS_NEEDED;
      engine.gameState.score2 = 1;

      engine._handleMatchOver();

      expect(onEnd).toHaveBeenCalledWith({
        score: { p1: WINS_NEEDED, p2: 1 },
        winner: 1,
      });
    });

    it("plays match win audio when P1 wins", () => {
      engine = new SurroundEngine(canvas, channel, "light_trails", true, null);
      engine.start();
      engine.gameState.score1 = WINS_NEEDED;
      engine.gameState.score2 = 1;

      engine._handleMatchOver();

      expect(engine.audio.playMatchWin).toHaveBeenCalled();
    });

    it("plays match lose audio when P2 wins", () => {
      engine = new SurroundEngine(canvas, channel, "light_trails", true, null);
      engine.start();
      engine.gameState.score1 = 1;
      engine.gameState.score2 = WINS_NEEDED;

      engine._handleMatchOver();

      expect(engine.audio.playMatchLose).toHaveBeenCalled();
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
      engine = new SurroundEngine(canvas, channel, "light_trails", true, null);
      engine.start();

      engine._handleMessage({ data: encodeGameReady() });

      expect(engine.gameState.phase).toBe(PHASE.COUNTDOWN);
      expect(engine.gameState.countdown).toBe(3);
      expect(engine.audio.playCountdown).toHaveBeenCalled();
    });

    it("counts down from 3 to 1", () => {
      engine = new SurroundEngine(canvas, channel, "light_trails", true, null);
      engine.start();
      engine._handleMessage({ data: encodeGameReady() });

      vi.advanceTimersByTime(1000);
      expect(engine.gameState.countdown).toBe(2);

      vi.advanceTimersByTime(1000);
      expect(engine.gameState.countdown).toBe(1);
    });

    it("transitions to PLAYING after countdown", () => {
      engine = new SurroundEngine(canvas, channel, "light_trails", true, null);
      engine.start();
      engine._handleMessage({ data: encodeGameReady() });

      vi.advanceTimersByTime(3000);

      expect(engine.gameState.phase).toBe(PHASE.PLAYING);
    });

    it("starts tick interval after countdown", () => {
      engine = new SurroundEngine(canvas, channel, "light_trails", true, null);
      engine.start();
      engine._handleMessage({ data: encodeGameReady() });

      vi.advanceTimersByTime(3000);

      expect(engine.tickInterval).not.toBeNull();
    });
  });

  describe("tick loop (host)", () => {
    it("moves players on each tick", () => {
      engine = new SurroundEngine(canvas, channel, "light_trails", true, null);
      engine.start();
      engine.gameState.phase = PHASE.PLAYING;

      const origP1X = engine.gameState.p1.x;
      engine._tickLoop();

      expect(engine.gameState.p1.x).toBe(origP1X + 1);
    });

    it("broadcasts state each tick", () => {
      engine = new SurroundEngine(canvas, channel, "light_trails", true, null);
      engine.start();
      engine.gameState.phase = PHASE.PLAYING;
      channel.send.mockClear();

      engine._tickLoop();

      expect(channel.send).toHaveBeenCalled();
    });

    it("transitions to ROUND_OVER on death", () => {
      engine = new SurroundEngine(canvas, channel, "light_trails", true, null);
      engine.start();
      engine.gameState.phase = PHASE.PLAYING;
      // Place P1 at left edge heading left → will die
      engine.gameState.p1.x = 0;
      engine.gameState.p1.dir = DIR.LEFT;
      engine.p1PendingDir = DIR.LEFT;

      engine._tickLoop();

      expect(engine.gameState.phase).toBe(PHASE.ROUND_OVER);
    });

    it("awards point to P2 when P1 dies", () => {
      engine = new SurroundEngine(canvas, channel, "light_trails", true, null);
      engine.start();
      engine.gameState.phase = PHASE.PLAYING;
      engine.gameState.score2 = 0;
      engine.gameState.p1.x = 0;
      engine.gameState.p1.dir = DIR.LEFT;
      engine.p1PendingDir = DIR.LEFT;

      engine._tickLoop();

      expect(engine.gameState.score2).toBe(1);
    });

    it("awards point to P1 when P2 dies", () => {
      engine = new SurroundEngine(canvas, channel, "light_trails", true, null);
      engine.start();
      engine.gameState.phase = PHASE.PLAYING;
      engine.gameState.score1 = 0;
      engine.gameState.p2.x = CANVAS_W; // Will be clamped to OOB
      engine.gameState.p2.dir = DIR.RIGHT;
      engine.p2PendingDir = DIR.RIGHT;
      // Place P2 at right edge
      engine.gameState.p2.x = 59; // GRID_W - 1
      engine.gameState.p2.dir = DIR.RIGHT;
      engine.p2PendingDir = DIR.RIGHT;

      engine._tickLoop();

      expect(engine.gameState.score1).toBe(1);
    });

    it("no points on mutual death (draw)", () => {
      engine = new SurroundEngine(canvas, channel, "light_trails", true, null);
      engine.start();
      engine.gameState.phase = PHASE.PLAYING;
      engine.gameState.score1 = 0;
      engine.gameState.score2 = 0;
      // Both at edges
      engine.gameState.p1.x = 0;
      engine.gameState.p1.dir = DIR.LEFT;
      engine.p1PendingDir = DIR.LEFT;
      engine.gameState.p2.x = 59;
      engine.gameState.p2.dir = DIR.RIGHT;
      engine.p2PendingDir = DIR.RIGHT;

      engine._tickLoop();

      expect(engine.gameState.score1).toBe(0);
      expect(engine.gameState.score2).toBe(0);
    });

    it("does nothing when not PLAYING", () => {
      engine = new SurroundEngine(canvas, channel, "light_trails", true, null);
      engine.start();
      engine.gameState.phase = PHASE.WAITING;
      channel.send.mockClear();

      engine._tickLoop();

      expect(channel.send).not.toHaveBeenCalled();
    });
  });
});
