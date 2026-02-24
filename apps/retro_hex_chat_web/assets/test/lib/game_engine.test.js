import { describe, it, expect, vi, beforeEach } from "vitest";
import {
  GameEngine,
  encodeGameMessage,
  decodeGameMessage,
  isGameMessage,
  GAME_MSG,
} from "../../js/lib/game_engine.js";

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

  describe("encodeGameMessage / decodeGameMessage", () => {
    it("round-trips a game message", () => {
      const payload = { key: "ArrowUp", pressed: true };
      const buf = encodeGameMessage(GAME_MSG.PLAYER_INPUT, payload);
      const result = decodeGameMessage(buf);
      expect(result).not.toBeNull();
      expect(result.type).toBe(GAME_MSG.PLAYER_INPUT);
      expect(result.payload.key).toBe("ArrowUp");
      expect(result.payload.pressed).toBe(true);
    });

    it("returns null for empty buffer", () => {
      expect(decodeGameMessage(new ArrayBuffer(0))).toBeNull();
    });

    it("returns null for non-game message (type < 0x80)", () => {
      const buf = new ArrayBuffer(2);
      new Uint8Array(buf)[0] = 0x01;
      expect(decodeGameMessage(buf)).toBeNull();
    });

    it("handles type-only message (no payload)", () => {
      const buf = new ArrayBuffer(1);
      new Uint8Array(buf)[0] = GAME_MSG.GAME_READY;
      const result = decodeGameMessage(buf);
      expect(result).not.toBeNull();
      expect(result.type).toBe(GAME_MSG.GAME_READY);
    });
  });

  describe("isGameMessage", () => {
    it("returns true for game messages", () => {
      const buf = new ArrayBuffer(1);
      new Uint8Array(buf)[0] = 0x80;
      expect(isGameMessage(buf)).toBe(true);
    });

    it("returns false for non-game messages", () => {
      const buf = new ArrayBuffer(1);
      new Uint8Array(buf)[0] = 0x01;
      expect(isGameMessage(buf)).toBe(false);
    });

    it("returns false for empty buffer", () => {
      expect(isGameMessage(new ArrayBuffer(0))).toBe(false);
    });
  });
});
