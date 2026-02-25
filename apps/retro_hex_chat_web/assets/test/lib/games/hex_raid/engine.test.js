import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import {
  PHASE,
  MSG_TYPE,
  INPUT_KEY,
  GAME_MODE,
  ENEMY_TYPE,
  encodeGameState,
  encodePlayerInput,
  encodeGameEnd,
  encodeGameReady,
} from "../../../../js/lib/games/hex_raid/protocol.js";
import { CANVAS_W, CANVAS_H, INITIAL_LIVES } from "../../../../js/lib/games/hex_raid/physics.js";

// Must mock audio before importing engine
vi.mock("../../../../js/lib/games/hex_raid/audio.js", () => ({
  HexRaidAudio: function () {
    return {
      playFire: vi.fn(),
      playEnemyDestroyed: vi.fn(),
      playBridgeHit: vi.fn(),
      playBridgeDestroyed: vi.fn(),
      playFuelCapture: vi.fn(),
      playFuelDestroyed: vi.fn(),
      playMineDeploy: vi.fn(),
      playMineHit: vi.fn(),
      playDeath: vi.fn(),
      playRespawn: vi.fn(),
      playSectionClear: vi.fn(),
      playFuelLow: vi.fn(),
      playKillSteal: vi.fn(),
      playCountdown: vi.fn(),
      playWin: vi.fn(),
      playLose: vi.fn(),
    };
  },
}));

// Must mock renderer
vi.mock("../../../../js/lib/games/hex_raid/renderer.js", () => ({
  getColors: vi.fn(() => ({
    bg: "#0a0e14",
    p1: "#39ff14",
    p2: "#00e5ff",
    water: "#0a1a2a",
    glow: "rgba(57,255,20,0.15)",
    warning: "#ff8c00",
    bank: "#1a2a1a",
    bankHi: "#2a4a2a",
    missile: "#ffee00",
    explosion: "#ff4444",
  })),
  render: vi.fn(),
}));

const { HexRaidEngine } = await import("../../../../js/lib/games/hex_raid/engine.js");
const { render, getColors } = await import("../../../../js/lib/games/hex_raid/renderer.js");

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

describe("HexRaidEngine", () => {
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
      engine = new HexRaidEngine(canvas, channel, "hex_raid", true, null);
      expect(engine.isHost).toBe(true);
      expect(engine.gameState.phase).toBe(PHASE.WAITING);
      expect(engine.mode).toBe(GAME_MODE.RIVER_DUEL);
    });

    it("creates with peer role", () => {
      engine = new HexRaidEngine(canvas, channel, "hex_raid", false, null);
      expect(engine.isHost).toBe(false);
      expect(engine.seed).toBe(0); // peer doesn't know seed yet
    });

    it("selects correct mode from gameId", () => {
      engine = new HexRaidEngine(canvas, channel, "hex_raid_pacifist", true, null);
      expect(engine.mode).toBe(GAME_MODE.PACIFIST);

      engine.stop();
      engine = new HexRaidEngine(canvas, channel, "hex_raid_blitz", true, null);
      expect(engine.mode).toBe(GAME_MODE.BLITZ);
    });

    it("initializes game state", () => {
      engine = new HexRaidEngine(canvas, channel, "hex_raid", true, null);
      expect(engine.gameState.jet1Alive).toBe(true);
      expect(engine.gameState.jet2Alive).toBe(true);
      expect(engine.gameState.jet1Lives).toBe(INITIAL_LIVES);
      expect(engine.gameState.jet2Lives).toBe(INITIAL_LIVES);
      expect(engine.gameState.m1Active).toBe(false);
      expect(engine.gameState.m2Active).toBe(false);
      expect(engine.gameState.section).toBe(0);
    });

    it("host generates a seed", () => {
      engine = new HexRaidEngine(canvas, channel, "hex_raid", true, null);
      expect(engine.seed).toBeGreaterThan(0);
    });
  });

  describe("start", () => {
    it("host waits for peer ready", () => {
      engine = new HexRaidEngine(canvas, channel, "hex_raid", true, null);
      engine.start();
      expect(channel.send).not.toHaveBeenCalled();
      expect(engine.gameState.phase).toBe(PHASE.WAITING);
    });

    it("peer sends GAME_READY on start", () => {
      engine = new HexRaidEngine(canvas, channel, "hex_raid", false, null);
      engine.start();
      expect(channel.send).toHaveBeenCalledTimes(1);
      const sent = channel.send.mock.calls[0][0];
      const view = new DataView(sent);
      expect(view.getUint8(0)).toBe(MSG_TYPE.GAME_READY);
    });

    it("reads colors from canvas", () => {
      engine = new HexRaidEngine(canvas, channel, "hex_raid", true, null);
      engine.start();
      expect(getColors).toHaveBeenCalledWith(canvas);
      expect(engine.colors).not.toBeNull();
    });
  });

  describe("GAME_READY handshake", () => {
    it("host starts countdown on GAME_READY", () => {
      vi.useFakeTimers();
      engine = new HexRaidEngine(canvas, channel, "hex_raid", true, null);
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
      engine = new HexRaidEngine(canvas, channel, "hex_raid", true, null);
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
    it("counts down from 3 to flying", () => {
      vi.useFakeTimers();
      engine = new HexRaidEngine(canvas, channel, "hex_raid", true, null);
      engine.start();

      const handler = channel.addEventListener.mock.calls.find((c) => c[0] === "message")[1];
      handler({ data: encodeGameReady() });

      expect(engine.gameState.countdown).toBe(3);

      vi.advanceTimersByTime(1000);
      expect(engine.gameState.countdown).toBe(2);

      vi.advanceTimersByTime(1000);
      expect(engine.gameState.countdown).toBe(1);

      vi.advanceTimersByTime(1000);
      expect(engine.gameState.phase).toBe(PHASE.FLYING);
      vi.useRealTimers();
    });
  });

  describe("input handling", () => {
    it("maps arrow keys to input codes", () => {
      engine = new HexRaidEngine(canvas, channel, "hex_raid", true, null);
      expect(engine._mapKey("ArrowLeft")).toBe(INPUT_KEY.LEFT);
      expect(engine._mapKey("ArrowRight")).toBe(INPUT_KEY.RIGHT);
      expect(engine._mapKey("ArrowUp")).toBe(INPUT_KEY.ACCEL);
      expect(engine._mapKey("ArrowDown")).toBe(INPUT_KEY.DECEL);
      expect(engine._mapKey(" ")).toBe(INPUT_KEY.FIRE);
      expect(engine._mapKey("Shift")).toBe(INPUT_KEY.MINE);
    });

    it("maps WASD + Q keys", () => {
      engine = new HexRaidEngine(canvas, channel, "hex_raid", true, null);
      expect(engine._mapKey("a")).toBe(INPUT_KEY.LEFT);
      expect(engine._mapKey("d")).toBe(INPUT_KEY.RIGHT);
      expect(engine._mapKey("w")).toBe(INPUT_KEY.ACCEL);
      expect(engine._mapKey("s")).toBe(INPUT_KEY.DECEL);
      expect(engine._mapKey("q")).toBe(INPUT_KEY.MINE);
    });

    it("returns null for unmapped keys", () => {
      engine = new HexRaidEngine(canvas, channel, "hex_raid", true, null);
      expect(engine._mapKey("Enter")).toBeNull();
      expect(engine._mapKey("z")).toBeNull();
    });

    it("peer sends input over channel", () => {
      engine = new HexRaidEngine(canvas, channel, "hex_raid", false, null);
      engine.start();
      channel.send.mockClear();

      engine._handleKeyDown({ key: "ArrowLeft", preventDefault: vi.fn() });
      expect(engine.localInputs.left).toBe(true);
      expect(channel.send).toHaveBeenCalled();
    });

    it("clears all inputs on blur", () => {
      engine = new HexRaidEngine(canvas, channel, "hex_raid", false, null);
      engine.start();

      engine.localInputs.left = true;
      engine.localInputs.fire = true;
      engine.localInputs.mine = true;
      engine._handleBlur();

      expect(engine.localInputs.left).toBe(false);
      expect(engine.localInputs.fire).toBe(false);
      expect(engine.localInputs.mine).toBe(false);
    });
  });

  describe("peer state application", () => {
    it("applies decoded state from host", () => {
      engine = new HexRaidEngine(canvas, channel, "hex_raid", false, null);
      engine.start();

      const state = {
        jet1X: 300,
        jet1Y: 400,
        jet1Speed: 2,
        jet1Fuel: 200,
        jet1Lives: 3,
        jet1Alive: true,
        jet1Invuln: false,
        jet1Respawning: false,
        jet2X: 340,
        jet2Y: 380,
        jet2Speed: 3,
        jet2Fuel: 150,
        jet2Lives: 2,
        jet2Alive: true,
        jet2Invuln: false,
        jet2Respawning: false,
        m1X: 300,
        m1Y: 200,
        m1Active: true,
        m2X: 0,
        m2Y: 0,
        m2Active: false,
        enemies: [{ type: ENEMY_TYPE.BOAT, x: 320, y: 100, alive: true }],
        enemyCount: 1,
        fuels: [{ x: 310, y: 250, available: true }],
        fuelCount: 1,
        mines: [],
        mineCount: 0,
        bridgeY: 50,
        bridgeHp: 3,
        bridgeActive: true,
        score1: 500,
        score2: 300,
        phase: PHASE.FLYING,
        countdown: 0,
        section: 2,
        scrollY: 1800,
        mode: GAME_MODE.RIVER_DUEL,
        seed: 12345,
      };

      const buf = encodeGameState(state);
      const handler = channel.addEventListener.mock.calls.find((c) => c[0] === "message")[1];
      handler({ data: buf });

      expect(engine.gameState.jet1X).toBe(300);
      expect(engine.gameState.score1).toBe(500);
      expect(engine.gameState.phase).toBe(PHASE.FLYING);
      expect(engine.gameState.section).toBe(2);
      expect(engine.seed).toBe(12345);
    });
  });

  describe("game end", () => {
    it("peer handles GAME_END message", () => {
      engine = new HexRaidEngine(canvas, channel, "hex_raid", false, null);
      engine.start();

      const result = { score1: 2340, score2: 1890, winner: 1 };
      const buf = encodeGameEnd(result);
      const handler = channel.addEventListener.mock.calls.find((c) => c[0] === "message")[1];
      handler({ data: buf });

      expect(engine.gameState.phase).toBe(PHASE.FINISHED);
      expect(engine.gameState.score1).toBe(2340);
      expect(engine.gameState.score2).toBe(1890);
    });

    it("host calls onGameEnd callback", () => {
      const onGameEnd = vi.fn();
      engine = new HexRaidEngine(canvas, channel, "hex_raid", true, onGameEnd);
      engine.start();

      engine.gameState.score1 = 5000;
      engine.gameState.score2 = 3000;
      engine.gameState.phase = PHASE.FINISHED;

      engine._handleGameOver();

      expect(onGameEnd).toHaveBeenCalledWith({
        score: { p1: 5000, p2: 3000 },
        winner: 1,
      });
    });
  });

  describe("stop", () => {
    it("cleans up timers and animation frames", () => {
      vi.useFakeTimers();
      engine = new HexRaidEngine(canvas, channel, "hex_raid", true, null);
      engine.start();

      const handler = channel.addEventListener.mock.calls.find((c) => c[0] === "message")[1];
      handler({ data: encodeGameReady() });

      engine.stop();
      expect(engine.running).toBe(false);
      vi.useRealTimers();
    });

    it("resets fire and mine pressed state on stop", () => {
      engine = new HexRaidEngine(canvas, channel, "hex_raid", true, null);
      engine.start();
      engine._localFirePressed = true;
      engine._remoteFirePressed = true;
      engine._localMinePressed = true;
      engine._remoteMinePressed = true;

      engine.stop();

      expect(engine._localFirePressed).toBe(false);
      expect(engine._remoteFirePressed).toBe(false);
      expect(engine._localMinePressed).toBe(false);
      expect(engine._remoteMinePressed).toBe(false);
    });

    it("guards phase callbacks after stop", () => {
      vi.useFakeTimers();
      engine = new HexRaidEngine(canvas, channel, "hex_raid", true, null);
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
      engine = new HexRaidEngine(canvas, channel, "hex_raid", true, null);
      engine.start();

      const inputBuf = encodePlayerInput(INPUT_KEY.LEFT, true);
      const handler = channel.addEventListener.mock.calls.find((c) => c[0] === "message")[1];
      handler({ data: inputBuf });

      expect(engine.remoteInputs.left).toBe(true);
    });

    it("applies remote mine input", () => {
      engine = new HexRaidEngine(canvas, channel, "hex_raid", true, null);
      engine.start();

      const handler = channel.addEventListener.mock.calls.find((c) => c[0] === "message")[1];
      handler({ data: encodePlayerInput(INPUT_KEY.MINE, true) });
      expect(engine.remoteInputs.mine).toBe(true);

      handler({ data: encodePlayerInput(INPUT_KEY.MINE, false) });
      expect(engine.remoteInputs.mine).toBe(false);
    });
  });

  describe("message filtering", () => {
    it("ignores non-ArrayBuffer messages", () => {
      engine = new HexRaidEngine(canvas, channel, "hex_raid", true, null);
      engine.start();

      const handler = channel.addEventListener.mock.calls.find((c) => c[0] === "message")[1];
      handler({ data: "not binary" });
    });

    it("ignores empty buffers", () => {
      engine = new HexRaidEngine(canvas, channel, "hex_raid", true, null);
      engine.start();

      const handler = channel.addEventListener.mock.calls.find((c) => c[0] === "message")[1];
      handler({ data: new ArrayBuffer(0) });
    });
  });

  describe("game loop", () => {
    function setupFlying(eng, chan) {
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
      engine = new HexRaidEngine(canvas, channel, "hex_raid", true, null);
      setupFlying(engine, channel);

      expect(engine.gameState.phase).toBe(PHASE.FLYING);

      const loopFn = getLoopFn();
      channel.send.mockClear();
      loopFn(); // frame 1
      loopFn(); // frame 2 — should broadcast

      expect(channel.send).toHaveBeenCalled();
      vi.useRealTimers();
    });

    it("processes host local inputs in game loop", () => {
      engine = new HexRaidEngine(canvas, channel, "hex_raid", true, null);
      setupFlying(engine, channel);

      const initialX = engine.gameState.jet1X;
      engine.localInputs.right = true;

      getLoopFn()();

      expect(engine.gameState.jet1X).not.toBe(initialX);
      vi.useRealTimers();
    });

    it("edge-triggers fire on press not hold", () => {
      engine = new HexRaidEngine(canvas, channel, "hex_raid", true, null);
      setupFlying(engine, channel);

      engine.localInputs.fire = true;
      getLoopFn()(); // should fire
      expect(engine.gameState.m1Active).toBe(true);

      // Deactivate missile to test re-fire
      engine.gameState.m1Active = false;
      engine.gameState.jet1MissileCooldown = 0;
      getLoopFn()(); // still holding — should NOT fire
      expect(engine.gameState.m1Active).toBe(false);

      vi.useRealTimers();
    });
  });

  describe("edge-triggered mine deployment", () => {
    function setupFlying(eng, chan) {
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

    it("deploys mine only once per press", () => {
      engine = new HexRaidEngine(canvas, channel, "hex_raid", true, null);
      setupFlying(engine, channel);

      engine.localInputs.mine = true;
      getLoopFn()(); // should deploy mine
      const mineCount1 = engine.gameState.mineCount;

      getLoopFn()(); // still holding — should NOT deploy again
      expect(engine.gameState.mineCount).toBe(mineCount1);

      vi.useRealTimers();
    });

    it("does not deploy mine in pacifist mode", () => {
      engine = new HexRaidEngine(canvas, channel, "hex_raid_pacifist", true, null);
      setupFlying(engine, channel);

      engine.localInputs.mine = true;
      getLoopFn()();
      expect(engine.gameState.mineCount).toBe(0);

      vi.useRealTimers();
    });
  });

  describe("remote fire edge-trigger", () => {
    function setupFlying(eng, chan) {
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

    it("edge-triggers remote fire", () => {
      engine = new HexRaidEngine(canvas, channel, "hex_raid", true, null);
      setupFlying(engine, channel);

      engine.remoteInputs.fire = true;
      getLoopFn()(); // should fire m2
      expect(engine.gameState.m2Active).toBe(true);

      // Clear missile to test hold behavior
      engine.gameState.m2Active = false;
      getLoopFn()(); // still holding — should NOT fire
      expect(engine.gameState.m2Active).toBe(false);

      vi.useRealTimers();
    });

    it("edge-triggers remote mine", () => {
      engine = new HexRaidEngine(canvas, channel, "hex_raid", true, null);
      setupFlying(engine, channel);

      engine.remoteInputs.mine = true;
      getLoopFn()();
      const mineCount = engine.gameState.mineCount;

      // Still holding — no second mine
      getLoopFn()();
      expect(engine.gameState.mineCount).toBe(mineCount);

      vi.useRealTimers();
    });
  });

  describe("DataChannel resilience", () => {
    it("handles closed channel without throwing", () => {
      engine = new HexRaidEngine(canvas, channel, "hex_raid", false, null);
      engine.start();

      channel.readyState = "closed";

      // Should not throw
      expect(() => {
        engine._safeSend(encodePlayerInput(INPUT_KEY.LEFT, true));
      }).not.toThrow();
    });

    it("handles channel send error without throwing", () => {
      engine = new HexRaidEngine(canvas, channel, "hex_raid", true, null);
      engine.start();

      channel.send.mockImplementation(() => {
        throw new Error("send failed");
      });

      expect(() => {
        engine._safeSend(encodePlayerInput(INPUT_KEY.LEFT, true));
      }).not.toThrow();
    });
  });

  describe("peer phase audio", () => {
    it("plays countdown audio on phase transition", () => {
      engine = new HexRaidEngine(canvas, channel, "hex_raid", false, null);
      engine.start();

      // First send a WAITING state
      const waitingState = {
        jet1X: 320,
        jet1Y: 400,
        jet1Speed: 2,
        jet1Fuel: 200,
        jet1Lives: 3,
        jet1Alive: true,
        jet1Invuln: false,
        jet1Respawning: false,
        jet2X: 340,
        jet2Y: 380,
        jet2Speed: 2,
        jet2Fuel: 200,
        jet2Lives: 3,
        jet2Alive: true,
        jet2Invuln: false,
        jet2Respawning: false,
        m1X: 0,
        m1Y: 0,
        m1Active: false,
        m2X: 0,
        m2Y: 0,
        m2Active: false,
        enemies: [],
        enemyCount: 0,
        fuels: [],
        fuelCount: 0,
        mines: [],
        mineCount: 0,
        bridgeY: 50,
        bridgeHp: 3,
        bridgeActive: true,
        score1: 0,
        score2: 0,
        phase: PHASE.WAITING,
        countdown: 0,
        section: 0,
        scrollY: 0,
        mode: GAME_MODE.RIVER_DUEL,
        seed: 42,
      };

      const handler = channel.addEventListener.mock.calls.find((c) => c[0] === "message")[1];
      handler({ data: encodeGameState(waitingState) });

      // Then send COUNTDOWN
      handler({
        data: encodeGameState({ ...waitingState, phase: PHASE.COUNTDOWN }),
      });

      expect(engine.audio.playCountdown).toHaveBeenCalled();
    });
  });
});
