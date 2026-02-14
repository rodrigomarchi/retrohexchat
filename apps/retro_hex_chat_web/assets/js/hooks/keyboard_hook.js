/**
 * LiveView hook for keyboard shortcuts in the chat input.
 *
 * - Arrow Up / Down: navigate command history
 * - Tab: nickname completion
 */
import { classifyInputKey } from "../lib/keyboard.js";

const KeyboardHook = {
  mounted() {
    this.inputEl = this.el;

    this.inputEl.addEventListener("keydown", (e) => {
      const action = classifyInputKey(e.key);
      if (!action) return;

      e.preventDefault();

      if (action === "tab_complete") {
        this.pushEvent("tab_complete", { partial: this.inputEl.value });
      } else {
        const direction = action === "history_up" ? "up" : "down";
        this.pushEvent("history_navigate", { direction });
      }
    });
  },
};

export default KeyboardHook;
