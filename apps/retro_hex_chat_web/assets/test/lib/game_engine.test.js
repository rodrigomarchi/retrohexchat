import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import {
  encodeGameMessage,
  decodeGameMessage,
  isGameMessage,
  GAME_MSG,
  GameEngine,
} from "../../js/lib/game_engine.js";

describe("game_engine", () => {
  describe("encodeGameMessage", () => {
    it("encodes type byte + JSON payload", () => {
      const buffer = encodeGameMessage(GAME_MSG.GAME_STATE, { tick: 42 });
      const view = new Uint8Array(buffer);

      expect(view[0]).toBe(0x80);
      const json = new TextDecoder().decode(view.slice(1));
      expect(JSON.parse(json)).toEqual({ tick: 42 });
    });

    it("encodes empty payload", () => {
      const buffer = encodeGameMessage(GAME_MSG.GAME_READY, {});
      const view = new Uint8Array(buffer);

      expect(view[0]).toBe(0x84);
      const json = new TextDecoder().decode(view.slice(1));
      expect(JSON.parse(json)).toEqual({});
    });
  });

  describe("decodeGameMessage", () => {
    it("decodes valid game message", () => {
      const buffer = encodeGameMessage(GAME_MSG.PLAYER_INPUT, {
        key: "ArrowUp",
        pressed: true,
      });
      const msg = decodeGameMessage(buffer);

      expect(msg).not.toBeNull();
      expect(msg.type).toBe(GAME_MSG.PLAYER_INPUT);
      expect(msg.payload).toEqual({ key: "ArrowUp", pressed: true });
    });

    it("returns null for non-game message (type < 0x80)", () => {
      const buffer = new ArrayBuffer(5);
      const view = new Uint8Array(buffer);
      view[0] = 0x01; // file transfer type
      expect(decodeGameMessage(buffer)).toBeNull();
    });

    it("returns null for empty buffer", () => {
      expect(decodeGameMessage(new ArrayBuffer(0))).toBeNull();
    });

    it("handles message with only type byte (no payload)", () => {
      const buffer = new ArrayBuffer(1);
      const view = new Uint8Array(buffer);
      view[0] = 0x84;
      const msg = decodeGameMessage(buffer);

      expect(msg).not.toBeNull();
      expect(msg.type).toBe(0x84);
      expect(msg.payload).toEqual({});
    });
  });

  describe("isGameMessage", () => {
    it("returns true for game messages (type >= 0x80)", () => {
      const buffer = encodeGameMessage(GAME_MSG.GAME_STATE, {});
      expect(isGameMessage(buffer)).toBe(true);
    });

    it("returns false for file transfer messages (type < 0x80)", () => {
      const buffer = new ArrayBuffer(5);
      const view = new Uint8Array(buffer);
      view[0] = 0x01;
      expect(isGameMessage(buffer)).toBe(false);
    });

    it("returns false for empty buffer", () => {
      expect(isGameMessage(new ArrayBuffer(0))).toBe(false);
    });
  });

  describe("GAME_MSG constants", () => {
    it("has correct values", () => {
      expect(GAME_MSG.GAME_STATE).toBe(0x80);
      expect(GAME_MSG.PLAYER_INPUT).toBe(0x81);
      expect(GAME_MSG.GAME_START).toBe(0x82);
      expect(GAME_MSG.GAME_END).toBe(0x83);
      expect(GAME_MSG.GAME_READY).toBe(0x84);
    });
  });

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
    });

    it("starts and sends GAME_START as host", () => {
      engine = new GameEngine(canvas, channel, "hex_pong", true);
      engine.start();

      expect(engine.running).toBe(true);
      expect(channel.addEventListener).toHaveBeenCalledWith("message", expect.any(Function));
      expect(channel.send).toHaveBeenCalledTimes(1);

      // Decode the sent message
      const sent = channel.send.mock.calls[0][0];
      const msg = decodeGameMessage(sent);
      expect(msg.type).toBe(GAME_MSG.GAME_START);
      expect(msg.payload.gameId).toBe("hex_pong");
    });

    it("starts and sends GAME_READY as peer", () => {
      engine = new GameEngine(canvas, channel, "hex_pong", false);
      engine.start();

      const sent = channel.send.mock.calls[0][0];
      const msg = decodeGameMessage(sent);
      expect(msg.type).toBe(GAME_MSG.GAME_READY);
    });

    it("stops cleanly", () => {
      engine = new GameEngine(canvas, channel, "hex_pong", true);
      engine.start();
      engine.stop();

      expect(engine.running).toBe(false);
      expect(channel.removeEventListener).toHaveBeenCalledWith("message", expect.any(Function));
    });

    it("renders stub on start", () => {
      engine = new GameEngine(canvas, channel, "hex_pong", true);
      engine.start();

      const ctx = canvas.getContext();
      expect(ctx.fillRect).toHaveBeenCalled();
      expect(ctx.fillText).toHaveBeenCalled();
    });

    it("sends input as peer on keydown", () => {
      engine = new GameEngine(canvas, channel, "light_trails", false);
      engine.start();

      // Simulate keydown
      const event = new KeyboardEvent("keydown", { key: "ArrowUp" });
      Object.defineProperty(event, "preventDefault", {
        value: vi.fn(),
      });
      document.dispatchEvent(event);

      // Should have sent GAME_READY + PLAYER_INPUT
      expect(channel.send).toHaveBeenCalledTimes(2);
      const inputMsg = decodeGameMessage(channel.send.mock.calls[1][0]);
      expect(inputMsg.type).toBe(GAME_MSG.PLAYER_INPUT);
      expect(inputMsg.payload.key).toBe("ArrowUp");
      expect(inputMsg.payload.pressed).toBe(true);
    });

    it("does not send input as host", () => {
      engine = new GameEngine(canvas, channel, "hex_pong", true);
      engine.start();

      const event = new KeyboardEvent("keydown", { key: "ArrowUp" });
      Object.defineProperty(event, "preventDefault", {
        value: vi.fn(),
      });
      document.dispatchEvent(event);

      // Only GAME_START was sent, not PLAYER_INPUT
      expect(channel.send).toHaveBeenCalledTimes(1);
    });
  });
});
