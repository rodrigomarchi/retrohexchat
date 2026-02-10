/**
 * LiveView hook for keyboard shortcuts in the chat input.
 *
 * - Arrow Up / Down: navigate command history
 * - Tab: nickname completion
 */
const KeyboardHook = {
  mounted() {
    this.inputEl = this.el;

    this.inputEl.addEventListener("keydown", (e) => {
      if (e.key === "ArrowUp") {
        e.preventDefault();
        this.pushEvent("history_navigate", { direction: "up" });
        return;
      }

      if (e.key === "ArrowDown") {
        e.preventDefault();
        this.pushEvent("history_navigate", { direction: "down" });
        return;
      }

      if (e.key === "Tab") {
        e.preventDefault();
        this.pushEvent("tab_complete", { partial: this.inputEl.value });
      }
    });
  },
};

export default KeyboardHook;
