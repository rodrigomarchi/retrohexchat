/**
 * LiveView hook for the emoji picker.
 *
 * Handles:
 * - insert_emoji push_event: inserts emoji at cursor position in chat input
 * - Click-outside to close the picker
 * - Escape key to close the picker
 */
import { insertAtCursor } from "../lib/input.js";

const EmojiPickerHook = {
  mounted() {
    this.handleEvent("insert_emoji", ({ char }) => {
      const input = document.getElementById("chat-input");
      if (!input) return;

      insertAtCursor(input, char);
      input.focus();
    });

    this._outsideClick = (e) => {
      if (!this.el.contains(e.target) && !e.target.closest("[data-emoji-toggle]")) {
        this.pushEvent("toggle_emoji_picker", {});
      }
    };
    document.addEventListener("mousedown", this._outsideClick);

    this._escapeKey = (e) => {
      if (e.key === "Escape") {
        this.pushEvent("toggle_emoji_picker", {});
      }
    };
    document.addEventListener("keydown", this._escapeKey);
  },

  destroyed() {
    if (this._outsideClick) {
      document.removeEventListener("mousedown", this._outsideClick);
    }
    if (this._escapeKey) {
      document.removeEventListener("keydown", this._escapeKey);
    }
  },
};

export default EmojiPickerHook;
