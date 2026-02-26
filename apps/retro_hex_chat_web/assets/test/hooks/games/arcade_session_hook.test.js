import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { ArcadeSessionHook } from "../../../js/hooks/games/arcade_iframe_hook";

describe("ArcadeSessionHook", () => {
  let hook;
  let eventHandlers;

  beforeEach(() => {
    vi.useFakeTimers();

    eventHandlers = {};

    hook = {
      ...ArcadeSessionHook,
      pushEvent: vi.fn(),
      handleEvent: vi.fn((event, handler) => {
        eventHandlers[event] = handler;
      }),
    };
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it("registers arcade_close_tab and open_game_window handlers on mount", () => {
    hook.mounted();

    expect(hook.handleEvent).toHaveBeenCalledWith("arcade_close_tab", expect.any(Function));
    expect(hook.handleEvent).toHaveBeenCalledWith("open_game_window", expect.any(Function));
  });

  describe("open_game_window", () => {
    it("opens a new window with the given URL", () => {
      const mockWindow = { closed: false };
      const openSpy = vi.spyOn(window, "open").mockReturnValue(mockWindow);

      hook.mounted();
      eventHandlers["open_game_window"]({ url: "/arcade/token/doom" });

      expect(openSpy).toHaveBeenCalledWith("/arcade/token/doom", "_blank");
      openSpy.mockRestore();
    });

    it("pushes game_window_blocked when popup is blocked", () => {
      const openSpy = vi.spyOn(window, "open").mockReturnValue(null);

      hook.mounted();
      eventHandlers["open_game_window"]({ url: "/arcade/token/doom" });

      expect(hook.pushEvent).toHaveBeenCalledWith("game_window_blocked", {});
      openSpy.mockRestore();
    });

    it("does not start polling when popup is blocked", () => {
      const openSpy = vi.spyOn(window, "open").mockReturnValue(null);

      hook.mounted();
      eventHandlers["open_game_window"]({ url: "/arcade/token/doom" });

      // Advance time — no polling should fire
      vi.advanceTimersByTime(5000);

      // Only game_window_blocked should have been pushed, not game_window_closed
      expect(hook.pushEvent).toHaveBeenCalledTimes(1);
      expect(hook.pushEvent).toHaveBeenCalledWith("game_window_blocked", {});
      openSpy.mockRestore();
    });
  });

  describe("window polling", () => {
    it("detects window close after polling interval", () => {
      const mockWindow = { closed: false };
      const openSpy = vi.spyOn(window, "open").mockReturnValue(mockWindow);

      hook.mounted();
      eventHandlers["open_game_window"]({ url: "/arcade/token/doom" });

      // Window not closed yet
      vi.advanceTimersByTime(1000);
      expect(hook.pushEvent).not.toHaveBeenCalled();

      // Window closes
      mockWindow.closed = true;
      vi.advanceTimersByTime(1000);
      expect(hook.pushEvent).toHaveBeenCalledWith("game_window_closed", {});

      openSpy.mockRestore();
    });

    it("stops polling after detecting window close", () => {
      const mockWindow = { closed: false };
      const openSpy = vi.spyOn(window, "open").mockReturnValue(mockWindow);

      hook.mounted();
      eventHandlers["open_game_window"]({ url: "/arcade/token/doom" });

      mockWindow.closed = true;
      vi.advanceTimersByTime(1000);
      expect(hook.pushEvent).toHaveBeenCalledTimes(1);

      // Further ticks should not push again
      vi.advanceTimersByTime(5000);
      expect(hook.pushEvent).toHaveBeenCalledTimes(1);

      openSpy.mockRestore();
    });

    it("handles cross-origin SecurityError on window.closed", () => {
      const mockWindow = {};
      Object.defineProperty(mockWindow, "closed", {
        get() {
          throw new DOMException("Blocked", "SecurityError");
        },
      });
      const openSpy = vi.spyOn(window, "open").mockReturnValue(mockWindow);

      hook.mounted();
      eventHandlers["open_game_window"]({ url: "/arcade/token/doom" });

      // Should treat SecurityError as window closed
      vi.advanceTimersByTime(1000);
      expect(hook.pushEvent).toHaveBeenCalledWith("game_window_closed", {});

      openSpy.mockRestore();
    });
  });

  describe("cleanup", () => {
    it("stops polling on destroyed", () => {
      const mockWindow = { closed: false };
      const openSpy = vi.spyOn(window, "open").mockReturnValue(mockWindow);

      hook.mounted();
      eventHandlers["open_game_window"]({ url: "/arcade/token/doom" });

      hook.destroyed();

      mockWindow.closed = true;
      vi.advanceTimersByTime(5000);
      expect(hook.pushEvent).not.toHaveBeenCalled();

      openSpy.mockRestore();
    });

    it("stops polling on arcade_close_tab", () => {
      const mockWindow = { closed: false };
      const openSpy = vi.spyOn(window, "open").mockReturnValue(mockWindow);
      const closeSpy = vi.spyOn(window, "close").mockImplementation(() => {});

      hook.mounted();
      eventHandlers["open_game_window"]({ url: "/arcade/token/doom" });

      eventHandlers["arcade_close_tab"]();

      mockWindow.closed = true;
      vi.advanceTimersByTime(5000);
      // game_window_closed should NOT be pushed — polling was stopped
      expect(hook.pushEvent).not.toHaveBeenCalled();

      openSpy.mockRestore();
      closeSpy.mockRestore();
    });
  });
});
