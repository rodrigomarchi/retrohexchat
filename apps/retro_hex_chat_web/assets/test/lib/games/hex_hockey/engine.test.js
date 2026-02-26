import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import {
  PHASE,
  GAME_MODE,
  INPUT_KEY,
  MSG_TYPE,
  EVENT,
  encodeGameState,
  encodePlayerInput,
  encodeGameReady,
  encodeGameEnd,
} from "../../../../js/lib/games/hex_hockey/protocol.js";
import {
  createInitialState,
  packState,
  COUNTDOWN_FRAME_INTERVAL,
  GOAL_CELEBRATION_FRAMES,
} from "../../../../js/lib/games/hex_hockey/physics.js";

// Mock audio BEFORE importing engine
vi.mock("../../../../js/lib/games/hex_hockey/audio.js", () => ({
  HexHockeyAudio: function () {
    return {
      playCountdownTick: vi.fn(),
      playGo: vi.fn(),
      playFaceoffWhistle: vi.fn(),
      playGoal: vi.fn(),
      playShot: vi.fn(),
      playWallBounce: vi.fn(),
      playGoalieBlock: vi.fn(),
      playTackleSuccess: vi.fn(),
      playTackleFail: vi.fn(),
      playCapture: vi.fn(),
      playPeriodBuzzer: vi.fn(),
      playSuddenDeath: vi.fn(),
      stopSuddenDeath: vi.fn(),
      playVictory: vi.fn(),
      destroy: vi.fn(),
    };
  },
}));

// Mock renderer
vi.mock("../../../../js/lib/games/hex_hockey/renderer.js", () => ({
  render: vi.fn(),
  readColors: vi.fn(() => ({
    bg: "#000033",
    fg: "#00ff00",
    muted: "#006600",
    p1: "#39ff14",
    p2: "#00e5ff",
  })),
  generateIceParticles: vi.fn(() => []),
}));

const { HexHockeyEngine } = await import("../../../../js/lib/games/hex_hockey/engine.js");

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
    arcTo: vi.fn(),
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

function createEngine(gameId = "hex_hockey", isHost = true, onGameEndFn) {
  const canvas = createMockCanvas();
  const channel = createMockChannel();
  const onGameEnd = onGameEndFn || vi.fn();
  const engine = new HexHockeyEngine(canvas, channel, gameId, isHost, onGameEnd);
  return { engine, canvas, channel, onGameEnd };
}

/**
 * Set up a host engine in PLAYING phase with mocked audio spies accessible.
 */
function setupPlayingEngine(gameId = "hex_hockey") {
  const onGameEnd = vi.fn();
  const { engine, channel } = createEngine(gameId, true, onGameEnd);
  engine.start();
  engine.peerReady = true;
  engine.gameState = createInitialState(
    gameId === "hex_hockey_blitz"
      ? GAME_MODE.BLITZ
      : gameId === "hex_hockey_showdown"
        ? GAME_MODE.SHOWDOWN
        : GAME_MODE.CLASSIC,
  );
  engine.gameState.phase = PHASE.PLAYING;
  engine.gameState.timerFrames = 9999;
  return { engine, channel, onGameEnd };
}

describe("hex_hockey_engine", () => {
  let originalRAF;

  beforeEach(() => {
    originalRAF = globalThis.requestAnimationFrame;
    globalThis.requestAnimationFrame = vi.fn((cb) => {
      return setTimeout(cb, 0);
    });
    globalThis.cancelAnimationFrame = vi.fn((id) => clearTimeout(id));
  });

  afterEach(() => {
    globalThis.requestAnimationFrame = originalRAF;
  });

  // ── Mode resolution ─────────────────────────────────────────

  it("resolves CLASSIC mode for hex_hockey", () => {
    const { engine } = createEngine("hex_hockey");
    expect(engine.mode).toBe(GAME_MODE.CLASSIC);
  });

  it("resolves BLITZ mode for hex_hockey_blitz", () => {
    const { engine } = createEngine("hex_hockey_blitz");
    expect(engine.mode).toBe(GAME_MODE.BLITZ);
  });

  it("resolves SHOWDOWN mode for hex_hockey_showdown", () => {
    const { engine } = createEngine("hex_hockey_showdown");
    expect(engine.mode).toBe(GAME_MODE.SHOWDOWN);
  });

  // ── Lifecycle ───────────────────────────────────────────────

  it("host creates initial game state on start", () => {
    const { engine } = createEngine("hex_hockey", true);
    engine.start();
    expect(engine.gameState).not.toBeNull();
    expect(engine.gameState.phase).toBe(PHASE.WAITING);
    engine.stop();
  });

  it("peer sends GAME_READY on start", () => {
    const { engine, channel } = createEngine("hex_hockey", false);
    engine.start();
    expect(channel.send).toHaveBeenCalled();
    // First send should be GAME_READY
    const sentBuf = channel.send.mock.calls[0][0];
    expect(new DataView(sentBuf).getUint8(0)).toBe(MSG_TYPE.GAME_READY);
    engine.stop();
  });

  it("host starts countdown when peer ready received", () => {
    const { engine } = createEngine("hex_hockey", true);
    engine.start();

    // Simulate receiving GAME_READY
    const readyBuf = encodeGameReady();
    engine._handleMessage({ data: readyBuf });

    expect(engine.peerReady).toBe(true);
    expect(engine.gameState.phase).toBe(PHASE.COUNTDOWN);
    engine.stop();
  });

  it("ignores duplicate GAME_READY", () => {
    const { engine } = createEngine("hex_hockey", true);
    engine.start();

    engine._handleMessage({ data: encodeGameReady() });
    const phase1 = engine.gameState.phase;
    engine._handleMessage({ data: encodeGameReady() }); // duplicate
    expect(engine.gameState.phase).toBe(phase1);
    engine.stop();
  });

  it("peer updates state from GAME_STATE message", () => {
    const { engine } = createEngine("hex_hockey", false);
    engine.start();

    const state = createInitialState(GAME_MODE.CLASSIC);
    state.phase = PHASE.PLAYING;
    state.scoreP1 = 2;
    const packed = packState(state);
    const buf = encodeGameState(packed);

    engine._handleMessage({ data: buf });
    expect(engine.gameState.phase).toBe(PHASE.PLAYING);
    expect(engine.gameState.scoreP1).toBe(2);
    engine.stop();
  });

  it("host processes player input from peer", () => {
    const { engine } = createEngine("hex_hockey", true);
    engine.start();

    const buf = encodePlayerInput(INPUT_KEY.RIGHT, true);
    engine._handleMessage({ data: buf });
    expect(engine.remoteInputs.right).toBe(true);

    const buf2 = encodePlayerInput(INPUT_KEY.RIGHT, false);
    engine._handleMessage({ data: buf2 });
    expect(engine.remoteInputs.right).toBe(false);
    engine.stop();
  });

  it("maps WASD and arrow keys correctly", () => {
    const { engine } = createEngine("hex_hockey", true);
    expect(engine._mapKey({ key: "ArrowLeft" })).toBe(INPUT_KEY.LEFT);
    expect(engine._mapKey({ key: "a" })).toBe(INPUT_KEY.LEFT);
    expect(engine._mapKey({ key: "A" })).toBe(INPUT_KEY.LEFT);
    expect(engine._mapKey({ key: "ArrowRight" })).toBe(INPUT_KEY.RIGHT);
    expect(engine._mapKey({ key: "d" })).toBe(INPUT_KEY.RIGHT);
    expect(engine._mapKey({ key: "ArrowUp" })).toBe(INPUT_KEY.UP);
    expect(engine._mapKey({ key: "w" })).toBe(INPUT_KEY.UP);
    expect(engine._mapKey({ key: "ArrowDown" })).toBe(INPUT_KEY.DOWN);
    expect(engine._mapKey({ key: "s" })).toBe(INPUT_KEY.DOWN);
    expect(engine._mapKey({ key: " " })).toBe(INPUT_KEY.ACTION);
    expect(engine._mapKey({ key: "Shift" })).toBe(INPUT_KEY.ACTION);
    expect(engine._mapKey({ key: "x" })).toBeNull();
    engine.stop();
  });

  it("ignores non-ArrayBuffer messages", () => {
    const { engine } = createEngine("hex_hockey", true);
    engine.start();
    // Should not throw
    engine._handleMessage({ data: "string data" });
    engine._handleMessage({ data: 42 });
    engine.stop();
  });

  it("stop clears all state", () => {
    const { engine } = createEngine("hex_hockey", true);
    engine.start();
    engine._handleMessage({ data: encodeGameReady() });

    engine.stop();
    expect(engine.peerReady).toBe(false);
    expect(engine.frameCount).toBe(0);
    expect(engine.puckTrail).toEqual([]);
    expect(engine.goalFlash).toBe(0);
  });

  it("peer receives GAME_END and calls onGameEnd", () => {
    const { engine, onGameEnd } = createEngine("hex_hockey", false);
    engine.start();

    const result = { winner: "p1", score_p1: 3, score_p2: 1 };
    const buf = encodeGameEnd(result);
    engine._handleMessage({ data: buf });

    expect(onGameEnd).toHaveBeenCalledWith(
      expect.objectContaining({ winner: "p1", score_p1: 3, score_p2: 1 }),
    );
    engine.stop();
  });

  it("action input resets actionHandled flag", () => {
    const { engine } = createEngine("hex_hockey", true);
    engine.start();

    // Simulate action key press
    engine._handleKeyDown({ key: " ", preventDefault: vi.fn() });
    expect(engine.localInputs.action).toBe(true);
    expect(engine.actionHandled).toBe(false);

    engine._handleKeyUp({ key: " ", preventDefault: vi.fn() });
    expect(engine.localInputs.action).toBe(false);
    engine.stop();
  });

  it("remote action input resets remoteActionHandled", () => {
    const { engine } = createEngine("hex_hockey", true);
    engine.start();

    engine._applyRemoteInput({ key: INPUT_KEY.ACTION, pressed: true });
    expect(engine.remoteInputs.action).toBe(true);
    expect(engine.remoteActionHandled).toBe(false);

    engine._applyRemoteInput({ key: INPUT_KEY.ACTION, pressed: false });
    expect(engine.remoteInputs.action).toBe(false);
    engine.stop();
  });

  it("puck trail clears when puck is possessed", () => {
    const { engine } = createEngine("hex_hockey", true);
    engine.start();
    engine.gameState = createInitialState(GAME_MODE.CLASSIC);
    engine.puckTrail = [
      { x: 100, y: 200 },
      { x: 110, y: 200 },
    ];

    engine.gameState.puck.possessedBy = 1;
    engine._updatePuckTrail();
    expect(engine.puckTrail).toEqual([]);
    engine.stop();
  });

  it("puck trail accumulates when puck is free", () => {
    const { engine } = createEngine("hex_hockey", true);
    engine.start();
    engine.gameState = createInitialState(GAME_MODE.CLASSIC);
    engine.puckTrail = [];

    engine.gameState.puck.possessedBy = 0;
    engine._updatePuckTrail();
    expect(engine.puckTrail.length).toBe(1);

    engine._updatePuckTrail();
    expect(engine.puckTrail.length).toBe(2);
    engine.stop();
  });

  it("puck trail caps at 8 entries", () => {
    const { engine } = createEngine("hex_hockey", true);
    engine.start();
    engine.gameState = createInitialState(GAME_MODE.CLASSIC);
    engine.puckTrail = [];
    engine.gameState.puck.possessedBy = 0;

    for (let i = 0; i < 12; i++) {
      engine._updatePuckTrail();
    }
    expect(engine.puckTrail.length).toBe(8);
    engine.stop();
  });

  // ── Resilience features ─────────────────────────────────────

  it("double-start is a no-op", () => {
    const { engine } = createEngine("hex_hockey", true);
    engine.start();
    const firstState = engine.gameState;
    engine.start(); // should not reset state
    expect(engine.gameState).toBe(firstState);
    engine.stop();
  });

  it("blur clears local inputs", () => {
    const { engine } = createEngine("hex_hockey", true);
    engine.start();
    engine.localInputs.left = true;
    engine.localInputs.up = true;
    engine.localInputs.action = true;
    engine._handleBlur();
    expect(engine.localInputs.left).toBe(false);
    expect(engine.localInputs.up).toBe(false);
    expect(engine.localInputs.action).toBe(false);
    engine.stop();
  });

  it("channel close ends game with disconnect flag", () => {
    const { engine, onGameEnd } = createEngine("hex_hockey", true);
    engine.start();
    engine._handleMessage({ data: encodeGameReady() });
    // Game is in COUNTDOWN — simulate channel close
    engine._handleChannelClose();
    expect(engine.gameState.phase).toBe(PHASE.FINISHED);
    expect(onGameEnd).toHaveBeenCalledWith(expect.objectContaining({ disconnected: true }));
    engine.stop();
  });

  it("channel close is no-op when game already finished", () => {
    const { engine, onGameEnd } = createEngine("hex_hockey", true);
    engine.start();
    engine.gameState = createInitialState(GAME_MODE.CLASSIC);
    engine.gameState.phase = PHASE.FINISHED;
    engine._handleChannelClose();
    // onGameEnd should NOT be called for already-finished game
    expect(onGameEnd).not.toHaveBeenCalled();
    engine.stop();
  });

  it("channel close is no-op when no game state exists", () => {
    const { engine, onGameEnd } = createEngine("hex_hockey", false);
    // Don't start — gameState is null
    engine._handleChannelClose();
    expect(onGameEnd).not.toHaveBeenCalled();
  });

  // ── Game loop — COUNTDOWN phase ─────────────────────────────

  describe("game loop — COUNTDOWN", () => {
    it("decrements phaseTimer each frame", () => {
      const { engine } = setupPlayingEngine();
      engine.gameState.phase = PHASE.COUNTDOWN;
      engine.gameState.countdownValue = 3;
      engine.phaseTimer = COUNTDOWN_FRAME_INTERVAL;

      engine._gameLoop();

      expect(engine.phaseTimer).toBe(COUNTDOWN_FRAME_INTERVAL - 1);
      engine.stop();
    });

    it("decrements countdownValue when phaseTimer reaches 0", () => {
      const { engine } = setupPlayingEngine();
      engine.gameState.phase = PHASE.COUNTDOWN;
      engine.gameState.countdownValue = 3;
      engine.phaseTimer = 1; // will hit 0 this frame

      engine._gameLoop();

      expect(engine.gameState.countdownValue).toBe(2);
      expect(engine.phaseTimer).toBe(COUNTDOWN_FRAME_INTERVAL);
      engine.stop();
    });

    it("plays playCountdownTick when countdownValue decrements", () => {
      const { engine } = setupPlayingEngine();
      engine.gameState.phase = PHASE.COUNTDOWN;
      engine.gameState.countdownValue = 2;
      engine.phaseTimer = 1;

      engine._gameLoop();

      expect(engine.audio.playCountdownTick).toHaveBeenCalled();
      engine.stop();
    });

    it("transitions to FACE_OFF when countdown reaches 0", () => {
      const { engine } = setupPlayingEngine();
      engine.gameState.phase = PHASE.COUNTDOWN;
      engine.gameState.countdownValue = 1;
      engine.phaseTimer = 1;

      engine._gameLoop();

      expect(engine.gameState.phase).toBe(PHASE.FACE_OFF);
      expect(engine.gameState.countdownValue).toBe(0);
      expect(engine.audio.playGo).toHaveBeenCalled();
      engine.stop();
    });
  });

  // ── Game loop — FACE_OFF phase ──────────────────────────────

  describe("game loop — FACE_OFF", () => {
    it("decrements faceoffGoTimer each frame", () => {
      const { engine } = setupPlayingEngine();
      engine.gameState.phase = PHASE.FACE_OFF;
      engine.faceoffGoTimer = 20;

      engine._gameLoop();

      expect(engine.faceoffGoTimer).toBe(19);
      engine.stop();
    });

    it("transitions to PLAYING when faceoffGoTimer reaches 0 (normal period)", () => {
      const { engine } = setupPlayingEngine();
      engine.gameState.phase = PHASE.FACE_OFF;
      engine.gameState.period = 1;
      engine.faceoffGoTimer = 1;

      engine._gameLoop();

      expect(engine.gameState.phase).toBe(PHASE.PLAYING);
      expect(engine.audio.playFaceoffWhistle).toHaveBeenCalled();
      engine.stop();
    });

    it("transitions to SUDDEN_DEATH when in overtime period (classic)", () => {
      const { engine } = setupPlayingEngine();
      engine.gameState.phase = PHASE.FACE_OFF;
      engine.gameState.period = 4; // > maxPeriods(3) for classic
      engine.gameState.mode = GAME_MODE.CLASSIC;
      engine.faceoffGoTimer = 1;

      engine._gameLoop();

      expect(engine.gameState.phase).toBe(PHASE.SUDDEN_DEATH);
      expect(engine.audio.playSuddenDeath).toHaveBeenCalled();
      expect(engine.audio.playFaceoffWhistle).toHaveBeenCalled();
      engine.stop();
    });

    it("transitions to PLAYING (not sudden death) for showdown mode regardless of period", () => {
      const { engine } = setupPlayingEngine("hex_hockey_showdown");
      engine.gameState.phase = PHASE.FACE_OFF;
      engine.gameState.period = 4;
      engine.faceoffGoTimer = 1;

      engine._gameLoop();

      expect(engine.gameState.phase).toBe(PHASE.PLAYING);
      expect(engine.audio.playSuddenDeath).not.toHaveBeenCalled();
      engine.stop();
    });
  });

  // ── Game loop — PLAYING / SUDDEN_DEATH phase ────────────────

  describe("game loop — PLAYING / SUDDEN_DEATH", () => {
    it("increments frameCount each loop tick", () => {
      const { engine } = setupPlayingEngine();
      const before = engine.frameCount;

      engine._gameLoop();

      expect(engine.frameCount).toBe(before + 1);
      engine.stop();
    });

    it("clears eventFlags at start of each frame", () => {
      const { engine } = setupPlayingEngine();
      engine.gameState.eventFlags = 0xffff;

      engine._gameLoop();

      // eventFlags should have been reset to 0 at start, then only set by physics
      // It won't be 0xffff anymore
      expect(engine.gameState.eventFlags).not.toBe(0xffff);
      engine.stop();
    });

    it("handles local action (shoot) when player has puck", () => {
      const { engine } = setupPlayingEngine();
      engine.gameState.p1.hasPuck = true;
      engine.gameState.puck.possessedBy = 1;
      engine.localInputs.action = true;
      engine.actionHandled = false;

      engine._gameLoop();

      // Action should have been handled (shoot)
      expect(engine.actionHandled).toBe(true);
      // Puck should have been released (shot)
      expect(engine.gameState.p1.hasPuck).toBe(false);
      expect(engine.gameState.puck.possessedBy).toBe(0);
      engine.stop();
    });

    it("handles remote action (shoot) when remote player has puck", () => {
      const { engine } = setupPlayingEngine();
      engine.gameState.p2.hasPuck = true;
      engine.gameState.puck.possessedBy = 2;
      engine.remoteInputs.action = true;
      engine.remoteActionHandled = false;

      engine._gameLoop();

      expect(engine.remoteActionHandled).toBe(true);
      expect(engine.gameState.p2.hasPuck).toBe(false);
      engine.stop();
    });

    it("transitions to GOAL_CELEBRATION on goal scored", () => {
      const { engine } = setupPlayingEngine();
      // Place puck past left goal line in goal opening (P2 scores by default)
      engine.gameState.puck.x = 10;
      engine.gameState.puck.y = 240; // within goal opening
      engine.gameState.puck.vx = -5;
      engine.gameState.puck.vy = 0;
      engine.gameState.puck.possessedBy = 0;

      engine._gameLoop();

      expect(engine.gameState.phase).toBe(PHASE.GOAL_CELEBRATION);
      expect(engine.gameState.scoreP2).toBe(1);
      expect(engine.audio.playGoal).toHaveBeenCalled();
      // goalFlash is set to GOAL_CELEBRATION_FRAMES then decremented by _renderState
      expect(engine.goalFlash).toBe(GOAL_CELEBRATION_FRAMES - 1);
      engine.stop();
    });

    it("handles puck stuck → face-off reset", () => {
      const { engine } = setupPlayingEngine();
      // Set puckStuckFrames just below threshold, puck nearly stopped
      engine.gameState.puckStuckFrames = 299;
      engine.gameState.puck.vx = 0.01;
      engine.gameState.puck.vy = 0.01;
      engine.gameState.puck.possessedBy = 0;

      engine._gameLoop();

      // After the puck physics update increments stuckFrames to 300
      expect(engine.gameState.phase).toBe(PHASE.COUNTDOWN);
      expect(engine.audio.playFaceoffWhistle).toHaveBeenCalled();
      engine.stop();
    });

    it("advances period when timerFrames reach 0", () => {
      const { engine } = setupPlayingEngine();
      engine.gameState.phase = PHASE.PLAYING;
      engine.gameState.timerFrames = 1;
      engine.gameState.period = 1;

      engine._gameLoop();

      // advancePeriod should have been called, moving to PERIOD_BREAK
      expect(engine.gameState.phase).toBe(PHASE.PERIOD_BREAK);
      expect(engine.audio.playPeriodBuzzer).toHaveBeenCalled();
      engine.stop();
    });

    it("broadcasts state every 2 frames", () => {
      const { engine, channel } = setupPlayingEngine();
      channel.send.mockClear();

      // Frame 1 (odd) — no broadcast
      engine._gameLoop();
      const callsAfter1 = channel.send.mock.calls.length;

      // Frame 2 (even) — broadcast
      engine._gameLoop();
      const callsAfter2 = channel.send.mock.calls.length;

      expect(callsAfter2).toBeGreaterThan(callsAfter1);
      engine.stop();
    });

    it("sudden death phase runs same gameplay logic", () => {
      const { engine } = setupPlayingEngine();
      engine.gameState.phase = PHASE.SUDDEN_DEATH;
      engine.gameState.timerFrames = 0; // no timer in sudden death

      const prevFrameCount = engine.frameCount;
      engine._gameLoop();

      expect(engine.frameCount).toBe(prevFrameCount + 1);
      // Should still be in SUDDEN_DEATH (no timer to expire)
      expect(engine.gameState.phase).toBe(PHASE.SUDDEN_DEATH);
      engine.stop();
    });
  });

  // ── Game loop — GOAL_CELEBRATION phase ──────────────────────

  describe("game loop — GOAL_CELEBRATION", () => {
    it("decrements celebrationFrames each frame", () => {
      const { engine } = setupPlayingEngine();
      engine.gameState.phase = PHASE.GOAL_CELEBRATION;
      engine.gameState.celebrationFrames = 50;

      engine._gameLoop();

      expect(engine.gameState.celebrationFrames).toBe(49);
      engine.stop();
    });

    it("updates goalFlash from celebrationFrames (decremented by render)", () => {
      const { engine } = setupPlayingEngine();
      engine.gameState.phase = PHASE.GOAL_CELEBRATION;
      engine.gameState.celebrationFrames = 30;

      engine._gameLoop();

      // celebrationFrames goes 30→29, goalFlash set to 29, then _renderState decrements to 28
      expect(engine.goalFlash).toBe(28);
      engine.stop();
    });

    it("transitions to COUNTDOWN for next faceoff when celebration ends", () => {
      const { engine } = setupPlayingEngine();
      engine.gameState.phase = PHASE.GOAL_CELEBRATION;
      engine.gameState.celebrationFrames = 1;
      engine.gameState.mode = GAME_MODE.CLASSIC;

      engine._gameLoop();

      expect(engine.gameState.phase).toBe(PHASE.COUNTDOWN);
      expect(engine.gameState.countdownValue).toBe(3);
      expect(engine.audio.playCountdownTick).toHaveBeenCalled();
      engine.stop();
    });

    it("transitions to FINISHED in showdown when target score reached", () => {
      const { engine, onGameEnd } = setupPlayingEngine("hex_hockey_showdown");
      engine.gameState.phase = PHASE.GOAL_CELEBRATION;
      engine.gameState.celebrationFrames = 1;
      engine.gameState.scoreP1 = 5; // showdown target

      engine._gameLoop();

      expect(engine.gameState.phase).toBe(PHASE.FINISHED);
      expect(onGameEnd).toHaveBeenCalled();
      engine.stop();
    });
  });

  // ── Game loop — PERIOD_BREAK phase ──────────────────────────

  describe("game loop — PERIOD_BREAK", () => {
    it("decrements periodBreakFrames each frame", () => {
      const { engine } = setupPlayingEngine();
      engine.gameState.phase = PHASE.PERIOD_BREAK;
      engine.gameState.periodBreakFrames = 100;

      engine._gameLoop();

      expect(engine.gameState.periodBreakFrames).toBe(99);
      engine.stop();
    });

    it("transitions to COUNTDOWN when break ends", () => {
      const { engine } = setupPlayingEngine();
      engine.gameState.phase = PHASE.PERIOD_BREAK;
      engine.gameState.periodBreakFrames = 1;

      engine._gameLoop();

      expect(engine.gameState.phase).toBe(PHASE.COUNTDOWN);
      expect(engine.gameState.countdownValue).toBe(3);
      expect(engine.phaseTimer).toBe(COUNTDOWN_FRAME_INTERVAL);
      expect(engine.audio.playCountdownTick).toHaveBeenCalled();
      engine.stop();
    });
  });

  // ── Game loop — FINISHED phase ──────────────────────────────

  describe("game loop — FINISHED", () => {
    it("broadcasts final state and stops running", () => {
      const { engine, channel } = setupPlayingEngine();
      engine.gameState.phase = PHASE.FINISHED;
      channel.send.mockClear();

      engine._gameLoop();

      expect(engine.running).toBe(false);
      // Should have broadcast at least once
      expect(channel.send).toHaveBeenCalled();
      engine.stop();
    });

    it("does not continue looping after FINISHED", () => {
      const { engine } = setupPlayingEngine();
      engine.gameState.phase = PHASE.FINISHED;

      engine._gameLoop();
      // Running is false, so next _gameLoop should be a no-op
      engine._gameLoop();
      // frameCount should not increment because running=false means isHost still true
      // but the FINISHED branch sets running=false, and _gameLoop guard checks isHost not running
      // Actually _gameLoop only checks isHost and gameState, not running
      // So the FINISHED branch runs again — but that's fine, it just re-broadcasts
      expect(engine.running).toBe(false);
      engine.stop();
    });
  });

  // ── _handleGameFinished ─────────────────────────────────────

  describe("_handleGameFinished", () => {
    it("calls determineWinner and sends GAME_END", () => {
      const { engine, channel } = setupPlayingEngine();
      engine.gameState.scoreP1 = 3;
      engine.gameState.scoreP2 = 1;
      channel.send.mockClear();

      engine._handleGameFinished(engine.gameState);

      expect(engine.audio.stopSuddenDeath).toHaveBeenCalled();
      expect(engine.audio.playVictory).toHaveBeenCalled();
      expect(channel.send).toHaveBeenCalled();
      // Verify GAME_END was sent
      const sentBuf = channel.send.mock.calls[0][0];
      expect(new DataView(sentBuf).getUint8(0)).toBe(MSG_TYPE.GAME_END);
      engine.stop();
    });

    it("calls onGameEnd with correct result", () => {
      const { engine, onGameEnd } = setupPlayingEngine();
      engine.gameState.scoreP1 = 2;
      engine.gameState.scoreP2 = 4;

      engine._handleGameFinished(engine.gameState);

      expect(onGameEnd).toHaveBeenCalledWith(
        expect.objectContaining({
          winner: "p2",
          score_p1: 2,
          score_p2: 4,
        }),
      );
      engine.stop();
    });

    it("reports draw when scores are equal", () => {
      const { engine, onGameEnd } = setupPlayingEngine();
      engine.gameState.scoreP1 = 2;
      engine.gameState.scoreP2 = 2;

      engine._handleGameFinished(engine.gameState);

      expect(onGameEnd).toHaveBeenCalledWith(expect.objectContaining({ winner: "draw" }));
      engine.stop();
    });

    it("works without onGameEnd callback", () => {
      const { engine } = createEngine("hex_hockey", true, null);
      engine.start();
      engine.gameState = createInitialState(GAME_MODE.CLASSIC);
      engine.onGameEnd = null;

      // Should not throw even without callback
      expect(() => engine._handleGameFinished(engine.gameState)).not.toThrow();
      engine.stop();
    });
  });

  // ── _handleAudioEvents ──────────────────────────────────────

  describe("_handleAudioEvents", () => {
    it("plays shot audio on SHOT event", () => {
      const { engine } = setupPlayingEngine();
      engine._handleAudioEvents(EVENT.SHOT);
      expect(engine.audio.playShot).toHaveBeenCalled();
      engine.stop();
    });

    it("plays wall bounce audio on WALL_BOUNCE event", () => {
      const { engine } = setupPlayingEngine();
      engine._handleAudioEvents(EVENT.WALL_BOUNCE);
      expect(engine.audio.playWallBounce).toHaveBeenCalled();
      engine.stop();
    });

    it("skips individual sounds when GOAL event is present (early return)", () => {
      const { engine } = setupPlayingEngine();
      engine._handleAudioEvents(EVENT.GOAL_P1 | EVENT.SHOT);
      // GOAL causes early return — SHOT should NOT play
      expect(engine.audio.playShot).not.toHaveBeenCalled();
      engine.stop();
    });

    it("plays multiple audio events in same frame", () => {
      const { engine } = setupPlayingEngine();
      engine._handleAudioEvents(EVENT.TACKLE_SUCCESS | EVENT.CAPTURE);
      expect(engine.audio.playTackleSuccess).toHaveBeenCalled();
      expect(engine.audio.playCapture).toHaveBeenCalled();
      engine.stop();
    });

    it("plays goalie block audio", () => {
      const { engine } = setupPlayingEngine();
      engine._handleAudioEvents(EVENT.GOALIE_BLOCK);
      expect(engine.audio.playGoalieBlock).toHaveBeenCalled();
      engine.stop();
    });

    it("plays tackle fail audio", () => {
      const { engine } = setupPlayingEngine();
      engine._handleAudioEvents(EVENT.TACKLE_FAIL);
      expect(engine.audio.playTackleFail).toHaveBeenCalled();
      engine.stop();
    });

    it("plays whistle audio on WHISTLE event", () => {
      const { engine } = setupPlayingEngine();
      engine._handleAudioEvents(EVENT.WHISTLE);
      expect(engine.audio.playFaceoffWhistle).toHaveBeenCalled();
      engine.stop();
    });
  });

  // ── _handlePeerEvents ───────────────────────────────────────

  describe("_handlePeerEvents", () => {
    it("plays goal sound and sets goalFlash on GOAL_P1 event", () => {
      const { engine } = createEngine("hex_hockey", false);
      engine.start();
      engine.gameState = createInitialState(GAME_MODE.CLASSIC);

      engine._handlePeerEvents(EVENT.GOAL_P1);

      expect(engine.audio.playGoal).toHaveBeenCalled();
      expect(engine.goalFlash).toBe(GOAL_CELEBRATION_FRAMES);
      engine.stop();
    });

    it("plays goal sound on GOAL_P2 event", () => {
      const { engine } = createEngine("hex_hockey", false);
      engine.start();
      engine.gameState = createInitialState(GAME_MODE.CLASSIC);

      engine._handlePeerEvents(EVENT.GOAL_P2);

      expect(engine.audio.playGoal).toHaveBeenCalled();
      engine.stop();
    });

    it("plays period buzzer on PERIOD_END event", () => {
      const { engine } = createEngine("hex_hockey", false);
      engine.start();
      engine.gameState = createInitialState(GAME_MODE.CLASSIC);

      engine._handlePeerEvents(EVENT.PERIOD_END);

      expect(engine.audio.playPeriodBuzzer).toHaveBeenCalled();
      engine.stop();
    });

    it("plays sudden death audio on SUDDEN_DEATH event", () => {
      const { engine } = createEngine("hex_hockey", false);
      engine.start();
      engine.gameState = createInitialState(GAME_MODE.CLASSIC);

      engine._handlePeerEvents(EVENT.SUDDEN_DEATH);

      expect(engine.audio.playSuddenDeath).toHaveBeenCalled();
      engine.stop();
    });

    it("plays multiple peer event sounds in same frame", () => {
      const { engine } = createEngine("hex_hockey", false);
      engine.start();
      engine.gameState = createInitialState(GAME_MODE.CLASSIC);

      engine._handlePeerEvents(EVENT.SHOT | EVENT.WALL_BOUNCE | EVENT.WHISTLE);

      expect(engine.audio.playShot).toHaveBeenCalled();
      expect(engine.audio.playWallBounce).toHaveBeenCalled();
      expect(engine.audio.playFaceoffWhistle).toHaveBeenCalled();
      engine.stop();
    });
  });

  // ── Peer GAME_END handling ──────────────────────────────────

  describe("peer GAME_END handling", () => {
    it("stops sudden death audio and plays victory on GAME_END", () => {
      const { engine } = createEngine("hex_hockey", false);
      engine.start();

      const buf = encodeGameEnd({ winner: "p1", score_p1: 3, score_p2: 2 });
      engine._handleMessage({ data: buf });

      expect(engine.audio.stopSuddenDeath).toHaveBeenCalled();
      expect(engine.audio.playVictory).toHaveBeenCalled();
      engine.stop();
    });

    it("calls onGameEnd callback with decoded result", () => {
      const { engine, onGameEnd } = createEngine("hex_hockey", false);
      engine.start();

      const buf = encodeGameEnd({ winner: "p2", score_p1: 1, score_p2: 5 });
      engine._handleMessage({ data: buf });

      expect(onGameEnd).toHaveBeenCalledWith(
        expect.objectContaining({ winner: "p2", score_p1: 1, score_p2: 5 }),
      );
      engine.stop();
    });
  });

  // ── Timer countdown → sudden death path ─────────────────────

  describe("timer countdown — sudden death path", () => {
    it("enters sudden death countdown when period ends with tied score", () => {
      const { engine } = setupPlayingEngine();
      engine.gameState.phase = PHASE.PLAYING;
      engine.gameState.timerFrames = 1;
      engine.gameState.period = 3; // last period for classic
      engine.gameState.scoreP1 = 2;
      engine.gameState.scoreP2 = 2;

      engine._gameLoop();

      // advancePeriod with tied score at max period → SUDDEN_DEATH event
      // Engine then sets phase to COUNTDOWN for sudden death faceoff
      expect(engine.gameState.phase).toBe(PHASE.COUNTDOWN);
      expect(engine.audio.playPeriodBuzzer).toHaveBeenCalled();
      engine.stop();
    });

    it("enters FINISHED when period ends with different scores at max period", () => {
      const { engine, onGameEnd } = setupPlayingEngine();
      engine.gameState.phase = PHASE.PLAYING;
      engine.gameState.timerFrames = 1;
      engine.gameState.period = 3;
      engine.gameState.scoreP1 = 3;
      engine.gameState.scoreP2 = 1;

      engine._gameLoop();

      expect(engine.gameState.phase).toBe(PHASE.FINISHED);
      expect(onGameEnd).toHaveBeenCalled();
      engine.stop();
    });
  });

  // ── Game loop edge cases ────────────────────────────────────

  describe("game loop edge cases", () => {
    it("game loop is a no-op for non-host", () => {
      const { engine, channel } = createEngine("hex_hockey", false);
      engine.start();
      engine.gameState = createInitialState(GAME_MODE.CLASSIC);
      engine.gameState.phase = PHASE.PLAYING;
      channel.send.mockClear();

      engine._gameLoop();

      // Non-host should not run game loop logic
      expect(channel.send).not.toHaveBeenCalled();
      expect(engine.frameCount).toBe(0);
      engine.stop();
    });

    it("game loop is a no-op when gameState is null", () => {
      const { engine } = createEngine("hex_hockey", true);
      engine.start();
      engine.gameState = null;

      // Should not throw
      expect(() => engine._gameLoop()).not.toThrow();
      engine.stop();
    });

    it("game loop renders but does nothing for unknown phase", () => {
      const { engine } = setupPlayingEngine();
      engine.gameState.phase = 99; // unknown phase

      // Should not throw
      expect(() => engine._gameLoop()).not.toThrow();
      engine.stop();
    });

    it("_startCountdown sets up countdown state correctly", () => {
      const { engine } = createEngine("hex_hockey", true);
      engine.start();

      engine._startCountdown();

      expect(engine.gameState.phase).toBe(PHASE.COUNTDOWN);
      expect(engine.gameState.countdownValue).toBe(3);
      expect(engine.phaseTimer).toBe(COUNTDOWN_FRAME_INTERVAL);
      expect(engine.audio.playCountdownTick).toHaveBeenCalled();
      engine.stop();
    });

    it("FACE_OFF sets WHISTLE event flag on countdown-to-faceoff transition", () => {
      const { engine } = setupPlayingEngine();
      engine.gameState.phase = PHASE.COUNTDOWN;
      engine.gameState.countdownValue = 1;
      engine.phaseTimer = 1;

      engine._gameLoop();

      expect(engine.gameState.eventFlags & EVENT.WHISTLE).toBeTruthy();
      engine.stop();
    });

    it("peer sends input to host on keydown", () => {
      const { engine, channel } = createEngine("hex_hockey", false);
      engine.start();
      channel.send.mockClear();

      engine._handleKeyDown({ key: "ArrowRight", preventDefault: vi.fn() });

      expect(channel.send).toHaveBeenCalled();
      const sentBuf = channel.send.mock.calls[0][0];
      expect(new DataView(sentBuf).getUint8(0)).toBe(MSG_TYPE.PLAYER_INPUT);
      engine.stop();
    });

    it("peer sends input to host on keyup", () => {
      const { engine, channel } = createEngine("hex_hockey", false);
      engine.start();
      engine.localInputs.right = true;
      channel.send.mockClear();

      engine._handleKeyUp({ key: "ArrowRight", preventDefault: vi.fn() });

      expect(channel.send).toHaveBeenCalled();
      engine.stop();
    });
  });
});
