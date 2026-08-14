import { describe, expect, it, vi } from "vitest";

import { lazyFeatureHooks } from "../../../js/hooks/lazy_feature_hooks.js";
import { createRetroGameCanvasHook } from "../../../js/hooks/games/retro_game_canvas_hook.js";

function mountContext(overrides = {}) {
  const el = document.createElement("div");
  el.dataset.gameId = overrides.gameId || "hex_pong";
  el.dataset.difficulty = overrides.difficulty || "normal";

  const canvas = document.createElement("canvas");
  el.appendChild(canvas);

  return { el, canvas };
}

function buildEngine(overrides = {}) {
  return {
    start: vi.fn(),
    stop: vi.fn(),
    beginMatch: vi.fn(() => true),
    ...overrides,
  };
}

function buildHook(engineFactory, context = mountContext()) {
  return Object.assign(
    Object.create(createRetroGameCanvasHook({ engineFactory })),
    {
      pushEvent: vi.fn(),
      handleEvent: vi.fn(),
    },
    context,
  );
}

describe("RetroGameCanvasHook lazy registration", () => {
  it("registers the server event contract", () => {
    const meta = lazyFeatureHooks.RetroGameCanvasHook.__lazyFeature;

    expect(meta.name).toBe("RetroGameCanvasHook");
    expect(meta.serverEvents).toEqual(["retro_game_begin", "retro_game_stop"]);
    expect(meta.readyEvent).toBe("retro_game_canvas_ready");
    expect(meta.reason).toMatch(/solo/i);
  });
});

describe("RetroGameCanvasHook", () => {
  it("loads a solo engine and announces readiness", async () => {
    const engine = buildEngine();
    const engineFactory = vi.fn(() => Promise.resolve(engine));
    const hook = buildHook(engineFactory);

    hook.mounted();
    await hook._enginePromise;

    expect(engineFactory).toHaveBeenCalledWith(
      expect.objectContaining({
        canvas: hook.canvas,
        gameId: "hex_pong",
        mode: "solo",
        isHost: true,
        difficulty: "normal",
      }),
    );
    expect(engine.start).toHaveBeenCalledOnce();
    expect(hook.pushEvent).toHaveBeenCalledWith("retro_game_canvas_ready", {
      game_id: "hex_pong",
    });
  });

  it("starts the match from the server begin event", async () => {
    const engine = buildEngine();
    const eventHandlers = {};
    const hook = buildHook(() => Promise.resolve(engine));
    const focusSpy = vi.spyOn(hook.el, "focus");
    hook.handleEvent.mockImplementation((event, cb) => {
      eventHandlers[event] = cb;
    });

    hook.mounted();
    await hook._enginePromise;
    eventHandlers.retro_game_begin({ game_id: "hex_pong", difficulty: "hard" });

    expect(engine.beginMatch).toHaveBeenCalledWith({ difficulty: "hard" });
    expect(focusSpy).toHaveBeenCalledOnce();
  });

  it("focuses the game surface when the player clicks the canvas area", async () => {
    const engine = buildEngine();
    const hook = buildHook(() => Promise.resolve(engine));
    const focusSpy = vi.spyOn(hook.el, "focus");

    hook.mounted();
    await hook._enginePromise;
    hook.el.dispatchEvent(new Event("pointerdown", { bubbles: true }));

    expect(focusSpy).toHaveBeenCalledOnce();
  });

  it("ignores begin events for another game", async () => {
    const engine = buildEngine();
    const eventHandlers = {};
    const hook = buildHook(() => Promise.resolve(engine));
    hook.handleEvent.mockImplementation((event, cb) => {
      eventHandlers[event] = cb;
    });

    hook.mounted();
    await hook._enginePromise;
    eventHandlers.retro_game_begin({ game_id: "light_trails", difficulty: "hard" });

    expect(engine.beginMatch).not.toHaveBeenCalled();
  });

  it("stops the engine on server stop and destroy", async () => {
    const engine = buildEngine();
    const eventHandlers = {};
    const hook = buildHook(() => Promise.resolve(engine));
    hook.handleEvent.mockImplementation((event, cb) => {
      eventHandlers[event] = cb;
    });

    hook.mounted();
    await hook._enginePromise;
    eventHandlers.retro_game_stop({ game_id: "hex_pong" });
    hook.destroyed();

    expect(engine.stop).toHaveBeenCalledOnce();
    expect(hook.engine).toBeNull();
  });
});
