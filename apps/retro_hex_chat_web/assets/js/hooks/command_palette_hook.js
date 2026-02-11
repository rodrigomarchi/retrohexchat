/**
 * LiveView hook for slash-command palette interaction and keyboard shortcuts.
 *
 * Combines command palette (/) and keyboard shortcuts (↑/↓ history, Tab completion)
 * into a single hook since LiveView allows only one phx-hook per element.
 */
const CommandPaletteHook = {
  mounted() {
    this.inputEl = this.el;

    this.inputEl.addEventListener("keyup", (e) => {
      const value = this.inputEl.value;

      if (value === "/") {
        this.pushEvent("open_command_palette", {});
        return;
      }

      if (value.startsWith("/") && value.length > 1) {
        const filter = value.slice(1).split(" ")[0];
        this.pushEvent("filter_command_palette", { filter: filter });
        return;
      }

      if (!value.startsWith("/")) {
        this.pushEvent("close_command_palette", {});
      }
    });

    this.inputEl.addEventListener("keydown", (e) => {
      if (e.key === "Escape") {
        this.pushEvent("close_command_palette", {});
        return;
      }

      if (e.key === "Enter") {
        const value = this.inputEl.value;
        if (value.startsWith("/") && !value.includes(" ")) {
          const filter = value.slice(1);
          if (filter.length > 0) {
            this.pushEvent("select_command", { command: filter });
          }
        }
      }

      // Keyboard shortcuts from KeyboardHook
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
        return;
      }

      // IRC formatting shortcuts (Ctrl+key)
      if (e.ctrlKey && !e.altKey && !e.metaKey) {
        const formatCodes = {
          b: "\x02", // Bold
          i: "\x1D", // Italic
          u: "\x1F", // Underline
          k: "\x03", // Color
          r: "\x16", // Reverse
          o: "\x0F", // Reset
        };

        const code = formatCodes[e.key.toLowerCase()];
        if (code) {
          e.preventDefault();
          this.insertAtCursor(code);
        }
      }
    });
  },

  insertAtCursor(text) {
    const el = this.inputEl;
    const start = el.selectionStart;
    const end = el.selectionEnd;
    const value = el.value;
    el.value = value.slice(0, start) + text + value.slice(end);
    el.selectionStart = el.selectionEnd = start + text.length;
    el.dispatchEvent(new Event("input", { bubbles: true }));
  },
};

export default CommandPaletteHook;
