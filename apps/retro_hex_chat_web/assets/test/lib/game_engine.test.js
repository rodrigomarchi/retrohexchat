import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { GameEngine, SEND_HIGH_WATER_BYTES } from "../../js/lib/game_engine.js";
import { FIXED_STEP_MS } from "../../js/lib/games/frame_clock.js";
import { decodeInputState, encodeInputState, packInputs } from "../../js/lib/games/net_protocol.js";
import { createLocalTransport } from "../../js/lib/games/transport.js";

function createMockChannel() {
  return {
    readyState: "open",
    bufferedAmount: 0,
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
    font: "",
    textAlign: "",
    fillRect: vi.fn(),
    strokeRect: vi.fn(),
    fillText: vi.fn(),
  };
  canvas.getContext = vi.fn(() => mockCtx);
  return canvas;
}

/** A game with held keys and one smoothed coordinate. */
class TestEngine extends GameEngine {
  static INPUT_BITS = { up: 0, down: 1 };
  static INTERPOLATION = { keys: ["x"] };

  constructor(canvas, channel, gameId, isHost) {
    super(canvas, channel, gameId, isHost);
    this.gameState = { x: 0, score: 0 };
    this.localInputs = { up: false, down: false };
    this.remoteInputs = { up: false, down: false };
    this.steps = 0;
    this.idleSteps = 0;
    this.paints = 0;
  }

  _gameLoop() {
    this.steps += 1;
  }

  _idleStep() {
    this.idleSteps += 1;
  }

  _renderState() {
    this.paints += 1;
  }
}

describe("GameEngine", () => {
  let engine;
  let channel;
  let canvas;

  beforeEach(() => {
    channel = createMockChannel();
    canvas = createMockCanvas();
    vi.stubGlobal(
      "requestAnimationFrame",
      vi.fn(() => 1),
    );
    vi.stubGlobal("cancelAnimationFrame", vi.fn());
  });

  afterEach(() => {
    if (engine) engine.stop();
    engine = null;
    vi.unstubAllGlobals();
  });

  describe("_safeSend", () => {
    it("stores the normalized transport and runtime mode", () => {
      engine = new GameEngine(canvas, channel, "test", true, { mode: "solo" });

      expect(engine.transport.kind).toBe("p2p");
      expect(engine.channel).toBe(engine.transport);
      expect(engine.mode).toBe("solo");
    });

    it("reports local runtime state separately from DataChannel state", () => {
      engine = new GameEngine(canvas, createLocalTransport(), "test", true, { mode: "solo" });

      expect(engine._transportTelemetryState()).toBe("local");
    });

    it("sends data when channel is open", () => {
      engine = new GameEngine(canvas, channel, "test", true);
      const data = new ArrayBuffer(4);
      expect(engine._safeSend(data)).toBe(true);
      expect(channel.send).toHaveBeenCalledWith(data);
    });

    it("does not send when channel is closed", () => {
      channel.readyState = "closed";
      engine = new GameEngine(canvas, channel, "test", true);
      expect(engine._safeSend(new ArrayBuffer(1))).toBe(false);
      expect(channel.send).not.toHaveBeenCalled();
    });

    it("does not send when channel is closing", () => {
      channel.readyState = "closing";
      engine = new GameEngine(canvas, channel, "test", true);
      engine._safeSend(new ArrayBuffer(1));
      expect(channel.send).not.toHaveBeenCalled();
    });

    it("catches throw on channel that closes during send", () => {
      channel.send = () => {
        throw new Error("closing");
      };
      engine = new GameEngine(canvas, channel, "test", true);
      expect(() => engine._safeSend(new ArrayBuffer(1))).not.toThrow();
      expect(engine._safeSend(new ArrayBuffer(1))).toBe(false);
    });
  });

  describe("_sendState", () => {
    it("sends a snapshot while the channel is keeping up", () => {
      engine = new TestEngine(canvas, channel, "test", true);
      expect(engine._sendState(new ArrayBuffer(25))).toBe(true);
    });

    it("drops a snapshot once the channel is backed up", () => {
      channel.bufferedAmount = SEND_HIGH_WATER_BYTES;
      engine = new TestEngine(canvas, channel, "test", true);

      // Queuing behind a backlog only adds latency the game never recovers
      // from, and the next snapshot supersedes this one anyway.
      expect(engine._sendState(new ArrayBuffer(25))).toBe(false);
      expect(channel.send).not.toHaveBeenCalled();
    });
  });

  describe("_sendCommand", () => {
    it("repeats a one-shot message, because the channel is unreliable", () => {
      vi.useFakeTimers();
      engine = new TestEngine(canvas, channel, "test", true);
      engine.running = true;

      engine._sendCommand(new ArrayBuffer(4));
      expect(channel.send).toHaveBeenCalledTimes(1);

      vi.advanceTimersByTime(200);
      expect(channel.send).toHaveBeenCalledTimes(3);
      vi.useRealTimers();
    });

    it("stops repeating once the engine is torn down", () => {
      vi.useFakeTimers();
      engine = new TestEngine(canvas, channel, "test", true);
      engine.start();

      engine._sendCommand(new ArrayBuffer(4));
      engine.stop();
      vi.advanceTimersByTime(200);

      expect(channel.send).toHaveBeenCalledTimes(1);
      vi.useRealTimers();
    });
  });

  describe("ready handshake", () => {
    /** A ready message is one byte; the guest also sends 5-byte input masks. */
    const READY_BYTE = 0x84;
    const READY = () => {
      const buf = new ArrayBuffer(1);
      new DataView(buf).setUint8(0, READY_BYTE);
      return buf;
    };

    const readyPings = () =>
      channel.send.mock.calls.filter(
        ([buf]) => buf.byteLength === 1 && new DataView(buf).getUint8(0) === READY_BYTE,
      ).length;

    it("keeps announcing until the host answers", () => {
      vi.useFakeTimers();
      engine = new TestEngine(canvas, channel, "test", false);
      engine.start();

      engine._advertiseReady(READY);
      expect(readyPings()).toBe(1);

      // Nothing else restates this message, and the host does nothing until it
      // lands — a single send would hang the match on one dropped datagram.
      vi.advanceTimersByTime(1000);
      expect(readyPings()).toBeGreaterThan(3);
      vi.useRealTimers();
    });

    it("stops announcing on the first word from the host", () => {
      vi.useFakeTimers();
      engine = new TestEngine(canvas, channel, "test", false);
      engine.start();
      engine._advertiseReady(READY);

      const state = new ArrayBuffer(8);
      new DataView(state).setUint8(0, 0x80);
      engine._onChannelMessage({ data: state });

      const afterAnswer = readyPings();
      vi.advanceTimersByTime(2000);

      expect(readyPings()).toBe(afterAnswer);
      vi.useRealTimers();
    });

    it("never announces from the host side", () => {
      vi.useFakeTimers();
      engine = new TestEngine(canvas, channel, "test", true);
      engine.start();

      engine._advertiseReady(READY);
      vi.advanceTimersByTime(2000);

      expect(channel.send).not.toHaveBeenCalled();
      vi.useRealTimers();
    });

    it("stops announcing once the engine is torn down", () => {
      vi.useFakeTimers();
      engine = new TestEngine(canvas, channel, "test", false);
      engine.start();
      engine._advertiseReady(READY);
      engine.stop();

      const afterStop = readyPings();
      vi.advanceTimersByTime(2000);

      expect(readyPings()).toBe(afterStop);
      vi.useRealTimers();
    });
  });

  describe("input transport", () => {
    it("sends the full held mask, not one message per key", () => {
      engine = new TestEngine(canvas, channel, "test", false);
      engine.localInputs = { up: true, down: true };
      engine._sendInputState();

      const decoded = decodeInputState(channel.send.mock.calls[0][0]);
      expect(decoded.mask).toBe(packInputs({ up: true, down: true }, TestEngine.INPUT_BITS));
    });

    it("restates a held mask every frame", () => {
      engine = new TestEngine(canvas, channel, "test", false);
      engine.localInputs = { up: true, down: false };

      engine._sendInputState();
      engine._sendInputState();

      // Losing one datagram must cost a step of staleness, never a stuck key.
      expect(channel.send).toHaveBeenCalledTimes(2);
    });

    it("stops restating an empty mask once the release has been repeated", () => {
      engine = new TestEngine(canvas, channel, "test", false);
      engine.localInputs.up = true;
      engine._sendInputState();
      engine.localInputs.up = false;
      channel.send.mockClear();

      for (let i = 0; i < 50; i++) engine._sendInputState();

      // The release is restated a few times, then the guest goes quiet.
      expect(channel.send.mock.calls.length).toBeGreaterThan(0);
      expect(channel.send.mock.calls.length).toBeLessThan(20);
    });

    it("says nothing when no key was ever held", () => {
      engine = new TestEngine(canvas, channel, "test", false);

      for (let i = 0; i < 50; i++) engine._sendInputState();

      // The host already assumes everything is released.
      expect(channel.send).not.toHaveBeenCalled();
    });

    it("never sends input from the host", () => {
      engine = new TestEngine(canvas, channel, "test", true);
      engine.localInputs = { up: true, down: false };
      engine._sendInputState();
      expect(channel.send).not.toHaveBeenCalled();
    });

    it("applies a received mask to remote inputs", () => {
      engine = new TestEngine(canvas, channel, "test", true);
      engine._receiveInputState(encodeInputState(1, 0b01));
      expect(engine.remoteInputs).toEqual({ up: true, down: false });
    });

    it("ignores a datagram that arrived out of order", () => {
      engine = new TestEngine(canvas, channel, "test", true);
      engine._receiveInputState(encodeInputState(5, 0b11));
      engine._receiveInputState(encodeInputState(4, 0b00));

      // Unordered delivery means stale input can land after fresh input.
      expect(engine.remoteInputs).toEqual({ up: true, down: true });
    });

    it("deduplicates the repeats of a discrete command", () => {
      engine = new TestEngine(canvas, channel, "test", true);
      const seen = [];
      engine._handleRemoteEdge = (code) => seen.push(code);

      const buf = new ArrayBuffer(4);
      const view = new DataView(buf);
      view.setUint8(0, 0x8f);
      view.setUint16(1, 3, true);
      view.setUint8(3, 2);

      engine._receiveInputEdge(buf);
      engine._receiveInputEdge(buf);

      expect(seen).toEqual([2]);
    });
  });

  describe("keyboard", () => {
    it("ignores auto-repeat", () => {
      engine = new TestEngine(canvas, channel, "test", false);
      const handled = [];
      engine._handleKeyDown = (event) => handled.push(event.key);

      engine._onKeyDown({ key: "ArrowUp", repeat: false, target: null });
      engine._onKeyDown({ key: "ArrowUp", repeat: true, target: null });

      expect(handled).toEqual(["ArrowUp"]);
    });

    it("leaves keystrokes aimed at a text field alone", () => {
      engine = new TestEngine(canvas, channel, "test", false);
      const handled = [];
      engine._handleKeyDown = (event) => handled.push(event.key);

      // The game runs in a window beside the chat composer.
      engine._onKeyDown({ key: "ArrowUp", repeat: false, target: { tagName: "INPUT" } });
      engine._onKeyDown({ key: "ArrowUp", repeat: false, target: { isContentEditable: true } });

      expect(handled).toEqual([]);
    });

    it("stops handled game keys before they reach global LiveView shortcuts", () => {
      engine = new TestEngine(canvas, channel, "test", false);
      engine._handleKeyDown = (event) => {
        if (event.key === "ArrowUp") event.preventDefault();
      };

      const globalShortcut = vi.fn();
      window.addEventListener("keydown", globalShortcut);

      engine.start();
      window.dispatchEvent(
        new KeyboardEvent("keydown", { key: "ArrowUp", bubbles: true, cancelable: true }),
      );

      expect(globalShortcut).not.toHaveBeenCalled();

      window.removeEventListener("keydown", globalShortcut);
    });

    it("captures active-game keys before already-registered LiveView window bindings", () => {
      engine = new TestEngine(canvas, channel, "test", false);
      engine._handleKeyDown = vi.fn();
      engine.setKeyboardCaptured(true);

      const liveViewWindowBinding = vi.fn();
      window.addEventListener("keydown", liveViewWindowBinding);

      engine.start();
      window.dispatchEvent(
        new KeyboardEvent("keydown", { key: "ArrowRight", bubbles: true, cancelable: true }),
      );

      expect(engine._handleKeyDown).toHaveBeenCalledOnce();
      expect(liveViewWindowBinding).not.toHaveBeenCalled();

      window.removeEventListener("keydown", liveViewWindowBinding);
    });

    it("lets non-game keys continue to global shortcuts", () => {
      engine = new TestEngine(canvas, channel, "test", false);
      engine._handleKeyDown = vi.fn();

      const globalShortcut = vi.fn();
      window.addEventListener("keydown", globalShortcut);

      engine.start();
      document.dispatchEvent(
        new KeyboardEvent("keydown", { key: "Meta", bubbles: true, cancelable: true }),
      );

      expect(globalShortcut).toHaveBeenCalledOnce();

      window.removeEventListener("keydown", globalShortcut);
    });

    it("lets text-entry keys continue to global listeners even during keyboard capture", () => {
      engine = new TestEngine(canvas, channel, "test", false);
      engine._handleKeyDown = vi.fn();
      engine.setKeyboardCaptured(true);

      const input = document.createElement("input");
      document.body.appendChild(input);
      const globalShortcut = vi.fn();
      window.addEventListener("keydown", globalShortcut);

      engine.start();
      input.dispatchEvent(
        new KeyboardEvent("keydown", { key: "ArrowUp", bubbles: true, cancelable: true }),
      );

      expect(engine._handleKeyDown).not.toHaveBeenCalled();
      expect(globalShortcut).toHaveBeenCalledOnce();

      window.removeEventListener("keydown", globalShortcut);
      input.remove();
    });
  });

  describe("presentation loop", () => {
    it("runs no simulation steps until the game starts stepping", () => {
      engine = new TestEngine(canvas, channel, "test", true);
      engine.start();

      engine._pump(0);
      engine._pump(FIXED_STEP_MS * 3);

      expect(engine.steps).toBe(0);
      expect(engine.idleSteps).toBe(3);
    });

    it("runs one step per elapsed step duration once started", () => {
      engine = new TestEngine(canvas, channel, "test", true);
      engine.start();
      engine._startSteps();

      engine._pump(0);
      engine._pump(FIXED_STEP_MS * 4);

      expect(engine.steps).toBe(4);
    });

    it("paints once per frame however many repaints were requested", () => {
      engine = new TestEngine(canvas, channel, "test", true);
      engine.start();

      engine._invalidate();
      engine._invalidate();
      engine._pump(0);

      expect(engine.paints).toBe(1);
    });

    it("keeps painting the guest while a snapshot is being interpolated", () => {
      engine = new TestEngine(canvas, channel, "test", false);
      engine.start();

      engine._pump(0);
      const before = engine.paints;

      engine._ingestSnapshot({ x: 0 });
      engine._ingestSnapshot({ x: 40 });

      // No new snapshot arrives, and the guest still has frames to draw.
      engine._pump(FIXED_STEP_MS);
      engine._pump(FIXED_STEP_MS * 2);

      expect(engine.paints).toBeGreaterThan(before + 1);
    });
  });

  describe("_ingestSnapshot", () => {
    it("lands non-motion fields immediately", () => {
      engine = new TestEngine(canvas, channel, "test", false);
      engine._ingestSnapshot({ x: 100, score: 7 });
      expect(engine.gameState.score).toBe(7);
    });

    it("runs a game-specific applier when one is given", () => {
      engine = new TestEngine(canvas, channel, "test", false);
      const apply = vi.fn(() => {
        engine.gameState.applied = true;
      });

      engine._ingestSnapshot({ x: 10 }, apply);

      expect(apply).toHaveBeenCalled();
      expect(engine.gameState.applied).toBe(true);
    });

    it("ignores a snapshot that failed to decode", () => {
      engine = new TestEngine(canvas, channel, "test", false);
      const apply = vi.fn();
      engine._ingestSnapshot(null, apply);
      expect(apply).not.toHaveBeenCalled();
    });
  });

  describe("stop", () => {
    it("releases the game's AudioContext", () => {
      engine = new TestEngine(canvas, channel, "test", true);
      engine.audio = { dispose: vi.fn() };
      engine.start();
      engine.stop();

      // Each context holds a real-time audio thread, and browsers cap how many
      // a page may open.
      expect(engine.audio.dispose).toHaveBeenCalledTimes(1);
    });

    it("tolerates a game whose audio has no teardown", () => {
      engine = new TestEngine(canvas, channel, "test", true);
      engine.audio = {};
      engine.start();
      expect(() => engine.stop()).not.toThrow();
    });

    it("stops the simulation and the frame loop", () => {
      engine = new TestEngine(canvas, channel, "test", true);
      engine.start();
      engine._startSteps();
      engine.stop();

      engine._pump(FIXED_STEP_MS * 10);
      expect(engine.steps).toBe(0);
      expect(engine.stepping).toBe(false);
    });
  });
});
