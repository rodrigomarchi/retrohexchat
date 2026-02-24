import { mountHook, simulateEvent, getPushEvents, cleanupDOM } from "../../helpers/hook_helper.js";
import SearchHighlightHook from "../../../js/hooks/chat/search_highlight_hook.js";

describe("SearchHighlightHook", () => {
  let hook;

  function setupChatMessages(html) {
    const container = document.createElement("div");
    container.id = "chat-messages";
    container.innerHTML = html;
    document.body.appendChild(container);
    return container;
  }

  beforeEach(() => {
    hook = mountHook(SearchHighlightHook);
  });

  afterEach(() => {
    cleanupDOM();
  });

  // ── highlight ──────────────────────────────────────────

  describe("search_highlight", () => {
    it("wraps matches in <mark> elements", () => {
      setupChatMessages('<div class="chat-content">hello world hello</div>');
      simulateEvent(hook, "search_highlight", {
        query: "hello",
        case_sensitive: false,
        regex: false,
      });

      const marks = document.querySelectorAll("mark.search-highlight");
      expect(marks).toHaveLength(2);
      expect(marks[0].textContent).toBe("hello");
    });

    it("pushes match count", () => {
      setupChatMessages('<div class="chat-content">foo bar foo baz foo</div>');
      simulateEvent(hook, "search_highlight", {
        query: "foo",
        case_sensitive: false,
        regex: false,
      });

      const counts = getPushEvents(hook, "search_highlight_count");
      expect(counts[counts.length - 1]).toEqual({ count: 3 });
    });

    it("handles empty query gracefully", () => {
      setupChatMessages('<div class="chat-content">hello</div>');
      simulateEvent(hook, "search_highlight", { query: "", case_sensitive: false, regex: false });

      const counts = getPushEvents(hook, "search_highlight_count");
      expect(counts[counts.length - 1]).toEqual({ count: 0 });
    });
  });

  // ── case sensitivity ───────────────────────────────────

  describe("case sensitivity", () => {
    it("is case-insensitive by default", () => {
      setupChatMessages('<div class="chat-content">Hello HELLO hello</div>');
      simulateEvent(hook, "search_highlight", {
        query: "hello",
        case_sensitive: false,
        regex: false,
      });

      const marks = document.querySelectorAll("mark.search-highlight");
      expect(marks).toHaveLength(3);
    });

    it("respects case-sensitive flag", () => {
      setupChatMessages('<div class="chat-content">Hello HELLO hello</div>');
      simulateEvent(hook, "search_highlight", {
        query: "hello",
        case_sensitive: true,
        regex: false,
      });

      const marks = document.querySelectorAll("mark.search-highlight");
      expect(marks).toHaveLength(1);
    });
  });

  // ── regex mode ─────────────────────────────────────────

  describe("regex mode", () => {
    it("compiles regex pattern", () => {
      setupChatMessages('<div class="chat-content">foo123 bar456</div>');
      simulateEvent(hook, "search_highlight", {
        query: "\\d+",
        case_sensitive: false,
        regex: true,
      });

      const marks = document.querySelectorAll("mark.search-highlight");
      expect(marks).toHaveLength(2);
      expect(marks[0].textContent).toBe("123");
    });

    it("handles invalid regex gracefully", () => {
      setupChatMessages('<div class="chat-content">hello</div>');
      simulateEvent(hook, "search_highlight", {
        query: "[invalid",
        case_sensitive: false,
        regex: true,
      });

      const counts = getPushEvents(hook, "search_highlight_count");
      expect(counts[counts.length - 1]).toEqual({ count: 0, error: "Invalid regex" });
    });
  });

  // ── scroll to match ────────────────────────────────────

  describe("search_scroll_to", () => {
    it("adds active class to specified match", () => {
      setupChatMessages('<div class="chat-content">foo foo foo</div>');
      simulateEvent(hook, "search_highlight", {
        query: "foo",
        case_sensitive: false,
        regex: false,
      });
      simulateEvent(hook, "search_scroll_to", { index: 2 });

      const marks = document.querySelectorAll("mark.search-highlight");
      expect(marks[1].classList.contains("search-highlight-active")).toBe(true);
      expect(marks[0].classList.contains("search-highlight-active")).toBe(false);
    });
  });

  // ── clear ──────────────────────────────────────────────

  describe("search_clear_highlights", () => {
    it("removes all mark elements", () => {
      setupChatMessages('<div class="chat-content">hello world hello</div>');
      simulateEvent(hook, "search_highlight", {
        query: "hello",
        case_sensitive: false,
        regex: false,
      });
      expect(document.querySelectorAll("mark.search-highlight")).toHaveLength(2);

      simulateEvent(hook, "search_clear_highlights", {});
      expect(document.querySelectorAll("mark.search-highlight")).toHaveLength(0);
    });
  });
});
