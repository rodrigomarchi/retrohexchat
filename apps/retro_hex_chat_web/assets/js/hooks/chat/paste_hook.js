/**
 * LiveView hook for intercepting multi-line paste into chat input.
 * If pasted text has 2+ non-empty lines, prevents default and pushes event.
 */
import { parseMultiLinePaste } from "../../lib/chat/paste.js";

const PasteHook = {
  mounted() {
    const input = document.getElementById("chat-input");
    if (!input) return;

    this.input = input;
    this._onPaste = (e) => {
      if (this.contentFormat(input) === "markdown") return;

      const text = (e.clipboardData || window.clipboardData).getData("text/plain");
      const lines = parseMultiLinePaste(text);

      if (lines) {
        e.preventDefault();
        this.pushEvent("paste_lines", { lines });
      }
      // Single line: allow normal paste behavior
    };

    input.addEventListener("paste", this._onPaste);
  },

  destroyed() {
    if (this.input && this._onPaste) {
      this.input.removeEventListener("paste", this._onPaste);
    }
  },

  contentFormat(input) {
    const form = input.form;
    const formatInput = form?.querySelector("[name='content_format']");
    return formatInput?.value || "irc";
  },
};

export default PasteHook;
