/**
 * LiveView hook for intercepting multi-line paste into chat input.
 * If pasted text has 2+ non-empty lines, prevents default and pushes event.
 */
import { parseMultiLinePaste } from "../../lib/chat/paste.js";

const PasteHook = {
  mounted() {
    const input = document.getElementById("chat-input");
    if (!input) return;

    input.addEventListener("paste", (e) => {
      const text = (e.clipboardData || window.clipboardData).getData("text/plain");
      const lines = parseMultiLinePaste(text);

      if (lines) {
        e.preventDefault();
        this.pushEvent("paste_lines", { lines });
      }
      // Single line: allow normal paste behavior
    });
  },
};

export default PasteHook;
