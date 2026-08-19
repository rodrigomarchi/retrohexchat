/**
 * The chat search-highlight controller — the observer, the suppression window
 * and the highlight orchestration, no LiveView.
 *
 * The primitives (compile a pattern, wrap matches, clear them, scroll to one)
 * are in search.js; this owns the MutationObserver that re-highlights as the
 * stream grows, the suppression that keeps its own writes from re-triggering it,
 * and the run that filters targets, highlights and counts. The match count goes
 * back to the caller through the `onCount` port.
 *
 * @module chat/search_highlight
 */
import { compilePattern, highlightInElement, clearHighlights, scrollToMatch } from "./search.js";

/**
 * Keep only the elements whose text mentions the nick (case-insensitive).
 * @param {Element[]|NodeList} elements
 * @param {string|null} nick
 * @returns {Element[]}
 */
export function filterMentionTargets(elements, nick) {
  const list = Array.from(elements);
  if (!nick) return list;
  const needle = nick.toLowerCase();
  return list.filter((el) => el.textContent.toLowerCase().includes(needle));
}

/**
 * @param {object} ports
 * @param {(payload: {count: number, error?: string}) => void} ports.onCount
 * @param {() => Element|null} [ports.getContainer]
 * @param {string} [ports.invalidRegexMessage]
 */
export function createSearchHighlighter({
  onCount,
  getContainer,
  invalidRegexMessage = "Invalid regex",
}) {
  const container = getContainer || (() => document.getElementById("chat-messages"));

  let lastPayload = null;
  let observer = null;
  let rehighlightTimer = null;
  let suppress = false;

  function withObserverSuppressed(fn) {
    suppress = true;
    try {
      return fn();
    } finally {
      setTimeout(() => {
        suppress = false;
      }, 0);
    }
  }

  function ensureObserver(node) {
    if (observer || !node) return;

    observer = new MutationObserver(() => {
      if (suppress || !lastPayload) return;
      if (rehighlightTimer) clearTimeout(rehighlightTimer);
      rehighlightTimer = setTimeout(() => highlight(lastPayload), 0);
    });

    observer.observe(node, { childList: true, subtree: true });
  }

  function highlight(payload) {
    lastPayload = payload.query?.trim() ? payload : null;
    const { query, case_sensitive, regex, mention_nick, my_nick } = payload;

    withObserverSuppressed(() => clearHighlights());

    if (!query || query.trim() === "") {
      onCount({ count: 0 });
      return;
    }

    const node = container();
    if (!node) {
      onCount({ count: 0 });
      return;
    }

    ensureObserver(node);

    const pattern = compilePattern(query, case_sensitive, regex);
    if (!pattern) {
      onCount({ count: 0, error: invalidRegexMessage });
      return;
    }

    const targets = filterMentionTargets(
      node.querySelectorAll(".chat-content, .chat-action"),
      mention_nick || my_nick,
    );

    let total = 0;
    withObserverSuppressed(() => {
      targets.forEach((target) => (total += highlightInElement(target, pattern)));
    });

    onCount({ count: total });

    if (total > 0) scrollToMatch(document.querySelectorAll("mark.search-highlight"), 1);
  }

  return {
    highlight,

    scrollTo(index) {
      scrollToMatch(document.querySelectorAll("mark.search-highlight"), index);
    },

    clear() {
      lastPayload = null;
      withObserverSuppressed(() => clearHighlights());
    },

    destroy() {
      if (rehighlightTimer) clearTimeout(rehighlightTimer);
      observer?.disconnect();
      observer = null;
    },
  };
}
