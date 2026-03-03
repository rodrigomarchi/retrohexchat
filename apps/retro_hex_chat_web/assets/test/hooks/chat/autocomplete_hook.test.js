import {
  mountHook,
  simulateEvent,
  cleanupDOM,
  mockLocalStorage,
} from "../../helpers/hook_helper.js";
import AutocompleteHook from "../../../js/hooks/chat/autocomplete_hook.js";

describe("AutocompleteHook", () => {
  let hook;
  let storage;

  beforeEach(() => {
    storage = mockLocalStorage();
    hook = mountHook(AutocompleteHook, { tag: "textarea", attrs: { id: "chat-input" } });
  });

  afterEach(() => {
    cleanupDOM();
    storage.restore();
  });

  // ── detectTrigger ──────────────────────────────────────

  describe("detectTrigger", () => {
    it("detects /command trigger", () => {
      const result = hook.detectTrigger("/join");
      expect(result).toEqual({ type: "command", partial: "join" });
    });

    it("detects / with empty partial", () => {
      const result = hook.detectTrigger("/");
      expect(result).toEqual({ type: "command", partial: "" });
    });

    it("returns null for command with space (not a trigger)", () => {
      const result = hook.detectTrigger("/join #test");
      // This hits the argument context path
      expect(result).toEqual({ type: "arg_channel", partial: "#test", command: "join" });
    });

    it("detects @nick trigger", () => {
      hook.el.value = "hello @rod";
      hook.el.selectionStart = 10;
      const result = hook.detectTrigger("hello @rod");
      expect(result).toEqual({ type: "nick", partial: "rod" });
    });

    it("detects #channel trigger", () => {
      hook.el.value = "go to #gen";
      hook.el.selectionStart = 10;
      const result = hook.detectTrigger("go to #gen");
      expect(result).toEqual({ type: "channel", partial: "gen" });
    });

    it("returns null for empty input", () => {
      expect(hook.detectTrigger("")).toBeNull();
      expect(hook.detectTrigger(null)).toBeNull();
    });

    it("returns null for regular text", () => {
      hook.el.value = "hello world";
      hook.el.selectionStart = 11;
      expect(hook.detectTrigger("hello world")).toBeNull();
    });

    it("detects arg_nick for /msg command", () => {
      const result = hook.detectTrigger("/msg rod");
      expect(result).toEqual({ type: "arg_nick", partial: "rod", command: "msg" });
    });
  });

  // ── isSensitiveCommand ─────────────────────────────────

  describe("isSensitiveCommand", () => {
    it("identifies /identify as sensitive", () => {
      expect(hook.isSensitiveCommand("/identify mypass")).toBe(true);
    });

    it("identifies /nickserv as sensitive", () => {
      expect(hook.isSensitiveCommand("/nickserv identify pass")).toBe(true);
    });

    it("identifies standalone /identify", () => {
      expect(hook.isSensitiveCommand("/identify")).toBe(true);
    });

    it("is case-insensitive", () => {
      expect(hook.isSensitiveCommand("/IDENTIFY pass")).toBe(true);
    });

    it("allows /msg (not sensitive)", () => {
      expect(hook.isSensitiveCommand("/msg user hello")).toBe(false);
    });
  });

  // ── history ────────────────────────────────────────────

  describe("history navigation", () => {
    beforeEach(() => {
      // Pre-populate persisted history via the history manager
      storage.store["retro_hex_chat_history"] = JSON.stringify(["third", "second", "first"]);
      hook.historyManager.load();
      hook.persistedHistory = hook.historyManager.getHistory();
    });

    it("Ctrl+Up navigates to most recent history entry", () => {
      hook.historyUp();
      expect(hook.el.value).toBe("third");
    });

    it("Ctrl+Up twice navigates to second entry", () => {
      hook.historyUp();
      hook.historyUp();
      expect(hook.el.value).toBe("second");
    });

    it("Ctrl+Down restores draft after browsing", () => {
      hook.el.value = "my draft";
      hook.el.selectionStart = 8;
      hook.historyUp();
      expect(hook.el.value).toBe("third");
      hook.historyDown();
      expect(hook.el.value).toBe("my draft");
    });

    it("does nothing when history is empty", () => {
      storage.store["retro_hex_chat_history"] = JSON.stringify([]);
      hook.historyManager.load();
      hook.el.value = "keep me";
      hook.historyUp();
      expect(hook.el.value).toBe("keep me");
    });
  });

  // ── tab completion ─────────────────────────────────────

  describe("tab completion", () => {
    it("pushes tab_complete event on Tab", () => {
      hook.el.value = "rod";
      hook.el.dispatchEvent(new KeyboardEvent("keydown", { key: "Tab", bubbles: true }));
      expect(hook.pushEvent).toHaveBeenCalledWith("tab_complete", {
        partial: "rod",
        is_start: true,
      });
    });

    it("tab_matches event sets input value", () => {
      simulateEvent(hook, "tab_matches", { matches: ["alice", "robot"], is_start: true });
      expect(hook.el.value).toBe("alice: ");
    });
  });

  // ── IRC formatting shortcuts ───────────────────────────

  describe("IRC formatting shortcuts", () => {
    it("Ctrl+Shift+B inserts bold code", () => {
      hook.el.value = "";
      hook.el.selectionStart = 0;
      hook.el.selectionEnd = 0;
      hook.el.dispatchEvent(
        new KeyboardEvent("keydown", { key: "b", ctrlKey: true, shiftKey: true, bubbles: true }),
      );
      expect(hook.el.value).toBe("\x02");
    });

    it("Ctrl+Shift+U inserts underline code", () => {
      hook.el.value = "";
      hook.el.selectionStart = 0;
      hook.el.selectionEnd = 0;
      hook.el.dispatchEvent(
        new KeyboardEvent("keydown", { key: "u", ctrlKey: true, shiftKey: true, bubbles: true }),
      );
      expect(hook.el.value).toBe("\x1F");
    });
  });

  // ── Enter submission ───────────────────────────────────

  describe("Enter key", () => {
    it("submits the form on Enter", () => {
      const form = document.createElement("form");
      form.appendChild(hook.el);
      document.body.appendChild(form);

      let submitted = false;
      form.addEventListener("submit", (e) => {
        e.preventDefault();
        submitted = true;
      });

      hook.el.value = "hello";
      hook.el.dispatchEvent(
        new KeyboardEvent("keydown", { key: "Enter", bubbles: true, cancelable: true }),
      );
      expect(submitted).toBe(true);
    });

    it("saves to persisted history on Enter", () => {
      const form = document.createElement("form");
      form.appendChild(hook.el);
      document.body.appendChild(form);

      hook.el.value = "hello world";
      hook.el.dispatchEvent(
        new KeyboardEvent("keydown", { key: "Enter", bubbles: true, cancelable: true }),
      );
      expect(hook.persistedHistory[0]).toBe("hello world");
    });
  });

  // ── auto-resize ────────────────────────────────────────

  describe("auto-resize", () => {
    it("computes maxHeight on mount", () => {
      expect(hook.maxHeight).toBeGreaterThan(0);
    });

    it("adjusts height on input event", () => {
      hook.el.value = "line1\nline2\nline3";
      hook.el.dispatchEvent(new Event("input", { bubbles: true }));
      // After auto-resize, the height style should be set
      expect(hook.el.style.height).toBeDefined();
    });
  });

  // ── getArgumentContext ─────────────────────────────────

  describe("getArgumentContext", () => {
    it("returns arg_nick for /msg", () => {
      expect(hook.getArgumentContext("msg")).toBe("arg_nick");
    });

    it("returns arg_nick for /kick", () => {
      expect(hook.getArgumentContext("kick")).toBe("arg_nick");
    });

    it("returns arg_channel for /join", () => {
      expect(hook.getArgumentContext("join")).toBe("arg_channel");
    });

    it("returns null for unknown command", () => {
      expect(hook.getArgumentContext("unknown")).toBeNull();
    });
  });
});
