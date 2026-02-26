import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import ArcadeGameHook from "../../../js/hooks/games/arcade_game_hook";

describe("ArcadeGameHook", () => {
  let hook;
  let addSpy;
  let removeSpy;

  beforeEach(() => {
    addSpy = vi.spyOn(window, "addEventListener");
    removeSpy = vi.spyOn(window, "removeEventListener");

    const iframe = {
      addEventListener: vi.fn(),
      focus: vi.fn(),
    };

    hook = {
      ...ArcadeGameHook,
      el: { querySelector: vi.fn(() => iframe) },
      pushEvent: vi.fn(),
      handleEvent: vi.fn(),
    };
  });

  afterEach(() => {
    addSpy.mockRestore();
    removeSpy.mockRestore();
  });

  it("adds beforeunload listener on mount", () => {
    hook.mounted();

    expect(addSpy).toHaveBeenCalledWith("beforeunload", expect.any(Function));
  });

  it("removes beforeunload listener on destroy", () => {
    hook.mounted();
    hook.destroyed();

    expect(removeSpy).toHaveBeenCalledWith("beforeunload", expect.any(Function));
  });

  it("pushes game_window_closing event on beforeunload", () => {
    hook.mounted();

    const handler = addSpy.mock.calls.find((call) => call[0] === "beforeunload")[1];
    handler();

    expect(hook.pushEvent).toHaveBeenCalledWith("game_window_closing", {});
  });

  it("registers arcade_close_tab handler on mount", () => {
    hook.mounted();

    expect(hook.handleEvent).toHaveBeenCalledWith("arcade_close_tab", expect.any(Function));
  });

  it("focuses iframe on load", () => {
    hook.mounted();

    const iframe = hook.el.querySelector("iframe");
    const loadHandler = iframe.addEventListener.mock.calls.find((call) => call[0] === "load")[1];
    loadHandler();

    expect(iframe.focus).toHaveBeenCalled();
  });

  it("focuses iframe on mouseenter", () => {
    hook.mounted();

    const iframe = hook.el.querySelector("iframe");
    const enterHandler = iframe.addEventListener.mock.calls.find(
      (call) => call[0] === "mouseenter",
    )[1];
    enterHandler();

    expect(iframe.focus).toHaveBeenCalled();
  });

  it("handles missing iframe gracefully", () => {
    hook.el.querySelector = vi.fn(() => null);

    expect(() => hook.mounted()).not.toThrow();
    expect(addSpy).toHaveBeenCalledWith("beforeunload", expect.any(Function));
  });
});
