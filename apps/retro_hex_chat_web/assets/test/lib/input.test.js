import {
  insertAtCursor,
  detectTrigger,
  getArgumentContext,
  computeMaxHeight,
  autoResize,
} from "../../js/lib/input.js";
import "../helpers/hook_helper.js"; // for scrollIntoView stub
import { cleanupDOM } from "../helpers/hook_helper.js";

describe("lib/input", () => {
  afterEach(() => {
    cleanupDOM();
  });

  // ── insertAtCursor ─────────────────────────────────────

  describe("insertAtCursor", () => {
    function makeInput(value = "", selStart = 0, selEnd = 0) {
      const el = document.createElement("textarea");
      document.body.appendChild(el);
      el.value = value;
      el.selectionStart = selStart;
      el.selectionEnd = selEnd;
      return el;
    }

    it("inserts at empty input", () => {
      const el = makeInput();
      insertAtCursor(el, "hello");
      expect(el.value).toBe("hello");
      expect(el.selectionStart).toBe(5);
    });

    it("inserts in the middle", () => {
      const el = makeInput("abcd", 2, 2);
      insertAtCursor(el, "XY");
      expect(el.value).toBe("abXYcd");
      expect(el.selectionStart).toBe(4);
    });

    it("replaces selection", () => {
      const el = makeInput("hello world", 6, 11);
      insertAtCursor(el, "earth");
      expect(el.value).toBe("hello earth");
    });

    it("dispatches input event", () => {
      const el = makeInput();
      let fired = false;
      el.addEventListener("input", () => {
        fired = true;
      });
      insertAtCursor(el, "x");
      expect(fired).toBe(true);
    });

    it("inserts at end", () => {
      const el = makeInput("abc", 3, 3);
      insertAtCursor(el, "!");
      expect(el.value).toBe("abc!");
      expect(el.selectionStart).toBe(4);
    });
  });

  // ── detectTrigger ──────────────────────────────────────

  describe("detectTrigger", () => {
    const getCtx = getArgumentContext;

    it("detects command trigger /cmd", () => {
      expect(detectTrigger("/join", 5, getCtx)).toEqual({ type: "command", partial: "join" });
    });

    it("detects empty command /", () => {
      expect(detectTrigger("/", 1, getCtx)).toEqual({ type: "command", partial: "" });
    });

    it("detects arg_nick for /msg user", () => {
      expect(detectTrigger("/msg alice", 10, getCtx)).toEqual({
        type: "arg_nick",
        partial: "alice",
        command: "msg",
      });
    });

    it("detects arg_channel for /join #ch", () => {
      expect(detectTrigger("/join #gen", 10, getCtx)).toEqual({
        type: "arg_channel",
        partial: "#gen",
        command: "join",
      });
    });

    it("detects @nick at word boundary", () => {
      expect(detectTrigger("hey @rod", 8, getCtx)).toEqual({ type: "nick", partial: "rod" });
    });

    it("detects @nick at start", () => {
      expect(detectTrigger("@alice", 6, getCtx)).toEqual({ type: "nick", partial: "alice" });
    });

    it("detects #channel at word boundary", () => {
      expect(detectTrigger("go #gen", 7, getCtx)).toEqual({ type: "channel", partial: "gen" });
    });

    it("returns null for plain text", () => {
      expect(detectTrigger("hello world", 11, getCtx)).toBeNull();
    });

    it("returns null for empty/null", () => {
      expect(detectTrigger("", 0, getCtx)).toBeNull();
      expect(detectTrigger(null, 0, getCtx)).toBeNull();
    });

    it("requires min 1 char after @ trigger", () => {
      expect(detectTrigger("@", 1, getCtx)).toBeNull();
    });

    it("requires min 1 char after # trigger", () => {
      expect(detectTrigger("#", 1, getCtx)).toBeNull();
    });
  });

  // ── getArgumentContext ─────────────────────────────────

  describe("getArgumentContext", () => {
    it("returns arg_nick for nick commands", () => {
      expect(getArgumentContext("msg")).toBe("arg_nick");
      expect(getArgumentContext("whois")).toBe("arg_nick");
      expect(getArgumentContext("kick")).toBe("arg_nick");
      expect(getArgumentContext("invite")).toBe("arg_nick");
    });

    it("returns arg_channel for channel commands", () => {
      expect(getArgumentContext("join")).toBe("arg_channel");
      expect(getArgumentContext("part")).toBe("arg_channel");
      expect(getArgumentContext("topic")).toBe("arg_channel");
    });

    it("returns null for unknown commands", () => {
      expect(getArgumentContext("quit")).toBeNull();
      expect(getArgumentContext("help")).toBeNull();
    });
  });

  // ── computeMaxHeight ───────────────────────────────────

  describe("computeMaxHeight", () => {
    it("computes positive value", () => {
      const el = document.createElement("textarea");
      document.body.appendChild(el);
      const result = computeMaxHeight(el, 5);
      expect(result).toBeGreaterThan(0);
    });
  });

  // ── autoResize ─────────────────────────────────────────

  describe("autoResize", () => {
    it("sets height style on element", () => {
      const el = document.createElement("textarea");
      document.body.appendChild(el);
      el.value = "test";
      autoResize(el, 100);
      expect(el.style.height).toBeDefined();
    });
  });
});
