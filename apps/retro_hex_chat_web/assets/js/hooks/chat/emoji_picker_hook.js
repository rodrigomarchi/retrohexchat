/**
 * LiveView hook for the emoji picker.
 *
 * Handles:
 * - Click-outside to close the picker
 * - Escape key to close the picker
 */
const EmojiPickerHook = {
  mounted() {
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
