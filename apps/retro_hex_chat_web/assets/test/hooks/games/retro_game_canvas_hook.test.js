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

/** The engine is loaded once the hook says so to the server. */
const ready = (hook) =>
  vi.waitFor(() =>
    expect(hook.pushEvent).toHaveBeenCalledWith("retro_game_canvas_ready", expect.anything()),
  );

describe("RetroGameCanvasHook lazy registration", () => {
  it("registers the server event contract", () => {
    const meta = lazyFeatureHooks.RetroGameCanvasHook.__lazyFeature;

    expect(meta.name).toBe("RetroGameCanvasHook");
    expect(meta.serverEvents).toEqual([
      "retro_game_begin",
      "retro_game_stop",
      "retro_game_quit",
      "retro_game_pause",
      "retro_game_resume",
    ]);
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

  it("a match ended early gets a fresh engine, ready for the next one", async () => {
    const first = buildEngine();
    const second = buildEngine();
    const engineFactory = vi.fn().mockResolvedValueOnce(first).mockResolvedValueOnce(second);
    const eventHandlers = {};
    const hook = buildHook(engineFactory);
    hook.handleEvent.mockImplementation((event, cb) => {
      eventHandlers[event] = cb;
    });

    hook.mounted();
    await vi.waitFor(() => expect(hook.engine).toBe(first));
    eventHandlers.retro_game_stop({ game_id: "hex_pong" });
    await vi.waitFor(() => expect(hook.engine).toBe(second));

    expect(first.stop).toHaveBeenCalledOnce();
    expect(hook.engine).toBe(second);
    expect(
      hook.pushEvent.mock.calls.filter(([event]) => event === "retro_game_canvas_ready"),
    ).toHaveLength(2);

    hook.destroyed();
    expect(second.stop).toHaveBeenCalledOnce();
    expect(hook.engine).toBeNull();
  });

  it("ends the match as it stands on the server's quit event, and the engine's report goes up", async () => {
    let onGameEnd;
    const engine = buildEngine({
      quit: vi.fn(() => {
        onGameEnd({ score: { p1: 3, p2: 1 }, ended_early: true });
        return true;
      }),
    });
    const eventHandlers = {};
    const hook = buildHook((options) => {
      onGameEnd = options.onGameEnd;
      return Promise.resolve(engine);
    });
    hook.handleEvent.mockImplementation((event, cb) => {
      eventHandlers[event] = cb;
    });

    hook.mounted();
    await ready(hook);
    eventHandlers.retro_game_quit({ game_id: "other_game" });
    expect(engine.quit).not.toHaveBeenCalled();
    eventHandlers.retro_game_quit({ game_id: "hex_pong" });

    expect(engine.quit).toHaveBeenCalledOnce();
    expect(hook.pushEvent).toHaveBeenCalledWith("retro_game_result", {
      score: { p1: 3, p2: 1 },
      ended_early: true,
      game_id: "hex_pong",
    });
    expect(engine.stop).not.toHaveBeenCalled();
  });

  it("says so when the engine had no match left to end", async () => {
    const engine = buildEngine({ quit: vi.fn(() => false) });
    const eventHandlers = {};
    const hook = buildHook(() => Promise.resolve(engine));
    hook.handleEvent.mockImplementation((event, cb) => {
      eventHandlers[event] = cb;
    });

    hook.mounted();
    await ready(hook);
    eventHandlers.retro_game_quit({ game_id: "hex_pong" });

    expect(hook.pushEvent).toHaveBeenCalledWith("retro_game_stopped", { game_id: "hex_pong" });
  });

  it("holds and resumes the match on the server's pause and resume events", async () => {
    const engine = buildEngine({ pause: vi.fn(() => true), resume: vi.fn(() => true) });
    const eventHandlers = {};
    const hook = buildHook(() => Promise.resolve(engine));
    hook.handleEvent.mockImplementation((event, cb) => {
      eventHandlers[event] = cb;
    });

    hook.mounted();
    await ready(hook);
    eventHandlers.retro_game_pause({ game_id: "other_game" });
    expect(engine.pause).not.toHaveBeenCalled();
    eventHandlers.retro_game_pause({ game_id: "hex_pong" });
    eventHandlers.retro_game_resume({ game_id: "hex_pong" });

    expect(engine.pause).toHaveBeenCalledOnce();
    expect(engine.resume).toHaveBeenCalledOnce();
    hook.destroyed();
  });

  it("Esc in a running match holds it and asks for the menu, and the key goes no further", async () => {
    const engine = buildEngine({ stepping: true, pause: vi.fn(() => true) });
    const hook = buildHook(() => Promise.resolve(engine));
    const later = vi.fn();
    window.addEventListener("keydown", later);

    hook.mounted();
    await ready(hook);
    window.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", cancelable: true }));

    expect(engine.pause).toHaveBeenCalledOnce();
    expect(hook.pushEvent).toHaveBeenCalledWith("retro_games_menu", { game_id: "hex_pong" });
    expect(later).not.toHaveBeenCalled();

    engine.stepping = false;
    window.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", cancelable: true }));
    expect(engine.pause).toHaveBeenCalledOnce();
    expect(later).toHaveBeenCalledOnce();

    hook.destroyed();
    window.removeEventListener("keydown", later);
  });

  it("a tab put away mid-match holds it and asks for the menu", async () => {
    const engine = buildEngine({ stepping: true, pause: vi.fn(() => true) });
    const hook = buildHook(() => Promise.resolve(engine));
    const visibility = vi.spyOn(document, "visibilityState", "get").mockReturnValue("hidden");

    hook.mounted();
    await ready(hook);
    document.dispatchEvent(new Event("visibilitychange"));

    expect(engine.pause).toHaveBeenCalledOnce();
    expect(hook.pushEvent).toHaveBeenCalledWith("retro_games_menu", { game_id: "hex_pong" });
    visibility.mockRestore();
    hook.destroyed();
  });
});
