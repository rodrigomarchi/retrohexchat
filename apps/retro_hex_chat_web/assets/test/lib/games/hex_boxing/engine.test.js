import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import {
  PHASE,
  MSG_TYPE,
  INPUT_KEY,
  encodeGameState,
  encodePlayerInput,
  encodeGameEnd,
  encodeGameReady,
} from "../../../../js/lib/games/hex_boxing/protocol.js";
import {
  createInitialState,
  ROUND_DURATION,
  KO_SCORE,
} from "../../../../js/lib/games/hex_boxing/physics.js";

// Must mock audio BEFORE importing engine
vi.mock("../../../../js/lib/games/hex_boxing/audio.js", () => ({
  BoxingAudio: function () {
    return {
      playCountdown: vi.fn(),
      playBellStart: vi.fn(),
      playBellEnd: vi.fn(),
      playPunchMiss: vi.fn(),
      playHit: vi.fn(),
      playHitClose: vi.fn(),
      playHitMedium: vi.fn(),
      playHitFar: vi.fn(),
      playKO: vi.fn(),
      playTimerTick: vi.fn(),
      playWin: vi.fn(),
      playLose: vi.fn(),
      destroy: vi.fn(),
    };
  },
}));

// Must mock renderer
vi.mock("../../../../js/lib/games/hex_boxing/renderer.js", () => ({
  render: vi.fn(),
  getColors: vi.fn(() => ({
    bg: "#0a0808",
    fg: "#39ff14",
    accent: "#00e5ff",
    muted: "#2a1a1a",
    glow: "rgba(57, 255, 20, 0.15)",
    warning: "#ff4444",
    rope: "#aaaaaa",
    ring: "#1a1208",
    hit: "#ffffff",
  })),
  createHitParticles: vi.fn(() => []),
  updateParticles: vi.fn(() => []),
}));

const { BoxingEngine } = await import("../../../../js/lib/games/hex_boxing/engine.js");
const { render, getColors, createHitParticles, updateParticles } =
  await import("../../../../js/lib/games/hex_boxing/renderer.js");

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
    lineCap: "butt",
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
    clearRect: vi.fn(),
  };
  canvas.getContext = vi.fn(() => mockCtx);

  return canvas;
}

/** Create engine and start it in FIGHTING phase for game loop tests. */
function setupFightingEngine(onGameEnd = vi.fn()) {
  const channel = createMockChannel();
  const canvas = createMockCanvas();
  const engine = new BoxingEngine(canvas, channel, "hex_boxing", true, onGameEnd);
  engine.start();
  engine.peerReady = true;
  engine.gameState.phase = PHASE.FIGHTING;
  engine.gameState.roundTimer = ROUND_DURATION;
  return { engine, channel, onGameEnd };
}

describe("BoxingEngine", () => {
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
    createHitParticles.mockClear();
    updateParticles.mockClear();
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
    it("creates engine with correct initial state", () => {
      engine = new BoxingEngine(canvas, channel, "hex_boxing", true, null);
      expect(engine.isHost).toBe(true);
      expect(engine.gameState.phase).toBe(PHASE.WAITING);
      expect(engine.gameState.score1).toBe(0);
      expect(engine.gameState.score2).toBe(0);
    });

    it("initializes localInputs and remoteInputs", () => {
      engine = new BoxingEngine(canvas, channel, "hex_boxing", true, null);
      expect(engine.localInputs).toEqual({
        up: false,
        down: false,
        left: false,
        right: false,
        punch: false,
      });
      expect(engine.remoteInputs).toEqual({
        up: false,
        down: false,
        left: false,
        right: false,
        punch: false,
      });
    });

    it("initializes punch edge-trigger flags to false", () => {
      engine = new BoxingEngine(canvas, channel, "hex_boxing", true, null);
      expect(engine._localPunchPressed).toBe(false);
      expect(engine._remotePunchPressed).toBe(false);
    });

    it("stores onGameEnd callback", () => {
      const cb = vi.fn();
      engine = new BoxingEngine(canvas, channel, "hex_boxing", true, cb);
      expect(engine.onGameEnd).toBe(cb);
    });

    it("sets peerReady to false", () => {
      engine = new BoxingEngine(canvas, channel, "hex_boxing", true, null);
      expect(engine.peerReady).toBe(false);
    });
  });

  // ── Start / Stop ──

  describe("start / stop", () => {
    it("host starts and renders initial state", () => {
      engine = new BoxingEngine(canvas, channel, "hex_boxing", true, null);
      engine.start();
      // Should not send GAME_READY (that's peer only)
      expect(channel.send).not.toHaveBeenCalled();
      expect(render).toHaveBeenCalled();
    });

    it("peer sends GAME_READY on start", () => {
      engine = new BoxingEngine(canvas, channel, "hex_boxing", false, null);
      engine.start();
      expect(channel.send).toHaveBeenCalledTimes(1);
      // Verify GAME_READY message type
      const sent = channel.send.mock.calls[0][0];
      expect(sent).toBeInstanceOf(ArrayBuffer);
      expect(new DataView(sent).getUint8(0)).toBe(MSG_TYPE.GAME_READY);
    });

    it("stop cleans up", () => {
      engine = new BoxingEngine(canvas, channel, "hex_boxing", true, null);
      engine.start();
      engine.stop();
      expect(engine.running).toBe(false);
    });

    it("stop is safe to call multiple times", () => {
      engine = new BoxingEngine(canvas, channel, "hex_boxing", true, null);
      engine.start();
      engine.stop();
      expect(() => engine.stop()).not.toThrow();
    });

    it("double-start is a no-op", () => {
      engine = new BoxingEngine(canvas, channel, "hex_boxing", true, null);
      engine.start();
      const firstState = engine.gameState;
      engine.start(); // should not reset
      expect(engine.gameState).toBe(firstState);
    });

    it("stop clears phaseTimer", () => {
      vi.useFakeTimers();
      engine = new BoxingEngine(canvas, channel, "hex_boxing", true, null);
      engine.start();
      engine.phaseTimer = setTimeout(() => {}, 5000);
      engine.stop();
      expect(engine.phaseTimer).toBeNull();
    });
  });

  // ── _mapKey ──

  describe("_mapKey", () => {
    it("maps arrow keys correctly", () => {
      engine = new BoxingEngine(canvas, channel, "hex_boxing", true, null);
      expect(engine._mapKey("ArrowUp")).toBe(INPUT_KEY.UP);
      expect(engine._mapKey("ArrowDown")).toBe(INPUT_KEY.DOWN);
      expect(engine._mapKey("ArrowLeft")).toBe(INPUT_KEY.LEFT);
      expect(engine._mapKey("ArrowRight")).toBe(INPUT_KEY.RIGHT);
      expect(engine._mapKey(" ")).toBe(INPUT_KEY.PUNCH);
      expect(engine._mapKey("Shift")).toBe(INPUT_KEY.PUNCH);
    });

    it("maps WASD keys correctly", () => {
      engine = new BoxingEngine(canvas, channel, "hex_boxing", true, null);
      expect(engine._mapKey("w")).toBe(INPUT_KEY.UP);
      expect(engine._mapKey("s")).toBe(INPUT_KEY.DOWN);
      expect(engine._mapKey("a")).toBe(INPUT_KEY.LEFT);
      expect(engine._mapKey("d")).toBe(INPUT_KEY.RIGHT);
    });

    it("maps uppercase WASD keys", () => {
      engine = new BoxingEngine(canvas, channel, "hex_boxing", true, null);
      expect(engine._mapKey("W")).toBe(INPUT_KEY.UP);
      expect(engine._mapKey("S")).toBe(INPUT_KEY.DOWN);
      expect(engine._mapKey("A")).toBe(INPUT_KEY.LEFT);
      expect(engine._mapKey("D")).toBe(INPUT_KEY.RIGHT);
    });

    it("returns null for unmapped keys", () => {
      engine = new BoxingEngine(canvas, channel, "hex_boxing", true, null);
      expect(engine._mapKey("q")).toBeNull();
      expect(engine._mapKey("z")).toBeNull();
      expect(engine._mapKey("Enter")).toBeNull();
    });
  });

  // ── _dirFromInputs ──

  describe("_dirFromInputs", () => {
    beforeEach(() => {
      engine = new BoxingEngine(canvas, channel, "hex_boxing", true, null);
    });

    it("computes cardinal directions", () => {
      expect(
        engine._dirFromInputs({ up: false, down: false, left: false, right: true, punch: false }),
      ).toBe(0); // right
      expect(
        engine._dirFromInputs({ up: false, down: true, left: false, right: false, punch: false }),
      ).toBe(2); // down
      expect(
        engine._dirFromInputs({ up: false, down: false, left: true, right: false, punch: false }),
      ).toBe(4); // left
      expect(
        engine._dirFromInputs({ up: true, down: false, left: false, right: false, punch: false }),
      ).toBe(6); // up
    });

    it("computes all diagonal directions", () => {
      // down-right
      expect(
        engine._dirFromInputs({ up: false, down: true, left: false, right: true, punch: false }),
      ).toBe(1);
      // down-left
      expect(
        engine._dirFromInputs({ up: false, down: true, left: true, right: false, punch: false }),
      ).toBe(3);
      // up-left
      expect(
        engine._dirFromInputs({ up: true, down: false, left: true, right: false, punch: false }),
      ).toBe(5);
      // up-right
      expect(
        engine._dirFromInputs({ up: true, down: false, left: false, right: true, punch: false }),
      ).toBe(7);
    });

    it("returns -1 when no direction pressed", () => {
      expect(
        engine._dirFromInputs({ up: false, down: false, left: false, right: false, punch: false }),
      ).toBe(-1);
    });

    it("handles opposing directions (cancel out)", () => {
      // Both left and right → cancels
      expect(
        engine._dirFromInputs({ up: false, down: false, left: true, right: true, punch: false }),
      ).toBe(-1);
      // Both up and down → cancels
      expect(
        engine._dirFromInputs({ up: true, down: true, left: false, right: false, punch: false }),
      ).toBe(-1);
    });
  });

  // ── _safeSend ──

  describe("_safeSend", () => {
    it("handles closed channel gracefully", () => {
      const closedChannel = { ...createMockChannel(), readyState: "closed" };
      engine = new BoxingEngine(canvas, closedChannel, "hex_boxing", true, null);
      engine._safeSend(new ArrayBuffer(10));
      expect(closedChannel.send).not.toHaveBeenCalled();
    });

    it("sends data on open channel", () => {
      engine = new BoxingEngine(canvas, channel, "hex_boxing", true, null);
      const buf = new ArrayBuffer(10);
      engine._safeSend(buf);
      expect(channel.send).toHaveBeenCalledWith(buf);
    });
  });

  // ── _handleBlur ──

  describe("_handleBlur", () => {
    it("resets all local inputs", () => {
      engine = new BoxingEngine(canvas, channel, "hex_boxing", true, null);
      engine.localInputs = { up: true, down: true, left: true, right: true, punch: true };
      engine._handleBlur();
      expect(engine.localInputs).toEqual({
        up: false,
        down: false,
        left: false,
        right: false,
        punch: false,
      });
    });

    it("peer sends key releases on blur", () => {
      engine = new BoxingEngine(canvas, channel, "hex_boxing", false, null);
      engine.localInputs = { up: true, down: true, left: true, right: true, punch: true };
      engine._handleBlur();
      // 5 key releases sent
      expect(channel.send).toHaveBeenCalledTimes(5);
    });

    it("host does not send key releases on blur", () => {
      engine = new BoxingEngine(canvas, channel, "hex_boxing", true, null);
      engine.localInputs = { up: true, down: true, left: true, right: true, punch: true };
      engine._handleBlur();
      expect(channel.send).not.toHaveBeenCalled();
    });
  });

  // ── _handleMessage — host receiving ──

  describe("_handleMessage — host receiving", () => {
    beforeEach(() => {
      engine = new BoxingEngine(canvas, channel, "hex_boxing", true, null);
      engine.start();
    });

    it("GAME_READY sets peerReady and starts countdown", () => {
      vi.useFakeTimers();
      expect(engine.peerReady).toBe(false);
      engine._handleMessage({ data: encodeGameReady() });
      expect(engine.peerReady).toBe(true);
      expect(engine.gameState.phase).toBe(PHASE.COUNTDOWN);
      expect(engine.gameState.countdown).toBe(3);
      expect(engine.audio.playCountdown).toHaveBeenCalled();
    });

    it("duplicate GAME_READY is a no-op", () => {
      vi.useFakeTimers();
      engine._handleMessage({ data: encodeGameReady() });
      engine.audio.playCountdown.mockClear();
      engine._handleMessage({ data: encodeGameReady() });
      // Should not restart countdown
      expect(engine.audio.playCountdown).not.toHaveBeenCalled();
    });

    it("PLAYER_INPUT applies remote input", () => {
      engine._handleMessage({
        data: encodePlayerInput(INPUT_KEY.UP, true),
      });
      expect(engine.remoteInputs.up).toBe(true);

      engine._handleMessage({
        data: encodePlayerInput(INPUT_KEY.PUNCH, true),
      });
      expect(engine.remoteInputs.punch).toBe(true);
    });

    it("ignores GAME_STATE on host", () => {
      const fakeState = createInitialState();
      fakeState.score1 = 99;
      engine._handleMessage({ data: encodeGameState(fakeState) });
      // Host should NOT apply peer state
      expect(engine.gameState.score1).toBe(0);
    });

    it("GAME_END is processed by host too (no role guard)", () => {
      engine._handleMessage({
        data: encodeGameEnd({
          score1: 50,
          score2: 60,
          winner: 2,
          roundWins1: 0,
          roundWins2: 2,
        }),
      });
      // GAME_END has no isHost guard — both roles process it
      expect(engine.gameState.phase).toBe(PHASE.MATCH_OVER);
    });

    it("rejects non-ArrayBuffer data", () => {
      // Should not throw
      engine._handleMessage({ data: "not a buffer" });
      engine._handleMessage({ data: null });
      expect(engine.gameState.phase).toBe(PHASE.WAITING);
    });
  });

  // ── _handleMessage — peer receiving ──

  describe("_handleMessage — peer receiving", () => {
    beforeEach(() => {
      engine = new BoxingEngine(canvas, channel, "hex_boxing", false, vi.fn());
      engine.start();
      render.mockClear();
    });

    it("GAME_STATE applies peer state and renders", () => {
      const state = createInitialState();
      state.score1 = 42;
      state.phase = PHASE.FIGHTING;
      state.round = 2;
      engine._handleMessage({ data: encodeGameState(state) });
      expect(engine.gameState.score1).toBe(42);
      expect(engine.gameState.phase).toBe(PHASE.FIGHTING);
      expect(engine.gameState.round).toBe(2);
      expect(render).toHaveBeenCalled();
    });

    it("GAME_END sets MATCH_OVER, plays win audio for P2 winner", () => {
      engine._handleMessage({
        data: encodeGameEnd({
          score1: 30,
          score2: 50,
          winner: 2,
          roundWins1: 0,
          roundWins2: 2,
        }),
      });
      expect(engine.gameState.phase).toBe(PHASE.MATCH_OVER);
      expect(engine.gameState.roundWins2).toBe(2);
      expect(engine.audio.playWin).toHaveBeenCalled();
      expect(engine.audio.playLose).not.toHaveBeenCalled();
    });

    it("GAME_END plays lose audio for P1 winner (peer is P2)", () => {
      engine._handleMessage({
        data: encodeGameEnd({
          score1: 50,
          score2: 30,
          winner: 1,
          roundWins1: 2,
          roundWins2: 0,
        }),
      });
      expect(engine.gameState.phase).toBe(PHASE.MATCH_OVER);
      expect(engine.audio.playLose).toHaveBeenCalled();
      expect(engine.audio.playWin).not.toHaveBeenCalled();
    });

    it("ignores PLAYER_INPUT on peer", () => {
      engine._handleMessage({
        data: encodePlayerInput(INPUT_KEY.UP, true),
      });
      // Peer should not apply remote inputs
      expect(engine.remoteInputs.up).toBe(false);
    });

    it("ignores GAME_READY on peer", () => {
      engine._handleMessage({ data: encodeGameReady() });
      // Peer should not start countdown
      expect(engine.gameState.phase).toBe(PHASE.WAITING);
    });
  });

  // ── _applyRemoteInput ──

  describe("_applyRemoteInput", () => {
    beforeEach(() => {
      engine = new BoxingEngine(canvas, channel, "hex_boxing", true, null);
    });

    it("sets all 5 remote input keys", () => {
      engine._applyRemoteInput({ keyCode: INPUT_KEY.UP, pressed: true });
      expect(engine.remoteInputs.up).toBe(true);

      engine._applyRemoteInput({ keyCode: INPUT_KEY.DOWN, pressed: true });
      expect(engine.remoteInputs.down).toBe(true);

      engine._applyRemoteInput({ keyCode: INPUT_KEY.LEFT, pressed: true });
      expect(engine.remoteInputs.left).toBe(true);

      engine._applyRemoteInput({ keyCode: INPUT_KEY.RIGHT, pressed: true });
      expect(engine.remoteInputs.right).toBe(true);

      engine._applyRemoteInput({ keyCode: INPUT_KEY.PUNCH, pressed: true });
      expect(engine.remoteInputs.punch).toBe(true);
    });

    it("release clears the input", () => {
      engine._applyRemoteInput({ keyCode: INPUT_KEY.UP, pressed: true });
      expect(engine.remoteInputs.up).toBe(true);
      engine._applyRemoteInput({ keyCode: INPUT_KEY.UP, pressed: false });
      expect(engine.remoteInputs.up).toBe(false);
    });

    it("ignores unknown keyCode gracefully", () => {
      engine._applyRemoteInput({ keyCode: 99, pressed: true });
      expect(engine.remoteInputs).toEqual({
        up: false,
        down: false,
        left: false,
        right: false,
        punch: false,
      });
    });
  });

  // ── _applyPeerState ──

  describe("_applyPeerState", () => {
    beforeEach(() => {
      engine = new BoxingEngine(canvas, channel, "hex_boxing", false, null);
      engine.start();
    });

    it("merges all decoded state fields", () => {
      const decoded = {
        b1x: 100,
        b1y: 200,
        b1dir: 3,
        b1punchState: 1,
        b1arm: 1,
        b1punchTimer: 5,
        b2x: 400,
        b2y: 300,
        b2dir: 7,
        b2punchState: 0,
        b2arm: 0,
        b2punchTimer: 0,
        score1: 15,
        score2: 20,
        phase: PHASE.FIGHTING,
        countdown: 0,
        round: 2,
        roundWins1: 1,
        roundWins2: 0,
        roundTimer: 3600,
        lastHitPlayer: 0,
        lastHitPoints: 0,
      };
      engine._applyPeerState(decoded);
      expect(engine.gameState.b1x).toBe(100);
      expect(engine.gameState.b2y).toBe(300);
      expect(engine.gameState.score1).toBe(15);
      expect(engine.gameState.score2).toBe(20);
      expect(engine.gameState.phase).toBe(PHASE.FIGHTING);
      expect(engine.gameState.round).toBe(2);
      expect(engine.gameState.roundTimer).toBe(3600);
    });

    it("triggers hit audio when lastHitPlayer !== 0", () => {
      const decoded = {
        ...createInitialState(),
        lastHitPlayer: 1,
        lastHitPoints: 3,
        phase: PHASE.FIGHTING,
      };
      engine._applyPeerState(decoded);
      expect(engine.audio.playHit).toHaveBeenCalledWith(3);
      expect(createHitParticles).toHaveBeenCalled();
    });

    it("does not trigger hit audio when lastHitPlayer is 0", () => {
      const decoded = {
        ...createInitialState(),
        lastHitPlayer: 0,
        lastHitPoints: 0,
        phase: PHASE.FIGHTING,
      };
      engine._applyPeerState(decoded);
      expect(engine.audio.playHit).not.toHaveBeenCalled();
    });

    it("calls _playPhaseAudio on phase transition", () => {
      engine.gameState.phase = PHASE.WAITING;
      const decoded = {
        ...createInitialState(),
        phase: PHASE.COUNTDOWN,
        lastHitPlayer: 0,
        lastHitPoints: 0,
      };
      engine._applyPeerState(decoded);
      expect(engine.audio.playCountdown).toHaveBeenCalled();
    });
  });

  // ── _playPhaseAudio ──

  describe("_playPhaseAudio", () => {
    beforeEach(() => {
      engine = new BoxingEngine(canvas, channel, "hex_boxing", true, null);
    });

    it("COUNTDOWN transition plays playCountdown", () => {
      engine._playPhaseAudio(PHASE.WAITING, PHASE.COUNTDOWN);
      expect(engine.audio.playCountdown).toHaveBeenCalled();
    });

    it("SPAWNING transition plays playBellStart", () => {
      engine._playPhaseAudio(PHASE.COUNTDOWN, PHASE.SPAWNING);
      expect(engine.audio.playBellStart).toHaveBeenCalled();
    });

    it("ROUND_OVER transition plays playBellEnd", () => {
      engine._playPhaseAudio(PHASE.FIGHTING, PHASE.ROUND_OVER);
      expect(engine.audio.playBellEnd).toHaveBeenCalled();
    });

    it("no-op when phase unchanged", () => {
      engine._playPhaseAudio(PHASE.FIGHTING, PHASE.FIGHTING);
      expect(engine.audio.playCountdown).not.toHaveBeenCalled();
      expect(engine.audio.playBellStart).not.toHaveBeenCalled();
      expect(engine.audio.playBellEnd).not.toHaveBeenCalled();
    });
  });

  // ── Countdown / Spawning phases ──

  describe("countdown and spawning phases", () => {
    it("_startCountdown sets phase to COUNTDOWN with count 3 and plays audio", () => {
      vi.useFakeTimers();
      engine = new BoxingEngine(canvas, channel, "hex_boxing", true, null);
      engine.start();
      engine._startCountdown();
      expect(engine.gameState.phase).toBe(PHASE.COUNTDOWN);
      expect(engine.gameState.countdown).toBe(3);
      expect(engine.audio.playCountdown).toHaveBeenCalled();
      // Also broadcasts state
      expect(channel.send).toHaveBeenCalled();
    });

    it("countdown ticks 3→2→1 then starts spawning", () => {
      vi.useFakeTimers();
      engine = new BoxingEngine(canvas, channel, "hex_boxing", true, null);
      engine.start();
      engine._startCountdown();
      expect(engine.gameState.countdown).toBe(3);

      vi.advanceTimersByTime(1000);
      expect(engine.gameState.countdown).toBe(2);

      vi.advanceTimersByTime(1000);
      expect(engine.gameState.countdown).toBe(1);

      vi.advanceTimersByTime(1000);
      expect(engine.gameState.phase).toBe(PHASE.SPAWNING);
      expect(engine.audio.playBellStart).toHaveBeenCalled();
    });

    it("_startSpawning transitions to FIGHTING after SPAWNING_DELAY", () => {
      vi.useFakeTimers();
      engine = new BoxingEngine(canvas, channel, "hex_boxing", true, null);
      engine.start();
      engine._startSpawning();
      expect(engine.gameState.phase).toBe(PHASE.SPAWNING);

      vi.advanceTimersByTime(1000); // SPAWNING_DELAY
      expect(engine.gameState.phase).toBe(PHASE.FIGHTING);
      expect(engine.gameState.roundTimer).toBe(ROUND_DURATION);
    });

    it("countdown stops if engine is stopped mid-countdown", () => {
      vi.useFakeTimers();
      engine = new BoxingEngine(canvas, channel, "hex_boxing", true, null);
      engine.start();
      engine._startCountdown();
      expect(engine.gameState.countdown).toBe(3);

      engine.stop();
      vi.advanceTimersByTime(3000);
      // Countdown should not have progressed further after stop
      expect(engine.gameState.phase).toBe(PHASE.COUNTDOWN);
    });
  });

  // ── Game loop — FIGHTING phase ──

  describe("game loop — FIGHTING phase", () => {
    it("clears event flags each frame", () => {
      const { engine: e } = setupFightingEngine();
      engine = e;
      engine.gameState.lastHitPlayer = 1;
      engine.gameState.lastHitPoints = 3;

      engine._gameLoop(0);

      expect(engine.gameState.lastHitPlayer).toBe(0);
      expect(engine.gameState.lastHitPoints).toBe(0);
    });

    it("moves boxers with localInputs (P1)", () => {
      const { engine: e } = setupFightingEngine();
      engine = e;
      const startX = engine.gameState.b1x;

      engine.localInputs.right = true;
      engine._gameLoop(0);

      expect(engine.gameState.b1x).toBeGreaterThan(startX);
    });

    it("moves boxers with remoteInputs (P2)", () => {
      const { engine: e } = setupFightingEngine();
      engine = e;
      const startX = engine.gameState.b2x;

      engine.remoteInputs.left = true;
      engine._gameLoop(0);

      expect(engine.gameState.b2x).toBeLessThan(startX);
    });

    it("no movement when no inputs pressed", () => {
      const { engine: e } = setupFightingEngine();
      engine = e;
      const startX1 = engine.gameState.b1x;
      const startX2 = engine.gameState.b2x;

      engine._gameLoop(0);

      expect(engine.gameState.b1x).toBe(startX1);
      expect(engine.gameState.b2x).toBe(startX2);
    });

    it("edge-triggered punch — local press triggers once, hold does not retrigger", () => {
      const { engine: e } = setupFightingEngine();
      engine = e;

      // First frame with punch pressed → triggers punch
      engine.localInputs.punch = true;
      engine._gameLoop(0);
      expect(engine._localPunchPressed).toBe(true);
      // b1 should be in a punch state (PUNCHING or COOLDOWN after hit check)
      // Second frame still holding → should NOT re-trigger (edge-triggered)
      // Reset punch state to IDLE to see if it re-triggers
      engine.gameState = {
        ...engine.gameState,
        b1punchState: 0,
        b1punchTimer: 0,
        b1cooldownTimer: 0,
      };
      engine._gameLoop(0);
      // Since _localPunchPressed is still true and localInputs.punch is still true,
      // the edge trigger should NOT fire again
      expect(engine.gameState.b1punchState).toBe(0); // stays IDLE
    });

    it("edge-triggered punch — remote press triggers once", () => {
      const { engine: e } = setupFightingEngine();
      engine = e;

      engine.remoteInputs.punch = true;
      engine._gameLoop(0);
      expect(engine._remotePunchPressed).toBe(true);

      // Release and re-press to trigger again
      engine.remoteInputs.punch = false;
      engine._gameLoop(0);
      expect(engine._remotePunchPressed).toBe(false);
    });

    it("round timer ticks down each frame", () => {
      const { engine: e } = setupFightingEngine();
      engine = e;
      const timerBefore = engine.gameState.roundTimer;

      engine._gameLoop(0);

      expect(engine.gameState.roundTimer).toBe(timerBefore - 1);
    });

    it("plays timer tick at last 15 seconds (roundTimer <= 900, every 60 frames)", () => {
      const { engine: e } = setupFightingEngine();
      engine = e;
      // Set roundTimer to 900 (15 seconds * 60fps) — after tick it becomes 899
      // We need roundTimer to be 901 so after tickRoundTimer it's 900 and 900 % 60 === 0
      engine.gameState.roundTimer = 901;

      engine._gameLoop(0);

      expect(engine.audio.playTimerTick).toHaveBeenCalled();
    });

    it("does not play timer tick when roundTimer > 900", () => {
      const { engine: e } = setupFightingEngine();
      engine = e;
      engine.gameState.roundTimer = 1000;

      engine._gameLoop(0);

      expect(engine.audio.playTimerTick).not.toHaveBeenCalled();
    });

    it("broadcasts state every 2 frames", () => {
      const { engine: e, channel: ch } = setupFightingEngine();
      engine = e;
      ch.send.mockClear();
      engine.frameCount = 0;

      // Frame 0 → frameCount becomes 1 after increment (1 % 2 !== 0) → no broadcast
      engine._gameLoop(0);
      expect(ch.send).not.toHaveBeenCalled();

      // Frame 1 → frameCount becomes 2 (2 % 2 === 0) → broadcast
      engine._gameLoop(0);
      expect(ch.send).toHaveBeenCalledTimes(1);
    });

    it("schedules next frame via requestAnimationFrame", () => {
      const { engine: e } = setupFightingEngine();
      engine = e;
      globalThis.requestAnimationFrame.mockClear();

      engine._gameLoop(0);

      expect(globalThis.requestAnimationFrame).toHaveBeenCalled();
    });

    it("does nothing when running is false", () => {
      const { engine: e } = setupFightingEngine();
      engine = e;
      engine.running = false;
      const timerBefore = engine.gameState.roundTimer;

      engine._gameLoop(0);

      expect(engine.gameState.roundTimer).toBe(timerBefore);
    });
  });

  // ── Round end and match over ──

  describe("round end and match over", () => {
    it("round end with timer expired advances round", () => {
      vi.useFakeTimers();
      const { engine: e } = setupFightingEngine();
      engine = e;
      engine.gameState.roundTimer = 1; // Will reach 0 after tick
      engine.gameState.score1 = 10;
      engine.gameState.score2 = 5;

      engine._gameLoop(0);

      // P1 wins the round (higher score), round advances
      expect(engine.gameState.roundWins1).toBe(1);
      expect(engine.gameState.phase).toBe(PHASE.ROUND_OVER);
      expect(engine.audio.playBellEnd).toHaveBeenCalled();
    });

    it("KO triggers playKO audio", () => {
      vi.useFakeTimers();
      const { engine: e } = setupFightingEngine();
      engine = e;
      engine.gameState.score1 = KO_SCORE; // KO!
      engine.gameState.roundTimer = 1;

      engine._gameLoop(0);

      expect(engine.audio.playKO).toHaveBeenCalled();
    });

    it("match over when a player reaches ROUNDS_TO_WIN", () => {
      vi.useFakeTimers();
      const onEnd = vi.fn();
      const { engine: e } = setupFightingEngine(onEnd);
      engine = e;
      engine.gameState.roundWins1 = 1; // already won 1 round
      engine.gameState.roundTimer = 1;
      engine.gameState.score1 = 10;
      engine.gameState.score2 = 5;

      engine._gameLoop(0);

      expect(engine.gameState.phase).toBe(PHASE.MATCH_OVER);
      expect(engine.audio.playWin).toHaveBeenCalled();
      expect(onEnd).toHaveBeenCalledWith(expect.objectContaining({ winner: 1 }));
    });

    it("after round over, starts new round countdown after delay", () => {
      vi.useFakeTimers();
      const { engine: e } = setupFightingEngine();
      engine = e;
      engine.gameState.roundTimer = 1;
      engine.gameState.score1 = 10;
      engine.gameState.score2 = 5;

      engine._gameLoop(0);
      expect(engine.gameState.phase).toBe(PHASE.ROUND_OVER);

      // After ROUND_OVER_DELAY (2500ms), should reset and start countdown
      vi.advanceTimersByTime(2500);
      expect(engine.gameState.phase).toBe(PHASE.COUNTDOWN);
    });
  });

  // ── _handleMatchOver ──

  describe("_handleMatchOver", () => {
    it("P1 winner plays win audio and sends GAME_END", () => {
      engine = new BoxingEngine(canvas, channel, "hex_boxing", true, vi.fn());
      engine.start();
      engine.gameState.phase = PHASE.MATCH_OVER;
      engine.gameState.roundWins1 = 2;
      engine.gameState.roundWins2 = 1;
      channel.send.mockClear();

      engine._handleMatchOver();

      expect(engine.audio.playWin).toHaveBeenCalled();
      expect(engine.audio.playLose).not.toHaveBeenCalled();
      // GAME_END sent to peer
      const gameEndCalls = channel.send.mock.calls.filter((call) => {
        const buf = call[0];
        return buf instanceof ArrayBuffer && new DataView(buf).getUint8(0) === MSG_TYPE.GAME_END;
      });
      expect(gameEndCalls.length).toBe(1);
    });

    it("P2 winner plays lose audio for host", () => {
      engine = new BoxingEngine(canvas, channel, "hex_boxing", true, vi.fn());
      engine.start();
      engine.gameState.phase = PHASE.MATCH_OVER;
      engine.gameState.roundWins1 = 0;
      engine.gameState.roundWins2 = 2;

      engine._handleMatchOver();

      expect(engine.audio.playLose).toHaveBeenCalled();
      expect(engine.audio.playWin).not.toHaveBeenCalled();
    });

    it("calls onGameEnd with score and winner", () => {
      const onEnd = vi.fn();
      engine = new BoxingEngine(canvas, channel, "hex_boxing", true, onEnd);
      engine.start();
      engine.gameState.phase = PHASE.MATCH_OVER;
      engine.gameState.roundWins1 = 2;
      engine.gameState.roundWins2 = 1;

      engine._handleMatchOver();

      expect(onEnd).toHaveBeenCalledWith({
        score: { p1: 2, p2: 1 },
        winner: 1,
      });
    });

    it("does not throw when onGameEnd is null", () => {
      engine = new BoxingEngine(canvas, channel, "hex_boxing", true, null);
      engine.start();
      engine.gameState.phase = PHASE.MATCH_OVER;
      engine.gameState.roundWins1 = 2;
      engine.gameState.roundWins2 = 0;

      expect(() => engine._handleMatchOver()).not.toThrow();
    });
  });

  // ── Connection Resilience ──

  describe("connection resilience", () => {
    it("channel close ends game with disconnect flag", () => {
      const onEnd = vi.fn();
      engine = new BoxingEngine(canvas, channel, "hex_boxing", true, onEnd);
      engine.start();
      engine.gameState.phase = PHASE.FIGHTING;
      engine._handleChannelClose();
      expect(engine.gameState.phase).toBe(PHASE.MATCH_OVER);
      expect(onEnd).toHaveBeenCalledWith(expect.objectContaining({ disconnected: true }));
    });

    it("channel close is no-op when game already finished", () => {
      const onEnd = vi.fn();
      engine = new BoxingEngine(canvas, channel, "hex_boxing", true, onEnd);
      engine.start();
      engine.gameState.phase = PHASE.MATCH_OVER;
      engine._handleChannelClose();
      expect(onEnd).not.toHaveBeenCalled();
    });

    it("channel close during WAITING phase still triggers disconnect", () => {
      const onEnd = vi.fn();
      engine = new BoxingEngine(canvas, channel, "hex_boxing", true, onEnd);
      engine.start();
      engine.gameState.phase = PHASE.WAITING;
      engine._handleChannelClose();
      expect(engine.gameState.phase).toBe(PHASE.MATCH_OVER);
      expect(onEnd).toHaveBeenCalledWith(
        expect.objectContaining({ disconnected: true, winner: 0 }),
      );
    });

    it("channel close swallows callback error", () => {
      const badCallback = vi.fn(() => {
        throw new Error("callback boom");
      });
      engine = new BoxingEngine(canvas, channel, "hex_boxing", true, badCallback);
      engine.start();
      engine.gameState.phase = PHASE.FIGHTING;
      expect(() => engine._handleChannelClose()).not.toThrow();
    });
  });

  // ── _handleKeyDown / _handleKeyUp ──

  describe("_handleKeyDown / _handleKeyUp", () => {
    it("host keydown sets local input", () => {
      engine = new BoxingEngine(canvas, channel, "hex_boxing", true, null);
      engine.start();
      engine._handleKeyDown({ key: "ArrowRight", preventDefault: vi.fn() });
      expect(engine.localInputs.right).toBe(true);
      // Host does NOT send input to channel
      expect(channel.send).not.toHaveBeenCalled();
    });

    it("peer keydown sets local input AND sends to channel", () => {
      engine = new BoxingEngine(canvas, channel, "hex_boxing", false, null);
      engine.start();
      channel.send.mockClear();
      engine._handleKeyDown({ key: "ArrowUp", preventDefault: vi.fn() });
      expect(engine.localInputs.up).toBe(true);
      expect(channel.send).toHaveBeenCalledTimes(1);
    });

    it("keyup clears local input", () => {
      engine = new BoxingEngine(canvas, channel, "hex_boxing", true, null);
      engine.start();
      engine._handleKeyDown({ key: "ArrowLeft", preventDefault: vi.fn() });
      expect(engine.localInputs.left).toBe(true);
      engine._handleKeyUp({ key: "ArrowLeft" });
      expect(engine.localInputs.left).toBe(false);
    });

    it("unmapped keys are ignored", () => {
      engine = new BoxingEngine(canvas, channel, "hex_boxing", true, null);
      engine.start();
      const preventDefault = vi.fn();
      engine._handleKeyDown({ key: "q", preventDefault });
      expect(preventDefault).not.toHaveBeenCalled();
    });

    it("peer keyup sends release to channel", () => {
      engine = new BoxingEngine(canvas, channel, "hex_boxing", false, null);
      engine.start();
      channel.send.mockClear();
      engine._handleKeyDown({ key: "d", preventDefault: vi.fn() });
      channel.send.mockClear();
      engine._handleKeyUp({ key: "d" });
      expect(channel.send).toHaveBeenCalledTimes(1);
      const sent = channel.send.mock.calls[0][0];
      expect(new DataView(sent).getUint8(0)).toBe(MSG_TYPE.PLAYER_INPUT);
      // pressed = false (release)
      expect(new DataView(sent).getUint8(2)).toBe(0);
    });
  });
});
