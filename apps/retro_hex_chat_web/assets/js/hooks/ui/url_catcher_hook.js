/**
 * URL catcher — double-clicking a captured row offers to open it.
 *
 * It asks rather than opening. The row's own anchor is gated by
 * `OpenTabConfirmHook` like every other door, and a double-click that skipped
 * the question would be the one way into this dialog that opens a stranger's
 * link with no warning at all.
 *
 * Two details worth not rediscovering:
 *
 *   - The row is an `<article data-url>`. This hook looked for `tr[data-url]`,
 *     which the dialog stopped rendering when it moved off a table, so the
 *     double-click had quietly done nothing; its unit test built a `<tr>` and so
 *     agreed with the hook rather than with the screen.
 *   - A double-click fires two `click`s first, and the anchor inside the row is
 *     gated. So a double-click that landed on the anchor has already raised the
 *     dialog, and asking again here would push the same question a third time.
 *     The row outside the anchor is this handler's to claim.
 */
import { gatedAnchor } from "../../lib/chat/open_tab_targets.js";
import { findClosestWithData } from "../../lib/ui/dom.js";

const URLCatcherHook = {
  mounted() {
    this.el.addEventListener("dblclick", (e) => {
      if (gatedAnchor(e.target)) return;

      const url = findClosestWithData(e.target, "[data-url]", "url");
      if (url) {
        this.pushEvent("confirm_open_tab", { url, kind: "external" });
      }
    });
  },
};

export default URLCatcherHook;
