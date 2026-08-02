import { describe, it, expect, beforeEach, vi } from "vitest";
import WindowManagerHook from "../../../js/hooks/ui/window_manager_hook";

// The engine's behaviour is covered in test/lib/window_manager/window_manager.test.js.
// What matters here is only the seam: that the hook hands LiveView's two
// capabilities to the engine and maps the lifecycle onto it.
describe("WindowManagerHook", () => {
  let hook;
  let el;

  beforeEach(() => {
    el = document.createElement("div");
    el.innerHTML = '<div class="desktop__workspace"></div>';
    document.body.appendChild(el);

    hook = {
      ...WindowManagerHook,
      el,
      pushEvent: vi.fn(),
      handleEvent: vi.fn(),
    };
  });

  it("mounts an engine over its own element", () => {
    hook.mounted();

    expect(hook.wm).toBeTruthy();
    expect(hook.wm.el).toBe(el);
  });

  it("gives the engine a pushEvent channel", () => {
    hook.mounted();

    hook.wm.pushEvent("window_open", { id: "chat" });

    expect(hook.pushEvent).toHaveBeenCalledWith("window_open", { id: "chat" });
  });

  it("forwards server window_command payloads to the engine", () => {
    hook.mounted();

    const [event, callback] = hook.handleEvent.mock.calls[0];
    expect(event).toBe("window_command");

    hook.wm.command = vi.fn();
    const payload = { action: "focus", id: "chat" };
    callback(payload);

    expect(hook.wm.command).toHaveBeenCalledWith("focus", "chat", null, payload);
  });

  it("maps the LiveView lifecycle onto the engine", () => {
    hook.mounted();

    hook.wm.reconcile = vi.fn();
    hook.wm.destroy = vi.fn();

    hook.updated();
    expect(hook.wm.reconcile).toHaveBeenCalled();

    hook.destroyed();
    expect(hook.wm.destroy).toHaveBeenCalled();
  });
});
