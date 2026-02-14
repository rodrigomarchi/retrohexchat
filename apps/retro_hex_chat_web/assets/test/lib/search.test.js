import {
  escapeRegex,
  compilePattern,
  highlightInElement,
  clearHighlights,
  scrollToMatch,
} from "../../js/lib/search.js";
import "../helpers/hook_helper.js"; // scrollIntoView stub
import { cleanupDOM } from "../helpers/hook_helper.js";

describe("lib/search", () => {
  afterEach(() => {
    cleanupDOM();
  });

  // ── escapeRegex ────────────────────────────────────────

  describe("escapeRegex", () => {
    it("escapes special characters", () => {
      expect(escapeRegex("a.b*c")).toBe("a\\.b\\*c");
    });

    it("escapes brackets", () => {
      expect(escapeRegex("[test]")).toBe("\\[test\\]");
    });

    it("passes through plain text", () => {
      expect(escapeRegex("hello")).toBe("hello");
    });
  });

  // ── compilePattern ─────────────────────────────────────

  describe("compilePattern", () => {
    it("compiles literal pattern (case-insensitive)", () => {
      const p = compilePattern("hello", false, false);
      expect(p).toBeInstanceOf(RegExp);
      expect(p.flags).toContain("i");
    });

    it("compiles literal pattern (case-sensitive)", () => {
      const p = compilePattern("hello", true, false);
      expect(p.flags).not.toContain("i");
    });

    it("compiles regex pattern", () => {
      const p = compilePattern("\\d+", false, true);
      expect("abc123".match(p)).toBeTruthy();
    });

    it("returns null for invalid regex", () => {
      expect(compilePattern("[invalid", false, true)).toBeNull();
    });

    it("escapes special chars in literal mode", () => {
      const p = compilePattern("a.b", false, false);
      expect("axb".match(p)).toBeNull();
      expect("a.b".match(p)).toBeTruthy();
    });
  });

  // ── highlightInElement ─────────────────────────────────

  describe("highlightInElement", () => {
    function makeEl(text) {
      const el = document.createElement("div");
      el.textContent = text;
      document.body.appendChild(el);
      return el;
    }

    it("wraps matches in <mark>", () => {
      const el = makeEl("hello world hello");
      const count = highlightInElement(el, /hello/gi);
      expect(count).toBe(2);
      expect(el.querySelectorAll("mark.search-highlight")).toHaveLength(2);
    });

    it("returns 0 for no matches", () => {
      const el = makeEl("hello world");
      const count = highlightInElement(el, /zzz/gi);
      expect(count).toBe(0);
    });

    it("skips existing marks", () => {
      const el = document.createElement("div");
      el.innerHTML = '<mark class="search-highlight">hello</mark> world';
      document.body.appendChild(el);
      const count = highlightInElement(el, /hello/gi);
      expect(count).toBe(0);
    });

    it("preserves surrounding text", () => {
      const el = makeEl("abc foo def");
      highlightInElement(el, /foo/g);
      expect(el.textContent).toBe("abc foo def");
    });

    it("handles empty text nodes", () => {
      const el = makeEl("");
      const count = highlightInElement(el, /test/g);
      expect(count).toBe(0);
    });
  });

  // ── clearHighlights ────────────────────────────────────

  describe("clearHighlights", () => {
    it("unwraps mark elements", () => {
      const el = document.createElement("div");
      el.innerHTML = 'hello <mark class="search-highlight">world</mark> foo';
      document.body.appendChild(el);
      clearHighlights();
      expect(el.querySelectorAll("mark")).toHaveLength(0);
      expect(el.textContent).toBe("hello world foo");
    });

    it("normalizes adjacent text nodes", () => {
      const el = document.createElement("div");
      el.innerHTML =
        '<mark class="search-highlight">a</mark><mark class="search-highlight">b</mark>';
      document.body.appendChild(el);
      clearHighlights();
      expect(el.childNodes).toHaveLength(1);
    });
  });

  // ── scrollToMatch ──────────────────────────────────────

  describe("scrollToMatch", () => {
    function makeMarks(count) {
      const container = document.createElement("div");
      for (let i = 0; i < count; i++) {
        const m = document.createElement("mark");
        m.className = "search-highlight";
        m.textContent = `match${i}`;
        container.appendChild(m);
      }
      document.body.appendChild(container);
      return container.querySelectorAll("mark.search-highlight");
    }

    it("adds active class to correct mark", () => {
      const marks = makeMarks(3);
      scrollToMatch(marks, 2);
      expect(marks[1].classList.contains("search-highlight-active")).toBe(true);
      expect(marks[0].classList.contains("search-highlight-active")).toBe(false);
    });

    it("clamps index to valid range", () => {
      const marks = makeMarks(3);
      scrollToMatch(marks, 10);
      expect(marks[2].classList.contains("search-highlight-active")).toBe(true);
    });

    it("handles empty marks", () => {
      scrollToMatch([], 1); // should not throw
    });
  });
});
