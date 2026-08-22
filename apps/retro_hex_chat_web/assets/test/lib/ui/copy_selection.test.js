import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import {
  copyCurrentSelection,
  handleCopySelectionClick,
  refreshCopySelectionItems,
  selectedChatLogText,
} from "../../../js/lib/ui/copy_selection";

// The Copy entry exists in two menus driven by two different engines, so its
// rules live in one module and are tested here rather than twice over.
describe("copy_selection", () => {
  let root;
  let chatLog;

  beforeEach(() => {
    document.body.innerHTML = `
      <div id="chat-messages"><p id="message">a message</p></div>
      <div id="outside"><p id="stray">not a message</p></div>
      <div id="menu">
        <button data-menubar-copy-selection data-copy-disabled="true" aria-disabled="true">
          Copy
        </button>
      </div>
    `;
    root = document.getElementById("menu");
    chatLog = document.getElementById("chat-messages");
  });

  afterEach(() => {
    vi.restoreAllMocks();
    document.body.innerHTML = "";
  });

  // The selection API is not implemented in jsdom beyond a stub, so the two
  // things the module actually asks it — the text, and where the range sits —
  // are supplied directly.
  function selectWithin(container, text) {
    vi.spyOn(window, "getSelection").mockReturnValue({
      rangeCount: container ? 1 : 0,
      toString: () => text,
      getRangeAt: () => ({ commonAncestorContainer: container }),
    });
  }

  describe("what counts as a selection", () => {
    it("reads text selected inside the chat log", () => {
      selectWithin(document.getElementById("message"), "a message");

      expect(selectedChatLogText()).toBe("a message");
    });

    it("ignores a selection outside the chat log", () => {
      // Otherwise a menu-driven Copy would happily copy the menu's own label.
      selectWithin(document.getElementById("stray"), "not a message");

      expect(selectedChatLogText()).toBe("");
    });

    it("ignores whitespace-only text", () => {
      selectWithin(document.getElementById("message"), "   \n ");

      expect(selectedChatLogText()).toBe("");
    });

    it("reads nothing on a screen with no chat log", () => {
      chatLog.remove();
      selectWithin(document.getElementById("stray"), "a message");

      expect(selectedChatLogText()).toBe("");
    });

    it("treats a stale range as no selection, and says so", () => {
      const debug = vi.spyOn(console, "debug").mockImplementation(() => {});
      vi.spyOn(window, "getSelection").mockReturnValue({
        rangeCount: 1,
        toString: () => "a message",
        getRangeAt: () => {
          throw new Error("stale range");
        },
      });

      expect(selectedChatLogText()).toBe("");
      expect(debug).toHaveBeenCalled();
    });
  });

  describe("syncing the rows", () => {
    it("enables the row while the chat log has a selection", () => {
      selectWithin(document.getElementById("message"), "a message");
      refreshCopySelectionItems(root);

      const item = root.querySelector("[data-menubar-copy-selection]");
      expect(item.dataset.copyDisabled).toBe("false");
      expect(item.getAttribute("aria-disabled")).toBe("false");
      expect(item.classList.contains("menubar-copy-disabled")).toBe(false);
    });

    it("disables the row when nothing is selected", () => {
      selectWithin(null, "");
      refreshCopySelectionItems(root);

      const item = root.querySelector("[data-menubar-copy-selection]");
      expect(item.dataset.copyDisabled).toBe("true");
      expect(item.getAttribute("aria-disabled")).toBe("true");
      expect(item.classList.contains("menubar-copy-disabled")).toBe(true);
    });

    it("survives being handed nothing to sync", () => {
      expect(() => refreshCopySelectionItems(null)).not.toThrow();
    });
  });

  describe("copying", () => {
    it("writes the selection to the clipboard", async () => {
      const writeText = vi.fn().mockResolvedValue(undefined);
      vi.stubGlobal("navigator", { clipboard: { writeText } });
      selectWithin(document.getElementById("message"), "a message");

      copyCurrentSelection();

      expect(writeText).toHaveBeenCalledWith("a message");
    });

    it("falls back to execCommand when the clipboard refuses", async () => {
      const writeText = vi.fn().mockRejectedValue(new Error("denied"));
      const execCommand = vi.fn();
      vi.stubGlobal("navigator", { clipboard: { writeText } });
      vi.spyOn(console, "debug").mockImplementation(() => {});
      document.execCommand = execCommand;
      selectWithin(document.getElementById("message"), "a message");

      copyCurrentSelection();
      await vi.waitFor(() => expect(execCommand).toHaveBeenCalledWith("copy"));
    });

    it("does nothing when there is no selection to copy", () => {
      const writeText = vi.fn();
      vi.stubGlobal("navigator", { clipboard: { writeText } });
      selectWithin(null, "");

      copyCurrentSelection();

      expect(writeText).not.toHaveBeenCalled();
    });
  });

  describe("claiming the click", () => {
    it("claims a click on a copy row and copies", () => {
      const writeText = vi.fn().mockResolvedValue(undefined);
      vi.stubGlobal("navigator", { clipboard: { writeText } });
      selectWithin(document.getElementById("message"), "a message");
      refreshCopySelectionItems(root);

      const event = clickOn(root.querySelector("[data-menubar-copy-selection]"));

      expect(handleCopySelectionClick(event)).toBe(true);
      expect(writeText).toHaveBeenCalledWith("a message");
    });

    it("rechecks selection on click when an already-open row is stale", () => {
      const writeText = vi.fn().mockResolvedValue(undefined);
      vi.stubGlobal("navigator", { clipboard: { writeText } });
      selectWithin(document.getElementById("message"), "a message");

      const item = root.querySelector("[data-menubar-copy-selection]");
      expect(item.dataset.copyDisabled).toBe("true");

      const event = clickOn(item);

      expect(handleCopySelectionClick(event)).toBe(true);
      expect(item.dataset.copyDisabled).toBe("false");
      expect(writeText).toHaveBeenCalledWith("a message");
    });

    it("claims the click but copies nothing while the row is dead", () => {
      // Claiming it either way matters: the row is neither a window opener nor
      // a server action, so falling through would make the menu act on it.
      const writeText = vi.fn();
      vi.stubGlobal("navigator", { clipboard: { writeText } });
      selectWithin(null, "");
      refreshCopySelectionItems(root);

      const event = clickOn(root.querySelector("[data-menubar-copy-selection]"));

      expect(handleCopySelectionClick(event)).toBe(true);
      expect(writeText).not.toHaveBeenCalled();
    });

    it("leaves any other click alone", () => {
      const event = clickOn(document.getElementById("stray"));

      expect(handleCopySelectionClick(event)).toBe(false);
    });
  });

  function clickOn(target) {
    const event = new MouseEvent("click", { bubbles: true, cancelable: true });
    Object.defineProperty(event, "target", { value: target });
    return event;
  }
});
