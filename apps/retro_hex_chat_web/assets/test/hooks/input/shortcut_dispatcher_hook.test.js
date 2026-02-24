import { mountHook, simulateEvent, cleanupDOM } from "../../helpers/hook_helper.js";
import ShortcutDispatcherHook from "../../../js/hooks/input/shortcut_dispatcher_hook.js";

describe("ShortcutDispatcherHook", () => {
  let hook;

  const testBindings = {
    toggle_search: { key: "f", modifiers: ["ctrl", "shift"] },
    next_channel: { key: "ArrowRight", modifiers: ["ctrl", "shift"] },
  };

  beforeEach(() => {
    hook = mountHook(ShortcutDispatcherHook);
    simulateEvent(hook, "update_bindings", { bindings: testBindings });
  });

  afterEach(() => {
    if (hook.destroyed) hook.destroyed();
    cleanupDOM();
  });

  // ── match ──────────────────────────────────────────────

  describe("shortcut matching", () => {
    it("pushes shortcut_action for matching key", () => {
      document.dispatchEvent(
        new KeyboardEvent("keydown", { key: "f", ctrlKey: true, shiftKey: true, bubbles: true }),
      );
      expect(hook.pushEvent).toHaveBeenCalledWith("shortcut_action", { action: "toggle_search" });
    });

    it("does not push for non-matching key", () => {
      hook.pushEvent.mockClear();
      document.dispatchEvent(
        new KeyboardEvent("keydown", { key: "z", ctrlKey: true, shiftKey: true, bubbles: true }),
      );
      const actionCalls = hook.pushEvent.mock.calls.filter((c) => c[0] === "shortcut_action");
      expect(actionCalls).toHaveLength(0);
    });

    it("ignores keys without Ctrl+Shift", () => {
      hook.pushEvent.mockClear();
      document.dispatchEvent(new KeyboardEvent("keydown", { key: "f", bubbles: true }));
      const actionCalls = hook.pushEvent.mock.calls.filter((c) => c[0] === "shortcut_action");
      expect(actionCalls).toHaveLength(0);
    });
  });

  // ── update_bindings ────────────────────────────────────

  describe("update_bindings", () => {
    it("updates bindings dynamically", () => {
      simulateEvent(hook, "update_bindings", {
        bindings: { new_action: { key: "n", modifiers: ["ctrl", "shift"] } },
      });

      document.dispatchEvent(
        new KeyboardEvent("keydown", { key: "n", ctrlKey: true, shiftKey: true, bubbles: true }),
      );
      expect(hook.pushEvent).toHaveBeenCalledWith("shortcut_action", { action: "new_action" });
    });
  });

  // ── bubble-up ──────────────────────────────────────────

  describe("bubble-up", () => {
    it("skips already-prevented events", () => {
      hook.pushEvent.mockClear();
      const event = new KeyboardEvent("keydown", {
        key: "f",
        ctrlKey: true,
        shiftKey: true,
        bubbles: true,
        cancelable: true,
      });
      event.preventDefault();
      document.dispatchEvent(event);

      const actionCalls = hook.pushEvent.mock.calls.filter((c) => c[0] === "shortcut_action");
      expect(actionCalls).toHaveLength(0);
    });
  });
});
