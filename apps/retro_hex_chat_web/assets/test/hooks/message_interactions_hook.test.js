import { describe, it, expect, vi, beforeEach } from "vitest";
import MessageInteractionsHook from "../../js/hooks/message_interactions_hook";

function createMockHook() {
  const hook = Object.create(MessageInteractionsHook);
  hook.el = document.createElement("div");
  hook.el.id = "chat-messages";
  hook.pushEvent = vi.fn();
  hook.handleEvent = vi.fn();

  // Store event handlers for testing
  hook._eventHandlers = {};
  hook.handleEvent = (event, callback) => {
    hook._eventHandlers[event] = callback;
  };

  return hook;
}

describe("MessageInteractionsHook", () => {
  let hook;

  beforeEach(() => {
    document.body.innerHTML = "";
    hook = createMockHook();
    document.body.appendChild(hook.el);
  });

  it("has a mounted function", () => {
    expect(typeof MessageInteractionsHook.mounted).toBe("function");
  });

  it("registers scroll_to_message event handler on mount", () => {
    hook.mounted();
    expect(hook._eventHandlers).toHaveProperty("scroll_to_message");
  });

  it("registers enter_edit_mode event handler on mount", () => {
    hook.mounted();
    expect(hook._eventHandlers).toHaveProperty("enter_edit_mode");
  });

  it("registers exit_edit_mode event handler on mount", () => {
    hook.mounted();
    expect(hook._eventHandlers).toHaveProperty("exit_edit_mode");
  });

  describe("scroll_to_message handler", () => {
    it("scrolls to target message and adds highlight class", () => {
      hook.mounted();

      const msgEl = document.createElement("div");
      msgEl.id = "msg-42";
      hook.el.appendChild(msgEl);
      msgEl.scrollIntoView = vi.fn();

      hook._eventHandlers["scroll_to_message"]({ message_id: 42 });

      expect(msgEl.scrollIntoView).toHaveBeenCalled();
      expect(msgEl.classList.contains("chat-message--scroll-highlight")).toBe(true);
    });

    it("silently ignores when message not found", () => {
      hook.mounted();
      // Should not throw
      hook._eventHandlers["scroll_to_message"]({ message_id: 999 });
    });
  });
});
