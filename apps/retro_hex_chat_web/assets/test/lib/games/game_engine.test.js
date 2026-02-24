import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { GameEngine } from "../../../js/lib/game_engine.js";

describe("game_engine", () => {
  describe("GameEngine", () => {
    let canvas;
    let channel;
    let engine;
    let ctx;

    beforeEach(() => {
      ctx = {
        fillStyle: "",
        strokeStyle: "",
        lineWidth: 0,
        font: "",
        textAlign: "",
        fillRect: vi.fn(),
        fillText: vi.fn(),
        strokeRect: vi.fn(),
      };

      canvas = {
        width: 640,
        height: 480,
        getContext: vi.fn(() => ctx),
      };

      // Stub getComputedStyle
      vi.spyOn(globalThis, "getComputedStyle").mockReturnValue({
        getPropertyValue: () => "",
      });

      channel = {
        readyState: "open",
        addEventListener: vi.fn(),
        removeEventListener: vi.fn(),
        send: vi.fn(),
      };
    });

    afterEach(() => {
      vi.restoreAllMocks();
      if (engine) {
        engine.stop();
        engine = null;
      }
    });

    it("creates with correct properties", () => {
      engine = new GameEngine(canvas, channel, "hex_pong", true);
      expect(engine.gameId).toBe("hex_pong");
      expect(engine.isHost).toBe(true);
      expect(engine.running).toBe(false);
      expect(engine.animFrame).toBeNull();
    });

    it("start() wires event listeners and sets running", () => {
      engine = new GameEngine(canvas, channel, "hex_pong", true);
      engine.start();

      expect(engine.running).toBe(true);
      expect(channel.addEventListener).toHaveBeenCalledWith("message", expect.any(Function));
    });

    it("start() does not send any messages (no protocol in base)", () => {
      engine = new GameEngine(canvas, channel, "hex_pong", true);
      engine.start();
      expect(channel.send).not.toHaveBeenCalled();
    });

    it("start() does not send messages as peer either", () => {
      engine = new GameEngine(canvas, channel, "hex_pong", false);
      engine.start();
      expect(channel.send).not.toHaveBeenCalled();
    });

    it("stop() cleans up listeners and sets running false", () => {
      engine = new GameEngine(canvas, channel, "hex_pong", true);
      engine.start();
      engine.stop();

      expect(engine.running).toBe(false);
      expect(channel.removeEventListener).toHaveBeenCalledWith("message", expect.any(Function));
    });

    it("stop() cancels animation frame", () => {
      engine = new GameEngine(canvas, channel, "hex_pong", true);
      engine.start();
      engine.animFrame = 42;
      const cancelSpy = vi.spyOn(globalThis, "cancelAnimationFrame").mockImplementation(() => {});
      engine.stop();

      expect(cancelSpy).toHaveBeenCalledWith(42);
      expect(engine.animFrame).toBeNull();
    });

    it("_renderStub draws to canvas", () => {
      engine = new GameEngine(canvas, channel, "hex_pong", true);
      engine._renderStub();

      expect(ctx.fillRect).toHaveBeenCalled();
      expect(ctx.fillText).toHaveBeenCalled();
    });

    it("_render calls _renderStub by default", () => {
      engine = new GameEngine(canvas, channel, "hex_pong", true);
      const spy = vi.spyOn(engine, "_renderStub");
      engine._render();
      expect(spy).toHaveBeenCalled();
    });

    it("_safeSend sends when channel is open", () => {
      engine = new GameEngine(canvas, channel, "hex_pong", true);
      const data = new ArrayBuffer(4);
      engine._safeSend(data);
      expect(channel.send).toHaveBeenCalledWith(data);
    });

    it("_safeSend does not send when channel is closed", () => {
      channel.readyState = "closed";
      engine = new GameEngine(canvas, channel, "hex_pong", true);
      engine._safeSend(new ArrayBuffer(1));
      expect(channel.send).not.toHaveBeenCalled();
    });

    it("_safeSend catches errors on send", () => {
      channel.send = () => {
        throw new Error("closed");
      };
      engine = new GameEngine(canvas, channel, "hex_pong", true);
      expect(() => engine._safeSend(new ArrayBuffer(1))).not.toThrow();
    });

    it("_handleMessage is a no-op stub", () => {
      engine = new GameEngine(canvas, channel, "hex_pong", true);
      // Should not throw
      expect(() => engine._handleMessage({ data: new ArrayBuffer(1) })).not.toThrow();
    });

    it("_handleKeyDown is a no-op stub", () => {
      engine = new GameEngine(canvas, channel, "hex_pong", true);
      expect(() => engine._handleKeyDown(new Event("keydown"))).not.toThrow();
    });

    it("_handleKeyUp is a no-op stub", () => {
      engine = new GameEngine(canvas, channel, "hex_pong", true);
      expect(() => engine._handleKeyUp(new Event("keyup"))).not.toThrow();
    });

    it("bound handlers reference instance methods", () => {
      engine = new GameEngine(canvas, channel, "hex_pong", true);
      // The bound functions should exist and be callable
      expect(typeof engine._boundOnMessage).toBe("function");
      expect(typeof engine._boundOnKeyDown).toBe("function");
      expect(typeof engine._boundOnKeyUp).toBe("function");
    });
  });
});
