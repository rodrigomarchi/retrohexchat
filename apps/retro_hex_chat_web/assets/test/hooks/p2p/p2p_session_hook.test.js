import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import P2PSessionHook from "../../../js/hooks/p2p/p2p_session_hook";

describe("P2PSessionHook", () => {
  let hook;
  let addSpy;
  let removeSpy;

  beforeEach(() => {
    addSpy = vi.spyOn(window, "addEventListener");
    removeSpy = vi.spyOn(window, "removeEventListener");

    hook = {
      ...P2PSessionHook,
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

  it("pushes p2p_leave event on beforeunload", () => {
    hook.mounted();

    // Get the handler function that was registered
    const handler = addSpy.mock.calls.find((call) => call[0] === "beforeunload")[1];
    handler();

    expect(hook.pushEvent).toHaveBeenCalledWith("p2p_leave", {});
  });

  it("registers p2p_close_tab handler on mount", () => {
    hook.mounted();

    expect(hook.handleEvent).toHaveBeenCalledWith("p2p_close_tab", expect.any(Function));
  });

  it("p2p_close_tab removes beforeunload and closes window", () => {
    const closeSpy = vi.spyOn(window, "close").mockImplementation(() => {});
    hook.mounted();

    // Get the callback registered for p2p_close_tab
    const callback = hook.handleEvent.mock.calls.find((call) => call[0] === "p2p_close_tab")[1];
    callback();

    expect(removeSpy).toHaveBeenCalledWith("beforeunload", hook._beforeUnloadHandler);
    expect(closeSpy).toHaveBeenCalled();
    closeSpy.mockRestore();
  });
});
