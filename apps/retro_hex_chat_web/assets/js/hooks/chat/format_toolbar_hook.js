/**
 * LiveView hook for the formatting toolbar.
 *
 * Uses mousedown (not click) with preventDefault() to avoid stealing focus
 * from the chat input. Handles B/I/U buttons, color dropdown toggle,
 * and color swatch selection.
 */
import { insertAtCursor } from "../../lib/chat/input.js";
import { IRC_FORMAT_CODES } from "../../lib/chat/irc_format.js";

const FormatToolbarHook = {
  mounted() {
    const dropdown = this.el.querySelector(".format-color-dropdown");

    this.el.addEventListener("mousedown", (e) => {
      const btn = e.target.closest(".format-btn");
      if (!btn) return;

      e.preventDefault();

      const formatCode = btn.dataset.formatCode;
      if (!formatCode) return;

      if (formatCode === "color") {
        dropdown.classList.toggle("format-color-dropdown--open");
        return;
      }

      const code = IRC_FORMAT_CODES[formatCode];
      if (code) {
        const input = document.getElementById("chat-input");
        if (input) {
          insertAtCursor(input, code);
          input.focus();
        }
      }
    });

    this.el.addEventListener("mousedown", (e) => {
      const swatch = e.target.closest(".color-swatch");
      if (!swatch) return;

      e.preventDefault();

      const colorCode = swatch.dataset.colorCode;
      if (colorCode !== undefined) {
        const input = document.getElementById("chat-input");
        if (input) {
          insertAtCursor(input, "\x03" + colorCode);
          input.focus();
        }
        dropdown.classList.remove("format-color-dropdown--open");
      }
    });

    document.addEventListener("mousedown", (e) => {
      if (!this.el.contains(e.target)) {
        dropdown.classList.remove("format-color-dropdown--open");
      }
    });

    document.addEventListener("keydown", (e) => {
      if (e.key === "Escape") {
        dropdown.classList.remove("format-color-dropdown--open");
      }
    });
  },
};

export default FormatToolbarHook;
