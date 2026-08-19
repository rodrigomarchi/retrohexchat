/**
 * LiveView binding for search highlighting in chat messages.
 *
 * The observer, the suppression window and the highlight orchestration live in
 * `lib/chat/search_highlight.js`. This forwards the server's search events and
 * pushes the match count back.
 */
import { createSearchHighlighter } from "../../lib/chat/search_highlight.js";
import { t } from "../../lib/i18n.js";

export function createSearchHighlightHook({ factory = createSearchHighlighter } = {}) {
  return {
    mounted() {
      this.highlighter = factory({
        onCount: (payload) => this.pushEvent("search_highlight_count", payload),
        invalidRegexMessage: t("Invalid regex"),
      });

      this.handleEvent("search_highlight", (payload) => this.highlighter.highlight(payload));
      this.handleEvent("search_scroll_to", ({ index }) => this.highlighter.scrollTo(index));
      this.handleEvent("search_clear_highlights", () => this.highlighter.clear());
    },

    destroyed() {
      this.highlighter.destroy();
    },
  };
}

export default createSearchHighlightHook();
