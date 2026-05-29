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
} from "../../lib/chat/search.js";

const SearchHighlightHook = {
  mounted() {
    this.lastSearchPayload = null;
    this.rehighlightTimer = null;
    this.observer = null;
    this.suppressObserver = false;

    this.handleEvent("search_highlight", (payload) => {
      this.lastSearchPayload = payload.query?.trim() ? payload : null;
      this.highlightMatches(payload);
    });

    this.handleEvent("search_scroll_to", ({ index }) => {
      const marks = document.querySelectorAll("mark.search-highlight");
      scrollToMatch(marks, index);
    });

    this.handleEvent("search_clear_highlights", () => {
      this.lastSearchPayload = null;
      this.withObserverSuppressed(() => clearHighlights());
    });
  },

  destroyed() {
    if (this.rehighlightTimer) {
      clearTimeout(this.rehighlightTimer);
    }

    if (this.observer) {
      this.observer.disconnect();
    }
  },

  ensureObserver(container) {
    if (this.observer || !container) return;

    this.observer = new MutationObserver(() => {
      if (this.suppressObserver || !this.lastSearchPayload) return;

      if (this.rehighlightTimer) {
        clearTimeout(this.rehighlightTimer);
      }

      this.rehighlightTimer = setTimeout(() => {
        this.highlightMatches(this.lastSearchPayload);
      }, 0);
    });

    this.observer.observe(container, { childList: true, subtree: true });
  },

  withObserverSuppressed(callback) {
    this.suppressObserver = true;

    try {
      return callback();
    } finally {
      setTimeout(() => {
        this.suppressObserver = false;
      }, 0);
    }
  },

  clearHighlights() {
    this.withObserverSuppressed(() => {
      clearHighlights();
    });
  },

  highlightMatches({ query, case_sensitive, regex, mention_nick, my_nick }) {
    this.withObserverSuppressed(() => clearHighlights());

    if (!query || query.trim() === "") {
      this.pushEvent("search_highlight_count", { count: 0 });
      return;
    }

    const container = document.getElementById("chat-messages");
    if (!container) {
      this.pushEvent("search_highlight_count", { count: 0 });
      return;
    }

    this.ensureObserver(container);

    const pattern = compilePattern(query, case_sensitive, regex);
    if (!pattern) {
      this.pushEvent("search_highlight_count", { count: 0, error: "Invalid regex" });
      return;
    }

    let targets = container.querySelectorAll(".chat-content, .chat-action");
    const mentionNick = mention_nick || my_nick;

    if (mentionNick) {
      const normalizedNick = mentionNick.toLowerCase();
      targets = Array.from(targets).filter((el) => {
        return el.textContent.toLowerCase().includes(normalizedNick);
      });
    }

    let totalCount = 0;

    this.withObserverSuppressed(() => {
      targets.forEach((target) => {
        totalCount += highlightInElement(target, pattern);
      });
    });

    this.pushEvent("search_highlight_count", { count: totalCount });

    if (totalCount > 0) {
      const marks = document.querySelectorAll("mark.search-highlight");
      scrollToMatch(marks, 1);
    }
  },
};

export default SearchHighlightHook;
