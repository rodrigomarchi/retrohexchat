import { describe, it, expect, vi, afterEach } from "vitest";
import GameCanvasHook from "../../js/hooks/game_canvas_hook.js";
import { cleanupDOM } from "../helpers/hook_helper.js";

function createHookContext(canvasHTML = '<canvas width="640" height="480"></canvas>') {
  const el = document.createElement("div");
  el.innerHTML = canvasHTML;
  document.body.appendChild(el);

  const webrtcEl = document.createElement("div");
  webrtcEl.id = "game-webrtc";
  document.body.appendChild(webrtcEl);

  return {
    el,
    webrtcEl,
    pushEvent: vi.fn(),
    handleEvent: vi.fn(),
  };
}

describe("GameCanvasHook", () => {
  afterEach(() => {
    cleanupDOM();
  });

  describe("mounted", () => {
    it("registers game_start and game_end event handlers", () => {
      const ctx = createHookContext();
      const hook = Object.create(GameCanvasHook);
      Object.assign(hook, ctx);

      hook.mounted();

      expect(ctx.handleEvent).toHaveBeenCalledWith("game_start", expect.any(Function));
      expect(ctx.handleEvent).toHaveBeenCalledWith("game_end", expect.any(Function));
    });

    it("initializes engine and channel as null", () => {
      const ctx = createHookContext();
      const hook = Object.create(GameCanvasHook);
      Object.assign(hook, ctx);

      hook.mounted();

      expect(hook.engine).toBeNull();
      expect(hook.channel).toBeNull();
    });

    it("listens for game_channel_ready on webrtc element", () => {
      const ctx = createHookContext();
      const addSpy = vi.spyOn(ctx.webrtcEl, "addEventListener");

      const hook = Object.create(GameCanvasHook);
      Object.assign(hook, ctx);

      hook.mounted();

      expect(addSpy).toHaveBeenCalledWith("game_channel_ready", expect.any(Function));
    });

    it("picks up existing DataChannel from webrtc element", () => {
      const ctx = createHookContext();
      const mockChannel = { readyState: "open" };
      ctx.webrtcEl._gameDataChannel = mockChannel;

      const hook = Object.create(GameCanvasHook);
      Object.assign(hook, ctx);

      hook.mounted();

      expect(hook.channel).toBe(mockChannel);
    });
  });

  describe("game initialization", () => {
    it("does not init engine without game_id", () => {
      const ctx = createHookContext();
      const mockChannel = { readyState: "open", onmessage: null };
      ctx.webrtcEl._gameDataChannel = mockChannel;

      const hook = Object.create(GameCanvasHook);
      Object.assign(hook, ctx);

      hook.mounted();

      expect(hook.engine).toBeNull();
    });

    it("does not init engine without channel", () => {
      const ctx = createHookContext();
      const hook = Object.create(GameCanvasHook);
      Object.assign(hook, ctx);

      hook.mounted();

      // Simulate game_start event
      const startHandler = ctx.handleEvent.mock.calls.find((c) => c[0] === "game_start")[1];
      startHandler({ game_id: "hex_pong", is_host: true });

      expect(hook.engine).toBeNull();
    });
  });

  describe("game_end handler", () => {
    it("calls cleanup on game_end", () => {
      const ctx = createHookContext();
      const hook = Object.create(GameCanvasHook);
      Object.assign(hook, ctx);

      hook.mounted();

      // Set up a mock engine
      hook.engine = { stop: vi.fn() };

      const endHandler = ctx.handleEvent.mock.calls.find((c) => c[0] === "game_end")[1];
      endHandler();

      expect(hook.engine).toBeNull();
    });
  });

  describe("destroyed", () => {
    it("cleans up engine on destroy", () => {
      const ctx = createHookContext();
      const hook = Object.create(GameCanvasHook);
      Object.assign(hook, ctx);

      hook.mounted();

      const mockEngine = { stop: vi.fn() };
      hook.engine = mockEngine;

      hook.destroyed();

      expect(mockEngine.stop).toHaveBeenCalled();
      expect(hook.engine).toBeNull();
    });

    it("handles destroy without engine", () => {
      const ctx = createHookContext();
      const hook = Object.create(GameCanvasHook);
      Object.assign(hook, ctx);

      hook.mounted();

      expect(() => hook.destroyed()).not.toThrow();
    });
  });
});
