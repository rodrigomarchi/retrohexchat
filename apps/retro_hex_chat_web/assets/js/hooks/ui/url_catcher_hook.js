/**
 * LiveView hook for URL catcher double-click → open URL.
 * Delegates dblclick events to table rows with data-url attribute.
 */
import { findClosestWithData } from "../../lib/ui/dom.js";

const URLCatcherHook = {
  mounted() {
    this.el.addEventListener("dblclick", (e) => {
      const url = findClosestWithData(e.target, "tr[data-url]", "url");
      if (url) {
        window.open(url, "_blank", "noopener,noreferrer");
      }
    });
  },
};

export default URLCatcherHook;
