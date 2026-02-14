/**
 * LiveView hook for search highlighting in chat messages.
 *
 * Handles server push events:
 * - search_highlight: scan message bodies, wrap matches in <mark>
 * - search_scroll_to: activate Nth match, scrollIntoView
 * - search_clear_highlights: unwrap all <mark> elements
 *
 * Pushes back: search_highlight_count with total match count.
 */
import {
  compilePattern,
  highlightInElement,
  clearHighlights,
  scrollToMatch,
} from "../lib/search.js";

const SearchHighlightHook = {
  mounted() {
    this.handleEvent("search_highlight", (payload) => {
      this.highlightMatches(payload);
    });

    this.handleEvent("search_scroll_to", ({ index }) => {
      const marks = document.querySelectorAll("mark.search-highlight");
      scrollToMatch(marks, index);
    });

    this.handleEvent("search_clear_highlights", () => {
      clearHighlights();
    });
  },

  highlightMatches({ query, case_sensitive, regex, my_nick }) {
    clearHighlights();

    if (!query || query.trim() === "") {
      this.pushEvent("search_highlight_count", { count: 0 });
      return;
    }

    const container = document.getElementById("chat-messages");
    if (!container) {
      this.pushEvent("search_highlight_count", { count: 0 });
      return;
    }

    const pattern = compilePattern(query, case_sensitive, regex);
    if (!pattern) {
      this.pushEvent("search_highlight_count", { count: 0, error: "Invalid regex" });
      return;
    }

    let targets = container.querySelectorAll(".chat-content, .chat-action");

    if (my_nick) {
      targets = Array.from(targets).filter((el) => {
        const row = el.closest("[data-nick]");
        return row && row.getAttribute("data-nick") === my_nick;
      });
    }

    let totalCount = 0;

    targets.forEach((target) => {
      totalCount += highlightInElement(target, pattern);
    });

    this.pushEvent("search_highlight_count", { count: totalCount });

    if (totalCount > 0) {
      const marks = document.querySelectorAll("mark.search-highlight");
      scrollToMatch(marks, 1);
    }
  },
};

export default SearchHighlightHook;
