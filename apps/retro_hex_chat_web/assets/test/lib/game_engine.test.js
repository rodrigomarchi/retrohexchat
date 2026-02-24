import { describe, it, expect, vi, beforeEach } from "vitest";
import { GameEngine } from "../../js/lib/game_engine.js";

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
    font: "",
    textAlign: "",
    fillRect: vi.fn(),
    strokeRect: vi.fn(),
    fillText: vi.fn(),
  };
  canvas.getContext = vi.fn(() => mockCtx);
  return canvas;
}

describe("GameEngine", () => {
  let engine;
  let channel;
  let canvas;

  beforeEach(() => {
    channel = createMockChannel();
    canvas = createMockCanvas();
  });

  describe("_safeSend", () => {
    it("sends data when channel is open", () => {
      engine = new GameEngine(canvas, channel, "test", true);
      const data = new ArrayBuffer(4);
      engine._safeSend(data);
      expect(channel.send).toHaveBeenCalledWith(data);
    });

    it("does not send when channel is closed", () => {
      channel.readyState = "closed";
      engine = new GameEngine(canvas, channel, "test", true);
      engine._safeSend(new ArrayBuffer(1));
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
    });
  });
});
