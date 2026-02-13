/**
 * LiveView hook for the emoji picker.
 *
 * Handles:
 * - insert_emoji push_event: inserts emoji at cursor position in chat input
 * - Click-outside to close the picker
 * - Escape key to close the picker
 */
const EmojiPickerHook = {
  mounted() {
    this.handleEvent("insert_emoji", ({ char }) => {
      const input = document.getElementById("chat-input");
      if (!input) return;

      const start = input.selectionStart;
      const end = input.selectionEnd;
      const value = input.value;
      input.value = value.slice(0, start) + char + value.slice(end);
      input.selectionStart = input.selectionEnd = start + char.length;
      input.dispatchEvent(new Event("input", { bubbles: true }));
      input.focus();
    });

    // Close on click outside
    this._outsideClick = (e) => {
      if (!this.el.contains(e.target) && !e.target.closest("[data-emoji-toggle]")) {
        this.pushEvent("toggle_emoji_picker", {});
      }
    };
    document.addEventListener("mousedown", this._outsideClick);

    // Close on Escape
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
