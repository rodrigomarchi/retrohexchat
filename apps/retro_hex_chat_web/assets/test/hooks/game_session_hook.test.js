import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import GameSessionHook from "../../js/hooks/game_session_hook";

describe("GameSessionHook", () => {
  let hook;
  let addSpy;
  let removeSpy;

  beforeEach(() => {
    addSpy = vi.spyOn(window, "addEventListener");
    removeSpy = vi.spyOn(window, "removeEventListener");

    hook = {
      ...GameSessionHook,
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

  it("pushes game_leave event on beforeunload", () => {
    hook.mounted();

    const handler = addSpy.mock.calls.find((call) => call[0] === "beforeunload")[1];
    handler();

    expect(hook.pushEvent).toHaveBeenCalledWith("game_leave", {});
  });

  it("registers game_close_tab handler on mount", () => {
    hook.mounted();

    expect(hook.handleEvent).toHaveBeenCalledWith("game_close_tab", expect.any(Function));
  });

  it("game_close_tab removes beforeunload and closes window", () => {
    const closeSpy = vi.spyOn(window, "close").mockImplementation(() => {});
    hook.mounted();

    const callback = hook.handleEvent.mock.calls.find((call) => call[0] === "game_close_tab")[1];
    callback();

    expect(removeSpy).toHaveBeenCalledWith("beforeunload", hook._beforeUnloadHandler);
    expect(closeSpy).toHaveBeenCalled();
    closeSpy.mockRestore();
  });
});
