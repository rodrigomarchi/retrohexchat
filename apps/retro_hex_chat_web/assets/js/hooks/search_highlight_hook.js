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
const SearchHighlightHook = {
  mounted() {
    this.handleEvent("search_highlight", (payload) => {
      this.highlightMatches(payload);
    });

    this.handleEvent("search_scroll_to", ({ index }) => {
      this.scrollToMatch(index);
    });

    this.handleEvent("search_clear_highlights", () => {
      this.clearHighlights();
    });
  },

  highlightMatches({ query, case_sensitive, regex, my_nick }) {
    this.clearHighlights();

    if (!query || query.trim() === "") {
      this.pushEvent("search_highlight_count", { count: 0 });
      return;
    }

    const container = document.getElementById("chat-messages");
    if (!container) {
      this.pushEvent("search_highlight_count", { count: 0 });
      return;
    }

    let pattern;
    try {
      const flags = case_sensitive ? "g" : "gi";
      pattern = regex ? new RegExp(query, flags) : new RegExp(this.escapeRegex(query), flags);
    } catch {
      this.pushEvent("search_highlight_count", { count: 0, error: "Invalid regex" });
      return;
    }

    // Find all text nodes inside .chat-content and .chat-action spans
    let targets = container.querySelectorAll(".chat-content, .chat-action");

    // Filter to messages from specific nick if my_nick is set
    if (my_nick) {
      targets = Array.from(targets).filter((el) => {
        const row = el.closest("[data-nick]");
        return row && row.getAttribute("data-nick") === my_nick;
      });
    }

    let totalCount = 0;

    targets.forEach((target) => {
      totalCount += this.highlightInElement(target, pattern);
    });

    this.pushEvent("search_highlight_count", { count: totalCount });

    // Auto-scroll to first match if any
    if (totalCount > 0) {
      this.scrollToMatch(1);
    }
  },

  highlightInElement(element, pattern) {
    const walker = document.createTreeWalker(element, NodeFilter.SHOW_TEXT, null);
    const textNodes = [];

    let node;
    while ((node = walker.nextNode())) {
      // Skip nodes inside existing marks
      if (node.parentElement && node.parentElement.closest("mark.search-highlight")) continue;
      textNodes.push(node);
    }

    let count = 0;
    textNodes.forEach((textNode) => {
      const text = textNode.textContent;
      if (!text) return;

      // Reset regex lastIndex
      pattern.lastIndex = 0;
      const matches = [];
      let match;

      while ((match = pattern.exec(text)) !== null) {
        matches.push({ start: match.index, end: match.index + match[0].length, text: match[0] });
        if (match[0].length === 0) {
          pattern.lastIndex++;
        }
      }

      if (matches.length === 0) return;

      const fragment = document.createDocumentFragment();
      let lastIdx = 0;

      matches.forEach((m) => {
        // Text before match
        if (m.start > lastIdx) {
          fragment.appendChild(document.createTextNode(text.slice(lastIdx, m.start)));
        }
        // Highlighted match
        const mark = document.createElement("mark");
        mark.className = "search-highlight";
        mark.textContent = m.text;
        fragment.appendChild(mark);
        lastIdx = m.end;
        count++;
      });

      // Remaining text
      if (lastIdx < text.length) {
        fragment.appendChild(document.createTextNode(text.slice(lastIdx)));
      }

      textNode.parentNode.replaceChild(fragment, textNode);
    });

    return count;
  },

  scrollToMatch(index) {
    const marks = document.querySelectorAll("mark.search-highlight");
    if (marks.length === 0) return;

    // Remove active class from all
    marks.forEach((m) => m.classList.remove("search-highlight-active"));

    // Clamp index to valid range (1-based)
    const clampedIndex = Math.max(1, Math.min(index, marks.length));
    const target = marks[clampedIndex - 1];

    if (target) {
      target.classList.add("search-highlight-active");
      target.scrollIntoView({ block: "center", behavior: "smooth" });
    }
  },

  clearHighlights() {
    const marks = document.querySelectorAll("mark.search-highlight");
    marks.forEach((mark) => {
      const parent = mark.parentNode;
      const text = document.createTextNode(mark.textContent);
      parent.replaceChild(text, mark);
      // Merge adjacent text nodes
      parent.normalize();
    });
  },

  escapeRegex(str) {
    return str.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  },
};

export default SearchHighlightHook;
