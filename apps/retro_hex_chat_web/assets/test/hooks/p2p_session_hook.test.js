import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import P2PSessionHook from "../../js/hooks/p2p_session_hook";

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
});
