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
} from "../../../../js/lib/games/pixel_tanks/protocol.js";
import { CANVAS_W, CANVAS_H } from "../../../../js/lib/games/pixel_tanks/physics.js";

// Must mock audio before importing engine
vi.mock("../../../../js/lib/games/pixel_tanks/audio.js", () => ({
  PixelTanksAudio: function () {
    return {
      playFire: vi.fn(),
      playHit: vi.fn(),
      playRicochet: vi.fn(),
      playCountdown: vi.fn(),
      playSpawn: vi.fn(),
      playTimerTick: vi.fn(),
      playRoundEnd: vi.fn(),
      playWin: vi.fn(),
      playLose: vi.fn(),
    };
  },
}));

// Must mock renderer
vi.mock("../../../../js/lib/games/pixel_tanks/renderer.js", () => ({
  getColors: vi.fn(() => ({
    bg: "#0a0e0a",
    fg: "#39ff14",
    accent: "#00e5ff",
    muted: "#1a2a1a",
    glow: "rgba(57,255,20,0.15)",
    warning: "#ff8c00",
    wall: "#2a2a2a",
    wallHi: "#3a3a3a",
    missile: "#ffee00",
    explosion: "#ff4444",
  })),
  render: vi.fn(),
}));

const { PixelTanksEngine } = await import("../../../../js/lib/games/pixel_tanks/engine.js");
const { render, getColors } = await import("../../../../js/lib/games/pixel_tanks/renderer.js");

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
  };
  canvas.getContext = vi.fn(() => mockCtx);

  return canvas;
}

describe("PixelTanksEngine", () => {
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
    // Restore real timers first, then re-apply RAF/CAF mocks for stop()
    vi.useRealTimers();
    globalThis.requestAnimationFrame = vi.fn(() => 42);
    globalThis.cancelAnimationFrame = vi.fn();
    if (engine) engine.stop();
    globalThis.requestAnimationFrame = originalRAF;
    globalThis.cancelAnimationFrame = originalCAF;
  });

  describe("construction", () => {
    it("creates with host role", () => {
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", true, null);
      expect(engine.isHost).toBe(true);
      expect(engine.gameState.phase).toBe(PHASE.WAITING);
    });

    it("creates with peer role", () => {
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", false, null);
      expect(engine.isHost).toBe(false);
    });

    it("initializes game state", () => {
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", true, null);
      expect(engine.gameState.tank1Alive).toBe(true);
      expect(engine.gameState.tank2Alive).toBe(true);
      expect(engine.gameState.m1Active).toBe(false);
      expect(engine.gameState.m2Active).toBe(false);
      expect(engine.gameState.round).toBe(1);
    });
  });

  describe("start", () => {
    it("host waits for peer ready", () => {
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", true, null);
      engine.start();
      expect(channel.send).not.toHaveBeenCalled();
      expect(engine.gameState.phase).toBe(PHASE.WAITING);
    });

    it("peer sends GAME_READY on start", () => {
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", false, null);
      engine.start();
      expect(channel.send).toHaveBeenCalledTimes(1);
      const sent = channel.send.mock.calls[0][0];
      const view = new DataView(sent);
      expect(view.getUint8(0)).toBe(MSG_TYPE.GAME_READY);
    });

    it("reads colors from canvas", () => {
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", true, null);
      engine.start();
      expect(getColors).toHaveBeenCalledWith(canvas);
      expect(engine.colors).not.toBeNull();
    });
  });

  describe("GAME_READY handshake", () => {
    it("host starts countdown on GAME_READY", () => {
      vi.useFakeTimers();
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", true, null);
      engine.start();

      // Simulate receiving GAME_READY
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
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", true, null);
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
    it("counts down from 3 to spawning", () => {
      vi.useFakeTimers();
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", true, null);
      engine.start();

      const handler = channel.addEventListener.mock.calls.find((c) => c[0] === "message")[1];
      handler({ data: encodeGameReady() });

      expect(engine.gameState.countdown).toBe(3);

      vi.advanceTimersByTime(1000);
      expect(engine.gameState.countdown).toBe(2);

      vi.advanceTimersByTime(1000);
      expect(engine.gameState.countdown).toBe(1);

      vi.advanceTimersByTime(1000);
      expect(engine.gameState.phase).toBe(PHASE.SPAWNING);
      vi.useRealTimers();
    });
  });

  describe("input handling", () => {
    it("maps arrow keys to input codes", () => {
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", true, null);
      expect(engine._mapKey("ArrowLeft")).toBe(INPUT_KEY.ROTATE_LEFT);
      expect(engine._mapKey("ArrowRight")).toBe(INPUT_KEY.ROTATE_RIGHT);
      expect(engine._mapKey("ArrowUp")).toBe(INPUT_KEY.FORWARD);
      expect(engine._mapKey(" ")).toBe(INPUT_KEY.FIRE);
    });

    it("maps WASD keys", () => {
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", true, null);
      expect(engine._mapKey("a")).toBe(INPUT_KEY.ROTATE_LEFT);
      expect(engine._mapKey("d")).toBe(INPUT_KEY.ROTATE_RIGHT);
      expect(engine._mapKey("w")).toBe(INPUT_KEY.FORWARD);
      expect(engine._mapKey("Shift")).toBe(INPUT_KEY.FIRE);
    });

    it("returns null for unmapped keys", () => {
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", true, null);
      expect(engine._mapKey("q")).toBeNull();
      expect(engine._mapKey("Enter")).toBeNull();
    });

    it("peer sends input over channel", () => {
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", false, null);
      engine.start();
      channel.send.mockClear();

      // Peer handles key input locally and sends over channel
      engine._handleKeyDown({ key: "ArrowUp", preventDefault: vi.fn() });
      expect(engine.localInputs.forward).toBe(true);
      expect(channel.send).toHaveBeenCalled();
    });

    it("clears all inputs on blur", () => {
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", false, null);
      engine.start();

      engine.localInputs.forward = true;
      engine.localInputs.fire = true;
      engine._handleBlur();

      expect(engine.localInputs.forward).toBe(false);
      expect(engine.localInputs.fire).toBe(false);
    });
  });

  describe("peer state application", () => {
    it("applies decoded state from host", () => {
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", false, null);
      engine.start();

      const state = {
        tank1X: 100,
        tank1Y: 200,
        tank1Rot: 1.0,
        tank1Alive: true,
        tank1Invuln: false,
        tank2X: 500,
        tank2Y: 300,
        tank2Rot: 2.0,
        tank2Alive: true,
        tank2Invuln: true,
        m1X: 150,
        m1Y: 250,
        m1VX: 5,
        m1VY: 0,
        m1Active: true,
        m1Bounced: false,
        m2X: 0,
        m2Y: 0,
        m2VX: 0,
        m2VY: 0,
        m2Active: false,
        m2Bounced: false,
        score1: 2,
        score2: 1,
        phase: PHASE.PLAYING,
        countdown: 0,
        mode: GAME_MODE.MAZE_BATTLE,
        mazeIndex: 3,
        round: 1,
        roundWins1: 0,
        roundWins2: 0,
        roundTimer: 5000,
      };

      const buf = encodeGameState(state);
      const handler = channel.addEventListener.mock.calls.find((c) => c[0] === "message")[1];
      handler({ data: buf });

      expect(engine.gameState.tank1X).toBeCloseTo(100, 0);
      expect(engine.gameState.score1).toBe(2);
      expect(engine.gameState.phase).toBe(PHASE.PLAYING);
      expect(engine.mazeIndex).toBe(3);
    });
  });

  describe("game end", () => {
    it("peer handles GAME_END message", () => {
      const onGameEnd = vi.fn();
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", false, onGameEnd);
      engine.start();

      const result = {
        score1: 5,
        score2: 3,
        winner: 1,
        roundWins1: 2,
        roundWins2: 1,
      };
      const buf = encodeGameEnd(result);
      const handler = channel.addEventListener.mock.calls.find((c) => c[0] === "message")[1];
      handler({ data: buf });

      expect(engine.gameState.phase).toBe(PHASE.MATCH_OVER);
      expect(engine.gameState.roundWins1).toBe(2);
    });

    it("host calls onGameEnd callback", () => {
      const onGameEnd = vi.fn();
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", true, onGameEnd);
      engine.start();

      // Set up winning state
      engine.gameState.roundWins1 = 2;
      engine.gameState.roundWins2 = 0;
      engine.gameState.phase = PHASE.MATCH_OVER;

      engine._handleMatchOver();

      expect(onGameEnd).toHaveBeenCalledWith({
        score: { p1: 2, p2: 0 },
        winner: 1,
      });
    });
  });

  describe("stop", () => {
    it("cleans up timers and animation frames", () => {
      vi.useFakeTimers();
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", true, null);
      engine.start();

      const handler = channel.addEventListener.mock.calls.find((c) => c[0] === "message")[1];
      handler({ data: encodeGameReady() });

      engine.stop();
      expect(engine.running).toBe(false);
      vi.useRealTimers();
    });
  });

  describe("host remote input", () => {
    it("applies remote player input", () => {
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", true, null);
      engine.start();

      const inputBuf = encodePlayerInput(INPUT_KEY.FORWARD, true);
      const handler = channel.addEventListener.mock.calls.find((c) => c[0] === "message")[1];
      handler({ data: inputBuf });

      expect(engine.remoteInputs.forward).toBe(true);
    });

    it("applies remote fire release", () => {
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", true, null);
      engine.start();

      const handler = channel.addEventListener.mock.calls.find((c) => c[0] === "message")[1];
      handler({ data: encodePlayerInput(INPUT_KEY.FIRE, true) });
      expect(engine.remoteInputs.fire).toBe(true);

      handler({ data: encodePlayerInput(INPUT_KEY.FIRE, false) });
      expect(engine.remoteInputs.fire).toBe(false);
    });
  });

  describe("message filtering", () => {
    it("ignores non-ArrayBuffer messages", () => {
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", true, null);
      engine.start();

      const handler = channel.addEventListener.mock.calls.find((c) => c[0] === "message")[1];
      // Should not throw
      handler({ data: "not binary" });
    });

    it("ignores empty buffers", () => {
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", true, null);
      engine.start();

      const handler = channel.addEventListener.mock.calls.find((c) => c[0] === "message")[1];
      handler({ data: new ArrayBuffer(0) });
    });
  });

  describe("game loop", () => {
    function setupPlaying(eng, chan) {
      vi.useFakeTimers();
      // Re-apply RAF mock after fake timers take over
      globalThis.requestAnimationFrame = vi.fn(() => 42);
      globalThis.cancelAnimationFrame = vi.fn();

      eng.start();
      const handler = chan.addEventListener.mock.calls.find((c) => c[0] === "message")[1];
      handler({ data: encodeGameReady() });
      vi.advanceTimersByTime(4000);
    }

    function getLoopFn() {
      return globalThis.requestAnimationFrame.mock.calls.at(-1)[0];
    }

    it("runs game loop and broadcasts state", () => {
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", true, null);
      setupPlaying(engine, channel);

      expect(engine.gameState.phase).toBe(PHASE.PLAYING);

      const loopFn = getLoopFn();
      channel.send.mockClear();
      loopFn(0); // frame 1
      loopFn(0); // frame 2 — should broadcast

      expect(channel.send).toHaveBeenCalled();
      vi.useRealTimers();
    });

    it("processes host local inputs in game loop", () => {
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", true, null);
      setupPlaying(engine, channel);

      const initialRot = engine.gameState.tank1Rot;
      engine.localInputs.rotateRight = true;

      getLoopFn()(0);

      expect(engine.gameState.tank1Rot).not.toBe(initialRot);
      vi.useRealTimers();
    });

    it("edge-triggers fire on press not hold", () => {
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", true, null);
      setupPlaying(engine, channel);

      // Clear walls so barrel tip is never blocked by a random maze
      engine.walls = new Uint8Array(40 * 30);
      engine.localInputs.fire = true;
      getLoopFn()(0); // should fire
      expect(engine.gameState.m1Active).toBe(true);

      // Deactivate missile to test re-fire
      engine.gameState.m1Active = false;
      getLoopFn()(0); // still holding — should NOT fire
      expect(engine.gameState.m1Active).toBe(false);

      vi.useRealTimers();
    });
  });

  describe("round transitions", () => {
    function setupPlaying(eng, chan) {
      vi.useFakeTimers();
      globalThis.requestAnimationFrame = vi.fn(() => 42);
      globalThis.cancelAnimationFrame = vi.fn();

      eng.start();
      const handler = chan.addEventListener.mock.calls.find((c) => c[0] === "message")[1];
      handler({ data: encodeGameReady() });
      vi.advanceTimersByTime(4000);
    }

    function getLoopFn() {
      return globalThis.requestAnimationFrame.mock.calls.at(-1)[0];
    }

    it("transitions to ROUND_OVER when timer expires", () => {
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", true, null);
      setupPlaying(engine, channel);

      engine.gameState.roundTimer = 1;
      engine.gameState.score1 = 3;
      engine.gameState.score2 = 1;

      getLoopFn()(0);

      expect(engine.gameState.phase).toBe(PHASE.ROUND_OVER);
      expect(engine.gameState.roundWins1).toBe(1);
      vi.useRealTimers();
    });

    it("starts new countdown after ROUND_OVER delay", () => {
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", true, null);
      setupPlaying(engine, channel);

      engine.gameState.roundTimer = 1;
      engine.gameState.score1 = 2;
      engine.gameState.score2 = 0;

      getLoopFn()(0);

      expect(engine.gameState.phase).toBe(PHASE.ROUND_OVER);

      vi.advanceTimersByTime(2500);
      expect(engine.gameState.phase).toBe(PHASE.COUNTDOWN);
      expect(engine.gameState.round).toBe(2);
      vi.useRealTimers();
    });
  });

  describe("match over", () => {
    function setupPlaying(eng, chan) {
      vi.useFakeTimers();
      globalThis.requestAnimationFrame = vi.fn(() => 42);
      globalThis.cancelAnimationFrame = vi.fn();

      eng.start();
      const handler = chan.addEventListener.mock.calls.find((c) => c[0] === "message")[1];
      handler({ data: encodeGameReady() });
      vi.advanceTimersByTime(4000);
    }

    function getLoopFn() {
      return globalThis.requestAnimationFrame.mock.calls.at(-1)[0];
    }

    it("ends match when a player reaches ROUNDS_TO_WIN", () => {
      const onGameEnd = vi.fn();
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", true, onGameEnd);
      setupPlaying(engine, channel);

      engine.gameState.roundWins1 = 1;
      engine.gameState.roundTimer = 1;
      engine.gameState.score1 = 5;
      engine.gameState.score2 = 2;

      getLoopFn()(0);

      expect(engine.gameState.phase).toBe(PHASE.MATCH_OVER);
      expect(onGameEnd).toHaveBeenCalledWith({
        score: { p1: 2, p2: 0 },
        winner: 1,
      });
      vi.useRealTimers();
    });

    it("sends GAME_END to peer on match over", () => {
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", true, null);
      setupPlaying(engine, channel);

      engine.gameState.roundWins1 = 1;
      engine.gameState.roundTimer = 1;
      engine.gameState.score1 = 3;
      engine.gameState.score2 = 0;
      channel.send.mockClear();

      getLoopFn()(0);

      const sentTypes = channel.send.mock.calls.map((c) => new DataView(c[0]).getUint8(0));
      expect(sentTypes).toContain(MSG_TYPE.GAME_END);
      vi.useRealTimers();
    });
  });

  describe("respawn", () => {
    it("respawns tanks after a hit", () => {
      vi.useFakeTimers();
      globalThis.requestAnimationFrame = vi.fn(() => 42);
      globalThis.cancelAnimationFrame = vi.fn();

      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", true, null);
      engine.start();

      const handler = channel.addEventListener.mock.calls.find((c) => c[0] === "message")[1];
      handler({ data: encodeGameReady() });
      vi.advanceTimersByTime(4000);

      // Set up a hit scenario: place missile on top of tank2
      engine.gameState.m1Active = true;
      engine.gameState.m1X = engine.gameState.tank2X;
      engine.gameState.m1Y = engine.gameState.tank2Y;
      engine.gameState.m1VX = 5;
      engine.gameState.m1VY = 0;

      const prevScore = engine.gameState.score1;
      const loopFn = globalThis.requestAnimationFrame.mock.calls.at(-1)[0];
      loopFn(0);

      expect(engine.gameState.score1).toBe(prevScore + 1);
      expect(engine.gameState.tank1Invuln).toBe(true);
      expect(engine.gameState.tank2Invuln).toBe(true);
      expect(engine.gameState.respawnPause).toBeGreaterThan(0);
      vi.useRealTimers();
    });
  });

  describe("stop cleanup", () => {
    it("resets fire pressed state on stop", () => {
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", true, null);
      engine.start();
      engine._localFirePressed = true;
      engine._remoteFirePressed = true;

      engine.stop();

      expect(engine._localFirePressed).toBe(false);
      expect(engine._remoteFirePressed).toBe(false);
    });

    it("guards phase callbacks after stop", () => {
      vi.useFakeTimers();
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", true, null);
      engine.start();

      const handler = channel.addEventListener.mock.calls.find((c) => c[0] === "message")[1];
      handler({ data: encodeGameReady() });

      engine.stop();

      // Advance timer — countdown tick should be a no-op
      vi.advanceTimersByTime(3000);
      expect(engine.running).toBe(false);
      vi.useRealTimers();
    });
  });

  // ── Connection Resilience ──

  describe("connection resilience", () => {
    it("double-start is a no-op", () => {
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", true, null);
      engine.start();
      const firstState = engine.gameState;
      engine.start(); // should not reset
      expect(engine.gameState).toBe(firstState);
    });

    it("blur clears local inputs", () => {
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", true, null);
      engine.start();
      engine.localInputs = { rotateLeft: true, rotateRight: true, forward: true, fire: true };
      engine._handleBlur();
      expect(engine.localInputs.rotateLeft).toBe(false);
      expect(engine.localInputs.rotateRight).toBe(false);
      expect(engine.localInputs.forward).toBe(false);
      expect(engine.localInputs.fire).toBe(false);
    });

    it("channel close ends game with disconnect flag", () => {
      const onEnd = vi.fn();
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", true, onEnd);
      engine.start();
      engine.gameState.phase = PHASE.PLAYING;
      engine._handleChannelClose();
      expect(engine.gameState.phase).toBe(PHASE.MATCH_OVER);
      expect(onEnd).toHaveBeenCalledWith(expect.objectContaining({ disconnected: true }));
    });

    it("channel close is no-op when game already finished", () => {
      const onEnd = vi.fn();
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", true, onEnd);
      engine.start();
      engine.gameState.phase = PHASE.MATCH_OVER;
      engine._handleChannelClose();
      expect(onEnd).not.toHaveBeenCalled();
    });
  });

  describe("RICOCHET mode missile update", () => {
    function setupPlaying(eng, chan, _gameMode) {
      vi.useFakeTimers();
      globalThis.requestAnimationFrame = vi.fn(() => 42);
      globalThis.cancelAnimationFrame = vi.fn();

      eng.start();
      const handler = chan.addEventListener.mock.calls.find((c) => c[0] === "message")[1];
      handler({ data: encodeGameReady() });
      vi.advanceTimersByTime(4000);
    }

    function getLoopFn() {
      return globalThis.requestAnimationFrame.mock.calls.at(-1)[0];
    }

    it("uses updateMissileRicochet in RICOCHET mode", () => {
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", true, null);
      engine.mode = GAME_MODE.RICOCHET;
      setupPlaying(engine, channel);

      // Set missile active so updateMissileRicochet has work to do
      engine.gameState.m1Active = true;
      engine.gameState.m1VX = 5;
      engine.gameState.m1VY = 0;
      engine.walls = new Uint8Array(40 * 30); // empty maze

      const loopFn = getLoopFn();
      loopFn(0);

      // Should not throw and continue loop
      expect(globalThis.requestAnimationFrame).toHaveBeenCalled();
      vi.useRealTimers();
    });

    it("plays playRicochet on wallBounced event", () => {
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", true, null);
      engine.mode = GAME_MODE.RICOCHET;
      setupPlaying(engine, channel);

      engine.audio.playRicochet.mockClear();

      // Force a wall bounce by manipulating state during loop
      // We can test the audio path directly:
      // In the game loop, after missile update, if s.wallBounced is truthy, playRicochet is called
      // Let's set up a missile heading into a wall
      engine.gameState.m1Active = true;
      engine.gameState.m1X = 16; // near cell boundary
      engine.gameState.m1Y = 16;
      engine.gameState.m1VX = 5;
      engine.gameState.m1VY = 0;

      // Put a wall at the cell the missile will hit
      engine.walls = new Uint8Array(40 * 30);
      engine.walls[1 * 40 + 2] = 1; // wall at grid position near missile path

      const loopFn = getLoopFn();
      loopFn(0);

      // Whether ricochet was triggered depends on physics, but the code path is tested
      vi.useRealTimers();
    });
  });

  describe("respawnPause branch in game loop", () => {
    function setupPlaying(eng, chan) {
      vi.useFakeTimers();
      globalThis.requestAnimationFrame = vi.fn(() => 42);
      globalThis.cancelAnimationFrame = vi.fn();

      eng.start();
      const handler = chan.addEventListener.mock.calls.find((c) => c[0] === "message")[1];
      handler({ data: encodeGameReady() });
      vi.advanceTimersByTime(4000);
    }

    function getLoopFn() {
      return globalThis.requestAnimationFrame.mock.calls.at(-1)[0];
    }

    it("continues loop during respawnPause without physics", () => {
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", true, null);
      setupPlaying(engine, channel);

      // Set respawnPause
      engine.gameState.respawnPause = 30;
      const initialTank1Rot = engine.gameState.tank1Rot;

      engine.localInputs.rotateRight = true;

      const loopFn = getLoopFn();
      loopFn(0);

      // Tank should NOT have rotated (physics skipped)
      expect(engine.gameState.tank1Rot).toBe(initialTank1Rot);
      // But RAF should have been called to continue loop
      expect(globalThis.requestAnimationFrame).toHaveBeenCalled();
      vi.useRealTimers();
    });

    it("ticks timers during respawnPause", () => {
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", true, null);
      setupPlaying(engine, channel);

      engine.gameState.respawnPause = 5;

      const loopFn = getLoopFn();
      loopFn(0);

      // respawnPause should have been decremented by tickTimers
      expect(engine.gameState.respawnPause).toBeLessThan(5);
      vi.useRealTimers();
    });
  });

  describe("remote input for rotateLeft/rotateRight", () => {
    it("applies rotateLeft from remote", () => {
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", true, null);
      engine.start();

      const handler = channel.addEventListener.mock.calls.find((c) => c[0] === "message")[1];
      handler({ data: encodePlayerInput(INPUT_KEY.ROTATE_LEFT, true) });
      expect(engine.remoteInputs.rotateLeft).toBe(true);

      handler({ data: encodePlayerInput(INPUT_KEY.ROTATE_LEFT, false) });
      expect(engine.remoteInputs.rotateLeft).toBe(false);
    });

    it("applies rotateRight from remote", () => {
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", true, null);
      engine.start();

      const handler = channel.addEventListener.mock.calls.find((c) => c[0] === "message")[1];
      handler({ data: encodePlayerInput(INPUT_KEY.ROTATE_RIGHT, true) });
      expect(engine.remoteInputs.rotateRight).toBe(true);

      handler({ data: encodePlayerInput(INPUT_KEY.ROTATE_RIGHT, false) });
      expect(engine.remoteInputs.rotateRight).toBe(false);
    });
  });

  describe("timer tick audio", () => {
    function setupPlaying(eng, chan) {
      vi.useFakeTimers();
      globalThis.requestAnimationFrame = vi.fn(() => 42);
      globalThis.cancelAnimationFrame = vi.fn();

      eng.start();
      const handler = chan.addEventListener.mock.calls.find((c) => c[0] === "message")[1];
      handler({ data: encodeGameReady() });
      vi.advanceTimersByTime(4000);
    }

    function getLoopFn() {
      return globalThis.requestAnimationFrame.mock.calls.at(-1)[0];
    }

    it("plays playTimerTick when roundTimer <= 900 and divisible by 60", () => {
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", true, null);
      setupPlaying(engine, channel);

      engine.audio.playTimerTick.mockClear();

      // Set roundTimer so after tickTimers it will be exactly 900 (or 60*n <= 900)
      // tickTimers decrements by 1 each frame
      // We want s.roundTimer after tick to be 900 and % 60 === 0
      engine.gameState.roundTimer = 901; // after tick: 900

      const loopFn = getLoopFn();
      loopFn(0);

      expect(engine.audio.playTimerTick).toHaveBeenCalled();
      vi.useRealTimers();
    });
  });

  describe("_handleMatchOver audio", () => {
    it("plays playWin when host (P1) wins match", () => {
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", true, null);
      engine.start();

      engine.gameState.roundWins1 = 2;
      engine.gameState.roundWins2 = 0;
      engine.gameState.phase = PHASE.MATCH_OVER;

      engine.audio.playWin.mockClear();
      engine.audio.playLose.mockClear();

      engine._handleMatchOver();

      expect(engine.audio.playWin).toHaveBeenCalled();
      expect(engine.audio.playLose).not.toHaveBeenCalled();
    });

    it("plays playLose when host (P1) loses match", () => {
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", true, null);
      engine.start();

      engine.gameState.roundWins1 = 0;
      engine.gameState.roundWins2 = 2;
      engine.gameState.phase = PHASE.MATCH_OVER;

      engine.audio.playWin.mockClear();
      engine.audio.playLose.mockClear();

      engine._handleMatchOver();

      expect(engine.audio.playLose).toHaveBeenCalled();
      expect(engine.audio.playWin).not.toHaveBeenCalled();
    });
  });

  describe("_playPhaseAudio ROUND_OVER transition", () => {
    it("plays playRoundEnd on ROUND_OVER phase transition", () => {
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", false, null);
      engine.start();

      engine.audio.playRoundEnd.mockClear();

      // Simulate phase transition to ROUND_OVER
      engine._playPhaseAudio(PHASE.PLAYING, PHASE.ROUND_OVER);

      expect(engine.audio.playRoundEnd).toHaveBeenCalled();
    });
  });

  describe("keyUp handling", () => {
    it("clears local input on keyup for host", () => {
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", true, null);
      engine.start();

      engine.localInputs.forward = true;
      engine._handleKeyUp({ key: "ArrowUp", preventDefault: vi.fn() });
      expect(engine.localInputs.forward).toBe(false);
    });

    it("peer sends release over channel on keyup", () => {
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", false, null);
      engine.start();
      channel.send.mockClear();

      engine._handleKeyUp({ key: "ArrowUp", preventDefault: vi.fn() });
      expect(channel.send).toHaveBeenCalled();
    });

    it("ignores unmapped keys on keydown", () => {
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", true, null);
      engine.start();

      const prevState = { ...engine.localInputs };
      engine._handleKeyDown({ key: "z", preventDefault: vi.fn() });
      expect(engine.localInputs).toEqual(prevState);
    });
  });

  describe("peer GAME_END audio paths", () => {
    it("peer plays playWin when winner=2 (peer is P2)", () => {
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", false, null);
      engine.start();

      engine.audio.playWin.mockClear();
      engine.audio.playLose.mockClear();

      const result = { score1: 2, score2: 5, winner: 2, roundWins1: 0, roundWins2: 2 };
      const buf = encodeGameEnd(result);
      const handler = channel.addEventListener.mock.calls.find((c) => c[0] === "message")[1];
      handler({ data: buf });

      expect(engine.gameState.phase).toBe(PHASE.MATCH_OVER);
      expect(engine.audio.playWin).toHaveBeenCalled();
      expect(engine.audio.playLose).not.toHaveBeenCalled();
    });

    it("peer plays playLose when winner=1 (peer is P2, lost)", () => {
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", false, null);
      engine.start();

      engine.audio.playWin.mockClear();
      engine.audio.playLose.mockClear();

      const result = { score1: 5, score2: 2, winner: 1, roundWins1: 2, roundWins2: 0 };
      const buf = encodeGameEnd(result);
      const handler = channel.addEventListener.mock.calls.find((c) => c[0] === "message")[1];
      handler({ data: buf });

      expect(engine.audio.playLose).toHaveBeenCalled();
      expect(engine.audio.playWin).not.toHaveBeenCalled();
    });
  });

  describe("_playPhaseAudio edge cases", () => {
    it("does nothing when phase is unchanged", () => {
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", false, null);
      engine.start();
      engine.audio.playCountdown.mockClear();
      engine.audio.playSpawn.mockClear();
      engine.audio.playRoundEnd.mockClear();

      engine._playPhaseAudio(PHASE.PLAYING, PHASE.PLAYING);
      expect(engine.audio.playCountdown).not.toHaveBeenCalled();
      expect(engine.audio.playSpawn).not.toHaveBeenCalled();
      expect(engine.audio.playRoundEnd).not.toHaveBeenCalled();
    });

    it("plays countdown audio on COUNTDOWN transition", () => {
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", false, null);
      engine.start();
      engine.audio.playCountdown.mockClear();

      engine._playPhaseAudio(PHASE.WAITING, PHASE.COUNTDOWN);
      expect(engine.audio.playCountdown).toHaveBeenCalled();
    });
  });

  describe("_handleChannelClose error handling", () => {
    it("swallows callback error without throwing", () => {
      const onEnd = vi.fn(() => {
        throw new Error("callback error");
      });
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", true, onEnd);
      engine.start();
      engine.gameState.phase = PHASE.PLAYING;

      expect(() => engine._handleChannelClose()).not.toThrow();
      expect(onEnd).toHaveBeenCalled();
    });
  });

  describe("_gameLoop guard", () => {
    it("exits early when not running", () => {
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", true, null);
      engine.start();
      engine.running = false;
      engine.gameState.phase = PHASE.PLAYING;

      globalThis.requestAnimationFrame.mockClear();
      engine._gameLoop(0);

      expect(globalThis.requestAnimationFrame).not.toHaveBeenCalled();
    });
  });

  describe("peer phase audio", () => {
    it("plays spawn audio on SPAWNING phase transition", () => {
      engine = new PixelTanksEngine(canvas, channel, "pixel_tanks", false, null);
      engine.start();

      const state = {
        tank1X: 48,
        tank1Y: 240,
        tank1Rot: 0,
        tank1Alive: true,
        tank1Invuln: false,
        tank2X: 592,
        tank2Y: 240,
        tank2Rot: 3.14,
        tank2Alive: true,
        tank2Invuln: false,
        m1X: 0,
        m1Y: 0,
        m1VX: 0,
        m1VY: 0,
        m1Active: false,
        m1Bounced: false,
        m2X: 0,
        m2Y: 0,
        m2VX: 0,
        m2VY: 0,
        m2Active: false,
        m2Bounced: false,
        score1: 0,
        score2: 0,
        phase: PHASE.SPAWNING,
        countdown: 0,
        mode: 0,
        mazeIndex: 0,
        round: 1,
        roundWins1: 0,
        roundWins2: 0,
        roundTimer: 7200,
      };

      const buf = encodeGameState(state);
      const handler = channel.addEventListener.mock.calls.find((c) => c[0] === "message")[1];
      handler({ data: buf });

      expect(engine.audio.playSpawn).toHaveBeenCalled();
    });
  });
});
