import { mountHook, simulateEvent, cleanupDOM } from "../helpers/hook_helper.js";
import KeyBindingCaptureHook from "../../js/hooks/key_binding_capture_hook.js";

describe("KeyBindingCaptureHook", () => {
  let hook;

  beforeEach(() => {
    hook = mountHook(KeyBindingCaptureHook);
  });

  afterEach(() => {
    if (hook.destroyed) hook.destroyed();
    cleanupDOM();
  });

  it("captures key press after start_key_capture", () => {
    simulateEvent(hook, "start_key_capture", { action: "toggle_search" });
    document.dispatchEvent(
      new KeyboardEvent("keydown", { key: "f", ctrlKey: true, shiftKey: true, bubbles: true }),
    );
    expect(hook.pushEvent).toHaveBeenCalledWith("options_capture_key", {
      action: "toggle_search",
      key: "f",
      ctrlKey: true,
      altKey: false,
      shiftKey: true,
    });
  });

  it("ignores standalone modifier keys", () => {
    simulateEvent(hook, "start_key_capture", { action: "test" });
    hook.pushEvent.mockClear();
    document.dispatchEvent(new KeyboardEvent("keydown", { key: "Shift", bubbles: true }));
    const captureCalls = hook.pushEvent.mock.calls.filter((c) => c[0] === "options_capture_key");
    expect(captureCalls).toHaveLength(0);
  });

  it("stops capturing after first key press", () => {
    simulateEvent(hook, "start_key_capture", { action: "test" });
    document.dispatchEvent(new KeyboardEvent("keydown", { key: "a", bubbles: true }));
    hook.pushEvent.mockClear();
    document.dispatchEvent(new KeyboardEvent("keydown", { key: "b", bubbles: true }));
    const captureCalls = hook.pushEvent.mock.calls.filter((c) => c[0] === "options_capture_key");
    expect(captureCalls).toHaveLength(0);
  });

  it("stops capturing on stop_key_capture event", () => {
    simulateEvent(hook, "start_key_capture", { action: "test" });
    simulateEvent(hook, "stop_key_capture", {});
    hook.pushEvent.mockClear();
    document.dispatchEvent(new KeyboardEvent("keydown", { key: "a", bubbles: true }));
    const captureCalls = hook.pushEvent.mock.calls.filter((c) => c[0] === "options_capture_key");
    expect(captureCalls).toHaveLength(0);
  });
});
