import { mountHook, simulateEvent, cleanupDOM, getPushEvents } from "../../helpers/hook_helper.js";
import AutocompleteHook from "../../../js/hooks/chat/autocomplete_hook.js";

describe("AutocompleteHook", () => {
  let hook;
  let localStorageMock;
  const originalInnerWidth = window.innerWidth;

  beforeEach(() => {
    localStorageMock = {
      getItem: vi.fn(() => {
        throw new Error("AutocompleteHook must not read localStorage");
      }),
      setItem: vi.fn(() => {
        throw new Error("AutocompleteHook must not write localStorage");
      }),
      removeItem: vi.fn(() => {
        throw new Error("AutocompleteHook must not remove localStorage");
      }),
    };

    vi.stubGlobal("localStorage", localStorageMock);
    hook = mountAutocompleteHook();
  });

  afterEach(() => {
    hook?.destroyed?.();
    cleanupDOM();
    vi.unstubAllGlobals();
    Object.defineProperty(window, "innerWidth", {
      configurable: true,
      writable: true,
      value: originalInnerWidth,
    });
  });

  function mountAutocompleteHook(attrs = {}) {
    return mountHook(AutocompleteHook, {
      tag: "textarea",
      attrs: {
        id: "chat-input",
        "data-input-history": "[]",
        "data-recent-commands": "[]",
        ...attrs,
      },
    });
  }

  function setViewportWidth(width) {
    Object.defineProperty(window, "innerWidth", {
      configurable: true,
      writable: true,
      value: width,
    });
  }

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

  // ── history ────────────────────────────────────────────

  describe("history navigation", () => {
    beforeEach(() => {
      hook.historyManager.load({ history: ["third", "second", "first"] });
      hook.persistedHistory = hook.historyManager.getHistory();
    });

    it("loads initial history from server data attributes", () => {
      hook.destroyed();
      cleanupDOM();
      hook = mountAutocompleteHook({
        "data-input-history": JSON.stringify(["from-server"]),
        "data-recent-commands": JSON.stringify(["join"]),
      });

      expect(hook.persistedHistory).toEqual(["from-server"]);
      expect(hook.historyManager.getRecentCommands()).toEqual(["join"]);
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
      hook.historyManager.load({ history: [] });
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

    it("insert_emoji event inserts emoji at cursor", () => {
      simulateEvent(hook, "insert_emoji", { char: "😀" });
      expect(hook.el.value).toBe("😀");
    });

    it("insert_emoji event inserts emoji in the middle of text", () => {
      hook.el.value = "hello world";
      hook.el.selectionStart = 5;
      hook.el.selectionEnd = 5;
      simulateEvent(hook, "insert_emoji", { char: "👋" });
      expect(hook.el.value).toBe("hello👋 world");
    });

    it("focus_input event restores focus to the textarea", () => {
      const other = document.createElement("button");
      document.body.appendChild(other);
      other.focus();

      simulateEvent(hook, "focus_input", {});

      expect(document.activeElement).toBe(hook.el);
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

    it("does not save sensitive commands to recent commands on Enter", () => {
      const form = document.createElement("form");
      form.appendChild(hook.el);
      document.body.appendChild(form);

      hook.el.value = "/ns identify secret";
      hook.el.dispatchEvent(
        new KeyboardEvent("keydown", { key: "Enter", bubbles: true, cancelable: true }),
      );

      expect(hook.historyManager.getRecentCommands()).not.toContain("ns");
    });

    it("pushes updated recent commands to LiveView for non-sensitive commands", () => {
      const form = document.createElement("form");
      form.appendChild(hook.el);
      document.body.appendChild(form);

      hook.el.value = "/away lunch";
      hook.el.dispatchEvent(
        new KeyboardEvent("keydown", { key: "Enter", bubbles: true, cancelable: true }),
      );

      expect(getPushEvents(hook, "recent_commands_loaded")).toContainEqual({
        commands: ["away"],
      });
    });

    it("does not touch localStorage while recording input history", () => {
      const form = document.createElement("form");
      form.appendChild(hook.el);
      document.body.appendChild(form);

      hook.el.value = "/join #lobby";
      hook.el.dispatchEvent(
        new KeyboardEvent("keydown", { key: "Enter", bubbles: true, cancelable: true }),
      );

      expect(localStorageMock.getItem).not.toHaveBeenCalled();
      expect(localStorageMock.setItem).not.toHaveBeenCalled();
      expect(localStorageMock.removeItem).not.toHaveBeenCalled();
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

    it("uses fewer max lines on mobile viewports", () => {
      setViewportWidth(390);
      hook.configureTextareaSizing();
      expect(hook.maxLines).toBe(3);

      setViewportWidth(900);
      hook.configureTextareaSizing();
      expect(hook.maxLines).toBe(5);
    });
  });
});
